# SceneJS 与 SceneManager 关系分析

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 7 日

---

## 1. 核心问题

**问题**: SceneJS 是否持有一个唯一的 SceneManager 以记录所有 load 的场景和创建的 ECS？

**简短回答**: 
- ❌ **SceneJS 不持有 SceneManager**
- ❌ **SceneJS 不记录所有 load 的场景**
- ✅ **每个 Scene 实例独立管理自己的 ECS**
- ✅ **SceneManager 是临时创建的，用完即弃**

---

## 2. SceneJS 类结构分析

### **2.1 SceneJS 成员变量**

```cpp
// SceneJS.h
class SceneJS : public BaseObject {
    // ========== 没有 SceneManager 成员 ==========
    
    // 渲染上下文
    NapiApi::StrongRef renderContextJS_;
    BASE_NS::shared_ptr<RenderResources> resources_;
    
    // 环境
    NapiApi::StrongRef environmentJS_;
    
    // Dispose 管理
    BASE_NS::unordered_map<uintptr_t, NapiApi::StrongRef> strongDisposables_;
    BASE_NS::unordered_map<uintptr_t, NapiApi::WeakRef> disposables_;
    
    // 环境
    napi_env env_;
    SCENE_NS::IRenderResourceManager::Ptr renderMan_;
    bool currentAlwaysRender_ = true;
    
    // Scene Adapter (可选)
#ifdef __SCENE_ADAPTER__
    std::shared_ptr<OHOS::Render3D::ISceneAdapter> scene_ = nullptr;
#endif
    
    // ❌ 没有 sceneManager_ 成员！
};
```

**关键发现**：SceneJS **没有**持有任何 SceneManager 指针！

---

### **2.2 SceneJS::Load 流程**

```cpp
// SceneJS.cpp:233
napi_value SceneJS::Load(NapiApi::FunctionContext<>& ctx)
{
    const auto env = ctx.Env();
    auto promise = Promise(env);
    
    // 1. 创建临时 SceneManager
    auto sceneManager = CreateSceneManager(uri);
    if (!sceneManager) {
        return promise.Reject("Creating scene manager failed");
    }
    
    // 2. 使用 SceneManager 创建 Scene
    //    sceneManager->CreateScene(uri) 返回 Future<IScene::Ptr>
    sceneManager->CreateScene(uri)
        .Then(BASE_NS::move(massageScene), engineQ)
        .Then(BASE_NS::move(convertToJs), jsQ);
    
    // 3. SceneManager 不被保存，用完即弃
    //    sceneManager 是局部变量，函数结束后销毁
    
    return promise;
}

// SceneJS.cpp:353
SCENE_NS::ISceneManager::Ptr SceneJS::CreateSceneManager(BASE_NS::string_view uri)
{
    auto& objRegistry = META_NS::GetObjectRegistry();
    auto objContext = interface_pointer_cast<META_NS::IMetadata>(
        objRegistry.GetDefaultObjectContext());
    
    // 创建临时的 SceneManager
    return objRegistry.Create<SCENE_NS::ISceneManager>(
        SCENE_NS::ClassId::SceneManager, objContext);
}
```

**调用链路**：
```
SceneJS::Load()
    │
    ├─ CreateSceneManager(uri)  ← 创建临时 SceneManager
    │   └─ objRegistry.Create<ISceneManager>()
    │
    ├─ sceneManager->CreateScene(uri)
    │   └─ 创建 Scene 和 ECS
    │
    └─ sceneManager 销毁  ← 不保存！
```

---

## 3. 全局场景管理机制

### **3.1 场景注册到全局 ObjectRegistry**

虽然 SceneJS 不持有 SceneManager，但所有创建的场景会注册到**全局 ObjectRegistry**：

```cpp
// SceneJS.cpp:526
void SceneJS::AddScene(META_NS::IObjectRegistry* obr, SCENE_NS::IScene::Ptr scene)
{
    if (!obr) {
        return;
    }
    auto params = interface_pointer_cast<META_NS::IMetadata>(
        obr->GetDefaultObjectContext());
    if (!params) {
        return;
    }
    
    // 添加到全局 Scenes 列表
    auto duh = params->GetArrayProperty<IntfWeakPtr>("Scenes");
    if (!duh) {
        return;
    }
    duh->AddValue(interface_pointer_cast<CORE_NS::IInterface>(scene));
}
```

**全局场景列表**：
```
META_NS::ObjectRegistry (全局)
└─ DefaultObjectContext (Metadata)
   └─ "Scenes" ArrayProperty
      ├─ Scene1 (WeakPtr)
      ├─ Scene2 (WeakPtr)
      └─ Scene3 (WeakPtr)
```

