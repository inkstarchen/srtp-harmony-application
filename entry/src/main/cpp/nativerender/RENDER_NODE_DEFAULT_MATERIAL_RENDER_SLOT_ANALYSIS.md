# RenderNodeDefaultMaterialRenderSlot 详解

本文档详细说明 `RenderNodeDefaultMaterialRenderSlot` 的输入、创建、使用、输出，以及 Shader 如何识别传入的数据。

---

## 一、概述

`RenderNodeDefaultMaterialRenderSlot` 是负责渲染所有网格物体的核心渲染节点。它从 DataStore 获取排序后的子网格列表，绑定 Pipeline 和资源，执行绘制命令。

**核心功能：**
- 遍历并渲染所有可渲染的子网格 (Submesh)
- 管理 Pipeline State Object (PSO) 缓存
- 绑定全局 Descriptor Sets (Set 0/1/2/3)
- 处理材质排序和裁剪
- 支持 GPU 实例化和骨骼动画

---

## 二、输入

### 2.1 输入数据来源

| 数据存储 | 接口 | 内容 |
|----------|------|------|
| **IRenderDataStoreDefaultScene** | `stores_.dataStoreNameScene` | 当前场景信息 |
| **IRenderDataStoreDefaultCamera** | `stores_.dataStoreNameCamera` | 相机列表、环境配置 |
| **IRenderDataStoreDefaultMaterial** | `stores_.dataStoreNameMaterial` | 子网格列表、材质数据、自定义资源 |
| **IRenderDataStoreDefaultLight** | `stores_.dataStoreNameLight` | 灯光数据、阴影类型 |

### 2.2 RenderSubmesh 结构体

```cpp
struct RenderSubmesh {
    // 层信息
    struct Layers {
        uint64_t sceneId;      // 所属场景 ID
        uint64_t layerMask;    // 层遮罩
    } layers;

    // 索引
    struct Indices {
        uint32_t meshIndex;           // 网格索引
        uint32_t materialIndex;       // 材质索引
        uint32_t materialFrameOffset; // 材质帧偏移
        uint32_t skinJointIndex;      // 骨骼关节索引
    } indices;

    // 缓冲区
    struct Buffers {
        RenderHandle vertexBuffers[MAX_VERTEX_BUFFER_COUNT];
        uint32_t vertexBufferCount;
        IndexBuffer indexBuffer;
        VertexBuffer indirectArgsBuffer;
        InputAssembly inputAssembly;
    } buffers;

    // 绘制命令
    DrawCommand drawCommand;

    // 标志
    RenderSubmeshFlags submeshFlags;
};
```

### 2.3 JSON 配置输入

```json
{
    "typeName": "RenderNodeDefaultMaterialRenderSlot",
    "renderSlot": "CORE3D_RS_DM_FW_OPAQUE",
    "shaderMultiviewRenderSlot": "CORE3D_RS_DM_FW_OPAQUE_MV",
    "renderSlotSortType": "by_material",
    "renderSlotCullType": "view_frustum_cull",
    "nodeFlags": 1,
    "renderPass": { ... }
}
```

---

## 三、创建与调用

### 3.1 节点注册

```cpp
// static_plugin.cpp
void RenderNodeDefaultMaterialRenderSlot::FillRenderNodeTypeInfo(RenderNodeTypeInfo& info)
{
    info.uid = RenderNodeDefaultMaterialRenderSlot::UID;  // "80758e28-f064-45e6-878d-624652598405"
    info.typeName = "RenderNodeDefaultMaterialRenderSlot";
    info.createNode = RenderNodeDefaultMaterialRenderSlot::Create;
    info.destroyNode = RenderNodeDefaultMaterialRenderSlot::Destroy;
}
```

### 3.2 执行顺序

在典型的渲染管线中：

```
RenderNodeDefaultLights         // 灯光数据收集
    ↓
RenderNodeDefaultCameras        // 相机矩阵计算
    ↓
RenderNodeDefaultMaterialObjects // 材质物体处理
    ↓
RenderNodeDefaultShadowRenderSlot // 阴影渲染
    ↓
RenderNodeDefaultMaterialRenderSlot (Opaque) // 不透明物体渲染 ← 当前节点
    ↓
RenderNodeDefaultEnv            // 环境背景
    ↓
RenderNodeDefaultMaterialRenderSlot (Translucent) // 半透明物体渲染
    ↓
RenderNodeCameraPostProcessController // 后处理
```

---

## 四、输出

### 4.1 渲染输出

**不产生 GPU Buffer 输出**，直接渲染到 RenderPass 的颜色和深度附件。

### 4.2 渲染内容

