# RenderNodeDefaultCameras 详解

本文档详细说明 `RenderNodeDefaultCameras` 的输入、创建、使用和输出。

---

## 一、概述

`RenderNodeDefaultCameras` 是负责处理相机和环境数据的渲染节点。它从 DataStore 读取相机和环境信息，计算各种矩阵（视图、投影、阴影等），并将结果写入 GPU 缓冲区供后续渲染阶段使用。

---

## 二、输入

### 2.1 输入数据来源

| 数据存储 | 接口 | 内容 |
|----------|------|------|
| **IRenderDataStoreDefaultCamera** | `stores_.dataStoreNameCamera` | 相机列表、环境列表 |
| **IRenderDataStoreDefaultLight** | `stores_.dataStoreNameLight` | 灯光数据（用于阴影矩阵计算） |

### 2.2 RenderCamera 结构体

**文件:** `nativerender/Lume_3D/api/3d/render/render_data_defines_3d.h`

```cpp
struct RenderCamera {
    // 标志位
    enum CameraFlagBits : uint32_t {
        CAMERA_FLAG_CUBEMAP_BIT = (1 << 0),           // Cubemap 相机
        CAMERA_FLAG_SHADOW_BIT = (1 << 1),            // 阴影相机
        CAMERA_FLAG_JITTER_BIT = (1 << 2),            // 启用抖动（TAA）
        CAMERA_FLAG_MULTI_VIEW_ONLY_BIT = (1 << 3),   // 多视图
        // ...
    };

    uint64_t id;                    // 相机唯一 ID
    uint64_t sceneId;               // 所属场景 ID
    uint64_t layerMask;             // 渲染层遮罩
    uint32_t sceneIndex;            // 场景索引

    // 矩阵
    struct Matrices {
        Math::Mat4X4 view;              // 视图矩阵
        Math::Mat4X4 proj;              // 投影矩阵
        Math::Mat4X4 viewPrevFrame;     // 上一帧视图矩阵（用于 TAA）
        Math::Mat4X4 projPrevFrame;     // 上一帧投影矩阵
    } matrices;

    // 分辨率
    Math::UVec2 renderResolution;   // 渲染分辨率

    // 阴影相关
    uint64_t shadowId;              // 关联的阴影灯光 ID

    // 环境相关
    struct Environment env;         // 环境设置

    // 多视图
    uint32_t multiViewCameraCount;
    uint64_t multiViewCameraIds[7];

    // 标志
    CameraFlags flags;

    // 裁剪
    CameraCullType cullType;

    // 清除值
    float clearColorValues[4];
    float clearDepthStencil[2];
};
```

### 2.3 Environment 结构体

```cpp
struct Environment {
    uint64_t id;                    // 环境唯一 ID
    uint64_t layerMask;             // 层遮罩

    // 环境贴图
    RenderHandle radianceCubemap;   // 辐射度 Cubemap
    uint32_t radianceCubemapMipCount;

    // 因子
    Math::Vec4 indirectSpecularFactor;  // 间接高光因子
    Math::Vec4 indirectDiffuseFactor;   // 间接漫反射因子
    Math::Vec4 envMapFactor;            // 环境贴图因子

    // 球谐系数（用于间接光照）
    Math::Vec4 shIndirectCoefficients[9];

    // 旋转
    Math::Quat rotation;            // 环境旋转

    // 混合
    float blendFactor;              // 混合因子
    uint32_t multiEnvCount;         // 多环境数量
    uint64_t multiEnvIds[3];        // 多环境 ID
};
```

---

## 三、创建与调用

### 3.1 节点注册

**文件:** `nativerender/Lume_3D/src/plugin/static_plugin.cpp`

```cpp
void RenderNodeDefaultCameras::FillRenderNodeTypeInfo(RenderNodeTypeInfo& info)
{
    info.uid = RenderNodeDefaultCameras::UID;      // "b42910bb-33c4-4790-a257-3f1837415fce"
    info.typeName = "RenderNodeDefaultCameras";    // 类型名称
    info.createNode = RenderNodeDefaultCameras::Create;
    info.destroyNode = RenderNodeDefaultCameras::Destroy;
    info.backendFlags = IRenderNode::BackendFlagBits::BACKEND_FLAG_BITS_DEFAULT;
    info.classType = IRenderNode::ClassType::CLASS_TYPE_NODE;
}
```

### 3.2 配置文件声明

**文件:** `nativerender/Lume_3D/assets/3d/rendernodegraphs/core3d_rng_scene.rng`

