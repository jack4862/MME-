//=============================================================================
// ikBokeh.fx
// ポストプロセスで被写界深度のエミュレートを行う。
//=============================================================================

// 強制的に玉ボケのサイズをスケーリングする。1:等倍(デフォルト)、2:2倍になる。
// 別途設定されているサイズ上限を超えることはない。
#define FORCE_COC_SCALE		(1.0)

// 前ボケの大きさ。0.1～1.0。0に近づけることで前ボケを小さくする
#define FRONT_BOKEH_SCALE		(1.0)

// 外部から制御するコントローラの名前
#define CONTROLLER_NAME		"ikBokehController.pmx"

// オートフォーカスの基準位置
// 通常はアクセサリにのままにしておき、アクセサリをピントを合わせたいボーンにぶら下げる。
//#define	AF_MODEL_NAME	"ikBokeh.x"
#define	AF_MODEL_NAME	"(self)"
//#define	AF_BONE_NAME	"頭"

// テストモード有効設定。
// ENABLE_TEST_MODEが1のとき、モーフのテストモードを1にすることでピント表示を行う。
#define	ENABLE_TEST_MODE		1

// 時間の同期：編集中もズーム時間を考慮するか?
#define	TimeSync		0

// コントローラが無い場合の測距モードの値
// 0: アクセサリの位置
// 1: 画面中央(狭)にピントを合わせる
// 2: 画面中央(広)にピントを合わせる
#define	DEFAULT_MEASURING_MODE	0

// 玉ボケの強調：玉ボケDOF(Elle/データP)から借用
#define ENABLE_EMPHASIZE_COLOR	1
// 最大強調度合
#define EMPHASIZE_RATE	2

// TEST: v18以降の計算式を使う。0ならv17以前の計算式を使う。
#define USE_V18_METHOD	1

// 縮小バッファを追加するかどうか。
// (もう一段小さいバッファでもブラーを掛ける。より大きいボケを再現できる)
#define ENABLE_EXTRA_LEVEL	0


//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// ピントのあっている範囲をゆるくする。(0～1.0)
#define PINT_MARGIN		1.0

// 1回でボカすサイズ (6-8程度。小さいほど高速。)
#define BULR_SIZE		8

// テクスチャフォーマット
//	HDRを使うなら、浮動小数点である必要がある。
//#define TEXFORMAT "A32B32G32R32F"
#define TEXFORMAT "A16B16G16R16F"
//#define TEXFORMAT "A8R8G8B8"

// 計算用テクスチャのフォーマット
//	浮動小数点でないと計算結果を維持できない。
#define WORK_TEXFORMAT "A16B16G16R16F"


// 単位調整用の変数。
//#define		m	(1/0.1)	// 1MMD単位 = 10cm。本来は8cm程度?
#define		m	(1/0.08)	// 1MMD単位 ≒ 8cm
#define		cm	(m * 0.01)
#define		mm	(m * 0.001)

#define	PI	(3.14159265359)
#define RAD2DEG(x)	((x) * 180 / PI)
#define DEG2RAD(x)	((x) * PI / 180)
#define LOG2_E	(1.44269504089)		// log(e)/log(2)

// コントローラのモーフで設定したパラメータのスケール値
#define AbsoluteFocusScale		(50.0 * m)		// 絶対ピント距離係数(m)
#define RelativeFocusScale		(5.0 * m)		// 相対ピント距離係数(m)
#define FocalLengthScale		(100.0 * mm)	// 焦点距離係数(mm)
#define DefaultFNumber			4.0				// デフォルトの絞り
#define FNumberScale			4.0				// 絞り係数
#define BokehFocalLengthScale	(50.0 * mm)		// ボケ調整時の焦点距離係数(mm)

// 内部的な制限
const float MinFocusDistance = (0.1 * m);
const float MinFocalLength = (20.0 * mm);
const float MaxFocalLength = (200.0 * mm);
const float MinFNumber = 1.0;
const float MaxFNumber = 16.0;

// フィルムサイズ。35mmフィルムだと24x36mm
const float FilmSize = 24 * mm;

// なにも描画しない場合の背景までの距離
// これを弄るより普通にスカイドームなどの背景をおいたほうがいい。
// 弄る場合、ikDepth.fxの同名の値も変更する必要がある。
#define FAR_DEPTH		1000

