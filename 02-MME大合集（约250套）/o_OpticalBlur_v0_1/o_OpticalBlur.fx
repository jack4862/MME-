//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　光学風ぼかしフィルタ（試作） v0.1
//　　　by おたもん（user/5145841）
//
//　　　※このフィルタはデータＰの LargeBlur を参考にしております
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　ユーザーパラメータ

//　知覚的ブラーの使用（ 0: 一般的な処理（対数的）、1: 光量を考慮した処理（指数的））
#define USE_EXPONENTIAL 1

//　非透過モード（ 0: 透明部分はそのまま出力、1: 透明部分を白背景として出力）
#define NON_TRANSPARENT 0

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　初期定義

//　レンダリングターゲットのクリア値
#if NON_TRANSPARENT
float4 ClearColor = {1,1,1,1};			//{赤, 緑, 青, 不透明 1 固定}
#else
float4 ClearColor = {0.5, 0.5, 0.5, 0};	//{赤, 緑, 青, 透明 0 固定}
#endif
float ClearDepth  = 1.0;

//　ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

//　アクセサリ操作設定値を取得
float Alpha : CONTROLOBJECT <string name="(self)"; string item="Tr";>;

float Si : CONTROLOBJECT <string name="(self)"; string item="Si";>;
static const float Scale = Si*0.1;
static const float MipSize = log2(Scale);

float ObjX : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
static const float Overflow = ObjX + 1.0f;

//　スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static const float2 PixelSize = (float2(1.0,1.0)/(ViewportSize));
static const float AspectRatio = (ViewportSize.x / ViewportSize.y);

//　深度バッファ
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 0;
#if USE_EXPONENTIAL == 1
	string Format = "A16B16G16R16F";
#endif
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 0;
#if USE_EXPONENTIAL == 1
	string Format = "A16B16G16R16F";
