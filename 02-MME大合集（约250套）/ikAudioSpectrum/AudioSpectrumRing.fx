//-----------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------

// テクスチャ
#define IKAS_TEX_NAME	"wave.png"

//=============================================================================
// ここから

#define IKAS_OUTPUT_TEX_WIDTH	1024 // 出力用のテクスチャサイズ
#define IKAS_OUTPUT_TEX_HEIGHT	512

#define IKAS_ENABLE_MIPMAP	1 // mipmapを使う:1、使わない:0

#define IKAS_VALUE_TEX_WIDTH 256	// 計算途中のワークテクスチャサイズ
#define IKAS_VALUE_TEX_HEIGHT 1

#define IKAS_TEX_FPS	30.0	// テクスチャ作成時のfps。現在の再生fpsではない。
#define IKAS_MaxAttenuationTime 5.0 // 最大音量が消える速度
#define IKAS_MaxMoveScale 5.0	// 前後に移動する量

#define IKAS_TextureWidth 2048 // テクスチャの幅
#define IKAS_TextureLine 8 // テクスチャの段数。(256 * IKAS_TextureLine) がテクスチャの高さ
#define IKAS_MaxNoteCount 255 // キーの数
#define IKAS_TextureLineHeight (IKAS_MaxNoteCount + 1)
#define IKAS_TextureHeight (IKAS_TextureLineHeight * IKAS_TextureLine)


// 表情モーフからの値の取得
#define IKAS_DECLARE_PARAM(_t,_var,_item)	\
	_t IKAS_##_var : CONTROLOBJECT < string name = "(self)"; string item = _item;>;

IKAS_DECLARE_PARAM(float, mNoteBegin, "開始ノート");
IKAS_DECLARE_PARAM(float, mNoteEnd, "終了ノート");
IKAS_DECLARE_PARAM(float, mMirror, "左右対称");
IKAS_DECLARE_PARAM(float, mNoteInterpolation, "ノート補間");
IKAS_DECLARE_PARAM(float, mMoveNote, "移動ノート");
IKAS_DECLARE_PARAM(float, mMoveScale, "移動量");
IKAS_DECLARE_PARAM(float, mAngleP, "回転+"); // こっちが時計回り
IKAS_DECLARE_PARAM(float, mAngleM, "回転-");
IKAS_DECLARE_PARAM(float, mHue, "色");
IKAS_DECLARE_PARAM(float, mSaturate, "白");
IKAS_DECLARE_PARAM(float, mBrightness, "明るさ");
IKAS_DECLARE_PARAM(float, mDirection, "向き"); // 上、下、上下
IKAS_DECLARE_PARAM(float, mStyle, "スタイル"); // 描画スタイル (線/バー)
IKAS_DECLARE_PARAM(float, mSize, "サイズ");
IKAS_DECLARE_PARAM(float, mHeight, "高さ");
IKAS_DECLARE_PARAM(float, mBold, "太さ");
IKAS_DECLARE_PARAM(float, mGap, "間隔");
IKAS_DECLARE_PARAM(float, mAttenuation, "減衰速度");
IKAS_DECLARE_PARAM(float, mDelay, "ディレイ"); // 最大で1秒の遅れ
IKAS_DECLARE_PARAM(float, mSoftness, "やわらかさ");
IKAS_DECLARE_PARAM(float, mChannel, "チャンネル"); // L+R, L, R

IKAS_DECLARE_PARAM(float4x4, mObjectMatrix, "センター");

static bool IKAS_mEnableMirror = (IKAS_mMirror > 0.5);
static bool IKAS_mEnableNoteInterpolation = (IKAS_mNoteInterpolation < 0.5);
static float IKAS_AttenuationSpeed = IKAS_mAttenuation * IKAS_MaxAttenuationTime + 1.0 / 60.0;
static float IKAS_mBrightnessPower = (1.0 + IKAS_mBrightness * 2);

//-----------------------------------------------------------------------------

texture2D IKAS_FFTTex <
	string ResourceName = IKAS_TEX_NAME;
	int MipLevels = 1;
