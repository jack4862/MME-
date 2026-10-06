#define LIGHT_PARAMS_TYPE 1

static const float3 lightBlink = 0.0;
static const float3 lightColor = 1.0;
static const float2 lightIntensityLimits = float2(1.0, 10.0);

#define SHADOW_MAP_FROM 1

static const float2 shadowHardness = float2(0.15, 0.5);

#define SHADOW_QUALITY 2

#include "../directional_lighting.fxsub"