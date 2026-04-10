# ECS 持有关系与传递给引擎的链路分析

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 7 日

---

## 1. 核心问题

**问题**: ECS 最终被谁持有？如何传递给引擎？

---

## 2. ECS 持有关系图

```
┌─────────────────────────────────────────────────────────────┐
│  持有层次结构                                                │
│                                                              │
│  SceneObject (IScene)                                        │
│  └─ internal_: InternalScene::Ptr                           │
│      └─ ecs_: Ecs::Ptr           ← Scene 持有 Ecs 包装器       │
│          └─ ecs: IEcs::Ptr       ← Ecs 持有真正的 ECS 实例     │
│                                                              │
│  访问链路：                                                  │
│  Scene → InternalScene → Ecs → IEcs                         │
│                                                              │
│  获取方法：                                                  │
│  scene->GetInternalScene()->GetEcsContext().GetNativeEcs()  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 详细持有关系

### **3.1 SceneObject 持有 InternalScene**

**文件**: `scene.h`

```cpp
// SceneObject (IScene 实现)
class SceneObject : public META_NS::InterfaceObject<IScene> {
    // InternalScene 指针
    BASE_NS::shared_ptr<IInternalScene> internal_;
};
```

---

### **3.2 InternalScene 持有 Ecs**

**文件**: `internal_scene.h:179`

```cpp
// InternalScene
class InternalScene : public IInternalScene {
    // Ecs 包装器（智能指针）
    BASE_NS::unique_ptr<Ecs> ecs_;
    
    // 外部 ECS（Fusion Mode 使用）
    CORE_NS::IEcs::Ptr externalEcs_;
};
```

**初始化代码** (`internal_scene.cpp:61`):
```cpp
bool InternalScene::Initialize()
{
    // 创建 Ecs 包装器
    ecs_.reset(new Ecs);
    
    // 初始化 ECS
    if (!ecs_->Initialize(self_.lock(), options_, externalEcs_)) {
        return false;
    }
    return true;
}
```

---

### **3.3 Ecs 持有真正的 ECS 实例**

**文件**: `ecs.h:100`

```cpp
// Ecs 类
class Ecs : public IEcsContext {
    // 真正的 ECS 实例（智能指针）
    CORE_NS::IEcs::Ptr ecs;
    
    // Component Managers
    ICameraComponentManager* cameraComponentManager;
    ILightComponentManager* lightComponentManager;
    ITransformComponentManager* transformComponentManager;
    // ... 更多 Managers
};
```

**创建代码** (`ecs.cpp:64`):
```cpp
bool Ecs::Initialize(..., CORE_NS::IEcs::Ptr externalEcs)
{
    auto& engine = context.GetEngine();
    
    if (externalEcs) {
        // Fusion Mode: 使用外部 ECS
        ecs = externalEcs;
    } else {
        // Normal Mode: 创建新的 ECS ⭐
        ecs = engine.CreateEcs();  // ← 创建 ECS！
    }
    
    return true;
}
```

---

### **3.4 获取 ECS 的完整链路**

```cpp
// 从 Scene 获取 ECS
auto ecs = scene->GetInternalScene()           // InternalScene::Ptr
              ->GetEcsContext()                 // IEcsContext&
              ->GetNativeEcs();                 // IEcs::Ptr

// 简化版本（使用 EcsScene）
auto ecs = EcsScene::GetEcs(scene);            // IEcs::Ptr
```

**代码位置**:
- `ecs_scene.h:42`
- `internal_scene.h:83-86`
- `ecs.h:87-90`

```cpp
// ecs_scene.h:42
CORE_NS::IEcs::Ptr EcsScene::GetEcs() const
{
    auto is = META_INTERFACE_OBJECT_CALL_PTR(GetInternalScene());
    return is ? is->GetEcsContext().GetNativeEcs() : nullptr;
}

// internal_scene.h:83
IEcsContext& InternalScene::GetEcsContext() override
{
    return *ecs_;  // 返回 Ecs 包装器
}

