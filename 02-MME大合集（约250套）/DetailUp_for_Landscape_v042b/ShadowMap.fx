////////////////////////////////////////////////////////////////////////////////////////////////
//
//  ShadowMap.fx v0.3
//  作成: データP
//
////////////////////////////////////////////////////////////////////////////////////////////////

#include "config.h"

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

#if SOFTSHADOW==SOFTSHADOW_VSM_LARGE
#define SHADOWMAP_MIP 0
#else
#define SHADOWMAP_MIP 1
#endif
shared texture ShadowMap : OFFSCREENRENDERTARGET <
	string Description = "ShadowMap";
	string Format = "D3DFMT_R32F";
	int2 Dimensions = {SHADOWMAP_WIDTH, SHADOWMAP_HEIGHT};
	float4 ClearColor = { 1, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	int Miplevels = SHADOWMAP_MIP;
	string DefaultEffect =
	    "self = hide;"
	    "*=ShadowDraw.fx;";
>;

// 見えないように各種テクニックを潰す
technique MainTec < string MMDPass = "object"; > { }
technique MainTec < string MMDPass = "object_ss"; > { }
technique MainTec < string MMDPass = "zplot"; > { }
technique MainTec < string MMDPass = "edge"; > { }
technique MainTec < string MMDPass = "shadow"; > { }

