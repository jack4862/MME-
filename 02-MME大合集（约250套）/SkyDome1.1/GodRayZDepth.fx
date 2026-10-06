////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:Z深度出力
//	作成;kion
//	種類:オブジェクト
//	説明:
//		Zを出力
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// 透過度以下を切り捨て
#define CLIP_ALPHA 0.1

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// カメラの行列
float4x4 WorldViewProjMatrix	: WORLDVIEWPROJECTION;

// オブジェクト材質
float4 MaterialDiffuse	: DIFFUSE	< string Object = "Geometry"; >;	// 拡散
// ライト色
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
// 拡散
static float4 DiffuseColor	= MaterialDiffuse * float4(LightDiffuse, 1.0f);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    Filter = LINEAR;
};
// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// 濃淡をつける範囲
#include "GodRay_config.h"
float SkyDomeScale : CONTROLOBJECT < string name = "SkyDome.x"; >;		// 距離補正
static float RevScale = SkyDomeScale*0.1*SunRevDistanceScale;
#ifdef SYNCLIGHT
float3 SunXYZ : CONTROLOBJECT < string name = "Sun.x"; string item = "XYZ";>;
static float2 Param = {0, abs(SunXYZ.z*RevScale)};
#else
float3 CameraPosition	: POSITION	< string Object = "Camera"; >;
float4x4 SunMatrix : CONTROLOBJECT < string name = "Sun.x"; >;
static float2 Param = {0, distance(SunMatrix._41_42_43,CameraPosition)*RevScale};
#endif


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;		// 射影変換座標
	float4 PosW	: TEXCOORD0;	// 変換済み座標
	float2 Tex	: TEXCOORD1;	// テクスチャ座標
};
// 頂点シェーダ
VS_OUTPUT Z_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0) 
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Out.PosW = Out.Pos = mul(Pos, WorldViewProjMatrix);
	// テクスチャ座標
	Out.Tex = Tex;
	return Out;
}
// ピクセルシェーダ
float4 Z_PS(VS_OUTPUT In, uniform bool useTexture) : COLOR
{
	float4 Color=(float4)1;
	// テクスチャ
	if(useTexture) DiffuseColor.a*=tex2D(ObjTexSampler,In.Tex).a;
	if(DiffuseColor.a<=CLIP_ALPHA) clip(-1);
	Color.rgb = saturate((In.PosW.w-Param.x)/(Param.y-Param.x));
	return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック //
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; > {
	pass DrawObject {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(false);
	}
}
technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; > {
	pass DrawObject {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(true);
	}
}
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; > {
	pass DrawObject {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(false);
	}
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; > {
	pass DrawObject {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(true);
	}
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > { }
// 影（非セルフシャドウ）描画
technique ShadowTec < string MMDPass = "shadow"; > { }
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