---

### **3.2 刷新场景列表**

```cpp
// SceneJS.cpp:566
void SceneJS::FlushScenes()
{
    ExecSyncTask([]() {
        auto& obr = META_NS::GetObjectRegistry();
        if (auto params = interface_pointer_cast<META_NS::IMetadata>(
                obr.GetDefaultObjectContext())) {
            
            if (auto duh = params->GetArrayProperty<IntfWeakPtr>("Scenes")) {
                // 清理无效的弱引用
                for (auto i = 0; i < duh->GetSize();) {
                    auto w = duh->GetValueAt(i);
                    if (w.lock() == nullptr) {
                        duh->RemoveAt(i);  // 移除已销毁的场景
                    } else {
                        i++;
                    }
                }
            }
        }
        return META_NS::IAny::Ptr {};
    });
}
```

---

## 4. 完整的场景创建和管理架构

### **4.1 架构图**

```
┌─────────────────────────────────────────────────────────────┐
│  ArkTS 层                                                     │
│  const scene1 = await Scene.load("scene1.gltf");            │
│  const scene2 = await Scene.load("scene2.gltf");            │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ NAPI
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  SceneJS (C++ Wrapper)                                       │
│  ├─ scene1: SceneJS 实例                                     │
│  │   ├─ nativeObject_: IScene::Ptr  ← 指向 Scene1          │
│  │   └─ 不持有 SceneManager                                 │
│  │                                                          │
│  ├─ scene2: SceneJS 实例                                     │
│  │   ├─ nativeObject_: IScene::Ptr  ← 指向 Scene2          │
│  │   └─ 不持有 SceneManager                                 │
│  └─ ...                                                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 弱引用注册
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  META_NS::ObjectRegistry (全局)                              │
│  └─ DefaultObjectContext                                    │
│     └─ "Scenes" ArrayProperty                               │
│        ├─ WeakPtr → Scene1                                  │
│        ├─ WeakPtr → Scene2                                  │
│        └─ ...                                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 每个 Scene 有自己的 ECS
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Scene1 (InternalScene)                                     │
│  └─ ecs_: Ecs                                               │
│     ├─ nativeEcs_: IEcs::Ptr (独立 ECS)                     │
│     ├─ transformComponentManager                            │
│     ├─ cameraComponentManager                               │
│     └─ ...                                                  │
│                                                              │
│  Scene2 (InternalScene)                                     │
│  └─ ecs_: Ecs                                               │
│     ├─ nativeEcs_: IEcs::Ptr (独立 ECS)                     │
│     ├─ transformComponentManager                            │
│     ├─ cameraComponentManager                               │
│     └─ ...                                                  │
└─────────────────────────────────────────────────────────────┘
```

---

### **4.2 SceneManager 的生命周期**

