# RenderSystem 与渲染后端绑定机制深度分析

**文档版本**: 1.1
**创建日期**: 2026 年 4 月 7 日
**更新日期**: 2026 年 4 月 7 日

---

## 1. 核心问题

**用户问题**: RenderSystem 是被 ECS 持有的，但是只有一个渲染后端，它怎么选择渲染哪个 ECS？

---

## 1.1 关键结论：ECS 切换渲染场景

**重要发现**：在所有 ECS 都已初始化完成后，**只需修改 `CollectRenderHandles()` 中的 `ecs_` 即可切换渲染场景**。

```cpp
// 前提：每个 ECS 都已初始化
auto ecs1 = engine_->CreateEcs();
LoadSystemGraph(ecs1, "render_system.json");
engine_->TickFrame([ecs1]);  // RenderSystem 已创建 RenderNodeGraph

auto ecs2 = engine_->CreateEcs();
LoadSystemGraph(ecs2, "render_system.json");
engine_->TickFrame([ecs2]);  // RenderSystem 已创建 RenderNodeGraph

// 切换渲染：只需修改 ecs_
lumeCommon->ecs_ = ecs1;
CollectRenderHandles();  // 获取 handle1
RenderFrame([handle1]);  // 渲染场景 1

lumeCommon->ecs_ = ecs2;
CollectRenderHandles();  // 获取 handle2
RenderFrame([handle2]);  // 渲染场景 2
```

**原理**：
1. `TickFrame()` 时 `RenderSystem::Update()` 已创建并缓存 `RenderNodeGraph`
2. `GetRenderNodeGraphs()` 只返回缓存的句柄，不创建新的
3. `CollectRenderHandles()` 中的 `ecs_` 决定从哪个 ECS 获取句柄
4. `RenderFrame()` 执行句柄对应的 `RenderNodeGraph`

**注意事项**：
- 场景变化后需要重新调用 `TickFrame()` 更新 RenderSystem
- `customRender_` 存在时会提前返回，需要修改不提前返回
- ⚠️ **Component Managers 不会自动切换** - 它们仍然指向原来的 ECS

---

## 1.2 重要警告：Component Managers 不会自动切换

**严重问题**：`LumeCommon` 持有的 Component Manager 指针（如 `cameraManager_`, `transformManager_` 等）**在切换 `ecs_` 时不会自动更新**！

```cpp
class LumeCommon {
    // 这些指针在 LoadSystemGraph 时从 ecs_ 获取
    CORE3D_NS::ITransformComponentManager* transformManager_;
    CORE3D_NS::ICameraComponentManager* cameraManager_;
    CORE3D_NS::IRenderConfigurationComponentManager* sceneManager_;
    CORE3D_NS::ILightComponentManager* lightManager_;
    CORE3D_NS::IPostProcessComponentManager* postprocessManager_;
    
    // 获取方式（在 LoadSystemGraph 中）
    void LoadSystemGraph(BASE_NS::string sysGraph) {
        auto& ecs = *ecs_;  // ← 使用当前的 ecs_
        
        transformManager_ = CORE_NS::GetManager<CORE3D_NS::ITransformComponentManager>(ecs);
        cameraManager_ = CORE_NS::GetManager<CORE3D_NS::ICameraComponentManager>(ecs);
        // ... 其他 managers
        
        // ⚠️ 这些指针之后不会自动更新！
    }
};

// 问题演示
auto ecs1 = engine_->CreateEcs();
LoadSystemGraph(ecs1, "...");  // cameraManager_ = ecs1 的 CameraManager

auto ecs2 = engine_->CreateEcs();
LoadSystemGraph(ecs2, "...");  // cameraManager_ = ecs2 的 CameraManager

// 切换 ecs_
lumeCommon->ecs_ = ecs1;
CollectRenderHandles();  // ← 从 ecs1 获取 RenderHandles
RenderFrame();           // ← 渲染 ecs1 的场景

// 但是如果你调用了使用 cameraManager_ 的方法：
SetupCameraTransform(...);  // ⚠️ 修改的是 ecs2 的相机！（因为 cameraManager_ 还指向 ecs2）
```

**影响范围**：

| 方法 | 使用的 Manager | 影响 |
|------|---------------|------|
| `SetupCameraTransform()` | `cameraManager_`, `transformManager_` | 修改错误的 ECS 的相机 |
| `SetupCameraViewPort()` | `cameraManager_` | 修改错误的 ECS 的相机 |
| `LoadEnvModel()` | `sceneManager_`, `lightManager_` | 修改错误的 ECS 的环境 |
| `UpdateLights()` | `lightManager_`, `transformManager_` | 修改错误的 ECS 的灯光 |
| `CreateScene()` | `sceneManager_`, `nodeSystem_` | 在错误的 ECS 创建场景 |

