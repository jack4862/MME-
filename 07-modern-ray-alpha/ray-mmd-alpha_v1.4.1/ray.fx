#include "ray.conf"
#include "ray_advanced.conf"

const float4 BackColor = 0.0;
const float4 WhiteColor = 1.0;
const float ClearDepth = 1.0;
const int ClearStencil = 0;

float mSunLightP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLight+";>;
float mSunLightM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLight-";>;
float mSunShadowRP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunShadowR+";>;
float mSunShadowGP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunShadowG+";>;
float mSunShadowBP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunShadowB+";>;
float mSunShadowVM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunShadowV-";>;
float mSSAOP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSAO+";>;
float mSSAOM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSAO-";>;
float mSSAORadiusP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSAORadius+";>;
float mSSAORadiusM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSAORadius-";>;
float mSSDOP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSDO+";>;
float mSSDOM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSDO-";>;
float mSSSSP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSSS+";>;
float mSSSSM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSSS-";>;
float mExposureP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Exposure+";>;
float mExposureM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Exposure-";>;
float mFstopP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Fstop+";>;
float mFstopM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Fstop-";>;
float mFocalLengthP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "FocalLength+";>;
float mFocalLengthM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "FocalLength-";>;
float mFocalDistanceP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "FocalDistance+";>;
float mFocalDistanceM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "FocalDistance-";>;
float mFocalRegionP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "FocalRegion+";>;
float mFocalRegionM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "FocalRegion-";>;
float mMeasureMode : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "MeasureMode";>;
float mTestMode : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "TestMode";>;
float mVignette : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Vignette";>;
float mDispersion : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Dispersion";>;
float mDispersionRadius : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "DispersionRadius";>;
float mContrastP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Contrast+";>;
float mContrastM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Contrast-";>;
float mSaturationP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Saturation+";>;
float mSaturationM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Saturation-";>;
float mGammaP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Gamma+";>;
float mGammaM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Gamma-";>;
float mColBalanceRP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BalanceR+";>;
float mColBalanceGP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BalanceG+";>;
float mColBalanceBP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BalanceB+";>;
float mColBalanceRM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BalanceR-";>;
float mColBalanceGM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BalanceG-";>;
float mColBalanceBM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BalanceB-";>;
float mTemperatureP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Temperature+";>;
float mTemperatureM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "Temperature-";>;

static float mSSAOScale = lerp(lerp(mSSDOIntensityMin, mSSDOIntensityMax, mSSAOP), 0, mSSAOM);
static float mSSAORadius = lerp(lerp(1.0, 2.0, mSSAORadiusP), 0.5, mSSAORadiusM);
static float mSSDOScale = lerp(lerp(mSSDOIntensityMin, mSSDOIntensityMax, mSSDOP), 0, mSSDOM);
static float mSSSSScale = lerp(lerp(mSSSSIntensityMin, mSSSSIntensityMax, mSSSSP), 0.25, mSSSSM);
static float mSunIntensity = lerp(lerp(mLightIntensityMin, mLightIntensityMax, mSunLightP), 0, mSunLightM);
static float mExposure = lerp(lerp(mExposureMin, mExposureMax, mExposureP), 0, mExposureM);
static float mColorContrast = lerp(lerp(1, 2, mContrastP), 0.5, mContrastM);
static float mColorSaturation = lerp(lerp(1, 2, mSaturationP), 0.0, mSaturationM);
static float mColorGamma = lerp(lerp(1.0, 0.45, mGammaP), 2.2, mGammaM);
static float mColorTemperature = lerp(lerp(mTemperature, 1000, mTemperatureP), 40000, mTemperatureM);
static float3 mColorShadowSunP = pow(float3(mSunShadowRP, mSunShadowGP, mSunShadowBP), 2);
static float3 mColorBalanceP = float3(mColBalanceRP, mColBalanceGP, mColBalanceBP);
static float3 mColorBalanceM = float3(mColBalanceRM, mColBalanceGM, mColBalanceBM);

float mSunLayer0FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer0-";>;
float mSunLayer1FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer1-";>;
float mSunLayer2FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer2-";>;
float mSunLayer3FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer3-";>;
float mSunLayer4FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer4-";>;
float mSunLayer5FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer5-";>;
float mSunLayer6FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer6-";>;
float mSunLayer7FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SunLayer7-";>;

static float2x4 mSunLayers = {
	mSunLayer0FadeM, mSunLayer1FadeM, mSunLayer2FadeM, mSunLayer3FadeM,
	mSunLayer4FadeM, mSunLayer5FadeM, mSunLayer6FadeM, mSunLayer7FadeM
};

float mSSRBlurP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRBlur+";>;
float mSSRBlurM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRBlur-";>;
float mSSRSmoothnessP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRSmoothness+";>;
float mSSRSmoothnessM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRSmoothness-";>;
float mSSRThicknessP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRThickness+";>;
float mSSRNormalBiasP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRNormalBias+";>;
float mSSRDirectionBiasP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRDirectionBias+";>;
float mSSRIntensityP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRIntensity+";>;
float mSSRIntensityM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRIntensity-";>;
float mSSRLayer0FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer0-";>;
float mSSRLayer1FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer1-";>;
float mSSRLayer2FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer2-";>;
float mSSRLayer3FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer3-";>;
float mSSRLayer4FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer4-";>;
float mSSRLayer5FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer5-";>;
float mSSRLayer6FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer6-";>;
float mSSRLayer7FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSRLayer7-";>;

static float2x4 mSSRLayers = {
	mSSRLayer0FadeM, mSSRLayer1FadeM, mSSRLayer2FadeM, mSSRLayer3FadeM,
	mSSRLayer4FadeM, mSSRLayer5FadeM, mSSRLayer6FadeM, mSSRLayer7FadeM
};

static float mSSRBlur = lerp(lerp(1024, 512, mSSRBlurP), 4096, mSSRBlurM);
static float mSSRSmoothness = lerp(lerp(0.0, 2, mSSRSmoothnessP), -1, mSSRSmoothnessM);
static float mSSRThickness = lerp(0.0, 100.0, mSSRThicknessP);
static float mSSRNormalBias = lerp(0.0, 10.0, mSSRNormalBiasP);
static float mSSRDirectionBias = lerp(0.0, 10.0, mSSRDirectionBiasP);
static float mSSRIntensity = lerp(lerp(1, 10, mSSRIntensityP), 0, mSSRIntensityM);