>;
sampler IKAS_FFTTexSamp = sampler_state {
	texture = <IKAS_FFTTex>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU = BORDER; AddressV = BORDER; BorderColor = float4(0,0,0,0);
};
texture IKAS_ValueWorkTex : RENDERCOLORTARGET
<
	int Width = IKAS_VALUE_TEX_WIDTH;
	int Height = IKAS_VALUE_TEX_HEIGHT;
	int MipLevels = 1;
	string Format = "G16R16F"; // 2ch
>;
sampler IKAS_ValueWorkSmp = sampler_state
{
	Texture = <IKAS_ValueWorkTex>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = WRAP; AddressV = CLAMP;
};
texture IKAS_ValueWorkTex2 : RENDERCOLORTARGET
<
	int Width = IKAS_VALUE_TEX_WIDTH;
	int Height = IKAS_VALUE_TEX_HEIGHT;
	int MipLevels = 1;
	string Format = "G16R16F"; // 2ch
>;
sampler IKAS_ValueWorkSmp2 = sampler_state
{
	Texture = <IKAS_ValueWorkTex2>;
	MinFilter = LINEAR;	MagFilter = LINEAR;	MipFilter = NONE;
	AddressU  = WRAP; AddressV = CLAMP;
};
texture IKAS_ValueWorkDepthBuffer : RenderDepthStencilTarget
<
	int Width = IKAS_VALUE_TEX_WIDTH;
	int Height = IKAS_VALUE_TEX_HEIGHT;
	string Format = "D24S8";
>;

texture IKAS_OutputWorkTex : RENDERCOLORTARGET
<
	int Width = IKAS_OUTPUT_TEX_WIDTH;
	int Height = IKAS_OUTPUT_TEX_HEIGHT;
	#if IKAS_ENABLE_MIPMAP > 0
	int MipLevels = 0;
	#else
	int MipLevels = 1;
	#endif
	string Format = "R16F";
>;
sampler IKAS_OutputWorkSmp = sampler_state
{
	Texture = <IKAS_OutputWorkTex>;
	MinFilter = Linear;	MagFilter = Linear;	MipFilter = Linear;
	AddressU  = WRAP; AddressV = CLAMP;
};
texture IKAS_OutputWorkDepthBuffer : RenderDepthStencilTarget
<
	int Width = IKAS_OUTPUT_TEX_WIDTH;
	int Height = IKAS_OUTPUT_TEX_HEIGHT;
	string Format = "D24S8";
>;

float IKAS_Time : TIME < bool SyncInEditMode = true; >;

// 時間からテクスチャの基準位置に変換する
// 時間軸での補間をしないならマージンは不要?
float2 IKAS_TimeToU()
{
	int frame = floor((IKAS_Time - IKAS_mDelay) * IKAS_TEX_FPS + 0.5);
	int frac = frame % IKAS_TextureWidth;
	int lines = floor((frame - frac) / IKAS_TextureWidth);

	float u = frac;
	float v = lines * IKAS_TextureLineHeight;
	return float2(u, v);
}

// UV位置を求める
float2 IKAS_GetUV(float noteNo)
{
	float2 offset = IKAS_TimeToU();
	noteNo = IKAS_mEnableMirror ? 1 - abs(noteNo * 2 - 1) : noteNo;
	noteNo = lerp(1.0 - IKAS_mNoteBegin, IKAS_mNoteEnd, noteNo);
	float note = saturate(noteNo) * IKAS_MaxNoteCount;
	note = IKAS_mEnableNoteInterpolation ? note : floor(note + 0.5);
		// 解像度もここで制御する?
		// IKAS_MaxNoteCountではなく別の係数をかけて、floorしてから正しい係数に戻す。

	offset.y += note;
	return (offset.xy + 0.5) / float2(IKAS_TextureWidth, IKAS_TextureHeight);
}

// 指定の音階の強度を得る
float2 IKAS_GetFFTValue(float noteNo)
{
	float2 uv = IKAS_GetUV(noteNo);
	return tex2D(IKAS_FFTTexSamp, uv).xy;
}

float IKAS_GetChannelValue(float2 values)
{
	float value = (IKAS_mChannel < 0.33) ? max(values.x, values.y) :
		((IKAS_mChannel < 0.66) ? values.x : values.y);
// value = abs(values.x - values.y); // 差分のテスト
	return value;
}

