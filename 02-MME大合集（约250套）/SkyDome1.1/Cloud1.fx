////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:雲シェーダー
//	作成;kion(ビームマンP/MME_Cloud0.5の改変)
//	種類:オブジェクト
//	説明:
//		動的な雲		
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// 雲の設定
#include "Cloud1_config.h"
////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 時間[s]
float time_0_X : TIME;
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
// ライト方向
float3 LightDirection	: DIRECTION	< string Object = "Light"; >;

// モデル拡散
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
// ライト色
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
float3 LightAmbient		: AMBIENT	< string Object = "Light"; >;	// 環境
float3 LightSpecular	: SPECULAR	< string Object = "Light"; >;	// 反射
// 拡散光
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);

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

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点出力
struct VS_OUTPUT {
	float4 Pos		: POSITION;	// 変換済み座標
	float2 TexRaw	: TEXCOORD0;// そのまま
	float2 Tex		: TEXCOORD1;// テクスチャ座標雲用に変換
};
// 頂点シェーダ
VS_OUTPUT VS(float4 Pos : POSITION, float2 Tex : TEXCOORD){
	VS_OUTPUT Out = (VS_OUTPUT)1;
	// サイズ補正
	Pos.xyz*=100*Scale;
	// 頂点変換
	Out.Pos = mul(Pos, WorldViewProjMatrix);
	// テクスチャ座標
	Out.Tex = Out.TexRaw = Tex;	// そのまま
	//Out.Tex = (Pos.xz + 0.5) * 0.5;	// ローカルXZ座標
	// 雲用に変換
	Out.Tex *= float2(0.2,1) * CloudTexDens;
	return Out;
}
//ピクセルシェーダ
float4 PS(VS_OUTPUT In) : COLOR
{
	// テクスチャ利用
	float T= time_0_X * Speed * 0.01;
	float2 tex = T * ScrollDir;
	float4 c1, c2, c3;
	c1 = tex2D(smpSample1, In.Tex+tex*CloudMix[0]);
	c2 = tex2D(smpSample2, In.Tex+tex*CloudMix[1]);
	c3 = tex2D(smpSample3, In.Tex+tex*CloudMix[2]);
	float4 Color = (c1 + c2 + c3)*0.33;
	float L = (Color.r+Color.g+Color.b)*0.33;
	// 色を強調
	Color.rgb = (Color.rgb-(1-CloudDens))*CloudVolume;
	Color.rgb*=LightAmbient;
	Color.rgb = saturate(Color.rgb);
	// 輝度で透過
	Color.a=(Color.r+Color.g+Color.b)*0.33;
	Color.a=pow(Color.a, 1);
	// 太陽が上になるほど明るい部分を暗くする
	Color.rgb = lerp(Color.rgb, 1-Color.rgb+0.9, max(0,dot(SunPos,float3(0,1,0))) );
	// 夜は暗くなる
	Color.rgb *= min(1, max(0,(0.1+SunPos.y)/0.1)+Dark);
	// 境界をぼかす
	float2 tcenter = (In.TexRaw-0.5) * 2.0;
	Color.a *= saturate((0.7-length(tcenter))/0.1);
	// ディフューズ色を考慮
	Color.a *= DiffuseColor.a;
	return saturate(Color)*CloudColor;
}

//テクニックの定義
technique MainTec0 < string MMDPass = "object"; > {
//technique MainTec0 < string Script = "RenderColorTarget0=; RenderDepthStencilTarget=; Pass=CloudPass;"; > {
	pass CloudPass {
		//Z値の考慮：する
		//ZENABLE = TRUE;
		//Z値の描画：しない
		//ZWRITEENABLE = FALSE;
		//カリングオフ（両面描画
		//CULLMODE = NONE;
		VertexShader = compile vs_2_0 VS();
		PixelShader = compile ps_2_0 PS();
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