float mBloomThresholdP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomThreshold";>;
float mBloomIntensityP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomIntensity+";>;
float mBloomIntensityM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomIntensity-";>;
float mBloomScatterP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomScatter+";>;
float mBloomScatterM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomScatter-";>;
float mBloomDepthM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomDepth-";>;
float mBloomNearM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomNear-";>;
float mBloomEmissiveP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomEmissive+";>;
float mBloomEmissiveM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomEmissive-";>;
float mBloomRP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomR+";>;
float mBloomGP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomG+";>;
float mBloomBP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomB+";>;
float mBloomSaturationP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomSat+";>;
float mBloomSaturationM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomSat-";>;
float mBloomStarFade : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomStarFade";>;
float mBloomLayer0FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer0-";>;
float mBloomLayer1FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer1-";>;
float mBloomLayer2FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer2-";>;
float mBloomLayer3FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer3-";>;
float mBloomLayer4FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer4-";>;
float mBloomLayer5FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer5-";>;
float mBloomLayer6FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer6-";>;
float mBloomLayer7FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "BloomLayer7-";>;

static float2x4 mBloomLayers = {
	mBloomLayer0FadeM, mBloomLayer1FadeM, mBloomLayer2FadeM, mBloomLayer3FadeM,
	mBloomLayer4FadeM, mBloomLayer5FadeM, mBloomLayer6FadeM, mBloomLayer7FadeM
};

static float mBloomEmissiveMultiplier = lerp(lerp(1.0, 10.0, mBloomEmissiveP), 0.0, mBloomEmissiveM);
static float mBloomThreshold = (1.0 - mBloomThresholdP) / (mBloomThresholdP + 1e-5);
static float mBloomThresholdKnee = mBloomThreshold * 0.5;
static float mBloomIntensity = lerp(lerp(1.0, mBloomIntensityMax, mBloomIntensityP), mBloomIntensityMin, mBloomIntensityM);
static float mBloomScatter = lerp(lerp(0.7, 0.95, mBloomScatterP), 0.05, mBloomScatterM);
static float mBloomSaturation = lerp(lerp(1, 2, mBloomSaturationP), 0, mBloomSaturationM);

float mSSGIIntensityP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGIIntensity";>;
float mSSGIThresholdP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGIThreshold";>;
float mSSGIBlurSpreadP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGIBlurSpread";>;
float mSSGIDistAttenP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGIDistAtten";>;
float mSSGINearAttenP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGINearAtten";>;
float mSSGILumaLimitP : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILumaLimit";>;
float mSSGILayer0FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer0-";>;
float mSSGILayer1FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer1-";>;
float mSSGILayer2FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer2-";>;
float mSSGILayer3FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer3-";>;
float mSSGILayer4FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer4-";>;
float mSSGILayer5FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer5-";>;
float mSSGILayer6FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer6-";>;
float mSSGILayer7FadeM : CONTROLOBJECT<string name="ray_controller.pmx"; string item = "SSGILayer7-";>;

static float2x4 mSSGILayers = {
	mSSGILayer0FadeM, mSSGILayer1FadeM, mSSGILayer2FadeM, mSSGILayer3FadeM,
	mSSGILayer4FadeM, mSSGILayer5FadeM, mSSGILayer6FadeM, mSSGILayer7FadeM
};

static float mSSGIIntensity = mSSGIIntensityP;
static float mSSGIThreshold = mSSGIThresholdP;
static float mSSGIBlurSpread = lerp(0.0, 1.25, mSSGIBlurSpreadP);
static float mSSGIDistAtten = mSSGIDistAttenP;
static float mSSGINearAtten = 1.0f / (mSSGINearAttenP + 0.0001f);
static float mSSGIMaxBrightness = lerp(8.0, 0.0, mSSGILumaLimitP);

#include "shader/math.fxsub"
#include "shader/common.fxsub"
#include "shader/textures.fxsub"
#include "shader/gbuffer.fxsub"
#include "shader/ibl.fxsub"
#include "shader/BRDF.fxsub"
#include "shader/ColorGrading.fxsub"
#include "shader/Layer.fxsub"
#include "shader/ShadingMaterials.fxsub"

#if SUN_SHADOW_QUALITY && SUN_LIGHT_ENABLE
#	include "shader/ShadowMapCascaded.fxsub"
#	include "shader/CascadeShadow.fxsub"
#	include "shader/ShadowSamplingTent.fxsub"
#	include "shader/ShadowMap.fxsub"
#endif

#if SSDO_QUALITY && (IBL_QUALITY || SUN_LIGHT_ENABLE)
#	include "shader/PostProcessOcclusion.fxsub"
#endif

#if SSSS_QUALITY
#	include "shader/PostProcessScattering.fxsub"
#endif

#if OUTLINE_QUALITY == 2
#	include "shader/EdgeLineAA.fxsub"
#endif

#if TOON_ENABLE == 2
#	include "shader/PostProcessDiffusion.fxsub"
#endif

#if SSR_QUALITY
#   include "shader/HZB.fxsub"
#endif

#if SSR_QUALITY
#	include "shader/PostProcessSSR.fxsub"
#endif

#if SSGI_QUALITY
#    include "shader/PostProcessSSGI.fxsub"
#endif

#if BOKEH_QUALITY
#	include "shader/PostProcessHexDOF.fxsub"
#endif

#if HDR_EYE_ADAPTATION
#	include "shader/PostProcessEyeAdaptation.fxsub"
#endif

#if HDR_STAR_MODE
#	include "shader/PostProcessLensflare.fxsub"
#endif

#if HDR_FLARE_MODE
#	include "shader/PostProcessGhost.fxsub"
#endif

#if HDR_BLOOM_MODE
#	include "shader/PostProcessBloom.fxsub"
#endif

#include "shader/PostProcessHDR.fxsub"

#if AA_QUALITY == 1
#	include "shader/FXAA3.fxsub"
#endif

#if AA_QUALITY >= 2 && AA_QUALITY <= 5
#	include "shader/SMAA.fxsub"
#endif

#if AA_QUALITY == 6
#	include "shader/CameraMotion.fxsub"
#endif

#if AA_QUALITY == 6
#	include "shader/TAA.fxsub"
#endif

float4 ScreenSpaceQuadVS(
	in float4 Position : POSITION,
	in float4 Texcoord : TEXCOORD,
	out float4 oTexcoord0 : TEXCOORD0,
	out float3 oTexcoord1 : TEXCOORD1) : POSITION
{
	oTexcoord0 = Texcoord;
	oTexcoord0.xy += ViewportOffset;
	oTexcoord0.zw = oTexcoord0.xy * ViewportSize;
	oTexcoord1 = -mul(Position, matProjectInverse).xyz;
	return Position;
}

