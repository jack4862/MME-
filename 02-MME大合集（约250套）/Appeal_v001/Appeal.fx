////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Appeal.fx ver0.0.1  アピールエフェクト  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define RadiantTexFile  "shoot1.png"     // 放射光のテクスチャファイル名
float3 RadiantColor = {1.0, 1.0, 0.5};  // 放射光の乗算色(RBG)
float RadiantSizeMin = 0.2;     // 放射光最小サイズ
float RadiantSizeMax = 25.0;    // 放射光最大サイズ
float RadiantAlpha = 1.0;       // 放射光のα値

float3 KiraColor = {0.5, 1.0, 1.0};  // キラキラ粒子の乗算色(RBG)
int KiraCount = 15;             // キラキラ粒子の描画オブジェクト数
float KiraSize = 1.5;           // キラキラ粒子のサイズ
float KiraStartPos = 0.2;       // キラキラ粒子の開始位置
float KiraEndPos = 0.8;         // キラキラ粒子の終了位置
float KiraRotSpeed = 2.0;       // キラキラ粒子の回転スピード
float KiraCross = 1.0;          // キラキラ粒子の十字度(大きくすると十字が鮮明になる)
float KiraAlpha = 1.0;          // キラキラ粒子のα値

#define ParticleTexFile  "star.png"    // パーティクルに貼り付けるテクスチャファイル名
int TexTypeCount = 1;           // パーティクルのテクスチャ種類数
int ParticleCount = 19;         // パーティクルの描画オブジェクト数
float3 ParticleColor = {1.0, 0.7, 1.0};  // パーティクルの乗算色(RBG)
float ParticleSize = 2.0;       // パーティクルのサイズ
float ParticleStartPos = 0.6;   // パーティクルの開始位置
float ParticleEndPos = 0.9;     // パーティクルの終了位置
float ParticleRotSpeed = 4.0;   // パーティクルの回転スピード
float ParticleAlpha = 1.0;      //パーティクルのα値

int SeedXY = 3;         // 配置に関する乱数シード
int SeedSize = 5;       // サイズに関する乱数シード
int SeedRotSpeed = 21;  // 回転スピードに関する乱数シード
int SeedView = 11;      // フェードイン･アウトに関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

#define PAI 3.14159265f   // π

int Index;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

texture2D RadiantTex <
    string ResourceName = RadiantTexFile;
