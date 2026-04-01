# RenderNode 批量创建与链接机制分析

## 一、概述

RenderNode 是 LumeRender 渲染管线中的核心组件，每个节点负责特定的渲染任务（如灯光处理、阴影渲染、材质渲染等）。本文档详细分析：

1. RenderNode 的批量创建机制
2. 创建逻辑的位置和实现
3. 节点之间的链接和上下级关联建立方式

---

## 二、RenderNode 创建机制

### 2.1 工厂注册模式

RenderNode 使用工厂模式创建实例，通过 `RenderNodeTypeInfo` 结构注册节点类型信息。

**关键文件:** `nativerender/LumeRender/src/nodecontext/render_node_manager.cpp`

```cpp
// RenderNodeTypeInfo 结构定义
struct RenderNodeTypeInfo {
    IRenderNode* (*createNode)();       // 创建函数指针
    void (*destroyNode)(IRenderNode*);  // 销毁函数指针
    IRenderNode::BackendFlags backendFlags;
    IRenderNode::ClassType classType;
    BASE_NS::Uid uid;
    const char* const typeName;         // 类型名称，用于配置匹配
};

// 工厂映射表
BASE_NS::unordered_map<BASE_NS::string_view, RenderNodeTypeInfo> factories_;
```

**注册流程:**

```
静态库初始化
    ↓
StaticPlugin::Register() 被调用
    ↓
FillRenderNodeTypeInfo(info) 填充节点信息
    ↓
RenderNodeManager::RegisterRenderNode(info) 注册到 factories_
```

**示例: RenderNodeDefaultLights 注册**

```cpp
// nativerender/Lume_3D/src/plugin/static_plugin.cpp
void RenderNodeDefaultLights::FillRenderNodeTypeInfo(RenderNodeTypeInfo& info)
{
    info.uid = RenderNodeDefaultLights::UID;
    info.typeName = RenderNodeDefaultLights::TYPE_NAME;  // "RenderNodeDefaultLights"
    info.createNode = RenderNodeDefaultLights::Create;
    info.destroyNode = RenderNodeDefaultLights::Destroy;
    info.backendFlags = RenderNodeDefaultLights::BACKEND_FLAGS;
    info.classType = RenderNodeDefaultLights::CLASS_TYPE;
}
```

### 2.2 批量创建逻辑

RenderNode 通过 `.rng` (RenderNodeGraph) 配置文件批量创建。

**关键文件:** `nativerender/LumeRender/src/nodecontext/render_node_graph_manager.cpp`

**核心函数:** `RenderNodeGraphManager::PendingCreate()`

```cpp
void RenderNodeGraphManager::PendingCreate(...)
{
    // 1. 解析 .rng 配置文件（JSON格式）
    const auto& nodeGraphData = renderNodeGraphDataStore.jsonData;

    // 2. 遍历配置中的所有节点定义
    for (const auto& node : nodeGraphData.nodes) {
        // 3. 根据 typeName 查找工厂
        auto factory = renderNodeMgr.CreateRenderNode(node.typeName);

        // 4. 创建节点实例
        IRenderNode* nodeInstance = factory.createNode();

        // 5. 存储节点到 NodeStore
        nodeStore.AddNode(nodeInstance, node.nodeName);
    }
}
```

**配置文件示例:** `nativerender/Lume_3D/assets/3d/rendernodegraphs/core3d_rng_scene.rng`

```json
{
    "nodes": [
        {
            "typeName": "RenderNodeDefaultLights",
            "nodeName": "CORE3D_RN_SCENE_DL"
        },
        {
            "typeName": "RenderNodeDefaultCameras",
            "nodeName": "CORE3D_RN_SCENE_DC"
        },
        {
            "typeName": "RenderNodeDefaultShadowRenderSlot",
            "nodeName": "CORE3D_RN_SCENE_SRS"
        },
        // ... 更多节点
    ]
}
```

---

## 三、节点链接与上下级关联

### 3.1 链接方式概述

RenderNode **不使用传统的父子指针链接**，而是通过以下机制建立关联：

| 机制 | 用途 | 实现方式 |
|------|------|----------|
| **执行顺序** | 定义节点执行次序 | `.rng` 配置中的 nodes 数组顺序 |
| **数据共享** | 传递数据给下游节点 | `IRenderNodeGraphShareManager` |
| **数据存储** | 持久化中间数据 | `IRenderDataStoreManager` |
| **输入句柄** | 获取上游节点输出 | `IRenderNodeContextManager::GetRenderNodeGraphData()` |