//****************** 設定はここまで

float4x4 matV : VIEW;
float4x4 matP : PROJECTION;
float3 CameraPosition	: POSITION  < string Object = "Camera"; >;

float time1 : TIME;
float time2 : TIME < bool SyncInEditMode = true; >;
static float time = TimeSync ? time2 : time1;
float elapsed_time1 : ELAPSEDTIME;
float elapsed_time2 : ELAPSEDTIME < bool SyncInEditMode = true; >;
static float Dt = clamp(TimeSync ? elapsed_time2 : elapsed_time1, 1.0/120.0, 1.0/15.0);

#ifdef AF_BONE_NAME
float3 AFPosition : CONTROLOBJECT < string name = AF_MODEL_NAME; string item = AF_BONE_NAME; >;
#else
float3 AFPosition : CONTROLOBJECT < string name = AF_MODEL_NAME; >;
#endif

#define DECLARE_PARAM(_t,_var,_item)	\
	_t _var : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = _item;>;

// 外部コントローラ
bool isExistController : CONTROLOBJECT < string name = CONTROLLER_NAME; >;

DECLARE_PARAM(float3, mCtrlPosition, "全ての親");
DECLARE_PARAM(float, mPintDistanceP, "ピント距離+");
DECLARE_PARAM(float, mPintDistanceM, "ピント距離-");
DECLARE_PARAM(float, mPintDelayParam, "ピント遅延");
DECLARE_PARAM(float, mPintSlip, "ピント滑り");
static float mPintDelay = (isExistController || DEFAULT_MEASURING_MODE ==0) ? mPintDelayParam : 0.5;

DECLARE_PARAM(float, mMeasuringXP, "測距点x+");
DECLARE_PARAM(float, mMeasuringXM, "測距点x-");
DECLARE_PARAM(float, mMeasuringYP, "測距点y+");
DECLARE_PARAM(float, mMeasuringYM, "測距点y-");
float2 CalcMeasuringPosition()
{
	float2 basePos = float2(mMeasuringXP - mMeasuringXM, mMeasuringYP - mMeasuringYM) * 0.5 + 0.5;
	float2 offset = mCtrlPosition.xy * float2(1, -1) * 0.1;
	return basePos + offset;
}
static float2 mMeasuringPosition = CalcMeasuringPosition();

//DECLARE_PARAM(float, mFNumber, "絞り");
DECLARE_PARAM(float, mFocusRange, "ピント幅");
DECLARE_PARAM(float, mBokehP, "ボケ+");
DECLARE_PARAM(float, mBokehM, "ボケ-");
DECLARE_PARAM(float, mFBokehM, "前ボケ-");
DECLARE_PARAM(float, mCoCSize, "CoCサイズ");
DECLARE_PARAM(float, mEmphasize, "玉ボケ強調");

DECLARE_PARAM(float, mTestMode, "テストモード");

DECLARE_PARAM(float, mAFModeParam, "AF測距モード");
static int mAFMode = (isExistController) ? (int)(mAFModeParam * 3.0 + 0.1) : DEFAULT_MEASURING_MODE;
DECLARE_PARAM(float, mManualMode, "マニュアルモード");
DECLARE_PARAM(float, mPintDistance, "ピント距離");
DECLARE_PARAM(float, mFocalLength, "焦点距離");

bool bLinearMode : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float ForceCoCSacle = FORCE_COC_SCALE * AcsSi * 0.1 * (mCoCSize + 1.0);


//=============================================================================

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

#define ScreenScale		1
#define MinimumCoCRadius	1.0		// CoCの最低保証値。小さすぎると発散する。

// ボケの半径上限
#define MAX_COC_SIZE	((BULR_SIZE) * 8)

// ワーク用テクスチャの設定
#define FILTER_MODE			MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
#define LINEAR_FILTER_MODE	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
//#define ADDRESSING_MODE		AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
#define ADDRESSING_MODE		AddressU = CLAMP; AddressV = CLAMP;

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5) /(ScreenScale * ViewportSize.xy));
static float2 SampleStep = (float2(1.0,1.0) / (ScreenScale * ViewportSize.xy));
static float2 AspectRatio = float2(ViewportSize.x / ViewportSize.y, 1);

// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
	bool AntiAlias = false;
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	string Format = TEXFORMAT;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	FILTER_MODE
	ADDRESSING_MODE
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	string Format = "D24S8";
>;