float4 ScreenSpaceQuadOffsetVS(
	in float4 Position : POSITION,
	in float2 Texcoord : TEXCOORD,
	out float2 oTexcoord : TEXCOORD0,
	uniform float2 offset) : POSITION
{
	oTexcoord = Texcoord + offset * 0.5;
	return Position;
}

float4 ScreenSpaceQuadRectVS(
    in float4 Position : POSITION,
    in float2 Texcoord : TEXCOORD,
    out float2 oTexcoord : TEXCOORD0,
    uniform float4 rect,
    uniform float2 offset
) : POSITION
{
    oTexcoord = Texcoord + offset * 0.5;

    float2 targetScreenUV = rect.xy + Texcoord * rect.zw;

    float4 oPosition;
    oPosition.x = targetScreenUV.x * 2.0f - 1.0f;
    oPosition.y = 1.0f - targetScreenUV.y * 2.0f;
    oPosition.z = Position.z;
    oPosition.w = 1.0f;

    return oPosition;
}

float Script : STANDARDSGLOBAL<
	string ScriptOutput = "color";
	string ScriptClass  = "scene";
	string ScriptOrder  = "postprocess";
> = 0.8;

technique DeferredLighting<
	string Script =
	"RenderColorTarget=ScnMap;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"ClearSetColor=BackColor;"
	"ClearSetDepth=ClearDepth;"
	"ClearSetStencil=ClearStencil;"
	"Clear=Color;"
	"Clear=Depth;"
	"ScriptExternal=Color;"

#if SUN_SHADOW_QUALITY && SUN_LIGHT_ENABLE
	"RenderColorTarget=ShadowMap;"
	"ClearSetColor=WhiteColor;"
	"Clear=Color;"
	"Pass=ShadowMapGen;"
	"ClearSetColor=BackColor;"
#if SHADOW_BLUR_COUNT
	"RenderColorTarget=ShadowMapTemp; Pass=ShadowBlurX;"
	"RenderColorTarget=ShadowMap;	  Pass=ShadowBlurY;"
#endif
	"RenderColorTarget=CSM1;"
	"RenderDepthStencilTarget=CSM1DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"RenderColorTarget=CSM2;"
	"RenderDepthStencilTarget=CSM2DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
	"RenderColorTarget=CSM3;"
	"RenderDepthStencilTarget=CSM3DepthBuffer;"
	"Clear=Color;"
	"Clear=Depth;"
#endif

#if SSDO_QUALITY && (IBL_QUALITY || SUN_LIGHT_ENABLE)
	"RenderColorTarget=SSDOMap; Pass=SSDO;"
#if SSDO_BLUR_RADIUS
	"RenderColorTarget=SSDOMapTemp; Pass=SSDOBlurX;"
	"RenderColorTarget=SSDOMap;	    Pass=SSDOBlurY;"
#endif
#endif

#if OUTLINE_QUALITY == 2
	"RenderColorTarget=EdgeEdgeMap;  Clear=Color; Pass=EdgeEdgeDetection;"
	"RenderColorTarget=EdgeBlendMap; Clear=Color; Pass=EdgeBlendingWeightCalculation;"
	"RenderColorTarget=OutlineTempMap; Pass=EdgeNeighborhoodBlending;"
#endif

#if SSSS_QUALITY
	"RenderColorTarget0=ShadingMapTemp;"
	"RenderColorTarget1=ShadingMapTempSpecular;"
	"Pass=ShadingOpacity;"
	"RenderColorTarget1=;"

	"RenderDepthStencilTarget=DepthBuffer;"
	"RenderColorTarget=;"
	"Clear=Depth;"
	"Pass=SSSSStencilTest;"
	"RenderColorTarget=ShadingMap; Clear=Color; Pass=SSSSBlurX;"
	"RenderColorTarget=ShadingMapTemp;	Pass=SSSSBlurY;"
	"RenderColorTarget=ShadingMapTemp;	Pass=ShadingOpacityAlbedo;"
	"RenderColorTarget=ShadingMapTemp;	Pass=ShadingOpacitySpecular;"
	"RenderColorTarget=ShadingMap;		Pass=ShadingTransparent;"
#else
	"RenderColorTarget=ShadingMapTemp;	Pass=ShadingOpacity;"
	"RenderColorTarget=ShadingMap;		Pass=ShadingTransparent;"
#endif

#if TOON_ENABLE == 2
	"RenderColorTarget=ShadingMapTemp; 	Pass=DiffusionBlurX;"
	"RenderColorTarget=ShadingMap; 		Pass=DiffusionBlurY;"
#endif

#if SSGI_QUALITY
	"RenderColorTarget=SSGISampleMap;"
	"Clear=Color;"
	"Pass=SSGIRayCast;"

	"RenderColorTarget=SSGIX1MapTemp; Pass=SSGIGaussionBlurX1;"
	"RenderColorTarget=SSGIX1Map;     Pass=SSGIGaussionBlurY1;"
	"RenderColorTarget=SSGIX2MapTemp; Pass=SSGIGaussionBlurX2;"
	"RenderColorTarget=SSGIX2Map;     Pass=SSGIGaussionBlurY2;"
	"RenderColorTarget=SSGIX3MapTemp; Pass=SSGIGaussionBlurX3;"
	"RenderColorTarget=SSGIX3Map;     Pass=SSGIGaussionBlurY3;"
	"RenderColorTarget=SSGIX4MapTemp; Pass=SSGIGaussionBlurX4;"
	"RenderColorTarget=SSGIX4Map;     Pass=SSGIGaussionBlurY4;"

	"RenderColorTarget=SSGIWideBlurMap;     Pass=SSGIWideKernelBlur;"
	"RenderColorTarget=SSGIX3Map;           Pass=SSGIUpsample3;"
	"RenderColorTarget=SSGIX2Map;           Pass=SSGIUpsample2;"
	"RenderColorTarget=SSGIX1Map;           Pass=SSGIUpsample1;"
	"RenderColorTarget=ShadingMap;          Pass=SSGIFinalCombine;"
#endif

