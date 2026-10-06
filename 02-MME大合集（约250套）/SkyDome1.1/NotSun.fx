////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:まっくろシェーダー
//	作成;kion
//	種類:オブジェクト
//	説明:
//		full.fxの改良版
//		ピクセルシェーダーでライティング
//		テクニックの並びを少し変更
//  参考:full.fx ver1.3(by 舞力介入P)			
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
// ライトの行列
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

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

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;		// 射影変換座標
	float2 Tex	: TEXCOORD0;	// テクスチャ座標
};
// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0) 
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Out.Pos = mul(Pos, WorldViewProjMatrix);
	// テクスチャ座標
	Out.Tex = Tex;
	return Out;
}
// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT In, uniform bool useTexture) : COLOR
{
	// テクスチャ
	if(useTexture) DiffuseColor.a*=tex2D(ObjTexSampler,In.Tex).a;
	return float4(0,0,0, DiffuseColor.a);
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
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(false);
	}
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(true);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭 //
// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
	// カメラ視点のワールドビュー射影変換
	return mul( Pos, WorldViewProjMatrix );
}
// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
	return float4(0,0,0,1);
}
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable  = FALSE;
		VertexShader = compile vs_2_0 ColorRender_VS();
		PixelShader  = compile ps_2_0 ColorRender_PS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
}

///////////////////////////////////////////////////////////////////////////////////////////////
// シャドウバッファ
struct VS_ZValuePlot_OUTPUT {
	float4 Pos			: POSITION;	// 射影変換座標
	float4 ShadowMapTex	: TEXCOORD0;// Zバッファテクスチャ
};
// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;
	// ライトの目線によるワールドビュー射影変換をする
	Out.Pos = mul( Pos, LightWorldViewProjMatrix );
    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;
    return Out;
}
// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
	// R色成分にZ値を記録する
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 ZValuePlot_VS();
		PixelShader  = compile ps_2_0 ZValuePlot_PS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
