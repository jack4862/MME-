////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ActiveParticleR.fx ver0.0.1 オブジェクトが移動している時だけテクスチャ粒子を放出します(3D回転あり)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define TexFile  "sample2.png"     // 粒子に貼り付けるテクスチャファイル名
int TexTypeCount = 1;              // テクスチャ種類数
float3 ParticleColor = {1.0, 1.0, 1.0}; // テクスチャの乗算色(RBG)
float ParticleRandamColor = 0.0;   // 粒子色のばらつき度(0.0～1.0)
float ParticleSize = 1.0;          // 粒子大きさ
float ParticleSizeRandam = 0.2;    // 粒子サイズばらつき度(0.0～1.0)
float ParticleSpeed = 1.5;         // 粒子スピード
float ParticleRotSpeed = 2.0;      // 粒子回転スピード
float ParticleInitPos = 1.0;       // 粒子発生時の相対位置(大きくすると粒子の配置がばらつきます)
float ParticleLife = 2.0;          // 粒子の寿命(秒)
float ParticleDecrement = 0.7;     // 粒子が消失を開始する時間(ParticleLifeとの比)
float CoefProbable = 0.0004;       // オブジェクト移動量に対する粒子発生度(大きくすると粒子が出やすくなる)
float ObjVelocityRate = 1.5;       // オブジェクト移動方向に対する粒子速度依存度


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言
#define ArrangeFileName "Arrange.png" // 配置･乱数情報ファイル名
#define TEX_WIDTH_A  32   // 配置･乱数情報テクスチャピクセル幅
#define TEX_WIDTH     4   // 座標情報テクスチャピクセル幅
#define TEX_HEIGHT 1024   // 配置･乱数情報テクスチャピクセル高さ

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

float time : TIME;
float elapsed_time : ELAPSEDTIME;

// 座標変換行列
float4x4 WorldMatrix          : WORLD;
float4x4 ViewProjMatrix       : VIEWPROJECTION;

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

// 粒子速度記録用
texture VelocityTex : RENDERCOLORTARGET
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler VelocitySmp : register(s5) = sampler_state
{
   Texture = <VelocityTex>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
    MinFilter = NONE;
    MagFilter = NONE;
    MipFilter = NONE;
};

// オブジェクトのワールド座標記録用
texture WorldCoord : RENDERCOLORTARGET
<
   int Width=1;
   int Height=1;
   string Format="A32B32G32R32F";
>;
sampler WorldCoordSmp = sampler_state
{
   Texture = <WorldCoord>;
   AddressU  = CLAMP;
   AddressV = CLAMP;
   MinFilter = NONE;
   MagFilter = NONE;
   MipFilter = NONE;
};
texture WorldCoordDepthBuffer : RenderDepthStencilTarget <
   int Width=1;
   int Height=1;
    string Format = "D24S8";
>;

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
   float rotX = 0.8*ParticleRotSpeed * time + (float)index * 37.0f;
   float rotY = ParticleRotSpeed * time + (float)index * 28.0f;
   float rotZ = 1.2*ParticleRotSpeed * time + (float)index * 19.0f;

   float sinx = sin(rotX);
   float cosx = cos(rotX);
   float siny = sin(rotY);
   float cosy = cos(rotY);
   float sinz = sin(rotZ);
   float cosz = cos(rotZ);

/*
   float4x4 rMat = { cosz, sinz, 0, 0.0f,
                    -sinz, cosz, 0, 0.0f,
                     0,    0,    1, 0.0f,
                     0.0f, 0.0f, 0.0f, 1.0f };
*/
   float4x4 rMat = { cosz*cosy+sinx*siny*sinz, cosx*sinz, -siny*cosz+sinx*cosy*sinz, 0.0f,
                    -cosy*sinz+sinx*siny*cosz, cosx*cosz,  siny*sinz+sinx*cosy*cosz, 0.0f,
                     cosx*siny,               -sinx,       cosx*cosy,                0.0f,
                     0.0f,                     0.0f,       0.0f,                     1.0f };

   return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
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

