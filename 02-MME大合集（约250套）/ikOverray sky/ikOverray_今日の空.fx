//パラメータ

//-----------------------------------------------------------------------------
// ライト色を使う。
// ライト色を使う場合、グラデ指定はできない。
#define USE_LIGHT_COLOR			1

// 独自のライト色を指定する場合の色指定：
// 光源側のライト色
#define LIGHT__COLOR				float4(1.0, 1.0, 1.0, 1)
// 端のほうのライト色
#define LIGHT_FALLOFF_COLOR			float4(0.0, 0.0, 1.0, 1)

// 合成モード
//#define COLOR_MODE			0		// 加算：光を足しこむ
//#define COLOR_MODE			1		// 乗算：暗くなる
//#define COLOR_MODE			2		// オーバーレイ：明るいときは足し、暗いときは乗算
//#define COLOR_MODE			3		// 塗りつぶし：フォグなどに使う。
#define COLOR_MODE			0

// 光源タイプ
// 0:平行グラデ、1:円形グラデ、2:球状グラデ
#define LIGHT_TYPE		0

// Rxで指定した角度をライトの方向とみなす。
// 光源タイプが平行グラデ(0)のときのみ有効。
#define USE_RX_AS_DIRECTION		0

// 奥行きの最大値。これ以上奥は奥行きによるライトの影響が変化しない。
#define	MAX_DISTANCE	2000

// 奥行き情報をボカす量。0:ボカしなし。
float BlurSize = 3;


// バッファサイズ。2のべき乗(1,2,4など)にする。
// 大きい数値ほどボケる。画質を犠牲に計算が速くなる。
#define BUFFER_SCALE	2

// ガンマ補正を行う
//#define ENABLE_GAMMA_CORRECT

//******************設定はここまで
////////////////////////////////////////////////////////////////////////////////////////////////

#define	PI	(3.14159265359)

// エフェクト全体の強度
// 0: エフェクトオフ、1：標準、>1、強調。強度が高いと白飛びします。
float LightScale : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
// ライトの減衰率(フォールオフの強さ)
// 0: グラデが長くなる、1: グラデが短くなる
float LightScale2 : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;

// 奥行きの影響をどの程度受けるか?
// 0:受けない(奥行きを無視してすべてがライトの影響を受ける)、
// 1:受ける(奥にあるものほどライトの影響を受ける)
float DepthRate : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;

// 1にするとテストモード
float TestMode : CONTROLOBJECT < string name = "(self)"; string item = "Z"; >;

// ライト方向の影響をどれだけ受けるか?
// 1: 受けない(光源と反対方向も明るくなる)、
// 0: 受ける(光源の反対は暗いまま)
float LightRateRy : CONTROLOBJECT < string name = "(self)"; string item = "Ry"; >;
static float LightRate = 1.0 - saturate(LightRateRy * (180.0 / PI));

// 偽光源の方向。USE_RX_AS_DIRECTIONが1のときのみ有効。
// 0で12時方向(上から)、90で3時方向(右)となる。
float LightAngle : CONTROLOBJECT < string name = "(self)"; string item = "Rx"; >;

// エフェクトの強度
float EffectIntensity : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;


////////////////////////////////////////////////////////////////////////////////////////////////


//テクスチャフォーマット
#define TEXFORMAT "D3DFMT_R16F"
// #define TEXFORMAT "D3DFMT_R32F"

#define TEXBUFFRATE {1.0/BUFFER_SCALE, 1.0/BUFFER_SCALE}

#if defined(USE_LIGHT_COLOR) && USE_LIGHT_COLOR > 0
#define	LightColorT			LightAmbient
#define	LightColorB			LightAmbient
#else
#define	LightColorT			LIGHT__COLOR
#define	LightColorB			LIGHT_FALLOFF_COLOR
#endif


////////////////////////////////////////////////////////////////////////////////////////////////


// ぼかし処理の重み係数：
//	ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//	(WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize.xy);

float3	CameraPosition	: POSITION  < string Object = "Camera"; >;
float4x4 matP		: PROJECTION;
float4x4 matV		: VIEW;
float4x4 matVP		: VIEWPROJECTION;
float4x4 matVPInv	: VIEWPROJECTIONINVERSE;

float3	LightPosition	: POSITION  < string Object = "Light"; >;
float3	LightDirection	: DIRECTION < string Object = "Light"; >;
float3	LightDiffuse	: DIFFUSE   < string Object = "Light"; >;
float3	LightAmbient	: AMBIENT   < string Object = "Light"; >;

static float2 SampStep = (float2(BlurSize, BlurSize) / ViewportSize.xx);