#if SSR_QUALITY
	"RenderColorTarget=ZBufferMipmap1;		  	  Pass=ZBufferMipmap1;"
	"RenderColorTarget=ZBufferMipmap2;		      Pass=ZBufferMipmap2;"
	"RenderColorTarget=ZBufferMipmap3;		      Pass=ZBufferMipmap3;"
	"RenderColorTarget=ZBufferMipmap4;		 	  Pass=ZBufferMipmap4;"
	"RenderColorTarget=ZBufferMipmap5;		      Pass=ZBufferMipmap5;"
	"RenderColorTarget=ZBufferMipmap6;		      Pass=ZBufferMipmap6;"
	"RenderColorTarget=ZBufferMipmap7;		      Pass=ZBufferMipmap7;"
	"RenderColorTarget=ZBufferMipmap8;		      Pass=ZBufferMipmap8;"
	"RenderColorTarget=ZBufferMipmap9;		      Pass=ZBufferMipmap9;"
	"RenderColorTarget=ZBufferMipmap10;		      Pass=ZBufferMipmap10;"

	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine2;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine3;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine4;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine5;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine6;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine7;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine8;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine9;"
	"RenderColorTarget=ZBufferMipmap;		      Pass=ZBufferCombine10;"
#endif

#if SSR_QUALITY
	"RenderColorTarget=SSRLightX1Map;"
	"Clear=Color;"
	"Pass=SSRConeTracing;"

	"RenderColorTarget=SSRLightX1MapTemp; Pass=SSRGaussionBlurX1;"
	"RenderColorTarget=SSRLightX1Map;	  Pass=SSRGaussionBlurY1;"
	"RenderColorTarget=SSRLightX2MapTemp; Pass=SSRGaussionBlurX2;"
	"RenderColorTarget=SSRLightX2Map;	  Pass=SSRGaussionBlurY2;"
	"RenderColorTarget=SSRLightX3MapTemp; Pass=SSRGaussionBlurX3;"
	"RenderColorTarget=SSRLightX3Map;	  Pass=SSRGaussionBlurY3;"
	"RenderColorTarget=SSRLightX4MapTemp; Pass=SSRGaussionBlurX4;"
	"RenderColorTarget=SSRLightX4Map;	  Pass=SSRGaussionBlurY4;"

	"RenderColorTarget=ShadingMap;		  Pass=SSRFinalCombie;"
#endif

#if BOKEH_QUALITY
	"RenderColorTarget0=AutoFocalMap; Pass=ComputeFocalDistance;"

	"RenderColorTarget0=FocalBokehMap; Pass=ComputeDepthBokeh;"

	"RenderColorTarget0=FocalBlur1Map;"
	"RenderColorTarget1=FocalBlur2Map;"
	"Clear=Color;"
	"Pass=ComputeHexBlurFarX;"

	"RenderColorTarget0=FocalBokehFarMap;"
	"RenderColorTarget1=;"
	"Clear=Color;"
	"Pass=ComputeHexBlurFarY;"

	"RenderColorTarget=FocalBokehTempMap; Pass=ComputeBokehFarGather;"

	"RenderColorTarget=FocalBokehCoCNearMap; Pass=ComputeNearDown;"
	"RenderColorTarget=FocalBokehTempMap;    Clear=Color; Pass=ComputeSmoothingNearX;"
	"RenderColorTarget=FocalBokehCoCNearMap; Clear=Color; Pass=ComputeSmoothingNearY;"
	"RenderColorTarget=FocalBokehTempMap;    Clear=Color; Pass=ComputeNearCoC;"
	"RenderColorTarget=FocalBokehCoCNearMap; Clear=Color; Pass=ComputeNearSamllBlur;"

	"RenderColorTarget=ShadingMap; Pass=ComputeBokehGatherFinal;"
#endif

#if HDR_EYE_ADAPTATION
	"RenderColorTarget=EyeLumMap; 	 Pass=EyeLum;"
	"RenderColorTarget=EyeLumAveMap; Pass=EyeAdapation;"
#endif

#if HDR_BLOOM_MODE
	"RenderColorTarget=BloomDetectioMap;   Pass=BloomDetection;"
	"RenderColorTarget=BloomMipDownMap1;   Pass=BloomPrefilter;"
#if HDR_STAR_MODE || HDR_FLARE_MODE
	"RenderColorTarget=BloomPrefilterDownMap; Pass=BloomPrefilterDownsample;"
#endif
	"RenderColorTarget=BloomMipUpMap2;     Pass=BloomBlurH1;"
	"RenderColorTarget=BloomMipDownMap2;   Pass=BloomBlurV1;"
#if HDR_FLARE_MODE
	"RenderColorTarget=GhostSourceMap;     Pass=GhostSource;"
#endif
	"RenderColorTarget=BloomMipUpMap3;     Pass=BloomBlurH2;"
	"RenderColorTarget=BloomMipDownMap3;   Pass=BloomBlurV2;"
	"RenderColorTarget=BloomMipUpMap4;     Pass=BloomBlurH3;"
	"RenderColorTarget=BloomMipDownMap4;   Pass=BloomBlurV3;"
	"RenderColorTarget=BloomMipUpMap5;     Pass=BloomBlurH4;"
	"RenderColorTarget=BloomMipDownMap5;   Pass=BloomBlurV4;"

	"RenderColorTarget=BloomMipUpMap4;   Pass=BloomUpSample1;"
	"RenderColorTarget=BloomMipUpMap3;   Pass=BloomUpSample2;"
	"RenderColorTarget=BloomMipUpMap2;   Pass=BloomUpSample3;"
	"RenderColorTarget=BloomMipUpMap1;   Pass=BloomUpSample4;"
#if HDR_STAR_MODE == 1 || HDR_STAR_MODE == 2
	"RenderColorTarget=StreakMap1stTemp; Pass=Star1stStreak1st;"
	"RenderColorTarget=StreakMap1st;	 Pass=Star1stStreak2nd;"
	"RenderColorTarget=StreakMap1stTemp; Pass=Star1stStreak3rd;"
	"RenderColorTarget=StreakMap1st;	 Pass=Star1stStreak4th;"
	"RenderColorTarget=StreakMap2ndTemp; Pass=Star2ndStreak1st;"
	"RenderColorTarget=StreakMap2nd;	 Pass=Star2ndStreak2nd;"
	"RenderColorTarget=StreakMap2ndTemp; Pass=Star2ndStreak3rd;"
	"RenderColorTarget=StreakMap2nd;	 Pass=Star2ndStreak4th;"
#endif
#if HDR_STAR_MODE == 3 || HDR_STAR_MODE == 4
	"RenderColorTarget=StreakMap1st;	 Pass=Star1stStreak1st;"
	"RenderColorTarget=StreakMap1stTemp; Pass=Star1stStreak2nd;"
	"RenderColorTarget=StreakMap1st;	 Pass=Star1stStreak3rd;"
	"RenderColorTarget=StreakMap2nd;	 Pass=Star2ndStreak1st;"
	"RenderColorTarget=StreakMap2ndTemp; Pass=Star2ndStreak2nd;"
	"RenderColorTarget=StreakMap2nd;	 Pass=Star2ndStreak3rd;"
	"RenderColorTarget=StreakMap3rd;	 Pass=Star3rdStreak1st;"
	"RenderColorTarget=StreakMap3rdTemp; Pass=Star3rdStreak2nd;"
	"RenderColorTarget=StreakMap3rd;	 Pass=Star3rdStreak3rd;"
	"RenderColorTarget=StreakMap4th;	 Pass=Star4thStreak1st;"
	"RenderColorTarget=StreakMap4thTemp; Pass=Star4thStreak2nd;"
	"RenderColorTarget=StreakMap4th;	 Pass=Star4thStreak3rd;"
