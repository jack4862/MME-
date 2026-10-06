/* ------------------------------------------------------------
 * AlternativeFull
 * ------------------------------------------------------------ */
#define TEXTURE_THRESHOLD "Skin&Face.png"
#define USE_MATERIAL_TEXTURE
#define USE_EXCELLENT_SHADOW_SYSTEM
#define USE_SELFSHADOW_MODE
#define USE_NONE_SELFSHADOW_MODE
#define USE_FILL_LIGHT_TYPE2
float FillLight2Power = 0.05;
#define USE_RIM_LIGHT
float RimLightPower = 0.7;
float RimLightThreshold = 2.2;
float SelfShadowPower = 0.4;
#define HIGHLIGHT_ANTI_AUTOLUMINOUS
#define USE_SHADOWCOLOR_SELFPOWER_MODE
float SelfPowerShadowStrength = 1;
#define USE_MATERIAL_SPHERE
float3 DefaultModeShadowColor = {0.9294118,0.8784314,0.8666667};
#define USE_MIPMAP
#define FX_MAX_ANISOTROPY 2
#define MAX_ANISOTROPY 16

#include "AlternativeFull.fxsub"
