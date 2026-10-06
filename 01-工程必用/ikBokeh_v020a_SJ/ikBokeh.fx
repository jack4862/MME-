//=============================================================================
// ikBokeh2.fx
// ポストプロセスで被写界深度のエミュレートを行う。

// 主な参考資料：
// 川瀬さんの各種資料
// CryENGINE3 Graphics Gems, Sousa 2013
// Next Generation Post Processing in Call of Duty Advanced Warfare, Jimenez 2014
// A Life of a Bokeh, Guillaume 2018

//=============================================================================

#define SJ_TEST 0
float throri = 0.6;
float3 thrin = float3(0.8,1,1.5)*1.5;

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

// サンプリングするリングの数 (3～10くらい。大きいほど遅くてきれい)
#define	RingNum		8


//****************** 設定はここまで
//****************** 以下は、弄らないほうがいい設定項目

// ピントのあっている範囲をゆるくする。(0～1.0)
#define PINT_MARGIN		1.0

// テクスチャフォーマット
//	HDRを使うなら、浮動小数点である必要がある。
//#define TEXFORMAT "A32B32G32R32F"
#define TEXFORMAT "A16B16G16R16F"
//#define TEXFORMAT "A8R8G8B8"

// ワーク用テクスチャのフォーマット
//	浮動小数点でないと計算結果を維持できない。
//#define WORK_TEXFORMAT "A32B32G32R32F"
#define WORK_TEXFORMAT "A16B16G16R16F"


// 単位調整用の変数。
//#define		m	(1/0.1)	// 1MMD単位 = 10cm。本来は8cm程度?
#define		m	(1/0.08)	// 1MMD単位 ≒ 8cm
#define		cm	(m * 0.01)
#define		mm	(m * 0.001)

#define	PI	(3.14159265359)
#define RAD2DEG(x)	((x) * 180.0 / PI)
#define DEG2RAD(x)	((x) * PI / 180.0)
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
float4x4 matInvVP		: VIEWPROJECTIONINVERSE;
float3 CameraPosition	: POSITION  < string Object = "Camera"; >;
float3 CameraDirection	: DIRECTION  < string Object = "Camera"; >;

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
static float mPintDelay = (isExistController || DEFAULT_MEASURING_MODE==0) ? mPintDelayParam : 0.5;

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

DECLARE_PARAM(float, mFocusRange, "ピント幅");
DECLARE_PARAM(float, mBokehP, "ボケ+");
DECLARE_PARAM(float, mBokehM, "ボケ-");
DECLARE_PARAM(float, mFBokehM, "前ボケ-");
DECLARE_PARAM(float, mCoCSize, "CoCサイズ");
DECLARE_PARAM(float, mEmphasize, "玉ボケ強調");

DECLARE_PARAM(float, mTestMode, "テストモード");
DECLARE_PARAM(float, mManualAperture, "手動絞り");
DECLARE_PARAM(float, mAperture, "絞り");
DECLARE_PARAM(float, mBladesNum, "ブレード枚数");

DECLARE_PARAM(float, mAFModeParam, "AF測距モード");
static int mAFMode = (isExistController) ? (int)(mAFModeParam * 3.0 + 0.1) : DEFAULT_MEASURING_MODE;
DECLARE_PARAM(float, mManualMode, "マニュアルモード");
DECLARE_PARAM(float, mPintDistance, "ピント距離");
DECLARE_PARAM(float, mFocalLength, "焦点距離");

DECLARE_PARAM(float4x4, mTiltMat, "ティルト");
DECLARE_PARAM(float, mTiltUp, "ティルトアップ");
DECLARE_PARAM(float, mTiltDown, "ティルトダウン");
static float3 mTiltDirection = mTiltMat[1].xyz;

bool bLinearMode : CONTROLOBJECT < string name = "ikLinearEnd.x"; >;

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static float ForceCoCSacle = AcsSi * 0.1 * (mCoCSize + 1.0);


//=============================================================================

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

#define ScreenScale		1
#define MinimumCoCRadius	1.0		// CoCの最低保証値。小さすぎると発散する。

// ボケの半径上限
#define MAX_COC_SIZE	(32)

// CoCのタイルサイズ
// 半分の解像度なので16(=MAX_COC_SIZE/2)。
// さらにダイレーションするので8で十分?
#define TILE_SIZE	16

// ワーク用テクスチャの設定
#define FILTER_MODE			MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
#define LINEAR_FILTER_MODE	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
#define ADDRESSING_MODE		AddressU = CLAMP; AddressV = CLAMP;
#define ADDRESSING_MODE_BORDER		AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

