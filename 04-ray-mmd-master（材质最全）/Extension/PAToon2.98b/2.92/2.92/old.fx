//フラグ設定　使わないフラグの前には「//」を入れておく


//ハンドルエッジのフラグ（オンにするとコントローラーで色が変えられるがpmxのエッジ設定が生きない）
//#define HANDLE_EDGE


//モデルの材質Toon設定の優先設定
//#define MODEL_TOON

//コントローラー定義
#define PATOONCONTROLLER "PAToonコントローラー.pmx"


//HAToon2のパラメーター設定

//色相の変換（RGB→HSV、色がおかしくなる場合はオフにする）
#define BLENDDIFFUSE0TEXTURE "DiffuseHue.png"
#define BLENDDIFFUSE0TEXTURE_X 256
#define BLENDDIFFUSE0TEXTURE_Y 360

//トゥーンに青みを付ける（赤みのあるテクスチャでおかしくなる場合はオフ）
#define BLENDDIFFUSE1TEXTURE "DiffuseMulBySat.png"
#define BLENDDIFFUSE1TEXTURE_X 256
#define BLENDDIFFUSE1TEXTURE_Y 256

//デフォルトのトゥーン色（テクスチャを替えれば色調変更可。MODEL_TOONを有効にしてるとモデルの材質トゥーン優先）
#define BLENDDIFFUSE2TEXTURE "DiffuseMulc2.png"
#define BLENDDIFFUSE2TEXTURE_X 256
#define BLENDDIFFUSE2TEXTURE_Y 256

//材質を全体に明るく加算する（オフにするとモデルのデフォルトの色設定）
#define BLENDDIFFUSE3TEXTURE "DiffuseAdd.png"
#define BLENDDIFFUSE3TEXTURE_X 256
#define BLENDDIFFUSE3TEXTURE_Y 256

//反射色（スペキュラ）を使う（トゥーンで使うのは難しいのでオフでいいと思う）
//#define BLENDSPECULAR0TEXTURE "SpecularMul.png"
//#define BLENDSPECULAR0TEXTURE_X 256
//#define BLENDSPECULAR0TEXTURE_Y 256
#define BLENDSPECULAR1TEXTURE
#define BLENDSPECULAR1TEXTURE_X 256
#define BLENDSPECULAR1TEXTURE_Y 256

#define BLENDADDSPHERE0TEXTURE
#define BLENDADDSPHERE0TEXTURE_X 256
#define BLENDADDSPHERE0TEXTURE_Y 256

//加算スフィアにトゥーンをかける（弱い光沢は無視されやすい。オフにするとデフォルトのスフィア設定）
#define BLENDADDSPHERE1TEXTURE "AddSphereRepl.png"
#define BLENDADDSPHERE1TEXTURE_X 256
#define BLENDADDSPHERE1TEXTURE_Y 1

//#define BLENDADDSPHERE2TEXTURE
//#define BLENDADDSPHERE2TEXTURE_X 256
//#define BLENDADDSPHERE2TEXTURE_Y 256

//エッジテクスチャの有無
#define BLENDEDGE0TEXTURE
#define BLENDEDGE0TEXTURE_X 256
#define BLENDEDGE0TEXTURE_Y 256
//#define SHADE_TOONLESS
//#define AMBIENT_AS_BASE
//#define AMBIENT_TOON_AS_BASE

//PAToonのコントローラー用設定（いじる必要なし。コントローラー色調しないならオフの方が多少は軽い）
#define BLENDDIFFUSESHADOWTEXTURE "DiffuseShadowMask.png"
#define BLENDDIFFUSESHADOWTEXTURE_X 256
#define BLENDDIFFUSESHADOWTEXTURE_Y 256

#define BLENDDIFFUSEMATERIALTEXTURE "DiffuseMaterialMask.png"
#define BLENDDIFFUSEMATERIALTEXTURE_X 256
#define BLENDDIFFUSEMATERIALTEXTURE_Y 256

//LocalShadowのフラグ（オフにすると嘘影が使えない）
#define USE_LOCALSHADOW

//ExcellentShadowのフラグ（LocalShdaowを使うので必要ない）
//#define USE_EXCELLENTSHADOW

//HgShadowのフラグ（LocalShdaowを使うので必要ない)
//#define USE_HGSHADOW

//ノーマルマップのフラグ（ノーマルマップは各自用意）
//#define USE_NORMALMAP "NormalMap.png"




/////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////
// LocalShadowのパラメーター設定
// セルフ影の設定はここのパラメータを変更してください

// 影生成の計算に用いるデフォルトのライト方向(読み込んだ時の照明方向(X,Y,Z）。モデルが最も見栄えする方向を設定します)
#define LS_InitDirection  float3(-0.1, -0.1, 1.0)

// シャドウマップバッファサイズ（セルフ影マップの解像度、512,1024,2048,4196,8192のどれか）
// コントローラーでぼかせるので小さい数値でもいい。スペックに余裕があるなら大きくした方が楽。

#define LS_ShadowMapBuffSize  4196



// シャドウマップが適用させる範囲サイズ(フェイス部位より少し大きめのサイズを入力します)
#define LS_ShadowMapAreaSize  3.5

// シャドウマップが適用させる深度サイズ(モデル全体より少し大きめのサイズを入力します)
#define LS_ShadowMapDepthLength  20.0

// 影生成の計算に用いるデフォルトのぼかし強度(0～1で設定,モーフで調整可能なので,ここでは最小値を設定します)
#define LS_InitBlurPower  0

// 陰影が照明操作に連動するデフォルトの割合(0～1で設定,モーフで調整可能なので,ここでは最小値を設定します)
#define LS_LightSyncShade 0

// 遮蔽影が照明操作に連動するデフォルトの割合(0～1で設定,モーフで調整可能なので,ここでは最小値を設定します)
#define LS_LightSyncShadow 0

// 遮蔽影の濃度が照明操作に連0するデフォルトの割合(0～1で設定,モーフで調整可能なので,ここでは最小値を設定します)
#define LS_LightSyncDensity  0


//float LS_ShadowMapBuffSize = ( LS_ShadowMapBuffSizeA * 2 )

// VSMシャドウマップの実装
#define LS_UseSoftShadow  1
// 0 : 実装しない(ソフトシャドウは使えないけど描画速度は向上する)
// 1 : 実装する(ソフトシャドウが使えるようになります)

// フェイス材質を識別するためのキー数値(材質のキー設定した反射強度を10倍した値の小数部を入力します)
// PAToonではキー数値の設定をなくしているので無効です。
// #define LS_ExecKey  0.39

////////////////////////////////////////////////////////
////////////////////////////////////////////////////////







#include "PACore.hlsl"