**解决方案**：

### 方案 1: 每次切换 ecs_ 后重新获取 Managers

```cpp
void LumeCommon::SwitchEcs(uint64_t ecsId)
{
    auto it = ecsMap_.find(ecsId);
    if (it == ecsMap_.end()) {
        return;
    }
    
    ecs_ = it->second;
    
    // 重新获取 Component Managers
    auto& ecs = *ecs_;
    transformManager_ = CORE_NS::GetManager<CORE3D_NS::ITransformComponentManager>(ecs);
    cameraManager_ = CORE_NS::GetManager<CORE3D_NS::ICameraComponentManager>(ecs);
    sceneManager_ = CORE_NS::GetManager<CORE3D_NS::IRenderConfigurationComponentManager>(ecs);
    lightManager_ = CORE_NS::GetManager<CORE3D_NS::ILightComponentManager>(ecs);
    postprocessManager_ = CORE_NS::GetManager<CORE3D_NS::IPostProcessComponentManager>(ecs);
    // ...
}
```

### 方案 2: 延迟获取 Managers（推荐）

```cpp
// 不存储 Manager 指针，使用时动态获取
CORE3D_NS::ICameraComponentManager* LumeCommon::GetCameraManager() const
{
    if (!ecs_) {
        return nullptr;
    }
    return CORE_NS::GetManager<CORE3D_NS::ICameraComponentManager>(*ecs_);
}

// 使用时代替直接访问成员
void LumeCommon::SetupCameraTransform(...)
{
    auto* camMgr = GetCameraManager();  // ← 动态获取
    if (camMgr) {
        auto cameraHandle = camMgr->Write(cameraEntity_);
        // ...
    }
}
```

### 方案 3: 限制使用场景

如果满足以下条件，可以**不处理**这个问题：

1. **只读操作** - 不调用修改 Component 的方法
2. **渲染后不修改** - 只渲染，不修改场景内容
3. **单 ECS 渲染** - 不同时渲染多个 ECS

```cpp
// ✅ 安全的使用方式
lumeCommon->ecs_ = ecs1;
CollectRenderHandles();
RenderFrame();  // ← 只读渲染，没问题

lumeCommon->ecs_ = ecs2;
CollectRenderHandles();
RenderFrame();  // ← 只读渲染，没问题

// ❌ 不安全的使用方式
lumeCommon->ecs_ = ecs1;
SetupCameraTransform(...);  // ⚠️ 修改的是错误的 ECS！
```

---

---

## 2. 关键发现

### 2.1 架构层次

```
┌─────────────────────────────────────────────────────────────────┐
│  应用层 (LumeCommon)                                             │
│                                                                  │
│  void LumeCommon::DrawFrame()                                    │
│  {                                                               │
│      // 1. TickFrame 更新 ECS                                   │
│      engine_->TickFrame([ecs1, ecs2, ecs3]);                    │
│                                                                  │
│      // 2. 收集 RenderHandle                                    │
│      CollectRenderHandles();                                     │
│                                                                  │
│      // 3. 提交渲染 (只有一个后端)                               │
│      GetRenderContext()->GetRenderer().RenderFrame(handles);    │
│  }                                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ECS 层 (每个 ECS 独立)                                           │
│                                                                  │
│  ECS1                    ECS2                    ECS3           │
│  ├─ RenderSystem1        ├─ RenderSystem2        ├─ RenderSystem3
│  │  └─ Update()          │  └─ Update()          │  └─ Update() 
│  │      ↓                │      ↓                │      ↓       
│  │  收集场景数据         │  收集场景数据         │  收集场景数据  
│  └─ GetRenderNodeGraphs()└─ GetRenderNodeGraphs()└─ GetRenderNodeGraphs()
│         │                       │                       │
│         └───────────────────────┼───────────────────────┘
│                                 ▼
│                    返回 RenderHandleReference[]
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  渲染后端层 (唯一)                                               │
│                                                                  │
│  IRenderContext::GetRenderer()                                   │
│  └─> IRenderer::RenderFrame(renderHandles[])                    │
│      │                                                           │
│      ├─→ 遍历所有 RenderHandle                                  │
│      ├─→ 执行 RenderNodeGraph                                    │
│      └─→ 提交到 GPU                                              │
│                                                                  │
│  注意：只有一个渲染后端，但它可以执行多个 RenderNodeGraph          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 详细机制分析

### 3.1 RenderSystem 在 ECS 中的角色

```cpp
// 每个 ECS 有自己的 RenderSystem 实例
class RenderSystem : public IRenderSystem {
    // 每个 RenderSystem 持有对其所属 ECS 的引用
    CORE_NS::IEcs& ecs_;
    
