const float smoothness = 1.0;
const float metallic = 1.0;
const float3 albedo = float3(1,1,1);
const float alpha = 1.0;

float rippleIntensity = 1.0;
float rippleNormalIntensity = 1.0;

#define MASK_MAP_ENABLE 0
#define MASK_MAP_FILE "textures/mask.png"

#define WAVE_MAP_ENABLE 1
#define WAVE_MAP_FILE "textures/wave.png"

const float waveHeightLow = 0.6;
const float waveHeightHigh  = 0.5;

const float waveLoopsLow = 0.6;
const float waveLoopsHigh = 4.0;

const float waveMapScaleLow = 0.0;

const float2 waveMapLoopNumLow = 1.0;

const float2 waveMapTranslate = float2(1, 1);

#define WAVE_NOISE_MAP_ENABLE 1
#define WAVE_NOISE_MAP_FILE "textures/noise.png"

#include "material_common.fxsub"