```json
{
    "nodes": [
        {
            "typeName": "RenderNodeDefaultLights",
            "nodeName": "CORE3D_RN_SCENE_DL"
        },
        {
            "typeName": "RenderNodeDefaultCameras",   // <-- 在 Lights 之后
            "nodeName": "CORE3D_RN_SCENE_DC"
        },
        // ... 更多节点
    ]
}
```

### 3.3 创建流程

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 渲染器初始化                                                   │
│    Renderer::InitNodeGraphs()                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. 工厂创建节点实例                                               │
│    RenderNodeManager::CreateRenderNode("RenderNodeDefaultCameras")│
│        ↓                                                         │
│    RenderNodeDefaultCameras::Create() → new RenderNodeDefaultCameras()│
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. 初始化节点                                                     │
│    RenderNodeDefaultCameras::InitNode(contextManager)            │
│    - 创建 CameraData GPU 缓冲区                                   │
│    - 创建 EnvironmentData GPU 缓冲区                              │
│    - 注册输出句柄                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 执行顺序

在 `.rng` 配置中的执行顺序：

```
RenderNodeDefaultLights (灯光数据收集)
    ↓
RenderNodeDefaultCameras (相机矩阵计算)  ← 当前节点
    ↓
RenderNodeDefaultMaterialObjects (材质物体处理)
    ↓
RenderNodeDefaultShadowRenderSlot (阴影渲染)
    ↓
RenderNodeDefaultMaterialRenderSlot (主要物体渲染)
    ↓
...
```

---

## 四、输出

### 4.1 输出句柄

| 句柄 | 类型 | 用途 |
|------|------|------|
| `camHandle_` | Uniform Buffer | 相机矩阵数据（视图、投影、阴影矩阵等） |
| `envHandle_` | Uniform Buffer | 环境数据（球谐系数、环境贴图因子等） |

### 4.2 缓冲区名称

```cpp
// Camera Buffer
bufferName = stores_.dataStoreNameScene + "CORE3D_DM_CAMERA_DATA_BUFFER"
// 例: "SceneName_CORE3D_DM_CAMERA_DATA_BUFFER"

// Environment Buffer
bufferName = stores_.dataStoreNameScene + "CORE3D_DM_SCENE_ENVIRONMENT_DATA_BUFFER"
// 例: "SceneName_CORE3D_DM_SCENE_ENVIRONMENT_DATA_BUFFER"
```

### 4.3 DefaultCameraMatrixStruct 结构

```cpp
// 文件: 3d/shaders/common/3d_dm_structures_common.h

struct DefaultCameraMatrixStruct {
    // 基本矩阵
    Math::Mat4X4 view;             // 视图矩阵
    Math::Mat4X4 proj;             // 投影矩阵
    Math::Mat4X4 viewProj;         // 视图-投影矩阵

    // 逆矩阵
    Math::Mat4X4 viewInv;          // 视图矩阵的逆
    Math::Mat4X4 projInv;          // 投影矩阵的逆
    Math::Mat4X4 viewProjInv;      // 视图-投影矩阵的逆

    // 上一帧矩阵（用于 TAA、运动模糊）
    Math::Mat4X4 viewPrevFrame;
    Math::Mat4X4 projPrevFrame;
    Math::Mat4X4 viewProjPrevFrame;

    // 阴影矩阵
    Math::Mat4X4 shadowViewProj;       // 阴影视图-投影矩阵（带偏移）
    Math::Mat4X4 shadowViewProjInv;    // 阴影矩阵的逆

    // 抖动数据（TAA）
    Math::Vec4 jitter;            // 当前帧抖动偏移
    Math::Vec4 jitterPrevFrame;   // 上一帧抖动偏移

    // 索引
    Math::UVec4 indices;          // 相机 ID、层遮罩

    // 多视图索引
    Math::UVec4 multiViewIndices;

    // 视锥体平面（用于裁剪）
    Math::Vec4 frustumPlanes[6];

    // 计数和填充
    Math::UVec4 counts;
    Math::UVec4 pad0;
    Math::Mat4X4 matPad0;
    Math::Mat4X4 matPad1;
};
```

### 4.4 DefaultMaterialEnvironmentStruct 结构

```cpp
struct DefaultMaterialEnvironmentStruct {
    // 光照因子
    Math::Vec4 indirectSpecularFactor;  // 间接高光
    Math::Vec4 indirectDiffuseFactor;   // 间接漫反射
    Math::Vec4 envMapFactor;            // 环境贴图

    // LOD 参数
    Math::Vec4 envMapParams;            // LOD 系数、LOD 级别

    // 混合
    float blendFactor;

    // 旋转
    Math::Mat4X4 rotation;

    // 索引
    Math::UVec4 indices;

    // 球谐系数（用于间接漫反射）
    Math::Vec4 shIndirectCoefficients[9];

    // 多环境索引
    Math::UVec4 multiEnvIndices;

    // 填充
    Math::UVec4 pad0;
    Math::UVec4 pad1;
};
```