#endif
	"RenderColorTarget=BloomMap;		Pass=BloomCombine;"
#if HDR_FLARE_MODE
	"RenderColorTarget=BloomMapTemp;    Pass=GhostImage1st;"
	"RenderColorTarget=BloomMap;		Pass=GhostImage2nd;"
#endif
#endif

#if AA_QUALITY == 0
	"RenderColorTarget=;"
	"RenderDepthStencilTarget=;"
	"Pass=HDRTonemapping;"
#else
	"RenderColorTarget=ShadingMapTemp;"
	"Pass=HDRTonemapping;"
#endif

#if AA_QUALITY == 1
	"RenderColorTarget=;"
	"RenderDepthStencilTarget=;"
	"Pass=FXAA;"
#endif

#if AA_QUALITY == 2 || AA_QUALITY == 3
	"RenderColorTarget=SMAAEdgeMap;  Clear=Color; Pass=SMAAEdgeDetection;"
	"RenderColorTarget=SMAABlendMap; Clear=Color; Pass=SMAABlendingWeightCalculation;"
	"RenderColorTarget=;"
	"RenderDepthStencilTarget=;"
	"Pass=SMAANeighborhoodBlending;"
#endif

#if AA_QUALITY == 4 || AA_QUALITY == 5
	"RenderColorTarget=SMAAEdgeMap;  Clear=Color; Pass=SMAAEdgeDetection1x;"
	"RenderColorTarget=SMAABlendMap; Clear=Color; Pass=SMAABlendingWeightCalculation1x;"
	"RenderColorTarget=ShadingMap; Pass=SMAANeighborhoodBlending;"

	"RenderColorTarget=SMAAEdgeMap;  Clear=Color; Pass=SMAAEdgeDetection2x;"
	"RenderColorTarget=SMAABlendMap; Clear=Color; Pass=SMAABlendingWeightCalculation2x;"
	"RenderColorTarget=;"
	"RenderDepthStencilTarget=;"
	"Pass=SMAANeighborhoodBlendingFinal;"
#endif
;>
{
#if SUN_LIGHT_ENABLE && SUN_SHADOW_QUALITY
	pass ShadowMapGen<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ShadowMapGenPS();
	}
#if SHADOW_BLUR_COUNT
	pass ShadowBlurX<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ShadowMapBlurPS(ShadowMapSamp, float2(ViewportOffset2.x, 0.0f));
	}
	pass ShadowBlurY<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ShadowMapBlurPS(ShadowMapSampTemp, float2(0.0f, ViewportOffset2.y));
	}
#endif
#endif
#if SSDO_QUALITY && (IBL_QUALITY || SUN_LIGHT_ENABLE)
	pass SSDO<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceDirOccPassVS();
		PixelShader  = compile ps_3_0 ScreenSpaceDirOccPassPS();
	}
	pass SSDOBlurX<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ScreenSpaceDirOccBlurPS(SSDOMapSamp, float2(ViewportOffset2.x, 0.0f));
	}
	pass SSDOBlurY<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ScreenSpaceDirOccBlurPS(SSDOMapSampTemp, float2(0.0f, ViewportOffset2.y));
	}
#endif
	pass ShadingOpacity<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ShadingOpacityPS();
	}
	pass ShadingTransparent<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ShadingTransparentPS();
	}
#if SSSS_QUALITY
	pass SSSSStencilTest<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		ColorWriteEnable = false;
		StencilEnable = true;
		StencilFunc = ALWAYS;
		StencilRef = 1;
		StencilPass = REPLACE;
		StencilFail = KEEP;
		StencilZFail = KEEP;
		StencilWriteMask = 1;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 SSSSStencilTestPS();
	}
	pass SSSSBlurX<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		StencilEnable = true; StencilFunc = EQUAL; StencilRef = 1; StencilWriteMask = 0;
		VertexShader = compile vs_3_0 SSSGaussBlurVS();
		PixelShader  = compile ps_3_0 SSSGaussBlurPS(ShadingMapTempPointSamp, ShadingMapTempPointSamp, float2(1.0, 0.0));
	}
	pass SSSSBlurY<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		StencilEnable = true; StencilFunc = EQUAL; StencilRef = 1; StencilWriteMask = 0;
		VertexShader = compile vs_3_0 SSSGaussBlurVS();
		PixelShader  = compile ps_3_0 SSSGaussBlurPS(ShadingMapPointSamp, ShadingMapTempPointSamp,float2(0.0, 1.0));
	}
	pass ShadingOpacityAlbedo<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = true; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		SrcBlend = DESTCOLOR; DestBlend = ZERO;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ShadingOpacityAlbedoPS();
	}
	pass ShadingOpacitySpecular<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = true; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		SrcBlend = ONE; DestBlend = ONE;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ShadingOpacitySpecularPS();
	}
#endif
#if OUTLINE_QUALITY == 2
	pass EdgeEdgeDetection<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 EdgeEdgeDetectionVS();
		PixelShader  = compile ps_3_0 EdgeLumaEdgeDetectionPS(OutlineMapSamp);
	}
	pass EdgeBlendingWeightCalculation<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 EdgeBlendingWeightCalculationVS();
		PixelShader  = compile ps_3_0 EdgeBlendingWeightCalculationPS(0.0);
	}
	pass EdgeNeighborhoodBlending<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 EdgeNeighborhoodBlendingVS();
		PixelShader  = compile ps_3_0 EdgeNeighborhoodBlendingPS(OutlineMapSamp, ViewportOffset2);
	}
#endif
#if TOON_ENABLE == 2
	pass DiffusionBlurX<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ScreenSpaceBilateralFilterPS(ShadingMapSamp, mDiffusionOffsetX);
	}
	pass DiffusionBlurY<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = true; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		SrcBlend = SRCALPHA; DestBlend = INVSRCALPHA;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ScreenSpaceBilateralFilterPS(ShadingMapTempSamp, mDiffusionOffsetY);
	}
