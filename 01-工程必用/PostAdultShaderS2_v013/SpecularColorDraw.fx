/////////////////////////////////////////////////////////////////////
// スペキュラマップ v1
// データP

float4x4 WVPMatrix : WORLDVIEWPROJECTION;

float4 MaterialDiffuse	: DIFFUSE <string Object = "Geometry";>;
float3 MaterialSpecular	: SPECULAR < string Object = "Geometry"; >;
float3 LightSpecular	: SPECULAR  < string Object = "Light"; >;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

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
struct Color_Out {
	float4 Pos: POSITION;
	float2 Tex: TEXCOORD0;
	float3 Color: COLOR0;
};

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ShadowMapTec <string MMDPass = "zplot";>{}

////////////////////////////////////////////////////////////////////////////////
// オブジェクト
Color_Out Object_VS(float4 Pos:POSITION, float2 Tex:TEXCOORD0){
	Color_Out o=(Color_Out)0;
	o.Pos = mul(Pos, WVPMatrix);
	o.Tex = Tex;
	o.Color = SpecularColor;
	return o;
}

float4 Object_NoTex_PS(float3 col:COLOR0) : COLOR {
	return float4(col, MaterialDiffuse.a);
}

float4 Object_Tex_PS(float2 Tex:TEXCOORD0, float3 col:COLOR0) : COLOR {
	return float4(col,MaterialDiffuse.a*tex2D(ObjTexSampler, Tex).a);
}

#define DefTech(id_, pass_, tex,sym)\
	technique ObjectTec##id_ < string MMDPass = #pass_; bool UseTexture=tex;> {\
		pass DrawEdge {\
			AlphaBlendEnable = true;\
			VertexShader = compile vs_2_0 Object_VS();\
			PixelShader  = compile ps_2_0 Object_##sym##_PS();\
		}\
	}\

DefTech(_0, object , true, Tex)
DefTech(_1, object , false, NoTex)
DefTech(_2, object_ss , true, Tex)
DefTech(_3, object_ss , false, NoTex)