// 指定の音階の強度を得る
float IKAS_GetValueFromSample(float noteNo)
{
	float2 values = tex2D(IKAS_ValueWorkSmp2, float2(noteNo, 0.5)).rg;
	return IKAS_GetChannelValue(values);
}

// check side
float2 IKAS_ComputeHeightParam(float height)
{
	bool isLowerSide = (height > 0.5f);
	height = isLowerSide ? (2 - height * 2) : (height * 2);
	height = 1 - height;

	float scale = (IKAS_mDirection < 0.66) ? !isLowerSide : isLowerSide;	// 上 : 下
	scale = (IKAS_mDirection < 0.33) ? 1 : scale; // 上・下

	return float2(height, scale);
}

// スタイル込みを考慮した値を返す
float IKAS_GetHeightValue(float noteNo, float height)
{
	// スタイル
	// IKAS_mStyle < 0.2 : 折れ線グラフ(中身あり)
	// IKAS_mStyle < 0.4 : 棒グラフ
	// IKAS_mStyle < 0.6 : 棒グラフ+折れ線グラフ
	// IKAS_mStyle < 0.8 : 折れ線グラフ(中身なし)
	// IKAS_mStyle < 1.0 : 点のみのグラフ

	float halfheight = IKAS_OUTPUT_TEX_HEIGHT * 0.5;
	float gapInterval = (IKAS_mGap * 6 + 2) / (IKAS_mSize + 1.0); // 2～8
	float barWeight = (IKAS_mBold * 3 + 1) / (IKAS_mSize + 1.0); // 1～4

	float2 hparam = IKAS_ComputeHeightParam(height);
	float value = IKAS_GetValueFromSample(noteNo);
	float valueNext = IKAS_GetValueFromSample(noteNo + 1.0 / IKAS_OUTPUT_TEX_WIDTH);
	value += 1.0 / halfheight;
	valueNext += 1.0 / halfheight;

	// 塗りつぶし
	float valueBar = saturate((value + barWeight / halfheight - hparam.x) * halfheight + 1.0);

	// 折れ線
	float2 range = (value < valueNext) ? float2(value, valueNext) : float2(valueNext, value);
	range = (IKAS_mStyle < 0.8) ? range : value.xx;
	range.x -= barWeight * 2 / IKAS_OUTPUT_TEX_HEIGHT;
	range.y += barWeight * 2 / IKAS_OUTPUT_TEX_HEIGHT;
	float valueLine = (range.x <= hparam.x && hparam.x < range.y);

	// ライン状にするためのマスク
	float noteRange = IKAS_OUTPUT_TEX_HEIGHT / (gapInterval + barWeight);
	float lineRange = barWeight / (gapInterval + barWeight);
	float valueBarMask = ((frac(noteNo * noteRange) - lineRange) < 0);

	float valueGapBar = valueBar * valueBarMask;
	float valueDot = valueLine * valueBarMask;

	// 最終決定
	value = (IKAS_mStyle < 0.2) ? valueBar : valueGapBar;
	value = (IKAS_mStyle < 0.4) ? value : saturate(valueGapBar + valueLine);
	value = (IKAS_mStyle < 0.6) ? value : valueLine;
	value = (IKAS_mStyle < 0.8) ? value : valueDot;

	return value * hparam.y * IKAS_mBrightnessPower;
}

float IKAS_GetValue(float4 uv)
{
	return tex2Dlod(IKAS_OutputWorkSmp, uv).x;
}

float IKAS_CalcLod(float2 origUV)
{
#if IKAS_ENABLE_MIPMAP > 0
	float2 dx = ddx(origUV.xy * IKAS_OUTPUT_TEX_HEIGHT);
	float2 dy = ddy(origUV.xy * IKAS_OUTPUT_TEX_HEIGHT);
	float d = max(dot(dx, dx), dot(dy, dy));
	float lod = log2(d) * 0.5; // == log2(sqrt(d))
	return lod;
#else
	return 0;
#endif
}

