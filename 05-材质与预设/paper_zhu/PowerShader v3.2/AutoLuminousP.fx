////////////////////////////////////////////////////////////////////////////////////////////////
//
//  AutoLuminousP
//  作成: そぼろ
//  改変: 角砂糖
//
////////////////////////////////////////////////////////////////////////////////////////////////

//一方向のサンプリング数
#define AL_SAMP_NUM  8

//作業用バッファのサイズを半分にして軽くするか
// 0 : 軽くしない
// 1 : 軽くする
#define HALF_DRAW  0

//厳密アルファ出力モード
//MMD上での表示はおかしくなるが、動画・画像出力で正しいアルファ値が得られる
// 0 : オフ
// 1 : オン
#define ALPHA_OUT  0

//テクスチャフォーマット
#define AL_TEXFORMAT "D3DFMT_A16B16G16R16F"

////////////////////////////////////////////////////////////////////////////////////////////////
// ユーザーパラメータ

// 線形空間で計算を行うか
#define ENABLE_GAMMA_CORRECT 1

// ぼかし範囲
#define AL_Extent 0.03

// 白飛び係数　0～1
#define OverExposureRatio 0.85

// 弱光減衰　0～1
#define Modest 1.0

// 背景色
const float4 BackColor = float4( 0, 0, 0, 0 );


////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////
//これ以降はエフェクトの知識のある人以外は触れないこと



////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#if HALF_DRAW==0
    #define TEXSIZE1  1
    #define TEXSIZE2  0.5
    #define TEXSIZE3  0.25
    #define TEXSIZE4  0.125
    #define TEXSIZE5  0.0625
    
#else
    #define TEXSIZE1  0.5
    #define TEXSIZE2  0.25
    #define TEXSIZE3  0.125
    #define TEXSIZE4  0.0625
    #define TEXSIZE5  0.03125
    
#endif

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// パラメータ取得
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
float alpha1 : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float4x4 matWorld : CONTROLOBJECT < string name = "(self)"; >; 
static float OverLight = (matWorld._42 + 100) / 100;
static float scaling = scaling0 * 0.05 * (1.0 + matWorld._43 / 100);

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float2 OnePx = (float2(1,1)/ViewportSize);
static float2 AL_SampStepScaled = AL_Extent * float2(1/ViewportAspect, 1) * alpha1 / (float)AL_SAMP_NUM * 0.08;


////////////////////////////////////////////////////////////////////////////////////
// 深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    string Format = "D24S8";
>;
texture2D DepthBuffer2 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE2,TEXSIZE2};
    string Format = "D24S8";
>;
texture2D DepthBuffer3 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE3,TEXSIZE3};
    string Format = "D24S8";
>;
texture2D DepthBuffer4 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE4,TEXSIZE4};
    string Format = "D24S8";
>;
texture2D DepthBuffer5 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {TEXSIZE5,TEXSIZE5};
    string Format = "D24S8";
>;

///////////////////////////////////////////////////////////////////////////////////////////////

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// 高輝度部分を記録するためのレンダーターゲット
texture2D HighLight : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    int MipLevels = 0;
    string Format = AL_TEXFORMAT ;
    
