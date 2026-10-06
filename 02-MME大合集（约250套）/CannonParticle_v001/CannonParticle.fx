////////////////////////////////////////////////////////////////////////////////////////////////
//
//  CannonParticle.fx ver0.0.1 打ち出し式パーティクルエフェクト
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define TexFile  "sample.png"       // 粒子に貼り付けるテクスチャファイル名
int TexTypeCount = 1;               // テクスチャ種類数
float3 ParticleColor = {1.0, 1.0, 1.0}; // テクスチャの乗算色(RBG)
float ParticleRandamColor = 0.9;   // 粒子色のばらつき度(0.0～1.0)
float ParticleSize = 0.2;          // 粒子大きさ
float ParticleSpeedMin = 150.0;    // 粒子初速度最小値
float ParticleSpeedMax = 200.0;    // 粒子初速度最大値
float ParticleRotSpeed = 4.0;      // 粒子の回転スピード
float ParticleInitPos = 3.0;       // 粒子発生時の分散位置(大きくすると粒子の初期配置が広くなります)
float ParticleLife = 8.0;          // 粒子の寿命(秒)
float ParticleDecrement = 0.9;     // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float DiffusionAngle = 5.0;        // 発射拡散角(0.0～360.0)
float GravFactor = 20.0;           // 重力定数
float ResistFactor = 5.0;          // 速度抵抗力
float RotResistFactor = 8.0;       // 回転抵抗力(大きくするとゆらゆら感が増します)
float FloorFadeMax = 5.0;          // フェードアウト開始高さ
float FloorFadeMin = 0.0;          // フェードアウト終了高さ

// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
#define ArrangeFileName "Arrange.png" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A  16   // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH     2   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT 1024   // 配置･乱数情報テクスチャピクセル高さ

#define PAI 3.14159265f   // π

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

static float diffD = radians( DiffusionAngle * 0.5f );

float time : TIME;
float elapsed_time : ELAPSEDTIME;
static float Dt = (elapsed_time < 0.2f) ? clamp(elapsed_time, 0.001f, 1.0f/15.0f) : 1.0f/30.0f;

// 1フレーム当たりの粒子発生確率
static float probable = 0.95f * (Dt / ParticleLife) * AcsSi*0.1f; 

// 座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewProjMatrix : VIEWPROJECTION;

texture2D ParticleTex <
    string ResourceName = TexFile;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// 配置･乱数情報テクスチャ
texture2D ArrangeTex <
    string ResourceName = ArrangeFileName;
>;
sampler ArrangeSmp : register(s3) = sampler_state{
    texture = <ArrangeTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
};

// 粒子座標記録用
texture CoordTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmp : register(s4) = sampler_state
{
   Texture = <CoordTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};
texture CoordDepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format = "D24S8";
>;