#endif
>;
sampler2D ScnSamp2 = sampler_state {
	texture = <ScnMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

//　マクロ定義
	//指数・対数変換時の底
#define RADIX (128*Scale*Overflow)

#define toExp(x) pow(RADIX,x)
#define toLog(x) (log(x)/log(RADIX))

#define	WT_0	0.0920246
#define	WT_1	0.0902024
#define	WT_2	0.0849494
#define	WT_3	0.0768654
#define	WT_4	0.0668236
#define	WT_5	0.0558158
#define	WT_6	0.0447932
#define	WT_7	0.0345379

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　汎用VS
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

struct BLUR_DATA		// ガウスブラー 半径7
{
	float4 Pos:POSITION;
	float2 Tex:TEXCOORD0;
	float4 T1:TEXCOORD1;
	float4 T2:TEXCOORD2;
	float4 T3:TEXCOORD3;
	float4 T4:TEXCOORD4;
	float4 T5:TEXCOORD5;
	float4 T6:TEXCOORD6;
	float4 T7:TEXCOORD7;
};

BLUR_DATA BlurVS(float4 Pos:POSITION, float2 Tex:TEXCOORD0, uniform float2 dir)
{
	float blurStep = Scale * 0.5 * PixelSize.x ;
	BLUR_DATA Out;

	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	Out.T1.xy = Out.Tex + 1.0 * blurStep * dir;
	Out.T1.zw = Out.Tex - 1.0 * blurStep * dir;
	Out.T2.xy = Out.Tex + 2.0 * blurStep * dir;
	Out.T2.zw = Out.Tex - 2.0 * blurStep * dir;
	Out.T3.xy = Out.Tex + 3.0 * blurStep * dir;
	Out.T3.zw = Out.Tex - 3.0 * blurStep * dir;
	Out.T4.xy = Out.Tex + 4.0 * blurStep * dir;
	Out.T4.zw = Out.Tex - 4.0 * blurStep * dir;
	Out.T5.xy = Out.Tex + 5.0 * blurStep * dir;
	Out.T5.zw = Out.Tex - 5.0 * blurStep * dir;
	Out.T6.xy = Out.Tex + 6.0 * blurStep * dir;
	Out.T6.zw = Out.Tex - 6.0 * blurStep * dir;
	Out.T7.xy = Out.Tex + 7.0 * blurStep * dir;
	Out.T7.zw = Out.Tex - 7.0 * blurStep * dir;

	return Out;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　X方向ぼかし（RGBの指数処理つき）

float4 PS_passX(float2 T0:TEXCOORD0, float4 T1:TEXCOORD1,
				float4 T2:TEXCOORD2, float4 T3:TEXCOORD3,
				float4 T4:TEXCOORD4, float4 T5:TEXCOORD5,
				float4 T6:TEXCOORD6, float4 T7:TEXCOORD7):COLOR
{
#if USE_EXPONENTIAL == 1
	float4 Color;
	Color.rgb =   WT_0 * toExp(tex2Dlod(ScnSamp, float4(T0   ,0,MipSize)).rgb)
				+ WT_1 * toExp(tex2Dlod(ScnSamp, float4(T1.xy,0,MipSize)).rgb)
				+ WT_1 * toExp(tex2Dlod(ScnSamp, float4(T1.zw,0,MipSize)).rgb)
				+ WT_2 * toExp(tex2Dlod(ScnSamp, float4(T2.xy,0,MipSize)).rgb)
				+ WT_2 * toExp(tex2Dlod(ScnSamp, float4(T2.zw,0,MipSize)).rgb)
				+ WT_3 * toExp(tex2Dlod(ScnSamp, float4(T3.xy,0,MipSize)).rgb)
				+ WT_3 * toExp(tex2Dlod(ScnSamp, float4(T3.zw,0,MipSize)).rgb)
				+ WT_4 * toExp(tex2Dlod(ScnSamp, float4(T4.xy,0,MipSize)).rgb)
				+ WT_4 * toExp(tex2Dlod(ScnSamp, float4(T4.zw,0,MipSize)).rgb)
				+ WT_5 * toExp(tex2Dlod(ScnSamp, float4(T5.xy,0,MipSize)).rgb)
				+ WT_5 * toExp(tex2Dlod(ScnSamp, float4(T5.zw,0,MipSize)).rgb)
				+ WT_6 * toExp(tex2Dlod(ScnSamp, float4(T6.xy,0,MipSize)).rgb)
				+ WT_6 * toExp(tex2Dlod(ScnSamp, float4(T6.zw,0,MipSize)).rgb)
				+ WT_7 * toExp(tex2Dlod(ScnSamp, float4(T7.xy,0,MipSize)).rgb)
				+ WT_7 * toExp(tex2Dlod(ScnSamp, float4(T7.zw,0,MipSize)).rgb);

	//　透明度は指数化処理を行わない
	Color.a =     WT_0 * tex2Dlod(ScnSamp, float4(T0   ,0,MipSize)).a
				+ WT_1 * tex2Dlod(ScnSamp, float4(T1.xy,0,MipSize)).a
				+ WT_1 * tex2Dlod(ScnSamp, float4(T1.zw,0,MipSize)).a
				+ WT_2 * tex2Dlod(ScnSamp, float4(T2.xy,0,MipSize)).a
				+ WT_2 * tex2Dlod(ScnSamp, float4(T2.zw,0,MipSize)).a
				+ WT_3 * tex2Dlod(ScnSamp, float4(T3.xy,0,MipSize)).a
				+ WT_3 * tex2Dlod(ScnSamp, float4(T3.zw,0,MipSize)).a
				+ WT_4 * tex2Dlod(ScnSamp, float4(T4.xy,0,MipSize)).a
				+ WT_4 * tex2Dlod(ScnSamp, float4(T4.zw,0,MipSize)).a
				+ WT_5 * tex2Dlod(ScnSamp, float4(T5.xy,0,MipSize)).a
				+ WT_5 * tex2Dlod(ScnSamp, float4(T5.zw,0,MipSize)).a
				+ WT_6 * tex2Dlod(ScnSamp, float4(T6.xy,0,MipSize)).a
				+ WT_6 * tex2Dlod(ScnSamp, float4(T6.zw,0,MipSize)).a
				+ WT_7 * tex2Dlod(ScnSamp, float4(T7.xy,0,MipSize)).a
				+ WT_7 * tex2Dlod(ScnSamp, float4(T7.zw,0,MipSize)).a;
#else
	float4 Color = WT_0 * tex2Dlod(ScnSamp, float4(T0  ,0,MipSize))
				+ WT_1 * tex2Dlod(ScnSamp, float4(T1.xy,0,MipSize))
				+ WT_1 * tex2Dlod(ScnSamp, float4(T1.zw,0,MipSize))
				+ WT_2 * tex2Dlod(ScnSamp, float4(T2.xy,0,MipSize))
				+ WT_2 * tex2Dlod(ScnSamp, float4(T2.zw,0,MipSize))
				+ WT_3 * tex2Dlod(ScnSamp, float4(T3.xy,0,MipSize))
				+ WT_3 * tex2Dlod(ScnSamp, float4(T3.zw,0,MipSize))
				+ WT_4 * tex2Dlod(ScnSamp, float4(T4.xy,0,MipSize))
				+ WT_4 * tex2Dlod(ScnSamp, float4(T4.zw,0,MipSize))
				+ WT_5 * tex2Dlod(ScnSamp, float4(T5.xy,0,MipSize))
				+ WT_5 * tex2Dlod(ScnSamp, float4(T5.zw,0,MipSize))
				+ WT_6 * tex2Dlod(ScnSamp, float4(T6.xy,0,MipSize))
				+ WT_6 * tex2Dlod(ScnSamp, float4(T6.zw,0,MipSize))
				+ WT_7 * tex2Dlod(ScnSamp, float4(T7.xy,0,MipSize))
				+ WT_7 * tex2Dlod(ScnSamp, float4(T7.zw,0,MipSize));
#endif

	return Color;
}

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//　Y方向ぼかし（RGBの対数処理あり）

float4 PS_passY(float2 T0:TEXCOORD0, float4 T1:TEXCOORD1,
				float4 T2:TEXCOORD2, float4 T3:TEXCOORD3,
				float4 T4:TEXCOORD4, float4 T5:TEXCOORD5,
				float4 T6:TEXCOORD6, float4 T7:TEXCOORD7) : COLOR
{   
	float4 Color= WT_0 *  tex2D(ScnSamp2, T0)
				+ WT_1 * (tex2D(ScnSamp2, T1.xy) + tex2D(ScnSamp2, T1.zw))
				+ WT_2 * (tex2D(ScnSamp2, T2.xy) + tex2D(ScnSamp2, T2.zw))
				+ WT_3 * (tex2D(ScnSamp2, T3.xy) + tex2D(ScnSamp2, T3.zw))
				+ WT_4 * (tex2D(ScnSamp2, T4.xy) + tex2D(ScnSamp2, T4.zw))
				+ WT_5 * (tex2D(ScnSamp2, T5.xy) + tex2D(ScnSamp2, T5.zw))
				+ WT_6 * (tex2D(ScnSamp2, T6.xy) + tex2D(ScnSamp2, T6.zw))
				+ WT_7 * (tex2D(ScnSamp2, T7.xy) + tex2D(ScnSamp2, T7.zw));

#if USE_EXPONENTIAL == 1
	Color.rgb = toLog(Color.rgb);
#endif

	//　合成比率とアクセサリの不透明度を元にオリジナルと合成
	return lerp(tex2D(ScnSamp, T0), Color, Alpha);
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
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
		"Pass=Gaussian_Y;"
	;
> {
	pass Gaussian_X < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 BlurVS(float2(1,0));
		PixelShader  = compile ps_3_0 PS_passX();
	}
	pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 BlurVS(float2(0,AspectRatio));
		PixelShader  = compile ps_3_0 PS_passY();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