// レンダリングターゲットのクリア値
float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;


// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	int MipLevels = 1;
	string Format = "D3DFMT_A16B16G16R16F";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	string Format = "D24S8";
>;

//
texture2D ScnMap1 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
>;
sampler2D ScnSamp1 = sampler_state {
	texture = <ScnMap1>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
>;
sampler2D ScnSamp2 = sampler_state {
	texture = <ScnMap2>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
	int MipLevels = 1;
	float2 ViewportRatio = TEXBUFFRATE;
	string Format = TEXFORMAT;
>;
sampler2D ScnSamp3 = sampler_state {
	texture = <ScnMap3>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

//-----------------------------------------------------------------------------
#if defined(ENABLE_GAMMA_CORRECT)
const float gamma = 2.2;
const float epsilon = 1.0e-6;
inline float3 Degamma(float3 col) { return pow(max(col,epsilon), gamma); }
inline float3 Gamma(float3 col) { return pow(max(col,epsilon), 1.0/gamma); }
inline float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
inline float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }
#else
inline float3 Degamma(float3 col) { return col; }
inline float3 Gamma(float3 col) { return col; }
inline float4 Degamma4(float4 col) { return col; }
inline float4 Gamma4(float4 col) { return col; }
#endif

inline float rgb2gray(float3 rgb)
{
	return dot(float3(0.299, 0.587, 0.114), rgb);
}

//-----------------------------------------------------------------------------
// 深度マップ
//-----------------------------------------------------------------------------
texture LinearDepthMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikLinearDepth.fx";
	float4 ClearColor = { MAX_DISTANCE, 0, 0, 1 };
	float2 ViewportRatio = TEXBUFFRATE;
	float ClearDepth = 1.0;
	string Format = TEXFORMAT;
	bool AntiAlias = true;
	string DefaultEffect = 
		"self = hide;"
		"* = ikLinearDepth.fx";
>;

sampler DepthMap = sampler_state {
	texture = <LinearDepthMapRT>;
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};




//-----------------------------------------------------------------------------
// 固定定義
//-----------------------------------------------------------------------------
struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float2 TexCoord		: TEXCOORD0;
	float2 TexCoord2	: TEXCOORD1;
	float4 LPos			: TEXCOORD2;
};


//-----------------------------------------------------------------------------
// 共通のVS
VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex + ViewportOffset.xy;
	Out.TexCoord2 = Tex + BUFFER_SCALE * ViewportOffset.xy;

	return Out;
}

VS_OUTPUT VS_SetTexCoordHalf( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	Out.TexCoord = Tex + BUFFER_SCALE * ViewportOffset.xy;
	return Out;
}


VS_OUTPUT VS_SetLightPos( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0; 

	Out.Pos = Pos;
	Out.TexCoord = Tex + BUFFER_SCALE * ViewportOffset.xy;
	Out.TexCoord2 = Tex + BUFFER_SCALE * ViewportOffset.xy;
	Out.LPos = mul( -LightDirection * 100, matVP);
	return Out;
}


//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
float4 Blur(sampler2D Samp, float2 TexCoord, float2 Offset)
{
	float Color;
	float Color0 = tex2D( Samp, TexCoord );
	Color  = WT_0 * Color0;
	Color += WT_1 * ( tex2D( Samp, TexCoord+Offset  ) + tex2D( Samp, TexCoord-Offset  ) );
	Color += WT_2 * ( tex2D( Samp, TexCoord+Offset*2) + tex2D( Samp, TexCoord-Offset*2) );
	Color += WT_3 * ( tex2D( Samp, TexCoord+Offset*3) + tex2D( Samp, TexCoord-Offset*3) );
	Color += WT_4 * ( tex2D( Samp, TexCoord+Offset*4) + tex2D( Samp, TexCoord-Offset*4) );
	Color += WT_5 * ( tex2D( Samp, TexCoord+Offset*5) + tex2D( Samp, TexCoord-Offset*5) );
	Color += WT_6 * ( tex2D( Samp, TexCoord+Offset*6) + tex2D( Samp, TexCoord-Offset*6) );
	Color += WT_7 * ( tex2D( Samp, TexCoord+Offset*7) + tex2D( Samp, TexCoord-Offset*7) );

	return float4(Color.xxx,1);
}