    // Component Managers (从 ECS 获取)
    ICameraComponentManager* cameraMgr_;
    ILightComponentManager* lightMgr_;
    IRenderMeshComponentManager* renderMeshMgr_;
    // ...
    
    // 渲染数据缓存
    BASE_NS::vector<RenderHandleReference> renderNodeGraphs_;
};

// ECS 创建时加载 RenderSystem
void LumeCommon::LoadSystemGraph(uint32_t key)
{
    auto& ecs = *ecs_;
    
    // 加载系统图到 ECS
    systemGraphLoader->Load(sysGraph, ecs);
    // ↑ 这会在 ECS 中创建 RenderSystem 实例
    
    // 获取 RenderSystem (从 ECS)
    auto* renderSystem = CORE_NS::GetSystem<IRenderSystem>(ecs);
}
```

### 3.2 RenderSystem 如何收集渲染数据

```cpp
// RenderSystem::Update() - 在 TickFrame 时被调用
bool RenderSystem::Update(bool frameRenderingQueued, uint64_t totalTime, uint64_t deltaTime)
{
    // 1. 检查变化
    if (!hasChanges) {
        return false;  // 无需重新渲染
    }
    
    // 2. 获取场景数据 (从 ECS 的 Component)
    FetchFullScene();
    
    // 3. 处理场景
    ProcessScene();
    ProcessCameras();
    ProcessLights();
    ProcessMeshes();
    
    // 4. 创建/更新 RenderNodeGraph
    //    (RenderNodeGraph 是渲染后端的输入)
    CreateRenderNodeGraphs();
    
    return true;  // 需要渲染
}

// RenderSystem::GetRenderNodeGraphs() - 返回渲染句柄
BASE_NS::array_view<const RENDER_NS::RenderHandleReference> 
RenderSystem::GetRenderNodeGraphs() const
{
    // 返回之前创建的 RenderNodeGraph 句柄
    return renderNodeGraphs_;
}
```

### 3.3 LumeCommon 如何收集多个 ECS 的渲染数据

```cpp
// 当前实现：只收集一个 ECS
void LumeCommon::CollectRenderHandles()
{
    renderHandles_.clear();
    
    // 从自定义渲染收集
    if (customRender_) {
        auto rngs = customRender_->GetRenderHandles();
        renderHandles_.insert(renderHandles_.end(), rngs.begin(), rngs.end());
        return;  // ← 提前返回，不收集 ECS 的
    }
    
    // 从当前 ECS 收集
    auto* ecs = ecs_.get();
    BASE_NS::array_view<const RENDER_NS::RenderHandleReference> main = 
        GetGraphicsContext()->GetRenderNodeGraphs(*ecs);  // ← 只从一个 ECS 收集
    
    renderHandles_.insert(renderHandles_.end(), main.begin(), main.end());
}

// 多 ECS 版本 (DrawMultiEcs 中的实现)
void LumeCommon::DrawMultiEcs(const std::unordered_map<void*, void*>& ecss)
{
    BASE_NS::vector<RENDER_NS::RenderHandleReference> handles;
    BASE_NS::vector<CORE_NS::IEcs*> ecsInputs;
    
    // 遍历所有 ECS
    for (auto& key : ecss) {
        CORE_NS::IEcs* ecs = reinterpret_cast<CORE_NS::IEcs*>(key.first);
        ecsInputs.push_back(ecs);
        
        // 从每个 ECS 收集渲染句柄
        BASE_NS::vector<RENDER_NS::RenderHandleReference>* dirty = 
            reinterpret_cast<BASE_NS::vector<RENDER_NS::RenderHandleReference>*>(key.second);
        handles.insert(handles.end(), dirty->begin(), dirty->end());
    }
    
    // 更新所有 ECS
    if (engine_->TickFrame(BASE_NS::array_view(ecsInputs.data(), ecsInputs.size()))) {
        // 统一渲染所有句柄
        GetRenderContext()->GetRenderer().RenderFrame(
            BASE_NS::array_view(handles.data(), handles.size()));
    }
}
```

### 3.4 渲染后端如何处理多个 RenderNodeGraph

```cpp
// IRenderer::RenderFrame 实现
void Renderer::RenderFrame(array_view<RenderHandleReference> renderHandles)
{
    // 1. 开始帧
    BeginFrame();
    
    // 2. 遍历所有 RenderHandle
    for (RenderHandleReference handle : renderHandles) {
        // 每个 handle 对应一个 RenderNodeGraph
        // RenderNodeGraph 可能来自不同的 ECS
        
        // 3. 执行 RenderNodeGraph
        ExecuteRenderNodeGraph(handle);
        // ↑ 这会：
        //   - 绑定对应的 GPU 资源
        //   - 执行渲染通道 (RenderPass)
        //   - 提交到 GPU 命令缓冲区
    }
    
    // 4. 提交到 GPU
    SubmitToGPU();
    
    // 5. 呈现 (Present)
    Present();
}
```

---

## 4. 关键概念解释

### 4.1 RenderNodeGraph 是什么？

```
RenderNodeGraph = 渲染节点图 = 渲染管线的 JSON 描述文件

