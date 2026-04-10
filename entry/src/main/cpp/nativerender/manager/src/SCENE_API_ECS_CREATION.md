# Scene API 创建场景时的 ECS 和 Manager 分析

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 7 日

---

## 1. 核心问题

**问题**: Scene API 在创建场景时会创建新的 ECS 吗？如果会，那它会创建相应的 Manager 吗？

**简短回答**: 
- ✅ **会创建新的 ECS**
- ✅ **会创建相应的 Component Managers**
- ⚠️ **但支持与外部 ECS 融合（Fusion Mode）**

---

## 2. Scene API 创建场景的完整流程

### **2.1 调用链路**

```
ArkTS: Scene.load("scene://default")
    │
    ▼ NAPI
SceneJS::Load()
    │
    ├─ CreateSceneManager(uri)
    │   │
    │   └─ objRegistry.Create<ISceneManager>(...)
    │
    ├─ sceneManager->CreateScene(uri)
    │   │
    │   └─ context_->AddTask([...])
    │       │
    │       └─ META_NS::GetObjectRegistry().Create<IScene>(ClassId::Scene, args)
    │           │
    │           └─ SceneObject::Build()
    │               │
    │               └─ InternalScene::Initialize()
    │                   │
    │                   └─ ecs_->Initialize()  ← 创建 ECS！
    │
    └─ 返回 SceneJS 对象
```

---

### **2.2 关键代码分析**

#### **SceneManager::CreateScene**

```cpp
// scene_manager.cpp:85
Future<IScene::Ptr> SceneManager::CreateScene(SceneOptions opts)
{
    return context_->AddTask([context = CreateContext(BASE_NS::move(opts))] {
        // 创建 Scene 对象
        if (auto scene = META_NS::GetObjectRegistry().Create<IScene>(
                SCENE_NS::ClassId::Scene, context)) {
            
            // 获取 InternalScene 并创建 ECS
            auto& ecs = scene->GetInternalScene()->GetEcsContext();
            
            // 创建未命名根节点
            if (ecs.CreateUnnamedRootNode()) {
                return scene;
            }
            CORE_LOG_E("Failed to create root node");
        }
        return SCENE_NS::IScene::Ptr {};
    });
}
```

#### **SceneObject::Build**

```cpp
// scene.cpp:54
bool SceneObject::Build(const META_NS::IMetadata::Ptr& d)
{
    bool res = Super::Build(d);
    if (res) {
        auto context = GetInterfaceBuildArg<IRenderContext>(d, "RenderContext");
        auto opts = GetBuildArg<SceneOptions>(d, "Options");
        
        // 创建 InternalScene
        auto in = CreateShared<InternalScene>(
            GetSelf<IScene>(), BASE_NS::move(context), BASE_NS::move(opts));
        
        internal_ = in;
        in->SetSelf(internal_);
        
        // 添加 Component Factories
        AddBuiltinComponentFactories(internal_);
        
        // 初始化 InternalScene
        res = internal_->Initialize();
    }
    return res;
}
```

#### **InternalScene::Initialize**

```cpp
// internal_scene.cpp:56
bool InternalScene::Initialize()
{
    LOGI("InternalScene::Initialize: externalEcs_=%{public}p, externalEcsId=%{public}lu",
        externalEcs_.get(), externalEcs_ ? externalEcs_->GetId() : 0);
    
    // ========== 创建 ECS ==========
    ecs_.reset(new Ecs);
    
    // 初始化 ECS（支持外部 ECS）
    if (!ecs_->Initialize(self_.lock(), options_, externalEcs_)) {
        CORE_LOG_E("failed to initialize ecs");
        return false;
    }
    return true;
}
```

---

## 3. ECS 创建细节

### **3.1 Ecs 类初始化**