// ecs.h:87
CORE_NS::IEcs::Ptr Ecs::GetNativeEcs() const override
{
    return ecs;  // 返回真正的 ECS 实例
}
```

---

## 4. ECS 如何传递给引擎

### **4.1 引擎通过 ECS 获取渲染数据**

```
┌─────────────────────────────────────────────────────────────┐
│  渲染流程                                                    │
│                                                              │
│  1. Engine::TickFrame(ecs[])                                │
│     │                                                        │
│     └─ 遍历所有 ECS，调用 Update()                           │
│                                                              │
│  2. ECS::Update()                                           │
│     │                                                        │
│     └─ 遍历所有 System：                                     │
│        ├─ RenderSystem::Update()                            │
│        ├─ NodeSystem::Update()                              │
│        └─ AnimationSystem::Update()                         │
│                                                              │
│  3. RenderSystem::Update()                                  │
│     │                                                        │
│     ├─ 从 ECS 获取 Component 数据                             │
│     │  ├─ CameraComponent                                   │
│     │  ├─ LightComponent                                    │
│     │  └─ MeshComponent                                     │
│     │                                                        │
│     └─ 创建 RenderNodeGraphs                                │
│        └─ 返回 RenderHandleReference[]                      │
│                                                              │
│  4. Renderer::RenderFrame(handles[])                        │
│     │                                                        │
│     └─ 执行 RenderNodeGraphs → GPU 渲染                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### **4.2 GraphicsContext 从 ECS 获取 RenderNodeGraphs**

**文件**: `graphics_context.cpp:363`

```cpp
array_view<const RenderHandleReference> 
GraphicsContext::GetRenderNodeGraphs(const IEcs& ecs) const
{
    // 从 ECS 获取 RenderSystem
    if (IRenderSystem* rs = GetSystem<IRenderSystem>(ecs); rs) {
        // 获取 RenderSystem 创建的 RenderNodeGraphs
        return rs->GetRenderNodeGraphs();
    } else {
        return {};
    }
}
```

**关键点**：
- 通过 `GetSystem<IRenderSystem>(ecs)` 从 ECS 获取 RenderSystem
- RenderSystem 在 ECS 初始化时通过系统图加载创建
- RenderSystem 持有渲染所需的 RenderNodeGraphs

---

### **4.3 RenderSystem 在 ECS 中**

**文件**: `render_system.cpp:1048`

```cpp
// RenderSystem 持有 ECS 引用
class RenderSystem : public IRenderSystem {
    const IEcs& ecs_;  // ECS 引用
    
public:
    const IEcs& GetECS() const override
    {
        return ecs_;
    }
};
```

**初始化** (`render_system.cpp:1053`):
```cpp
void RenderSystem::Initialize()
{
    LOGI("RenderSystem::Initialize() - graphicsContext=%{public}d",
        !!graphicsContext_);
    
    // 从 ECS 获取 RenderPreprocessorSystem
    renderPreprocessorSystem_ = GetSystem<IRenderPreprocessorSystem>(ecs_);
    
    // 设置 DataStore Pointers
    SetDataStorePointers(renderContext_->GetRenderDataStoreManager());
}
```

---

### **4.4 LumeCommon 使用 ECS 渲染**

**文件**: `lume_common.cpp:776`

```cpp
void LumeCommon::DrawFrame()
{
    // 获取当前 ECS
    auto* ecs = ecs_.get();
    
    // TickFrame 更新 ECS（包括 RenderSystem）
    if (const bool needsRender = engine_->TickFrame(
            BASE_NS::array_view(&ecs, 1)); needsRender) {
        
        // 收集 RenderHandles
        CollectRenderHandles();
        
        // 渲染
        GetRenderContext()->GetRenderer().RenderFrame(
            BASE_NS::array_view(renderHandles_.data(), renderHandles_.size()));
    }
}
```

**CollectRenderHandles** (`lume_common.cpp:1156`):
```cpp
void LumeCommon::CollectRenderHandles()
{
    renderHandles_.clear();
    
    // 从 GraphicsContext 获取 RenderNodeGraphs
    auto* ecs = ecs_.get();
    BASE_NS::array_view<const RENDER_NS::RenderHandleReference> main = 
        GetGraphicsContext()->GetRenderNodeGraphs(*ecs);
        // ↑ 从 ECS 获取 RenderNodeGraphs
    
    for (auto handle : main) {
        renderHandles_.push_back(handle);
    }
}
```