---

## 五、被谁使用

### 5.1 Camera Buffer 使用者

| 渲染节点 | 用途 |
|----------|------|
| **RenderNodeDefaultShadowRenderSlot** | 获取阴影相机设置 |
| **RenderNodeDefaultMaterialRenderSlot** | 在 Shader 中访问相机矩阵进行变换 |
| **RenderNodeDefaultEnv** | 环境反射需要相机位置 |
| **RenderNodeCameraPostProcessController** | 后处理需要相机参数 |

### 5.2 Environment Buffer 使用者

| 渲染节点 | 用途 |
|----------|------|
| **RenderNodeDefaultMaterialRenderSlot** | 访问环境光照数据 |
| **RenderNodeDefaultEnv** | 渲染天空盒和环境反射 |

### 5.3 Shader 绑定

```glsl
// GLSL 示例
layout(set = 0, binding = 1) uniform DefaultCameraMatrixStruct uCameraData;
layout(set = 0, binding = 2) uniform DefaultMaterialEnvironmentStruct uEnvironmentData;

// 使用相机矩阵
vec4 worldPos = uCameraData.viewInv * vec4(viewPos, 1.0);
vec4 clipPos = uCameraData.viewProj * worldPos;

// 使用环境数据
vec3 indirectDiffuse = CalculateSH(uEnvironmentData.shIndirectCoefficients, normal);
```

---

## 六、如何使用

### 6.1 下游节点获取 Camera Buffer

```cpp
// 在其他 RenderNode 的 InitNode() 中
void SomeRenderNode::InitNode(IRenderNodeContextManager& renderNodeContextMgr)
{
    auto& rngShareMgr = renderNodeContextMgr.GetRenderNodeGraphShareManager();

    // 获取相机数据缓冲区
    RenderHandle cameraHandle = rngShareMgr.GetNamedRenderNodeGraphOutput(
        "CORE3D_DM_CAMERA_DATA_BUFFER");

    // 或者通过节点名称和索引获取
    RenderHandle cameraHandle = rngShareMgr.GetRegisteredRenderNodeOutput(
        "CORE3D_RN_SCENE_DC", 0);  // 节点名, 输出索引
}
```

### 6.2 Shader 中使用

```glsl
// 顶点着色器
vec4 GetClipPosition(vec3 worldPos)
{
    return uCameraData.viewProj * vec4(worldPos, 1.0);
}

// 片元着色器 - 计算运动向量（TAA）
vec2 CalculateMotionVector(vec4 currentClip, vec4 previousClip)
{
    vec2 currentNDC = currentClip.xy / currentClip.w;
    vec2 previousNDC = previousClip.xy / previousClip.w;
    return currentNDC - previousNDC;
}

// 片元着色器 - 阴影坐标
vec4 GetShadowCoord(vec4 worldPos, uint cameraIndex)
{
    return uCameraData.cameras[cameraIndex].shadowViewProj * worldPos;
}
```

---

## 七、内部处理流程

### 7.1 ExecuteFrame 流程

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 获取 DataStore                                                │
│    - IRenderDataStoreDefaultCamera (相机和环境列表)              │
│    - IRenderDataStoreDefaultLight (灯光数据)                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Map Camera Buffer                                             │
│    gpuResMgr.MapBuffer(camHandle_)                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. 添加普通相机                                                   │
│    AddCameras(dsCamera, dsLight, cameras, data, 0)              │
│    - 计算 view/proj/viewProj 矩阵                                │
│    - 计算逆矩阵                                                   │
│    - 计算阴影矩阵                                                 │
│    - 计算抖动偏移（TAA）                                          │
│    - 计算视锥体平面                                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. 添加 Cubemap 相机（如果有）                                    │
│    AddCameras(dsCamera, dsLight, cubemapCameras_, data, count)  │
│    - 处理 6 个方向的 Cubemap 视图                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Unmap Camera Buffer                                           │
│    gpuResMgr.UnmapBuffer(camHandle_)                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. Map Environment Buffer                                        │
│    gpuResMgr.MapBuffer(envHandle_)                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. 添加环境数据                                                   │
│    AddEnvironments(dsCamera, environments, data)                 │
│    - 复制球谐系数                                                 │
│    - 复制环境因子                                                 │
│    - 处理多环境混合                                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 8. Unmap Environment Buffer                                      │
│    gpuResMgr.UnmapBuffer(envHandle_)                             │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 阴影矩阵计算