#define DECL_TEXTURE( _map, _samp, _size) \
	texture2D _map : RENDERCOLORTARGET < \
		bool AntiAlias = false; \
		float2 ViewportRatio = {ScreenScale * 1.0/(_size), ScreenScale * 1.0/(_size)}; \
		string Format = WORK_TEXFORMAT; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		FILTER_MODE	ADDRESSING_MODE \
	}; \
	sampler2D _samp##Linear = sampler_state { \
		texture = <_map>; \
		LINEAR_FILTER_MODE	ADDRESSING_MODE \
	};

DECL_TEXTURE( DownscaleMap0, DownscaleSamp0, 1)
DECL_TEXTURE( DownscaleMap1, DownscaleSamp1, 2)
DECL_TEXTURE( DownscaleMap2, DownscaleSamp2, 4)
DECL_TEXTURE( DownscaleMap3, DownscaleSamp3, 8)

DECL_TEXTURE( BlurMap0, BlurSamp0, 1)
DECL_TEXTURE( BlurMap1, BlurSamp1, 2)
DECL_TEXTURE( BlurMap2, BlurSamp2, 4)
DECL_TEXTURE( BlurMap3, BlurSamp3, 8)

DECL_TEXTURE( BlurMapF0, BlurSampF0, 1)
DECL_TEXTURE( BlurMapF1, BlurSampF1, 2)
DECL_TEXTURE( BlurMapF2, BlurSampF2, 4)
DECL_TEXTURE( BlurMapF3, BlurSampF3, 8)
// F:Front(前ボケ) / B:Back(後ボケ)

#if ENABLE_EXTRA_LEVEL > 0
DECL_TEXTURE( DownscaleMap4, DownscaleSamp4,16)
DECL_TEXTURE( BlurMap4, BlurSamp4,16)
DECL_TEXTURE( BlurMapF4, BlurSampF4,16)
#endif

// 自動焦点用の情報。フレームを超えて情報をやりとりする。
texture2D AutoFocusTex : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	string Format="A32B32G32R32F";
>;
sampler2D AutoFocusSmp = sampler_state {
	Texture = <AutoFocusTex>;
	ADDRESSING_MODE		FILTER_MODE
};
texture2D AutoFocusTex2 : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	string Format="A32B32G32R32F";
>;
sampler2D AutoFocusSmp2 = sampler_state {
	Texture = <AutoFocusTex2>;
	ADDRESSING_MODE		FILTER_MODE
};
texture AutoFocusDepthBuffer : RenderDepthStencilTarget <
	int2 Dimensions = {1,1};
	string Format = "D24S8";
>;



//-----------------------------------------------------------------------------
// 深度マップ
// 深度情報を格納
texture LinearDepthMapRT: OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikBokeh.fx";
	float4 ClearColor = { 1.0, 0, 0, 1 };
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	float ClearDepth = 1.0;
	string Format = "R16F";
	bool AntiAlias = false;
	string DefaultEffect = 
		"self = hide;"
		"ikBokeh*.* = hide;"
		"rgbm_*.x = depth_rgbm.fx;"	// スカイドーム
		"*.pm* = depth.fx;"
		"*.x = depth.fx;"
		"* = hide;";
>;

sampler DepthMap = sampler_state {
	texture = <LinearDepthMapRT>;
	AddressU = CLAMP;	AddressV = CLAMP;
	MinFilter = POINT;	MagFilter = POINT;	MipFilter = NONE;
};


//-----------------------------------------------------------------------------
// ガンマ補正
const float gamma = 2.2;
const float epsilon = 1.0e-4;
float3 Degamma(float3 col) { return (!bLinearMode) ? pow(max(col,epsilon), gamma) : col; }
float3 Gamma(float3 col) { return (!bLinearMode) ? pow(max(col,epsilon), 1.0/gamma) : col; }
float4 Degamma4(float4 col) { return float4(Degamma(col.rgb), col.a); }
float4 Gamma4(float4 col) { return float4(Gamma(col.rgb), col.a); }

float rgb2gray(float3 rgb) { return dot(float3(0.299, 0.587, 0.114), rgb); }

