# RenderNodeDefaultEnv 详解

本文档详细说明 `RenderNodeDefaultEnv` 的输入、创建、使用、输出，以及与 Camera 环境数据的关系。

---

## 一、概述

`RenderNodeDefaultEnv` 是负责渲染相机环境背景的渲染节点。它从相机的环境配置中读取背景类型和环境贴图，然后渲染到屏幕。

**核心功能：**
- 渲染天空盒 (Sky)
- 渲染 Cubemap 环境背景
- 渲染 2D 全景图 (Equirectangular)
- 渲染 2D 图像背景
- 支持自定义 Shader 背景
- 支持多环境混合

---

## 二、输入

### 2.1 输入数据来源

| 数据存储 | 接口 | 内容 |
|----------|------|------|
| **IRenderDataStoreDefaultScene** | `stores_.dataStoreNameScene` | 当前场景信息（相机索引） |
| **IRenderDataStoreDefaultCamera** | `stores_.dataStoreNameCamera` | 相机列表、环境配置 |
| **IRenderDataStoreDefaultLight** | `stores_.dataStoreNameLight` | 灯光数据（间接使用） |

### 2.2 RenderCamera::Environment 结构体

**文件:** `nativerender/Lume_3D/api/3d/render/render_data_defines_3d.h`

```cpp
struct Environment {
    // 背景类型
    enum BackgroundType : uint32_t {
        BG_TYPE_NONE = 0,           // 无背景
        BG_TYPE_IMAGE = 1,          // 2D 图像
        BG_TYPE_CUBEMAP = 2,        // Cubemap
        BG_TYPE_EQUIRECTANGULAR = 3, // 全景图
        BG_TYPE_SKY = 4,            // 程序化天空
    };
    BackgroundType backgroundType;

    // 环境贴图
    RenderHandle envMap;            // 环境贴图句柄
    float envMapLodLevel;           // LOD 级别

    // 自定义 Shader
    RenderHandleReference shader;   // 自定义背景着色器

    // 自定义资源（用于自定义 Shader）
    RenderHandleReference customResourceHandles[MAX_ENV_CUSTOM_RESOURCE_COUNT];

    // 多环境混合
    uint32_t multiEnvCount;
    uint64_t multiEnvIds[3];

    // 层遮罩
    uint64_t layerMask;
};
```

### 2.3 JSON 配置输入

**文件示例:** `core3d_rng_cam_scene_lwrp.rng`

```json
{
    "typeName": "RenderNodeDefaultEnv",
    "nodeName": "CORE3D_RN_CAM_DM_E_LWRP",
    "renderDataStore": {
        "dataStoreName": "RenderDataStorePod",
        "typeName": "RenderDataStorePod",
        "configurationName": "CORE3D_POST_PROCESS_CAM"
    },
    "renderSlot": "CORE3D_RS_DM_ENV",
    "shaderMultiviewRenderSlot": "CORE3D_RS_DM_ENV_MV",
    "nodeFlags": 1,
    "renderPass": {
        "attachments": [...]
    }
}
```

---

## 三、创建与调用

### 3.1 节点注册

**文件:** `nativerender/Lume_3D/src/plugin/static_plugin.cpp`

```cpp
void RenderNodeDefaultEnv::FillRenderNodeTypeInfo(RenderNodeTypeInfo& info)
{
    info.uid = RenderNodeDefaultEnv::UID;      // "e3bc29b2-c1d0-4322-a41a-449354fd5a42"
    info.typeName = "RenderNodeDefaultEnv";
    info.createNode = RenderNodeDefaultEnv::Create;
    info.destroyNode = RenderNodeDefaultEnv::Destroy;
    info.backendFlags = IRenderNode::BackendFlagBits::BACKEND_FLAG_BITS_DEFAULT;
    info.classType = IRenderNode::ClassType::CLASS_TYPE_NODE;
}
```

### 3.2 配置文件声明

**文件:** `nativerender/Lume_3D/assets/3d/rendernodegraphs/core3d_rng_cam_scene_lwrp.rng`