示例：core3d_rng_cam_scene_hdrp.rng
{
    "renderNodeGraphName": "CameraSceneHDRP",
    "renderNodes": [
        {
            "name": "GeometryPass",
            "type": "render",
            "loadOp": "clear",
            "format": "RGBA8",
            ...
        },
        {
            "name": "LightingPass",
            "type": "compute",
            ...
        },
        {
            "name": "PostProcess",
            "type": "fullscreen",
            ...
        }
    ]
}

每个 RenderSystem 在 Update() 时：
1. 读取场景数据 (相机、灯光、网格等)
2. 根据 RenderNodeGraph 定义创建 GPU 资源
3. 返回 RenderHandleReference (句柄)

渲染后端收到句柄后：
1. 根据句柄找到对应的 RenderNodeGraph
2. 执行其中定义的所有渲染节点
3. 提交到 GPU
```

### 4.2 多 ECS 渲染流程

```
帧开始
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ TickFrame([ecs1, ecs2, ecs3])                               │
│                                                              │
│ ├─ ecs1->RenderSystem::Update()                             │
│ │   ├─ 收集 ecs1 的场景数据                                   │
│ │   └─ 创建/更新 RenderNodeGraph1                           │
│ │       └─ 返回 handle1                                     │
│ │                                                           │
│ ├─ ecs2->RenderSystem::Update()                             │
│ │   ├─ 收集 ecs2 的场景数据                                   │
│ │   └─ 创建/更新 RenderNodeGraph2                           │
│ │       └─ 返回 handle2                                     │
│ │                                                           │
│ └─ ecs3->RenderSystem::Update()                             │
│     ├─ 收集 ecs3 的场景数据                                   │
│     └─ 创建/更新 RenderNodeGraph3                           │
│         └─ 返回 handle3                                     │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
handles = [handle1, handle2, handle3]
  │
  ▼
┌─────────────────────────────────────────────────────────────┐
│ RenderFrame(handles)                                        │
│                                                              │
│ ├─ ExecuteRenderNodeGraph(handle1) ← 渲染 ecs1 的场景         │
│ ├─ ExecuteRenderNodeGraph(handle2) ← 渲染 ecs2 的场景         │
│ └─ ExecuteRenderNodeGraph(handle3) ← 渲染 ecs3 的场景         │
│                                                              │
│ 注意：所有渲染都提交到同一个 GPU 命令缓冲区                    │
└─────────────────────────────────────────────────────────────┘
  │
  ▼
提交到 GPU → 显示
```

---

## 5. 回答核心问题

### Q1: RenderSystem 是被 ECS 持有的吗？

**A: 是的**。每个 ECS 有自己的 RenderSystem 实例：

```cpp
// ECS 内部结构
class IEcs {
    std::vector<ISystem*> systems_;
    
    // 创建系统时
    void AddSystem(ISystem* system) {
        systems_.push_back(system);
    }
};

// LoadSystemGraph 时创建 RenderSystem
auto* renderSystem = new RenderSystem(ecs);  // ← 传入 ECS 引用
ecs->AddSystem(renderSystem);                // ← ECS 持有 RenderSystem
```

### Q2: 只有一个渲染后端，怎么选择渲染哪个 ECS？

**A: 渲染后端不"选择"ECS，它只执行 RenderNodeGraph**

关键理解：
- **渲染后端不知道 ECS 的存在**
- **渲染后端只认 RenderHandleReference**
- **RenderSystem 是 ECS 和渲染后端之间的桥梁**

```cpp
// 渲染后端的视角
class IRenderer {
    void RenderFrame(array_view<RenderHandleReference> handles) {
        // 我不知道这些 handles 来自哪个 ECS
        // 我只负责执行它们对应的 RenderNodeGraph
        
        for (auto handle : handles) {
            ExecuteRenderNodeGraph(handle);  // ← 只认 handle，不认 ECS
        }
    }
};