#endif
#if SSGI_QUALITY
	pass SSGIRayCast<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 SSGIRayCastPS();
	}
	pass SSGIGaussionBlurX1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur1QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGISampleMapSamp, SSGIOffsetX1);
	}
	pass SSGIGaussionBlurY1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur1QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGIX1MapTempSamp, SSGIOffsetY1);
	}
	pass SSGIGaussionBlurX2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur2QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGIX1MapSamp, SSGIOffsetX2);
	}
	pass SSGIGaussionBlurY2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur2QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGIX2MapTempSamp, SSGIOffsetY2);
	}
	pass SSGIGaussionBlurX3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur3QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGIX2MapSamp, SSGIOffsetX3);
	}
	pass SSGIGaussionBlurY3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur3QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGIX3MapTempSamp, SSGIOffsetY3);
	}
	pass SSGIGaussionBlurX4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur4QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGIX3MapSamp, SSGIOffsetX4);
	}
	pass SSGIGaussionBlurY4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlur4QuadOffset);
		PixelShader  = compile ps_3_0 SSGIGaussionBlurPS(SSGIX4MapTempSamp, SSGIOffsetY4);
	}
	pass SSGIWideKernelBlur<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(kSSGIBlurFinalQuadOffset);
		PixelShader  = compile ps_3_0 SSGIWideKernelBlurPS(SSGIX4MapSamp);
	}
	pass SSGIUpsample3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SSGIUpSampleVS(kSSGIBlur3QuadOffset, kSSGIBlur4QuadOffset);
		PixelShader  = compile ps_3_0 SSGIUpsamplePS(SSGIWideBlurMapSamp, SSGIX4MapTexelSize);
	}
	pass SSGIUpsample2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SSGIUpSampleVS(kSSGIBlur2QuadOffset, kSSGIBlur3QuadOffset);
		PixelShader  = compile ps_3_0 SSGIUpsamplePS(SSGIX3MapSamp, SSGIX3MapTexelSize);
	}
	pass SSGIUpsample1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SSGIUpSampleVS(kSSGIBlur1QuadOffset, kSSGIBlur2QuadOffset);
		PixelShader  = compile ps_3_0 SSGIUpsamplePS(SSGIX2MapSamp, SSGIX2MapTexelSize);
	}
	pass SSGIFinalCombine<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = true; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		SrcBlend = ONE; DestBlend = ONE;
		VertexShader = compile vs_3_0 SSGIUpSampleVS(ViewportOffset, kSSGIBlur1QuadOffset);
		PixelShader  = compile ps_3_0 SSGIFinalCombinePS(SSGIX1MapSamp, SSGIX1MapTexelSize);
	}
#endif
#if SSR_QUALITY
	pass ZBufferMipmap1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_1_PS(Gbuffer8Map);
	}
	pass ZBufferMipmap2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap1Samp, kHZBMip2ViewportSize, kHZBMip1ViewportSize);
	}
	pass ZBufferMipmap3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap2Samp, kHZBMip3ViewportSize, kHZBMip2ViewportSize);
	}
	pass ZBufferMipmap4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap3Samp, kHZBMip4ViewportSize, kHZBMip3ViewportSize);
	}
	pass ZBufferMipmap5<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap4Samp, kHZBMip5ViewportSize, kHZBMip4ViewportSize);
	}
	pass ZBufferMipmap6<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap5Samp, kHZBMip6ViewportSize, kHZBMip5ViewportSize);
	}
	pass ZBufferMipmap7<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap6Samp, kHZBMip7ViewportSize, kHZBMip6ViewportSize);
	}
	pass ZBufferMipmap8<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap7Samp, kHZBMip8ViewportSize, kHZBMip7ViewportSize);
	}
	pass ZBufferMipmap9<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap8Samp, kHZBMip9ViewportSize, kHZBMip8ViewportSize);
	}
	pass ZBufferMipmap10<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(0);
		PixelShader  = compile ps_3_0 ZBufferMipmap_N_PS(ZBufferMipmap9Samp, kHZBMip10ViewportSize, kHZBMip9ViewportSize);
	}
	pass ZBufferCombine2<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip2Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap2Samp);
 	}
	pass ZBufferCombine3<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip3Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap3Samp);
 	}
	pass ZBufferCombine4<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip4Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap4Samp);
 	}
	pass ZBufferCombine5<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip5Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap5Samp);
 	}
	pass ZBufferCombine6<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip6Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap6Samp);
 	}
	pass ZBufferCombine7<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip7Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap7Samp);
 	}
	pass ZBufferCombine8<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip8Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap8Samp);
 	}
	pass ZBufferCombine9<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip9Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap9Samp);
 	}
	pass ZBufferCombine10<string Script= "Draw=Buffer;";>{
 		AlphaBlendEnable = false; AlphaTestEnable = false;
 		ZEnable = false; ZWriteEnable = false;
 		VertexShader = compile vs_3_0 ScreenSpaceQuadRectVS(kMip10Rect, 0);
 		PixelShader  = compile ps_3_0 ZBufferMipmapCombinePS(ZBufferMipmap10Samp);
 	}
#endif
#if SSR_QUALITY
	pass SSRConeTracing<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 SSRConeTracingPS();
	}
	pass SSRGaussionBlurX1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX1Samp, SSROffsetX1);
	}
	pass SSRGaussionBlurY1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX1SampTemp, SSROffsetY1);
	}
	pass SSRGaussionBlurX2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX1Samp, SSROffsetX2);
	}
	pass SSRGaussionBlurY2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2.x * 2);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX2SampTemp, SSROffsetY2);
	}
	pass SSRGaussionBlurX3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2.x * 2);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX2Samp, SSROffsetX3);
	}
	pass SSRGaussionBlurY3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2.x * 4);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX3SampTemp, SSROffsetY3);
	}
	pass SSRGaussionBlurX4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2.x * 4);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX3Samp, SSROffsetX4);
	}
	pass SSRGaussionBlurY4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(ViewportOffset2.x * 8);
		PixelShader  = compile ps_3_0 SSRGaussionBlurPS(SSRLightX4SampTemp, SSROffsetY4);
	}
	pass SSRFinalCombie<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = true; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		SrcBlend = ONE; DestBlend = INVSRCALPHA;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 SSRFinalCombiePS();
	}
