#include "../../lighting_common.fxsub"

#include "../../../ray.conf"
#include "../../../ray_advanced.conf"
#include "../../../shader/math.fxsub"
#include "../../../shader/Layer.fxsub"
#include "../../../shader/common.fxsub"
#include "../../../shader/gbuffer.fxsub"
#include "../../../shader/gbuffer_sampler.fxsub"

static const float2 lightIntensityLimits = float2(1.0, 10.0);

float mR : CONTROLOBJECT<string name = "(self)"; string item = "R+";>;
float mG : CONTROLOBJECT<string name = "(self)"; string item = "G+";>;
float mB : CONTROLOBJECT<string name = "(self)"; string item = "B+";>;
float mIntensityP : CONTROLOBJECT<string name = "(self)"; string item = "Intensity+";>;
float mIntensityM : CONTROLOBJECT<string name = "(self)"; string item = "Intensity-";>;
float mMultiLightP : CONTROLOBJECT<string name = "ray_controller.pmx"; string item = "MultiLight+";>;
float mMultiLightM : CONTROLOBJECT<string name = "ray_controller.pmx"; string item = "MultiLight-";>;

float mWidthP : CONTROLOBJECT<string name="(self)"; string item = "Width+";>;
float mWidthM : CONTROLOBJECT<string name="(self)"; string item = "Width-";>;
float mFadeP : CONTROLOBJECT<string name="(self)"; string item = "Fade+";>;
float mFadeM : CONTROLOBJECT<string name="(self)"; string item = "Fade-";>;
float mThresholdP : CONTROLOBJECT<string name="(self)"; string item = "Threshold+";>;
float mThresholdM : CONTROLOBJECT<string name="(self)"; string item = "Threshold-";>;

float3 mPosition : CONTROLOBJECT<string name = "(self)"; string item = "Position";>;
float3 mDirection : CONTROLOBJECT<string name = "(self)"; string item = "Direction";>;

static const float LightIntensity = lerp(lerp(lightIntensityLimits.x, lightIntensityLimits.y, mIntensityP), 0, mIntensityM);
static const float LightIntensity2 = lerp(lerp(mLightIntensityMin, mLightIntensityMax, mMultiLightP), 0, mMultiLightM);

static float mWidth = lerp(lerp(5, 20, mWidthP), 0, mWidthM);
static float mFade = lerp(lerp(0.8, 0, mFadeP), 1, mFadeM);
static float mThreshold = lerp(lerp(0.625, 1, mThresholdP), 0, mThresholdM);

static const float3 LightPosition = mPosition;
static const float3 LightDirection = normalize(mDirection - mPosition);
static const float3 LightColor = float3(mR, mG, mB) * LightIntensity * LightIntensity2;

static const float3 viewLightDirection = normalize(mul(-LightDirection, (float3x3)matView));

void ShadingMaterial(sampler MRT4, float4 texcoord, inout float3 diffuse, inout float3 specular)
{
	float2 coord = texcoord.xy / texcoord.w;

	float linearEyeDepth = tex2Dlod(MRT4, float4(coord, 0, 0)).r;
	float cameraDistanceFix = 1/(0.08 + linearEyeDepth);
	float uvOffsetMultiplier = max(0, mWidth) * 5 * cameraDistanceFix / 100;

	float3 lightDirectionVS = viewLightDirection;
	float2 offset = lightDirectionVS.xy * uvOffsetMultiplier * float2(1, -1);
	float offsetLinearEyeDepth = tex2Dlod(MRT4, float4(coord + offset, 0, 0)).r;
	float rimLight = saturate((offsetLinearEyeDepth - (linearEyeDepth + mThreshold)) * mFade);
	diffuse = rimLight * LightColor;
	specular = rimLight * LightColor;
}

