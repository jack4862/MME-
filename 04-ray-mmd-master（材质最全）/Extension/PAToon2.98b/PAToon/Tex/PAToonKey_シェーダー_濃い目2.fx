//PAToon2.98以降
//Key, 無印, lite統合版

//フラグ設定
//使わないフラグの前には「//」を入れておく


//追加材質色調（材質色にRGB、HSVの数値を加算、マイナス可。コントローラー値の10分の1に対応）
#define ADDMATERIALCOLOR
float3 AddMaterialRgb = float3(0.00, 0.00, 0.00);
float3 AddMaterialHsv = float3(0.00, 0.00, 0.00);

//追加トゥーン色調（トゥーンの色にRGB、HSVの数値を加算、マイナス可。コントローラー値の10分の1に対応）
#define ADDTOONCOLOR
float3 AddToonRgb     = float3(0.00, 0.00, 0.00);
float3 AddToonHsv     = float3(0.00, 0.00, 0.00);


//キーイング材質のカラーコントローラーオフ設定
#define FLAGCOLOROFF


//LocalShadwoの使用フラグ
//#define USE_LOCALSHADOW

// 材質を識別するためのキー数値、キーをオフにすると強制的に嘘影描写になります。
//#define LS_ExecKey  0.39


//ExcellentShadowのフラグ（キーイング材質以外に適用。HgShadowとどちらかを適用）
#define USE_EXCELLENTSHADOW

//HgShadowのフラグ（キーイング材質以外に適用。ExcellentShadowとどちらか。両方オンの場合はHgShadowが優先)
#define USE_HGSHADOW


//ハンドルエッジのフラグ
//#define HANDLE_EDGE

//ハンドルエッジの太さ倍率
static float PAEdgeWidth = 1.0;

//ハンドルエッジにモデル側の独自設定を反映するか（色, 半透明, 太さ）１で有効、０で無効    ※色無効で黒、半透明無効で非透過、太さ無効でデフォルト１
float3 HandleEdgeSettingON = float3(1, 1, 1);


//モデルの材質設定Toon色の優先
//#define MODEL_TOON


//外部コントローラー名
#define PATOONCONTROLLER "PAToonコントローラー.pmx"

//法線球面化のフラグ
#define USE_ROUNDNORMAL


//影傾向テクスチャのフラグ（テクスチャの右上1ドットに（0,0,0）の黒色を置くと優先される）
#define USE_SHADOWBIAS_TOONTEX
#define USE_SHADOWBIAS_SUBTEX

//影傾向テクスチャの外部指定
//#define USE_SHADOWBIASMAP  "ShadowBiasMap.png"

//ノーマルマップのフラグ（影傾向テクスチャと競合する場合、右上1ドット（0,0,0）の黒色を置いた影傾向テクスチャが優先される）
#define USE_NORMALMAP_TOONTEX
#define USE_NORMALMAP_SUBTEX

//ノーマルマップの外部指定（あまり使えない）
//#define USE_NORMALMAP  "NormalMap.png"


//HAToon2のパラメーター設定

//色相の変換（RGB→HSV、色がおかしくなる場合はオフにする）
#define BLENDDIFFUSE0TEXTURE "Tex/DiffuseHue.png"
#define BLENDDIFFUSE0TEXTURE_X 256
#define BLENDDIFFUSE0TEXTURE_Y 360

//トゥーンに青みを付ける（赤みのあるテクスチャでおかしくなる場合はオフ）
#define BLENDDIFFUSE1TEXTURE "Tex/DiffuseMulBySat.png"
#define BLENDDIFFUSE1TEXTURE_X 256
#define BLENDDIFFUSE1TEXTURE_Y 256

//デフォルトのトゥーン色（テクスチャを替えれば色調変更可。MODEL_TOONを有効にしてるとモデルの材質トゥーン優先）
#define BLENDDIFFUSE2TEXTURE "Tex/DiffuseMulc3.png"
#define BLENDDIFFUSE2TEXTURE_X 256
#define BLENDDIFFUSE2TEXTURE_Y 256

