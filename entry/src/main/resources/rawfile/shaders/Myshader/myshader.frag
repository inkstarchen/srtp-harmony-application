/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#version 460 core
#extension GL_ARB_separate_shader_objects : enable
#extension GL_ARB_shading_language_420pack : enable

// includes

#include "render/shaders/common/render_compatibility_common.h"

#include "render/shaders/common/render_color_conversion_common.h"
#include "render/shaders/common/render_post_process_common.h"
#include "render/shaders/common/render_tonemap_common.h"

#include "3d/shaders/common/3d_dm_structures_common.h"

// sets and specializations

#include "3d/shaders/common/3d_dm_frag_layout_common.h"
#include "3d/shaders/common/3d_dm_lighting_common.h"

// custom user set
struct MyMaterialSampleStruct {
    vec4 vec_1;
    float time;
    bool dof;
    bool motionBlur;
};
layout(set = 1, binding = 4, std140) uniform uMyBuffer0
{
    MyMaterialSampleStruct uMyData;
};


#define CORE3D_DM_FW_FRAG_INPUT 1
#include "3d/shaders/common/3d_dm_inout_common.h"
#include "3d/shaders/common/3d_dm_inplace_sampling_common.h"
#include "3d/shaders/common/3d_dm_inplace_post_process.h"

// in / out

layout(location = 0) out vec4 outColor;


// Corrected normal vector.

#define hash(x) fract(sin(x)*5723.2622)
const float pi = acos(-1.);
const float pi2 = acos(-1.)*2.;

// If you have a strong PC, make it bigger.
const int nS = 2; // Number of samples.

const float w = .03; // Width of the fiber.

// Rotation matrix in two dimensions.
mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, s, -s, c);
}

float hash12(vec2 p) {
    float v = dot(p, vec2(1.8672, 1.3723));
    return hash(v);
}

// 1D perlin noise.
float perlin1d(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f*f*(3.-2.*f);

    return mix(f*(hash(i)*2.-1.), (f-1.)*(hash(i+1.)*2.-1.), u); // from -0.5 to 0.5
}

float fiberShape(float x, float time) {
    float s = .03;
    float curve = smoothstep(.25-s, .25+s, abs(fract(time*.11) - .5));
    return perlin1d(x) * (1. - w * 2.) * curve;
}

// Smooth stair-like noise.
float stepNoise(float x, float n) {
    float i = floor(x);
    float s = .1;
    float u = smoothstep(.5-s, .5+s, fract(x));
    
    return mix(floor(hash(i)*n), floor(hash(i+1.)*n), u);
}



// void main(void)
// {
//     vec2 uv = (inUv.xy-vec2(0.5,0.5))*2.0f;
//     vec2 fragCoord = inUv.xy;

//     vec3 col = vec3(0);

//     vec3 ac = vec3(0);

    
//     for(float j=0.; j<float(nS); j++) { // Sampling for Motion blur and DOF.
//         float time = uMyData.time;
//         vec2 seed = fragCoord.xy + fract(time)*500. + j * sqrt(983.);

//         // Motion blur
//         if (uMyData.motionBlur) {
//             time += hash12(seed) * .05;
//         }

//         vec3 ro = vec3(0, 1, -time);
//         vec3 ta = vec3(0, -.5, -time-.5);

//         // Camera movement.
//         ro.x += (stepNoise(ro.z, 5.) - 2.) * .5;
//         ro.y += stepNoise(ro.z - 500., 5.) * .5;

//         vec3 dir = normalize(ta - ro);
//         vec3 side = normalize(cross(dir, vec3(0,1,0)));
//         vec3 up = normalize(cross(side, dir));

//         float fov = 40.;
//         fov += (stepNoise(ro.z - 1000., 2.) * 2. - 1.) * 20.;
//         vec3 rd = normalize(uv.x*side + uv.y*up + dir/tan(fov/360.*pi));
//         float L = length(ta - ro);
//         vec3 fp = ro + rd * L;

//         // Depth of field (DOF).
//         vec3 ros = ro;
//         if (uMyData.dof) {
//             float r = sqrt(hash12(seed*1.1));
//             float theta = hash12(seed*1.2) * pi2;
//             ros.xy += r * vec2(cos(theta), sin(theta)) * L * .025;
//         }
//         vec3 rds = normalize(fp - ros);

//         bool hit = false;
//         float t; // Ray length to the object.
//         vec2 id, q;