```
SceneJS::Load()
    │
    │ 创建临时 SceneManager
    ▼
┌─────────────────────────────────────────────────────────────┐
│  SceneManager (临时对象)                                     │
│  ├─ context_: IRenderContext                                │
│  └─ opts_: SceneOptions                                     │
│                                                              │
│  生命周期：                                                  │
│  1. CreateSceneManager() 创建                               │
│  2. sceneManager->CreateScene(uri) 使用                     │
│  3. 函数结束，SceneManager 销毁                             │
└─────────────────────────────────────────────────────────────┘
    │
    │ 创建 Scene 对象（永久）
    ▼
┌─────────────────────────────────────────────────────────────┐
│  IScene (永久对象)                                           │
│  ├─ internal_: InternalScene                                │
│  │   └─ ecs_: Ecs (独立 ECS)                               │
│  └─ 注册到全局 ObjectRegistry                               │
│                                                              │
│  生命周期：                                                  │
│  1. sceneManager->CreateScene() 创建                        │
│  2. 返回给 SceneJS 包装                                      │
│  3. 注册到全局 Scenes 列表                                   │
│  4. SceneJS::Dispose() 时销毁                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 与 LumeCommon 的对比

### **5.1 LumeCommon 的场景管理**

```cpp
// LumeCommon 持有 Scene Adapter
class LumeCommon {
    SCENE_NS::IScene::Ptr attachedSceneApiScene_;
    bool hasAttachedSceneApi_ = false;
    std::shared_ptr<ISceneAdapter> sceneAdapter_;  // ← 持有 Adapter
};
```

**对比**：

| 特性 | SceneJS | LumeCommon |
|------|---------|------------|
| **持有 Scene** | ✅ 通过 BaseObject::nativeObject_ | ✅ attachedSceneApiScene_ |
| **持有 SceneManager** | ❌ 不持有 | ❌ 不持有 |
| **持有 Scene Adapter** | ✅ scene_ (可选) | ✅ sceneAdapter_ |
| **场景注册** | ✅ 全局 ObjectRegistry | ❌ 仅内部持有 |
| **多场景支持** | ✅ 多个 SceneJS 实例 | ⚠️ 通常一个 |

---

### **5.2 LumeCommon 持有 sceneAdapter_ 的详细分析**

#### **设计目的**

`LumeCommon::sceneAdapter_` 成员的主要目的是**保持 SceneAdapterXComponent 的生命周期**，防止其在渲染完成前被销毁。

#### **设置场景**

`sceneAdapter_` 在以下两个关键位置被设置：

**场景 1：CreateSceneJsObject 函数**
```cpp
// lume_xcomponent_manager.cpp:391
static napi_value CreateSceneJsObject(napi_env env, SCENE_NS::IScene::Ptr scene, 
                                       OHOS::Render3D::LumeCommon* lumeCommon)
{
    // ... 创建 JS Scene 对象 ...
    
#ifdef __SCENE_ADAPTER_XCOMPONENT__
    // 创建 SceneAdapterXComponent
    auto sceneAdapter = std::make_shared<OHOS::Render3D::SceneAdapterXComponent>();
    
    // 连接到 LumeCommon 渲染引擎
    if (lumeCommon) {
        sceneAdapter->AttachToEngine(lumeCommon, 0);
        LOGI("CreateSceneJsObject: SceneAdapterXComponent attached to engine");
    }
    
    // 设置 Scene 对象
    sceneAdapter->SetSceneObj(interface_pointer_cast<META_NS::IObject>(scene));
    
    // ★ 关键：存储到 LumeCommon 保持生命周期 ★
    lumeCommon->SetSceneAdapter(sceneAdapter);
#endif

    return jsscene.ToNapiValue();
}
```

**场景 2：LoadScene 的 convertToJs 回调**
```cpp
// lume_xcomponent_manager.cpp:588
auto convertToJs = [lumeCommon, sceneJs, env, engineQ, jsQ, 
                    createSceneFunc, loadGLB, setupRendering](
    SCENE_NS::IScene::Ptr scene) {
    
    // ... 创建 SceneJS 对象 ...
    
#ifdef __SCENE_ADAPTER_XCOMPONENT__
    // 创建 SceneAdapterXComponent
    auto sceneAdapter = std::make_shared<OHOS::Render3D::SceneAdapterXComponent>();
    
    // 连接到 LumeCommon 渲染引擎
    if (lumeCommon) {
        sceneAdapter->AttachToEngine(lumeCommon, 0);
        LOGI("convertToJs: SceneAdapterXComponent attached to engine");
    }
    
    // 设置 Scene 对象
    sceneAdapter->SetSceneObj(interface_pointer_cast<META_NS::IObject>(scene));
    
    // ★ 存储到 LumeCommon 保持生命周期 ★
    lumeCommon->SetSceneAdapter(sceneAdapter);
    
    // 同时存储到 SceneJS 供后续使用
    if (sceneJs) {
        sceneJs->scene_ = sceneAdapter;
    }
#endif
};
```

#### **生命周期管理架构**

```
┌─────────────────────────────────────────────────────────────┐
│  XComponent 渲染管理器                                        │
│  LumeXComponentManager                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 创建
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  LumeCommon (渲染引擎)                                        │
│  ├─ ecs_ : IEcs::Ptr                                        │
│  ├─ attachedSceneApiScene_ : IScene::Ptr                    │
│  └─ sceneAdapter_ : shared_ptr<ISceneAdapter>  ← 生命周期持有│
└─────────────────────────────────────────────────────────────┘
                              │
                              │ AttachToEngine
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  SceneAdapterXComponent                                     │
│  ├─ lumeCommon_ : LumeCommon*  ← 反向引用                   │
│  ├─ sceneObj_ : IObject::Ptr                                │
│  └─ 渲染桥接逻辑                                            │
│                                                              │
│  生命周期：                                                  │
│  1. 创建时 shared_ptr 引用计数 = 1                          │
│  2. lumeCommon->SetSceneAdapter() 保存     引用计数 = 2     │
│  3. sceneJs->scene_ = sceneAdapter         引用计数 = 3     │
│  4. 临时变量销毁                             引用计数 = 2   │
│  5. LumeCommon 销毁时释放                    引用计数 = 1   │
│  6. SceneJS 销毁时释放                       引用计数 = 0   │
└─────────────────────────────────────────────────────────────┘
```

#### **双重持有机制**

在 XComponent 融合模式下，`SceneAdapterXComponent` 被**两个地方同时持有**：

| 持有者 | 成员变量 | 目的 |
|--------|----------|------|
| **LumeCommon** | `sceneAdapter_` | **生命周期管理** - 防止适配器过早销毁 |
| **SceneJS** | `scene_` | **功能使用** - 用于 Scene 相关操作 |

```cpp
// LumeCommon.h:232
void SetSceneAdapter(std::shared_ptr<ISceneAdapter> adapter) { 
    sceneAdapter_ = BASE_NS::move(adapter); 
}