// 極座標形式に変換
float4 IKAS_EuclidToPolar(float2 uv)
{
	float2 pos = uv * 2 - 1;
	float ang = atan2(-pos.y, pos.x) / 3.14159265 * 0.5 + 0.5;
	ang = ang + (IKAS_mAngleP - IKAS_mAngleM) * IKAS_Time;
		// IKAS_mAngleP == 1 のとき、1秒で1回転する。
	float r = 1 - length(pos);
	float lod = IKAS_CalcLod(uv);
	return float4(ang, r, 0, lod);
}

float2 IKAS_EuclidToLocal(float2 uv)
{
	float ang = uv.x;
	ang = (ang + (IKAS_mAngleP - IKAS_mAngleM) * IKAS_Time);
		// IKAS_mAngleP == 1 のとき、1秒で1回転する。
	float r = uv.y;
	return float2(ang, r);
}


float3 IKAS_MoveOffset()
{
	float2 values = tex2Dlod(IKAS_ValueWorkSmp2, float4(IKAS_mMoveNote, 0.5,0,0)).rg;
	float value = IKAS_GetChannelValue(values) * IKAS_mMoveScale * IKAS_MaxMoveScale;
	return mul(float3(0,0,-value), (float3x3)IKAS_mObjectMatrix);
}

struct IKAS_VS_OUTPUT {
	float4 Pos		: POSITION;	// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
};