#endif
#if BOKEH_QUALITY
	pass ComputeFocalDistance<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 ComputeFocalDistancePS(ShadingMapPointSamp);
	}
	pass ComputeDepthBokeh<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ComputeDepthBokehVS();
		PixelShader  = compile ps_3_0 ComputeDepthBokeh4XPS(ShadingMapPointSamp);
	}
	pass ComputeHexBlurFarX<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ComputeHexBlurXVS();
		PixelShader  = compile ps_3_0 ComputeHexBlurXFarPS(FocalBokehMapPointSamp, FocalBokehMapSamp);
	}
	pass ComputeHexBlurFarY<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ComputeHexBlurYVS();
		PixelShader  = compile ps_3_0 ComputeHexBlurYFarPS(FocalBokehMapPointSamp, FocalBlur1MapSamp, FocalBlur2MapSamp);
	}
	pass ComputeBokehFarGather<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ComputeBokehGatherVS();
		PixelShader  = compile ps_3_0 ComputeBokehFarGatherPS(FocalBokehMapSamp, FocalBokehFarMapSamp);
	}
	pass ComputeNearDown<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(1.0 / (ViewportSize * mFocalMapScale));
		PixelShader  = compile ps_3_0 ComputeNearDownPS(FocalBokehTempMapPointSamp, 1.0 / mFocalStepScale);
	}
	pass ComputeSmoothingNearX<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(1.0 / (ViewportSize * mFocalMapScale));
		PixelShader  = compile ps_3_0 ComputeSmoothingNearPS(FocalBokehCoCNearMapSamp, float2(1.0 / mFocalStepScale.x, 0));
	}
	pass ComputeSmoothingNearY<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(1.0 / (ViewportSize * mFocalMapScale));
		PixelShader  = compile ps_3_0 ComputeSmoothingNearPS(FocalBokehTempMapSamp, float2(0, 1.0 / mFocalStepScale.y));
	}
	pass ComputeNearCoC<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(1.0 / (ViewportSize * mFocalMapScale));
		PixelShader  = compile ps_3_0 ComputeNearCoCPS(FocalBokehMapPointSamp, FocalBokehCoCNearMapSamp);
	}
	pass ComputeNearSamllBlur<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadOffsetVS(1.0 / (ViewportSize * mFocalMapScale));
		PixelShader  = compile ps_3_0 ComputeNearSamllBlurPS(FocalBokehTempMapSamp, float2(0, 1.0 / mFocalStepScale.y));
	}
	pass ComputeBokehGatherFinal<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = true; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		DestBlend = INVSRCALPHA; SrcBlend = SRCALPHA;
		VertexShader = compile vs_3_0 ComputeBokehGatherVS();
		PixelShader  = compile ps_3_0 ComputeBokehGatherFinalPS(FocalBokehMapPointSamp, FocalBokehCoCNearMapSamp, 1.0 / mFocalStepScale);
	}
#endif
#if HDR_EYE_ADAPTATION
	pass EyeLum<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 EyeDownsampleVS(ViewportOffset2);
		PixelShader  = compile ps_3_0 EyeDownsamplePS(ShadingMapPointSamp);
	}
	pass EyeAdapation<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 EyeAdapationPS();
	}
#endif
#if HDR_BLOOM_MODE
	pass BloomDetection<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 BloomDetectionPS(ShadingMapPointSamp);
	}
	pass BloomPrefilter<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomPrefilterVS();
		PixelShader  = compile ps_3_0 BloomPrefilterPS(BloomDetectioMapSamp);
	}
#if HDR_STAR_MODE || HDR_FLARE_MODE
	pass BloomPrefilterDownsample<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomPrefilterDownsampleVS(ViewportOffset2 * 2);
		PixelShader  = compile ps_3_0 BloomPrefilterDownsamplePS(BloomMipDownMap1Samp);
	}
#endif
	pass BloomBlurH1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset1);
		PixelShader  = compile ps_3_0 BloomBlurHPS(BloomMipDownMap1Samp, BloomBlurMip1TexelSize.x);
	}
	pass BloomBlurV1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset1);
		PixelShader  = compile ps_3_0 BloomBlurVPS(BloomMipUpMap2Samp, BloomBlurMip2TexelSize.y);
	}
#if HDR_FLARE_MODE
	pass GhostSource<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 GhostSourceVS();
		PixelShader  = compile ps_3_0 GhostSourcePS();
	}
#endif
	pass BloomBlurH2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset2);
		PixelShader  = compile ps_3_0 BloomBlurHPS(BloomMipDownMap2Samp, BloomBlurMip2TexelSize.x);
	}
	pass BloomBlurV2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset2);
		PixelShader  = compile ps_3_0 BloomBlurVPS(BloomMipUpMap3Samp, BloomBlurMip3TexelSize.y);
	}
	pass BloomBlurH3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset3);
		PixelShader  = compile ps_3_0 BloomBlurHPS(BloomMipDownMap3Samp, BloomBlurMip3TexelSize.x);
	}
	pass BloomBlurV3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset3);
		PixelShader  = compile ps_3_0 BloomBlurVPS(BloomMipUpMap4Samp, BloomBlurMip4TexelSize.y);
	}
	pass BloomBlurH4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset4);
		PixelShader  = compile ps_3_0 BloomBlurHPS(BloomMipDownMap4Samp, BloomBlurMip4TexelSize.x);
	}
	pass BloomBlurV4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomBlurVS(BloomBlurOffset4);
		PixelShader  = compile ps_3_0 BloomBlurVPS(BloomMipUpMap5Samp, BloomBlurMip5TexelSize.y);
	}
	pass BloomUpSample1<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomUpsampleVS(BloomUpsampleOffset1);
		PixelShader  = compile ps_3_0 BloomUpsamplePS(BloomMipDownMap4Samp, BloomMipDownMap5Samp);
	}
	pass BloomUpSample2<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomUpsampleVS(BloomUpsampleOffset2);
		PixelShader  = compile ps_3_0 BloomUpsamplePS(BloomMipDownMap3Samp, BloomMipUpMap4Samp);
	}
	pass BloomUpSample3<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomUpsampleVS(BloomUpsampleOffset3);
		PixelShader  = compile ps_3_0 BloomUpsamplePS(BloomMipDownMap2Samp, BloomMipUpMap3Samp);
	}
	pass BloomUpSample4<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomUpsampleVS(BloomUpsampleOffset4);
		PixelShader  = compile ps_3_0 BloomUpsamplePS(BloomMipDownMap1Samp, BloomMipUpMap2Samp);
	}
