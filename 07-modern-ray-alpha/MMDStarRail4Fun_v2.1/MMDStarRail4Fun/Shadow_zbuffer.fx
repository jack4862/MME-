////  Shadow_zbuffer.fx
//  MMDStarRail4Fun
//
//  Created by hzy on 2025/4/20.
//  Copyright Â© 2019 Bilibili. All rights reserved.
//

float4x4 matWorld         	 : WORLD;
float4x4 matView         	 : VIEW;
float4x4 matWorldViewProject : WORLDVIEWPROJECTION;

float4 MaterialDiffuse : DIFFUSE<string Object = "Geometry";>;
bool use_texture;

float3 uCenter : CONTROLOBJECT < string name = "fun_controller.pmx"; string item = "‘S‚Ä‚Ìe"; >;

float uRange : CONTROLOBJECT < string name = "fun_controller.pmx"; string item = "ShadowRange"; >;
float uUp : CONTROLOBJECT < string name = "fun_controller.pmx"; string item = "ShadowUp"; >;
float uLeft : CONTROLOBJECT < string name = "fun_controller.pmx"; string item = "ShadowLeft"; >;
float uBottom : CONTROLOBJECT < string name = "fun_controller.pmx"; string item = "ShadowBottom"; >;
float uRight : CONTROLOBJECT < string name = "fun_controller.pmx"; string item = "ShadowRight"; >;

#define PI 3.1415926535

const static float DepthBias = 0.1;

float3x3 CreateViewRotate() {
	float pitch = (uUp - uBottom) * PI / 2.0;
	float yaw   = (uRight - uLeft) * PI / 2.0;

	float cosYaw   = cos(yaw);
	float sinYaw   = sin(yaw);
	float cosPitch = cos(pitch);
	float sinPitch = sin(pitch);

	float3x3 rotY = {
		cosYaw, 0, sinYaw,
		0,      1, 0,
		-sinYaw, 0, cosYaw
	};

	float3x3 rotX = {
		1, 0,        0,
		0, cosPitch, -sinPitch,
		0, sinPitch, cosPitch
	};

	return mul(rotY, rotX);
}

float4x4 CreateOrthographicMatrix(float left, float right, float bottom, float top, float znear, float zfar)
{
    float4x4 orthoMatrix;

    orthoMatrix[0][0] = 2.0f / (right - left);
    orthoMatrix[0][1] = 0.0f;
    orthoMatrix[0][2] = 0.0f;
    orthoMatrix[0][3] = 0.0f;

    orthoMatrix[1][0] = 0.0f;
    orthoMatrix[1][1] = 2.0f / (top - bottom);
    orthoMatrix[1][2] = 0.0f;
    orthoMatrix[1][3] = 0.0f;

    orthoMatrix[2][0] = 0.0f;
    orthoMatrix[2][1] = 0.0f;
    orthoMatrix[2][2] = 1.0f / (zfar - znear);
    orthoMatrix[2][3] = 0.0f;

    orthoMatrix[3][0] = -(right + left) / (right - left);
    orthoMatrix[3][1] = -(top + bottom) / (top - bottom);
    orthoMatrix[3][2] = -znear / (zfar - znear);
    orthoMatrix[3][3] = 1.0f;

    return orthoMatrix;
}

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
	float3 positionWS = mul(Position, matWorld).xyz;

	float3x3 viewRotate = CreateViewRotate();
	float3x3 oldRotate = (float3x3)matView;
	float3x3 newRotate = mul(oldRotate, viewRotate);

	float3 forward = newRotate[2];
	forward.xy *= -1;

	float radius = lerp(6.25, 31.25, uRange);
	float3 centerWS = uCenter;
	float3 cameraPosWS = centerWS + normalize(-forward) * radius;
	float3 t = mul(-cameraPosWS, newRotate);

	float4x4 viewMatrix = float4x4(
		newRotate[0], 0,
		newRotate[1], 0,
		newRotate[2], 0,
		t,      1
	);

	float3 positionVS = mul(float4(positionWS, 1), viewMatrix).xyz;
	positionVS.z += DepthBias;

	float3 centerVS = mul(float4(centerWS, 1), viewMatrix).xyz;

	float4x4 projMatrix = CreateOrthographicMatrix(
		centerVS.x - radius,
		centerVS.x + radius,
		centerVS.y - radius,
		centerVS.y + radius,
		centerVS.z - radius,
		centerVS.z + radius
	);

	oPosition = mul(float4(positionVS, 1), projMatrix);
	oWorldPos = float4(Texcoord,0, positionVS.z);
}

float4 frag(in float4 worldPos : TEXCOORD0) : COLOR
{
	float2 uv = worldPos.xy;
	float alpha = MaterialDiffuse.a;
	if (use_texture) alpha *= tex2D(DiffuseMapSamp, uv).a;
	clip(alpha - 0.999);
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