IKAS_VS_OUTPUT IKAS_VS_Value( float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	IKAS_VS_OUTPUT Out = (IKAS_VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = float2(Tex.x + 0.5 / IKAS_VALUE_TEX_WIDTH, 0.5);
	// TODO: 計算用のパラメータをVSで計算しておく
	return Out;
}

float4 IKAS_PS_UpdateValue(IKAS_VS_OUTPUT IN) : COLOR
{
	float2 uv = IN.Tex.xy;

		float2 lastValue = tex2D(IKAS_ValueWorkSmp2, uv).rg;
		float attenuation = 1.0 / max(IKAS_TEX_FPS * IKAS_AttenuationSpeed, 1.0);
		float2 result = max(lastValue - attenuation, 0);

		// 0フレ目ならリセットする
		result = (IKAS_Time < 1.0 / 90.0) ? 0 : result;

		float2 value = IKAS_GetFFTValue(uv.x);
		result = max(result, value);

	return float4(result, 0, 1);
}

float4 IKAS_PS_CopyValue(IKAS_VS_OUTPUT IN) : COLOR
{
	float2 result = tex2D(IKAS_ValueWorkSmp, IN.Tex.xy).rg;

	// ブラー
	float wsum = 1;
	float sigma = (0.1 + IKAS_mSoftness * 1.9);
	float denom = -1.0 / (2 * sigma * sigma);
	float2 offset = float2(1.0 / IKAS_VALUE_TEX_WIDTH, 0);
	for(int i = 1; i < 8; i++)
	{
		float w = exp(i*i * denom);
		float2 result0 = tex2D(IKAS_ValueWorkSmp, IN.Tex.xy + i * offset).rg;
		float2 result1 = tex2D(IKAS_ValueWorkSmp, IN.Tex.xy - i * offset).rg;
		result += (result0 + result1) * w;
		wsum += w * 2;
	}

	result.xy *= (1 - IKAS_mHeight);
	return float4(result.xy / wsum, 0, 1);
}

IKAS_VS_OUTPUT IKAS_VS_DrawValue( float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	IKAS_VS_OUTPUT Out = (IKAS_VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex.xy + 0.5 / float2(IKAS_OUTPUT_TEX_WIDTH, IKAS_OUTPUT_TEX_HEIGHT);
	return Out;
}

float4 IKAS_PS_DrawValue(IKAS_VS_OUTPUT IN) : COLOR
{
	float value = IKAS_GetHeightValue(IN.Tex.x, IN.Tex.y);
	return float4(value, 0,0, 1);
}

#define IKAS_ValueRenderStates \
	ALPHABLENDENABLE = FALSE; ALPHATESTENABLE = FALSE; \
	ZENABLE = FALSE; ZWRITEENABLE = FALSE; \
	CULLMODE = NONE;

#define IKAS_Scripts \
	"RenderColorTarget0=IKAS_ValueWorkTex; RenderDepthStencilTarget=IKAS_ValueWorkDepthBuffer;" \
	"Pass=IKAS_UpdateValue;" \
	"RenderColorTarget0=IKAS_ValueWorkTex2; RenderDepthStencilTarget=IKAS_ValueWorkDepthBuffer;" \
	"Pass=IKAS_CopyValue;" \
	"RenderColorTarget0=IKAS_OutputWorkTex; RenderDepthStencilTarget=IKAS_OutputWorkDepthBuffer;" \
	"Pass=IKAS_DrawValue;" \
	"RenderColorTarget0=; RenderDepthStencilTarget=;"

#define IKAS_Passes \
	pass IKAS_UpdateValue < string Script= "Draw=Buffer;"; > { \
			IKAS_ValueRenderStates \
			VertexShader = compile vs_3_0 IKAS_VS_Value(); \
			PixelShader  = compile ps_3_0 IKAS_PS_UpdateValue(); \
		} \
		pass IKAS_CopyValue < string Script= "Draw=Buffer;"; > { \
			IKAS_ValueRenderStates \
			VertexShader = compile vs_3_0 IKAS_VS_Value(); \
			PixelShader  = compile ps_3_0 IKAS_PS_CopyValue(); \
		} \
		pass IKAS_DrawValue < string Script= "Draw=Buffer;"; > { \
			IKAS_ValueRenderStates \
			VertexShader = compile vs_3_0 IKAS_VS_DrawValue(); \
			PixelShader  = compile ps_3_0 IKAS_PS_DrawValue(); \
		}

// ここまで
//=============================================================================



float3 hsv2rgb(float3 c)
{
	float3 hcol = saturate((abs(frac(c.x + float3(3,2,1)/3)*6 - 3) - 1));
	return float3(lerp(1, hcol, c.y) * c.z);
}

//-----------------------------------------------------------------------------
// オブジェクト描画

float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 WorldMatrix : WORLD;
float4	MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
float4	TextureAddValue	: ADDINGTEXTURE;
float4	TextureMulValue	: MULTIPLYINGTEXTURE;

static float4 DiffuseColor = MaterialDiffuse;

texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;	MAGFILTER = LINEAR;	MIPFILTER = LINEAR;
	ADDRESSU  = WRAP;	ADDRESSV  = CLAMP;
};

struct VS_OUTPUT {
	float4 Pos		: POSITION;
	float2 Tex		: TEXCOORD0;
	// float3 Normal	: TEXCOORD1;
	float4 Color	: COLOR0;
};

VS_OUTPUT Object_VS(
	float4 Pos : POSITION,
	float3 Normal : NORMAL,
	float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Pos.xyz += IKAS_MoveOffset();

	Out.Pos = mul( Pos, WorldViewProjMatrix );
	// Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	Out.Color.rgb = hsv2rgb(float3(IKAS_mHue, IKAS_mSaturate, 1));
	Out.Color.a = DiffuseColor.a;
	Out.Tex = Tex;
	return Out;
}

float4 Object_PS(VS_OUTPUT IN) : COLOR
{
	float4 uv = IKAS_EuclidToPolar(IN.Tex.xy);
	// NOTE: 普通にtex2Dすると、つなぎ目で色が飛ぶ
	float4 result = IN.Color * tex2Dlod(ObjTexSampler, uv);
	float value = IKAS_GetValue(uv);
	float alpha = result.a * value;
	clip(alpha - 1e-4);

	result.a = alpha;

	return result;
}

#define RenderStates \
	ZENABLE = TRUE;	ZWRITEENABLE = FALSE; \
	ALPHABLENDENABLE = TRUE; ALPHATESTENABLE = TRUE; \
	CULLMODE = NONE;

#define OBJECT_TEC(name, mmdpass) \
	technique name < string MMDPass = mmdpass; \
		string Script = IKAS_Scripts \
			"Pass=DrawObject;"; \
	> { \
		IKAS_Passes \
		pass DrawObject { \
			RenderStates \
			VertexShader = compile vs_3_0 Object_VS(); \
			PixelShader  = compile ps_3_0 Object_PS(); \
		} \
	}

OBJECT_TEC(MainTec0, "object")
OBJECT_TEC(MainTec1, "object_ss")

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}


//-----------------------------------------------------------------------------