#if HDR_STAR_MODE == 1 || HDR_STAR_MODE == 2
	pass Star1stStreak1st<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, 0), 1);
		PixelShader  = compile ps_3_0 StarStreakPS(BloomPrefilterDownMapSamp, star_colorCoeff1st, mBloomStarFade);
	}
	pass Star1stStreak2nd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, 0), 4);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp1stTemp, star_colorCoeff2nd, 0);
	}
	pass Star1stStreak3rd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, 0), 16);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp1st, star_colorCoeff3rd, 0);
	}
	pass Star1stStreak4th<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, 0), 64);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp1stTemp, star_colorCoeff4th, 0);
	}
	pass Star2ndStreak1st<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, 0), 1);
		PixelShader  = compile ps_3_0 StarStreakPS(BloomPrefilterDownMapSamp, star_colorCoeff1st, mBloomStarFade);
	}
	pass Star2ndStreak2nd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, 0), 4);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp2ndTemp, star_colorCoeff2nd, 0);
	}
	pass Star2ndStreak3rd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, 0), 16);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp2nd, star_colorCoeff3rd, 0);
	}
	pass Star2ndStreak4th<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, 0), 64);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp2ndTemp, star_colorCoeff4th, 0);
	}
#endif
#if HDR_STAR_MODE == 3 || HDR_STAR_MODE == 4
	pass Star1stStreak1st<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, 0.9), 1);
		PixelShader  = compile ps_3_0 StarStreakPS(BloomPrefilterDownMapSamp, star_colorCoeff1st, mBloomStarFade);
	}
	pass Star1stStreak2nd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, 0.9), 4);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp1st, star_colorCoeff2nd, 0);
	}
	pass Star1stStreak3rd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, 0.9), 16);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp1stTemp, star_colorCoeff3rd, 0);
	}
	pass Star2ndStreak1st<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, 0.9), 1);
		PixelShader  = compile ps_3_0 StarStreakPS(BloomPrefilterDownMapSamp, star_colorCoeff1st, mBloomStarFade);
	}
	pass Star2ndStreak2nd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, 0.9), 4);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp2nd, star_colorCoeff2nd, 0);
	}
	pass Star2ndStreak3rd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, 0.9), 16);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp2ndTemp, star_colorCoeff3rd, 0);
	}
	pass Star3rdStreak1st<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, -0.9), 1);
		PixelShader  = compile ps_3_0 StarStreakPS(BloomPrefilterDownMapSamp, star_colorCoeff1st, mBloomStarFade);
	}
	pass Star3rdStreak2nd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, -0.9), 4);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp3rd, star_colorCoeff2nd, 0);
	}
	pass Star3rdStreak3rd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(0.9, -0.9), 16);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp3rdTemp, star_colorCoeff3rd, 0);
	}
	pass Star4thStreak1st<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, -0.9), 1);
		PixelShader  = compile ps_3_0 StarStreakPS(BloomPrefilterDownMapSamp, star_colorCoeff1st, mBloomStarFade);
	}
	pass Star4thStreak2nd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, -0.9), 4);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp4th, star_colorCoeff2nd, 0);
	}
	pass Star4thStreak3rd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 StarStreakVS(float2(-0.9, -0.9), 16);
		PixelShader  = compile ps_3_0 StarStreakPS(StreakSamp4thTemp, star_colorCoeff3rd, 0);
	}
#endif
	pass BloomCombine<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 BloomCombineVS();
		PixelShader  = compile ps_3_0 BloomCombinePS();
	}
#if HDR_FLARE_MODE
	pass GhostImage1st<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 GhostImageVS(ghost_scalar1st);
		PixelShader  = compile ps_3_0 GhostImagePS(BloomPrefilterDownMapSamp, GhostSourceMapSamp, GhostSourceMapSamp, ghost_modulation1st, mBloomStarFade);
	}
	pass GhostImage2nd<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = true; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		SrcBlend = ONE; DestBlend = ONE;
		VertexShader = compile vs_3_0 GhostImageVS(ghost_scalar2nd);
		PixelShader  = compile ps_3_0 GhostImagePS(BloomMapTempSamp, BloomMapTempSamp, GhostSourceMapSamp, ghost_modulation2nd, 0);
	}
#endif
#endif
	pass HDRTonemapping<string Script= "Draw=Buffer;";>{
		 AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 HDRTonemappingVS();
		PixelShader  = compile ps_3_0 HDRTonemappingPS(ShadingMapPointSamp);
	}
#if AA_QUALITY == 1
	pass FXAA<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 ScreenSpaceQuadVS();
		PixelShader  = compile ps_3_0 FXAA3(ShadingMapTempSamp, ViewportOffset2);
	}
#endif
#if AA_QUALITY == 2 || AA_QUALITY == 3
	pass SMAAEdgeDetection<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAAEdgeDetectionVS();
		PixelShader  = compile ps_3_0 SMAALumaEdgeDetectionPS(ShadingMapTempSamp);
	}
	pass SMAABlendingWeightCalculation<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAABlendingWeightCalculationVS();
		PixelShader  = compile ps_3_0 SMAABlendingWeightCalculationPS(0.0);
	}
	pass SMAANeighborhoodBlending<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAANeighborhoodBlendingVS();
		PixelShader  = compile ps_3_0 SMAANeighborhoodBlendingPS(ShadingMapTempSamp, true);
	}
#endif
#if AA_QUALITY == 4 || AA_QUALITY == 5
	pass SMAAEdgeDetection1x<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAAEdgeDetectionVS();
		PixelShader  = compile ps_3_0 SMAALumaEdgeDetectionPS(ShadingMapTempSamp);
	}
	pass SMAABlendingWeightCalculation1x<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAABlendingWeightCalculationVS();
		PixelShader  = compile ps_3_0 SMAABlendingWeightCalculationPS(float4(1, 1, 1, 0));
	}
	pass SMAANeighborhoodBlending<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAANeighborhoodBlendingVS();
		PixelShader  = compile ps_3_0 SMAANeighborhoodBlendingPS(ShadingMapTempSamp, false);
	}
	pass SMAAEdgeDetection2x<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAAEdgeDetectionVS();
		PixelShader  = compile ps_3_0 SMAALumaEdgeDetectionPS(ShadingMapSamp);
	}
	pass SMAABlendingWeightCalculation2x<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAABlendingWeightCalculationVS();
		PixelShader  = compile ps_3_0 SMAABlendingWeightCalculationPS(float4(2, 2, 2, 0));
	}
	pass SMAANeighborhoodBlendingFinal<string Script= "Draw=Buffer;";>{
		AlphaBlendEnable = false; AlphaTestEnable = false;
		ZEnable = false; ZWriteEnable = false;
		VertexShader = compile vs_3_0 SMAANeighborhoodBlendingVS();
		PixelShader  = compile ps_3_0 SMAANeighborhoodBlendingPS(ShadingMapSamp, true);
	}
#endif
}