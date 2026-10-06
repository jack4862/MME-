////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:法線出力
//	作成;kion
//	種類:オブジェクト
//	説明:
//		法線を出力
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
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
float4x4 ViewMatrix			: VIEW;
float4x4 ProjMatrix			: PROJECTION;
// ライトの行列
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;
// カメラ位置
float3 CameraPosition	: POSITION	< string Object = "Camera"; >;

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
// オブジェクト描画
// 頂点出力
struct VS_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float3 Normal	: TEXCOORD0;	// 法線
	float2 Tex		: TEXCOORD1;	// テクスチャ座標
};
// 頂点シェーダ
VS_OUTPUT Normal_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0) 
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Out.Pos = mul(Pos, WorldViewProjMatrix);
	// 法線
	Out.Normal = mul(Normal, (float3x3)(mul(WorldMatrix,ViewMatrix)));	// ビュー
	//Out.Normal = mul(Normal, (float3x3)WorldMatrix);	// ワールド
	// テクスチャ座標
	Out.Tex = Tex;
	return Out;
}
// ピクセルシェーダ
float4 Normal_PS(VS_OUTPUT In, uniform bool useTexture) : COLOR
{
	// テクスチャ
	if(useTexture) DiffuseColor.a*=tex2D(ObjTexSampler,In.Tex).a;
	if(DiffuseColor.a<=CLIP_ALPHA) clip(-1);
	return float4(normalize(In.Normal)*0.5+0.5, DiffuseColor.a);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック //
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; > {
	pass DrawObject {
		//AlphaBlendEnable = FALSE;
		//CullMode = NONE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Normal_VS();
		PixelShader  = compile ps_2_0 Normal_PS(false);
	}
}
technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; > {
	pass DrawObject {
		//AlphaBlendEnable = FALSE;
		//CullMode = NONE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Normal_VS();
		PixelShader  = compile ps_2_0 Normal_PS(true);
	}
}
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; > {
	pass DrawObject {
		//AlphaBlendEnable = FALSE;
		//CullMode = NONE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Normal_VS();
		PixelShader  = compile ps_2_0 Normal_PS(false);
	}
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; > {
	pass DrawObject {
		//AlphaBlendEnable = FALSE;
		//CullMode = NONE;
		SRCBLEND = SRCALPHA;
		DESTBLEND = INVSRCALPHA;
		VertexShader = compile vs_2_0 Normal_VS();
		PixelShader  = compile ps_2_0 Normal_PS(true);
	}
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > { }
// 影（非セルフシャドウ）描画
technique ShadowTec < string MMDPass = "shadow"; > { }
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
