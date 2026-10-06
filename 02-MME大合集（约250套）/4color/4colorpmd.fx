////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ScreenTexPmd.fx ver0.0.4  テクスチャを画面サイズにスケーリングして貼り付けます(PMD版)
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define UseTex  1                   // 1:テクスチャ, 2:アニメGIF･APNG
#define TexFile  "4c.png"       // 画面に貼り付けるテクスチャファイル名(単色の場合は無視)
#define AnimeStart 0.0              // アニメGIF･APNGの場合のアニメーション開始時間(単位：秒)(アニメGIF･APNG以外では無視)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

// PMDパラメータ
float PmdAlpha : CONTROLOBJECT < string name = "4colorpmd.pmd"; string item = "透過度"; >;
float PmdRed : CONTROLOBJECT < string name = "4colorpmd.pmd"; string item = "key赤"; >;
float PmdGreen : CONTROLOBJECT < string name = "4colorpmd.pmd"; string item = "key緑"; >;
float PmdBlue : CONTROLOBJECT < string name = "4colorpmd.pmd"; string item = "key青"; >;
float PmdThres : CONTROLOBJECT < string name = "4colorpmd.pmd"; string item = "key閾値"; >;
static float Alpha = 1.0f - PmdAlpha;
static float3 ColorKey = saturate( float3(PmdRed, PmdGreen, PmdBlue) ); // カラーキーの色(RGB指定)
static float Threshold = saturate( PmdThres ) - 0.01f;                  // カラーキーの閾値

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

#if(UseTex == 1)
// 画面に貼り付けるテクスチャ
texture2D screen_tex <
    string ResourceName = TexFile;
    int MipLevels = 1;
>;
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif

#if(UseTex == 2)
// 画面に貼り付けるアニメーションテクスチャ
texture screen_tex : ANIMATEDTEXTURE <
    string ResourceName = TexFile;
    int MipLevels = 1;
    float Offset = AnimeStart;
>;
sampler TexSampler = sampler_state {
    texture = <screen_tex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
#endif


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
};

// 頂点シェーダ
VS_OUTPUT ScreenTex_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// ピクセルシェーダ
float4 ScreenTex_PS( float2 Tex :TEXCOORD0 ) : COLOR0
{
    // テクスチャ適用
    float4 Color = tex2D( TexSampler, Tex );

    // カラーキー透過
    float len = length(Color.rgb - ColorKey);
    if(len <= Threshold) Color.a = 0;

    Color.a *= Alpha;
    return Color;
}

technique MainTec < string MMDPass = "object"; > {
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        ZENABLE = false;
        VertexShader = compile vs_1_1 ScreenTex_VS();
        PixelShader  = compile ps_2_0 ScreenTex_PS();
    }
}

technique MainTecSS < string MMDPass = "object_ss"; > {
    pass DrawObject < string Script= "Draw=Buffer;"; > {
        ZENABLE = false;
        VertexShader = compile vs_1_1 ScreenTex_VS();
        PixelShader  = compile ps_2_0 ScreenTex_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
//エッジや地面影は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