```cpp
// Ecs::Initialize
bool Ecs::Initialize(const IScene::Ptr& scene, const SceneOptions& options, 
                     CORE_NS::IEcs::Ptr externalEcs)
{
    if (externalEcs) {
        // Fusion Mode: 使用外部 ECS
        LOGI("Using external ECS for fusion mode, ecsId=%{public}lu", 
             externalEcs->GetId());
        nativeEcs_ = externalEcs;
    } else {
        // Normal Mode: 创建新的 ECS
        LOGI("Creating new ECS for scene");
        nativeEcs_ = engine_->CreateEcs();
    }
    
    // ========== 创建 Component Managers ==========
    // 每个 ECS 都有自己独立的 Component Managers
    transformComponentManager = 
        CORE_NS::GetManager<CORE3D_NS::ITransformComponentManager>(*nativeEcs_);
    cameraComponentManager = 
        CORE_NS::GetManager<CORE3D_NS::ICameraComponentManager>(*nativeEcs_);
    lightComponentManager = 
        CORE_NS::GetManager<CORE3D_NS::ILightComponentManager>(*nativeEcs_);
    renderMeshComponentManager = 
        CORE_NS::GetManager<CORE3D_NS::IRenderMeshComponentManager>(*nativeEcs_);
    // ... 更多 Managers
    
    // 初始化 Systems
    ecs->Initialize();
    
    return true;
}
```

---

### **3.2 Component Managers 的创建**

**每个 Scene 的 ECS 都会创建以下 Managers**：

```cpp
class Ecs {
    // Scene API 的 Component Managers
    CORE3D_NS::ITransformComponentManager* transformComponentManager;
    CORE3D_NS::ICameraComponentManager* cameraComponentManager;
    CORE3D_NS::ILightComponentManager* lightComponentManager;
    CORE3D_NS::IRenderMeshComponentManager* renderMeshComponentManager;
    CORE3D_NS::IMaterialComponentManager* materialComponentManager;
    CORE3D_NS::IMeshComponentManager* meshComponentManager;
    CORE3D_NS::INameComponentManager* nameComponentManager;
    // ...
    
    CORE_NS::IEcs::Ptr nativeEcs_;  // ECS 实例
};
```

**创建方式**：
```cpp
// 从 ECS 获取 Manager（每个 ECS 有自己的 Manager 实例）
transformComponentManager = 
    CORE_NS::GetManager<CORE3D_NS::ITransformComponentManager>(*nativeEcs_);
```

---

## 4. 两种模式对比

### **4.1 Normal Mode（普通模式）**

```cpp
// 创建新的 ECS
auto ecs = engine_->CreateEcs();

// 创建 Component Managers
auto transformMgr = GetManager<ITransformComponentManager>(*ecs);
auto cameraMgr = GetManager<ICameraComponentManager>(*ecs);
// ...

// 创建 Scene
auto scene = objRegistry.Create<IScene>(ClassId::Scene, context);
scene->GetInternalScene()->GetEcsContext().CreateUnnamedRootNode();

// 结果：
// - Scene 有自己的 ECS
// - Scene 有自己的 Component Managers
// - 与 LumeCommon 完全独立
```

**架构图**：
```
┌─────────────────────────────────────────────────────────────┐
│  Scene API Scene                                             │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  InternalScene                                        │   │
│  │  ├─ ecs_: Ecs (独立创建)                              │   │
│  │  │   ├─ nativeEcs_: IEcs::Ptr                        │   │
│  │  │   ├─ transformComponentManager                    │   │
│  │  │   ├─ cameraComponentManager                       │   │
│  │  │   ├─ lightComponentManager                        │   │
│  │  │   └─ ...                                          │   │
│  │  │                                                    │   │
│  │  └─ nodes_: 节点列表                                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

### **4.2 Fusion Mode（融合模式）**

```cpp
// 设置外部 ECS（来自 LumeCommon）
auto externalEcs = lumeCommon->GetEcs();

// 创建 Scene
auto scene = objRegistry.Create<IScene>(ClassId::Scene, context);

// 在 ECS 初始化前设置外部 ECS
scene->GetInternalScene()->SetExternalEcs(externalEcs);