// LumeCommon 的视角 (决定渲染哪些 ECS)
void LumeCommon::DrawFrame() {
    // 1. 选择要更新的 ECS
    std::vector<IEcs*> ecsToUpdate = { ecs1, ecs2 };  // ← 我选择
    engine_->TickFrame(ecsToUpdate);
    
    // 2. 从选中的 ECS 收集 RenderHandle
    CollectRenderHandles();  // 从 ecs1, ecs2 收集
    
    // 3. 提交到渲染后端
    renderer->RenderFrame(renderHandles_);  // ← 后端不知道 ECS
}
```

### Q3: 如果想切换渲染的 ECS 怎么办？

**A: 在 CollectRenderHandles 阶段选择从哪些 ECS 收集**

```cpp
// 方案 1: 修改 CollectRenderHandles 支持多 ECS
void LumeCommon::CollectRenderHandles() {
    renderHandles_.clear();
    
    // 从所有绑定的 ECS 收集
    for (uint64_t ecsId : boundEcsIds_) {
        auto* ecs = ecsMap_[ecsId].get();
        auto handles = GetGraphicsContext()->GetRenderNodeGraphs(*ecs);
        renderHandles_.insert(renderHandles_.end(), handles.begin(), handles.end());
    }
}

// 方案 2: 动态绑定/解绑 ECS
void LumeCommon::BindEcsToRender(uint64_t ecsId) {
    boundEcsIds_.push_back(ecsId);  // ← 添加到渲染列表
}

void LumeCommon::UnbindEcsFromRender(uint64_t ecsId) {
    boundEcsIds_.erase(
        std::remove(boundEcsIds_.begin(), boundEcsIds_.end(), ecsId),
        boundEcsIds_.end());  // ← 从渲染列表移除
}

// 使用示例
lumeCommon->BindEcsToRender(ecs1);   // 渲染 ecs1
lumeCommon->BindEcsToRender(ecs2);   // 渲染 ecs2
lumeCommon->UnbindEcsFromRender(ecs1); // 只渲染 ecs2
```

---

## 6. 现有代码中的多 ECS 支持证据

### 6.1 IEngine::TickFrame 支持多 ECS

```cpp
// 从 LumeCommon::DrawMultiEcs 可以看出
engine_->TickFrame(BASE_NS::array_view(ecsInputs.data(), ecsInputs.size()));
// ↑ 明确支持 ECS 数组
```

### 6.2 注释证明

```cpp
// lume_common.cpp:1210
// multi ecs needs unique DataStore name, otherwise only one RenderSystem created
// ↑ 明确说明每个 ECS 需要独立的 DataStore，否则会共享 RenderSystem
```

### 6.3 GraphicsManager 的多 ECS 支持

```cpp
// GraphicsManager::DrawFrame
void GraphicsManager::DrawFrame(void* ecs, void* renderHandles) {
    // 支持从多个 ECS 接收渲染请求
    // 内部会合并所有 handles 然后统一渲染
}
```

---

## 7. 总结

### 架构层次

| 层次 | 组件 | 数量 | 职责 |
|------|------|------|------|
| 应用层 | LumeCommon | 1 | 决定渲染哪些 ECS |
| ECS 层 | IEcs + RenderSystem | N | 每个 ECS 独立更新和收集数据 |
| 渲染后端 | IRenderer | 1 | 执行所有 RenderNodeGraph |

### 关键机制

1. **RenderSystem 属于 ECS** - 每个 ECS 有自己的 RenderSystem 实例
2. **RenderSystem 收集数据** - Update() 时从 ECS 的 Component 收集场景数据
3. **RenderSystem 创建 RenderNodeGraph** - 根据收集的数据创建渲染句柄
4. **LumeCommon 收集句柄** - 从选中的 ECS 收集 RenderHandleReference
5. **渲染后端执行** - 不关心 ECS，只执行 RenderNodeGraph

### 多 ECS 渲染的关键

```
LumeCommon (应用层)
    │
    ├─ 决定：渲染哪些 ECS
    │   └─> TickFrame([ecs1, ecs2, ...])
    │
    ├─ 收集：从选中的 ECS 收集 RenderHandle
    │   └─> CollectRenderHandles()
    │
    └─ 提交：所有 handles 到渲染后端
        └─> RenderFrame(handles)
            
渲染后端 (执行层)
    │
    ├─ 遍历：所有 handles
    │   └─> ExecuteRenderNodeGraph(handle)
    │
    └─ 提交：到 GPU
        └─> SubmitToGPU()
