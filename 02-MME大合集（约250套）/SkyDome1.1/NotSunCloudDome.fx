////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:まっくろシェーダー
//	作成;kion
//	種類:オブジェクト
//	説明:
//		まっくろ
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// コントロールオブジェクト //
float4x4 Matrix : CONTROLOBJECT < string name = "Sun.x"; >;
float3 SunXYZ : CONTROLOBJECT < string name = "Sun.x"; string item = "XYZ";>;
// カメラ位置
float3 CameraPosition	: POSITION	< string Object = "Camera"; >;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// ライトに合わせる(コメントアウトで無効化)
#include "GodRay_config.h"

// 透過度以下を切り捨て
#define CLIP_ALPHA 0.5

// 雲の設定
#include "CloudDome_config.h"

// 濃淡をつける範囲
static float RevScale = SkyDomeScale*0.1*SunRevDistanceScale;	// 距離補正
#ifdef SYNCLIGHT
static float2 Param = {0, SunXYZ.z*RevScale};
#else
static float2 Param = {0, distance(Matrix._41_42_43,CameraPosition)*RevScale};
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 時間[s]
float time_0_X : TIME;
// カメラの行列
float4x4 WorldViewProjMatrix	: WORLDVIEWPROJECTION;

// オブジェクト材質
float4 MaterialDiffuse	: DIFFUSE	< string Object = "Geometry"; >;	// 拡散
// ライト色
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
float3 LightAmbient		: AMBIENT	< string Object = "Light"; >;	// 環境
// 拡散
static float4 DiffuseColor	= MaterialDiffuse * float4(LightDiffuse, 1.0f);

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画
// 頂点出力
struct VS_OUTPUT {
	float4 Pos		: POSITION;	// 射影変換座標
	float4 PosW		: TEXCOORD0;// 変換済み座標
	float2 TexRaw	: TEXCOORD1;// そのまま
	float2 Tex		: TEXCOORD2;// テクスチャ座標雲用に変換
};
// 頂点シェーダ
VS_OUTPUT Z_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0) 
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Pos.xyz*=Scale;
	Out.PosW = Out.Pos = mul(Pos, WorldViewProjMatrix);
	// テクスチャ座標
	Out.Tex = Out.TexRaw = Tex;	// そのまま
	//Out.Tex = (Pos.xz + 0.5) * 0.5;	// ローカルXZ座標
	// 雲用に変換
	Out.Tex *= float2(0.2,1) * CloudTexDens;
	return Out;
}
// ピクセルシェーダ
float4 Z_PS(VS_OUTPUT In) : COLOR
{
	// テクスチャ利用
	float T= time_0_X * 0.01;
	float2 tex = T * SpeedDir;
	float4 c1, c2, c3;
	c1 = tex2D(smpSample1, In.Tex+tex*CloudMix[0]);
	c2 = tex2D(smpSample2, In.Tex+tex*CloudMix[1]);
	c3 = tex2D(smpSample3, In.Tex+tex*CloudMix[2]);
	float4 Color = (c1 + c2 + c3)*0.33;
	// 色を強調
	Color.rgb = (Color.rgb-(1-CloudDens))*CloudVolume;
	Color.rgb*=LightAmbient;
	Color.rgb = saturate(Color.rgb);
	// 輝度で透過
	Color.a=(Color.r+Color.g+Color.b)*0.33;
	Color.a=pow(Color.a, 1);
	// 範囲を制限する
	Color.a *= 1-saturate(abs(In.TexRaw.y-0.4)/0.2);
	// ディフューズ色を考慮
	Color.a *= DiffuseColor.a;
	Color.a = saturate(Color.a)*CloudColor.a;
	// 透過
	Color.rgb = 0;
	return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック //
technique MainTec0 < string MMDPass = "object"; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS();
	}
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > { }
// 影（非セルフシャドウ）描画
technique ShadowTec < string MMDPass = "shadow"; > { }
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