// SceneJS.h (可选成员)
#ifdef __SCENE_ADAPTER__
    std::shared_ptr<OHOS::Render3D::ISceneAdapter> scene_ = nullptr;
#endif
```

#### **为什么需要 LumeCommon 持有**

**问题场景**：如果不持有，会发生什么？

```cpp
// ❌ 错误示例：没有持有 sceneAdapter
void CreateScene() {
    auto sceneAdapter = std::make_shared<SceneAdapterXComponent>();
    sceneAdapter->AttachToEngine(lumeCommon, 0);
    sceneAdapter->SetSceneObj(scene);
    // 函数结束，sceneAdapter 销毁！
    // AttachToEngine 的 lumeCommon 变成悬空指针！
}

// ✅ 正确示例：LumeCommon 持有
void CreateScene() {
    auto sceneAdapter = std::make_shared<SceneAdapterXComponent>();
    sceneAdapter->AttachToEngine(lumeCommon, 0);
    sceneAdapter->SetSceneObj(scene);
    lumeCommon->SetSceneAdapter(sceneAdapter);  // ← 保持生命周期
    // 函数结束，sceneAdapter 仍然存活
}
```

**核心原因**：
1. `SceneAdapterXComponent::AttachToEngine()` 只保存原始指针 `LumeCommon*`
2. 如果 `sceneAdapter` 被销毁，`AttachToEngine` 的内部回调可能失效
3. `LumeCommon` 持有 `shared_ptr` 确保适配器在渲染周期内一直存在

#### **渲染流程中的使用**

```cpp
// LumeCommon::DrawSceneApiFrame()
void LumeCommon::DrawSceneApiFrame()
{
    if (!hasAttachedSceneApi_ || !attachedSceneApiScene_) {
        DrawFrame();  // 降级到原生渲染
        return;
    }

    // 1. 同步 Scene API 属性到 ECS
    auto internalScene = attachedSceneApiScene_->GetInternalScene();
    if (internalScene) {
        internalScene->Update(false);
    }

    // 2. 收集渲染句柄
    CollectRenderHandles();

    // 3. 使用共享 ECS 渲染
    auto* ecs = ecs_.get();
    if (engine_->TickFrame(BASE_NS::array_view(&ecs, 1))) {
        Tick(et.deltaTimeUs);
        
        if (customRender_) {
            customRender_->OnDrawFrame();
        }

        // 4. 渲染帧
        GetRenderContext()->GetRenderer().RenderFrame(
            BASE_NS::array_view(renderHandles_.data(), renderHandles_.size()));
    }
}
```

**注意**：`DrawSceneApiFrame()` 主要使用 `attachedSceneApiScene_`，而不是直接使用 `sceneAdapter_`。
`sceneAdapter_` 的主要作用是**生命周期管理**，而非直接用于渲染逻辑。

---

### **5.3 SceneJS 与 LumeCommon 架构对比**

| 特性 | SceneJS | LumeCommon |
|------|---------|------------|
| **设计目的** | ArkTS Scene API | XComponent 渲染引擎 |
| **场景管理** | 全局 ObjectRegistry | 内部持有 |
| **ECS 来源** | 每个 Scene 独立创建 | 可共享外部 ECS |
| **渲染集成** | 通过 Scene Adapter | 直接渲染 |
| **Adapter 持有** | `scene_` (功能使用) | `sceneAdapter_` (生命周期) |
| **多实例** | ✅ 多个 SceneJS 实例 | ⚠️ 通常单例 |

---

### **5.4 SceneJS::Load 的 sceneAdapter 持有机制对比**

#### **SceneJS 的 sceneAdapter 持有方式**

SceneJS 也持有 `sceneAdapter`，但其生命周期管理与 LumeCommon 不同：

**SceneJS.h:45**
```cpp
class SceneJS : public BaseObject {
#ifdef __SCENE_ADAPTER__
    std::shared_ptr<OHOS::Render3D::ISceneAdapter> scene_ = nullptr;
#endif
};
```

**SceneJS.cpp:316, 321**
```cpp
// Fusion Mode (XComponent)
auto sceneAdapter = std::make_shared<OHOS::Render3D::SceneAdapterXComponent>();
sceneAdapter->SetSceneObj(interface_pointer_cast<META_NS::IObject>(scene));
sceneJs->scene_ = sceneAdapter;  // ← 持有到 SceneJS 实例

