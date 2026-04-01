# RenderNodeDefaultLights 疑惑点详解

本文档针对 `render_node_default_lights.cpp` 中标注的疑惑点进行深入分析和解答。

---

## 疑惑点一：GPU资源创建、InitNode调用点，Output注册

**代码位置:** `render_node_default_lights.cpp:80`

```cpp
void RenderNodeDefaultLights::InitNode(IRenderNodeContextManager& renderNodeContextMgr)
{
    // ...
    lightBufferHandle_ = gpuResourceMgr.Create(bufferName, {...});
    // ...
    rngShareMgr.RegisterRenderNodeOutputs(handles);
}
```

### 解答

#### 1. InitNode 调用时机

**调用链路：**

```
Renderer::InitNodeGraphs()
    ↓
遍历 nodeGraphData.nodes
    ↓
获取 nodeContextData.renderNodeContextManager
    ↓
renderNodeData.node->InitNode(*(nodeContextData.renderNodeContextManager))
```

**源码位置:** `nativerender/LumeRender/src/renderer.cpp:540-547`

```cpp
void Renderer::InitNodeGraphs()
{
    for (size_t nodeIdx = 0; nodeIdx < nodeGraphData.nodes.size(); ++nodeIdx) {
        auto& renderNodeData = nodeGraphData.nodes[nodeIdx];
        auto& nodeContextData = nodeGraphStore.GetNodeContextData(renderNodeData);

        // 在此处调用每个节点的 InitNode
        renderNodeData.node->InitNode(*(nodeContextData.renderNodeContextManager));
    }
}
```

**调用时机：** 在渲染器初始化阶段，所有 RenderNode 创建完成后，**一次性**调用每个节点的 `InitNode()`。

#### 2. GPU 资源创建流程

详见 `RENDER_NODE_CREATION_AND_LINKING.md` 第八章。关键点：

- `gpuResourceMgr.Create()` 返回 `RenderHandleReference`（智能指针）
- 资源描述符被存储到 `pendingData.allocations`
- 实际 GPU 资源在 `HandlePendingAllocations()` 中创建（帧开始时）

#### 3. Output 注册目的

```cpp
IRenderNodeGraphShareManager& rngShareMgr = renderNodeContextMgr_->GetRenderNodeGraphShareManager();
rngShareMgr.RegisterRenderNodeOutputs(handles);
```

**目的：** 将当前节点的输出句柄注册到共享管理器，使**下游节点**能够通过索引或名称获取这些句柄。

**注册内容：**

```cpp
void RenderNodeGraphShareDataManager::RegisterRenderNodeOutput(
    const uint32_t renderNodeIdx, const string_view name, const RenderHandle& handle)
{
    auto& rnRef = renderNodeResources_[renderNodeIdx];

    if (RenderHandleUtil::IsValid(handle)) {
        // 存储到 renderNodeResources_[renderNodeIdx].outputs
        rnRef.outputs.push_back(handle);

        // 如果是 RenderNodeGraph 的输出，也注册到全局输出
        RegisterAsRenderNodeGraphOutput(renderNodeIdx, name, handle);
    }
}
```

---

## 疑惑点二：为什么要每帧重新注册 Output

**代码位置:** `render_node_default_lights.cpp:139`

```cpp
void RenderNodeDefaultLights::PreExecuteFrame()
{
    if (lightBufferHandle_) {
        IRenderNodeGraphShareManager& rngShareMgr = renderNodeContextMgr_->GetRenderNodeGraphShareManager();
        const RenderHandle handle = lightBufferHandle_.GetHandle();
        rngShareMgr.RegisterRenderNodeOutputs({ &handle, 1u });
    }
}
```

### 解答

#### 核心原因：动态环形缓冲区的句柄每帧不同

**环形缓冲区原理：**

```
┌─────────────────────────────────────────────────────────────────┐
│ 环形缓冲区 (DYNAMIC_RING_BUFFER)                                  │
│                                                                  │
│   总大小 = sizeof(DefaultMaterialLightStruct) × bufferingCount  │
│                                                                  │
│   ┌─────────┬─────────┬─────────┬─────────┐                     │
│   │ Frame 0 │ Frame 1 │ Frame 2 │ Frame 3 │  (bufferingCount=4) │
│   │ Region  │ Region  │ Region  │ Region  │                     │
│   └─────────┴─────────┴─────────┴─────────┘                     │
│       ↑                                                         │
│       │                                                         │
│   currentByteOffset (每帧变化)                                   │
└─────────────────────────────────────────────────────────────────┘
```