// ブラー用の係数
float4 BlurWeightArray[] = {
	float4(0.117695786, 0.1129886  , 0.09996678 , 0.08151249 ),
	float4(0.061254784, 0.042423185, 0.027077833, 0.015928391)
};
static float BlurWeight[8] = (float[8])BlurWeightArray;


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
	int Miplevels = 1;
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	FILTER_MODE	ADDRESSING_MODE
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {ScreenScale, ScreenScale};
	string Format = "D24S8";
>;

#define DECL_TEXTURE0( _map, _samp, _fmt, _w, _h, _mip) \
	texture2D _map : RENDERCOLORTARGET < \
		bool AntiAlias = false; \
		float2 ViewportRatio = {ScreenScale * (1.0/(_w)), ScreenScale * (1.0/(_h))}; \
		string Format = _fmt; \
		int Miplevels = _mip; \
	>; \
	sampler2D _samp = sampler_state { \
		texture = <_map>; \
		FILTER_MODE	ADDRESSING_MODE \
	}; \
	sampler2D _samp##Linear = sampler_state { \
		texture = <_map>; \
		LINEAR_FILTER_MODE	ADDRESSING_MODE \
	}; \

#define DECL_TEXTURE( _map, _samp, _s) DECL_TEXTURE0(_map, _samp, WORK_TEXFORMAT, _s, _s, 1)
#define DECL_TEXTURE2( _map, _samp, _fmt, _w, _h) DECL_TEXTURE0(_map, _samp, _fmt, _w, _h, 1)

// RGBとCoCを持ったマップ
DECL_TEXTURE( CocMap, CocSamp, 1)

// F:Front(前ボケ) / B:Back(後ボケ)
DECL_TEXTURE( BlurMapB0, BlurSampB0, 1)
DECL_TEXTURE( BlurMapF0, BlurSampF0, 1)
DECL_TEXTURE( BlurMapW0, BlurSampW0, 1)  // W:Work
	// 後ボケはBorderにしたほうが画面端の色が滲み過ぎなくていい。
	// 前ボケはBorderじゃないほうが自然なのでそのままにする。
	sampler2D BlurSampB0Border = sampler_state {
		texture = <BlurMapB0>;
		FILTER_MODE	ADDRESSING_MODE_BORDER
	};

// H:Hole filling: 前ボケのエッジをごまかすための嘘画像
DECL_TEXTURE( BlurMapH0, BlurSampH0, 2)
DECL_TEXTURE( BlurMapH1, BlurSampH1, 2)

// 後ボケのCoCを滑らかにするのと、タイルCoC計算で使用
DECL_TEXTURE2( WorkCocMap0, WorkCocSamp0, "R16F", 2, 2)
DECL_TEXTURE2( WorkCocMap1, WorkCocSamp1, "R16F", 2, 2)

// tile coc. 前ボケ用のCoCしか使っていないが、一応後ボケのCoCも保存する
#define TILE_TEXFORMAT	"G16R16F"
#define TILE_SIZE2	(TILE_SIZE * 2)
DECL_TEXTURE2( TileCocMap1, TileCocSamp1, TILE_TEXFORMAT, TILE_SIZE2, 2)
DECL_TEXTURE2( TileCocMap2, TileCocSamp2, TILE_TEXFORMAT, TILE_SIZE2, TILE_SIZE2)
DECL_TEXTURE2( TileCocMap3, TileCocSamp3, TILE_TEXFORMAT, TILE_SIZE2, TILE_SIZE2)
#define	TileCocSampLinear TileCocSamp3Linear


// 自動焦点用の情報。フレームを超えて情報をやりとりする。
texture2D AutoFocusTex : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	string Format="A32B32G32R32F";
	int Miplevels = 1;
>;
sampler2D AutoFocusSmp = sampler_state {
	Texture = <AutoFocusTex>;
	ADDRESSING_MODE		FILTER_MODE
};
texture2D AutoFocusTex2 : RENDERCOLORTARGET <
	int2 Dimensions = {1,1};
	string Format="A32B32G32R32F";
	int Miplevels = 1;
>;
sampler2D AutoFocusSmp2 = sampler_state {
	Texture = <AutoFocusTex2>;
	ADDRESSING_MODE		FILTER_MODE
};