### 3.2 执行顺序定义

**节点执行顺序完全由 `.rng` 配置文件中的 nodes 数组顺序决定：**

```cpp
// nativerender/LumeRender/src/renderer.cpp
void Renderer::RenderFrame(...)
{
    // 按配置顺序遍历所有节点
    for (auto& renderNodeData : nodeGraphData.nodes) {
        // 依次执行每个节点
        renderNodeData.node->ExecuteFrame(cmdList);
    }
}
```

**典型执行顺序 (core3d_rng_scene.rng):**

```
1. RenderNodeDefaultLights        → 收集灯光数据，写入 GPU 缓冲区
2. RenderNodeDefaultCameras       → 设置相机参数
3. RenderNodeDefaultMaterialObjects → 处理材质物体
4. RenderNodeMorph                → 形态目标动画
5. RenderNodeDefaultShadowRenderSlot → 【阴影贴图渲染】
6. RenderNodeDefaultShadowsBlur   → VSM 阴影模糊
7. RenderNodeDefaultEnvironmentBlender → 环境混合
8. RenderNodeDefaultMaterialRenderSlot → 【主要物体渲染】
9. RenderNodeDefaultDepthRenderSlot → 深度预处理
10. RenderNodeDefaultEnv          → 环境反射/天空盒
11. RenderNodeCameraPostProcessController → 【后处理】
```

### 3.3 数据共享机制

**上游节点输出 → 下游节点输入：**

通过 `IRenderNodeGraphShareManager` 注册输出句柄，下游节点通过名称查找获取。

```cpp
// 上游节点注册输出 (RenderNodeDefaultLights)
void RenderNodeDefaultLights::InitNode(...)
{
    // 创建 GPU 缓冲区
    lightBufferHandle_ = gpuResourceMgr.Create(bufferName, ...);

    // 注册到共享管理器
    IRenderNodeGraphShareManager& rngShareMgr =
        renderNodeContextMgr_->GetRenderNodeGraphShareManager();
    rngShareMgr.RegisterRenderNodeOutputs({ lightBufferHandle_.GetHandle() });
}

// 下游节点获取输入 (RenderNodeDefaultMaterialRenderSlot)
void RenderNodeDefaultMaterialRenderSlot::InitNode(...)
{
    // 从共享管理器获取上游输出
    IRenderNodeGraphShareManager& rngShareMgr =
        renderNodeContextMgr_->GetRenderNodeGraphShareManager();

    // 查找特定名称的输出
    RenderHandle lightHandle = rngShareMgr.GetRenderNodeOutput(
        "CORE3D_DM_LIGHT_DATA_BUFFER");
}
```

### 3.4 DataStore 数据传递

DataStore 用于持久化渲染数据，节点可以读写共享的数据存储。

**关键接口:** `IRenderDataStoreManager`

```cpp
void RenderNodeDefaultLights::ExecuteFrame(...)
{
    // 获取数据存储管理器
    const auto& renderDataStoreMgr =
        renderNodeContextMgr_->GetRenderDataStoreManager();

    // 读取其他节点/系统写入的数据
    const auto* dataStoreLight =
        renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameLight);

    // 处理数据并写入自己的输出
    const auto& lights = dataStoreLight->GetLights();
    // ... 写入 GPU 缓冲区
}
```

**DataStore 类型:**

| DataStore | 提供者 | 内容 |
|-----------|--------|------|
| `IRenderDataStoreDefaultScene` | 场景系统 | 场景信息、相机索引 |
| `IRenderDataStoreDefaultCamera` | 相机系统 | 相机列表、投影矩阵 |
| `IRenderDataStoreDefaultLight` | 灯光系统 | 所有灯光数据 |
| `IRenderDataStoreDefaultMaterial` | 材质系统 | 材质属性 |

---

## 四、节点初始化流程

### 4.1 初始化时机

节点创建后，在 `Renderer::InitNodeGraphs()` 中统一初始化。