>;
sampler2D HighLightView = sampler_state {
    texture = <HighLight>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Border;
    AddressV = Border;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX = sampler_state {
    texture = <ScnMapX>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut = sampler_state {
    texture = <ScnMapOut>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE2,TEXSIZE2};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX2 = sampler_state {
    texture = <ScnMapX2>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE2,TEXSIZE2};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut2 = sampler_state {
    texture = <ScnMapOut2>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE3,TEXSIZE3};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX3 = sampler_state {
    texture = <ScnMapX3>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE3,TEXSIZE3};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut3 = sampler_state {
    texture = <ScnMapOut3>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX4 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE4,TEXSIZE4};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX4 = sampler_state {
    texture = <ScnMapX4>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut4 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE4,TEXSIZE4};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut4 = sampler_state {
    texture = <ScnMapOut4>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMapX5 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE5,TEXSIZE5};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampX5 = sampler_state {
    texture = <ScnMapX5>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};

// 出力結果を記録するためのレンダーターゲット
texture2D ScnMapOut5 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {TEXSIZE5,TEXSIZE5};
    int MipLevels = 1;
    string Format = AL_TEXFORMAT ;
>;
sampler2D ScnSampOut5 = sampler_state {
    texture = <ScnMapOut5>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Point;
    AddressU  = Clamp;
    AddressV = Clamp;
};


////////////////////////////////////////////////////////////////////////////////////////////////
// ガンマ補正対応
#if defined(ENABLE_GAMMA_CORRECT) && ENABLE_GAMMA_CORRECT > 0
bool bLinearMode : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;
const float epsilon = 1.0e-6;
const float gamma = 2.2;
inline float3 Degamma(float3 col)
{
	return (!bLinearMode) ? pow(max(col,epsilon), gamma) : col;
}
inline float3 Gamma(float3 col)
{
	return (!bLinearMode) ? pow(max(col,epsilon), 1.0/gamma) : col;
}
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }
#else
inline float4 Degamma4(float4 col) { return col; }
inline float4 Gamma4(float4 col) { return col; }
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// 白とび表現関数
float4 OverExposure(float4 color){
    float4 newcolor = color;
    
    //ある色が1を超えると、他の色にあふれる
    newcolor.gb += max(color.r - 1, 0) * OverExposureRatio * float2(0.65, 0.6);
    newcolor.rb += max(color.g - 1, 0) * OverExposureRatio * float2(0.5, 0.6);
    newcolor.rg += max(color.b - 1, 0) * OverExposureRatio * float2(0.5, 0.6);
    
    #if defined(ENABLE_GAMMA_CORRECT) && ENABLE_GAMMA_CORRECT > 0
    if (!bLinearMode) newcolor = color;
    #endif
    
    return newcolor;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//トーンカーブの調整
//自分でも何がどうなっているかよくわからない関数になってしまったが、
//何となくうまく動いているので怖くていじれない

float3 ToneCurve(float3 Color){
    float3 newcolor;
    const float th = 0.65;
    newcolor = normalize(Color.rgb) * (th + sqrt(max(0, (length(Color.rgb) - th) / 2)));
    newcolor.r = (Color.r > 0) ? newcolor.r : Color.r;
    newcolor.g = (Color.g > 0) ? newcolor.g : Color.g;
    newcolor.b = (Color.b > 0) ? newcolor.b : Color.b;
    
    Color = min(Color, newcolor);
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_ALDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 , uniform int miplevel)
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, ViewportOffset.y) * pow(2, miplevel);
    
    return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
//高輝度成分の抽出

float4 PS_DrawHighLight( float2 Tex: TEXCOORD0 ) : COLOR
{
    return float4(ToneCurve(max(0, Degamma4(tex2Dlod(ScnSamp,float4(Tex,0,0))).rgb * OverLight - 0.98)) * scaling, 1);
}

////////////////////////////////////////////////////////////////////////////////////////////////

#define HLSampler HighLightView

////////////////////////////////////////////////////////////////////////////////////////////////
// MipMap利用ぼかし

float4 PS_AL_Gaussian( float2 Tex: TEXCOORD0, uniform bool Horizontal, uniform sampler2D Samp, uniform int miplevel, uniform int scalelevel) : COLOR
{
    float e, n = 0;
    float2 stex;
    float4 Color = 0;
    float step = (Horizontal ? AL_SampStepScaled.x : AL_SampStepScaled.y) * pow(2, scalelevel);
    const float2 dir = float2(Horizontal, !Horizontal);
    
    [unroll] //ループ展開
    for(int i = -AL_SAMP_NUM; i <= AL_SAMP_NUM; i++){
        e = exp(-pow((float)i / (AL_SAMP_NUM / 2.0), 2) / 2); //正規分布
        stex = Tex + dir * (step * (float)i);
        Color += tex2Dlod( Samp, float4(stex, 0, miplevel)) * e;
        n += e;
    }
    
    Color /= n;
    
    //低輝度領域の光の広がりを制限
    if(!Horizontal) Color = min(abs(Color), pow(abs(Color), 1 + scalelevel * 0.1 * (2 - alpha1) * Modest)) * sign(Color);
    
    return Color;
}


////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_DrawCoreColor( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 Color;
    
    Color = tex2D(ScnSampOut, Tex);
    
    Color = max(Color, 0.8 * tex2D( ScnSampOut, Tex+float2(0,OnePx.y)));
    Color = max(Color, 0.8 * tex2D( ScnSampOut, Tex+float2(0,-OnePx.y)));
    Color = max(Color, 0.8 * tex2D( ScnSampOut, Tex+float2(OnePx.x,0)));
    Color = max(Color, 0.8 * tex2D( ScnSampOut, Tex+float2(-OnePx.x,0)));
    
    Color = max(Color, 0.5 * tex2D( ScnSampOut, Tex+float2(OnePx.x,OnePx.y)));
    Color = max(Color, 0.5 * tex2D( ScnSampOut, Tex+float2(OnePx.x,-OnePx.y)));
    Color = max(Color, 0.5 * tex2D( ScnSampOut, Tex+float2(-OnePx.x,OnePx.y)));
    Color = max(Color, 0.5 * tex2D( ScnSampOut, Tex+float2(-OnePx.x,-OnePx.y)));
    
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
//合成

float4 PS_AL_Mix( float2 Tex: TEXCOORD0 , uniform bool FullOut) : COLOR
{
    float4 Color;
    
    Color = tex2D(ScnSampOut, Tex);
    Color += tex2D(ScnSampOut2, Tex);
    Color += tex2D(ScnSampOut3, Tex);
    Color += tex2D(ScnSampOut4, Tex);
    Color += tex2D(ScnSampOut5, Tex) * 0.8;
    
    Color.rgb = ToneCurve(Color.rgb);
    
    float4 basecolor = Degamma4(tex2D(ScnSamp, Tex));
    basecolor.rgb *= OverLight;
    Color += basecolor;
    
    // 白とび表現
    Color = OverExposure(Color);
    
    Color.a = basecolor.a + length(Color.rgb);
    Color.a = saturate(Color.a);
    Color.rgb /= Color.a;
    
    return Gamma4(Color);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック

// レンダリングターゲットのクリア値

float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


technique AutoLuminous <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=BackColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=HighLight;"
        "RenderColorTarget1=ScnMapOut;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=DrawHighLight;"
        
        "RenderColorTarget0=ScnMapX;"
        "RenderColorTarget1=;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X;"
        
        "RenderColorTarget0=ScnMapOut;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y;"
        
        "RenderColorTarget0=ScnMapX2;"
        "RenderDepthStencilTarget=DepthBuffer2;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X2;"
        
        "RenderColorTarget0=ScnMapOut2;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y2;"
        
        "RenderColorTarget0=ScnMapX3;"
        "RenderDepthStencilTarget=DepthBuffer3;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X3;"
        
        "RenderColorTarget0=ScnMapOut3;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y3;"
        
        "RenderColorTarget0=ScnMapX4;"
        "RenderDepthStencilTarget=DepthBuffer4;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X4;"
        
        "RenderColorTarget0=ScnMapOut4;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y4;"
        
        
        "RenderColorTarget0=ScnMapX5;"
        "RenderDepthStencilTarget=DepthBuffer5;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_X5;"
        
        "RenderColorTarget0=ScnMapOut5;"
        "Clear=Color; Clear=Depth;"
        "Pass=AL_Gaussian_Y5;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
        "Clear=Depth;"
        "Clear=Color;"
        "Pass=AL_Mix;"
    ;
    
> {
    
    pass AL_Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 0, 0);
    }
    pass AL_Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX, 0, 0);
    }
    
    pass AL_Gaussian_X2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(1);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 2, 2);
    }
    pass AL_Gaussian_Y2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(1);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX2, 0, 2);
    }
    
    pass AL_Gaussian_X3 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(2);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 4, 4);
    }
    pass AL_Gaussian_Y3 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(2);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX3, 0, 4);
    }
    
    pass AL_Gaussian_X4 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(3);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 5, 5);
    }
    pass AL_Gaussian_Y4 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(3);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX4, 0, 5);
    }
    
    pass AL_Gaussian_X5 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(4);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(true, HLSampler, 7, 7);
    }
    pass AL_Gaussian_Y5 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = false;
        AlphaTestEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(4);
        PixelShader  = compile ps_3_0 PS_AL_Gaussian(false, ScnSampX5, 0, 7);
    }
    
    
    
    pass DrawHighLight < string Script= "Draw=Buffer;"; > {
        AlphaTestEnable = false;
        AlphaBlendEnable = false;
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_DrawHighLight();
    }
    
    pass AL_Mix < string Script= "Draw=Buffer;"; > {
        
        #if ALPHA_OUT!=0
            AlphaBlendEnable = false;
            AlphaTestEnable = false;
        #endif
        
        VertexShader = compile vs_3_0 VS_ALDraw(0);
        PixelShader  = compile ps_3_0 PS_AL_Mix(true);
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////




