////  Trail_depth_100.fx
//  Cartethyia
//
//  Created by 洪梓嫣 on 2025/3/20.
//  Copyright © 2019 Bilibili. All rights reserved.
//

// 顶点对数目, 别手贱乱改
#define VERTEX_PAIR_COUNT 101
// 透明度低于此值时将不写入深度
const float AlphaThroughThreshold = 0.2;
// 与ikBokeh.fx中的同名值保持一致
#define FAR_DEPTH		1000

#include "../common/trail_ikbokeh_depth.hlsl"