//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　夕焼け風フィルタ v0.1
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

//　非透過モード 0 時の背景色（0.0：黒色、0.5：灰色【初期値。o_disAlphaBlendと併用する場合向け】、1.0：白色）
#define B_COLOR 0.5

//　高画質モード（ 0：一般的な整数テクスチャを使います。1 が重かったりエラーが出る場合に使用して下さい。
//　　　　　　　　 1：浮動小数点数テクスチャを使います。特に問題なければこちらをご使用ください）
#define HQ_MODE 0

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1,1,1,1};
#else
float4 ClearColor = {B_COLOR,B_COLOR,B_COLOR,0};
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

//　アクセサリ操作設定値を取得
float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha = MaterialDiffuse.a;

//float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
//static float scaling = scaling0 * 0.1;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float ObjX = ObjXYZ0.x * 0.1;
static float ObjY = ObjXYZ0.y * 0.1 + 1.0;
static float ObjZ = ObjXYZ0.z + 0.33333333;

//　トーン補正用プリセットビットマップ
texture2D Tone <
	string ResourceName = "yuugure.bmp";
	int MipLevels = 1;
#if HQ_MODE
	string Format = "A16B16G16R16F";
#else
	string Format = "A8R8G8B8";
#endif
>;
sampler ToneSamp = sampler_state{
	Texture = <Tone>;
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
#if HQ_MODE
	string Format = "A32B32G32R32F";
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
	AddressV = CLAMP;
};

#define LumiFactor float3(0.2126, 0.7152, 0.0722)
#define cHue		ColorHSB.r
#define cSaturation	ColorHSB.g
#define cBrightness	ColorHSB.b

float3 RGBtoHSB(float3 ColorRGB)
{
	float3	ColorHSB;
	float	cMax, cMin, cDiff;

	cMax = max(max(ColorRGB.r, ColorRGB.g), ColorRGB.b);
	cMin = min(min(ColorRGB.r, ColorRGB.g), ColorRGB.b);

	cDiff = (cMax == cMin) ? 1.0f : (cMax - cMin);

	cHue = (cMax == ColorRGB.r) * ((ColorRGB.g - ColorRGB.b) / cDiff)
		 + (cMax == ColorRGB.g) * ((ColorRGB.b - ColorRGB.r) / cDiff + 2.0)
		 + (cMax == ColorRGB.b) * ((ColorRGB.r - ColorRGB.g) / cDiff + 4.0);

//	cSaturation = (cMax - cMin) / (cMax > 0.0 ? cMax : 1.0);
	cSaturation = cMax > 0.0 ? (cMax - cMin) / cMax : 0.0;
	cBrightness = cMax;

	return ColorHSB;
}

float3 HSBtoRGB(float3 ColorHSB)
{
	float3	ColorRGB;

	int		iHue;
	float	P, Q, T;

	cHue = fmod(cHue, 6.0);
	iHue = floor(cHue);

	P = cBrightness * (1.0 - cSaturation);
	Q = cBrightness * (1.0 - frac(cHue) * cSaturation);
	T = cBrightness * (frac(cHue) * cSaturation + (1.0 - cSaturation));

	
	if(iHue == 0) {
		ColorRGB.r = cBrightness;
		ColorRGB.g = T;
		ColorRGB.b = P;
	} else if(iHue == 1) {
		ColorRGB.r = Q;
		ColorRGB.g = cBrightness;
		ColorRGB.b = P;
	} else if(iHue == 2) {
		ColorRGB.r = P;
		ColorRGB.g = cBrightness;
		ColorRGB.b = T;
	} else if(iHue == 3) {
		ColorRGB.r = P;
		ColorRGB.g = Q;
		ColorRGB.b = cBrightness;
	} else if(iHue == 4) {
		ColorRGB.r = T;
		ColorRGB.g = P;
		ColorRGB.b = cBrightness;
	} else if(iHue == 5) {
		ColorRGB.r = cBrightness;
		ColorRGB.g = P;
		ColorRGB.b = Q;
	}

	return saturate(ColorRGB);
}

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
//　プリセットビットマップを元に色の置き換え

float4 PS_passDraw(float2 Tex: TEXCOORD0) : COLOR
{	
	float4 Color = tex2D( ScnSamp, Tex );	//　処理後のピクセルカラーを格納
	float4 ColorOrg = Color;				//　処理前のピクセルカラーを格納

	//　輝度算出
	float3 MonoColor = dot(LumiFactor, Color.rgb);
	Color.rgb = lerp(Color.rgb * ObjZ + MonoColor * (1-ObjZ), Color.rgb, LumiFactor);

	//　RGB各色の値から補正後の値をテクスチャから読み込む
	Color.r = tex2D( ToneSamp, float2(Color.r * 0.99607843 + 0.00196, 0.5)).r;
	Color.g = tex2D( ToneSamp, float2(Color.g * 0.99607843 + 0.00196, 0.5)).g;
	Color.b = tex2D( ToneSamp, float2(Color.b * 0.99607843 + 0.00196, 0.5)).b;

	float3 ColorHSB = RGBtoHSB(Color.rgb);
	ColorHSB.r *= ObjY;
	Color.rgb = HSBtoRGB(ColorHSB);

	MonoColor = dot(LumiFactor, Color.rgb);

	//　色調補正量を暗さに比例させて合成
	Color.rgb = saturate(lerp(Color.rgb, ColorOrg.rgb * (0.6 + ObjX) + Color.rgb * (0.75 - ObjX), MonoColor));

	//　アクセサリの不透明度を元にオリジナルと合成
	return saturate(lerp(ColorOrg, Color, alpha));
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
technique o_Yuyake <
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
		VertexShader = compile vs_3_0 VS_passDraw();
		PixelShader	 = compile ps_3_0 PS_passDraw();
	}
}
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
