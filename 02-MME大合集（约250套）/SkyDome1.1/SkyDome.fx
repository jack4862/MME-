////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:天空シェーダー
//	作成;kion
//	種類:オブジェクト
//	説明:
//		動的な空の色と雲		
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// 天空色計算 //
// テクスチャを混ぜる
//#define MIX_TEX
// 夜の暗さ(テクスチャ用)
float Dark = 0.2;
// 天空グラデーション
texture texSkyGrad < string ResourceName = "SkyGradation.jpg"; >;
sampler smpSkyGrad = sampler_state {
	texture = <texSkyGrad>;	Filter=LINEAR;	ADDRESSU = CLAMP; ADDRESSV = CLAMP; };
// 星空用テクスチャ
texture texNight < string ResourceName = "night.jpg"; >;
sampler smpNight = sampler_state {
	texture = <texNight>;	Filter=LINEAR;	ADDRESSU = WRAP; ADDRESSV = WRAP; };
float TexLoop =8.0;			// 星空テクスチャ繰り返し数
float NightSkyPower = 1.5;	// 星空の明るさ


////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
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

// テクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>; MINFILTER = LINEAR; MAGFILTER = LINEAR; };
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
	float2 Tex		: TEXCOORD0;	// テクスチャ座標
	float3 Normal	: TEXCOORD1;	// 法線(ワールド)
	float4 PosW		: TEXCOORD2;	// ワールド座標
};
// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Out.Pos = mul(Pos, WorldViewProjMatrix);
	// 頂点法線(ワールド空間)
	Out.Normal = normalize(mul(Normal,(float3x3)WorldMatrix));
	// テクスチャ座標
	Out.Tex = Tex;
	// ワールド座標
	Out.PosW = mul(Pos, WorldMatrix);
	return Out;
}
// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT In, uniform bool useTexture) : COLOR
{
	float4 Color = (float4)1;
	// 天球色計算
	In.PosW.xyz/=In.PosW.w;
	float3 lightdir = SunPos;
	// 時間を計算 -1～1
	float t = dot(lightdir, float3(0,1,0));
	// -1～1→0～1 テクスチャ座標に変換
	t = (t*0.5)+0.5;
	// 周囲の時間を含める
	t += dot(normalize(In.PosW), lightdir)*0.02;
	t = saturate(t);
	// 時間を元にグラデーションを取得
	Color = tex2D(smpSkyGrad, t);
	// テクスチャ混合
#ifdef MIX_TEX
	if(useTexture){
		float4 TexColor = tex2D(ObjTexSampler,In.Tex);
		float L = dot(TexColor.rgb, float3(0.29891f, 0.58661f, 0.11448f));
		Color.rgb = lerp(Color.rgb, (float3)TexColor.rgb, L);
		DiffuseColor.a *= Color.a;
		// 夜は暗くなる
		Color.rgb *= min(1, max(0,(0.1+lightdir.y)/0.1)+Dark);
	}
#endif
	// 星空のテクスチャ
	Color.rgb += tex2D(smpNight, In.Tex*TexLoop).rgb * saturate((0.45-t)/0.1)*NightSkyPower;

	// ディフューズ色を考慮
	Color.a *= DiffuseColor.a;
	return saturate(Color);
}
///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック（セルフシャドウOFF） //
// アクセサリ
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(false);
	}
}
technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(true);
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
