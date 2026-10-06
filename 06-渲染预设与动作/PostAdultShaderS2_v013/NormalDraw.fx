/////////////////////////////////////////////////////////////////////
// 法線マップ v1
// データP

#define EdgeMaterial "0-"		// エッジを描画する材質番号
#define ALPHACLIP 0.5

float4x4 WVPMatrix : WORLDVIEWPROJECTION;
float4x4 WVMatrix : WORLDVIEW;

float4 MaterialDiffuse : DIFFUSE <string Object = "Geometry";>;

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////
// データ構造
struct Tex_Out {
	float4 Pos: POSITION;
	float2 Tex : TEXCOORD0;
	float3 Normal : TEXCOORD1;
};

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ShadowMapTec <string MMDPass = "zplot";>{}

////////////////////////////////////////////////////////////////////////////////
// オブジェクト
Tex_Out Object_VS(float4 Pos:POSITION, float3 Normal:NORMAL, float2 Tex:TEXCOORD0){
	Tex_Out o=(Tex_Out)0;
	o.Pos = mul(Pos, WVPMatrix);
	o.Tex = Tex;
	o.Normal = mul(Normal, (float3x3)WVMatrix);
	return o;
}

float4 Object_NoTex_PS(Tex_Out In, uniform float enable) : COLOR {
	clip(MaterialDiffuse.a-ALPHACLIP);
	float3 nc = 0.5*normalize(In.Normal) + float3(0.5,0.5,0.5); // 0-1の範囲に収める
	return float4(nc,enable);
}

float4 Object_Tex_PS(Tex_Out In, uniform float enable) : COLOR {
	clip(MaterialDiffuse.a*tex2D(ObjTexSampler, In.Tex).a-ALPHACLIP);
	float3 nc = 0.5*normalize(In.Normal) + float3(0.5,0.5,0.5); // 0-1の範囲に収める
	return float4(nc,enable);
}

#define DefTech(id_, pass_, tex, sym)\
	technique ObjectEdgeTec##id_ < string MMDPass = #pass_; string Subset=EdgeMaterial; bool UseTexture=tex;> {\
		pass DrawEdge {\
			AlphaBlendEnable = FALSE;\
			AlphaTestEnable = FALSE;\
			VertexShader = compile vs_2_0 Object_VS();\
			PixelShader  = compile ps_2_0 Object_##sym##_PS(1);\
		}\
	}\
	technique ObjectNoEdgeTec##id_ < string MMDPass = #pass_; bool UseTexture=tex;> {\
		pass DrawEdge {\
			AlphaBlendEnable = FALSE;\
			AlphaTestEnable = FALSE;\
			VertexShader = compile vs_2_0 Object_VS();\
			PixelShader  = compile ps_2_0 Object_##sym##_PS(0);\
		}\
	}\

DefTech(_0, object , true, Tex)
DefTech(_1, object , false, NoTex)
DefTech(_2, object_ss , true, Tex)
DefTech(_3, object_ss , false, NoTex)