texture AutoFocusDepthBuffer : RenderDepthStencilTarget <
	int2 Dimensions = {1,1};
	string Format = "D24S8";
	int Miplevels = 1;
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
	//float emphasizeRate = (saturate(mEmphasize) * EMPHASIZE_RATE + 1.0);
	float emphasizeRate = (mEmphasize * EMPHASIZE_RATE + 1.0);
	return (mEmphasize <= 0.0) ? 0.0 : emphasizeRate;
}
float CalcDepreciateRate()
{
	// NOTE: >0 にしないと値を使わなくても、結果がNan(Inf?)になる。
	float emphasizeRate = max(CalcEmphasizeRate(), epsilon);
	return (mEmphasize <= 0.0) ? 0.0 : (1.0 / emphasizeRate);
}
float3 EmphasizeColor(float3 col, float rate)
{
	//return (rate > 0.0) ? pow(max(col, epsilon), rate) : col;
	//return (rate > 0.0) ? pow(max(col, 0), rate) : col;
	col = (mEmphasize > 0.0) ? exp(col * rate) : col;
	//col = float3(0,1,1);
	return col;
}
float3 DepreciateColor(float3 col, float rate)
{
	//return (rate > 0.0) ? pow(max(col, epsilon), rate) : col;
	//return (rate > 0.0) ? pow(max(col, 0), rate) : col;
	col = (mEmphasize > 0.0) ? log(col) * rate : col;
	//col = float3(0,1,1);
	return saturate(col);
}
#else
float CalcEmphasizeRate() { return 0; }
float CalcDepreciateRate() { return 0; }
float3 EmphasizeColor(float3 col, float rate) { return col; }
float3 DepreciateColor(float3 col, float rate) { return col; }
#endif

// Interleaved gradient noise
float hash12(float2 p)
{
	float2 uv = p * ViewportSize;
	float3 magic = float3( 0.06711056, 0.00583715, 52.9829189 );
	return frac( magic.z * frac( dot( uv, magic.xy )));
}

// for Tilt-Shift
float3 ReconstructWPos(float2 Tex, float depth)
{
	// depthはViewSpaceのz値ではなく、ViewSpaceでの大きさ(カメラとの距離)
	// なので、いったん視線方向を計算する
	float2 coord = Tex.xy * float2(2,-2) + float2(-1,1);
	float4 lpos = float4(coord, matP._33 + matP._43, 1);
	float3 wpos = mul(lpos, matInvVP).xyz;
	float3 cameraDir = normalize(wpos - CameraPosition);
	return CameraPosition + cameraDir * depth;
}

// ティルト用に深度値の再計算する
float ComputeTiltDepth(float2 texCoord, float defaltDepth, float focusDistance)
{
	float3 WPos = ReconstructWPos(texCoord, defaltDepth * FAR_DEPTH);

	float3 TiltUp = mTiltDirection;
	TiltUp = (dot(TiltUp, CameraDirection) <= 0.0) ? -TiltUp : TiltUp;
	float3 TiltDir = normalize(CameraDirection - TiltUp * dot(CameraDirection, TiltUp));
	// モードの切り替え: 
	// ティルトダウン(平面に平行) or ティルトアップ(モデルに垂直)
	TiltDir = (mTiltDown > mTiltUp) ? TiltUp : TiltDir;

	float3 VirtualCameraPos = AFPosition - TiltDir * focusDistance;
	float NewDistance = dot(WPos - VirtualCameraPos, TiltDir);
	float result = NewDistance / FAR_DEPTH;

	// ティルト無効なら defaltDepth をそのまま返す。
	float t = saturate(max(mTiltDown, mTiltUp));
	result = lerp(defaltDepth, result, t);
	return result;
}


//-----------------------------------------------------------------------------
// どれだけボケるか

float GetTanFoV()
{
	return 1.0 / matP._22;
}

