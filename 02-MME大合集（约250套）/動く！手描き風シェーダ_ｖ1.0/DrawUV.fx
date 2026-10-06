/////////////////////////////////////////////////////////////////////
// DrawUV.fx v0.2
// データP

//////////////////////////////////////////////////////

float NoTex_HatchingSize <
	string UIName = "テクスチャなしの時のハッチング粒度";
	string UIWidget = "Slider";
	bool UIVisible =  true;
	float UIMin = 1.0;
	float UIMax = 100.0;
	float UIDefault = 40.0;
> = float( 40.0 );

float Shadow_HatchingSize <
	string UIName = "地面影のハッチング粒度";
	string UIWidget = "Slider";
	bool UIVisible =  true;
	float UIMin = 1.0;
	float UIMax = 100.0;
	float UIDefault = 40.0;
> = float( 40.0 );

static const float NOTEX_RESOLUTION_RATE = 1/NoTex_HatchingSize;
static const float SHADOW_RESOLUTION_RATE = 1/Shadow_HatchingSize;

float4x4 WVPMatrix	: WORLDVIEWPROJECTION;
float4x4 WMatrix	: WORLD;

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
struct VS_Out {
	float4 Pos:		POSITION;
	float2 Tex:		TEXCOORD0;
	float4 WPos:	TEXCOORD1;
	float3 Normal:	TEXCOORD2;
};

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowMapTec <string MMDPass = "zplot";>{}

////////////////////////////////////////////////////////////////////////////////
// オブジェクト
#ifndef MIKUMIKUMOVING
VS_Out Object_VS(float4 Pos:POSITION, float3 Normal:NORMAL, float2 Tex:TEXCOORD0){
#else
VS_Out Object_VS(MMM_SKINNING_INPUT IN){
	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
	const float4 Pos = SkinOut.Position;
	const float3 Normal = SkinOut.Normal;
	const float2 Tex = IN.Tex;
#endif
	VS_Out o;
	o.Pos = mul(Pos, WVPMatrix);
	o.Tex = Tex;
	o.WPos = mul(Pos, WMatrix);
	o.Normal = mul(Normal, (float3x3)WMatrix);
	return o;
}

float4 Object_NoTex_PS(float4 WPos:TEXCOORD1, float3 Normal:TEXCOORD2) : COLOR {
	Normal=normalize(Normal);

	WPos/=WPos.w;
	WPos.xyz*=NOTEX_RESOLUTION_RATE;

	float2 Tex=WPos.yz;
	if(length(Normal.xy)<sqrt(0.5)){
		Tex=WPos.xy;
	}
	else if(length(Normal.xz)<sqrt(0.5)){
		Tex=WPos.xz;
	}
	Tex=frac(Tex+0.5);

	return float4(Tex,0,MaterialDiffuse.a!=0);
}

float4 Object_Tex_PS(float2 Tex: TEXCOORD0) : COLOR {
	return float4(Tex,0,MaterialDiffuse.a*tex2D(ObjTexSampler, Tex).a!=0);
}

float4 Object_Shadow_PS(float4 WPos:TEXCOORD1) : COLOR {
	WPos/=WPos.w;
	WPos.xz*=SHADOW_RESOLUTION_RATE;

	float2 Tex=frac(WPos.xz+0.5);

	return float4(Tex,0,MaterialDiffuse.a!=0);
}

technique ShadowTec < string MMDPass = "shadow"; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Object_VS();
		PixelShader  = compile ps_2_0 Object_Shadow_PS();
	}
}


#define DefTech(id_, pass_, tex, sym)\
	technique ObjectTec##id_ < string MMDPass = #pass_; bool UseTexture=tex;> {\
		pass DrawObject {\
			VertexShader = compile vs_2_0 Object_VS();\
			PixelShader  = compile ps_2_0 Object_##sym##_PS();\
		}\
	}\

DefTech(_0, object , true, Tex)
DefTech(_1, object , false, NoTex)
DefTech(_2, object_ss , true, Tex)
DefTech(_3, object_ss , false, NoTex)