```
RenderPass 输出:
├── 颜色附件: 渲染的物体颜色
├── 深度附件: 渲染的深度值
└── 可选附件: 速度缓冲、法线等
```

---

## 五、Shader 如何识别传入的数据

### 5.1 Descriptor Set 布局

```
┌─────────────────────────────────────────────────────────────────┐
│                    Descriptor Set 绑定                           │
├─────────────────────────────────────────────────────────────────┤
│ Set 0 (全局 - 每相机)                                            │
│   ├── Binding 0: Camera Matrix Buffer    (uCameraData)          │
│   ├── Binding 1: Environment Buffer      (uEnvironmentData)     │
│   ├── Binding 2: Light Buffer            (uLightData)           │
│   └── ... 其他全局资源                                           │
├─────────────────────────────────────────────────────────────────┤
│ Set 1 (每物体 - 动态偏移)                                        │
│   ├── Binding 0: Mesh Matrix Buffer      (uMeshMatrix)          │
│   │   - world: 世界矩阵                                          │
│   │   - prevWorld: 上一帧世界矩阵                                 │
│   ├── Binding 1: Skin Joint Buffer       (uSkinJointData)       │
│   ├── Binding 2: Material Buffer         (uMaterialData)        │
│   ├── Binding 3: Material User Data      (uMaterialUserData)    │
│   └── Binding 4: Material User Data 2                          │
├─────────────────────────────────────────────────────────────────┤
│ Set 2 (每材质)                                                   │
│   ├── Binding 0: Base Color Texture     (sBaseColor)            │
│   ├── Binding 1: Normal Texture         (sNormal)               │
│   ├── Binding 2: Material Texture       (sMaterial)             │
│   ├── Binding 3: Emissive Texture       (sEmissive)             │
│   ├── Binding 4: AO Texture             (sAo)                   │
│   ├── Binding 5: Cubemap Sampler        (sCubemap)              │
│   └── ... 其他材质资源                                           │
├─────────────────────────────────────────────────────────────────┤
│ Set 3 (自定义 - 可选)                                            │
│   └── 用户自定义资源 (Buffer/Image/Sampler)                      │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 特化常量 (Specialization Constants)

Shader 通过**特化常量**识别运行时配置：

```cpp
// 特化常量 ID 定义 (3d_dm_structures_common.h)
#define CORE_DM_CONSTANT_ID_MATERIAL_TYPE 0      // 材质类型
#define CORE_DM_CONSTANT_ID_MATERIAL_FLAGS 1     // 材质标志
#define CORE_DM_CONSTANT_ID_LIGHTING_FLAGS 2     // 光照标志
#define CORE_DM_CONSTANT_ID_POST_PROCESS_FLAGS 3 // 后处理标志
#define CORE_DM_CONSTANT_ID_CAMERA_FLAGS 4       // 相机标志
#define CORE_DM_CONSTANT_ID_ENV_TYPE 5           // 环境类型
#define CORE_DM_CONSTANT_ID_SUBMESH_FLAGS 6      // 子网格标志
```

### 5.3 特化常量的设置流程

```cpp
// C++ 端设置特化常量
ShaderSpecializationConstantDataView GetShaderSpecView(...)
{
    for (uint32_t idx = 0; idx < specializationCount; ++idx) {
        const auto& ref = constants[idx];
        const uint32_t constantId = ref.offset / sizeof(uint32_t);

        if (ref.shaderStage == VERTEX) {
            if (ref.id == CORE_DM_CONSTANT_ID_SUBMESH_FLAGS) {
                flags[constantId] = submeshFlags;  // 切线、顶点色、骨骼等
            } else if (ref.id == CORE_DM_CONSTANT_ID_MATERIAL_FLAGS) {
                flags[constantId] = materialFlags; // 阴影接收、法线贴图等
            }
        } else if (ref.shaderStage == FRAGMENT) {
            if (ref.id == CORE_DM_CONSTANT_ID_MATERIAL_TYPE) {
                flags[constantId] = materialType;  // MetallicRoughness/Unlit/Custom
            } else if (ref.id == CORE_DM_CONSTANT_ID_LIGHTING_FLAGS) {
                flags[constantId] = lightingFlags; // VSM阴影、点光源、聚光灯
            } else if (ref.id == CORE_DM_CONSTANT_ID_CAMERA_FLAGS) {
                flags[constantId] = cameraFlags;   // 雾效
            }
        }
    }
}
```

### 5.4 GLSL Shader 中的使用

```glsl
// 特化常量声明
layout (constant_id = 0) const uint CORE_MATERIAL_TYPE = 0;
layout (constant_id = 1) const uint CORE_MATERIAL_FLAGS = 0;
layout (constant_id = 2) const uint CORE_LIGHTING_FLAGS = 0;
layout (constant_id = 4) const uint CORE_CAMERA_FLAGS = 0;
layout (constant_id = 6) const uint CORE_SUBMESH_FLAGS = 0;