**每帧行为：**

1. **BeginFrame()**: 清空 `renderNodeResources_[nodeIdx].outputs`
2. **PreExecuteFrame()**: 重新注册当前帧的句柄
3. **ExecuteFrame()**: 使用当前帧偏移量映射缓冲区

**源码证据:** `render_node_graph_share_manager.cpp:72-119`

```cpp
void RenderNodeGraphShareDataManager::BeginFrame(...)
{
    // ...

    // 清空每个节点的输出列表
    renderNodeResources_.resize(renderNodeCount);
    for (auto& rnRef : renderNodeResources_) {
        rnRef.outputs.clear();  // <-- 清空！
    }
}
```

**为什么要清空再注册：**

| 原因 | 说明 |
|------|------|
| **动态偏移** | 环形缓冲区每帧使用不同的偏移区域，句柄中的偏移信息每帧变化 |
| **GPU 同步** | 防止当前帧写入覆盖上一帧 GPU 正在使用的数据 |
| **帧间隔离** | 确保每帧的输出句柄指向正确的内存区域 |

**官方注释:**

```cpp
// intf_render_node_graph_share_manager.h:104-106
/** Register render node output resource handles. (I.e. the output of this render node)
 *  Should be called every frame in PreExecuteFrame() (and initially in InitNode()).
 */
```

---

## 疑惑点三：RenderDataStoreManager 是所有 Node 共享的吗

**代码位置:** `render_node_default_lights.cpp:172`

```cpp
void RenderNodeDefaultLights::ExecuteFrame(IRenderCommandList& cmdList)
{
    const auto& renderDataStoreMgr = renderNodeContextMgr_->GetRenderDataStoreManager();

    const auto* dataStoreScene = renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameScene);
    const auto* dataStoreCamera = renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameCamera);
    const auto* dataStoreLight = renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameLight);
}
```

### 解答

#### 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      RenderContext                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            RenderDataStoreManager (全局唯一)              │   │
│  │                                                         │   │
│  │  stores_: unordered_map<name, IRenderDataStore*>        │   │
│  │                                                         │   │
│  │  ┌─────────────────┐ ┌─────────────────┐               │   │
│  │  │ DefaultScene    │ │ DefaultLight    │ ...           │   │
│  │  │ DataStore       │ │ DataStore       │               │   │
│  │  └─────────────────┘ └─────────────────┘               │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
        ┌─────────────────────┴─────────────────────┐
        ↓                     ↓                     ↓
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ RenderNode 1  │    │ RenderNode 2  │    │ RenderNode N  │
│               │    │               │    │               │
│ GetRenderData │    │ GetRenderData │    │ GetRenderData │
│ StoreManager()│    │ StoreManager()│    │ StoreManager()│
│    返回引用    │    │    返回引用    │    │    返回引用    │
└───────────────┘    └───────────────┘    └───────────────┘
```

#### 源码证据

**RenderNodeContextManager 持有的是引用：**

```cpp
// render_node_context_manager.h:99
class RenderNodeContextManager {
private:
    IRenderContext& renderContext_;  // 引用
    // ...
};

// render_node_context_manager.cpp:50-51
RenderNodeContextManager::RenderNodeContextManager(const CreateInfo& createInfo)
    : renderContext_(createInfo.renderContext), ...
```

**GetRenderDataStoreManager 返回全局管理器：**

```cpp
// render_node_context_manager.cpp:86-89
const IRenderNodeRenderDataStoreManager& RenderNodeContextManager::GetRenderDataStoreManager() const
{
    return *renderNodeRenderDataStoreMgr_;
}

// renderNodeRenderDataStoreMgr_ 创建时绑定到全局 RenderDataStoreManager
renderNodeRenderDataStoreMgr_ = make_unique<RenderNodeRenderDataStoreManager>(
    (RenderDataStoreManager&)renderContext_.GetRenderDataStoreManager());