// Standalone Mode
auto sceneAdapter = std::make_shared<OHOS::Render3D::SceneAdapter>();
sceneAdapter->SetSceneObj(interface_pointer_cast<META_NS::IObject>(scene));
sceneJs->scene_ = sceneAdapter;  // ← 持有到 SceneJS 实例
```

**SceneJS.cpp:373-378 (Dispose 时清理)**
```cpp
napi_value SceneJS::Dispose(NapiApi::FunctionContext<>& ctx)
{
    DisposeNative(nullptr);
#ifdef __SCENE_ADAPTER__
    if (scene_) {
        scene_->Deinit();  // ← 销毁时调用 Deinit
    }
#endif
    return {};
}
```

---

#### **SceneJS 与 LumeCommon 持有机制对比**

| 特性 | SceneJS | LumeCommon |
|------|---------|------------|
| **成员变量** | `scene_` | `sceneAdapter_` |
| **类型** | `std::shared_ptr<ISceneAdapter>` | `std::shared_ptr<ISceneAdapter>` |
| **设置位置** | `SceneJS::Load` → `convertToJs` | `LumeXComponentManager::CreateSceneJsObject` / `convertToJs` |
| **设置时机** | Scene 创建完成后 | Scene 创建完成前（CreateSceneJsObject 中） |
| **清理方式** | `scene_->Deinit()` | 自动释放（shared_ptr 析构） |
| **生命周期** | 与 SceneJS 实例相同 | 与 LumeCommon 实例相同 |
| **持有目的** | **功能使用** + 生命周期管理 | **生命周期管理** 为主 |
| **双重持有** | ✅ 与 LumeCommon 同时持有 | ✅ 与 SceneJS 同时持有 |

---

#### **为什么需要双重持有？**

在 XComponent Fusion Mode 下，`SceneAdapterXComponent` 被**两个地方同时持有**：

```
┌─────────────────────────────────────────────────────────────┐
│  SceneAdapterXComponent                                     │
│  引用计数 = 2                                               │
└─────────────────────────────────────────────────────────────┘
           ↑                        ↑
           │                        │
    ┌──────┴────────┐      ┌────────┴────────┐
    │   SceneJS     │      │   LumeCommon    │
    │   scene_      │      │   sceneAdapter_ │
    └───────────────┘      └─────────────────┘
    功能使用：             生命周期管理：
    - Scene 操作           - 防止过早销毁
    - 渲染桥接             - 保持引擎连接
```

**原因分析**：

1. **SceneJS 持有 (`scene_`)**：
   - 提供 Scene API 相关的功能（如节点操作、相机切换等）
   - 在 `Dispose()` 时调用 `Deinit()` 清理资源
   - 生命周期与 SceneJS 实例绑定

2. **LumeCommon 持有 (`sceneAdapter_`)**：
   - 确保 `AttachToEngine` 的连接不会失效
   - 在渲染周期内保持适配器存活
   - 生命周期与 LumeCommon 实例绑定

3. **双重保险**：
   - 即使 SceneJS 被销毁，LumeCommon 仍持有适配器，渲染系统不会崩溃
   - 即使 LumeCommon 先销毁，SceneJS 仍可操作 Scene（但无法渲染）
   - 两者相互独立，避免单点故障

---

#### **生命周期时序图**

```
SceneJS::Load() 调用
    │
    ├─ CreateSceneManager()
    ├─ sceneManager->CreateScene(uri)
    │
    └─ convertToJs 回调
        │
        ├─ 创建 SceneJS 实例
        │
        ├─ [LumeXComponentManager 路径]
        │   ├─ 创建 SceneAdapterXComponent
        │   ├─ sceneAdapter->AttachToEngine(lumeCommon, 0)
        │   ├─ lumeCommon->SetSceneAdapter(sceneAdapter)  ← LumeCommon 持有
        │   └─ sceneJs->scene_ = sceneAdapter             ← SceneJS 持有
        │
        └─ [SceneJS::Load 独立路径]
            ├─ 创建 SceneAdapterXComponent
            ├─ 尝试从 GraphicsManager 获取引擎
            ├─ sceneAdapter->AttachToEngine(engine, key)
            └─ sceneJs->scene_ = sceneAdapter             ← SceneJS 持有