// 1ステップ前の座標記録用
texture CoordTexOld : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler CoordSmpOld = sampler_state
{
   Texture = <CoordTexOld>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 粒子速度記録用
texture VelocityTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler VelocitySmp = sampler_state
{
   Texture = <VelocityTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


////////////////////////////////////////////////////////////////////////////////////////////////
// 配置･乱数情報テクスチャからデータを取り出す
float Color2Float(int i, int j)
{
    float4 d = tex2Dlod(ArrangeSmp, float4((i+0.5)/TEX_WIDTH_A, (j+0.5)/TEX_HEIGHT, 0, 1));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}

float Color2FloatPS(int i, int j)
{
    float4 d = tex2D(ArrangeSmp, float2((i+0.5)/TEX_WIDTH_A, (j+0.5)/TEX_HEIGHT));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 粒子の回転行列
float4x4 RoundMatrix(int index)
{
   float rotX = ParticleRotSpeed * (1.0f + 0.3f*sin(247*index)) * time + (float)index * 147.0f;
   float rotY = ParticleRotSpeed * (1.0f + 0.3f*sin(368*index)) * time + (float)index * 258.0f;
   float rotZ = ParticleRotSpeed * (1.0f + 0.3f*sin(122*index)) * time + (float)index * 369.0f;

   float sinx = sin(rotX);
   float cosx = cos(rotX);
   float siny = sin(rotY);
   float cosy = cos(rotY);
   float sinz = sin(rotZ);
   float cosz = cos(rotZ);

   float4x4 rMat = { cosz*cosy+sinx*siny*sinz, cosx*sinz, -siny*cosz+sinx*cosy*sinz, 0.0f,
                    -cosy*sinz+sinx*siny*cosz, cosx*cosz,  siny*sinz+sinx*cosy*cosz, 0.0f,
                     cosx*siny,               -sinx,       cosx*cosy,                0.0f,
                     0.0f,                     0.0f,       0.0f,                     1.0f };

   return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

// 共通の頂点シェーダ
VS_OUTPUT Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT Out;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

///////////////////////////////////////////////////////////////////////////////////////
// 粒子の発生・座標計算(xyz:座標,w:経過時間)
float4 UpdatePos_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   int i0 = floor( texCoord.x*TEX_WIDTH );
   int i = i0 * 8;
   int j = floor( texCoord.y*TEX_HEIGHT );
   int index = j + i0 * TEX_HEIGHT;

   if(Pos.w < 0.001f){
      // 未発生粒子の中から新たに粒子を発生させる
      float4 WPos = float4(Color2FloatPS(i, j), Color2FloatPS(i+1, j), Color2FloatPS(i+2, j), 1.0f);
      float3 WPos0 = WorldMatrix._41_42_43;
      WPos.xyz *= ParticleInitPos * 0.1f;
      WPos = mul( WPos, WorldMatrix );
      Pos.xyz = ((WPos.xyz / WPos.w) - WPos0) / AcsSi * 10.0f + WPos0;  // 発生初期座標
      float probable0 = Color2FloatPS(i+7, j);
      if(Vel.w<probable0 && probable0<Vel.w+probable){
         Pos.w = 0.0011f;  // Pos.w>0.001で粒子発生
      }
   }else{
      // 発生粒子は疑似物理計算で座標を更新
      // 1ステップ前の位置
      float4 Pos0 = tex2D(CoordSmpOld, texCoord);

      // 粒子の法線ベクトル
      float3 normal = mul( float3(0.0f,0.0f,1.0f), RoundMatrix(index) );

      // 抵抗係数の設定
      float v = length( Vel.xyz );
      float cosa = dot( normalize(Vel.xyz), normal );
      float coefResist = lerp(ResistFactor, 0.0f, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));
      float coefRotResist = lerp(0.2f, RotResistFactor, smoothstep(-0.3f*ParticleSpeedMax, -10.0f, -v));

      // 加速度計算(速度抵抗力+回転抵抗力+重力)
      float3 Accel = -Vel.xyz * coefResist
                     -normal * v * cosa * coefRotResist
                     + float3(0.0f, -GravFactor, 0.0f);

      // 新しい座標に更新
      Pos.xyz = Pos0.xyz + Dt * (Vel.xyz + Dt * Accel);

      // すでに発生している粒子は経過時間を進める
      Pos.w += elapsed_time;
      Pos.w *= step(Pos.w, ParticleLife); // 指定時間を超えると0
   }

   return Pos;
}

///////////////////////////////////////////////////////////////////////////////////////
// 粒子の速度計算(xyz:速度,w:発生起点)
float4 UpdateVelocity_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(Pos.w < 0.0012f){
      // 発生したての粒子に初速度与える
      int i = floor( texCoord.x*TEX_WIDTH ) * 8;
      int j = floor( texCoord.y*TEX_HEIGHT );
      float time1 = time + 100.0f;
      float s = sin( lerp(0.0f, diffD, frac(Color2FloatPS(i+4, j)*time1)) );
      float t = lerp(-PAI, PAI, frac(Color2FloatPS(i+5, j)*time1));
      float3 vec  = float3( s*cos(t), 1.0f-s, s*sin(t) );
      Vel.xyz = normalize( mul( vec, (float3x3)WorldMatrix ) )
                * lerp(ParticleSpeedMin, ParticleSpeedMax, frac(Color2FloatPS(i+6, j)*time1));
   }else{
      // 粒子の速度計算
      float4 Pos0 = tex2D(CoordSmpOld, texCoord);
      Vel.xyz = ( Pos.xyz - Pos0.xyz ) / Dt;
   }

   // 次発生粒子の起点
   Vel.w += probable;
   Vel.w *= step(Vel.w, 1.0f);

   return Vel;
}

////////////////////////////////////////////////////////////////////////////////////////
// 現座標値を1ステップ前の座標にコピー

float4 PosCopy_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos = tex2D(CoordSmp, texCoord);
   return Pos;
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // 粒子の乗算色
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
   VS_OUTPUT2 Out;

   int Index0 = round( Pos.z * 100.0f );
   Pos.z = 0.0f;
   int i0 = Index0 / 1024;
   int i = i0 * 8;
   int j = Index0 % 1024;
   float2 texCoord = float2((i0+0.5)/TEX_WIDTH, (j+0.5)/TEX_HEIGHT);

   // 粒子の座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 1));

   // 粒子の大きさ
   Pos.xy *= ParticleSize * 10.0f;

   // 粒子の回転
   Pos = mul( Pos, RoundMatrix(Index0) );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 粒子の乗算色
   float alpha = step(0.01f, Pos0.w) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -Pos0.w) * AcsTr;
   alpha *= smoothstep(FloorFadeMin, FloorFadeMax, Pos0.y);
   float4 randColor = tex2Dlod(ArrangeSmp, float4((i+3+0.5)/TEX_WIDTH_A, (j+0.5)/TEX_HEIGHT, 0, 1));
   randColor = ParticleRandamColor * (randColor - 1.0f) + 1.0f;
   Out.Color = float4( ParticleColor * randColor.xyz, alpha );

   // テクスチャ座標
   float LType = (float)floor( Color2Float(i+5, j) * (float)TexTypeCount );
   Tex.x = (Tex.x +  LType) / (float)TexTypeCount;
   Out.Tex = Tex;

   return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
   float4 Color = tex2D( ParticleSamp, IN.Tex );
   Color *= IN.Color;
   return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique MainTec1 < string MMDPass = "object";
   string Script = 
       "RenderColorTarget0=CoordTexOld;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=PosCopy;"
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdatePos;"
       "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdateVelocity;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
           "Pass=DrawObject;";
>{
    pass PosCopy < string Script = "Draw=Buffer;";>{
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosCopy_PS();
    }
   pass UpdatePos < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdatePos_PS();
   }
   pass UpdateVelocity < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_3_0 Common_VS();
       PixelShader  = compile ps_3_0 UpdateVelocity_PS();
   }
   pass DrawObject {
       ZENABLE = TRUE;
       ZWRITEENABLE = FALSE;
       AlphaBlendEnable = TRUE;
       CullMode = NONE;
       VertexShader = compile vs_3_0 Particle_VS();
       PixelShader  = compile ps_3_0 Particle_PS();
   }
}

