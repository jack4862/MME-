////////////////////////////////////////////////////////////////////////////////////////////////
//
//  指定オブジェクトは単なるエフェクトコントローラなので非表示にする
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// 全て非表示にする
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }
technique MainTec < string MMDPass = "object"; > { }
technique MainTecBS  < string MMDPass = "object_ss"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
