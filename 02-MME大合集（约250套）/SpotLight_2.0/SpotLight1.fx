////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SpotLight.fx Shadow Edition ver2.0
//  作成: そぼろ
//
////////////////////////////////////////////////////////////////////////////////////////////////

//独自セルフシャドウZバッファのサイズ
#define SHADOWBUFSIZE   1024

//ミップマップ使用可能か
#define MIPMAP_ENABLE  1

//シャドウバッファ・アンチエイリアスの有無
#define SHADOWBUF_AA  false

///////////////////////////////////////////////////////////////////////////////////////////////
// スポットライト反射光描画先

texture SpotLightDraw1: OFFSCREENRENDERTARGET <
    string Description = "SpotLightDrawRenderTarget for SpotLight1.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 1 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string DefaultEffect = 
        "self = hide;"
        "SpotLightModel* = SpotLight1_Object.fx;"
        "SpotLight* = hide;"
        
        "* = SpotLight1_Object.fx;" 
    ;
>;

sampler SpotLightView = sampler_state {
    texture = <SpotLightDraw1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 独自セルフシャドウ用マップ

shared texture SpotLightShadowDraw1: OFFSCREENRENDERTARGET <
    string Description = "SpotLightShadowRenderTarget for SpotLight1.fx";
    string Format = "D3DFMT_G16R16";
    float Width = SHADOWBUFSIZE;
    float Height = SHADOWBUFSIZE;
    float4 ClearColor = { 1, 1, 1, 1 };
    float ClearDepth = 1.0;
#if MIPMAP_ENABLE!=0
    int Miplevels = 0; //ミップマップ有効
#endif
    bool AntiAlias = SHADOWBUF_AA; //アンチエイリアス設定
    string DefaultEffect = 
        "self = hide;"
        "SpotLight* = hide;"
        
        "* = SpotLight1_ShadowZBuf.fx;" 
    ;
>;


////////////////////////////////////////////////////////////////////////////////////////////////

const float4 Color_Black = {0,0,0,1};
const float4 Color_White = {1,1,1,1};


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


////////////////////////////////////////////////////////////////////////////////////////////////
//共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ピクセルシェーダ

float4 PS_copy( float2 Tex: TEXCOORD0 ) : COLOR {
    float4 color = tex2D( SpotLightView, Tex );
    
    return color;
    
}


////////////////////////////////////////////////////////////////////////////////////////////////
//テクニック

technique SpotLight <
    string Script = 
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
        
        //"Pass=CopyPass;"
        "Pass=AddMix;"
        
    ;
    
> {
    
    pass CopyPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_copy();
    }
    
    pass AddMix < string Script= "Draw=Buffer;"; > {
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_copy();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////