```cpp
// nativerender/LumeRender/src/renderer.cpp
void Renderer::InitNodeGraphs()
{
    // 遍历所有已创建的节点
    for (auto& renderNodeData : nodeGraphData.nodes) {
        // 获取节点上下文数据
        auto& nodeContextData = nodeGraphStore.GetNodeContextData(renderNodeData);

        // 调用节点的 InitNode 方法
        renderNodeData.node->InitNode(
            *(nodeContextData.renderNodeContextManager));
    }
}
```

### 4.2 节点上下文管理器

`IRenderNodeContextManager` 为每个节点提供完整的上下文访问：

```cpp
class IRenderNodeContextManager {
    // 资源管理
    IRenderNodeGpuResourceManager& GetGpuResourceManager();

    // 数据存储
    IRenderDataStoreManager& GetRenderDataStoreManager();

    // 共享管理（用于节点间传递数据）
    IRenderNodeGraphShareManager& GetRenderNodeGraphShareManager();

    // 获取配置数据
    RenderNodeGraphData GetRenderNodeGraphData();
};
```

---

## 五、完整流程图

```
┌─────────────────────────────────────────────────────────────────┐
│ Phase 1: 插件注册                                                  │
│   StaticPlugin::Register()                                        │
│       ↓                                                           │
│   FillRenderNodeTypeInfo() 填充节点信息                            │
│       ↓                                                           │
│   RenderNodeManager::RegisterRenderNode() 注册到 factories_       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Phase 2: 批量创建                                                  │
│   RenderNodeGraphManager::PendingCreate()                        │
│       ↓                                                           │
│   解析 .rng 配置文件                                               │
│       ↓                                                           │
│   遍历 nodes 数组，根据 typeName 调用工厂创建                       │
│       ↓                                                           │
│   存储到 RenderNodeGraphNodeStore                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Phase 3: 统一初始化                                                │
│   Renderer::InitNodeGraphs()                                      │
│       ↓                                                           │
│   为每个节点创建 IRenderNodeContextManager                         │
│       ↓                                                           │
│   依次调用 node->InitNode(contextManager)                         │
│       ↓                                                           │
│   节点创建 GPU 资源、注册输出句柄                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Phase 4: 每帧执行                                                  │
│   Renderer::RenderFrame()                                         │
│       ↓                                                           │
│   按 .rng 配置顺序遍历节点                                          │
│       ↓                                                           │
│   node->PreExecuteFrame() (可选)                                  │
│       ↓                                                           │
│   node->ExecuteFrame(cmdList)                                     │
│       ↓                                                           │
│   通过 DataStore/ShareManager 传递数据                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 六、关键文件汇总

| 功能 | 文件路径 |
|------|----------|
| 工厂注册与管理 | `nativerender/LumeRender/src/nodecontext/render_node_manager.cpp` |
| 批量创建逻辑 | `nativerender/LumeRender/src/nodecontext/render_node_graph_manager.cpp` |
| 初始化与执行 | `nativerender/LumeRender/src/renderer.cpp` |
| 静态插件注册 | `nativerender/Lume_3D/src/plugin/static_plugin.cpp` |
| 渲染节点图配置 | `nativerender/Lume_3D/assets/3d/rendernodegraphs/core3d_rng_scene.rng` |
| 节点上下文接口 | `nativerender/LumeRender/api/render/nodecontext/intf_render_node_context_manager.h` |

---

## 七、总结

### 创建方式

| 问题 | 答案 |
|------|------|
| 是否批量创建？ | **是**，通过 `.rng` 配置文件一次性创建所有节点 |
| 创建逻辑位置？ | `RenderNodeGraphManager::PendingCreate()` |
| 创建时机？ | 渲染器初始化阶段 |

### 链接方式

| 问题 | 答案 |
|------|------|
| 如何链接？ | **不使用指针链接**，通过配置文件定义执行顺序 |
| 上下级关联？ | 通过 `ShareManager` 注册/获取输出句柄 |
| 数据传递？ | 通过 `DataStore` 持久化共享数据 |

### 设计优势

1. **解耦:** 节点不直接依赖其他节点，只依赖数据和配置
2. **灵活:** 通过修改 `.rng` 配置可以调整渲染管线
3. **可扩展:** 新增节点只需注册工厂并添加配置
4. **可测试:** 单个节点可以独立测试其输入输出

---

## 八、GPU 资源创建机制详解

### 8.1 调用链路概览

```
RenderNodeDefaultLights::InitNode()
    ↓
renderNodeContextMgr_->GetGpuResourceManager()  // 获取 RenderNodeGpuResourceManager
    ↓
