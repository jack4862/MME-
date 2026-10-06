//=============================================================================
// depth.fx
// ikBokeh.fxのために、線形の深度情報を出力する。
//=============================================================================

#include "WW_Settings.fxsub"

#if ENABLE_DOF > 0

#include "_ww_common.fxsub"

//=============================================================================

float4x4 ViewProjMatrix				: VIEWPROJECTION;

float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 WorkOffset = float2(0.5f, 0.5f) / (ViewportSize * TEXSIZE1);

shared texture WW_DepthMapRT: RENDERCOLORTARGET;
sampler DepthSamp = sampler_state {
	texture = <WW_DepthMapRT>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};


//=============================================================================

struct VS_OUTPUT {
	float4 Pos		: POSITION;
	float4 VPos		: TEXCOORD0;
};

VS_OUTPUT VS_Mirror(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	int planeNo = round(Pos.z * 10);

	float rotY = (90 - MirrorAngle * 0.5) * ((planeNo == 0) ? 1 : -1);
	float3x3 mat = RoundMatrixY(rotY * PI / 180.0);
	float2 offset = float2((planeNo == 0) ? 2 : 0, 0);
	Pos.xyz = float3(Tex.xy * 2 - offset, 0);
	Pos.xy *= AcsSi * FRAME_SCALE * 0.5 * float2(-1,1);
	Pos.xyz = mul(Pos.xyz, mat);
	Pos = mul( Pos, mWorldMat );
	Pos = mul( Pos, ViewProjMatrix );

	Out.Pos = Pos;
	Out.VPos = Pos;

	return Out;
}

float4 PS_Mirror(VS_OUTPUT IN) : COLOR
{
	float2 texCoord = IN.VPos.xy / IN.VPos.w * float2(1,-1);
	texCoord = texCoord * 0.5 + 0.5 + WorkOffset;
	float depth = tex2D(DepthSamp, texCoord).x;
	return float4(depth, 0, 0, 1);
}

#define OBJECT_TEC(name, mmdpass) \
	technique name < string MMDPass = mmdpass; > { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 VS_Mirror(); \
			PixelShader  = compile ps_3_0 PS_Mirror(); \
		} \
	}

OBJECT_TEC(MainTec0, "object")
OBJECT_TEC(MainTec1, "object_ss")

#else // ENABLE_DOF > 0
technique Tec0 < string MMDPass = "object"; > {}
technique Tec1 < string MMDPass = "object_ss"; > {}
#endif

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

//=============================================================================
