// 色収差: 画面の縁の色をにじませる
// コントローラのSiで色のズレる量をコントロール可能

//ぼかしのサンプリング数
#define SAMPLE_NUM  8


// 色ずれ量
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float ColorShift = AcsSi;

//背景色
float4 ClearColor
<
   string UIName = "ClearColor";
   string UIWidget = "Color";
   bool UIVisible =  true;
> = float4(0,0,0,0);



///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////
//これ以降はエフェクトの知識のある人以外は触れないこと


float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;


float4x4 matWorld : CONTROLOBJECT < string name = "(self)"; >; 

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

// レンダリングターゲットのクリア値
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


////////////////////////////////////////////////////////////////////////////////////////////////

float PosToRate(float2 Tex){
    
    Tex -= 0.5;
    Tex.y /= ViewportAspect;
    float r = length(Tex);
    float ret = r * 2.0;		// r * 2.0 / 1.41421356
    ret = ret * ret;
    return ret;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 共通頂点シェーダ
struct VS_OUTPUT {
    float4 Pos            : POSITION;
    float2 Tex            : TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}


////////////////////////////////////////////////////////////////////////////////////////////////
float3 hsv2rgb(float3 c)
{
	float3 K = float3(3,2,1)/3.;
	float3 hcol = saturate((abs(frac(c.x + K.xyz) * 6 - 3) - 1));
	return float3(lerp(1, hcol, c.y) * c.z);
}

float4 PS_passDraw1( float2 Tex: TEXCOORD0 ) : COLOR {   
    
    float4 Color;
    float rate = PosToRate(Tex);

    float2 vec_g = Tex - 0.5;
    vec_g.y /= ViewportAspect;
    float shiftIn = (1024 + ColorShift * rate) / 1024.0;
    float shiftOut = (1024 - ColorShift * rate) / 1024.0;

    float2 vec_r = vec_g * shiftIn;
    float2 vec_b = vec_g * shiftOut;

    vec_r.y *= ViewportAspect;
    vec_b.y *= ViewportAspect;

    vec_r += 0.5;
    vec_b += 0.5;

    Color = tex2D( ScnSamp, Tex );

#if 0
    Color.r = tex2D( ScnSamp, vec_r ).r;
    Color.b = tex2D( ScnSamp, vec_b ).b;
#else
	Color.rgb = 0;
	float3 weight = 0;
	for(int i = 0; i <= SAMPLE_NUM; i++)
	{
		float t = i * (1.0 / SAMPLE_NUM);
		float3 w = hsv2rgb(float3(t * 2.0/3.0, 1, 1));
		float2 uv = lerp(vec_r, vec_b, t);
		Color.rgb += tex2D( ScnSamp, uv ).rgb * w;
		weight += w;
	}

	Color.rgb /= weight;
#endif

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////


technique CheapLens <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
        "RenderDepthStencilTarget=DepthBuffer;"
        "ClearSetColor=ClearColor;"
        "ClearSetDepth=ClearDepth;"
        "Clear=Color;"
        "Clear=Depth;"
        "ScriptExternal=Color;"
        
        "RenderColorTarget0=;"
        "RenderDepthStencilTarget=;"
        "Clear=Color;"
        "Clear=Depth;"
        "Pass=Draw1;"
    ;
    
> {
    
    pass Draw1 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        VertexShader = compile vs_3_0 VS_passDraw();
        PixelShader  = compile ps_3_0 PS_passDraw1();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////