gpuResourceMgr.Create(bufferName, desc)         // 创建 GPU Buffer
    ↓
GpuResourceManager::Create(name, desc)           // 全局资源管理器
    ↓
CreateBuffer(name, {}, desc)                     // 内部创建方法
    ↓
StoreAllocation(store, info)                     // 存储分配信息
    ↓
[延迟创建] HandlePendingAllocations()           // 在渲染帧开始时实际创建
    ↓
Device::CreateGpuBuffer(desc)                    // 后端设备创建
    ↓
glGenBuffers() + glBufferStorageEXT/glBufferData() // OpenGL ES API 调用
```

### 8.2 资源存储架构

**核心数据结构:** `PerManagerStore`

```cpp
// 文件: nativerender/LumeRender/src/device/gpu_resource_manager.h

struct PerManagerStore {
    const RenderHandleType handleType { RenderHandleType::UNDEFINED };
    GpuResourceManagerBase* mgr { nullptr };

    // 客户端访问锁
    mutable std::shared_mutex clientMutex {};

    // 名称到索引的映射（用于命名资源查找）
    BASE_NS::unordered_map<BASE_NS::string, uint32_t> nameToClientIndex {};

    // 资源描述符数组（按 RenderHandle 索引访问）
    BASE_NS::vector<ResourceDescriptor> descriptions {};

    // 客户端句柄数组（智能指针，自动引用计数）
    BASE_NS::vector<RenderHandleReference> clientHandles {};

    // 额外数据（指向 GPU 资源的指针）
    BASE_NS::vector<AdditionalData> additionalData {};

    // 可复用的句柄 ID 池
    BASE_NS::vector<uint64_t> availableHandleIds {};

    // 待处理的分配/释放操作
    PendingData pendingData {};

    // GPU 端句柄数组（实际 GPU 资源索引）
    BASE_NS::vector<EngineResourceHandle> gpuHandles {};
};

// 三个独立的资源存储
PerManagerStore bufferStore_ { RenderHandleType::GPU_BUFFER };
PerManagerStore imageStore_ { RenderHandleType::GPU_IMAGE };
PerManagerStore samplerStore_ { RenderHandleType::GPU_SAMPLER };
```

### 8.3 资源创建流程详解

#### Phase 1: Create 调用（用户调用）

```cpp
// 文件: nativerender/LumeRender/src/device/gpu_resource_manager.cpp

