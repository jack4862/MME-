//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　画面縁の色を変えるエフェクト　v0.1
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

// 透過モード時の背景色（初期値：0.5［灰色］、0.0［黒］～1.0［白］）
#define BG_COLOR 0.5

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1,1,1,1};
#else
float4 ClearColor = {BG_COLOR,BG_COLOR,BG_COLOR,0};
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

static float2 ViewportOffset = (float2(0.5,0.5) / ViewportSize);
static float AspectRatio = (ViewportSize.x / ViewportSize.y);

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha = MaterialDiffuse.a;

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float Concentration = scaling0 * 0.1;

float3 ObjXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;

//　汚し用テクスチャ（tex169→16:9用テクスチャ、tex43→4:3用テクスチャ）
texture2D tex169 <
	string ResourceName = "alpha169.png";
	int MipLevels = 1;
	string Format = "A8" ;
>;
sampler tex169Samp = sampler_state{
	Texture = <tex169>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D tex43 <
	string ResourceName = "alpha43.png";
	int MipLevels = 1;
	string Format = "A8" ;
>;
sampler tex43Samp = sampler_state{
	Texture = <tex43>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

//　オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = NONE;
	MagFilter = NONE;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　頂点シェーダ
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passDraw( float4 Pos : POSITION, float2 Tex : TEXCOORD0 )
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	
	return Out;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　汚しテクスチャを乗算合成

float4 PS_passDrawShadow(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color;		//　処理後のピクセルカラーを格納
	float4 ColorOrg;	//　処理前のピクセルカラーを格納
	float  ToneAlpha;	//　汚しテクスチャ

	// ObjXYZ：アクセサリの位置＝フェードアウトカラー
	// Concentration：アクセサリのサイズ×Opacity＝適用する強さ
	
	Color = tex2D( ScnSamp, Tex );
	ColorOrg = Color;

	//　テクスチャからフェード強度を取得　※フェードアウトだけするならテクスチャじゃなくて良い？
	ToneAlpha = AspectRatio > 1.5 ? tex2D( tex169Samp, Tex ).r : tex2D( tex43Samp, Tex ).r;
	
	//　MMD出力に対して乗算合成
#if NON_TRANSPARENT
	Color.rgb = lerp(Color.rgb, ObjXYZ, ToneAlpha);
#else
	if(Color.a == 0) {
		Color.rgb = ObjXYZ;
		Color.a = ToneAlpha;
	} else {
		Color.rgb = (ObjXYZ * ToneAlpha) + (Color.rgb * (1.0 - ToneAlpha));
		Color.a = Color.a * (1.0 - ToneAlpha) + ToneAlpha;
	}
#endif

	//　アクセサリの不透明度を元にオリジナルと合成
	return lerp(ColorOrg, Color, alpha);
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
technique DrawShadow <
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
		"Pass=DrawShadowExec;"
	;
	
> {
	pass DrawShadowExec < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 VS_passDraw();
		PixelShader  = compile ps_2_0 PS_passDrawShadow();
	}
}
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