```cpp
// 标准阴影偏移矩阵
// 将 [-1, 1] 范围变换到 [0, 1] 用于阴影贴图采样
constexpr Math::Mat4X4 SHADOW_BIAS_MATRIX = {
    0.5f, 0.0f, 0.0f, 0.0f,
    0.0f, 0.5f, 0.0f, 0.0f,
    0.0f, 0.0f, 1.0f, 0.0f,
    0.5f, 0.5f, 0.0f, 1.0f
};

// 对于级联阴影，根据阴影索引计算偏移
Math::Mat4X4 GetShadowBias(uint32_t shadowIndex, uint32_t shadowCount)
{
    float invShadowCount = 1.0f / shadowCount;
    float sc = 0.5f * invShadowCount;  // 缩放
    float so = invShadowCount * shadowIndex;  // 偏移

    return {
        sc,   0.0f, 0.0f, 0.0f,
        0.0f, 0.5f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f, 0.0f,
        sc + so, 0.5f, 0.0f, 1.0f
    };
}
```

### 7.3 抖动（TAA）计算

```cpp
// Halton 序列用于生成低差异采样点
constexpr Math::Vec2 halton16[] = {
    { 0.500000f, 0.333333f },
    { 0.250000f, 0.666667f },
    // ... 16 个采样点
};

// 每帧使用不同的抖动偏移
Math::Vec2 GetHaltonOffset(uint32_t haltonIndex)
{
    return halton16[haltonIndex % 16];
}

// 应用抖动到投影矩阵
JitterProjection GetProjectionMatrix(const RenderCamera& camera, bool prevFrame)
{
    JitterProjection jp;
    jp.baseProj = camera.matrices.proj;
    jp.proj = jp.baseProj;

    if (camera.flags & CAMERA_FLAG_JITTER_BIT) {
        Math::Vec2 haltonOffset = GetHaltonOffset(jitterIndex_);
        Math::Vec2 jitterRes = (haltonOffset * 2.0f - 1.0f) / renderResolution;

        // 修改投影矩阵的偏移
        jp.proj[2][0] += jitterRes.x;
        jp.proj[2][1] += jitterRes.y;
    }
    return jp;
}
```

---

## 八、关键文件汇总

| 功能 | 文件路径 |
|------|----------|
| 节点实现 | `nativerender/Lume_3D/src/render/node/render_node_default_cameras.cpp` |
| 节点头文件 | `nativerender/Lume_3D/src/render/node/render_node_default_cameras.h` |
| DataStore 接口 | `nativerender/Lume_3D/api/3d/render/intf_render_data_store_default_camera.h` |
| RenderCamera 定义 | `nativerender/Lume_3D/api/3d/render/render_data_defines_3d.h` |
| GPU 结构定义 | `nativerender/Lume_3D/shaders/common/3d_dm_structures_common.h` |
| 场景系统（输入源） | `nativerender/Lume_3D/src/ecs/systems/render_system.cpp` |

---

## 九、总结

### 输入

| 数据 | 来源 | 提供者 |
|------|------|--------|
| 相机列表 | `IRenderDataStoreDefaultCamera` | `RenderSystem::ProcessCameras()` |
| 环境列表 | `IRenderDataStoreDefaultCamera` | `RenderSystem::ProcessEnvironments()` |
| 灯光数据 | `IRenderDataStoreDefaultLight` | `RenderSystem::ProcessLights()` |

### 创建调用

| 阶段 | 调用者 | 方法 |
|------|--------|------|
| 注册 | `StaticPlugin::Register()` | `FillRenderNodeTypeInfo()` |
| 创建 | `RenderNodeGraphManager` | 工厂方法 `Create()` |
| 初始化 | `Renderer::InitNodeGraphs()` | `InitNode()` |
| 每帧执行 | `Renderer::RenderFrame()` | `PreExecuteFrame()` → `ExecuteFrame()` |

### 输出

| 缓冲区 | 内容 | 使用者 |
|--------|------|--------|
| `CAMERA_DATA_BUFFER` | 相机矩阵、阴影矩阵、抖动数据 | 所有需要相机信息的渲染节点和 Shader |
| `SCENE_ENVIRONMENT_DATA_BUFFER` | 环境光照、球谐系数、混合因子 | 材质渲染、环境渲染节点 |

### 使用方式

```cpp
// 在其他节点中获取
RenderHandle camHandle = rngShareMgr.GetNamedRenderNodeGraphOutput("CORE3D_DM_CAMERA_DATA_BUFFER");

// 在 Shader 中访问
layout(set = 0, binding = 1) uniform DefaultCameraMatrixStruct uCameraData;
vec4 clipPos = uCameraData.viewProj * worldPos;
```