RenderHandleReference GpuResourceManager::Create(
    const string_view name, const GpuBufferDesc& desc)
{
    RenderHandleReference handle;

    // 1. 验证和修正描述符
    GpuBufferDesc validDesc = GetValidGpuBufferDesc(desc);
    CheckAndEnableMemoryOptimizations(gpuResourceMgrFlags_, validDesc);

    // 2. 立即创建模式：激活设备
    if (desc.engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_CREATE_IMMEDIATE) {
        device_.Activate();
    }

    PerManagerStore& store = bufferStore_;
    {
        // 3. 加锁保护
        const auto lock = std::lock_guard(store.clientMutex);

        // 4. 调用内部创建方法
        handle = CreateBuffer(name, {}, validDesc).handle;
    }

    // 5. 立即创建模式：停用设备
    if (desc.engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_CREATE_IMMEDIATE) {
        device_.Deactivate();
    }
    return handle;
}
```

#### Phase 2: CreateBuffer 内部创建

```cpp
GpuResourceManager::StoreAllocationData GpuResourceManager::CreateBuffer(
    const string_view name, const RenderHandle& replacedHandle, const GpuBufferDesc& desc)
{
    // 1. 验证描述符
    ValidateGpuBufferDesc(desc);

    // 2. 根据后端类型添加额外的内存属性标志
    MemoryPropertyFlags additionalMemPropFlags = 0U;
    if (device_.GetBackendType() == DeviceBackendType::VULKAN) {
        additionalMemPropFlags = (desc.engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_MAP_OUTSIDE_RENDERER)
                                     ? CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT : 0U;
    } else { // GLES
        additionalMemPropFlags = (desc.engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_MAP_OUTSIDE_RENDERER)
                                     ? (CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT | CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT)
                                     : 0U;
    }

    // 3. 构建验证后的描述符
    const GpuBufferDesc validatedDesc {
        desc.usageFlags | defaultBufferUsageFlags_,
        desc.memoryPropertyFlags | additionalMemPropFlags,
        desc.engineCreationFlags,
        Math::max(desc.byteSize, 1u),
        desc.format,
    };

    PerManagerStore& store = bufferStore_;

    // 4. 立即创建模式：直接创建 GPU 资源
    if (validatedDesc.engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_CREATE_IMMEDIATE) {
        // 在锁保护下创建实际的 GPU Buffer
        if (unique_ptr<GpuBuffer> gpuBuffer = device_.CreateGpuBuffer(validatedDesc)) {
            store.pendingData.buffers.push_back(move(gpuBuffer));
        }

        // 存储分配信息
        StoreAllocationData sad = StoreAllocation(store, { ResourceDescriptor { validatedDesc }, name, replacedHandle,
                                                             RenderHandleType::GPU_BUFFER, optionalResourceIndex, 0u });

        // 设置额外数据指针
        const uint32_t arrayIndex = RenderHandleUtil::GetIndexPart(sad.handle.GetHandle());
        store.additionalData[arrayIndex].resourcePtr = reinterpret_cast<uintptr_t>(buffer);
        return sad;
    } else {
        // 5. 延迟创建模式：仅存储分配请求
        return StoreAllocation(store, { ResourceDescriptor { validatedDesc }, name, replacedHandle,
                                          RenderHandleType::GPU_BUFFER, ~0u, 0u });
    }
}
```

#### Phase 3: StoreAllocation 存储分配信息

```cpp
GpuResourceManager::StoreAllocationData GpuResourceManager::StoreAllocation(
    PerManagerStore& store, const StoreAllocationInfo& info)
{
    StoreAllocationData data;

    const uint32_t replaceArrayIndex = RenderHandleUtil::GetIndexPart(info.replacedHandle);
    bool hasReplaceHandle = (replaceArrayIndex < (uint32_t)store.clientHandles.size());
    uint32_t hasNameId = (!info.name.empty()) ? 1u : 0u;

    // 情况 1: 替换现有句柄
    if (hasReplaceHandle) {
        data.handle = store.clientHandles[replaceArrayIndex];
        hasNameId = RenderHandleUtil::GetHasNamePart(data.handle.GetHandle());
        if (RenderHandleUtil::IsValid(data.handle.GetHandle())) {
            // 复用引用计数对象，创建新句柄（增加代数）
            data.handle = RenderHandleReference(
                CreateClientHandle(info.type, info.descriptor, data.handle.GetHandle().id, hasNameId, info.addHandleFlags),
                data.handle.GetCounter());
        }
    }
    // 情况 2: 通过名称查找或创建
    else if (hasNameId != 0u) {
        if (auto const iter = store.nameToClientIndex.find(info.name); iter != store.nameToClientIndex.cend()) {
            // 名称已存在，替换
            data.handle = store.clientHandles[iter->second];
            data.handle = RenderHandleReference(
                CreateClientHandle(info.type, info.descriptor, data.handle.GetHandle().id, hasNameId, info.addHandleFlags),
                data.handle.GetCounter());
        } else {
            // 名称不存在，创建新句柄
            const uint64_t handleId = GetNextAvailableHandleId(store);
            data.handle = RenderHandleReference(
                CreateClientHandle(info.type, info.descriptor, handleId, hasNameId, info.addHandleFlags),
                IRenderReferenceCounter::Ptr(new RenderReferenceCounter()));
            store.nameToClientIndex[info.name] = RenderHandleUtil::GetIndexPart(data.handle.GetHandle());
        }
    }
    // 情况 3: 创建匿名句柄
    else {
        const uint64_t handleId = GetNextAvailableHandleId(store);
        data.handle = RenderHandleReference(
            CreateClientHandle(info.type, info.descriptor, handleId, hasNameId, info.addHandleFlags),
            IRenderReferenceCounter::Ptr(new RenderReferenceCounter()));
    }

    // 存储到数组
    const uint32_t arrayIndex = RenderHandleUtil::GetIndexPart(data.handle.GetHandle());
    if (arrayIndex >= (uint32_t)store.clientHandles.size()) {
        store.clientHandles.push_back(data.handle);
        store.descriptions.push_back(info.descriptor);
        store.additionalData.push_back({});
        store.gpuHandles.push_back({});
    } else {
        store.clientHandles[arrayIndex] = data.handle;
        store.descriptions[arrayIndex] = info.descriptor;
    }

    // 添加到待处理分配列表
    const uint32_t allocationIndex = (uint32_t)store.pendingData.allocations.size();
    store.pendingData.allocations.push_back(
        OperationDescription(data.handle.GetHandle(), info.descriptor, AllocType::ALLOC, info.optResourceIndex));
    store.additionalData[arrayIndex].indexToPendingData = allocationIndex;

    return data;
}
```

#### Phase 4: HandlePendingAllocations 实际创建 GPU 资源

```cpp
// 文件: nativerender/LumeRender/src/renderer.cpp
// 在每帧渲染开始时调用