```

**答案**: 渲染后端不选择 ECS，它只执行 RenderNodeGraph。选择渲染哪些 ECS 的权力在 LumeCommon (应用层)，通过 `TickFrame()`和`CollectRenderHandles()` 来控制。

---

## 8. ECS 切换渲染场景完整方案

### 8.1 核心发现

**问题**：是否可以直接修改 `ecs_` 来切换渲染场景？

**答案**：**可以**！在所有 ECS 都已初始化完成后，只需修改 `CollectRenderHandles()` 中的 `ecs_` 即可切换渲染场景。

### 8.2 完整流程

```
┌─────────────────────────────────────────────────────────────┐
│ 阶段 1: 初始化 (一次性)                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ // 创建 ECS1                                                 │
│ auto ecs1 = engine_->CreateEcs();                           │
│ LoadSystemGraph(ecs1, "render_system.json");                │
│ engine_->TickFrame([ecs1]);                                 │
│   └─ RenderSystem1::Update()                                │
│      └─ 创建 RenderNodeGraph1 → 缓存为 handle1              │
│                                                              │
│ // 创建 ECS2                                                 │
│ auto ecs2 = engine_->CreateEcs();                           │
│ LoadSystemGraph(ecs2, "render_system.json");                │
│ engine_->TickFrame([ecs2]);                                 │
│   └─ RenderSystem2::Update()                                │
│      └─ 创建 RenderNodeGraph2 → 缓存为 handle2              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 阶段 2: 渲染切换 (可重复)                                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ // 渲染场景 1                                                │
│ lumeCommon->ecs_ = ecs1;                                    │
│ CollectRenderHandles();                                     │
│   └─ GetRenderNodeGraphs(*ecs1) → 返回 handle1              │
│ RenderFrame([handle1]);                                     │
│   └─ ExecuteRenderNodeGraph(handle1) ← 渲染场景 1           │
│                                                              │
│ // 渲染场景 2                                                │
│ lumeCommon->ecs_ = ecs2;                                    │
│ CollectRenderHandles();                                     │
│   └─ GetRenderNodeGraphs(*ecs2) → 返回 handle2              │
│ RenderFrame([handle2]);                                     │
│   └─ ExecuteRenderNodeGraph(handle2) ← 渲染场景 2           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 代码实现

#### 8.3.1 初始化阶段

```cpp
// 为每个场景创建独立的 ECS
std::unordered_map<std::string, CORE_NS::IEcs::Ptr> sceneEcsMap;

void InitializeScenes(const std::vector<std::string>& scenePaths)
{
    for (const auto& path : scenePaths) {
        // 1. 创建 ECS
        auto ecs = engine_->CreateEcs();
        
        // 2. 加载系统图
        LoadSystemGraph(ecs, "systems/render_system.json");
        
        // 3. 加载场景数据 (GLTF 等)
        LoadSceneToEcs(ecs, path);
        
        // 4. 初始化 RenderSystem (创建 RenderNodeGraph)
        engine_->TickFrame(BASE_NS::array_view(&ecs, 1));
        
        // 5. 存储 ECS
        sceneEcsMap[path] = ecs;
        
        LOGI("Initialized scene: %{public}s, ecsId=%{public}llu", 
             path.c_str(), ecs->GetId());
    }
}
```

#### 8.3.2 渲染切换阶段

```cpp
// 当前渲染的场景
std::string currentScene = "scene1.gltf";

void RenderLoop()
{
    while (running) {
        // 1. 获取当前场景的 ECS
        auto it = sceneEcsMap.find(currentScene);
        if (it == sceneEcsMap.end()) {
            LOGE("Scene not found: %{public}s", currentScene.c_str());
            return;
        }
        
        // 2. 切换到该 ECS (只需修改这一行！)
        lumeCommon->ecs_ = it->second;
        
        // 3. 收集 RenderHandles 并渲染
        lumeCommon->CollectRenderHandles();
        lumeCommon->RenderFrame();
        
        // 4. 可以动态切换场景
        if (userRequestedSwitch) {
            currentScene = GetNextScene();
            LOGI("Switching to scene: %{public}s", currentScene.c_str());
        }
    }
}
```

#### 8.3.3 场景变化更新

```cpp
void UpdateScene(const std::string& scenePath)
{
    auto it = sceneEcsMap.find(scenePath);
    if (it == sceneEcsMap.end()) {
        return;
    }
    
    auto* ecs = it->second.get();
    
    // 修改场景数据
    UpdateNodeTransform(ecs, nodeId, newPos);
    
    // 需要重新 TickFrame 以更新 RenderSystem
    engine_->TickFrame(BASE_NS::array_view(&ecs, 1));
    
    // 然后渲染
    lumeCommon->ecs_ = it->second;
    lumeCommon->CollectRenderHandles();
    lumeCommon->RenderFrame();
}
```