//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------
float4 PS_DrawFog( VS_OUTPUT IN ) : COLOR
{
	float depth = tex2D( DepthMap, IN.TexCoord2).r;
	depth = saturate(depth / MAX_DISTANCE) * DepthRate + (1.0 - DepthRate);

	float2 PPos = (IN.TexCoord - 0.5) / float2(0.5, -0.5);

	// 光源の向きによる影響
#if LIGHT_TYPE < 2
	float2 LPos = IN.LPos.xy / IN.LPos.w;
	PPos.x *= (ViewportSize.x / ViewportSize.y);
	LPos.x *= (ViewportSize.x / ViewportSize.y);

	#if LIGHT_TYPE == 0
		// 平行グラデ
		#if defined(USE_RX_AS_DIRECTION) && USE_RX_AS_DIRECTION > 0
			// 方向指定あり
			float2 L = float2(sin(LightAngle), cos(LightAngle));
		#else
			float2 L = normalize(LPos.xy);
		#endif
		float rot = PPos.x * L.x + PPos.y * L.y;
				// PPos.x * L.y + PPos.y * L.x;
		// 画面中心が0.5になるように調整
		float lightPower = rot * 0.25 + 0.5;
	#else
		// 円形グラデ
		float dist = distance(PPos.xy, LPos.xy);
		float lightPower = max(1.0 - dist / 5.1, 0);
		// lightPower = (lightPower > 0.5) ? 1 : 0;
	#endif

	// 光源の反対方向
	#if defined(USE_RX_AS_DIRECTION) && USE_RX_AS_DIRECTION > 0
	#else
		lightPower *= saturate(IN.LPos.z / 100.0);
	#endif

#else
	// 太陽の向きと視線の内積
	float4 ProjPos = float4(PPos.xy, 1, 1);
	float3 V = normalize(mul(ProjPos, matVPInv));
	float lightPower = saturate(dot(V, -LightDirection));
#endif

	lightPower = lightPower * LightRate + (1.0 - LightRate);
	lightPower = max(lightPower - (1.0 - lightPower) * LightScale2, 0);

	// 奥行きによる影響
	lightPower *= depth;

	float4 Color = float4(saturate(lightPower * LightScale * 0.1), 0, 0, 1);
	return Color;

}

//-----------------------------------------------------------------------------
// X Blur
//-----------------------------------------------------------------------------
float4 PS_passX( VS_OUTPUT IN ) : COLOR
{
	return Blur(ScnSamp1, IN.TexCoord, float2(SampStep.x  ,0));
}

//-----------------------------------------------------------------------------
// Y Blur
//-----------------------------------------------------------------------------
float4 PS_passY( VS_OUTPUT IN ) : COLOR
{
	return Blur(ScnSamp2, IN.TexCoord, float2(0 , SampStep.y));
}



//-----------------------------------------------------------------------------
// 最後に元画面と計算結果を合成する
float4 PS_Last( VS_OUTPUT IN ) : COLOR
{
	float4 BaseColor = Degamma4(max(tex2D( ScnSamp, IN.TexCoord ), 0));
	float4 Color = BaseColor;
	float fogBlur = tex2D( ScnSamp3, IN.TexCoord2).r;
	float fog = tex2D( ScnSamp1, IN.TexCoord2).r;
	fog = max(fog, fogBlur);

	float3 light = lerp(LightColorB, LightColorT, fog);

	#if !defined(COLOR_MODE) || COLOR_MODE == 0
		// 加算
		Color.rgb = Color.rgb + light * fog;
	#elif COLOR_MODE == 1
		// 乗算
		Color.rgb = lerp(Color.rgb, Color.rgb * light, 1.0 - fog);
	#elif COLOR_MODE == 2
		// オーバーレイ
		Color.rgb = (fog < 0.5)
			? lerp(Color.rgb * light, Color.rgb, fog * 2.0)
			: (Color.rgb + light * ((fog - 0.5) * 2.0));
	#else
		// 塗りつぶし
		Color.rgb = lerp(Color.rgb, light, fog);
	#endif

	Color.rgb = lerp(BaseColor.rgb, Color.rgb, EffectIntensity);

	// テストモード
	if (TestMode > 0.5) Color.rgb = float3(fog.x, fogBlur, rgb2gray(Color.rgb));

	return float4(Gamma(Color.rgb), 1);

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

		"RenderColorTarget0=ScnMap1;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DrawFog;"

		"RenderColorTarget0=ScnMap2;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=Gaussian_X;"

		"RenderColorTarget0=ScnMap3;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=Gaussian_Y;"

		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=LastPass;"
	;
> {
	pass DrawFog < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetLightPos();
		PixelShader  = compile ps_3_0 PS_DrawFog();
	}

	pass Gaussian_X < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoordHalf();
		PixelShader  = compile ps_3_0 PS_passX();
	}
	pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoordHalf();
		PixelShader  = compile ps_3_0 PS_passY();
	}
	pass LastPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord();
		PixelShader  = compile ps_3_0 PS_Last();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
