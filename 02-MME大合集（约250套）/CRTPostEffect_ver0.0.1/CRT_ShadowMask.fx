///////////////////////////////////////////////////////////////////////////////
// CRT Post Effect  <ShadowMask>
// Ver 0.0.1
// @Shitaper
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////

// 背景のクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;

///////////////////////////////////////////////////////////////////////////////

// ポストエフェクトでは必ず以下の設定をする。
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture OrgMap : RENDERCOLORTARGET <
    string Descriotion = "Default Color";
    float2 ViewPortRatio = {1.0/2,1.0/2};
    // string Format = "D3DFMT_A8R8G8B8" ;
    string Format = "D3DFMT_A16B16G16R16F" ;

>;
sampler OrgSamp = sampler_state {
    texture = <OrgMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};



texture GaussianMap1 : RENDERCOLORTARGET <
    string Descriotion = "Gaussian";
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D3DFMT_A8R8G8B8" ;

>;
sampler GaussianSamp1  = sampler_state {
    texture = <GaussianMap1 >;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


texture GaussianMap2 : RENDERCOLORTARGET <
    string Descriotion = "Gaussian";
    float2 ViewPortRatio = {1.0/2,1.0/2};
    string Format = "D3DFMT_A8R8G8B8" ;

>;
sampler GaussianSamp2  = sampler_state {
    texture = <GaussianMap2 >;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


texture GaussianMap3 : RENDERCOLORTARGET <
    string Descriotion = "Gaussian";
    float2 ViewPortRatio = {1.0/4,1.0/4};
    string Format = "D3DFMT_A8R8G8B8" ;

>;
sampler GaussianSamp3  = sampler_state {
    texture = <GaussianMap3 >;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


texture CRTColorMap : RENDERCOLORTARGET <
    string Descriotion = "CRT";
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D3DFMT_A8R8G8B8" ;

>;
sampler CRTColorSmap  = sampler_state {
    texture = <CRTColorMap >;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};


//Color Tex
#define COLOR_PATH "./image/ShadowMask.PNG"
texture2D ColorTex < string ResourceName = COLOR_PATH; >;
sampler ColorSampler = sampler_state {
texture = <ColorTex>;
MINFILTER = LINEAR;
MAGFILTER = LINEAR;
MIPFILTER = NONE;
ADDRESSU  = WRAP;
ADDRESSV  = WRAP;
};



// 深度バッファ
texture DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
>;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

// 半ピクセル
static float2 ViewportOffset = (float2(1.0,1.0)/ViewportSize);

// ピクセルサイズ
static float2 PIXELSIZE = (float2(1.0,1.0)/ViewportSize);

// CRTサイズ
static float2 CRTSIZE = (ViewportSize/float2(360,240));


struct VS_OUTPUT {
    float4 Pos          : POSITION;
    float2 Tex          : TEXCOORD0;
};

///////////////////////////////////////////////////////////////////////////////
// シェーダ

VS_OUTPUT VS_DrawBuffer( float4 Pos : POSITION, float4 Tex : TEXCOORD0){
    VS_OUTPUT Out;

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

VS_OUTPUT VS_Gaussian( float4 Pos : POSITION, float4 Tex : TEXCOORD0){
    VS_OUTPUT Out;

    Out.Pos = Pos;
    Out.Tex = Tex;

    return Out;
}

float4 PS_DrawBuffer(float2 Tex: TEXCOORD0) : COLOR
{
    float4 Color;

    Color = tex2D( CRTColorSmap, Tex);
    // Color = 1-((1-Color)*(1-tex2D( GaussianSamp1, Tex )));
    Color = 1-pow((1-Color)*(1-tex2D( GaussianSamp2, Tex )),1.8)*1.3;
    Color = 1-pow((1-Color)*(1-tex2D( GaussianSamp3, Tex )),2.2);
    return Color;

}


float4 PS_Gaussian1(float2 Tex: TEXCOORD0, float4 TexColor : TEXCOORD1) : COLOR
{
    float Sample = 2;
    float pix = PIXELSIZE * Sample;
    float4 Color = tex2D( CRTColorSmap, Tex );

    Color = tex2D( CRTColorSmap, Tex ) * 4;
    Color += tex2D( CRTColorSmap, Tex + float2(0 * pix, 1 * pix)) * 2;
    Color += tex2D( CRTColorSmap, Tex + float2(1 * pix, 0 * pix)) * 2;
    Color += tex2D( CRTColorSmap, Tex + float2(0 * pix, -1 * pix)) * 2;
    Color += tex2D( CRTColorSmap, Tex + float2(-1 * pix, 0 * pix)) * 2;
    Color += tex2D( CRTColorSmap, Tex + float2(1 * pix, 1 * pix));
    Color += tex2D( CRTColorSmap, Tex + float2(1 * pix, -1 * pix));
    Color += tex2D( CRTColorSmap, Tex + float2(-1 * pix, 1 * pix));
    Color += tex2D( CRTColorSmap, Tex + float2(-1 * pix, -1 * pix));

    Color = Color / 16;
    return Color;

}
float4 PS_Gaussian2(float2 Tex: TEXCOORD0, float4 TexColor : TEXCOORD1) : COLOR
{
    float Sample = 4;
    float pix = PIXELSIZE * Sample;
    float4 Color = tex2D( GaussianSamp1, Tex );
    Color = tex2D( GaussianSamp1, Tex ) * 4;
    Color += tex2D( GaussianSamp1, Tex + float2(0 * pix, 1 * pix)) * 2;
    Color += tex2D( GaussianSamp1, Tex + float2(1 * pix, 0 * pix)) * 2;
    Color += tex2D( GaussianSamp1, Tex + float2(0 * pix, -1 * pix)) * 2;
    Color += tex2D( GaussianSamp1, Tex + float2(-1 * pix, 0 * pix)) * 2;
    Color += tex2D( GaussianSamp1, Tex + float2(1 * pix, 1 * pix));
    Color += tex2D( GaussianSamp1, Tex + float2(1 * pix, -1 * pix));
    Color += tex2D( GaussianSamp1, Tex + float2(-1 * pix, 1 * pix));
    Color += tex2D( GaussianSamp1, Tex + float2(-1 * pix, -1 * pix));

    Color = Color / 16;
    return Color;

}
float4 PS_Gaussian3(float2 Tex: TEXCOORD0, float4 TexColor : TEXCOORD1) : COLOR
{
    float Sample = 8;
    float pix = PIXELSIZE * Sample;
    float4 Color = tex2D( GaussianSamp2, Tex );
    Color = tex2D( GaussianSamp2, Tex ) * 4;
    Color += tex2D( GaussianSamp2, Tex + float2(0 * pix, 1 * pix)) * 2;
    Color += tex2D( GaussianSamp2, Tex + float2(1 * pix, 0 * pix)) * 2;
    Color += tex2D( GaussianSamp2, Tex + float2(0 * pix, -1 * pix)) * 2;
    Color += tex2D( GaussianSamp2, Tex + float2(-1 * pix, 0 * pix)) * 2;
    Color += tex2D( GaussianSamp2, Tex + float2(1 * pix, 1 * pix));
    Color += tex2D( GaussianSamp2, Tex + float2(1 * pix, -1 * pix));
    Color += tex2D( GaussianSamp2, Tex + float2(-1 * pix, 1 * pix));
    Color += tex2D( GaussianSamp2, Tex + float2(-1 * pix, -1 * pix));

    Color = Color / 16;
    return Color;

}


float4 PS_CRT(float2 Tex: TEXCOORD0, float4 TexColor : TEXCOORD1) : COLOR
{
    float4 Color;
    float2 CRTtex;
    CRTtex.x = Tex.x * CRTSIZE.x;
    CRTtex.y = Tex.y * CRTSIZE.y;

    Color = tex2D( OrgSamp, Tex );
    Color *= tex2D( ColorSampler, CRTtex );

    return Color;

}


///////////////////////////////////////////////////////////////////////////////

technique PostEffect <
    string Script =
        "RenderColorTarget0=OrgMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"

        "RenderColorTarget0=CRTColorMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "pass=CRTBuffer;"


        "RenderColorTarget0=GaussianMap1;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "pass=GaussianBuffer1;"

        "RenderColorTarget0=GaussianMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "pass=GaussianBuffer2;"

        "RenderColorTarget0=GaussianMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "pass=GaussianBuffer3;"

        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Pass=DrawBuffer;"
    ;
> {
    pass DrawBuffer < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_DrawBuffer();
        PixelShader  = compile ps_2_0 PS_DrawBuffer();
    }
    pass CRTBuffer < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Gaussian();
        PixelShader  = compile ps_2_0 PS_CRT();
    }
    pass GaussianBuffer1 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Gaussian();
        PixelShader  = compile ps_2_0 PS_Gaussian1();
    }
    pass GaussianBuffer2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Gaussian();
        PixelShader  = compile ps_2_0 PS_Gaussian2();
    }
    pass GaussianBuffer3 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_Gaussian();
        PixelShader  = compile ps_2_0 PS_Gaussian3();
    }
}
///////////////////////////////////////////////////////////////////////////////
// EOF
///////////////////////////////////////////////////////////////////////////////






