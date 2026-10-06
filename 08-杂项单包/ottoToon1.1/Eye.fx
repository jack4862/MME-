/* ------------------------------------------------------------
 * AlternativeFull
 * ------------------------------------------------------------ */
/* created by AlternativeFullFrontend. */
#define TEXTURE_THRESHOLD "Eye&Metal.png"
#define USE_MATERIAL_TEXTURE
#define USE_EXCELLENT_SHADOW_SYSTEM
#define USE_LAMBERT
float LambertFactor = 0.6;
#define USE_SELFSHADOW_MODE
#define USE_NONE_SELFSHADOW_MODE
#define USE_FILL_LIGHT_TYPE1
float FillLight1Power = 2;
#define USE_FILL_LIGHT_TYPE2
float FillLight2Power = 2;
#define USE_HIGHLIGHT_CHEET
float HighlightPower = 0.35;
#define USE_HIGHLIGHT_COLOR_TYPE1
float SelfShadowPower = 0.7;
#define USE_MATERIAL_SPECULAR
#define USE_MATERIAL_SPHERE
float3 DefaultModeShadowColor = {0.7529412,0.7529412,0.7529412};
#define MAX_ANISOTROPY 16

#include "AlternativeFull.fxsub"