//材質を全体に明るく加算する（オフにするとモデルのデフォルトの色設定）
#define BLENDDIFFUSE3TEXTURE "Tex/DiffuseAdd.png"
#define BLENDDIFFUSE3TEXTURE_X 256
#define BLENDDIFFUSE3TEXTURE_Y 256

//反射色（スペキュラ）を使う（トゥーンで使うのは難しいのでオフでいいと思う）
//#define BLENDSPECULAR0TEXTURE "Tex/SpecularMul.png"
//#define BLENDSPECULAR0TEXTURE_X 256
//#define BLENDSPECULAR0TEXTURE_Y 256
#define BLENDSPECULAR1TEXTURE
#define BLENDSPECULAR1TEXTURE_X 256
#define BLENDSPECULAR1TEXTURE_Y 256

#define BLENDADDSPHERE0TEXTURE
#define BLENDADDSPHERE0TEXTURE_X 256
#define BLENDADDSPHERE0TEXTURE_Y 256

//加算スフィアにトゥーンをかける（弱い光沢は無視されやすい。オフにするとデフォルトのスフィア設定）
//#define BLENDADDSPHERE1TEXTURE "Tex/AddSphereRepl.png"
//#define BLENDADDSPHERE1TEXTURE_X 256
//#define BLENDADDSPHERE1TEXTURE_Y 1

//#define BLENDADDSPHERE2TEXTURE
//#define BLENDADDSPHERE2TEXTURE_X 256
//#define BLENDADDSPHERE2TEXTURE_Y 256

//エッジテクスチャの有無
#define BLENDEDGE0TEXTURE
#define BLENDEDGE0TEXTURE_X 256
#define BLENDEDGE0TEXTURE_Y 256

//死んでるフラグ（たぶん）
//#define SHADE_TOONLESS
//#define AMBIENT_AS_BASE
//#define AMBIENT_TOON_AS_BASE



//PAToonのコントローラー用設定（いじる必要なし。コントローラー色調しないならオフの方が多少は軽い）
#define BLENDDIFFUSESHADOWTEXTURE "Tex/DiffuseShadowMask.png"
#define BLENDDIFFUSESHADOWTEXTURE_X 256
#define BLENDDIFFUSESHADOWTEXTURE_Y 256

#define BLENDDIFFUSEMATERIALTEXTURE "Tex/DiffuseMaterialMask.png"
#define BLENDDIFFUSEMATERIALTEXTURE_X 256
#define BLENDDIFFUSEMATERIALTEXTURE_Y 256


//ノーマルマップのフラグ（ノーマルマップは各自用意）
//#define USE_NORMALMAP "NormalMap.png"


/////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////
// LocalShadowのパラメーター設定
// セルフ影の設定はここのパラメータを変更してください

// 影生成の計算に用いるデフォルトのライト方向(読み込んだ時の照明方向(X,Y,Z）。モデルが最も見栄えする方向を設定します)
#define LS_InitDirection  float3(-0.5, -0.1, 1.0)

// シャドウマップバッファサイズ（セルフ影マップの解像度、512,1024,2048,4196,8192のどれか）
// コントローラーでぼかせるので小さい数値でもいい。スペックに余裕があるなら大きくした方が楽。

#define LS_ShadowMapBuffSize  2048



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

// 遮蔽影の濃度が照明操作に連動するデフォルトの割合(0～1で設定,モーフで調整可能なので,ここでは最小値を設定します)
#define LS_LightSyncDensity  0


//float LS_ShadowMapBuffSize = ( LS_ShadowMapBuffSizeA * 2 )

// VSMシャドウマップの実装
#define LS_UseSoftShadow  1
// 0 : 実装しない(ソフトシャドウは使えないけど描画速度は向上する)
// 1 : 実装する(ソフトシャドウが使えるようになります)



////////////////////////////////////////////////////////
////////////////////////////////////////////////////////







#include "PACore.hlsl"

