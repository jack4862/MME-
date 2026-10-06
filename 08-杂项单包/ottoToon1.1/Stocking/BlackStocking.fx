/* ------------------------------------------------------------
 * AlternativeFull
 * ------------------------------------------------------------ */
#define TEXTURE_THRESHOLD "Stocking.png"
#define USE_MATERIAL_TEXTURE
#define USE_EXCELLENT_SHADOW_SYSTEM
#define USE_LAMBERT
float LambertFactor = 1;
#define USE_SELFSHADOW_MODE
#define USE_NONE_SELFSHADOW_MODE
#define USE_FILL_LIGHT_TYPE2
float FillLight2Power = 0.16;
#define USE_RIM_LIGHT
float RimLightPower = 0.25;
float RimLightThreshold = 1.5;
float SelfShadowPower = 0.5;
#define HIGHLIGHT_ANTI_AUTOLUMINOUS
#define USE_SHADOWCOLOR_SELFPOWER_MODE
float SelfPowerShadowStrength = 0.58;
#define USE_MATERIAL_SPHERE
#define USE_SPHERE_CHEET
float SphereBoost = 0.5;
float3 DefaultModeShadowColor = {0.7529412,0.7529412,0.7529412};
#define USE_MIPMAP
#define FX_MAX_ANISOTROPY 2
#define MAX_ANISOTROPY 16

#include "AlternativeFull.fxsub"
