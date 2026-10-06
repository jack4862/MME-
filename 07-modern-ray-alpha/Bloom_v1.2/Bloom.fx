////  Bloom.fx
//  Bloom
//
//  Created by 洪梓嫣 on 2025/4/20.
//  Copyright © 2019 Bilibili. All rights reserved.
//

#define DIRT_MASK_MAP_ENABLE 0
#define DIRT_MASK_MAP_FILE "Textures/DirtMaskTextureExample.png"

#define DEPTH_FADE_ENABLE 0

// R = default
// G = min
// B = max
const float3 dirtIntensityParams = float3(10.0, 0.0, 100.0);

#include "Bloom.fxsub"