float CalcFNumber()
{
	float f = DefaultFNumber + isExistController * ((mBokehM + 0.5 - mBokehP) * FNumberScale);
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

	float CoCCoef1 = -L * M * D * toPixel;
	float CoCCoef2 =      M * D * toPixel;

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

float CoCBrightness(float coc)
{
	// 本来は 1/(PI*coc^2) だが、どうせ正規化するので定数のPIは除く
	float cocSafe = max(coc, 1.0);
	return 1.0 / (cocSafe * cocSafe);
}


//-----------------------------------------------------------------------------
// 
float4 TestColor(float3 Color, float level, float2 uv)
{
	// テストモード
	#if ENABLE_TEST_MODE == 1
	if (mTestMode >= 0.5)
	{
		Color = saturate(rgb2gray(Color)) * 0.98 + 0.02;
			// 真っ黒い部分に色を乗せるためにゲタを履かせる。

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
	float4 Diaphragm	: TEXCOORD3;
};

VS_OUTPUT VS_SetTexCoord(float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;
	Out.TexCoord = float4(TexCoord, Offset);
	// downsample用
	Out.TexCoord1 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4(-1,-1, -1, 1);
	Out.TexCoord2 = TexCoord.xyxy + Offset.xyxy * 0.25 * float4( 1,-1,  1, 1);
	return Out;
}

VS_OUTPUT VS_SetTexCoord2(float4 Pos : POSITION, float4 Tex : TEXCOORD0
	, uniform float2 level, uniform float2 dir)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level * dir;
	Out.TexCoord = float4(TexCoord, Offset);
	return Out;
}

VS_OUTPUT VS_CalcCoC(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
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
	Out.TexCoord2.y = focusDistance;

	return Out;
}

VS_OUTPUT VS_Blur(float4 Pos : POSITION, float4 Tex : TEXCOORD0, 
	uniform float level, uniform bool bBackground)
{
	VS_OUTPUT Out = (VS_OUTPUT)0; 
	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;
	Out.TexCoord = float4(TexCoord, Offset);

	// aperture: 0だと○、1だと絞り形状
	float fnumber = smoothstep(-0.3, 0.1, mBokehM - mBokehP);  // ad-hoc
	float aperture = saturate(lerp(fnumber, mAperture, saturate(mManualAperture)));

	int bladesBase = clamp(round(mBladesNum * 5), 0, 4);  // 5～9
	int blades = bladesBase + 5;
	// 絞りに応じて回転させる
	// 後段は5枚羽と6枚羽の角度をいい感じにするための適当な調整
	float twist = aperture * DEG2RAD(30) + bladesBase * DEG2RAD(20);
	// 絞りの半径を調整するための分子
	float radiusNumerator = cos(PI / blades);
	Out.Diaphragm.x = aperture;
	Out.Diaphragm.y = blades;
	Out.Diaphragm.z = radiusNumerator;
	Out.Diaphragm.w = twist + (bBackground ? 0 : PI);  // 前ボケと後ボケで向きが変わる

	return Out;
}

VS_OUTPUT VS_Gather(float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
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

VS_OUTPUT VS_UpdateFocusDistance(float4 Pos : POSITION, float4 Tex : TEXCOORD0)
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
	velocity += sign(v) * speed * saturate(1.0 - mPintDelay);
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
	Depth = ComputeTiltDepth(texCoord, Depth, IN.TexCoord2.y);

	float level = CalcBlurLevel(IN.TexCoord1.xy, Depth);

	float forceCoCSacle = IN.TexCoord1.z;
	float frontCoCSacle = IN.TexCoord1.w;

	float s = sign(level);
	level = max(abs(level) - mFocusRange * 10.0, 0.0) * s;
	level = (level >= 0.0) ? level : (level * frontCoCSacle);
	
	if(SJ_TEST == 1 && abs(level) >= 1.0 && (Color.r + Color.g + Color.b) / 3 > throri)
	{
		Color.rgb = (Color.rgb * thrin);
	}
	
	level = (abs(level) >= 1.0)
			? s * ((abs(level) - 1.0) * forceCoCSacle + 1)
			: level;
			

	float emphasizeRate = IN.TexCoord2.x;
	Color.rgb = EmphasizeColor(Color.rgb, emphasizeRate);

	return float4(Color.rgb, level);
}

//-----------------------------------------------------------------------------
// CoCのタイルを作る

float4 PS_DownscaleCoc( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float4 Color0 = tex2D(smp, IN.TexCoord1.xy);
	float4 Color1 = tex2D(smp, IN.TexCoord1.zw);
	float4 Color2 = tex2D(smp, IN.TexCoord2.xy);
	float4 Color3 = tex2D(smp, IN.TexCoord2.zw);

	// cocの値を求める。前ボケと後ボケが混じらないようにする
	float4 cocQuad = float4(Color0.w, Color1.w, Color2.w, Color3.w);
	float cocf = min(min(cocQuad.x, cocQuad.y), min(cocQuad.z, cocQuad.w));
	float cocb = dot(0.25, cocQuad);
	float coc = cocf < 0.0 ? cocf : cocb;

	return float4(coc, 0,0,1);
}

float4 PS_CreateTileCocX( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	float2 result = 0;
	for(int i = 0; i < TILE_SIZE; i++)
	{
		float coc = tex2D(smp, uv + o * i).x;
		result = max(result, float2(-coc, coc));  // 前ボケ, 後ボケ
	}

	return float4(result, 0,1);
}

float4 PS_CreateTileCocY( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	float2 result = 0.0;
	for(int i = 0; i < TILE_SIZE; i++)
	{
		float2 coc = tex2D(smp, uv + o * i).xy;
		result = max(result, coc);
	}

	return float4(result, 0,1);
}

float4 PS_DilateTileCoc( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	float margin = (TILE_SIZE * 1.412 * 3.0) / (TILE_SIZE * 2.0);
	float scale = 1.0 / (TILE_SIZE * 2.0);

	float2 result = 0;
	int W = 2;
	for(int iy = 0; iy <= W * 2; iy++) {
	for(int ix = 0; ix <= W * 2; ix++) {
		float vx = ix - W;
		float vy = iy - W;
		float2 coc = tex2D(smp, uv + o * float2(vx,vy)).xy;

		// 距離を考慮する
		float2 v = float2(vx, vy);
		float dSq = dot(v,v);
		float2 cocSq = coc * scale + margin;
		cocSq = cocSq * cocSq;
		coc.x = (cocSq.x >= dSq) ? coc.x: 0.0;
		coc.y = (cocSq.y >= dSq) ? coc.y : 0.0;

		result = max(result, coc);
	}}

	return float4(result, 0,1);
}


//-----------------------------------------------------------------------------
// 遮蔽割合を計算するため後ボケのCoCの平均をとる
// 本来はVSMのようにcoc,coc^2の両方を保存するが、
// 同一平面でも分散が一定ではないためアーティファクトになっていた。要再調査。

// 前ボケは重みに加えない
float CocBlurWeight(float coc)
{
	return (coc > 1.0);
}

float4 PS_CocBlurX( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	// 自分自身は常に加える
	// 二乗したほうが奥に有利になる。
	float coc0 = max(tex2D(smp, uv).w, 0);
	float2 cocavg = float2(coc0*coc0, 1) * BlurWeight[0];

	for(int i = 1; i < 8; i++)
	{
		float cocp = tex2D(smp, uv + o * i).w;
		float cocn = tex2D(smp, uv - o * i).w;
		cocavg += float2(cocp*cocp, 1) * (CocBlurWeight(cocp) * BlurWeight[i]);
		cocavg += float2(cocn*cocn, 1) * (CocBlurWeight(cocn) * BlurWeight[i]);
	}
	cocavg.x = cocavg.x / cocavg.y;

	return float4(cocavg.x, 0,0,1);
}

float4 PS_CocBlurY( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	float coc0 = tex2D(smp, uv).w;
	float2 cocavg = float2(coc0, 1) * (CocBlurWeight(coc0) * BlurWeight[0]);
	for(int i = 1; i < 8; i++)
	{
		float cocp = tex2D(smp, uv + o * i).x;
		float cocn = tex2D(smp, uv - o * i).x;
		cocavg += float2(cocp, 1) * (CocBlurWeight(cocp) * BlurWeight[i]);
		cocavg += float2(cocn, 1) * (CocBlurWeight(cocn) * BlurWeight[i]);
	}
	cocavg.x = cocavg.y > 0.0 ? cocavg.x / cocavg.y : 0;
	// 前パスで二乗していたので戻す。
	cocavg.x = sqrt(max(cocavg.x,0));

	return float4(cocavg.x, 0,0,1);
}


//-----------------------------------------------------------------------------
// 事前に軽くボカすことでサンプリングのノイズを減らす

float4 ComputePreFilterWeight(float4 color, float coc0)
{
	float coc = color.w;
	float k = 1.0/4.0;
		// cocの差がありすぎたら無視
		// cocが大きいほど寛容にする?
		// k = 1 / max(coc0 * 4.0 / 32.0, 1.0); // みたいな
	float w = saturate(1.0 - abs(coc - coc0) * k);
	return float4(color.rgb, 1) * w;
}

// 後ボケ用のプリフィルタ
float4 PS_PreFilterBack( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	float4 color0 = tex2D(smp, uv);
	float coc0 = color0.w;
	float r = abs(coc0) * (1.0 / RingNum) * 0.5;
	o *= r;

	#define ComputeWeight(u,v) ComputePreFilterWeight(tex2D(smp, uv + o * float2(u,v)), coc0)
	float4 colorSum = float4(color0.rgb, 1) * 4;
	colorSum += ComputeWeight(-1,-1) * 1;
	colorSum += ComputeWeight( 0,-1) * 2;
	colorSum += ComputeWeight( 1,-1) * 1;
	colorSum += ComputeWeight(-1, 0) * 2;
	colorSum += ComputeWeight( 1, 0) * 2;
	colorSum += ComputeWeight(-1, 1) * 1;
	colorSum += ComputeWeight( 0, 1) * 2;
	colorSum += ComputeWeight( 1, 1) * 1;
	colorSum /= colorSum.w;

	// 後ボケ用の pre-multiply
	colorSum.rgb *= (coc0 > 1.0);

	return float4(colorSum.rgb, coc0);
}

// ポストフィルタ
// 単なるガウスフィルタ
float4 PS_PostFilter( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	#define ComputeWeight(u,v) tex2D(smp, uv + o * float2(u,v))
	float4 colorSum = ComputeWeight(0,0) * 4;
	colorSum += ComputeWeight(-1,-1) * 1;
	colorSum += ComputeWeight( 0,-1) * 2;
	colorSum += ComputeWeight( 1,-1) * 1;
	colorSum += ComputeWeight(-1, 0) * 2;
	colorSum += ComputeWeight( 1, 0) * 2;
	colorSum += ComputeWeight(-1, 1) * 1;
	colorSum += ComputeWeight( 0, 1) * 2;
	colorSum += ComputeWeight( 1, 1) * 1;
	colorSum /= (4*1+2*4+1*4);
	return colorSum;
}


//-----------------------------------------------------------------------------
// ボカす

float4 PS_BlurBack( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	// iy==0 は常に自分自身なので特別扱いにする
	float4 Color0 = tex2D(smp, texCoord);
	float coc0 = max(Color0.w, 0);  // 後ボケ
	float weight0 = CoCBrightness(coc0);
	float4 sum = float4(Color0.rgb, 1) * weight0;

	// cocをなじませる。ad-hoc
	float avgcoc = tex2D(WorkCocSamp1, texCoord).x;
	avgcoc = lerp(coc0, avgcoc, saturate((coc0-1.0) * (0.5 * MAX_COC_SIZE)));

	// サンプリングサイズの決定
	float Radius = avgcoc;

	float aperture = IN.Diaphragm.x;
	int blades = IN.Diaphragm.y;
	float RadiusNumerator = IN.Diaphragm.z; // cos(PI / blades);
	float Twist = IN.Diaphragm.w;
	float PI2BladeNum = (2.0 * PI) / blades;
	float InvPI2 = 1.0 / (2.0 * PI);

	// サンプリング位置を散らすために、PPOSに応じて角度と半径をいじる
	float jitter = hash12(texCoord.xy);
	float offsetTheta = jitter * (2.0 * PI);
	float offsetRadius = 0; //jitter * (1.0 / RingNum);

	// float ringWidth = Radius * (1.0 / RingNum);
	// float lod = max(log2(ringWidth), 0);

	for(int iy = 1; iy <= RingNum; iy++) {
		float r0 = saturate(iy * (1.0 / RingNum) + offsetRadius) * Radius;

		// 外周の長さ
		int sampleCount = iy * 8;
		float dTheta = PI * 2 / sampleCount;
		// 角度を半分ずつズラす
		offsetTheta += (PI / 8.0);

		for(int ix = 0; ix < sampleCount; ix++) {
			float theta = ix * dTheta + offsetTheta;
			// Note: 1ループで点対称の反対側も処理すれば、ループ回数を減らせる
			// float thetaOp = theta + PI;

			// Note: Twistはn-gonの計算には含めない
			float2 uv;
			sincos(theta + Twist, uv.y, uv.x);

			// n-gonに変形する
			float mod = floor((blades * theta + PI) * InvPI2);
			float modifier0 = cos(theta - PI2BladeNum * mod);
			float modifier = RadiusNumerator / modifier0;  // 分子は定数項
			modifier = lerp(1.0, modifier, aperture);
			float r = r0 * modifier;
			uv *= r;

			float l = r * ((RingNum - 1.0) / RingNum);  // ad-hoc

			float4 Color = tex2Dlod(smp, float4(offset * uv + texCoord, 0,0));
			float coc = max(Color.w, 0);  // 後ボケ
			float dist = saturate(coc - l);
			float weight = dist * CoCBrightness(coc);
			weight *= modifier * modifier;  // 短くなった分、暗くしないと詰まる
			sum += float4(Color.rgb, 1) * weight;
		}
	}

	// 正規化
	sum.rgb /= sum.w;

	return sum;
}


// 前ボケ用
// 後ボケと違ってCoCによる重み付けをしない
float4 PS_BlurFront( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float2 offset = IN.TexCoord.zw;

	float maxCoc = tex2D(TileCocSampLinear, texCoord).x;
	// clip(maxCoc - 1.0);  // early out. MMDのfps的に効果はなさそう
	float Radius = max(maxCoc, 1);  // 前ボケ用

	float4 Color0 = tex2D(smp, texCoord);
	float coc0 = max(-Color0.w, 0);  // 前ボケ
	float weight0 = saturate(coc0 - 1);
	float4 sum = float4(Color0.rgb, 1) * weight0;

	float aperture = IN.Diaphragm.x;
	int blades = IN.Diaphragm.y;
	float RadiusNumerator = IN.Diaphragm.z;
	float Twist = IN.Diaphragm.w;
	float PI2BladeNum = (2.0 * PI) / blades;
	float InvPI2 = 1.0 / (2.0 * PI);

	float jitter = hash12(texCoord.xy);
	float offsetTheta = jitter * (2.0 * PI);
	float offsetRadius = jitter * (1.0 / RingNum);

	for(int iy = 1; iy <= RingNum; iy++) {
		float r0 = saturate(iy * (1.0 / RingNum) + offsetRadius) * Radius;

		int sampleCount = iy * 8;
		float dTheta = PI * 2.0 / sampleCount;
		offsetTheta += (PI / 8.0);

		for(int ix = 0; ix < sampleCount; ix++) {
			float theta = ix * dTheta + offsetTheta;

			float mod = floor((blades * theta + PI) * InvPI2);
			float modifier0 = cos(theta - PI2BladeNum * mod);
			float modifier = RadiusNumerator / modifier0;
			modifier = lerp(1.0, modifier, aperture);
			float r = r0 * modifier;
			float2 uv;
			sincos(theta + Twist, uv.y, uv.x);
			uv *= r;

			float l = r * ((RingNum - 1.0) / RingNum);

			float4 Color = tex2Dlod(smp, float4(offset * uv + texCoord, 0,0));
			float coc = max(-Color.w, 0);  // 前ボケ
			float dist = saturate(coc - l);
			float weight = dist;
			weight *= modifier * modifier;
			sum += float4(Color.rgb, 1) * weight;
		}
	}

	// 正規化
	// ヒットした数 / サンプリングした回数 でカバレッジを得る
	float invActual = 1.0 / (1.0 + RingNum * (RingNum - 1) * 8.0 / 2);
	sum.rgb /= max(sum.w, epsilon);
	sum.w *= invActual;

	return sum;
}


//-----------------------------------------------------------------------------
// 前ボケの境界をなじませる
// 完全な嘘処理

// 後ボケとオリジナル画像を合成
float4 PS_PrepareHoleFill( VS_OUTPUT IN) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	float4 color0 = tex2D(CocSamp, uv);		// オリジナル
	float coc0 = color0.w;
	float4 ColorB = tex2D(BlurSampB0Linear, uv);	// 後ボケ
	float w = saturate(coc0 - PINT_MARGIN - 1);
	float3 color = lerp(color0.rgb, ColorB.rgb, w);

	// 前ボケを含むか?
	// エッジでweightが1になるように、あらかじめ倍にしておく
	float weight = saturate(-(coc0 + 1.0) * 0.5) * 2.0;

	return float4(color, weight);
}