// 根据特化常量决定代码路径
#if (CORE_MATERIAL_TYPE == CORE_MATERIAL_METALLIC_ROUGHNESS)
    // PBR Metallic-Roughness 材质
#elif (CORE_MATERIAL_TYPE == CORE_MATERIAL_UNLIT)
    // 无光照材质
#elif (CORE_MATERIAL_TYPE == CORE_MATERIAL_CUSTOM)
    // 自定义材质
#endif

// 根据标志启用功能
#if (CORE_MATERIAL_FLAGS & CORE_MATERIAL_NORMAL_MAP_BIT)
    // 使用法线贴图
    vec3 normal = texture(sNormal, uv).xyz;
#endif

#if (CORE_LIGHTING_FLAGS & CORE_LIGHTING_SHADOW_TYPE_VSM_BIT)
    // VSM 阴影
#endif

#if (CORE_CAMERA_FLAGS & CORE_CAMERA_FOG_BIT)
    // 启用雾效
#endif

#if (CORE_SUBMESH_FLAGS & CORE_SUBMESH_SKIN_BIT)
    // 骨骼动画
    mat4 skinMatrix = uSkinJointData.joints[jointIndices.x] * weights.x + ...;
#endif
```

### 5.5 动态偏移 (Dynamic Offsets)

Set 1 使用**动态偏移**来高效切换每物体的数据：

```cpp
// C++ 端绑定 Set 1
const uint32_t dynamicOffsets[] = {
    currSubmesh.indices.meshIndex * UBO_BIND_OFFSET_ALIGNMENT,    // Mesh 偏移
    skinJointIndex * sizeof(DefaultMaterialSkinStruct),           // Skin 偏移
    materialOffset,                                                // Material 偏移
    materialOffset,                                                // User Data 偏移
    materialOffset                                                 // User Data 2 偏移
};

cmdList.BindDescriptorSets(1, { set1Handle, dynamicOffsets });
```

```glsl
// GLSL 中访问（自动使用偏移）
layout(set = 1, binding = 0) uniform MeshMatrixStruct {
    mat4 world;
    mat4 prevWorld;
} uMeshMatrix;

// uMeshMatrix 会自动指向当前物体的数据
```

---

## 六、渲染流程详解

### 6.1 ExecuteFrame 流程

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 获取 DataStore                                                │
│    - Scene, Material, Camera, Light                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. 更新当前场景                                                  │
│    - UpdateCurrentScene()                                        │
│    - 获取当前相机、视口、灯光标志                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. 开始 RenderPass                                               │
│    - BeginRenderPass()                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. 处理子网格列表                                                │
│    - ProcessSlotSubmeshes()                                      │
│    - 排序、裁剪                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. 渲染子网格                                                    │
│    for each submesh in sortedSlotSubmeshes_:                    │
│    ├── BindPipeline()      - 绑定 PSO                           │
│    ├── BindSet1And2()      - 绑定 Mesh/Material 资源            │
│    ├── UpdateAndBindSet3() - 绑定自定义资源（可选）              │
│    └── Draw()              - 执行绘制                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. 结束 RenderPass                                               │
│    - EndRenderPass()                                             │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 PSO 缓存机制

```cpp
// 哈希计算：组合多个因素
uint64_t hash = HashShaderDataAndSubmesh(
    shaderDataHash,      // Shader 哈希
    renderHash,          // 渲染配置哈希
    lightingFlags,       // 光照标志
    cameraShaderFlags,   // 相机标志
    postProcessFlags,    // 后处理标志
    inputAssembly        // 输入装配（拓扑类型）
);

// 缓存查找
if (shaderIdToData.find(hash) != end()) {
    return cachedPso;  // 命中缓存
}

