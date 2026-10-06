//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　お手軽キーイングエフェクト v0.4
//　　　by おたもん（user/5145841）
//
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　表示モード ( 0：エフェクト適用結果を表示、1：キーイング用マップ（黒；透明 ～ 白；不透明）)
#define SHOW_KEYING_MAP 0

//　高画質モード（ 0：一般的な整数テクスチャを使います。1 が重かったりエラーが出る場合に使用して下さい。
//　　　　　　　　 1：浮動小数点数テクスチャを使います。特に問題なければこちらをご使用ください）
#define HQ_MODE 1

//　非透過モード（ 0: 透明部分はそのまま出力、1: 半透明部分は不透明として出力(非推奨)）
#define TRANSPARENT_MODE 0

#define B_COLOR 0.5
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha = MaterialDiffuse.a;

float Si : CONTROLOBJECT <string name="(self)"; string item="Si";>;
static const float Scale = Si * 0.1f;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f) / ViewportSize;

//　レンダリングターゲットのクリア値
float4 ClearColor = {B_COLOR, B_COLOR, B_COLOR, 0.0f};
float  ClearDepth = 1.0f;

#define Correction 1.0

//-----------------------------------------------------------------------------
// オリジナルの描画結果を記録するためのレンダーターゲット
//
//-----------------------------------------------------------------------------
Texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
#if HQ_MODE
	string Format = "A16B16G16R16F";
#else
	string Format = "A8R8G8B8";
#endif
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

Texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//-----------------------------------------------------------------------------
// キーマップ
Texture2D KeyingMapRT: OFFSCREENRENDERTARGET <
	string Description = "o_postKeying で切抜き指定に使用するオフスクリーンターゲット\n"
		"White.fx を指定したオブジェクトが Black.fx を指定したオブジェクトで切り抜かれます。";
	float4 ClearColor = {0,0,0,1};
	float ClearDepth = 1.0f;
#if HQ_MODE
	string Format = "R16F" ;
#else
	string Format = "X8R8G8B8";
#endif
	bool AntiAlias = true;
	string DefaultEffect = 
		"self = hide;"

		"*.x = Black.fx;"
		"*.pmd = White.fx;"
		"*.pmx = White.fx;";
>;

sampler KeyingMap = sampler_state {
	texture = <KeyingMapRT>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


//-----------------------------------------------------------------------------
// 固定定義
//-----------------------------------------------------------------------------
struct VS_OUTPUT
{
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
};

//-----------------------------------------------------------------------------
// KeyingMapを元に切り抜く
//-----------------------------------------------------------------------------

VS_OUTPUT VS_postKeying(float4 Pos:POSITION, float4 Tex:TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset;
	
	return Out;
}

float4 PS_postKeying( float2 inTex: TEXCOORD0 ) : COLOR
{   
	float4 Color = tex2D(ScnSamp, inTex);
	float KeyingAlpha = tex2D(KeyingMap, inTex);

#if SHOW_KEYING_MAP
	return float4(KeyingAlpha, KeyingAlpha, KeyingAlpha, 1.0f);
#else
	float4 ColorOrg = Color;

  #if TRANSPARENT_MODE
	Color.a = KeyingAlpha == 0.0f ? 0.0f : 1.0f;
  #else
		Color.a = pow(KeyingAlpha, Scale * Correction);
  #endif

	return lerp(ColorOrg, Color, alpha);
#endif
}
////////////////////////////////////////////////////////////////////////////////////////////////

technique PostKeying <
	string Script = 
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		//キーイング処理
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"

		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"

		"Pass=KeyingPass;"
	;
> {
	pass KeyingPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_postKeying();
		PixelShader  = compile ps_2_0 PS_postKeying();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