void GpuResourceManager::HandlePendingAllocations(const bool allowDestruction)
{
    HandlePendingAllocationsImpl(false, allowDestruction);
}

void GpuResourceManager::HandlePendingAllocationsImpl(const bool isFrameEnd, const bool allowDestruction)
{
    // 处理三种类型的资源存储
    HandleStorePendingAllocations(isFrameEnd, allowDestruction, bufferStore_);
    HandleStorePendingAllocations(isFrameEnd, allowDestruction, imageStore_);
    HandleStorePendingAllocations(isFrameEnd, allowDestruction, samplerStore_);
}

void GpuResourceManager::HandleStorePendingAllocations(
    const bool isFrameEnd, const bool allowDestruction, PerManagerStore& store)
{
    // 1. 获取待处理数据（移动语义）
    const PendingData pendingData = CommitPendingData(store);

    // 2. 加锁保护分配过程
    allocationMutex_.lock();
    store.clientMutex.lock();

    // 3. 遍历所有待处理操作
    for (const auto& allocation : pendingData.allocations) {
        const uint32_t arrayIndex = RenderHandleUtil::GetIndexPart(allocation.handle);

        if (allocation.allocType == AllocType::ALLOC) {
            // 创建 GPU 资源
            CreateGpuResource(allocation, arrayIndex, store.handleType, (uintptr_t)&pendingData.buffers);
            // 更新 GPU 句柄
            store.HandleAlloc(arrayIndex, allocation);
        } else if (allocation.allocType == AllocType::DEALLOC) {
            // 销毁 GPU 资源
            if (store.HandleDealloc(arrayIndex, allocation, isFrameEnd, allowDestruction)) {
                DestroyGpuResource(allocation, arrayIndex, store.handleType, store);
            }
        }
    }

    // 4. 解锁
    store.clientMutex.unlock();
    allocationMutex_.unlock();
}
```

#### Phase 5: CreateGpuResource 创建底层资源

```cpp
void GpuResourceManager::CreateGpuResource(const OperationDescription& op, const uint32_t arrayIndex,
    const RenderHandleType resourceType, const uintptr_t preCreatedResVec)
{
    if (resourceType == RenderHandleType::GPU_BUFFER) {
        if (op.optionalResourceIndex != ~0u) {
            // 使用预先创建的资源（立即创建模式）
            BufferVector& res = *(reinterpret_cast<BufferVector*>(preCreatedResVec));
            gpuBufferMgr_->Create(arrayIndex, op.descriptor.combinedBufDescriptor.bufferDesc,
                                   move(res[op.optionalResourceIndex]), false, op.descriptor.combinedBufDescriptor);
        } else {
            // 延迟创建：现在创建
            gpuBufferMgr_->Create(arrayIndex, op.descriptor.combinedBufDescriptor.bufferDesc,
                                   {}, false, op.descriptor.combinedBufDescriptor);
        }
    }
    // ... GPU_IMAGE 和 GPU_SAMPLER 类似
}
```

### 8.4 OpenGL ES 后端实现

**文件:** `nativerender/LumeRender/src/gles/gpu_buffer_gles.cpp`

```cpp
GpuBufferGLES::GpuBufferGLES(Device& device, const GpuBufferDesc& desc)
    : device_((DeviceGLES&)device), plat_({ {}, 0u, 0u, desc.byteSize, 0u, desc.byteSize }), desc_(desc),
      isPersistantlyMapped_((desc.memoryPropertyFlags & CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT) &&
                            (desc.memoryPropertyFlags & CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT)),
      isMappable_(IS_BIT(desc.memoryPropertyFlags, CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT))
{
    // 1. 生成 OpenGL 缓冲区对象
    glGenBuffers(1, &plat_.buffer);

    // 2. 计算 Uniform Buffer 对齐
    GLint minAlignment = sizeof(float) * 4u;
    glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, &minAlignment);
    plat_.alignedBindByteSize = ((plat_.bindMemoryByteSize + (minAlignment - 1)) / minAlignment) * minAlignment;
    plat_.alignedByteSize = plat_.alignedBindByteSize;

    // 3. 环形缓冲区：扩大到帧数倍
    if (desc.engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_DYNAMIC_RING_BUFFER) {
        isRingBuffer_ = true;
        plat_.alignedByteSize *= device_.GetCommandBufferingCount();
    }

    // 4. 绑定缓冲区
    const auto oldBind = device_.BoundBuffer(GL_COPY_WRITE_BUFFER);
    device_.BindBuffer(GL_COPY_WRITE_BUFFER, plat_.buffer);

    // 5. 分配存储（优先使用 glBufferStorageEXT）
    const bool hasBufferStorageEXT = device_.HasExtension("GL_EXT_buffer_storage") && (glBufferStorageEXT != nullptr);
    if (hasBufferStorageEXT) {
        // 现代路径：使用 glBufferStorageEXT（不可变存储）
        uint32_t flags = MakeFlags(desc.memoryPropertyFlags);
        glBufferStorageEXT(GL_COPY_WRITE_BUFFER, plat_.alignedByteSize, nullptr, flags);

        // 持久映射（HOST_VISIBLE + HOST_COHERENT）
        if (isPersistantlyMapped_) {
            flags = flags & (~GL_CLIENT_STORAGE_BIT_EXT);
            data_ = glMapBufferRange(GL_COPY_WRITE_BUFFER, 0, plat_.alignedByteSize, flags);
        }
    } else {
        // 传统路径：使用 glBufferData（可变存储）
        if (desc_.engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_SINGLE_SHOT_STAGING) {
            glBufferData(GL_COPY_WRITE_BUFFER, plat_.alignedByteSize, nullptr, GL_STREAM_DRAW);
        } else if (isMappable_) {
            glBufferData(GL_COPY_WRITE_BUFFER, plat_.alignedByteSize, nullptr, GL_DYNAMIC_DRAW);
        } else {
            glBufferData(GL_COPY_WRITE_BUFFER, plat_.alignedByteSize, nullptr, GL_STATIC_DRAW);
        }
    }

    device_.BindBuffer(GL_COPY_WRITE_BUFFER, oldBind);
}
```

**MakeFlags 标志转换：**

```cpp
constexpr uint32_t MakeFlags(uint32_t requiredFlags)
{
    uint32_t flags = 0;
    if ((requiredFlags & CORE_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) == 0) {
        flags |= GL_CLIENT_STORAGE_BIT_EXT;  // 允许 CPU 端存储
    }
    if (requiredFlags & CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT) {
        flags |= GL_MAP_WRITE_BIT;  // 可写入映射
    }
    if (requiredFlags & CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT) {
        flags |= GL_MAP_COHERENT_BIT_EXT;  // 无需刷新
    }
    if (flags & GL_MAP_COHERENT_BIT_EXT) {
        flags |= GL_MAP_PERSISTENT_BIT_EXT;  // 必须配对
        flags |= GL_MAP_WRITE_BIT;  // 必须配对
    }
    return flags;
}
```

### 8.5 资源使用方式

#### 映射缓冲区（写入数据）

```cpp
// 文件: nativerender/LumeRender/src/device/gpu_resource_manager.cpp