### 8.4 注意事项

#### ⚠️ 注意 1: customRender 会提前返回

**问题代码**：
```cpp
void LumeCommon::CollectRenderHandles()
{
    if (customRender_) {
        auto rngs = customRender_->GetRenderHandles();
        renderHandles_.insert(renderHandles_.end(), rngs.begin(), rngs.end());
        return;  // ← 提前返回！不收集 ECS 的 handles！
    }
    
    // 这行永远不会执行
    auto *ecs = ecs_.get();
    // ...
}
```

**修复方案**：
```cpp
void LumeCommon::CollectRenderHandles()
{
    renderHandles_.clear();
    
    // 1. 先收集 customRender 的 handles (如果有的话)
    if (customRender_) {
        auto rngs = customRender_->GetRenderHandles();
        renderHandles_.insert(renderHandles_.end(), rngs.begin(), rngs.end());
        // 不再 return，继续收集 ECS 的 handles
    }
    
    // 2. 从 ecs_ 收集
    auto *ecs = ecs_.get();
    BASE_NS::array_view<const RENDER_NS::RenderHandleReference> main = 
        GetGraphicsContext()->GetRenderNodeGraphs(*ecs);
    
    if (main.size() == 0) {
        LOGI("No render handles found");
        return;
    }
    
    for (auto handle : main) {
        renderHandles_.push_back(handle);
    }
}
```

#### ⚠️ 注意 2: 场景变化需要重新 TickFrame

```cpp
// ❌ 错误：修改场景后直接渲染
UpdateNodeTransform(ecs, nodeId, newPos);
lumeCommon->ecs_ = ecs;
CollectRenderHandles();
RenderFrame();  // ← RenderSystem 不知道场景变化了！

// ✅ 正确：修改场景后先 TickFrame
UpdateNodeTransform(ecs, nodeId, newPos);
engine_->TickFrame(BASE_NS::array_view(&ecs, 1));  // ← 更新 RenderSystem
lumeCommon->ecs_ = ecs;
CollectRenderHandles();
RenderFrame();
```

#### ⚠️ 注意 3: 多 ECS 同时渲染

如果需要**同时渲染多个 ECS**（如主场景 + UI overlay）：

```cpp
// ❌ 错误：只能渲染一个 ECS
lumeCommon->ecs_ = ecs1;
CollectRenderHandles();
RenderFrame();  // 只渲染 ecs1

lumeCommon->ecs_ = ecs2;
CollectRenderHandles();  // 覆盖了 ecs1 的 handles
RenderFrame();  // 只渲染 ecs2

// ✅ 正确：同时渲染多个 ECS
void CollectRenderHandles(const std::vector<uint64_t>& ecsIds)
{
    renderHandles_.clear();
    
    // 从所有指定的 ECS 收集
    for (uint64_t ecsId : ecsIds) {
        auto* ecs = ecsMap_[ecsId].get();
        auto handles = GetGraphicsContext()->GetRenderNodeGraphs(*ecs);
        renderHandles_.insert(renderHandles_.end(), handles.begin(), handles.end());
    }
}

CollectRenderHandles({ecs1, ecs2});
RenderFrame();  // 同时渲染 ecs1 和 ecs2
```

### 8.5 性能优化建议

#### 1. 预创建 RenderNodeGraph

```cpp
// 初始化时一次性创建所有场景的 RenderNodeGraph
void PreCreateRenderNodeGraphs()
{
    for (auto& [name, ecs] : sceneEcsMap) {
        engine_->TickFrame(BASE_NS::array_view(&ecs, 1));
        // RenderSystem::Update() 会创建并缓存 RenderNodeGraph
    }
}
```

#### 2. 按需更新

```cpp
// 只更新有变化的 ECS
void UpdateDirtyScenes(const std::vector<uint64_t>& dirtyEcsIds)
{
    std::vector<IEcs*> ecsToUpdate;
    for (uint64_t ecsId : dirtyEcsIds) {
        ecsToUpdate.push_back(ecsMap_[ecsId].get());
    }
    
    if (!ecsToUpdate.empty()) {
        engine_->TickFrame(BASE_NS::array_view(ecsToUpdate.data(), ecsToUpdate.size()));
    }
}
```

#### 3. 缓存 RenderHandles