// 初始化时会使用外部 ECS
scene->GetInternalScene()->Initialize();
// ↑ InternalScene::Initialize() 会检查 externalEcs_

// 结果：
// - Scene 使用 LumeCommon 的 ECS
// - Scene 的 Component Managers 从外部 ECS 获取
// - Scene 和 LumeCommon 共享同一个 ECS
```

**关键代码**：
```cpp
// internal_scene.cpp:76
void InternalScene::SetExternalEcs(CORE_NS::IEcs::Ptr ecs)
{
    LOGI("InternalScene::SetExternalEcs: ecs=%{public}p, ecsId=%{public}lu",
        ecs.get(), ecs ? ecs->GetId() : 0);
    
    if (ecs_ && ecs_->GetNativeEcs()) {
        LOGE("Cannot set external ECS after ECS is initialized");
        return;
    }
    
    externalEcs_ = ecs;  // ← 保存外部 ECS
}

// internal_scene.cpp:56
bool InternalScene::Initialize()
{
    ecs_.reset(new Ecs);
    
    // 传入 externalEcs_，Ecs::Initialize 会使用它
    if (!ecs_->Initialize(self_.lock(), options_, externalEcs_)) {
        return false;
    }
    return true;
}
```

**架构图**：
```
┌─────────────────────────────────────────────────────────────┐
│  LumeCommon                                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  ecs_: IEcs::Ptr  ← 共享的 ECS                        │   │
│  │  transformManager_                                    │   │
│  │  cameraManager_                                       │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ▲                                   │
│                          │ SetExternalEcs()                  │
│                          │                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Scene API Scene                                      │   │
│  │  ┌────────────────────────────────────────────────┐   │   │
│  │  │  InternalScene                                  │   │   │
│  │  │  ├─ externalEcs_: IEcs::Ptr  ← 指向 LumeCommon  │   │   │
│  │  │  ├─ ecs_: Ecs                                   │   │   │
│  │  │  │   └─ nativeEcs_ = externalEcs_  ← 使用外部 ECS │   │   │
│  │  │  └─ Component Managers (从外部 ECS 获取)           │   │   │
│  │  └────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 完整对比表

| 特性 | Normal Mode | Fusion Mode |
|------|-------------|-------------|
| **ECS 来源** | Scene API 自己创建 | 使用外部 ECS（LumeCommon） |
| **Component Managers** | Scene API 自己创建 | 从外部 ECS 获取 |
| **独立性** | 完全独立 | 与 LumeCommon 共享 |
| **适用场景** | 独立 Scene API 应用 | XComponent 融合渲染 |
| **内存开销** | 独立 ECS + Managers | 共享 ECS + Managers |
| **渲染集成** | 需要独立 RenderContext | 复用 LumeCommon 渲染 |

---

## 6. 实际使用示例

### **6.1 Normal Mode（默认）**

```typescript
// ArkTS
import { Scene } from "libnativerender.so";

// 加载场景 - 自动创建独立的 ECS
const scene = await Scene.load("scene://default");
// ↑ 内部：
//   1. 创建 SceneManager
//   2. sceneManager->CreateScene()
//   3. 创建新的 ECS
//   4. 创建 Component Managers
//   5. 创建根节点

// 创建节点 - 添加到 Scene 的 ECS
const node = await scene.createNode({ name: "MyNode" });
// ↑ 内部：
//   1. scene->CreateNode()
//   2. 在 Scene 的 ECS 中创建 Entity
//   3. 添加 TransformComponent 等

// 修改属性 - 直接修改 Scene 的 ECS
node.position = { x: 1, y: 2, z: 3 };
// ↑ 内部：
//   1. node->Position()->SetValue()
//   2. 修改 Scene 的 ECS 中的 TransformComponent
```

---

### **6.2 Fusion Mode（XComponent 融合）**