```

#### 共享机制总结

| 问题 | 答案 |
|------|------|
| RenderDataStoreManager 是唯一的吗？ | **是**，全局只有一个实例，存储在 `RenderContext` 中 |
| 所有 Node 共享吗？ | **是**，所有节点通过引用访问同一个管理器 |
| 如何访问数据？ | 通过 `GetRenderDataStore(name)` 按名称查找 DataStore |
| 线程安全？ | 是的，内部使用 mutex 保护，渲染时使用无锁版本 |

---

## 疑惑点四：阴影图集信息什么时候注册和更新

**代码位置:** `render_node_default_lights.cpp:173`

```cpp
const Math::Vec4 shadowAtlasSizeInvSize = RenderLightHelper::GetShadowAtlasSizeInvSize(*dataStoreLight);
const uint32_t shadowCount = dataStoreLight->GetLightCounts().shadowCount;
```

### 解答

#### 阴影图集信息来源

**GetShadowAtlasSizeInvSize 实现:**

```cpp
// render_light_helper.h:43-51
static Math::Vec4 GetShadowAtlasSizeInvSize(const IRenderDataStoreDefaultLight& dsLight)
{
    // 从 DataStore 获取阴影质量分辨率设置
    const Math::UVec2 shadowQualityRes = dsLight.GetShadowQualityResolution();
    const uint32_t shadowCount = dsLight.GetLightCounts().shadowCount;

    // 计算图集大小：宽度 = 分辨率 × 阴影数量
    Math::Vec2 size = { float(shadowQualityRes.x * shadowCount), float(shadowQualityRes.y) };
    size.x = Math::max(1.0f, size.x);
    size.y = Math::max(1.0f, size.y);

    // 返回: xy = 尺寸, zw = 逆尺寸
    return { size.x, size.y, 1.0f / size.x, 1.0f / size.y };
}
```

#### 数据流向

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 应用层设置 (用户代码 / 场景系统)                               │
│    - 创建 LightComponent 并设置 shadowEnabled = true             │
│    - 设置 ShadowQuality (LOW/NORMAL/HIGH/ULTRA)                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. RenderSystem::ProcessLight (每帧)                             │
│    - 遍历所有 LightComponent                                      │
│    - 构建 RenderLight 结构                                       │
│    - 调用 dsLight_->AddLight(light)                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. IRenderDataStoreDefaultLight 存储                             │
│    - 存储 RenderLight 列表                                        │
│    - 统计 shadowCount                                            │
│    - 存储阴影质量分辨率设置                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. RenderNodeDefaultLights::ExecuteFrame (渲染时)                │
│    - 从 DataStoreLight 读取 shadowCount 和 shadowQualityRes      │
│    - 计算图集尺寸并写入 GPU 缓冲区                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 阴影图集实际创建位置

**文件:** `render_node_default_shadow_render_slot.cpp`

阴影图集纹理在阴影渲染节点中创建，而不是在灯光节点中。

```cpp
// 伪代码，实际实现更复杂
void RenderNodeDefaultShadowRenderSlot::InitNode(...)
{
    // 创建阴影深度缓冲区
    shadowDepthBuffer = gpuResourceMgr.Create(
        "CORE3D_DM_SHADOW_DEPTH_BUFFER",
        {
            CORE_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT,
            CORE_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            ...
            width = shadowAtlasWidth,   // 基于阴影数量和质量计算
            height = shadowAtlasHeight,
        });
}
```

#### 关键时序

| 阶段 | 操作 | 文件 |
|------|------|------|
| 场景更新 | `RenderSystem::ProcessLight()` 更新 DataStore | `render_system.cpp` |
| 灯光节点 | 读取 DataStore，计算图集尺寸，写入 GPU Buffer | `render_node_default_lights.cpp` |
| 阴影节点 | 创建/更新阴影图集纹理，渲染阴影贴图 | `render_node_default_shadow_render_slot.cpp` |

---

## 疑惑点五：MapBuffer 做了什么事情

**代码位置:** `render_node_default_lights.cpp:174`

```cpp
if (auto data = MapBuffer<uint8_t>(gpuResourceMgr, lightBufferHandle_.GetHandle()); data) {
    // 写入灯光数据到 data 指针
    // ...
    gpuResourceMgr.UnmapBuffer(lightBufferHandle_.GetHandle());
}
```

### 解答

#### MapBuffer 完整调用链

```
RenderNodeDefaultLights::ExecuteFrame()
    ↓
MapBuffer<uint8_t>(gpuResourceMgr, handle)
    ↓
IRenderNodeGpuResourceManager::MapBuffer(handle)
    ↓
RenderNodeGpuResourceManager::MapBuffer(handle)
    ↓
GpuResourceManager::MapBuffer(handle)
    ↓
GpuBufferGLES::Map()
    ↓