```cpp
// 如果场景不变，可以缓存 handles 避免重复收集
std::unordered_map<uint64_t, BASE_NS::vector<RenderHandleReference>> handlesCache;

void CacheRenderHandles(uint64_t ecsId)
{
    auto* ecs = ecsMap_[ecsId].get();
    auto handles = GetGraphicsContext()->GetRenderNodeGraphs(*ecs);
    handlesCache[ecsId].assign(handles.begin(), handles.end());
}

void UseCachedHandles(uint64_t ecsId)
{
    auto it = handlesCache.find(ecsId);
    if (it != handlesCache.end()) {
        renderHandles_ = it->second;  // 直接使用缓存
    }
}
```

### 8.6 实际应用场景

#### 场景 1: 3D 模型预览器

```cpp
// 用户可以在多个模型之间切换预览
std::vector<std::string> models = { "car.gltf", "chair.gltf", "table.gltf" };
InitializeScenes(models);

// 用户点击切换按钮时
void OnModelSwitchButtonClicked(const std::string& newModel)
{
    currentScene = newModel;
    // 下次 RenderLoop 会自动渲染新模型
}
```

#### 场景 2: 多视图编辑

```cpp
// 同时显示多个视图（顶视图、侧视图、透视视图）
auto topViewEcs = CreateCameraView("top");
auto sideViewEcs = CreateCameraView("side");
auto perspectiveEcs = CreateCameraView("perspective");

// 同时渲染三个视图
CollectRenderHandles({topViewEcs, sideViewEcs, perspectiveEcs});
RenderFrame();
```

#### 场景 3: LOD 切换

```cpp
// 根据距离切换不同精度的模型
auto lodHighEcs = CreateLODScene("high_poly.gltf");
auto lodLowEcs = CreateLODScene("low_poly.gltf");

void UpdateLOD(float distance)
{
    if (distance < 10.0f) {
        lumeCommon->ecs_ = lodHighEcs;  // 近距离用高精度
    } else {
        lumeCommon->ecs_ = lodLowEcs;   // 远距离用低精度
    }
    CollectRenderHandles();
    RenderFrame();
}
```

---

## 9. 总结

### 架构层次

| 层次 | 组件 | 数量 | 职责 |
|------|------|------|------|
| 应用层 | LumeCommon | 1 | 决定渲染哪些 ECS |
| ECS 层 | IEcs + RenderSystem | N | 每个 ECS 独立更新和收集数据 |
| 渲染后端 | IRenderer | 1 | 执行所有 RenderNodeGraph |

### 关键机制

1. **RenderSystem 属于 ECS** - 每个 ECS 有自己的 RenderSystem 实例
2. **RenderSystem 收集数据** - Update() 时从 ECS 的 Component 收集场景数据
3. **RenderSystem 创建 RenderNodeGraph** - 根据收集的数据创建渲染句柄
4. **LumeCommon 收集句柄** - 从选中的 ECS 收集 RenderHandleReference
5. **渲染后端执行** - 不关心 ECS，只执行 RenderNodeGraph

### ECS 切换渲染的关键

```
初始化阶段 (一次性)
  CreateEcs() → LoadSystemGraph() → TickFrame()
                                      ↓
                              RenderSystem::Update()
                                      ↓
                              创建 RenderNodeGraph → 缓存 handle
                                      
渲染阶段 (可重复切换)
  lumeCommon->ecs_ = targetEcs  ← 只需修改这一行！
            ↓
  CollectRenderHandles()
            ↓
  GetRenderNodeGraphs(*ecs) → 返回缓存的 handle
            ↓
  RenderFrame(handle) → 渲染对应场景
```

### 多 ECS 渲染的关键

```
LumeCommon (应用层)
    │
    ├─ 决定：渲染哪些 ECS
    │   └─> TickFrame([ecs1, ecs2, ...])
    │
    ├─ 收集：从选中的 ECS 收集 RenderHandle
    │   └─> CollectRenderHandles()
    │
    └─ 提交：所有 handles 到渲染后端
        └─> RenderFrame(handles)

渲染后端 (执行层)
    │
    ├─ 遍历：所有 handles
    │   └─> ExecuteRenderNodeGraph(handle)
    │
    └─ 提交：到 GPU
        └─> SubmitToGPU()
```

### 最终答案

**渲染后端不选择 ECS，它只执行 RenderNodeGraph。选择渲染哪些 ECS 的权力在 LumeCommon (应用层)。**

**在所有 ECS 都已初始化完成后，只需修改 `CollectRenderHandles()` 中的 `ecs_` 即可切换渲染场景。**

---

**文档结束**