// 色の強調
#if ENABLE_EMPHASIZE_COLOR > 0
float CalcEmphasizeRate()
{
	float emphasizeRate = (saturate(mEmphasize) * EMPHASIZE_RATE + 1.0);
	return (mEmphasize <= 0.0) ? 0.0 : emphasizeRate;
}
float CalcDepreciateRate()
{
	// NOTE: >0 にしないと値を使わなくても、結果がNan(Inf?)になる。
	float emphasizeRate = max(CalcEmphasizeRate(), 1e-4);
	return (mEmphasize <= 0.0) ? 0.0 : (1.0 / emphasizeRate);
}
float3 EmphasizeColor(float3 col, float rate)
{
	return (rate > 0.0) ? pow(max(col, epsilon), rate) : col;
}
float3 DepreciateColor(float3 col, float rate)
{
	return (rate > 0.0) ? pow(max(col, epsilon), rate) : col;
}
#else
float CalcEmphasizeRate() { return 0; }
float CalcDepreciateRate() { return 0; }
float3 EmphasizeColor(float3 col, float rate) { return col; }
float3 DepreciateColor(float3 col, float rate) { return col; }
#endif


//-----------------------------------------------------------------------------
// どれだけボケるか

float GetTanFoV()
{
	return 1.0 / matP._22;
}

float CalcFNumber()
{
#if USE_V18_METHOD
	float f = DefaultFNumber + isExistController * ((mBokehM + 0.5 - mBokehP) * FNumberScale);
#else
	float f = DefaultFNumber + isExistController * ((mBokehM - mBokehP) * FNumberScale);
#endif
	return clamp(f, MinFNumber, MaxFNumber);
}

float CalcFocalLength(float focusDistance)
{
	float L = focusDistance;
	float h2 = FilmSize / 2.0;
	float focalA = (L * h2) / (GetTanFoV() * L + h2);

	float focalM = MinFocalLength + mFocalLength * FocalLengthScale;

	float focal = lerp(focalA, focalM, mManualMode);
	focal += (mBokehP - mBokehM) * BokehFocalLengthScale;
	return clamp(focal, MinFocalLength, MaxFocalLength);
}

// CoC計算用の係数を求める
// CoC(x) = V * D / L - V * D / x を C1 / x + C2 の形式にする。
float2 CalcCoCCoef(float focusDistance)
{
	float L = focusDistance;
	float f = CalcFocalLength(L);
	float F = CalcFNumber();
	float D = f / F;		// 有効径。
	float M = f / (L - f);	// 撮像倍率。
//	float V = L * M;		// 実効焦点距離
	float toPixel = ViewportSize.y / FilmSize; // ピクセル数に変換するための係数

#if USE_V18_METHOD // v18以降の計算式

	float CoCCoef1 = -L * M * D * toPixel;
	float CoCCoef2 =      M * D * toPixel;

#else // v17以前の計算式
	float s = (1.0 / F) * toPixel;
	float CoCCoef1 =-(L * f) / (L - f)        * s;
	float CoCCoef2 = (L      / (L - f) - 1.0) * s;

#endif

	return float2(CoCCoef1 * (1.0 / FAR_DEPTH), CoCCoef2);
}

float CalcBlurLevel(float2 coef, float depth)
{
	float CoC = coef.x / depth + coef.y;
	return clamp(CoC, -MAX_COC_SIZE, MAX_COC_SIZE);
}

float MeasuringCircleRadius()
{
	return (mAFMode > 1.5) ? 0.2 : 0.05;
}

float2 CoCBrightness(float2 coc)
{
	return saturate(1.0 / max(coc * coc, MinimumCoCRadius * MinimumCoCRadius));
}
float CoCBrightness(float coc)
{
	return saturate(1.0 / max(coc * coc, MinimumCoCRadius * MinimumCoCRadius));
}


//-----------------------------------------------------------------------------
//

