////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:ホログラムオブジェクト
//	作成;kion
//	種類:オブジェクト
//	説明:
//		黒でマスク
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

// オブジェクト材質
float4 MaterialDiffuse	: DIFFUSE	< string Object = "Geometry"; >;	// 拡散
// ライト色
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
// 拡散
static float4 DiffuseColor	= MaterialDiffuse * float4(LightDiffuse, 1.0f);

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

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）
// 頂点出力
struct VS_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ座標
};
// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
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
	return float4(0.5, 0.5, 0.5, DiffuseColor.a);
}
///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック //
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; > {
	pass DrawObject {
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(false);
	}
}
technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; > {
	pass DrawObject {
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(true);
	}
}
technique MainTecBS0 < string MMDPass = "object_ss"; bool UseTexture = false; > {
	pass DrawObject {
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(false);
	}
}
technique MainTecBS1 < string MMDPass = "object_ss"; bool UseTexture = true; > {
	pass DrawObject {
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(true);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭 //
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable  = FALSE;
		VertexShader = compile vs_2_0 Basic_VS();
		PixelShader  = compile ps_2_0 Basic_PS(false);
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
