/////////////////////////////////////////////////////////////////////
// 深度マップ v1.2
// データP

#define ALPHACLIP 0.5
#define HalfDistance 50

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
	float4 VPos : TEXCOORD1;
};

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ShadowMapTec <string MMDPass = "zplot";>{}

////////////////////////////////////////////////////////////////////////////////
// オブジェクト
Tex_Out Object_VS(float4 Pos:POSITION, float2 Tex:TEXCOORD0){
	Tex_Out o=(Tex_Out)0;
	o.Pos = mul(Pos, WVPMatrix);
	o.Tex = Tex;
	o.VPos = mul(Pos, WVMatrix);
	return o;
}

float4 Object_NoTex_PS(Tex_Out In) : COLOR {
	clip(MaterialDiffuse.a-ALPHACLIP);
	float z = In.VPos.z/In.VPos.w;
	float Distance = z/(z+HalfDistance);
	return float4(Distance,0,0,1);
}

float4 Object_Tex_PS(Tex_Out In) : COLOR {
	clip(MaterialDiffuse.a*tex2D(ObjTexSampler, In.Tex).a-ALPHACLIP);
	float z = In.VPos.z/In.VPos.w;
	float Distance = z/(z+HalfDistance);
	return float4(Distance,0,0,1);
}

technique ObjectTec0 < string MMDPass = "object"; bool UseTexture=false;> {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		VertexShader = compile vs_2_0 Object_VS();
		PixelShader  = compile ps_2_0 Object_NoTex_PS();
	}
}

technique ObjectTec1 < string MMDPass = "object"; bool UseTexture=true;> {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		VertexShader = compile vs_2_0 Object_VS();
		PixelShader  = compile ps_2_0 Object_Tex_PS();
	}
}

technique ObjectTec2 < string MMDPass = "object_ss"; bool UseTexture=false;> {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		VertexShader = compile vs_2_0 Object_VS();
		PixelShader  = compile ps_2_0 Object_NoTex_PS();
	}
}

technique ObjectTec3 < string MMDPass = "object_ss"; bool UseTexture=true;> {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;

		VertexShader = compile vs_2_0 Object_VS();
		PixelShader  = compile ps_2_0 Object_Tex_PS();
	}
}

