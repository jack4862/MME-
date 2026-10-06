////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:雲シェーダー
//	作成;kion
//	種類:オブジェクト
//	説明:
//		動的な雲(ドーム状)		
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
#include "CloudDome_config.h"
////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 時間[s]
float time_0_X : TIME;
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
float4x4 ViewMatrix			: VIEW;
float4x4 ProjMatrix			: PROJECTION;
// ライトの行列
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

// カメラ位置
float3 CameraPosition	: POSITION	< string Object = "Camera"; >;
// ライト方向
float3 LightDirection	: DIRECTION	< string Object = "Light"; >;

// オブジェクト材質
float4 MaterialDiffuse	: DIFFUSE	< string Object = "Geometry"; >;	// 拡散
// ライト色
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
float3 LightAmbient		: AMBIENT	< string Object = "Light"; >;	// 環境
float3 LightSpecular	: SPECULAR	< string Object = "Light"; >;	// 反射

// 拡散
static float4 DiffuseColor	= MaterialDiffuse * float4(LightDiffuse, 1.0f);

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// 太陽の位置
#include "GodRay_config.h"
#ifdef SYNCLIGHT
float3 SunXYZ : CONTROLOBJECT < string name = "Sun.x"; string item = "XYZ"; >;
static float3 SunPos = normalize(-LightDirection * SunXYZ.z);
#else
float4x4 SunMatrix : CONTROLOBJECT < string name = "Sun.x"; >;
static float3 SunPos = normalize(SunMatrix._41_42_43);
#endif

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）
// 頂点出力
struct VS_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float2 TexRaw	: TEXCOORD0;// そのまま
	float2 Tex		: TEXCOORD1;// テクスチャ座標雲用に変換
};
// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Pos.xyz*=Scale;
	Out.Pos = mul(Pos, WorldViewProjMatrix);
	// テクスチャ座標
	Out.Tex = Out.TexRaw = Tex;
	// 雲用に変換
	Out.Tex *= float2(1,5) * CloudTexDens;
	return Out;
}
// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT In) : COLOR
{
	// 雲色計算
	// テクスチャ利用
	float T= time_0_X * 0.01;
	float2 tex = T * SpeedDir;
	float4 c1, c2, c3;
	c1 = tex2D(smpSample1, In.Tex+tex*CloudMix[0]);
	c2 = tex2D(smpSample2, In.Tex+tex*CloudMix[1]);
	c3 = tex2D(smpSample3, In.Tex+tex*CloudMix[2]);
	float4 Color = (c1 + c2 + c3)*0.33;
	// 色を強調
	Color = (Color-(1-CloudDens))*CloudVolume;
	Color.rgb*=LightAmbient;
	Color.rgb = saturate(Color.rgb);
	// 輝度で透過
	Color.a=(Color.r+Color.g+Color.b)*0.33;
	Color.a=pow(Color.a, 1);
	Color.rgb = lerp(Color.rgb, 1-Color.rgb+0.9, max(0,dot(SunPos,float3(0,1,0))) );
	//Color.rgb = lerp(Color.rgb, 1-Color.rgb+0.9, max(0,dot(normalize(-LightDirection),float3(0,1,0))) );
	// 夜は暗くなる
	Color.rgb *= min(1, max(0,(0.1+SunPos.y)/0.1)+Dark);
	// 範囲を制限する
	Color.a *= 1-saturate(abs(In.TexRaw.y-0.4)/0.2);
	// ディフューズ色を考慮
	Color.a *= DiffuseColor.a;
	return saturate(Color)*CloudColor;
}
///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック（セルフシャドウOFF） //
// アクセサリ
technique MainTec0 < string MMDPass = "object"; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}
technique MainTecBS0 < string MMDPass = "object_ss"; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS();
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