SceneJS 销毁时 (~SceneJS / Dispose)
    │
    └─ scene_->Deinit()  ← 清理适配器资源

LumeCommon 销毁时
    │
    └─ sceneAdapter_ 自动释放 (shared_ptr 析构)
```

---

### **5.5 多场景加载示例**

```typescript
// ArkTS 加载多个场景
const scene1 = await Scene.load("scene1.gltf");
const scene2 = await Scene.load("scene2.gltf");
const scene3 = await Scene.load("scene3.gltf");

// 每个场景独立
scene1.root.position = { x: 0, y: 0, z: 0 };
scene2.root.position = { x: 10, y: 0, z: 0 };
scene3.root.position = { x: 20, y: 0, z: 0 };
```

**C++ 对应**：
```cpp
// 每个 Scene.load() 调用
SceneJS::Load()
    │
    ├─ 创建临时 SceneManager
    ├─ sceneManager->CreateScene() → 创建 Scene1
    ├─ SceneJS1::nativeObject_ = Scene1
    ├─ 注册 Scene1 到全局 ObjectRegistry
    └─ SceneManager 销毁

// 再次调用
SceneJS::Load()
    │
    ├─ 创建新的临时 SceneManager
    ├─ sceneManager->CreateScene() → 创建 Scene2
    ├─ SceneJS2::nativeObject_ = Scene2
    ├─ 注册 Scene2 到全局 ObjectRegistry
    └─ SceneManager 销毁

// 结果：
// - SceneJS1 持有 Scene1
// - SceneJS2 持有 Scene2
// - 全局 ObjectRegistry 有 [Scene1, Scene2] 列表
// - 每个 Scene 有独立的 ECS
```

---

## 6. ECS 管理

### **6.1 每个 Scene 独立的 ECS**

```cpp
// 每个 Scene 创建时都会创建自己的 ECS
SceneObject::Build()
    │
    └─ InternalScene::Initialize()
        │
        └─ ecs_.reset(new Ecs)
            │
            └─ ecs_->Initialize()
                │
                ├─ nativeEcs_ = engine_->CreateEcs()  ← 新 ECS
                └─ 创建 Component Managers

// 结果：
// Scene1.ecs_.nativeEcs_ → ECS1 (独立)
// Scene2.ecs_.nativeEcs_ → ECS2 (独立)
// Scene3.ecs_.nativeEcs_ → ECS3 (独立)
```

---

### **6.2 全局场景列表的作用**

```cpp
// 全局场景列表用于：
// 1. 场景销毁时清理
// 2. 遍历所有场景
// 3. 资源管理

