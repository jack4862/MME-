////  zbuffer_on.fx
//  RimLighting
//
//  Created by 洪梓嫣 on 2025/4/20.
//  Copyright © 2019 Bilibili. All rights reserved.
//

float4x4 matWorldViewProject : WORLDVIEWPROJECTION;

float4 MaterialDiffuse : DIFFUSE<string Object = "Geometry";>;
bool use_texture;

texture DiffuseMap: MATERIALTEXTURE;
sampler DiffuseMapSamp = sampler_state
{
	texture = <DiffuseMap>;
	MINFILTER = POINT; MAGFILTER = POINT; MIPFILTER = POINT;
	ADDRESSU = WRAP; ADDRESSV = WRAP;
};

void vert(
	in float4 Position : POSITION,
	in float2 Texcoord : TEXCOORD0,
	out float4 oWorldPos  : TEXCOORD0,
	out float4 oPosition  : POSITION)
{
	oPosition = mul(Position, matWorldViewProject);
	oWorldPos = float4(Texcoord,0, oPosition.w);
}

float4 frag(in float4 worldPos : TEXCOORD0) : COLOR
{
	float2 uv = worldPos.xy;
	float alpha = MaterialDiffuse.a;
	if (use_texture) alpha *= tex2D(DiffuseMapSamp, uv).a;
	clip(alpha - 0.01);
    return float4(worldPos.wwww);
}

#define OBJECT_TEC(name, mmdpass)\
	technique name<string MMDPass = mmdpass;\
	string Script =\
		"RenderColorTarget0=;"\
		"Pass=DrawObject;"\
	;>{\
		pass DrawObject {\
			AlphaTestEnable = false; AlphaBlendEnable = false;\
			VertexShader = compile vs_3_0 vert();\
			PixelShader  = compile ps_3_0 frag();\
		}\
	}

OBJECT_TEC(MainTec0, "object")
OBJECT_TEC(MainTecBS0, "object_ss")

technique EdgeTec<string MMDPass = "edge";>{}
technique ShadowTech<string MMDPass = "shadow";>{}
technique ZplotTec<string MMDPass = "zplot";>{}