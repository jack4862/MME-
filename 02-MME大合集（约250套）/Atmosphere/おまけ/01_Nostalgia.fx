//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　お手軽にトーン補正フィルタ v0.6
//　　　by おたもん（user/5145841）
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 1

//　プリセット指定：""に囲まれている文字（初期値"デフォルト"）を
//　　見本集フォルダに入っている"ネガフィルム"などのファイル名と書き換えると適用
#define Preset "Default5"

//　モノクロ映像にするかどうか　0 でカラー（標準）、1 でモノクロに
//　　1 にしたうえでプリセットを"セピア"にすればセピア映像になります
#define Monochrome 0

//　モノクロ化アルゴリズム指定
//　　0:変換しない　1:平均算出法　2:BT.601(NTSC)ベース　3:BT.709(HDTV)ベース（デフォルト）
#define MONO_ALGO 3
//　BT.709ベースでモノクロ化する際に用いるガンマ値（基本: 2.2、推奨値範囲: 1.0 ～ 5.0）
#define GAMMA 2.2

//　高画質モード（ 0：一般的な整数テクスチャを使います。1 が重かったりエラーが出る場合に使用して下さい。
//　　　　　　　　 1：浮動小数点数テクスチャを使います。特に問題なければこちらをご使用ください）
#define HQ_MODE 0

//　簡易色調補正（ 赤, 緑, 青（,α）の順に指定、1で変化なし）
//　　初期設定 1.0, 1.0, 1.0, 1.0
float4 ColorFilter
<
   string UIName = "ColorFilter";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = float4( 0, 0, 0, 1);
   float UIMax = float4( 2, 2, 2, 1);
> = float4( 1.0, 1.0, 1.0, 1.0 );


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1,1,1,1};
#else
float4 ClearColor = {0.5,0.5,0.5,0};
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

float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
static float scaling = scaling0 * 0.1;

float3 ObjXYZ0 : CONTROLOBJECT < string name = "(self)"; >;
static float3 ObjXYZ = ObjXYZ0 + 1.0;

//　トーン補正用プリセットビットマップ
texture2D Tone <
	string ResourceName = "bitmap\\"Preset".bmp";
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

#if MONO_ALGO == 2	//　輝度算出法（BT601:NTSC）
static const float3 LumiFactor = {0.29891, 0.58661, 0.11448};

#elif MONO_ALGO == 3	//　輝度算出法（BT709:HDTV）
static const float3 LumiFactor = {0.2126, 0.7152, 0.0722};
#endif
	
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
//　プリセットビットマップを元に色の置き換え

float4 PS_passTonemap(float2 Tex: TEXCOORD0) : COLOR
{   
	float4 Color;		//　処理後のピクセルカラーを格納
	float4 ColorOrg;	//　処理前のピクセルカラーを格納

	Color = tex2D( ScnSamp, Tex );
	ColorOrg = Color;

#if Monochrome		//　R,G,B に求めた輝度を入れてモノクロ化
	#if MONO_ALGO == 1		//　平均算出法
		Color.rgb = (Color.r + Color.g + Color.b) * (1.0 / 3.0);

	#elif MONO_ALGO == 2	//　輝度算出法（BT601:NTSC）
		Color.rgb = dot(LumiFactor, Color.rgb);

	#elif MONO_ALGO == 3	//　輝度算出法（BT709:HDTV）
		Color.rgb *= 127.5f;
		Color.rgb = pow(Color.rgb, GAMMA);
		Color.rgb = pow(dot(LumiFactor, Color.rgb), 1.0 / GAMMA);
		Color.rgb /= 127.5f;
	#endif
#endif
	
	//　RGB各色の値から補正後の値をテクスチャから読み込む
//	Color.r = tex2D( ToneSamp, float2(Color.r * (254.0/255.0) + (0.5/255.0), 0.5)).r;
	Color.r = tex2D( ToneSamp, float2(Color.r * 0.99607843 + 0.00196, 0.5)).r;
	Color.g = tex2D( ToneSamp, float2(Color.g * 0.99607843 + 0.00196, 0.5)).g;
	Color.b = tex2D( ToneSamp, float2(Color.b * 0.99607843 + 0.00196, 0.5)).b;

	//　色調補正量を暗さに比例させて合成
    Color.rgb = lerp(Color.rgb, lerp(Color.rgb * ColorFilter.rgb * ObjXYZ, Color.rgb, Color.rgb), Color.a);

	//　アクセサリの不透明度を元にオリジナルと合成
	return lerp(ColorOrg, Color, alpha);
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
technique Diffusion <
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