float4 TestColor(float3 Color, float level, float2 uv)
{
	// テストモード
	#if ENABLE_TEST_MODE == 1
	if (mTestMode >= 0.5)
	{
		Color = saturate(rgb2gray(Color)) * 0.98 + 0.02; // 真っ黒い部分に色を乗せるためにゲタを履かせる。

		// 測距点の表示
		float r = length((uv - mMeasuringPosition) * AspectRatio);
		float mcr = MeasuringCircleRadius();
		if (mAFMode > 0.5 && r > mcr * 0.5 && r < mcr)
		{
			// 黄色にする
			Color.b = 0;
		}
		else
		{
			// ピントの合致度
			float threshold = 0.1;
			float radius = abs(level);
			float grad0 = (mTestMode >= 0.75) ? 1.0 : 0.1;
			float grad = saturate(Color.g - saturate(radius - 1));
			grad = lerp(Color.r, grad, saturate((radius - threshold) * grad0));
			float gradC = saturate(Color.r - (1.0 - radius / threshold));

			if (radius < threshold) Color.rg = gradC; // ジャスピン：青
			else if (level < 0.0) Color.g = grad; // 前ボケ：紫
			else if (level > 0.0) Color.rb = grad; // 後ボケ：緑
		}
	}
	#endif

	return float4(Color, 1);
}

//-----------------------------------------------------------------------------
//

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 TexCoord		: TEXCOORD0;
	float4 TexCoord1	: TEXCOORD1;
	float4 TexCoord2	: TEXCOORD2;
};

VS_OUTPUT VS_SetTexCoord( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;
	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4(-1,-1, -1, 1);
	Out.TexCoord2 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4( 1,-1,  1, 1);
	return Out;
}

VS_OUTPUT VS_SetTexCoord2( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;
	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1 = TexCoord.xyxy + Offset.xyxy * float4(-1,-1, -1, 1);
	Out.TexCoord2 = TexCoord.xyxy + Offset.xyxy * float4( 1,-1,  1, 1);
	return Out;
}

VS_OUTPUT VS_CalcCoC( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy;
	float2 Offset = SampleStep;
	Out.TexCoord = float4(TexCoord, Offset);
	// 距離計算用係数を求める
	float focusDistance = tex2Dlod(AutoFocusSmp2, float4(0.5,0.5, 0,0)).x;
	// 画角の変化に対してもピントの遅れを発生させる
	focusDistance /= GetTanFoV();
	Out.TexCoord1.xy = CalcCoCCoef(focusDistance);
	// CoCサイズの調整係数
	Out.TexCoord1.z = ForceCoCSacle;
	Out.TexCoord1.w = FRONT_BOKEH_SCALE * (1 - mFBokehM);
	// 色強調用の係数
	Out.TexCoord2.x = CalcEmphasizeRate();
	return Out;
}

VS_OUTPUT VS_Gather( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;
	Out.TexCoord = float4(TexCoord, Offset);
	Out.TexCoord1.x = CalcDepreciateRate();
	return Out;
}

//-----------------------------------------------------------------------------
// 自動測距

VS_OUTPUT VS_UpdateFocusDistance( float4 Pos : POSITION, float4 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	// Out.TexCoord = float4(Tex.xy, 0, 0);
	return Out;
}

// 合焦距離の取得
float CalcFocusDistance()
{
	// AFPositionの深度
	float fd = distance(AFPosition, CameraPosition);

	// 測距点セレクト/測距点オート
	float2 center = mMeasuringPosition;
	float r1 = MeasuringCircleRadius();
	float r2 = r1 * 0.714;
	// MEMO: AspectRatioを考慮していない
	float depthA0 = tex2D( DepthMap, float2(-r2,-r2) + center).x;
	float depthA1 = tex2D( DepthMap, float2(-r1,  0) + center).x;
	float depthA2 = tex2D( DepthMap, float2(-r2, r2) + center).x;
	float depthA3 = tex2D( DepthMap, float2(  0,-r1) + center).x;
	float depthA4 = tex2D( DepthMap, float2(  0,  0) + center).x;
	float depthA5 = tex2D( DepthMap, float2(  0, r1) + center).x;
	float depthA6 = tex2D( DepthMap, float2( r2,-r2) + center).x;
	float depthA7 = tex2D( DepthMap, float2( r1,  0) + center).x;
	float depthA8 = tex2D( DepthMap, float2( r2, r2) + center).x;
	if (mAFMode > 0.5)
	{
		float4 depthMin = min(
			float4(depthA0,depthA1,depthA2,depthA3),
			float4(depthA4,depthA5,depthA6,depthA7));
		depthMin.xy = min(depthMin.xy, depthMin.zw);
		fd = min(min(depthMin.x, depthMin.y), depthA8) * FAR_DEPTH;
	}

	// マニュアルフォーカス
	float fdM = mPintDistance * AbsoluteFocusScale;
	fd = lerp(fd, fdM, mManualMode);

	// 微調整分
	float pd = mPintDistanceP - mPintDistanceM;
	pd = (pd * pd) * sign(pd);
	float adjuster = pd * RelativeFocusScale + mCtrlPosition.z;
	fd = max(fd + adjuster, MinFocusDistance);

	return fd;
}


