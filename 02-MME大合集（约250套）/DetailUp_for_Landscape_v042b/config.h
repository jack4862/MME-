/////////////////////////////////////////////////////////
// DetailUp_for_Landscape用 カスタマイズファイル v0.42b
#ifndef CONFIG_H_
#define CONFIG_H_

// シャドウマップのサイズ
#define SHADOWMAP_WIDTH 2048
#define SHADOWMAP_HEIGHT 2048

// テクスチャバッファのサイズ(Mipmap/異方性フィルタ用)
#define TEXBUFFWIDTH 512
#define TEXBUFFHEIGHT 512

// 透過素材の透過率が高いものを切り捨てる割合 (1-255)
#define AlphaClipLimit 128

///////////////////////////////////////////////
// ソフトシャドウのアルゴリズム
#define SOFTSHADOW_NONE 0		// ソフトシャドウなし
#define SOFTSHADOW_VSM_SMALL 1	// 9点 VSM ソフトシャドウ
#define SOFTSHADOW_VSM_LARGE 2	// 30点 VSM ソフトシャドウ
#define SOFTSHADOW_PCF_SMALL 3	// 9点 PCF ソフトシャドウ
#define SOFTSHADOW_PCF_UNJAGGY 4 // 4点近傍 PCF ジャギー軽減

// 上記の何れかを選択
#define SOFTSHADOW SOFTSHADOW_VSM_SMALL


//////////////////////////////
// ソフトシャドウ 補正係数
#define SOFTSHADOW_DISTANCE 0.1	// ソフトシャドウを打ち切る距離(小さいほど遠い)
#define SOFTSHADOW_THRESHOLD 0.0005 // ソフトシャドウ補正値 大きいほど影が薄い

///////////////////////////////////////////////
// テクスチャの透過を固定したい場合
// 以下をコメントを解除。(行頭の"// "を取る)
//#define ShadowMinTr 0.75

///////////////////////////////////////////////
// 距離フォグ関係
#define FOG_ENABLE 1 // 1:フォグを有効にする 0:フォグを無効にする
#define FOG_CONTROLER "ShadowMap.x"  // フォグ制御用コントローラ名

///////////////////////////////////////////////
// フォグの値を固定したい場合
// 以下のコメントを解除。(行頭の"// "を取る)
//#define FOG_BRIGHT 1.0 // フォグの明るさ(MMD照明に対する割合)
//#define FOG_NEAR 500.0   // フォグの無い距離
//#define FOG_FAR 15000.0 // これ以上遠くはフォグだらけで見えないという距離
//#define FOG_COLOR float3(0.3, 0.3, 0.3) // フォグの色 (定義すると、MMD照明との連動がはずれる


#endif // CONFIG_H_
