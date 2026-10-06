////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:カメラとの距離を出力
//	作成;kion
//	種類:オブジェクト
//	説明:
//		カメラとの距離を出力
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメーター //
// 透過度以下を切り捨て
#define CLIP_ALPHA	0.1

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 座標変換行列
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 WorldViewMatrix	: WORLDVIEW;

// オブジェクト材質
float4 MaterialDiffuse	: DIFFUSE	< string Object = "Geometry"; >;	// 拡散
// 拡散
static float4 DiffuseColor	= MaterialDiffuse;

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
// オブジェクト描画
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;		// 射影変換座標
	float4 PosV	: TEXCOORD0;	// 変換済み座標
	float2 Tex	: TEXCOORD1;	// テクスチャ座標
};
// 頂点シェーダ
VS_OUTPUT Z_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0) 
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Out.Pos = mul(Pos, WorldViewProjMatrix);
	Out.PosV = mul(Pos, WorldViewMatrix);
	// テクスチャ座標
	Out.Tex = Tex;
	return Out;
}
// ピクセルシェーダ
float4 Z_PS(VS_OUTPUT In, uniform bool useTexture) : COLOR
{
	// テクスチャ
	if(useTexture) DiffuseColor.a*=tex2D(ObjTexSampler,In.Tex).a;
	if(DiffuseColor.a<=CLIP_ALPHA) clip(-1);
	// 深度
	float depth;
	depth = length(In.PosV.xyz/In.PosV.w);
	return float4(depth,0,0,1);
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

////////////////////////////////////////////////////////////////////////////////////////////////
// ピクセルシェーダ
float4 EdgeZ_PS(VS_OUTPUT In) : COLOR
{
	// 深度
	float depth;
	depth = length(In.PosV.xyz/In.PosV.w);
	return float4(depth,0,0,1);
}
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 EdgeZ_PS();
	}
}
// 影（非セルフシャドウ）描画
technique ShadowTec < string MMDPass = "shadow"; > { }
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