float4 PS_HoleBlur( VS_OUTPUT IN, uniform sampler2D smp) : COLOR
{
	float2 uv = IN.TexCoord.xy;
	float2 o = IN.TexCoord.zw;

	// ブラー範囲の調整: Dilate前のTileCoCを使う
	float coc = max(tex2D(TileCocSamp2Linear, uv).x, 1.0);
	o *= saturate(coc / MAX_COC_SIZE);

	float4 color0 = tex2D(smp, uv);
	float4 avg = color0 * BlurWeight[0];
	for(int i = 1; i < 8; i++)
	{
		float4 colorp = tex2D(smp, uv + o * i);
		float4 colorn = tex2D(smp, uv - o * i);
		avg += (colorp + colorn) * BlurWeight[i];
	}

	return avg;
}


//-----------------------------------------------------------------------------
// 
float4 PS_Gather( VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.TexCoord.xy;
	float4 Color = tex2D(CocSamp, texCoord);
	float depth = Color.w;
	float coc = max(depth - PINT_MARGIN, 0);
	float w = saturate(coc - 1.0);

	float4 ColorB = tex2D(BlurSampB0Linear, texCoord);	// 後ボケ
	float4 ColorH = tex2D(BlurSampH0Linear, texCoord);	// 前ボケのなじませ
	float4 ColorF = tex2D(BlurSampF0Linear, texCoord);	// 前ボケ

	Color.rgb = lerp(Color.rgb, ColorB.rgb, w);
	Color.rgb = lerp(Color.rgb, ColorH.rgb, saturate(ColorH.w));
	Color.rgb = lerp(Color.rgb, ColorF.rgb, saturate(ColorF.w));

	// 色強調を戻す + ガンマ補正を掛ける。
	float demphasizeRate = IN.TexCoord1.x;
	Color.rgb = DepreciateColor(Color.rgb, demphasizeRate);
	Color = Gamma4(TestColor( Color.rgb, depth, texCoord));

	return Color;
}