>;
sampler RadiantSamp = sampler_state {
    texture = <RadiantTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D KiraTex1 <
    string ResourceName = "kira1.png";
>;
sampler KiraSamp1 = sampler_state {
    texture = <KiraTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D KiraTex2 <
    string ResourceName = "kira2.png";
>;
sampler KiraSamp2 = sampler_state {
    texture = <KiraTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex <
    string ResourceName = ParticleTexFile;
>;
sampler ParticleSamp = sampler_state {
    texture = <ParticleTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 放射光描画
struct VS_OUTPUT
{
    float4 Pos   : POSITION;    // 射影変換座標
    float2 Tex   : TEXCOORD0;   // テクスチャ
    float4 Color : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT Radiant_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 放射光配置
    float scale = RadiantSizeMin * (1.0f - AcsTr) + RadiantSizeMax * AcsTr;
    Pos.x *= scale*ViewportSize.y/ViewportSize.x;
    Pos.y *= scale;
    Out.Pos = Pos*10;

    // テクスチャの乗算色
    float alpha = (1.0f - smoothstep(0.05f, 0.5f, abs(AcsTr - 0.5f))) * RadiantAlpha;
    Out.Color = saturate( float4(RadiantColor*alpha, 1.0f) );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Radiant_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = tex2D( RadiantSamp, IN.Tex.xy );
    Color *= IN.Color;
    return Color;
}

// テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "0"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_3_0 Radiant_VS();
        PixelShader  = compile ps_3_0 Radiant_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////
// キラキラ描画
struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT2 Kira_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // パーティクルサイズ
    float scale = KiraSize * (sin(44 * SeedSize * Index + 13) + cos(87 * SeedSize * Index + 17) + 3.0f) * 0.25f;
    Pos.xy *= scale;

    // パーティクル回転配置
    float rot = KiraRotSpeed * AcsTr;
    Pos.xy = Rotation2D( Pos.xy, rot );

    // パーティクル配置
    float r = (sin(124 * SeedXY * Index*2 + 13) + cos(235 * SeedXY * Index + 17) + 1.5f) * 0.2f;
    float s = (sin(83 * SeedXY * Index*2 + 9) + cos(91 * SeedXY * Index + 11) + 3.0f) * 0.25f;
    float2 Pos0 = float2( 0.0f, lerp(r * KiraStartPos, (r + s) * KiraEndPos, AcsTr) );
    Pos.xy += Rotation2D(Pos0, ((float)Index/(float)KiraCount)*2.0f*PAI );
    Pos.x *= ViewportSize.y/ViewportSize.x;
    Out.Pos = Pos;

    // テクスチャの乗算色
    float alpha = (1.0f - smoothstep(0.05f, 0.5f, abs(AcsTr - 0.5f))) * KiraAlpha;
    Out.Color = saturate( float4(KiraColor*alpha, 1.0f) );

    // テクスチャ座標
    float rand = (sin(47 * SeedSize * Index + 13) + cos(81 * SeedSize * Index + 17) + 3.0f) * 0.1f;
    Out.Tex = float3(Tex, 1.0f+KiraCross*rand);

    return Out;
}

// ピクセルシェーダ
float4 Kira_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float4 Color = tex2D( KiraSamp2, IN.Tex.xy );
    float2 Tex1 = (IN.Tex.xy-0.5f)*IN.Tex.z+0.5f;
    float4 Color1 = tex2D( KiraSamp1, Tex1 );
    Color += Color1;
    Color.xyz *= IN.Color.xyz*0.5f;
    return Color;
}

// テクニック
technique MainTec1 < string MMDPass = "object"; string Subset = "1";
    string Script = "LoopByCount=KiraCount;"
                    "LoopGetIndex=Index;"
                    "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_3_0 Kira_VS();
        PixelShader  = compile ps_3_0 Kira_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画

// 頂点シェーダ
VS_OUTPUT Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // パーティクルサイズ
    float scale = ParticleSize * (sin(37 * SeedSize * Index + 13) + cos(71 * SeedSize * Index + 17) + 3.0f) * 0.25f;
    Pos.xy *= scale;

    // パーティクル回転配置
    float rot = ParticleRotSpeed * (sin(53 * SeedRotSpeed * Index + 13) + cos(61 * SeedRotSpeed * Index + 17)) * AcsTr;
    Pos.xy = Rotation2D( Pos.xy, rot );

    // パーティクル配置
    float r = (sin(124 * SeedXY * Index + 13) + cos(235 * SeedXY * Index + 17) + 2.1f) * 0.25f;
    float s = (sin(83 * SeedXY * Index + 13) + cos(91 * SeedXY * Index + 17) + 3.0f) * 0.25f;
    Pos.x += lerp(r * ParticleStartPos, (r + s) * ParticleEndPos, AcsTr);
    Pos.xy = Rotation2D(Pos.xy, ((float)Index/(float)ParticleCount)*2.0f*PAI );
    Pos.x *= ViewportSize.y/ViewportSize.x;
    Out.Pos = Pos;

    // テクスチャの乗算色
    float a = (sin(47 * SeedView * Index + 13) + cos(19 * SeedView * Index + 17)) * 0.04f;
    float alpha = (1.0f - smoothstep(0.25f+a, 0.5f, abs(AcsTr - 0.5f))) * ParticleAlpha;
    Out.Color = float4(ParticleColor, alpha);

    // テクスチャ座標
    Tex.x = (Tex.x+(float)(Index%TexTypeCount)) / (float)TexTypeCount;
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = tex2D( ParticleSamp, IN.Tex );
    Color *= IN.Color;
    return Color;
}

// テクニック
technique MainTec1 < string MMDPass = "object"; string Subset = "2-";
    string Script = "LoopByCount=ParticleCount;"
                    "LoopGetIndex=Index;"
                    "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 Particle_VS();
        PixelShader  = compile ps_3_0 Particle_PS();
    }
}