---

## 5. 完整传递链路

### **5.1 创建阶段**

```
Engine::CreateEcs()
    │
    └─ 创建 IEcs 实例
        │
        └─ Ecs::Initialize()
            │
            ├─ ecs = engine.CreateEcs()  ← 存储 ECS
            │
            └─ 创建 Component Managers
                ├─ cameraComponentManager
                ├─ lightComponentManager
                └─ ...
```

---

### **5.2 持有阶段**

```
SceneObject
    └─ internal_: InternalScene
        └─ ecs_: Ecs
            └─ ecs: IEcs::Ptr  ← 最终持有
```

---

### **5.3 使用阶段（渲染）**

```
LumeCommon::DrawFrame()
    │
    ├─ engine_->TickFrame([ecs])
    │   │
    │   └─ ECS 更新 Systems
    │       └─ RenderSystem::Update()
    │           └─ 创建 RenderNodeGraphs
    │
    ├─ CollectRenderHandles()
    │   │
    │   └─ GetGraphicsContext()->GetRenderNodeGraphs(*ecs)
    │       │
    │       └─ GetSystem<IRenderSystem>(ecs)->GetRenderNodeGraphs()
    │
    └─ Renderer::RenderFrame(handles[])
        │
        └─ 执行 RenderNodeGraphs → GPU
```

---

## 6. 关键接口

### **6.1 GetNativeEcs() - 获取 ECS 的标准方法**

```cpp
// IEcsContext 接口
class IEcsContext : public IInterface {
    virtual CORE_NS::IEcs::Ptr GetNativeEcs() const = 0;
};

// Ecs 实现
CORE_NS::IEcs::Ptr Ecs::GetNativeEcs() const override
{
    return ecs;  // 返回持有的 ECS 实例
}
```

---

### **6.2 GetSystem<T>() - 从 ECS 获取 System**

```cpp
// 从 ECS 获取 RenderSystem
IRenderSystem* rs = GetSystem<IRenderSystem>(ecs);

// RenderSystem 用于获取 RenderNodeGraphs
auto handles = rs->GetRenderNodeGraphs();
```

---

### **6.3 GetRenderNodeGraphs() - 获取渲染句柄**

```cpp
// GraphicsContext 从 ECS 获取 RenderNodeGraphs
array_view<const RenderHandleReference> 
GraphicsContext::GetRenderNodeGraphs(const IEcs& ecs) const
{
    if (IRenderSystem* rs = GetSystem<IRenderSystem>(ecs); rs) {
        return rs->GetRenderNodeGraphs();
    }
    return {};
}
```

---

## 7. 总结

### **ECS 持有关系**

| 层级 | 持有者 | 被持有 | 类型 |
|------|--------|--------|------|
| 1 | `SceneObject` | `InternalScene::Ptr` | 智能指针 |
| 2 | `InternalScene` | `Ecs::Ptr` | 智能指针 |
| 3 | `Ecs` | `IEcs::Ptr` | 智能指针 |

**最终持有者**: `Ecs::ecs` 成员变量

---

### **ECS 传递给引擎的方式**

| 方式 | 说明 | 代码位置 |
|------|------|----------|
| **TickFrame** | `engine_->TickFrame([ecs])` | lume_common.cpp:776 |
| **GetRenderNodeGraphs** | `GetGraphicsContext()->GetRenderNodeGraphs(*ecs)` | lume_common.cpp:1172 |
| **GetSystem** | `GetSystem<IRenderSystem>(ecs)` | graphics_context.cpp:363 |

---

### **关键代码行**

```cpp
// 获取 ECS
auto ecs = scene->GetInternalScene()
              ->GetEcsContext()
              ->GetNativeEcs();

// 传递给引擎渲染
engine_->TickFrame(BASE_NS::array_view(&ecs, 1));

// 获取渲染句柄
auto handles = GetGraphicsContext()->GetRenderNodeGraphs(*ecs);

// 渲染
Renderer::RenderFrame(handles);
```

---

**文档结束**
