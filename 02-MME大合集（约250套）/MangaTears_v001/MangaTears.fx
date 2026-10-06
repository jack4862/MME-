////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MangaTears.fx ver0.0.1 漫画風涙パーティクルエフェクト(CannonParticle.fx改変)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define TexFile  "Particle.png"       // 粒子に貼り付けるテクスチャファイル名
float3 ParticleColorS = {0.7, 0.9, 1.0}; // 粒子発生時のテクスチャ乗算色(RBG)
float3 ParticleColorE = {1.0, 1.0, 1.0}; // 粒子消失時のテクスチャ乗算色(RBG)
float ParticleSize = 0.07;         // 粒子大きさ
float ParticleSpeedMin = 12.0;     // 粒子初速度最小値
float ParticleSpeedMax = 15.0;     // 粒子初速度最大値
float ParticleInitPos = 0.3;       // 粒子発生時の分散位置(大きくすると粒子の初期配置が広くなります)
float ParticleLife = 3.0;          // 粒子の寿命(秒)
float ParticleDecrement = 0.9;     // 粒子が消失を開始する時間(0.0～1.0:ParticleLifeとの比)
float DiffusionAngle = 5.0;        // 放射拡散角(0.0～180.0)
float GravFactor = 25.0;           // 重力定数
float ResistFactor = 1.0;          // 速度抵抗力
float CoefRebound = 0.4;           // 地面のはね返り係数
float ReboundNoise = 7.0;          // 地面はね返り後の分散度

float3 OffsetPos = {0.0, 0.2, -1.0};  // 粒子発生位置の補正値(両目に付ける場合はXは0にしてMMDで設定)
float3 StartDirect = {1.0, 0.8, 0.0}; // 粒子放出方向ベクトル

// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
#define ArrangeFileName "Arrange.png" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A   8   // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH     1   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT 1024   // 配置･乱数情報テクスチャピクセル高さ

#define PAI 3.14159265f   // π

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

static float diffD = radians( DiffusionAngle );
static float3 sDirect = normalize( StartDirect );

float time : TIME;
float elapsed_time : ELAPSEDTIME;
static float Dt = (elapsed_time < 0.2f) ? clamp(elapsed_time, 0.001f, 1.0f/15.0f) : 1.0f/30.0f;

// 1フレーム当たりの粒子発生確率
static float probable = 0.60f * (Dt / ParticleLife) * AcsSi*0.1f; 

// 座標変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewProjMatrix : VIEWPROJECTION;
float4x4 ViewMatrixInverse    : VIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(ViewMatrixInverse[0].xyz),
    normalize(ViewMatrixInverse[1].xyz),
    normalize(ViewMatrixInverse[2].xyz),
};

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
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

// クォータニオンの積算
float4 MulQuat(float4 q1, float4 q2)
{
   return float4(cross(q1.xyz, q2.xyz)+q1.xyz*q2.w+q2.xyz*q1.w, q1.w*q2.w-dot(q1.xyz, q2.xyz));
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

   if(time < 0.001f) Pos.w = 0.0f;
   if(Pos.w < 0.001f){
      // 未発生粒子の中から新たに粒子を発生させる
      float4 WPos = float4(Color2FloatPS(i, j), Color2FloatPS(i+1, j), Color2FloatPS(i+2, j), 1.0f);
      float3 WPos0 = WorldMatrix._41_42_43;
      WPos.xyz *= ParticleInitPos * 0.1f;
      WPos = mul( WPos, WorldMatrix );
      Pos.xyz = ((WPos.xyz / WPos.w) - WPos0) / AcsSi * 10.0f + WPos0 + OffsetPos;  // 発生初期座標
      float probable0 = Color2FloatPS(i+6, j);
      if(Vel.w<probable0 && probable0<Vel.w+probable){
         Pos.w = 0.0011f;  // Pos.w>0.001で粒子発生
      }
   }else{
      // 発生粒子は疑似物理計算で座標を更新
      // 1ステップ前の位置
      float4 Pos0 = tex2D(CoordSmpOld, texCoord);

      // 加速度計算(速度抵抗力+重力)
      float3 Accel = -Vel.xyz * ResistFactor + float3(0.0f, -GravFactor, 0.0f);

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

   int i = floor( texCoord.x*TEX_WIDTH ) * 8;
   int j = floor( texCoord.y*TEX_HEIGHT );

   if(Pos.w < 0.0012f){
      // 発生したての粒子に初速度与える
      float time1 = time + 100.0f;
      float s = sin( lerp(0.0f, diffD, frac(Color2FloatPS(i+4, j)*time1)) );
      float t = lerp(-PAI, PAI, frac(Color2FloatPS(i+5, j)*time1));
      float3 vec  = float3( s*cos(t), 1.0f-s, s*sin(t) );
      float3 v = cross(sDirect, float3(0.0f, 1.0f, 0.0f) ); // 放出方向への回転軸
      float rot = acos( dot(float3(0.0f, 1.0f, 0.0f), sDirect) ); // 放出方向への回転角
      float sinHD = sin(0.5f * rot);
      float cosHD = cos(0.5f * rot);
      float4 q1 = float4(v*sinHD, cosHD);
      float4 q2 = float4(-v*sinHD, cosHD);
      vec = MulQuat( MulQuat(q2, float4(vec, 0.0f)), q1).xyz; // 放出方向への回転(クォータニオン)

      Vel.xyz = normalize( mul( vec, (float3x3)WorldMatrix ) )
                * lerp(ParticleSpeedMin, ParticleSpeedMax, frac(Color2FloatPS(i+6, j)*time1));
   }else{
      // 粒子の速度計算
      float4 Pos0 = tex2D(CoordSmpOld, texCoord);
      Vel.xyz = ( Pos.xyz - Pos0.xyz ) / Dt;
      if(Pos.y < 0.2f) Vel.xyz = float3( ReboundNoise*(Color2FloatPS(i+4, j)-0.5f),
                                         CoefRebound * abs(Vel.y) * (0.5f+Color2FloatPS(i+7, j)),
                                         ReboundNoise*(Color2FloatPS(i+5, j)-0.5f) );
   }

   // 次発生粒子の起点
   Vel.w += probable;
   Vel.w *= step(Vel.w, 1.0f);
   if(time < 0.001f) Vel.w = 0.0f;

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

   // 経過時間に対する粒子拡大度
   float scale = 1.5f * sqrt(Pos0.w) + 1.0f;

   // 粒子の大きさ
   Pos.xy *= (0.5f+Color2Float(i+7, j)) * ParticleSize * scale * 10.0f;

   // 粒子の回転
   float rot = 6.18f * ( Color2Float(i+5, j) - 0.5f );
   Pos.xy = Rotation2D(Pos.xy, rot);

   // ビルボード
   Pos.xyz = mul( Pos.xyz, BillboardMatrix );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz;
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 粒子の乗算色
   float alpha = step(0.01f, Pos0.w) * smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -Pos0.w) * AcsTr;
   float3 Color = lerp(ParticleColorS, ParticleColorE, Pos0.w/ParticleLife);
   Out.Color = float4(Color, alpha);

   // テクスチャ座標
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
       VertexShader = compile vs_3_0 Particle_VS();
       PixelShader  = compile ps_3_0 Particle_PS();
   }
}