float4 PS_UpdateFocusDistance(float2 Tex: TEXCOORD0) : COLOR
{
	float depth0 = CalcFocusDistance();

	// 画角の変化に対してもピントの遅れを発生させる
	depth0 *= GetTanFoV();

	float4 data = tex2Dlod(AutoFocusSmp2, float4(0.5,0.5,0,0));
	float depth1 = data.x;
	float velocity = data.y;
	float prevTime = data.z;	// 前回との時間が大幅に違ったら初期化する?

	// 0フレ目なら初期化
	if (time < 1.0 / 120.0)
	{
		depth1 = depth0;
		velocity = 0;
	}

	// 減速
	velocity = velocity * pow(max(0.8 * mPintSlip, 1e-4), Dt * 30.0);
	float v = depth0 - (depth1 + velocity);
	// 手前ほど距離合わせは高速になる
	float speed = min(abs(v), clamp(35000.0 / depth0, 50.0, 1000.0) * 30.0 * Dt);
	velocity += sign(v) * speed * (1.0 - mPintDelay);
	depth1 += velocity;

	depth1 = max(depth1, MinFocusDistance * GetTanFoV());
	return float4(depth1, velocity, time, 1.0);
}

float4 PS_CopyFocusDistance(float2 Tex: TEXCOORD0) : COLOR
{
	return tex2Dlod(AutoFocusSmp, float4(0.5,0.5,0,0));
}

//-----------------------------------------------------------------------------
// CoCの計算
float4 PS_CalcCoC( VS_OUTPUT IN ) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 Color = Degamma4(tex2D(ScnSamp, texCoord));
	float Depth = tex2D( DepthMap, texCoord).x;

	float level = CalcBlurLevel(IN.TexCoord1.xy, Depth);

	float forceCoCSacle = IN.TexCoord1.z;
	float frontCoCSacle = IN.TexCoord1.w;

	float s = sign(level);
	level = max(abs(level) - mFocusRange * 10.0, 0.0) * s;
	level = (level >= 0.0) ? level : (level * frontCoCSacle);
	level = (abs(level) >= 1.0)
			? s * ((abs(level) - 1.0) * forceCoCSacle + 1)
			: level;

	float emphasizeRate = IN.TexCoord2.x;
	Color.rgb = EmphasizeColor(Color.rgb, emphasizeRate);

	return float4(Color.rgb, level);
}

//-----------------------------------------------------------------------------
// 低解像度のバッファを作る

float CalcWeight(float4 col) { return abs(col.w); }

float4 PS_DownSampling( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float4 Color0 = tex2D(smp, IN.TexCoord1.xy);
	float4 Color1 = tex2D(smp, IN.TexCoord1.zw);
	float4 Color2 = tex2D(smp, IN.TexCoord2.xy);
	float4 Color3 = tex2D(smp, IN.TexCoord2.zw);

	float4 Color = 0;
	float w0 = CalcWeight(Color0); Color += Color0 * w0;
	float w1 = CalcWeight(Color1); Color += Color1 * w1;
	float w2 = CalcWeight(Color2); Color += Color2 * w2;
	float w3 = CalcWeight(Color3); Color += Color3 * w3;
	Color = Color / max(w0+w1+w2+w3, epsilon);
	Color.w *= 0.5;

	return Color;
}


//-----------------------------------------------------------------------------
// ボカす

struct PS_OUT_MRT
{
	float4 ColorBack	: COLOR0;
	float4 ColorFront	: COLOR1;
};

#define WeightFlagFirst		float2(1,0)
#define WeightFlagMiddle	float2(0,0)
#define WeightFlagLast		float2(0,1)

// coc.x: front
// coc.y: back
float2 CalcWeight(float2 coc, uniform float2 weightFlag)
{
	return CoCBrightness(coc)
		* max(weightFlag.x, saturate(coc * 2.0 - (BULR_SIZE - 1.0)))
		* max(weightFlag.y, saturate(BULR_SIZE - coc));
}