// 创建新 PSO
return CreateNewPso(...);
```

---

## 七、被谁使用

### 7.1 上游依赖

| 节点 | 提供内容 |
|------|----------|
| RenderNodeDefaultCameraController | GlobalDescriptorSets (Set 0/1/2) |
| RenderNodeDefaultCameras | 相机矩阵数据 |
| RenderNodeDefaultLights | 灯光数据 |
| RenderNodeDefaultMaterialObjects | 子网格排序数据 |

### 7.2 下游使用

| 节点 | 使用内容 |
|------|----------|
| RenderNodeDefaultEnv | 在物体渲染后绘制背景 |
| RenderNodeCameraPostProcessController | 后处理 |

---

## 八、如何使用

### 8.1 在 .rng 配置中使用

```json
{
    "typeName": "RenderNodeDefaultMaterialRenderSlot",
    "nodeName": "CORE3D_RN_CAM_DM_OPAQUE",
    "renderSlot": "CORE3D_RS_DM_FW_OPAQUE",
    "shaderMultiviewRenderSlot": "CORE3D_RS_DM_FW_OPAQUE_MV",
    "renderSlotSortType": "by_material",
    "renderSlotCullType": "view_frustum_cull",
    "renderPass": {
        "attachments": [
            { "name": "depth", "loadOp": "clear" },
            { "name": "output", "loadOp": "clear" }
        ]
    }
}
```

### 8.2 Shader 数据访问总结

```
┌─────────────────────────────────────────────────────────────────┐
│                     数据传递路径                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  C++ 端                          GLSL 端                         │
│  ─────────                       ─────────                       │
│                                                                  │
│  RenderNodeDefaultCameras::AddCameras()                         │
│       ↓                                                          │
│  Camera Buffer (Set 0, B0)  →   uCameraData.viewProj            │
│                                  uCameraData.viewInv            │
│                                  uCameraData.shadowViewProj     │
│                                                                  │
│  RenderNodeDefaultLights::ExecuteFrame()                        │
│       ↓                                                          │
│  Light Buffer (Set 0, B2)   →   uLightData.lights[]            │
│                                  uLightData.atlasSizeInvSize    │
│                                                                  │
│  RenderNodeDefaultMaterialRenderSlot::BindSet1And2()            │
│       ↓                                                          │
│  Mesh Matrix (Set 1, B0)    →   uMeshMatrix.world              │
│       ↑                         uMeshMatrix.prevWorld          │
│  [dynamicOffset = meshIdx * 256]                                │
│                                                                  │
│  Material Buffer (Set 1, B2) →   uMaterialData.factors[]       │
│       ↑                                                         │
│  [dynamicOffset = matOffset]                                    │
│                                                                  │
│  Material Textures (Set 2)  →   sBaseColor, sNormal            │
│       ↑                         sMaterial, sEmissive           │
│  [per material handle]                                           │
│                                                                  │
│  Specialization Constants   →   CORE_MATERIAL_TYPE             │
│       ↑                         CORE_MATERIAL_FLAGS            │
│  [set at PSO creation]           CORE_LIGHTING_FLAGS           │
│                                  CORE_CAMERA_FLAGS              │
│                                  CORE_SUBMESH_FLAGS             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 九、关键文件汇总

| 功能 | 文件路径 |
|------|----------|
| 节点实现 | `nativerender/Lume_3D/src/render/node/render_node_default_material_render_slot.cpp` |
| 节点头文件 | `nativerender/Lume_3D/src/render/node/render_node_default_material_render_slot.h` |
| GPU 结构定义 | `nativerender/Lume_3D/api/3d/shaders/common/3d_dm_structures_common.h` |
| 材质数据存储 | `nativerender/Lume_3D/src/render/datastore/render_data_store_default_material.cpp` |
| 渲染节点图配置 | `nativerender/Lume_3D/assets/3d/rendernodegraphs/core3d_rng_cam_scene_lwrp.rng` |

---

## 十、总结

### 输入

| 数据 | 来源 | 说明 |
|------|------|------|
| 子网格列表 | `IRenderDataStoreDefaultMaterial` | 所有可渲染物体 |
| 相机数据 | `IRenderDataStoreDefaultCamera` | 视图/投影矩阵 |
| 灯光数据 | `IRenderDataStoreDefaultLight` | 光照参数 |
| 场景数据 | `IRenderDataStoreDefaultScene` | 当前相机索引 |

### 创建调用

| 阶段 | 调用者 | 方法 |
|------|--------|------|
| 注册 | `StaticPlugin::Register()` | `FillRenderNodeTypeInfo()` |
| 创建 | `RenderNodeGraphManager` | 工厂方法 `Create()` |
| 初始化 | `Renderer::InitNodeGraphs()` | `InitNode()` |
| 每帧执行 | `Renderer::RenderFrame()` | `ExecuteFrame()` |

### 输出

| 类型 | 内容 |
|------|------|
| 渲染结果 | 直接写入 RenderPass 颜色/深度附件 |

### Shader 数据识别方式

| 方式 | 用途 |
|------|------|
| **Descriptor Sets** | 传递 Buffer 和 Texture 数据 |
| **Dynamic Offsets** | 高效切换每物体数据 |
| **Specialization Constants** | 编译时决定代码路径（材质类型、标志位等） |