```cpp
// C++ (LumeXComponentManager::LoadScene)

// 1. 获取 LumeCommon 的 ECS
auto lumeCommon = renderer->GetLumeCommon();
auto lumeEcs = lumeCommon->GetEcs();

// 2. 创建 SceneManager
auto sceneManager = CreateSceneManager(gltfPath, lumeCommon, env);

// 3. 创建 Scene（使用外部 ECS）
auto scene = META_NS::GetObjectRegistry().Create<SCENE_NS::IScene>(
    SCENE_NS::ClassId::Scene, context);

// 4. 在 ECS 初始化前设置外部 ECS
scene->GetInternalScene()->SetExternalEcs(lumeEcs);
// ↑ 关键：设置外部 ECS

// 5. 初始化（会使用外部 ECS）
scene->GetInternalScene()->Initialize();
// ↑ InternalScene::Initialize() → Ecs::Initialize(externalEcs)

// 6. 加载 GLB
assets->Load(scene, gltfPath);
// ↑ 节点添加到共享的 ECS

// 7. LumeCommon 使用共享 ECS 渲染
lumeCommon->SetEcs(sceneEcs);
lumeCommon->InitializeScene(sceneEcs->GetId());
```

---

## 7. 与 LumeCommon 的关系

### **7.1 两个独立的体系**

```
┌─────────────────────────────────────────────────────────────┐
│  LumeCommon (Lume 引擎)                                      │
│  ├─ ecs_: IEcs::Ptr                                         │
│  ├─ transformManager_: ITransformComponentManager*          │
│  ├─ cameraManager_: ICameraComponentManager*                │
│  ├─ lightManager_: ILightComponentManager*                  │
│  └─ ...                                                     │
│                                                              │
│  用途：Lume 引擎内部访问（SetupCameraTransform 等）          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Scene API Scene                                            │
│  ├─ internal_: InternalScene                                │
│  │   ├─ ecs_: Ecs                                           │
│  │   │   ├─ nativeEcs_: IEcs::Ptr                          │
│  │   │   ├─ transformComponentManager                      │
│  │   │   ├─ cameraComponentManager                         │
│  │   │   └─ ...                                            │
│  │   └─ externalEcs_: IEcs::Ptr (可选，Fusion Mode 使用)    │
│  └─ ...                                                     │
│                                                              │
│  用途：ArkTS 通过 Scene API 访问（node.position = ...）      │
└─────────────────────────────────────────────────────────────┘
```

---

### **7.2 Fusion Mode 时的关系**

```cpp
// Fusion Mode 时，两个体系共享同一个 ECS

LumeCommon::ecs_  ──────┐
                        │
                        ├─→ 同一个 ECS 实例
                        │
Scene::externalEcs_ ────┘

// Component Managers 也共享
LumeCommon::cameraManager_  ──→ 从 LumeCommon::ecs_ 获取
Scene::cameraComponentManager ─→ 从 Scene::externalEcs_ 获取
                                ↑
                                同一个 Manager 实例！
```

---

## 8. 总结

### **问题回答**

| 问题 | 答案 | 说明 |
|------|------|------|
| **Scene API 创建场景时会创建新的 ECS 吗？** | ✅ 会 | `ecs_.reset(new Ecs)` |
| **会创建相应的 Manager 吗？** | ✅ 会 | 从 ECS 获取 Component Managers |
| **可以与外部 ECS 共享吗？** | ✅ 可以 | 通过 `SetExternalEcs()` |

### **关键机制**

1. **Normal Mode** - 每个 Scene 有独立的 ECS 和 Managers
2. **Fusion Mode** - 通过 `SetExternalEcs()` 共享 LumeCommon 的 ECS
3. **Component Managers** - 从 ECS 获取，每个 ECS 有独立的 Managers
4. **ArkTS 访问** - 通过 Scene API Property Handle 直接修改 ECS

### **与 LumeCommon 的关系**

- **Normal Mode**: 完全独立，互不影响
- **Fusion Mode**: 共享 ECS 和 Managers
- **ArkTS 修改**: 不经过 LumeCommon 的 Managers，直接通过 Scene API

---

**文档结束**
