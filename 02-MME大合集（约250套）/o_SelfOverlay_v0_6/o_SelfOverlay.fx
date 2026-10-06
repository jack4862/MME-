//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　自己オーバーレイ合成フィルタ（o_SelfOverlay） v0.6
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

//　明るさ補正モード（1：全体的に暗く、0：暗い部分は補正しない）
#define BRIGHTNESS_MODE  1

//　使用テクスチャ（ 0: 整数テクスチャ、1: 浮動小数点数テクスチャ）
#define USE_FLOAT_TEXTURE 0

//　オーバーレイレイヤーの明度補正（ 0～1：0で真っ黒、1で補正なし）
//　　初期設定 0.9
float Correction = 0.9;

//　簡易色調補正（MikuMikuMoving 用：x,y,z が調整できないようなので：定義を分けているのは MMM の仕様回避）
//　　初期設定 1.0
float uiColorR <
   string UIName = "簡易補正:赤";
   string UIWidget = "Spinner";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 1.0;

float uiColorG <
   string UIName = "簡易補正:緑";
   string UIWidget = "Spinner";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 1.0;

float uiColorB <
   string UIName = "簡易補正:青";
   string UIWidget = "Spinner";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 1.0;


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義
#define BG_COLOR 0.5

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1.0 ,1.0 ,1.0, 1.0};
#else
float4 ClearColor = {BG_COLOR, BG_COLOR, BG_COLOR, 0.0};
#endif
float ClearDepth  = 1.0;

//　ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha = MaterialDiffuse.a;

float brightness0 : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float brightness = brightness0 * 0.1;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float3 ObjXYZ = ObjXYZ0 + 1.0;

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//　オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0, 1.0};
	int MipLevels = 1;
	bool AntiAlias = true;
#if USE_FLOAT_TEXTURE
	string Format = "A16B16G16R16F";
#else
	string Format = "A8R8G8B8";
#endif
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　レンダリング結果を自己オーバーレイ合成

float4 PS_passTonemap(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color = tex2D( ScnSamp, Tex );		//　処理後のピクセルカラーを格納
	float4 ColorOrg = Color;					//　処理前のピクセルカラーを格納
	
	//　オーバーレイ合成レイヤーの明度調整
    //　ボカしたオーバーレイ合成レイヤーの明度調整
	float bright = Correction * brightness;

#if BRIGHTNESS_MODE == 1
	Color.rgb *= bright;
#else
	Color.r = Color.r > 0.5 ? ((Color.r - 0.5) * bright) + 0.5 : Color.r;
	Color.g = Color.g > 0.5 ? ((Color.g - 0.5) * bright) + 0.5 : Color.g;
	Color.b = Color.b > 0.5 ? ((Color.b - 0.5) * bright) + 0.5 : Color.b;
#endif

	//　色調補正量を暗さに比例させて合成
	float3 uiPostColor = float3(uiColorR, uiColorG, uiColorB);
	Color.rgb = lerp(Color.rgb * ObjXYZ * uiPostColor, Color.rgb, Color.rgb);

	
	//　オーバーレイ合成
	Color.rgb = ColorOrg.rgb < 0.5 ? ColorOrg.rgb * Color.rgb * 2.0 : 1.0 - 2.0 * (1.0 - ColorOrg.rgb) * (1.0 - Color.rgb);
	
	//　アクセサリの不透明度を元にオリジナルと合成
	return lerp(ColorOrg, Color, alpha);
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
technique SelfOverlay <
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
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=TonemapExec;"
	;
	
> {
	pass TonemapExec < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_passDraw();
		PixelShader  = compile ps_2_0 PS_passTonemap();
	}
}
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
