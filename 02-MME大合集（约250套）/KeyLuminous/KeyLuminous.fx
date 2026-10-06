////////////////////////////////////////////////////////////////////////////////////////////////

// ぼかし範囲
//  *サンプリング数は固定のため、大きくしすぎると縞が出ます
#define EXTENT_S 0.004 //にじみ
#define EXTENT_G 0.006 //ガウス

//キーカラー
const float4 Key_Color1 = { 1.0, 0.0, 1.0, 1.0};
const float4 Key_Color2 = { 0.0, 0.0, 1.0, 1.0};
//キーカラー認識閾値
#define KEY_THRESHOLD   0.3

//コア色および発光色
const float4 Core_Color1     = {1.0, 1.0, 0.3, 1.0};
const float4 Emittion_Color1 = {0.8, 0.5, 0.3, 1.0};

const float4 Core_Color2     = {1.0, 0.8, 1.0, 1.0};
const float4 Emittion_Color2 = {0.2, 0.4, 1.0, 1.0};

//エフェクト強度
#define STRENGTH_A 1.5
#define STRENGTH_B 1.5




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

const float4 Color_Black = {0,0,0,1};
const float4 Color_White = {1,1,1,1};


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float2 SampStep = (float2(EXTENT_G,EXTENT_G)/ViewportSize*ViewportSize.y);
static float2 SampStep2 = (float2(EXTENT_S,EXTENT_S)/ViewportSize*ViewportSize.y);


// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
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
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 放射光を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
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

bool ColorMuch(float4 color1, float4 key){
	float4 s = color1 - key;
    return (length(s.rgb) <= KEY_THRESHOLD);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// キーイング

struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passKey( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    
    return Out;
}

float4 PS_passKey( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color = tex2D( ScnSamp, Tex );
    
    //Color = ColorMuch(Color, Key_Color1) ? Core_Color1 : Color_Black;
    Color = ColorMuch(Color, Key_Color1) ? (Emittion_Color1) : 
           (ColorMuch(Color, Key_Color2) ? (Emittion_Color2) : Color_Black);
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向にじみ

VS_OUTPUT VS_passSX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    
    return Out;
}


float4 PS_passSX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    
    Color = tex2D( ScnSamp2, Tex );
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp2, Tex+float2(SampStep2.x   ,0)));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp2, Tex+float2(SampStep2.x*2 ,0)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp2, Tex+float2(SampStep2.x*3 ,0)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp2, Tex+float2(SampStep2.x*4 ,0)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp2, Tex+float2(SampStep2.x*5 ,0)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp2, Tex+float2(SampStep2.x*6 ,0)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp2, Tex+float2(SampStep2.x*7 ,0)));
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp2, Tex-float2(SampStep2.x   ,0)));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp2, Tex-float2(SampStep2.x*2 ,0)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp2, Tex-float2(SampStep2.x*3 ,0)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp2, Tex-float2(SampStep2.x*4 ,0)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp2, Tex-float2(SampStep2.x*5 ,0)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp2, Tex-float2(SampStep2.x*6 ,0)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp2, Tex-float2(SampStep2.x*7 ,0)));
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向にじみ

VS_OUTPUT VS_passSY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    
    return Out;
}

float4 PS_passSY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    
    Color = tex2D( ScnSamp3, Tex );
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, SampStep2.y  )));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, SampStep2.y*2)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, SampStep2.y*3)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, SampStep2.y*4)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, SampStep2.y*5)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, SampStep2.y*6)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp3, Tex+float2(0, SampStep2.y*7)));
    
    Color = max(Color, (7.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, SampStep2.y  )));
    Color = max(Color, (6.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, SampStep2.y*2)));
    Color = max(Color, (5.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, SampStep2.y*3)));
    Color = max(Color, (4.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, SampStep2.y*4)));
    Color = max(Color, (3.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, SampStep2.y*5)));
    Color = max(Color, (2.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, SampStep2.y*6)));
    Color = max(Color, (1.0/8.0) * tex2D( ScnSamp3, Tex-float2(0, SampStep2.y*7)));
    
    //Color *= 11;
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    
    return Out;
}


float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
    
    Color  = WT_0 *   tex2D( ScnSamp2, Tex );
    Color.rgb *= STRENGTH_A;
    
    Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x  ,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x  ,0) ) );
    Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*2,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*2,0) ) );
    Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*3,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*3,0) ) );
    Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*4,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*4,0) ) );
    Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*5,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*5,0) ) );
    Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*6,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*6,0) ) );
    Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(SampStep.x*7,0) ) + tex2D( ScnSamp2, Tex-float2(SampStep.x*7,0) ) );
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    
    Color  = WT_0 *   tex2D( ScnSamp3, Tex );
    Color += WT_1 * ( tex2D( ScnSamp3, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSamp3, Tex-float2(0,SampStep.y  ) ) );
    Color += WT_2 * ( tex2D( ScnSamp3, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSamp3, Tex-float2(0,SampStep.y*2) ) );
    Color += WT_3 * ( tex2D( ScnSamp3, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSamp3, Tex-float2(0,SampStep.y*3) ) );
    Color += WT_4 * ( tex2D( ScnSamp3, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSamp3, Tex-float2(0,SampStep.y*4) ) );
    Color += WT_5 * ( tex2D( ScnSamp3, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSamp3, Tex-float2(0,SampStep.y*5) ) );
    Color += WT_6 * ( tex2D( ScnSamp3, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSamp3, Tex-float2(0,SampStep.y*6) ) );
    Color += WT_7 * ( tex2D( ScnSamp3, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSamp3, Tex-float2(0,SampStep.y*7) ) );
    
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// 合成

VS_OUTPUT VS_passMix( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y);
    
    return Out;
}

float4 PS_passMix(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
    float4 Emission;
    
    Color = tex2D( ScnSamp, Tex );
    //Color = ColorMuch(Color, Key_Color1) ? Core_Color1 : Color;
    Color = ColorMuch(Color, Key_Color1) ? (Core_Color1) : 
           (ColorMuch(Color, Key_Color2) ? (Core_Color2) : Color);
    
    
    Emission = tex2D( ScnSamp2, Tex );
    //Emission *= Emittion_Color1;
    Emission.rgb *= STRENGTH_B;
    
    Color.rgb += Emission.rgb;
    Color.a = 1;
    
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////

technique KeyLuminous <
    string Script = 
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Keying;"
        
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Spread_X;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Spread_Y;"
        
        "RenderColorTarget0=ScnMap3;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Gaussian_X;"
        
        "RenderColorTarget0=ScnMap2;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Gaussian_Y;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=Mix;"
    ;
    
> {
    pass Keying < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passKey();
        PixelShader  = compile ps_2_0 PS_passKey();
    }
    pass Spread_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passSX();
        PixelShader  = compile ps_2_0 PS_passSX();
    }
    pass Spread_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passSY();
        PixelShader  = compile ps_2_0 PS_passSY();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
    pass Mix < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passMix();
        PixelShader  = compile ps_2_0 PS_passMix();
    }
    
}
////////////////////////////////////////////////////////////////////////////////////////////////