// SceneJS::DisposeNative()
void SceneJS::DisposeNative(void*)
{
    // 销毁所有关联的对象
    while (!strongDisposables_.empty()) {
        auto it = strongDisposables_.begin();
        auto obj = it->second.GetObject();
        if (obj) {
            // 调用 dispose 方法
            NapiApi::Function func = obj.Get<NapiApi::Function>("destroy");
            if (func) {
                func.Invoke(obj, 1, &scene);
            }
        }
        strongDisposables_.erase(strongDisposables_.begin());
    }
    
    // 清理全局场景列表
    FlushScenes();
}
```

---

## 7. 总结

### **问题回答**

| 问题 | 答案 | 说明 |
|------|------|------|
| **SceneJS 持有唯一的 SceneManager 吗？** | ❌ 否 | SceneManager 是临时创建的，用完即弃 |
| **SceneJS 记录所有 load 的场景吗？** | ⚠️ 部分 | 通过全局 ObjectRegistry 的弱引用列表 |
| **每个 Scene 有独立的 ECS 吗？** | ✅ 是 | 每个 Scene 创建时都会创建自己的 ECS |
| **如何管理多个场景？** | 全局 ObjectRegistry | "Scenes" ArrayProperty 存储弱引用 |

### **架构特点**

1. **去中心化管理** - 没有唯一的 SceneManager
2. **临时 SceneManager** - 创建场景时使用，用完销毁
3. **全局场景列表** - ObjectRegistry 维护弱引用列表
4. **独立 ECS** - 每个 Scene 有自己的 ECS 和 Managers
5. **SceneJS 包装** - 每个 Scene 对应一个 SceneJS 实例

---

## 8. SceneJS 独立管理场景的可行性分析

### **8.1 核心问题**

**问题**: 如果想要让 SceneJS 单独管理其场景的存在性，是不是只需要使用 SceneJS 的方案？

**简短回答**: ✅ **是的**，但需要注意以下几点：

1. SceneJS 已经可以独立管理场景的生命周期
2. 但**渲染**需要依赖外部的 LumeCommon/XComponent 引擎
3. 双重持有机制是为了**融合模式**下的稳定性

---

### **8.2 SceneJS 独立管理场景的能力**

#### **SceneJS 已具备的能力**

| 能力 | 实现方式 | 状态 |
|------|----------|------|
| **场景创建** | `SceneJS::Load()` → `SceneManager::CreateScene()` | ✅ 独立 |
| **场景持有** | `BaseObject::nativeObject_` + `scene_` (SceneAdapter) | ✅ 独立 |
| **场景销毁** | `SceneJS::Dispose()` → `scene_->Deinit()` | ✅ 独立 |
| **ECS 管理** | 每个 Scene 自带独立 ECS | ✅ 独立 |
| **全局注册** | `ObjectRegistry::Scenes` 弱引用列表 | ✅ 独立 |

**结论**: SceneJS **完全有能力**独立管理场景的生命周期，不需要依赖 LumeCommon。

---

### **8.3 为什么需要 LumeCommon 持有 sceneAdapter_？**

#### **问题根源：渲染引擎分离**

```
┌─────────────────────────────────────────────────────────────┐
│  ArkTS 层                                                     │
│  const scene = await Scene.load("scene.gltf");              │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ NAPI
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  SceneJS (C++ Wrapper)                                       │
│  ├─ nativeObject_: IScene::Ptr  ← 场景数据                  │
│  ├─ scene_: SceneAdapter  ← 桥接                            │
│  └─ ECS: 独立 ECS  ← 场景数据                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ SceneAdapter::AttachToEngine
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  LumeCommon (渲染引擎)                                        │
│  ├─ ecs_: IEcs::Ptr  ← 渲染使用的 ECS                        │
│  ├─ sceneAdapter_: 保持 SceneAdapter 生命周期               │
│  └─ DrawFrame(): 渲染输出到 XComponent                       │
└─────────────────────────────────────────────────────────────┘
```

**关键点**：
1. **SceneJS 负责场景管理** - 创建、持有、销毁
2. **LumeCommon 负责渲染输出** - 将 ECS 数据渲染到 XComponent
3. **SceneAdapter 是桥梁** - 连接 SceneJS 的 ECS 和 LumeCommon 的渲染

---

#### **为什么 LumeCommon 需要持有 sceneAdapter_？**

**原因 1：生命周期独立性**

```cpp
// ❌ 如果 LumeCommon 不持有 sceneAdapter_
SceneJS::Load()
    │
    ├─ convertToJs 回调
    │   ├─ 创建 sceneAdapter
    │   ├─ sceneAdapter->AttachToEngine(lumeCommon)
    │   └─ sceneJs->scene_ = sceneAdapter  ← 只有 SceneJS 持有
    │
    └─ 函数结束，临时 shared_ptr 销毁

// 问题：
// 1. SceneJS 销毁时，sceneAdapter 被销毁
// 2. LumeCommon 的 AttachToEngine 内部回调变成悬空指针
// 3. 下一次 DrawFrame() 可能崩溃
```

```cpp
// ✅ LumeCommon 持有 sceneAdapter_
SceneJS::Load()
    │
    ├─ convertToJs 回调
    │   ├─ 创建 sceneAdapter
    │   ├─ sceneAdapter->AttachToEngine(lumeCommon)
    │   ├─ lumeCommon->SetSceneAdapter(sceneAdapter)  ← 双重持有
    │   └─ sceneJs->scene_ = sceneAdapter
    │
    └─ 函数结束

// 优点：
// 1. SceneJS 销毁后，LumeCommon 仍持有 sceneAdapter
// 2. AttachToEngine 的连接保持有效
// 3. 渲染系统稳定运行
```

**原因 2：渲染引擎的独立性**

LumeCommon 可能在没有 SceneJS 的情况下运行：

```cpp
// LumeCommon 独立渲染模式（不使用 SceneJS）
auto lumeCommon = std::make_unique<LumeCommon>();
lumeCommon->InitEngine(eglContext, platformData);
lumeCommon->LoadSceneModel("scene.gltf");  // 使用原生加载
while (running) {
    lumeCommon->DrawFrame();  // 直接渲染
}
```

在这种情况下，LumeCommon 需要自己管理 sceneAdapter。

---

### **8.4 使用场景对比**

#### **场景 1: 纯 SceneJS 方案（推荐用于简单场景）**

```typescript
// ArkTS - 纯 SceneJS 方案
import { Scene } from '@kit.SceneKit';

// 加载场景
const scene = await Scene.load("scene.gltf");

