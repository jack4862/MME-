//=============================================================================
// エッジだけをボカす
//=============================================================================

// アクセの Si でブルームの強度を変更できます。
// アクセの Tr でエフェクト全体の強度を変更できます。

// 明るい部分だけをボカす
// ブルームを有効にする
#define ENABLE_BLOOM		0
// ブルームの強度
#define	BloomIntensity		0.5  // 0.0-5.0
// ブルームさせる明るさのしきい値
#define	BloomThreshold		1.5  // 1.0-2.0 程度

// 簡易レンズフレアを有効にする。ゴーストを発生させる
#define ENABLE_LENSFLARE	1
// ゴーストの色
#define GHOST_CLOR1	float3(0.3, 1.0, 0.5)
#define GHOST_CLOR2	float3(0.2, 0.1, 0.5)


// 全体的にボカす
// ソトフォーカスを有効にする
#define ENABLE_SOFTFOCUS	0
// ソフトフォーカスの強度
#define SoftfocusIntensity	0.5  // 0.0～1.0
// 乗算する。より強くボケる
#define USE_MULTIPLIED		1


// エッジをボカして、ジャギを軽減する。滲み(小)
// アンチエイリアスを有効にする。
#define ENABLE_AA		1
// アンチエイリアスの強度
#define AA_Intensity	0.5		// 0.0 - 1.0

// エッジをボカす。滲み(大)
#define ENABLE_EDGEBLUR	1



//-----------------------------------------------------------------------------
// あまりいじらない項目

//#define TEX_FORMAT	"A16B16G16R16F"
#define TEX_FORMAT	"A8R8G8B8"

float4 ClearColor = {1,1,1,1};
float ClearDepth  = 1.0;


//=============================================================================

#include "SoftfocusBody.fxsub"
