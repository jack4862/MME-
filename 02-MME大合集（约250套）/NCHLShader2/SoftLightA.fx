//////////////////////////////////////////////////////////////////////////////////////////
// オリジナル：Diffusion5.fx(そぼろ氏)
// 主に最終合成がソフトライトになっただけ
//////////////////////////////////////////////////////////////////////////////////////////

// ガンマ補正値みたいな何か
// 小さいと暗く、大きいと明るくなる
float gamma : CONTROLOBJECT < string name = "SoftLightA.x"; string item = "Si"; >;

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5f,0.5f)/ViewportSize);

static float2 SampStep = (float2(0.00025f,0.00025f)/ViewportSize*ViewportSize.y);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 自己乗算の結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "D3DFMT_A16B16G16R16F" ;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 共通頂点シェーダ
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
// 自己乗算

float4 PS_passSM( float2 Tex: TEXCOORD0 ) : COLOR {   
    return pow( saturate(tex2D( ScnSamp, Tex )), 10.0f/gamma);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    float step = SampStep.x;
    
    Color  = WT_0 *   tex2D( ScnSamp3, Tex );
    Color += WT_1 * ( tex2D( ScnSamp3, Tex+float2(step  ,0.0f) ) + tex2D( ScnSamp3, Tex-float2(step  ,0.0f) ) );
    Color += WT_2 * ( tex2D( ScnSamp3, Tex+float2(step*2.0f,0.0f) ) + tex2D( ScnSamp3, Tex-float2(step*2.0f,0.0f) ) );
    Color += WT_3 * ( tex2D( ScnSamp3, Tex+float2(step*3.0f,0.0f) ) + tex2D( ScnSamp3, Tex-float2(step*3.0f,0.0f) ) );
    Color += WT_4 * ( tex2D( ScnSamp3, Tex+float2(step*4.0f,0.0f) ) + tex2D( ScnSamp3, Tex-float2(step*4.0f,0.0f) ) );
    Color += WT_5 * ( tex2D( ScnSamp3, Tex+float2(step*5.0f,0.0f) ) + tex2D( ScnSamp3, Tex-float2(step*5.0f,0.0f) ) );
    Color += WT_6 * ( tex2D( ScnSamp3, Tex+float2(step*6.0f,0.0f) ) + tex2D( ScnSamp3, Tex-float2(step*6.0f,0.0f) ) );
    Color += WT_7 * ( tex2D( ScnSamp3, Tex+float2(step*7.0f,0.0f) ) + tex2D( ScnSamp3, Tex-float2(step*7.0f,0.0f) ) );
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし + 合成

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float4 ColorOrg;
    
    float step = SampStep.y;
    
    Color  = WT_0 *   tex2D( ScnSamp2, Tex );
    Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(0.0f,step  ) ) + tex2D( ScnSamp2, Tex-float2(0.0f,step  ) ) );
    Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(0.0f,step*2.0f) ) + tex2D( ScnSamp2, Tex-float2(0.0f,step*2.0f) ) );
    Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(0.0f,step*3.0f) ) + tex2D( ScnSamp2, Tex-float2(0.0f,step*3.0f) ) );
    Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(0.0f,step*4.0f) ) + tex2D( ScnSamp2, Tex-float2(0.0f,step*4.0f) ) );
    Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(0.0f,step*5.0f) ) + tex2D( ScnSamp2, Tex-float2(0.0f,step*5.0f) ) );
    Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(0.0f,step*6.0f) ) + tex2D( ScnSamp2, Tex-float2(0.0f,step*6.0f) ) );
    Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(0.0f,step*7.0f) ) + tex2D( ScnSamp2, Tex-float2(0.0f,step*7.0f) ) );

    ColorOrg = saturate(tex2D( ScnSamp, Tex ));

    // オリジナルと合成
    float4 ColorS = Color<0.5f ? ColorOrg+(ColorOrg-(ColorOrg*ColorOrg))*(2.0f*Color-1.0f)
          : ColorOrg<=(32.0f/255.0f)
          ? ColorOrg+(ColorOrg-(ColorOrg*ColorOrg))*(2.0f*Color-1.0f)*(3.0f-8.0f*ColorOrg) 
          : ColorOrg+(sqrt(ColorOrg)-ColorOrg)*(2.0f*Color-1.0f);
    Color = ColorS > ColorOrg ? lerp(ColorOrg,ColorS,ColorS) : ColorS;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique Diffusion <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
     
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=SelfMultiply;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_X;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Gaussian_Y;"
    ;
    
> {
    pass SelfMultiply < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passSM();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passDraw();
        PixelShader  = compile ps_2_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