```json
{
    "nodes": [
        // ...
        {
            "typeName": "RenderNodeDefaultMaterialRenderSlot",  // 不透明物体
            "nodeName": "CORE3D_RN_CAM_DM_SO_LWRP",
            "subpassIndex": 0
        },
        {
            "typeName": "RenderNodeDefaultEnv",                 // 环境背景
            "nodeName": "CORE3D_RN_CAM_DM_E_LWRP",
            "subpassIndex": 1                                    // 在不透明物体之后
        },
        {
            "typeName": "RenderNodeDefaultMaterialRenderSlot",  // 半透明物体
            "nodeName": "CORE3D_RN_CAM_DM_ST_LWRP",
            "subpassIndex": 2
        }
    ]
}
```

### 3.3 执行顺序

在典型的渲染管线中，RenderNodeDefaultEnv 的执行位置：

```
RenderNodeDefaultCameraController  // 创建全局资源
    ↓
RenderNodeDefaultMaterialRenderSlot (Opaque)  // 不透明物体
    ↓
RenderNodeDefaultEnv                          // 环境背景 ← 当前节点
    ↓
RenderNodeDefaultMaterialRenderSlot (Translucent)  // 半透明物体
    ↓
RenderNodeCameraPostProcessController  // 后处理
```

---

## 四、输出

### 4.1 渲染输出

**不产生 GPU Buffer 输出**，直接渲染到 RenderPass 的颜色附件：

```
┌─────────────────────────────────────────────────────────────────┐
│ RenderPass 颜色附件                                              │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                                                         │   │
│   │   环境背景（天空盒/Cubemap/图像）                        │   │
│   │   - 使用最大深度值（在所有物体后面）                     │   │
│   │   - 通过全屏三角形绘制                                   │   │
│   │                                                         │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 渲染方式

使用**全屏三角形**渲染：

```cpp
// 3 个顶点，1 个实例
// Shader 使用 vertex ID 生成顶点位置，无需顶点缓冲
cmdList.Draw(3u, 1u, 0u, 0u);
```

---

## 五、与 RenderNodeDefaultCameras 的关系

### 5.1 两个节点的职责对比

```
┌─────────────────────────────────────────────────────────────────┐
│                  RenderNodeDefaultCameras                        │
│                                                                  │
│  职责：计算和存储环境光照数据                                     │
│                                                                  │
│  输出：                                                          │
│  - SCENE_ENVIRONMENT_DATA_BUFFER (GPU Uniform Buffer)           │
│    - 球谐系数（用于间接漫反射）                                   │
│    - 环境因子（高光、漫反射强度）                                 │
│    - 环境贴图因子                                                │
│    - 多环境混合索引                                              │
│                                                                  │
│  用途：                                                          │
│  - 物体着色时的环境光照计算                                      │
│  - Shader 中访问 uEnvironmentData                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  RenderNodeDefaultEnv                            │
│                                                                  │
│  职责：渲染可见的环境背景                                         │
│                                                                  │
│  输出：                                                          │
│  - 直接渲染到屏幕（无 GPU Buffer）                               │
│                                                                  │
│  用途：                                                          │
│  - 天空盒/环境贴图的视觉呈现                                     │
│  - 相机背景渲染                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 数据流向图

```
┌─────────────────────────────────────────────────────────────────┐
│                        RenderSystem                               │
│                           ↓                                      │
│              IRenderDataStoreDefaultCamera                       │
│                    - cameras[]                                   │
│                    - environments[]                              │
└─────────────────────────────────────────────────────────────────┘
                    ↓                           ↓
    ┌───────────────────────────┐   ┌───────────────────────────┐
    │ RenderNodeDefaultCameras  │   │   RenderNodeDefaultEnv    │
    │                           │   │                           │
    │ 读取:                     │   │ 读取:                     │
    │ - RenderCamera.environment │   │ - RenderCamera.environment│
    │                           │   │   - backgroundType        │
    │ 输出:                     │   │   - envMap                │
    │ - Environment Buffer      │   │   - shader                │
    │   (球谐系数、因子等)       │   │                           │
    │                           │   │ 输出:                     │
    │ 用于:                     │   │ - 直接渲染到屏幕          │
    │ - 物体着色计算            │   │                           │
    │   (间接光照)              │   │ 用于:                     │
    │                           │   │ - 可见的环境背景          │
    └───────────────────────────┘   └───────────────────────────┘
                    ↓                           ↓
              Shader 访问                  屏幕显示
         uEnvironmentData               天空盒/背景图
```

