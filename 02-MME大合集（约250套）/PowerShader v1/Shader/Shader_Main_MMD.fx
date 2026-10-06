// 光の倍率
float3 LightPower = 1.0;

// 影の倍率
float3 ShadowPower = 1.0;

// 発光色
float3 Emissive = float3(0,0,0);

// 光源が強い時の発光抑え
float Saturate = 0.0;

// トゥーンシェーディングをするか
// 0 : しない
// 1 : する
#define TOON_ENABLE 0

// トゥーン閾値
float ToonThreshold = 0.0;

// シェーディングヒント用テクスチャ
// AlternativeFullのシェーディングヒントと同じ仕様なので置き換え可能
#define TEXTURE_THRESHOLD "shading_hint_toon.png"

#include "Common_Shader.fxsub"
