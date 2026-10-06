//=============================================================================
// ikWorkingWall 本体簡易版
//=============================================================================

#include "WW_Settings.fxsub"
#include "_ww_common.fxsub"

//=============================================================================

#define BUFF_COLOR  { 0, 0, 0, 1 }

//テクスチャフォーマット
#if HDR_RENDER==0
	#define AL_TEXFORMAT "A8R8G8B8"
#else
	//#define AL_TEXFORMAT "A32B32G32R32F"
	#define AL_TEXFORMAT "A16B16G16R16F"
#endif

float4x4 ViewProjMatrix  : VIEWPROJECTION;

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 WorkOffset = float2(0.5f, 0.5f) / (ViewportSize * TEXSIZE1);

// 鏡面
texture WorkingWallRT : OFFSCREENRENDERTARGET <
	string Description = "OffScreen RenderTarget for ikWorkingWalls.fx";
	float2 ViewPortRatio = {TEXSIZE1, TEXSIZE1};
	float4 ClearColor = BUFF_COLOR;
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	string Format = AL_TEXFORMAT;
	string DefaultEffect = 
		"ikWorkingWalls.x = WW_Wall.fx;"
		CONTROLLER_NAME " = hide;"
		"*.x = WW_Object_noCheck.fx;"
		"* = WW_Object.fx;"
	;
>;
sampler WorkingWallView = sampler_state {
	texture = <WorkingWallRT>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU  = CLAMP; AddressV = CLAMP;
};


//=============================================================================

struct VS_OUTPUT {
	float4 Pos  : POSITION;
	float4 VPos : TEXCOORD0;
};

VS_OUTPUT VS_Mirror(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	int planeNo = round(Pos.z * 10);
	float side = ((planeNo == 0) ? 1 : -1); // 左右のどちら側か

	float rotY = (90 - MirrorAngle * 0.5) * side ;
	float3x3 mat = RoundMatrixY(DEG2RAD(rotY));
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
	float4 Color = tex2D(WorkingWallView, texCoord);
	Color.a *= AcsTr;
	return Color;
}

#define OBJECT_TEC(name, mmdpass) \
	technique name < string MMDPass = mmdpass; > {\
		pass DrawObject { \
			VertexShader = compile vs_3_0 VS_Mirror(); \
			PixelShader  = compile ps_3_0 PS_Mirror(); \
		} \
	}

OBJECT_TEC(MainTec0, "object")
OBJECT_TEC(MainTec1, "object_ss")

technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}
technique ZplotTec < string MMDPass = "zplot"; > {}

//=============================================================================