//=============================================================================
//
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
		"RenderColorTarget0=CocMap;	Pass=CalcCoCPass;"
		// TiledCoCを作成
		"RenderColorTarget0=WorkCocMap0; Pass=DownscaleCocPass;"
		"RenderColorTarget0=TileCocMap1; Pass=CreateTileCocX;"
		"RenderColorTarget0=TileCocMap2; Pass=CreateTileCocY;"
		"RenderColorTarget0=TileCocMap3; Pass=DilateTileCoc;"

		// 後ボケ
		"RenderColorTarget0=BlurMapB0;		Pass=PreFilterPass;"
		"RenderColorTarget0=WorkCocMap0;	Pass=CocBlurXPass;"
		"RenderColorTarget0=WorkCocMap1;	Pass=CocBlurYPass;"
		"RenderColorTarget0=BlurMapW0;		Pass=BlurPassBack1;"
		"RenderColorTarget0=BlurMapB0;		Pass=PostFilterPass;"

		// 前ボケの裏側を捏造
		"RenderColorTarget0=BlurMapH0;	Pass=PrepareHoleFill;"
		"RenderColorTarget0=BlurMapH1;	Pass=HoleBlurXPass;"
		"RenderColorTarget0=BlurMapH0;	Pass=HoleBlurYPass;"

		// 前ボケ
		"RenderColorTarget0=BlurMapW0;		Pass=BlurPassFront;"
		"RenderColorTarget0=BlurMapF0;		Pass=PostFilterPass;"

		// 合成
		"RenderColorTarget0=;"
		"RenderDepthStencilTarget=;"
		"Pass=GatherPass;"
	;