void GetGbufferParams(float4 texcoord, out MaterialParam materialAlpha)
{
	float2 coord = texcoord.xy / texcoord.w;

	float4 MRT5 = tex2Dlod(Gbuffer5Map, float4(coord, 0, 0));
	float4 MRT6 = tex2Dlod(Gbuffer6Map, float4(coord, 0, 0));
	float4 MRT7 = tex2Dlod(Gbuffer7Map, float4(coord, 0, 0));
	float4 MRT8 = tex2Dlod(Gbuffer8Map, float4(coord, 0, 0));

	DecodeGbuffer(MRT5, MRT6, MRT7, MRT8, materialAlpha);

	clip(sum(materialAlpha.albedo + materialAlpha.specular) - 1e-5);
}

void UseLayer(float4 texcoord, inout float3 diffuse, inout float3 specular, inout float3 diffuseAlpha, inout float3 specularAlpha)
{
	float2 coord = texcoord.xy / texcoord.w;
	float mul = CalculateLayer(LayerSamp, coord, mLayers);
	diffuse *= mul;
	specular *= mul;
	diffuseAlpha *= mul;
	specularAlpha *= mul;
}

void LightSourceVS(
	in float4 Position : POSITION,
	in float3 Normal : NORMAL,
	in float2 Texcoord : TEXCOORD0,
	out float4 oTexcoord0 : TEXCOORD0,
	out float4 oTexcoord1 : TEXCOORD1,
	out float4 oPosition  : POSITION)
{
	Position.xyz = LightPosition + Normal * 2000;
	oTexcoord1 = -mul(Position, matView);
	oTexcoord0 = oPosition = mul(Position, matViewProject);
	oTexcoord0.xy = PosToCoord(oTexcoord0.xy / oTexcoord0.w) + ViewportOffset;
	oTexcoord0.xy = oTexcoord0.xy * oTexcoord0.w;
}

void LightSourcePS(
	float4 coord : TEXCOORD0, 
	float3 viewdir : TEXCOORD1,
	out float4 oColor0 : COLOR0,
	out float4 oColor1 : COLOR1,
	out float4 oColor2 : COLOR2)
{
	MaterialParam materialAlpha;
	GetGbufferParams(coord, materialAlpha);

	float3 diffuse = 0, specular = 0;
	float3 diffuseAlpha = 0, specularAlpha = 0;

	ShadingMaterial(Gbuffer4Map, coord, diffuse, specular);
	ShadingMaterial(Gbuffer8Map, coord, diffuseAlpha, specularAlpha);

	UseLayer(coord, diffuse, specular, diffuseAlpha, specularAlpha);

	oColor0 = float4(diffuse, 0);
	oColor1 = float4(specular, 0);
	oColor2 = float4(diffuseAlpha * materialAlpha.albedo + specularAlpha, 0);
}

technique MainTech0<string MMDPass = "object";
	string Script = 
		"RenderColorTarget0=;"
		"RenderColorTarget1=LightSpecMap;"
		"RenderColorTarget2=LightAlphaMap;"
		"Pass=DrawObject;"
;>{
	pass DrawObject {
		ZEnable = false; ZWriteEnable = false;
		AlphaBlendEnable = TRUE; AlphaTestEnable = FALSE;
		SrcBlend = ONE; DestBlend = ONE;
		CullMode = CW;
		VertexShader = compile vs_3_0 LightSourceVS();
		PixelShader  = compile ps_3_0 LightSourcePS();
	}
}

technique MainTecBS0<string MMDPass = "object_ss";
	string Script = 
		"RenderColorTarget0=;"
		"RenderColorTarget1=LightSpecMap;"
		"RenderColorTarget2=LightAlphaMap;"
		"Pass=DrawObject;"
;>{
	pass DrawObject {
		ZEnable = false; ZWriteEnable = false;
		AlphaBlendEnable = TRUE; AlphaTestEnable = FALSE;
		SrcBlend = ONE; DestBlend = ONE;
		CullMode = CW;
		VertexShader = compile vs_3_0 LightSourceVS();
		PixelShader  = compile ps_3_0 LightSourcePS();
	}
}

technique EdgeTec<string MMDPass = "edge";>{}
technique ShadowTech<string MMDPass = "shadow";>{}
technique ZplotTec<string MMDPass = "zplot";>{}