PS_OUT_MRT PS_Blur( VS_OUTPUT IN, uniform sampler2D smp, uniform float2 weightFlag)
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;
	float depth0 = tex2D(smp, texCoord).w;
	float2 coc0 = float2(max(depth0,0), BULR_SIZE);
	float4 sumB = 0;
	float4 sumF = 0;

	int dither = 0;
	for(int iy = 0; iy <= BULR_SIZE * 2; iy++)
	{
		float vy = iy - BULR_SIZE;
		float dither2 = -BULR_SIZE + dither;
		for(int ix = 0; ix <= BULR_SIZE; ix++)
		{
			float vx = ix * 2 + dither2;
			float2 uv = float2(vx, vy);
			float l = length(uv);
			float4 Color = tex2Dlod(smp, float4(offset * uv + texCoord, 0,0));
			float2 coc = max(float2( Color.w, -Color.w), 0);
			float2 dist = saturate(min(coc, coc0) - l);
			float2 weight = dist * CalcWeight(coc, weightFlag);
			sumB += float4(Color.rgb, 1) * weight.x;
			sumF += float4(Color.rgb, 1) * weight.y;
		}
		dither = 1 - dither;
	}

	PS_OUT_MRT Out;
	Out.ColorBack = sumB;
	Out.ColorFront = sumF;
	return Out;
}

//-----------------------------------------------------------------------------
// 低解像度マップを高解像度に復元
float4 PS_UpSampling( VS_OUTPUT IN, uniform sampler2D smp, uniform sampler2D smp2) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 Color0 = tex2D(smp, texCoord);
	float4 Color1 = 
		tex2D(smp2, IN.TexCoord1.xy) + tex2D(smp2, IN.TexCoord1.zw) + 
		tex2D(smp2, IN.TexCoord2.xy) + tex2D(smp2, IN.TexCoord2.zw);
	return Color0 + Color1 / 4.0;
}

//-----------------------------------------------------------------------------
// 
float4 PS_Gather( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 Color = tex2D(DownscaleSamp0, texCoord);
	float depth = Color.w;
	Color.w = 1;

	float4 ColorB =	+ tex2D(DownscaleSamp1Linear, texCoord)	// 後ボケ 1/2.0
					+ tex2D(BlurSamp0Linear, texCoord);		// 後ボケ 1/1.0
	float4 ColorF = + tex2D(BlurSamp1Linear, texCoord)		// 前ボケ 1/2.0
					+ tex2D(BlurSampF0Linear, texCoord);	// 前ボケ 1/1.0
	ColorB *= saturate(depth - PINT_MARGIN);
		// マスキング。本来、前ボケの場所に後ボケははみ出さないが、
		// 縮小バッファの使用しているためズレがでる。

	float coc = max(depth - PINT_MARGIN, -depth);
	float compensation = 1.0 / (MAX_COC_SIZE * MAX_COC_SIZE);
	float w = CoCBrightness(coc) + compensation;
	Color = Color * w + ColorB + ColorF * 4.0;
	Color.rgb /= Color.w;

	float demphasizeRate = IN.TexCoord1.x;
	Color.rgb = DepreciateColor(Color.rgb, demphasizeRate);
	Color = Gamma4(TestColor( Color.rgb, depth, texCoord));

	return Color;
}

//=============================================================================

#if ENABLE_EXTRA_LEVEL > 0
#define FOR_EXTRA_LEVEL(command)	command
#else
#define FOR_EXTRA_LEVEL(command)	
#endif