### 5.3 关键区别

| 方面 | RenderNodeDefaultCameras | RenderNodeDefaultEnv |
|------|--------------------------|----------------------|
| **职责** | 计算/存储环境光照数据 | 渲染可见的环境背景 |
| **输出** | GPU Uniform Buffer | 直接渲染到屏幕 |
| **Shader 访问** | `uEnvironmentData` | 帧缓冲 |
| **用途** | 物体着色（间接光照） | 视觉呈现（天空盒） |
| **执行时机** | 灯光节点之后 | 不透明物体之后 |

---

## 六、疑惑点解答

### 疑惑点：GlobalDescriptorSet 是谁在什么阶段创建的，是每个节点一个的还是全局共享的？

**答案：**

#### 1. 创建者：RenderNodeDefaultCameraController

GlobalDescriptorSet (Set 0) 由 `RenderNodeDefaultCameraController` 创建。

**文件:** `nativerender/Lume_3D/src/render/node/render_node_default_camera_controller.cpp`

```cpp
void RenderNodeDefaultCameraController::InitNode(...)
{
    // ...
    // 创建全局 Descriptor Set
    const string globalSetName =
        dataStoreName + DefaultMaterialMaterialConstants::MATERIAL_SET0_GLOBAL_DESCRIPTOR_SET_PREFIX_NAME + cameraName;

    globalDescriptorSet_ = descriptorSetMgr.CreateGlobalDescriptorSet(globalSetName, plData);
}
```

#### 2. 创建阶段

在渲染器初始化时创建：

```
Renderer::InitNodeGraphs()
    ↓
遍历所有 RenderNode
    ↓
RenderNodeDefaultCameraController::InitNode()
    ↓
创建 GlobalDescriptorSet
```

#### 3. 是否全局共享？

**是全局共享的！**

```
┌─────────────────────────────────────────────────────────────────┐
│              NodeContextDescriptorSetManager                     │
│                                                                  │
│  globalDescriptorSets_: map<string, RenderHandle>               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ "SceneName_CORE3D_DM_MATERIAL_SET0_GLOBAL_CAMERA_NAME"  │   │
│  │ → RenderHandle (全局 Descriptor Set)                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
         ┌────────────────────┴────────────────────┐
         ↓                     ↓                     ↓
  RenderNodeDefaultEnv   RenderNodeDefaultMaterial   其他节点
  (通过名称获取)          (通过名称获取)              (通过名称获取)
```

#### 4. 获取方式

所有节点通过**相同名称**获取同一个 GlobalDescriptorSet：

```cpp
// RenderNodeDefaultEnv 中
fgds.set0 = dsMgr.GetGlobalDescriptorSet(
    us + DefaultMaterialMaterialConstants::MATERIAL_SET0_GLOBAL_DESCRIPTOR_SET_PREFIX_NAME + cameraName);
```

```cpp
// RenderNodeDefaultMaterialRenderSlot 中（类似）
set0 = dsMgr.GetGlobalDescriptorSet(
    dataStoreName + DefaultMaterialMaterialConstants::MATERIAL_SET0_GLOBAL_DESCRIPTOR_SET_PREFIX_NAME + cameraName);
```

#### 5. 包含的内容

Set 0 (GlobalDescriptorSet) 包含：

```
Set 0 (Global)
├── Binding 0: Camera Matrix Buffer    (uCameraData)
├── Binding 1: Environment Buffer       (uEnvironmentData)
├── Binding 2: Light Buffer             (uLightData)
├── Binding 3: Material Buffer          (uMaterialData)
└── ... 其他全局资源
```

---

## 七、被谁使用

### 7.1 渲染结果使用

- **屏幕显示**: 环境背景直接呈现给用户
- **后续节点**: 半透明物体在环境背景上叠加

### 7.2 依赖关系

| 上游节点 | 提供内容 |
|----------|----------|
| RenderNodeDefaultCameraController | GlobalDescriptorSet (Set 0) |
| RenderNodeDefaultCameras | 相机环境配置 |
| RenderNodeDefaultMaterialRenderSlot (Opaque) | 深度缓冲 |