// 操作场景
scene.root.position = { x: 0, y: 0, z: 0 };

// 销毁场景
scene.dispose();
```

**特点**：
- ✅ 简单直接
- ✅ 完全由 SceneJS 管理
- ⚠️ **需要 XComponent 提供渲染输出**（通过 SceneAdapter 自动连接）

**C++ 对应**：
```cpp
// SceneJS::Load 自动处理所有事情
SceneJS::Load()
    │
    ├─ 创建 Scene 和 ECS
    ├─ 创建 SceneAdapter
    ├─ 自动连接到 GraphicsManager 中的引擎
    └─ SceneJS 持有 scene_
```

---

#### **场景 2: SceneJS + LumeCommon 融合模式（推荐用于复杂应用）**

```typescript
// ArkTS - 融合模式
import { XComponent, Scene } from '@kit.ArkUI';

// 1. 创建 XComponent 渲染后端
<XComponent
  type="scene"
  onXComponentReady={() => {
    // 2. 加载 SceneJS 场景
    const scene = await Scene.load("scene.gltf");
    // 3. 自动连接到 XComponent 渲染
  }}
/>
```

**特点**：
- ✅ 双重持有，更稳定
- ✅ SceneJS 管理场景，LumeCommon 管理渲染
- ✅ 支持多场景、多 ECS
- ⚠️ 架构稍复杂

**C++ 对应**：
```cpp
// LumeXComponentManager::LoadScene
LoadScene()
    │
    ├─ 获取 LumeCommon (从 XComponent)
    ├─ 获取 ECS (从 LumeCommon)
    ├─ 创建 Scene (使用外部 ECS)
    ├─ 创建 SceneAdapterXComponent
    ├─ sceneAdapter->AttachToEngine(lumeCommon)
    ├─ lumeCommon->SetSceneAdapter(sceneAdapter)  ← 双重持有
    └─ sceneJs->scene_ = sceneAdapter
```

---

### **8.5 架构决策建议**

| 需求 | 推荐方案 | 原因 |
|------|----------|------|
| **简单 3D 展示** | 纯 SceneJS | 简单直接，自动连接渲染 |
| **复杂交互应用** | SceneJS + LumeCommon | 双重持有，更稳定 |
| **多场景管理** | SceneJS + LumeCommon | 支持多 ECS、多相机 |
| **自定义渲染** | LumeCommon 独立 | 完全控制渲染流程 |
| **跨平台兼容** | 纯 SceneJS | 不依赖 XComponent |

---

### **8.6 总结**

**问题回答**：

> 如果想要让 SceneJS 单独管理其场景的存在性，是不是只需要使用 SceneJS 的方案？

**答案**：

1. ✅ **是的**，SceneJS 可以独立管理场景的生命周期（创建、持有、销毁）
2. ⚠️ **但**渲染输出需要依赖 SceneAdapter 连接到渲染引擎
3. 💡 **双重持有** (`scene_` + `sceneAdapter_`) 是为了在融合模式下保证稳定性

**架构图**：

```
┌─────────────────────────────────────────────────────────────┐
│                     SceneJS 独立管理                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  场景创建   │───▶│  场景持有   │───▶│  场景销毁   │     │
│  │  Load()     │    │  nativeObj  │    │  Dispose()  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                  │                  │              │
│         ▼                  ▼                  ▼              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              SceneAdapter (桥梁)                     │   │
│  │  • AttachToEngine()  ← 连接渲染引擎                 │   │
│  │  • SetSceneObj()     ← 绑定场景对象                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ 可选连接
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  LumeCommon (渲染引擎)                        │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  sceneAdapter_ (生命周期管理)                        │   │
│  │  • 防止 SceneAdapter 过早销毁                        │   │
│  │  • 保持 AttachToEngine 连接有效                      │   │
│  └─────────────────────────────────────────────────────┘   │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  获取 ECS   │───▶│  收集句柄   │───▶│  DrawFrame  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

**核心结论**：
- SceneJS **可以**独立管理场景存在性
- LumeCommon 持有 sceneAdapter_ 是为了**渲染稳定性**，而非场景管理
- 双重持有是**融合模式**下的最佳实践，而非必须

### **与 LumeCommon 的区别**

| 特性 | SceneJS | LumeCommon |
|------|---------|------------|
| **设计目的** | ArkTS Scene API | XComponent 渲染引擎 |
| **场景管理** | 全局 ObjectRegistry | 内部持有 |
| **ECS 来源** | 每个 Scene 独立创建 | 可共享外部 ECS |
| **渲染集成** | 通过 Scene Adapter | 直接渲染 |

---

**文档结束**