//         for(float i=0.; i<50.; i++) {
//             t = -(ros.y + i*.05) / rds.y;
//             vec2 p = ros.xz + t * rds.xz;
//             p.x += hash(i) * 500.;
//             p *= rot(i*2.);

//             id = vec2(i, floor(p.x));

//             p.x = fract(p.x) - .5;
//             p.y += hash12(id) * 500.;
//             p.x -= fiberShape(p.y, time);

//             if (t > 0. && abs(p.x) < w) {
//                 q = p;
//                 hit = true;
//                 break;
//             }
//         }

//         if(hit) { // Ray hit a fiber.
//             vec3 add = vec3(1);

//             vec3 lightDir = normalize(vec3(-5, 2, -2));
//             vec3 normal = normalize(vec3(q.x, sqrt(w*w - q.x*q.x), 0));

//             float e = 1e-4;
//             float grad = (fiberShape(q.y + e, time) - fiberShape(q.y - e, time)) / (e*2.);
//             float a = atan(grad);
//             normal.xz *= rot(-id.x*2. + a);

//             // Shading
//             float diff = max(dot(normal, lightDir), 0.);
//             float spec = pow(max(dot(reflect(lightDir, normal), rds), 0.), 20.);
//             float m = .5;
//             float lp = 3.;
//             add *= diff * (1.-m) * lp + spec * m * lp + .2;

//             // Streaming light.
//             q.y = fract(q.y * .03 - time * .2) - .5;
//             add += smoothstep(.01, 0., abs(q.y)) * 3.;

//             // Flickering light.
//             float T = time + hash12(id);
//             add += step(hash12(id*1.1 + floor(T)), .05) * step(fract(T*3.), .8) * 3.;

//             add *= exp(-t*t*.1 -id.x*id.x*.001);

//             ac += add;
//         }
//     }

//     col += ac / float(nS);

//     float a= uMyData.vec_1.w;

//     col*=uMyData.vec_1.xyz;

//     col = pow(col, vec3(1./2.2)); // Gamma correction.

//     CORE_RELAXEDP vec4 baseColor = GetBaseColorSample(inUv);

//     col*=baseColor.xyz;

//     outColor = vec4(col,a);
// }

// 简单噪声函数
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

void main(void) {
    CORE_RELAXEDP vec4 baseColor = GetBaseColorSample(inUv);
    
    float time = uMyData.time / 100.0;
    vec2 uv = inUv.xy;
    
    // 创建多层正弦波浪
    float wave1 = sin(uv.x * 8.0 + time * 2.0) * 0.5 + 0.5;
    float wave2 = sin(uv.y * 6.0 + time * 1.5) * 0.3 + 0.5;
    float wave3 = sin((uv.x + uv.y) * 10.0 + time * 2.5) * 0.4 + 0.5;
    
    // 组合波浪
    float wavePattern = (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2);
    
    // 添加流向效果
    vec2 flowUV = uv;
    flowUV.x += sin(uv.y * 3.0 + time * 1.2) * 0.1;
    flowUV.y += sin(uv.x * 2.5 + time * 0.8) * 0.08;
    
    // 基于流向的波浪
    float flowWave = sin(flowUV.x * 12.0 + flowUV.y * 8.0 + time * 3.0) * 0.5 + 0.5;
    
    // 最终波浪值
    float waveValue = (wavePattern * 0.7 + flowWave * 0.3);
    
    // 海洋颜色渐变
    vec3 oceanColor;
    if (waveValue < 0.3) {
        oceanColor = mix(vec3(0.0, 0.1, 0.3), vec3(0.1, 0.3, 0.6), waveValue / 0.3);
    } else if (waveValue < 0.7) {
        oceanColor = mix(vec3(0.1, 0.3, 0.6), vec3(0.3, 0.6, 0.9), (waveValue - 0.3) / 0.4);
    } else {
        oceanColor = mix(vec3(0.3, 0.6, 0.9), vec3(0.5, 0.8, 1.0), (waveValue - 0.7) / 0.3);
    }
    
    // 添加波浪泡沫
    float foam = smoothstep(0.7, 0.9, waveValue) * (0.8 + 0.2 * sin(time * 5.0 + uv.x * 20.0));
    oceanColor += vec3(1.0, 1.0, 1.0) * foam * 0.3;
    
    // 与基础颜色混合
    vec3 finalColor = mix(baseColor.xyz, oceanColor, 0.7);
    
    outColor = vec4(finalColor, 1.0);
}