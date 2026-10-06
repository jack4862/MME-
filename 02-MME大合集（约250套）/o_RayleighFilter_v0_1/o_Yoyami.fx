//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　夜闇風フィルタ v0.1
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

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.015;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float3 ObjXYZ = ObjXYZ0 + 1.0;
static float ObjX = ObjXYZ0.x * 0.15 + 0.15;
static float ObjY = ObjXYZ0.y * 0.1 + 1.1;
static float ObjZ = ObjXYZ0.z * 0.5 + 3.0;

//　トーン補正用プリセットビットマップ
texture2D Tone <
	string ResourceName = "yoyami.bmp";
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

//#define LumiFactor float3(0.2126, 0.7152, 0.0722)
#define LumiFactor float3(0.222015, 0.706655, 0.071330)
#define GAMMA 2.2
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

float4 PS_passTonemap(float2 Tex: TEXCOORD0) : COLOR
{	
	float4 Color = tex2D( ScnSamp, Tex );	//　処理後のピクセルカラーを格納
	float4 ColorOrg = Color;				//　処理前のピクセルカラーを格納

	//　輝度算出
	float3 MonoColor = dot(LumiFactor, Color.rgb);
	Color.rgb = lerp((MonoColor * ObjZ + Color.rgb * (4.0 - ObjZ)) * 0.25, Color.rgb, LumiFactor);

	//　RGB各色の値から補正後の値をテクスチャから読み込む
	Color.r = tex2D( ToneSamp, float2(Color.r * 0.99607843 + 0.00196, 0.5)).r;
	Color.g = tex2D( ToneSamp, float2(Color.g * 0.99607843 + 0.00196, 0.5)).g;
	Color.b = tex2D( ToneSamp, float2(Color.b * 0.99607843 + 0.00196, 0.5)).b;

	//　輝度算出
	MonoColor = dot(LumiFactor, Color.rgb);

	//　色調補正量を暗さに比例させて合成
	Color.rgb = Color.rgb * ObjX + MonoColor * (1.0 - ObjX);
	Color.rgb = pow(Color.rgb, ObjY);

	//　アクセサリの不透明度を元にオリジナルと合成
	return saturate(lerp(ColorOrg, Color, alpha));
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
technique o_Yoyami <
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
		PixelShader	 = compile ps_2_0 PS_passTonemap();
	}
}
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