// 粒子の発生・座標計算(xyz:座標,w:経過時間)
float4 UpdatePos_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos = tex2D(CoordSmp, texCoord);

   if(Pos.w < 0.01f){
      // 未発生粒子の中から移動距離に応じて新たに粒子を発生させる
      float4 WPos0 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
      float3 WPos1 = WorldMatrix._41_42_43;
      Pos.xyz = lerp(WPos0.xyz, WPos1, texCoord.y); // 起点座標
      int i = floor( texCoord.x*TEX_WIDTH ) * 8;
      int j = floor( texCoord.y*TEX_HEIGHT );
      float probable = length( WPos1 - WPos0.xyz )*CoefProbable * AcsSi*0.1f;
      float probable0 = Color2FloatPS(i+7, j);
      if(WPos0.w<probable0 && probable0<WPos0.w+probable){
         Pos.w = 0.011f;  // Pos.w>0.01で粒子発生
      }
   }else{
      // すでに発生している粒子は経過時間を進める
      Pos.w += elapsed_time;
      Pos.w *= step(Pos.w, ParticleLife); // 指定時間を超えると0
   }

   return Pos;
}

// 粒子の速度計算
float4 UpdateVelocity_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // 粒子の座標
   float4 Pos0 = tex2D(CoordSmp, texCoord);

   // 粒子の速度
   float4 Vel = tex2D(VelocitySmp, texCoord);

   if(Pos0.w < 0.0111f){
      // 発生したての粒子のみ書き換える
      int i = floor( texCoord.x*TEX_WIDTH ) * 8;
      int j = floor( texCoord.y*TEX_HEIGHT );
      float3 pVel = float3(Color2FloatPS(i, j), Color2FloatPS(i+1, j), Color2FloatPS(i+2, j));
      float4 WPos0 = tex2D(WorldCoordSmp, float2(0.5f, 0.5f));
      float3 WPos1 = WorldMatrix._41_42_43;
      float3 wVel = normalize(WPos1-Pos0.xyz)*ObjVelocityRate; // オブジェクト移動方向を付加する
      Vel = float4( wVel+pVel, 1.0f )  ;
   }

   return Vel;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクトのワールド座標記録
VS_OUTPUT WorldCoord_VS(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.texCoord = float2(0.5f, 0.5f);

    return Out;
}

float4 WorldCoord_PS(float2 Tex: TEXCOORD0) : COLOR
{
   // オブジェクトのワールド座標
   float4 Pos0 = tex2D(WorldCoordSmp, Tex);
   float3 Pos1 = WorldMatrix._41_42_43;

   // 次発生粒子の起点
   float probable = length( Pos1 - Pos0.xyz )*CoefProbable * AcsSi*0.1f;
   float w = Pos0.w + probable;
   w *= step(w, 1.0f);
   if(time < 0.001f) w = 0.0;

   float4 Pos = float4(WorldMatrix._41_42_43, w);

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

   // 粒子の基点座標
   float4 Pos0 = tex2Dlod(CoordSmp, float4(texCoord, 0, 1));

   // 粒子の速度ベクトル
   float3 Vel = tex2Dlod(VelocitySmp, float4(texCoord, 0, 1));

   // 粒子の大きさ
   Pos.xy *= (1.0f + ParticleSizeRandam * (2.0f*Color2Float(i+4, j)-1.0f)) * ParticleSize * 10.0f;

   // 粒子の回転
   Pos = mul( Pos, RoundMatrix(Index0) );

   // 粒子のワールド座標
   Pos.xyz += Pos0.xyz + Vel * ( ParticleInitPos + ParticleSpeed * Pos0.w );
   Pos.w = 1.0f;

   // カメラ視点のビュー射影変換
   Out.Pos = mul( Pos, ViewProjMatrix );

   // 経過時間に対する粒子透過度
   float alpha = min( Pos0.w*3.0f, smoothstep(-ParticleLife, -ParticleLife*ParticleDecrement, -Pos0.w) );
   alpha *= step(0.01f, Pos0.w) * AcsTr;

   // 粒子の乗算色
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
       "RenderColorTarget0=CoordTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdatePos;"
       "RenderColorTarget0=VelocityTex;"
	    "RenderDepthStencilTarget=CoordDepthBuffer;"
	    "Pass=UpdateVelocity;"
       "RenderColorTarget0=WorldCoord;"
           "RenderDepthStencilTarget=WorldCoordDepthBuffer;"
           "Pass=UpdateWorldCoord;"
       "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
           "Pass=DrawObject;";
>{
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
   pass UpdateWorldCoord < string Script= "Draw=Buffer;"; > {
       ALPHABLENDENABLE = FALSE;
       ALPHATESTENABLE = FALSE;
       VertexShader = compile vs_2_0 WorldCoord_VS();
       PixelShader  = compile ps_2_0 WorldCoord_PS();
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

