// StellaTheater.fx
// v2.0
// 非商用のみ改変・再配布可
// ぺんぎん

// スカイドームの大きさ
// 実際にはこの値の2乗になります
// 視点に対して固定なので、余り使う機会はないかも
#define STAR_DISTANCE 28.0

// 明るい星をどれくらい大きくするか
#define MAGNITUDE_POWER 0.6

// ここから下がプログラム

float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

float4   MaterialDiffuse    : DIFFUSE  < string Object = "Geometry"; >;
float3   CameraPosition     : POSITION  < string Object = "Camera"; >;
float2   ScreenSize         : VIEWPORTPIXELSIZE;
float    StarBaseSize       : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float    MagnitudeThreshold : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float    StarColor          : CONTROLOBJECT < string name = "(self)"; string item = "Z"; >;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// 星表テクスチャ
texture2D CatalogueTexture <
    string ResourceName = "catalogue.png";
>;
sampler CatalogueSampler = sampler_state {
    texture = <CatalogueTexture>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

// 星表テクスチャのサイズ
#define CATALOGUE_WIDTH  512
#define CATALOGUE_HEIGHT 1024

// 星表テクスチャから視等級を取得
// i: インデックス
float GetMagnitude(int i)
{
    int x = i / CATALOGUE_HEIGHT * 4;
    int y = i % CATALOGUE_HEIGHT;
    float4 d = tex2Dlod(CatalogueSampler, float4((x + 0.5) / CATALOGUE_WIDTH, (y + 0.5) / CATALOGUE_HEIGHT,0,1));
    float tNum = (65536 * d.x + 256 * d.y + d.z) * 255;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}
// 星表テクスチャから経度を取得
// i: インデックス
float GetLongitude(int i)
{
    int x = i / CATALOGUE_HEIGHT * 4 + 1;
    int y = i % CATALOGUE_HEIGHT;
    float4 d = tex2Dlod(CatalogueSampler, float4((x + 0.5) / CATALOGUE_WIDTH, (y + 0.5) / CATALOGUE_HEIGHT,0,1));
    float tNum = (65536 * d.x + 256 * d.y + d.z) * 255;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return -data;
}
// 星表テクスチャから緯度を取得
// i: インデックス
float GetLatitude(int i)
{
    int x = i / CATALOGUE_HEIGHT * 4 + 2;
    int y = i % CATALOGUE_HEIGHT;
    float4 d = tex2Dlod(CatalogueSampler, float4((x + 0.5) / CATALOGUE_WIDTH, (y + 0.5) / CATALOGUE_HEIGHT,0,1));
    float tNum = (65536 * d.x + 256 * d.y + d.z) * 255;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return -data;
}
// 星表テクスチャから色情報を取得
// i: インデックス
float4 GetColorCode(int i)
{
    int x = i / CATALOGUE_HEIGHT * 4 + 3;
    int y = i % CATALOGUE_HEIGHT;
    return tex2Dlod(CatalogueSampler, float4((x + 0.5) / CATALOGUE_WIDTH, (y + 0.5) / CATALOGUE_HEIGHT,0,1));
}

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float4 Color      : COLOR0;      // ディフューズ色
    float Magnitude   : COLOR1;      // 視等級
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // インデックス取得
    int idx = round(Pos.z);
    
    float longitude = GetLongitude(idx);
    float laltitude = GetLatitude(idx);
    Out.Magnitude = GetMagnitude(idx);
    float starsize = 1;
    float magnitude_threshold = MagnitudeThreshold + 3.0;
    if(Out.Magnitude < magnitude_threshold)
    {
        starsize = pow((1.5 + magnitude_threshold) - Out.Magnitude, MAGNITUDE_POWER);
    }
    starsize *= (StarBaseSize / 10 + 1.0);
    
    float4 pos = float4(0, 0, STAR_DISTANCE, 1);
    
    // 座標変換
    float4x4 matRot;
    
    // 緯度反映
    matRot[0] = float4(1,0,0,0); 
    matRot[1] = float4(0,cos(laltitude),sin(laltitude),0);
    matRot[2] = float4(0,-sin(laltitude),cos(laltitude),0);
    matRot[3] = float4(0,0,0,1); 
    
    pos = mul(pos, matRot);
    
    // 経度反映
    matRot[0] = float4(cos(longitude),0,-sin(longitude),0);
    matRot[1] = float4(0,1,0,0);
    matRot[2] = float4(sin(longitude),0,cos(longitude),0);
    matRot[3] = float4(0,0,0,1);
    
    pos = mul(pos, matRot);
    
    // カメラ視点のワールドビュー射影変換
    // 移動をキャンセルする
    matRot[0] = WorldViewProjMatrix[0];
    matRot[1] = WorldViewProjMatrix[1];
    matRot[2] = WorldViewProjMatrix[2];
    matRot[3] = float4(0,0,0,1);
    
    Out.Pos = mul( pos, matRot );
    
    Out.Pos.x += Pos.x / ScreenSize.x * Out.Pos.w * starsize;
    Out.Pos.y += Pos.y / ScreenSize.y * Out.Pos.w * starsize;
    
    // 色情報
    float4 color = GetColorCode(idx);
    Out.Color = float4(color.r,color.g,color.b,MaterialDiffuse.a);
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN) : COLOR0
{
    float4 Color = IN.Color;
    // テクスチャ適用
    Color *= tex2D( ObjTexSampler, IN.Tex );
    // 等級適用
    if(IN.Magnitude > 3)
    {
        Color.a *= pow(1.0 - IN.Magnitude / 14, 2.0);
    }
    // 色変換
    Color.r *= (1.0 - StarColor * 0.1);
    Color.g *= (1.0 - StarColor * 0.1);
    
    return Color;
}

// オブジェクト描画用テクニック（アクセサリ用）
technique RenderParticle < string Script = "Pass=DrawObject;"; >
{
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS();
        PixelShader  = compile ps_3_0 Basic_PS();
    }
}
