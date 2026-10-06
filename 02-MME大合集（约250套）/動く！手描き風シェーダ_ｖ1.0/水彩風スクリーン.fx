////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Post_BlendTex.fx ver0.8b fps可変バージョン
//  作成: eye( ミーフォ茜のM4Layer.fx 針金PのScreenTex.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////

//このレイヤーは「スクリーン」モードです。

// 画面に貼り付けるアニメーションテクスチャ
#define TexFile "SuisaiFrame.gif"        // 画面に貼り付けるテクスチャファイル名
#define AnimeStart 0.0   // アニメGIF･APNGの場合のアニメーション開始時間(単位：秒)
#define AnimeFPS 12                 // アニメーションフレーム数(単位：fps)

//簡易色調補正。{赤, 緑, 青, 透明度}通常値は1。0から数値を高くすると濃くなっていく。
float4 ColorShift = { 1, 1, 1, 1 };   

//1(ON)にすると半透明なガラスなどを正確に描写するが、不必要な部分まで描写してしまう場合がある。
#define ALPHA_ENABLED 1

////////////////////////////////////////////////////////////////

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

float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
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

// 前画面にテクスチャのスクリーンを展開する。
texture Blending : ANIMATEDTEXTURE <
    string ResourceName = TexFile;
    float Offset = AnimeStart;
    float Speed = AnimeFPS / 30.00 ;
>;
sampler LayerSampler = sampler_state {
    texture = <Blending>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

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

//ブレンドモード
float Blend(float a, float b)
{
	return 1 - (1 - a) * (1 - b);	// スクリーン
}


float4 BlendPS(float2 Tex: TEXCOORD0) : COLOR
{
	float4 background = tex2D(ScreenSampler, Tex);
	float4 foreground = tex2D(LayerSampler, Tex);

	foreground = foreground * ColorShift ;

	
	[unroll]
	for (int i = 0; i < 3; i++)
		foreground[i] = Blend(background[i], foreground[i]);
	
	float a = Tr * foreground.a;
	
	background.a = min(1, background.a + a);
	background.rgb = lerp(background.rgb, foreground.rgb, a);
	
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
#if ALPHA_ENABLED
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
#endif
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
#if ALPHA_ENABLED
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
#endif
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
