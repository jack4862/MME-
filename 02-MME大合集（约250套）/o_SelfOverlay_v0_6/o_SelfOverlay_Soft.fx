//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　自己ボカしオーバーレイ合成フィルタ（o_SelfOverlay_Soft） v0.6
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

//　明るさ補正モード（1：全体的に暗く、0：暗い部分は補正しない）
#define BRIGHTNESS_MODE 1

//　ぼかしのサンプリング数
#define SAMP_NUM 7

//　使用テクスチャ（ 0: 整数テクスチャ、1: 浮動小数点数テクスチャ）
#define USE_FLOAT_TEXTURE 0

//　ぼかし範囲(サンプリング数は固定のため、大きくしすぎると縞が出ます)
//　　初期設定 0.001953125（=2^-9）
float Extent = 0.001953125;

//　オーバーレイ合成レイヤーの明度補正（ 0～1：0で真っ黒、1で補正なし）
//　　初期設定 0.8
float Correction = 0.8;

//　ボカシサイズ（MikuMikuMoving 用：Rx が調整できないようなので）
//　　初期設定 1.0
float uiBulrSize <
   string UIName = "ボカし幅調整";
   string UIWidget = "Spinner";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 1.0;

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

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha = MaterialDiffuse.a;

float brightness0 : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float brightness = brightness0 * 0.1;

float scaling0 : CONTROLOBJECT < string name = "(self)"; string item = "Rx"; >;
static float scaling = scaling0 * 57.4647887324 + 1.0;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float3 ObjXYZ = ObjXYZ0 + 1.0;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5, 0.5) / ViewportSize);
static float2 SampStep = (float2(Extent, Extent) / ViewportSize * ViewportSize.y) * scaling * uiBulrSize;

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
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

//　X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0, 1.0};
	int MipLevels = 1;
	bool AntiAlias = false;
#if USE_FLOAT_TEXTURE
	string Format = "A16B16G16R16F";
#else
	string Format = "A8R8G8B8";
#endif
>;
sampler2D ScnSamp2 = sampler_state {
	texture = <ScnMap2>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
// 共通頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　X方向ぼかし

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR
{   
	float4 sum = 0;
	float e, f, n = 0;

	[unroll]for(int i = -SAMP_NUM; i <= SAMP_NUM; i++)
	{
		f = float(i);

		e = exp(-pow(f / (SAMP_NUM / 2.0), 2.0) / 2.0); //正規分布
		sum += tex2D(ScnSamp, float2(Tex.x + SampStep.x * f, Tex.y)) * e;
		n += e;
	}

	return sum / n;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　Y方向ぼかし + 合成

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color, ColorOrg, sum = 0;
	float e, f, n = 0;

	[unroll]for(int i = -SAMP_NUM; i <= SAMP_NUM; i++)
	{
		f = float(i);

		e = exp(-pow(f / (SAMP_NUM / 2.0), 2.0) / 2.0); //正規分布
		sum += tex2D(ScnSamp2, float2(Tex.x, Tex.y + SampStep.y * f)) * e;
		n += e;
	}

	Color = sum / n;
	Color.rgb /= Color.a;

	ColorOrg = tex2D(ScnSamp, Tex);

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
	Color.rgb = lerp(ColorOrg.rgb, Color.rgb, alpha);
#if NON_TRANSPARENT == 0
//	Color.a = max(ColorOrg.a, Color.a);	//　透明部分にもボカシをはみ出させたい場合
	Color.a = ColorOrg.a;				//　透明部分にはボカシをはみ出させない場合
#endif

	return Color;
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
	pass Gaussian_X < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		VertexShader = compile vs_2_0 VS_passDraw();
		PixelShader  = compile ps_2_0 PS_passX();
	}
	pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = false;
		AlphaTestEnable = false;

		VertexShader = compile vs_3_0 VS_passDraw();
		PixelShader  = compile ps_3_0 PS_passY();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