> {
	// オートフォーカスの計算
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

	// CoCのサイズ計算
	pass CalcCoCPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_CalcCoC();
		PixelShader  = compile ps_3_0 PS_CalcCoC();
	}
	pass DownscaleCocPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_DownscaleCoc(CocSamp);
	}
	pass CreateTileCocX < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2, float2(1,0));
		PixelShader  = compile ps_3_0 PS_CreateTileCocX(WorkCocSamp0);
	}
	pass CreateTileCocY < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(float2(2 * TILE_SIZE, 2), float2(0,1));
		PixelShader  = compile ps_3_0 PS_CreateTileCocY(TileCocSamp1);
	}
	pass DilateTileCoc < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2 * TILE_SIZE, float2(1,1));
		PixelShader  = compile ps_3_0 PS_DilateTileCoc(TileCocSamp2);
	}

	// 後ボケ
	pass PreFilterPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_PreFilterBack(CocSamp);
	}
	pass CocBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2, float2(1,0));
		PixelShader  = compile ps_3_0 PS_CocBlurX(BlurSampB0);
	}
	pass CocBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2, float2(0,1));
		PixelShader  = compile ps_3_0 PS_CocBlurY(WorkCocSamp0);
	}
	pass BlurPassBack1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(1, /* bBackground = */ true);
		PixelShader  = compile ps_3_0 PS_BlurBack(BlurSampB0Border);
	}
	// ポストフィルタは前後ボケで共有
	pass PostFilterPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(1);
		PixelShader  = compile ps_3_0 PS_PostFilter(BlurSampW0);
	}

	// 穴埋め
	pass PrepareHoleFill < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord(2);
		PixelShader  = compile ps_3_0 PS_PrepareHoleFill();
	}
	pass HoleBlurXPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2, float2(1,0));
		PixelShader  = compile ps_3_0 PS_HoleBlur(BlurSampH0Linear);
	}
	pass HoleBlurYPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_SetTexCoord2(2, float2(0,1));
		PixelShader  = compile ps_3_0 PS_HoleBlur(BlurSampH1Linear);
	}

	// 前ボケ
	pass BlurPassFront < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Blur(1, /* bBackground = */ false);
		PixelShader  = compile ps_3_0 PS_BlurFront(CocSamp);
	}

	// 合成
	pass GatherPass < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;	AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS_Gather(1);
		PixelShader  = compile ps_3_0 PS_Gather();
	}
}

//=============================================================================