| 下游节点 | 使用内容 |
|----------|----------|
| RenderNodeDefaultMaterialRenderSlot (Translucent) | 在背景上渲染半透明物体 |

---

## 八、如何使用

### 8.1 下游节点获取环境渲染结果

环境背景直接渲染到 RenderPass 的颜色附件，下游节点通过共享的 RenderPass 获取：

```cpp
// 在其他 RenderNode 的 JSON 配置中
{
    "renderPass": {
        "attachments": [
            {
                "resourceLocation": "from_named_render_node_output",
                "name": "output",
                "nodeName": "CORE3D_RN_CAM_CTRL"  // 共享的输出
            }
        ]
    }
}
```

### 8.2 Shader 中访问环境数据

```glsl
// Set 0, Binding 1: Environment Buffer
layout(set = 0, binding = 1) uniform DefaultMaterialEnvironmentStruct uEnvironmentData;

// 使用球谐系数计算间接漫反射
vec3 CalculateIndirectDiffuse(vec3 normal)
{
    vec3 irradiance = vec3(0.0);
    for (int i = 0; i < 9; ++i) {
        irradiance += uEnvironmentData.shIndirectCoefficients[i].rgb * SHBasis[i];
    }
    return irradiance;
}
```

### 8.3 设置自定义环境背景

```cpp
// 在应用代码中设置相机的环境配置
RenderCamera::Environment env;
env.backgroundType = RenderCamera::Environment::BG_TYPE_CUBEMAP;
env.envMap = myCubemapHandle;
env.shader = myCustomShader;  // 可选

// 设置到相机
camera.environment = env;
```

---

## 九、关键文件汇总

| 功能 | 文件路径 |
|------|----------|
| 节点实现 | `nativerender/Lume_3D/src/render/node/render_node_default_env.cpp` |
| 节点头文件 | `nativerender/Lume_3D/src/render/node/render_node_default_env.h` |
| 环境结构定义 | `nativerender/Lume_3D/api/3d/render/render_data_defines_3d.h` |
| 渲染节点图配置 | `nativerender/Lume_3D/assets/3d/rendernodegraphs/core3d_rng_cam_scene_lwrp.rng` |
| 相机控制器（创建 GlobalDescriptorSet） | `nativerender/Lume_3D/src/render/node/render_node_default_camera_controller.cpp` |

---

## 十、总结

### 输入

| 数据 | 来源 | 说明 |
|------|------|------|
| 相机环境配置 | `IRenderDataStoreDefaultCamera` | `RenderCamera::environment` |
| 后处理配置 | `IRenderDataStorePod` | 可选，用于背景后处理 |
| 渲染通道 | JSON 配置 | 指定渲染目标 |

### 创建调用

| 阶段 | 调用者 | 方法 |
|------|--------|------|
| 注册 | `StaticPlugin::Register()` | `FillRenderNodeTypeInfo()` |
| 创建 | `RenderNodeGraphManager` | 工厂方法 `Create()` |
| 初始化 | `Renderer::InitNodeGraphs()` | `InitNode()` |
| 每帧执行 | `Renderer::RenderFrame()` | `PreExecuteFrame()` → `ExecuteFrame()` |

### 输出

| 类型 | 内容 |
|------|------|
| 渲染结果 | 直接写入 RenderPass 颜色附件（无 GPU Buffer 输出） |

### 与 Camera 环境的关系

| 节点 | 消费的数据 | 产出 | 用途 |
|------|------------|------|------|
| **RenderNodeDefaultCameras** | `environment` 的球谐系数、因子 | GPU Buffer | 物体着色 |
| **RenderNodeDefaultEnv** | `environment` 的背景类型、贴图、Shader | 屏幕渲染 | 可见背景 |

### GlobalDescriptorSet 答案

| 问题 | 答案 |
|------|------|
| 谁创建？ | `RenderNodeDefaultCameraController` |
| 何时创建？ | 渲染器初始化阶段 (`InitNode`) |
| 是否共享？ | **是**，全局唯一，所有节点通过名称获取同一个 |