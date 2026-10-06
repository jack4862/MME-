////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:非表示シェーダー
//	作成;kion
//	種類:オブジェクト
//	説明:
//		表示しない		
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
#include "Moon_config.h"
////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix: VIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
float4x4 ViewMatrix			: VIEW;
float4x4 ProjMatrix			: PROJECTION;
// ビルボード行列
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;
static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};
// ライト方向
float3 LightDirection	: DIRECTION	< string Object = "Light"; >;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

// テクスチャ
// オブジェクト
texture ObjectTexture: MATERIALTEXTURE;
// サンプラー
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR;
};
// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// その他パラメータと処理 //
// 月の位置と太陽の位置
#include "GodRay_config.h"
float SkyDomeScale : CONTROLOBJECT < string name = "SkyDome.x"; >;	// 距離補正
static float RevScale = SkyDomeScale*0.1*SunRevDistanceScale;
#ifdef SYNCLIGHT
float3 MoonXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ";>;	// 座標
static float3 MoonPos = -LightDirection * MoonXYZ.z * RevScale;
float3 SunXYZ : CONTROLOBJECT < string name = "Sun.x"; string item = "XYZ";>;	// 座標
static float3 SunPos = -LightDirection * SunXYZ.z * RevScale;
#else
float4x4 MoonMatrix : CONTROLOBJECT < string name = "(self)"; >;// 行列
static float3 MoonPos = MoonMatrix._41_42_43*RevScale;
float4x4 SunMatrix : CONTROLOBJECT < string name = "Sun.x"; >;	// 行列
static float3 SunPos = SunMatrix._41_42_43*RevScale;
#endif

// サイズ固定のビルボード
float4 TransformFixSizeBillboard(float4 Pos, float Size){
	Pos.y *= ViewportSize.x / ViewportSize.y;
	Pos.xyz *= Size;
	float4 spos = mul(float4(MoonPos, 1), ViewProjMatrix);
	if(spos.w<0.0) return float4(0,0,-1,1);
	else Pos.xyz += spos.xyz/spos.w;
	return float4(Pos.xyz, 1);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;
	float2 Tex	: TEXCOORD0;
};
// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ビルボード
#ifdef SYNCLIGHT
	Out.Pos = TransformFixSizeBillboard(Pos, Scale*0.01);
#else
	Out.Pos = TransformFixSizeBillboard(Pos, Scale*0.01);
#endif
	// テクスチャ座標
	Out.Tex=Tex;
	return Out;
}
// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT In) : COLOR
{
	// テクスチャ色
	float4 TexColor = tex2D(ObjTexSampler, In.Tex);
	// 地面に近づくほど透明になる
	TexColor.a *= saturate(dot(normalize(MoonPos),float3(0,1,0)));
	// 太陽が出るほど透明になる
	TexColor.a *= 1.0-saturate(dot(normalize(SunPos),float3(0,1,0)));
	// 太陽に近づくほど透明になる
	TexColor.a *= 1.0-saturate(dot(normalize(MoonPos),normalize(SunPos)));
	// 満ち欠け(ランバート拡散光)
	float3 Normal = (tex2D(smpMoonNormal, In.Tex).xyz-0.5)*2;
	TexColor.rgb *= saturate(dot(Normal,normalize(WaWMoonDir)));
	// グラデーションのテクスチャ位置
	float tex = dot(normalize(MoonPos),float3(0,1,0));
	// グラデーションを付けて出力
	return tex2D(smpMoon,saturate(tex))*TexColor*MoonColor;
}
///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック（セルフシャドウOFF） //
// アクセサリ
technique MainTec < string MMDPass = "object"; > {
	pass DrawObject {
		CULLMODE = NONE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}
technique MainTecBS < string MMDPass = "object_ss"; > {
	pass DrawObject {
		CULLMODE = NONE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
}

///////////////////////////////////////////////////////////////////////////////////////////////
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
}

///////////////////////////////////////////////////////////////////////////////////////////////