technique DepthOfField <
	string Script = 
		// 普通の画面をレンダリング
		"RenderColorTarget0=ScnMap;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor; ClearSetDepth=ClearDepth;"
		"Clear=Color; Clear=Depth;"
		"ScriptExternal=Color;"

		// オートフォーカスの計算
		"RenderDepthStencilTarget=AutoFocusDepthBuffer;"
		"RenderColorTarget0=AutoFocusTex;	Pass=UpdateFocusPass;"
		"RenderColorTarget0=AutoFocusTex2;	Pass=CopyFocusPass;"

		// CoCのサイズ計算
		"RenderDepthStencilTarget=DepthBuffer;"
		"RenderColorTarget0=DownscaleMap0;"
		// "Clear=Color; Clear=Depth;"
		"Pass=CalcCoCPass;"

		// 画像のダウンスケール
		"RenderColorTarget0=DownscaleMap1; Pass=ScalePass1;"
		"RenderColorTarget0=DownscaleMap2; Pass=ScalePass2;"
		"RenderColorTarget0=DownscaleMap3; Pass=ScalePass3;"
		FOR_EXTRA_LEVEL( "RenderColorTarget0=DownscaleMap4; Pass=ScalePass4;" )

		// ボカす
		"RenderColorTarget0=BlurMap0; RenderColorTarget1=BlurMapF0; Pass=BlurPass0;"
		"RenderColorTarget0=BlurMap1; RenderColorTarget1=BlurMapF1; Pass=BlurPass1;"
		"RenderColorTarget0=BlurMap2; RenderColorTarget1=BlurMapF2; Pass=BlurPass2;"
		"RenderColorTarget0=BlurMap3; RenderColorTarget1=BlurMapF3; Pass=BlurPass3;"
		FOR_EXTRA_LEVEL( "RenderColorTarget0=BlurMap4; RenderColorTarget1=BlurMapF4; Pass=BlurPass4;" )
		"RenderColorTarget1=;"

		// 後ボケのアップサンプリング
		FOR_EXTRA_LEVEL( "RenderColorTarget0=DownscaleMap3; Pass=UpScale3;" )
		"RenderColorTarget0=DownscaleMap2; Pass=UpScale2;"
		"RenderColorTarget0=DownscaleMap1; Pass=UpScale1;"
		// 前ボケのアップサンプリング
		// (※合成の終わった後ボケ用ワークに前ボケの合成結果を格納)
		FOR_EXTRA_LEVEL( "RenderColorTarget0=BlurMap3; Pass=UpScaleF3;" )
		"RenderColorTarget0=BlurMap2; Pass=UpScaleF2;"
		"RenderColorTarget0=BlurMap1; Pass=UpScaleF1;"

		// 合成
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=GatherPass;"
	;
> {
	pass UpdateFocusPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_UpdateFocusDistance();
		PixelShader  = compile ps_3_0 PS_UpdateFocusDistance();
	}
	pass CopyFocusPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_UpdateFocusDistance();
		PixelShader  = compile ps_3_0 PS_CopyFocusDistance();
	}

	pass CalcCoCPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_CalcCoC();
		PixelShader  = compile ps_3_0 PS_CalcCoC();
	}

	// ダウンサンプリング
	pass ScalePass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp0);
	}
	pass ScalePass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp1);
	}
	pass ScalePass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp2);
	}
#if ENABLE_EXTRA_LEVEL > 0
	pass ScalePass4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_DownSampling(DownscaleSamp3);
	}
#endif

	// ボカし
	pass BlurPass0 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp0, WeightFlagFirst);
	}
	pass BlurPass1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp1, WeightFlagMiddle);
	}
	pass BlurPass2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(4);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp2, WeightFlagMiddle);
	}
#if ENABLE_EXTRA_LEVEL > 0
	pass BlurPass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp3, WeightFlagMiddle);
	}
	pass BlurPass4 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(16);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp4, WeightFlagLast);
	}
#else
	pass BlurPass3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(8);
		PixelShader  = compile ps_3_0 PS_Blur(DownscaleSamp3, WeightFlagLast);
	}
#endif

	// アップサンプリング
#if ENABLE_EXTRA_LEVEL > 0
	pass UpScale3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(8);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp3, BlurSamp4Linear);
	}
	pass UpScale2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp2, DownscaleSamp3Linear);
	}
#else
	pass UpScale2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp2, BlurSamp3Linear);
	}
#endif
	pass UpScale1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSamp1, DownscaleSamp2Linear);
	}

#if ENABLE_EXTRA_LEVEL > 0
	pass UpScaleF3 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(8);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF3, BlurSampF4Linear);
	}
	pass UpScaleF2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF2, BlurSamp3Linear);
	}
#else
	pass UpScaleF2 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(4);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF2, BlurSampF3Linear);
	}
#endif
	pass UpScaleF1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2);
		PixelShader  = compile ps_3_0 PS_UpSampling(BlurSampF1, BlurSamp2Linear);
	}

	// 合成
	pass GatherPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Gather(1);
		PixelShader  = compile ps_3_0 PS_Gather();
	}
}

//=============================================================================