glMapBufferRange() 或 返回持久映射指针
```

#### GpuBufferGLES::Map() 实现

```cpp
// gpu_buffer_gles.cpp
void* GpuBufferGLES::Map()
{
    if (isPersistantlyMapped_) {
        // 持久映射模式：直接返回预映射的指针 + 当前帧偏移
        // （HOST_VISIBLE + HOST_COHERENT 创建的缓冲区）
        return data_ + plat_.currentByteOffset;
    } else if (isMappable_) {
        // 普通映射模式：每次调用 glMapBufferRange
        glBindBuffer(GL_COPY_WRITE_BUFFER, plat_.buffer);
        return glMapBufferRange(
            GL_COPY_WRITE_BUFFER,
            plat_.currentByteOffset,           // 偏移（环形缓冲区）
            plat_.bindMemoryByteSize,          // 大小
            GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT  // 标志
        );
    }
    return nullptr;
}
```

#### 环形缓冲区的偏移更新

```cpp
// 在每帧开始时，RenderNodeGpuResourceManager 会更新偏移
void* RenderNodeGpuResourceManager::MapBuffer(const RenderHandle& handle) const
{
    // 获取 GPU Buffer
    GpuBuffer* buffer = gpuResourceMgr_.GetBuffer(gpuHandle);

    // 对于环形缓冲区，currentByteOffset 会在每帧更新
    // currentByteOffset = (frameIndex % bufferingCount) * bindMemoryByteSize

    return buffer->Map();
}
```

#### UnmapBuffer 作用

```cpp
void GpuBufferGLES::Unmap() const
{
    if (isPersistantlyMapped_) {
        // 持久映射：无需操作，内存始终映射
        // CPU 写入会自动同步到 GPU（HOST_COHERENT）
    } else {
        // 普通映射：解除映射
        glBindBuffer(GL_COPY_WRITE_BUFFER, plat_.buffer);
        glUnmapBuffer(GL_COPY_WRITE_BUFFER);
    }
}
```

#### 图示：环形缓冲区的 Map 过程

```
帧 N (frameIndex % bufferingCount = 0):
┌─────────────────────────────────────────────────────────────────┐
│ [Region 0] [Region 1] [Region 2] [Region 3]                     │
│     ↑                                                           │
│     Map() 返回指向 Region 0 的指针                               │
└─────────────────────────────────────────────────────────────────┘

帧 N+1 (frameIndex % bufferingCount = 1):
┌─────────────────────────────────────────────────────────────────┐
│ [Region 0] [Region 1] [Region 2] [Region 3]                     │
│               ↑                                                 │
│     Map() 返回指向 Region 1 的指针                               │
│     (Region 0 可能还在被 GPU 使用)                               │
└─────────────────────────────────────────────────────────────────┘

帧 N+2 (frameIndex % bufferingCount = 2):
┌─────────────────────────────────────────────────────────────────┐
│ [Region 0] [Region 1] [Region 2] [Region 3]                     │
│                         ↑                                       │
│     Map() 返回指向 Region 2 的指针                               │
└─────────────────────────────────────────────────────────────────┘

帧 N+4 (frameIndex % bufferingCount = 0):
┌─────────────────────────────────────────────────────────────────┐
│ [Region 0] [Region 1] [Region 2] [Region 3]                     │
│     ↑                                                           │
│     Map() 返回指向 Region 0 的指针                               │
│     (帧 N 已完成，Region 0 可安全复用)                           │
└─────────────────────────────────────────────────────────────────┘
```

#### 为什么写入后不需要 Flush

因为创建时指定了 `CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT`：

```cpp
lightBufferHandle_ = gpuResourceMgr.Create(
    bufferName, {
        CORE_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
        (CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT | CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT),  // <-- COHERENT
        CORE_ENGINE_BUFFER_CREATION_DYNAMIC_RING_BUFFER,
        sizeof(DefaultMaterialLightStruct),
    });
```

**HOST_COHERENT 的含义：**
- CPU 写入自动对 GPU 可见
- 无需调用 `glFlushMappedBufferRange()` 或 `vkFlushMappedMemoryRanges()`
- 性能略低于非 COHERENT，但简化了同步

---

## 总结

| 疑惑点 | 核心答案 |
|--------|----------|
| InitNode 调用时机 | 渲染器初始化时，所有节点创建完成后**一次性**调用 |
| 每帧重新注册 Output | 环形缓冲区每帧使用不同区域，BeginFrame 清空后需重新注册 |
| RenderDataStoreManager 共享 | **全局唯一**，所有节点通过引用访问同一实例 |
| 阴影图集更新时机 | RenderSystem 每帧更新 DataStore，灯光节点读取并计算尺寸 |
| MapBuffer 作用 | 获取 CPU 可写的内存指针，环形缓冲区自动管理帧间偏移 |