void* GpuResourceManager::MapBuffer(const RenderHandleReference& handle) const
{
    const EngineResourceHandle gpuHandle = GetGpuHandle(handle.GetHandle());
    if (GpuBuffer* buffer = GetBuffer(gpuHandle)) {
        return buffer->Map();  // 调用 GpuBufferGLES::Map()
    }
    return nullptr;
}

// GpuBufferGLES::Map() 实现
void* GpuBufferGLES::Map()
{
    if (isPersistantlyMapped_) {
        // 持久映射：直接返回指针
        return data_ + plat_.currentByteOffset;
    } else if (isMappable_) {
        // 普通映射：每次映射
        glBindBuffer(GL_COPY_WRITE_BUFFER, plat_.buffer);
        return glMapBufferRange(GL_COPY_WRITE_BUFFER, plat_.currentByteOffset,
                                 plat_.bindMemoryByteSize, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
    }
    return nullptr;
}
```

#### 环形缓冲区偏移更新

```cpp
// RenderNodeGpuResourceManager::MapBuffer()
void* RenderNodeGpuResourceManager::MapBuffer(const RenderHandle& handle) const
{
    // 获取 GPU Buffer 对象
    GpuBuffer* buffer = gpuResourceMgr_.GetBuffer(gpuHandle);

    // 环形缓冲区：自动推进偏移
    if (buffer->GetDesc().engineCreationFlags & CORE_ENGINE_BUFFER_CREATION_DYNAMIC_RING_BUFFER) {
        // 每帧推进到下一个区域
        // frameIndex % bufferingCount 决定当前使用哪块区域
    }

    return buffer->Map();
}
```

### 8.6 句柄结构解析

**RenderHandle 结构（64位）：**

```
┌─────────────────────────────────────────────────────────────────┐
│  63-48: 附加标志位 (RenderHandleInfoFlags)                        │
│  47-32: 代数计数 (Generation) - 用于验证句柄有效性                  │
│  31-16: 类型 (RenderHandleType) - GPU_BUFFER/GPU_IMAGE/GPU_SAMPLER│
│  15-0:  数组索引 (Index) - 在 clientHandles 数组中的位置           │
└─────────────────────────────────────────────────────────────────┘
```

**EngineResourceHandle 结构（64位）：**

```
┌─────────────────────────────────────────────────────────────────┐
│  47-32: 代数计数 (Generation)                                     │
│  31-16: 类型 (RenderHandleType)                                   │
│  15-0:  GPU 端数组索引 - 在 gpuHandles 数组中的位置                │
└─────────────────────────────────────────────────────────────────┘
```

### 8.7 完整流程图

```
┌─────────────────────────────────────────────────────────────────┐
│ 用户调用: gpuResourceMgr.Create(name, desc)                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ GpuResourceManager::Create()                                     │
│   - 验证描述符                                                     │
│   - 加锁保护                                                       │
│   - 调用 CreateBuffer()                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ CreateBuffer()                                                   │
│   - 构建 validatedDesc                                            │
│   - 立即创建: Device::CreateGpuBuffer() → 存入 pendingData       │
│   - 延迟创建: 仅存储描述符                                         │
│   - 调用 StoreAllocation()                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ StoreAllocation()                                                │
│   - 查找/创建 RenderHandle                                        │
│   - 存储到 clientHandles 数组                                     │
│   - 存储描述符到 descriptions 数组                                │
│   - 添加操作到 pendingData.allocations                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ 返回 RenderHandleReference（智能指针，自动引用计数）               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ [渲染帧开始时] Renderer::RenderFrame()                            │
│   → GpuResourceManager::HandlePendingAllocations()               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ HandlePendingAllocations()                                       │
│   - 遍历 pendingData.allocations                                 │
│   - CreateGpuResource() 创建实际 GPU 资源                         │
│   - 更新 gpuHandles 数组                                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ CreateGpuResource()                                              │
│   - gpuBufferMgr_->Create() 调用后端创建                          │
│   - DeviceGLES::CreateGpuBuffer()                                │
│   - GpuBufferGLES 构造函数                                        │
│     - glGenBuffers() 生成缓冲区对象                               │
│     - glBufferStorageEXT() 或 glBufferData() 分配内存             │
│     - glMapBufferRange() 持久映射（可选）                          │
└─────────────────────────────────────────────────────────────────┘
```

### 8.8 关键文件汇总

| 功能 | 文件路径 |
|------|----------|
| GPU 资源管理器接口 | `nativerender/LumeRender/api/render/device/intf_gpu_resource_manager.h` |
| GPU 资源管理器实现 | `nativerender/LumeRender/src/device/gpu_resource_manager.cpp` |
| GPU Buffer 抽象基类 | `nativerender/LumeRender/src/device/gpu_buffer.h` |
| GPU Buffer GLES 实现 | `nativerender/LumeRender/src/gles/gpu_buffer_gles.cpp` |
| 渲染节点 GPU 资源管理器 | `nativerender/LumeRender/src/device/gpu_resource_manager.h:640` |
| 句柄工具类 | `nativerender/LumeRender/src/device/gpu_resource_handle_util.h` |