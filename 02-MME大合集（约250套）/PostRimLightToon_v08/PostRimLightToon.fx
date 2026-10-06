///////////////////////////////////////////////////////////////////////////////
//
//  PostRimLightToon.fx
//
//  M4Layerとfull2.0を改変しています。
//
//  改変: P.I.P
//
//
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  M4Layer.fx
//  作成: ミーフォ茜
//
////////////////////////////////////////////////////////////////////////////////

// マスクを使用するか（1にするとUVマスクが使用できます）
#define LAYER_MASK 0

// マスクを反転するか
#define LAYER_MASK_INVERT 1

// レンダリングターゲットを使用するか
// 0 にすると描画結果をそのまま使用するようになりますが、
// 他のレンダリングターゲットに対して使用できるようになります。
#define LAYER_RT 1

////////////////////////////////////////////////////////////////

#define MERGE(a, b) a##b

// ポストエフェクト宣言
float Script : STANDARDSGLOBAL
<
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

float TrPmx : CONTROLOBJECT < string name = "(self)"; string item = "ﾘﾑﾗｲﾄ弱"; >;
float SiPmx : CONTROLOBJECT < string name = "(self)"; string item = "ﾘﾑﾗｲﾄ強"; >;


static float Tr = 1 - TrPmx;
static float Si = 10 + ( SiPmx * 100 );


float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5, 0.5) / ViewportSize;

////////////////////////////////////////////////////////////////
// 作業用テクスチャ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;
texture2D ScreenBuffer : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScreenSampler = sampler_state {
	texture = <ScreenBuffer>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

#if LAYER_RT
texture PRLToon : OFFSCREENRENDERTARGET
<
	string Format = "A16B16G16R16F";
	string Description = "ポスト加算スフィアのマスク PostAddSphere.fx";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect = "self = hide; * = full_SphereAdd.fx;";
>;
sampler LayerSampler = sampler_state
{
	texture = <PRLToon>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

#endif

#if LAYER_MASK
texture PRLMask : OFFSCREENRENDERTARGET
<
	string Format = "A16B16G16R16F";
	string Description = "ポスト加算スフィアのマスク PostAddSphere.fx";
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 1;
	string DefaultEffect = "self = hide; * = VisibleMask.fx;";
>;
sampler LayerMaskSampler = sampler_state
{
	texture = <PRLMask>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
#endif

struct VS_OUTPUT
{
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT BlendVS(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{ 
	VS_OUTPUT Out;
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

#ifdef IS_COMPOSITE_BLENDING

float Lum(float3 rgb)
{
	return rgb.r * 0.3 + rgb.g * 0.59 + rgb.b * 0.11;
}

float3 ClipColor(float3 rgb)
{
	float l = Lum(rgb);
	float n = min(rgb.r, min(rgb.g, rgb.b));
	float x = max(rgb.r, max(rgb.g, rgb.b));
	
	if (n < 0)
	{
		float lMinusN = l - n;
		
		rgb = float3
		(
			l + (rgb.r - l) * l / lMinusN,
			l + (rgb.g - l) * l / lMinusN,
			l + (rgb.b - l) * l / lMinusN
		);
	}
	
	if (x > 1)
	{
		float oneMinusL = 1 - l;
		float xMinusL = x - l;
		
		rgb = float3
		(
			l + (rgb.r - l) * oneMinusL / xMinusL,
			l + (rgb.g - l) * oneMinusL / xMinusL,
			l + (rgb.b - l) * oneMinusL / xMinusL
		);
	}
	
	return rgb;
}

float3 SetLum(float3 rgb, float l)
{
	float d = l - Lum(rgb);
	
	rgb += float3(d, d, d);
	
	return ClipColor(rgb);
}

float Sat(float3 rgb)
{
	return max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
}

float3 SetSat(float3 rgb, float s)
{
	float3 rt = rgb;
	float maxValue = max(rgb.r, max(rgb.g, rgb.b));
	float minValue = min(rgb.r, min(rgb.g, rgb.b));
	float midValue =
		rgb.r < maxValue && rgb.r > minValue ? rgb.r :
		rgb.g < maxValue && rgb.g > minValue ? rgb.g :
		rgb.b < maxValue && rgb.b > minValue ? rgb.b : (maxValue + minValue) / 2;
	
	if (maxValue > minValue)
	{
		[unroll]
		for (int i = 0; i < 3; i++)
		{
			if (rgb[i] == midValue)
				rt[i] = (midValue - minValue) * s / (maxValue - minValue);
			else if (rgb[i] == maxValue)
				rt[i] = s;
			else
				rt[i] = 0;
		}
	}
	else
	{
		rt = 0;
	}
	
	return rt;
}

#else

float Blend(float a, float b)
{
	return a + b;	// 加算
}

#endif

float4 BlendPS(float2 Tex: TEXCOORD0) : COLOR
{
	float4 background = tex2D(ScreenSampler, Tex);
	
#if LAYER_RT
	float4 foreground = tex2D(LayerSampler, Tex);
#else
	float4 foreground = background;
#endif
	
#if LAYER_MASK
	float4 m = tex2D(LayerMaskSampler, Tex);
	
	#if LAYER_MASK_INVERT
	foreground.a *= m.r * m.a;
	#else
	foreground.a *= 1 - m.r * m.a;
	#endif
#endif
	
#ifdef IS_COMPOSITE_BLENDING
	foreground.rgb = Blend(background.rgb, foreground.rgb);
#else
	[unroll]
	for (int i = 0; i < 3; i++)
		foreground[i] = Blend(background[i], foreground[i]);
#endif
	
	background.rgb = lerp(background.rgb, foreground.rgb, Tr * (Si / 10) * foreground.a);
	
	return background;
}

////////////////////////////////////////////////////////////////
// エフェクトテクニック
//
float4 ClearColor = { 0, 0, 0, 0 };
float ClearDepth = 1;

technique PostEffectTec
<
	string Script =
		"RenderColorTarget0=ScreenBuffer;"
		"RenderDepthStencilTarget=DepthBuffer;"
		//"ClearSetColor=ClearColor;"
		//"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		//"ClearSetColor=ClearColor;"
		//"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=PassBlend;";
>
{
	pass PassBlend < string Script = "Draw=Buffer;"; >
	{
		AlphaBlendEnable = true;
		VertexShader = compile vs_3_0 BlendVS();
		PixelShader  = compile ps_3_0 BlendPS();
	}
};
