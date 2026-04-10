# Scene 创建时的 ECS 创建链路分析

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 7 日

---

## 1. 核心结论

**问题**: Scene 在 create 之后会创建一个相应的 ECS 吗？

**答案**: ✅ **是的！每个 Scene 创建时都会创建独立的 ECS**

---

## 2. 完整调用链路

### **2.1 调用链概览**

```
ArkTS: Scene.load("scene://default")
    │
    ▼ NAPI
SceneJS::Load()                              [SceneJS.cpp:233]
    │
    ├─ CreateSceneManager(uri)               [SceneJS.cpp:353]
    │   └─ objRegistry.Create<ISceneManager>()
    │
    ├─ sceneManager->CreateScene(uri)        [scene_manager.cpp:118]
    │   └─ context_->AddTask([...])
    │       │
    │       └─ Create<IScene>(ClassId::Scene)
    │           │
    │           └─ SceneObject::Build()      [scene.cpp:49]
    │               │
    │               └─ InternalScene::Initialize()  [internal_scene.cpp:59]
    │                   │
    │                   └─ Ecs::Initialize()        [ecs.cpp:46]
    │                       │
    │                       ├─ ecs = engine.CreateEcs()  ← 创建 ECS！
    │                       └─ 创建 Component Managers
    │
    └─ convertToJs(scene)
        └─ 返回 SceneJS 对象
```

---

## 3. 关键代码位置

### **3.1 SceneJS::Load (入口)**

**文件**: `d:\Workspace\HarmonyProject\DayNote\entry\src\main\cpp\nativerender\kits\src\SceneJS.cpp`  
**行号**: 233-348

```cpp
// SceneJS.cpp:233
napi_value SceneJS::Load(NapiApi::FunctionContext<>& ctx)
{
    const auto env = ctx.Env();
    auto promise = Promise(env);
    
    // 1. 创建 SceneManager
    auto sceneManager = CreateSceneManager(uri);
    if (!sceneManager) {
        return promise.Reject("Creating scene manager failed");
    }
    
    // 2. 创建 Scene（异步）
    sceneManager->CreateScene(uri)
        .Then(BASE_NS::move(massageScene), engineQ)
        .Then(BASE_NS::move(convertToJs), jsQ);
    
    return promise;
}
```

---

### **3.2 SceneManager::CreateScene**

**文件**: `d:\Workspace\HarmonyProject\DayNote\entry\src\main\cpp\nativerender\LumeScene\src\scene_manager.cpp`  
**行号**: 118-148

```cpp
// scene_manager.cpp:118
Future<IScene::Ptr> SceneManager::CreateScene(BASE_NS::string_view uri, SceneOptions opts)
{
    if (uri == "" || uri == "scene://empty") {
        return CreateScene(BASE_NS::move(opts));
    }
    
    return context_->AddTask(
        [path = BASE_NS::string(uri), renderContext = context_, args = CreateContext(BASE_NS::move(opts))] {
            IScene::Ptr result;
            
            // 创建 Scene 对象
            result = META_NS::GetObjectRegistry().Create<IScene>(
                SCENE_NS::ClassId::Scene, args);
            
            // 加载场景文件（GLTF 等）
            Load(result, path);
            
            return result;
        });
}
```

---

### **3.3 SceneObject::Build**

**文件**: `d:\Workspace\HarmonyProject\DayNote\entry\src\main\cpp\nativerender\LumeScene\src\scene.cpp`  
**行号**: 49-67

```cpp
// scene.cpp:49
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
        
        // ========== 初始化 InternalScene（会创建 ECS）==========
        res = internal_->Initialize();
    }
    return res;
}
```

---

### **3.4 InternalScene::Initialize**

**文件**: `d:\Workspace\HarmonyProject\DayNote\entry\src\main\cpp\nativerender\LumeScene\src\core\internal_scene.cpp`  
**行号**: 59-70

```cpp
// internal_scene.cpp:59
bool InternalScene::Initialize()
{
    LOGI("InternalScene::Initialize: externalEcs_=%{public}p, externalEcsId=%{public}lu",
        externalEcs_.get(), externalEcs_ ? externalEcs_->GetId() : 0);
    
    // ========== 创建 Ecs 包装器 ==========
    ecs_.reset(new Ecs);
    
    // ========== 初始化 ECS（创建真正的 ECS 实例）==========
    if (!ecs_->Initialize(self_.lock(), options_, externalEcs_)) {
        CORE_LOG_E("failed to initialize ecs");
        return false;
    }
    return true;
}
```

**关键点**：
- 第 61 行：`ecs_.reset(new Ecs)` - 创建 Ecs 包装器
- 第 63 行：`ecs_->Initialize(...)` - 初始化 ECS，**实际创建 ECS 实例**

---

### **3.5 Ecs::Initialize (最终创建 ECS)**

**文件**: `d:\Workspace\HarmonyProject\DayNote\entry\src\main\cpp\nativerender\LumeScene\src\core\ecs.cpp`  
**行号**: 46-160

```cpp
// ecs.cpp:46
bool Ecs::Initialize(const BASE_NS::shared_ptr<IInternalScene>& scene, const SceneOptions& opts,
                     CORE_NS::IEcs::Ptr externalEcs)
{
    using namespace CORE_NS;
    scene_ = scene;
    auto& context = scene->GetRenderContext();
    auto& engine = context.GetEngine();
    
    LOGI("Ecs::Initialize: externalEcs=%{public}p, externalEcsId=%{public}lu",
        externalEcs.get(), externalEcs ? externalEcs->GetId() : 0);
    
    // ========== 关键：创建或使用外部 ECS ==========
    if (externalEcs) {
        // Fusion Mode: 使用外部 ECS
        ecs = externalEcs;
        useExternalEcs_ = true;
        LOGI("Using external ECS for Scene API fusion, ecsId=%{public}lu", ecs->GetId());
    } else {
        // Normal Mode: 创建新的 ECS ⭐⭐⭐
        ecs = engine.CreateEcs();  // ← 创建 ECS！
        useExternalEcs_ = false;
        LOGI("Created new ECS, ecsId=%{public}lu", ecs->GetId());
    }
    
    ecs->SetRenderMode(CORE_NS::IEcs::RENDER_ALWAYS);
    
    // 加载系统图（如果有自定义）
    if (!opts.systemGraphUri.empty()) {
        auto* factory = GetInstance<ISystemGraphLoaderFactory>(UID_SYSTEM_GRAPH_LOADER);
        auto systemGraphLoader = factory->Create(engine.GetFileManager());
        systemGraphLoader->Load(opts.systemGraphUri, *ecs);
    }
    
    // 初始化 ECS
    ecs->Initialize();
    
    // ========== 创建 Component Managers ⭐⭐⭐ ==========
    animationComponentManager = GetCoreManager<CORE3D_NS::IAnimationComponentManager>();
    cameraComponentManager = GetCoreManager<CORE3D_NS::ICameraComponentManager>();
    envComponentManager = GetCoreManager<CORE3D_NS::IEnvironmentComponentManager>();
    layerComponentManager = GetCoreManager<CORE3D_NS::ILayerComponentManager>();
    lightComponentManager = GetCoreManager<CORE3D_NS::ILightComponentManager>();
    materialComponentManager = GetCoreManager<CORE3D_NS::IMaterialComponentManager>();
    meshComponentManager = GetCoreManager<CORE3D_NS::IMeshComponentManager>();
    nameComponentManager = GetCoreManager<CORE3D_NS::INameComponentManager>();
    nodeComponentManager = GetCoreManager<CORE3D_NS::INodeComponentManager>();
    renderMeshComponentManager = GetCoreManager<CORE3D_NS::IRenderMeshComponentManager>();
    rhComponentManager = GetCoreManager<CORE3D_NS::IRenderHandleComponentManager>();
    transformComponentManager = GetCoreManager<CORE3D_NS::ITransformComponentManager>();
    uriComponentManager = GetCoreManager<CORE3D_NS::IUriComponentManager>();
    renderConfigComponentManager = GetCoreManager<CORE3D_NS::IRenderConfigurationComponentManager>();
    postProcessComponentManager = GetCoreManager<CORE3D_NS::IPostProcessComponentManager>();
    localMatrixComponentManager = GetCoreManager<CORE3D_NS::ILocalMatrixComponentManager>();
    worldMatrixComponentManager = GetCoreManager<CORE3D_NS::IWorldMatrixComponentManager>();
    
    // 获取 NodeSystem
    nodeSystem = GetSystem<CORE3D_NS::INodeSystem>(*ecs);
    
    // ... 更多初始化
    
    return true;
}
```

**关键行号**：
- **第 64 行**: `ecs = engine.CreateEcs()` - **创建新的 ECS 实例**
- **第 77-97 行**: 创建所有 Component Managers

---

## 4. ECS 创建流程图

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SceneJS::Load()                                          │
│    位置：SceneJS.cpp:233                                    │
│    作用：NAPI 入口，创建临时 SceneManager                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. SceneManager::CreateScene()                              │
│    位置：scene_manager.cpp:118                              │
│    作用：创建 Scene 对象                                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. SceneObject::Build()                                     │
│    位置：scene.cpp:49                                       │
│    作用：创建 InternalScene                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. InternalScene::Initialize()                              │
│    位置：internal_scene.cpp:59                              │
│    作用：创建 Ecs 包装器，调用 Ecs::Initialize()             │
│    关键代码：                                                │
│      ecs_.reset(new Ecs);                                   │
│      ecs_->Initialize(...);                                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Ecs::Initialize()                                        │
│    位置：ecs.cpp:46                                         │
│    作用：创建真正的 ECS 实例和 Component Managers            │
│    关键代码：                                                │
│      ecs = engine.CreateEcs();  ← 创建 ECS！                │
│      transformComponentManager = GetCoreManager<...>();     │
│      cameraComponentManager = GetCoreManager<...>();        │
│      ...                                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 两种模式对比

### **5.1 Normal Mode（普通模式）**

```cpp
// Ecs::Initialize 检查
if (externalEcs) {
    // 使用外部 ECS
    ecs = externalEcs;
} else {
    // ⭐ 创建新的 ECS
    ecs = engine.CreateEcs();  // ← 第 64 行
}
```

**结果**：
- ✅ 创建新的 ECS 实例
- ✅ 创建独立的 Component Managers
- ✅ 与其他 Scene 完全独立

---

### **5.2 Fusion Mode（融合模式）**

```cpp
// 在 ECS 初始化前设置外部 ECS
scene->GetInternalScene()->SetExternalEcs(lumeEcs);

// InternalScene::Initialize
ecs_.reset(new Ecs);
ecs_->Initialize(self_.lock(), options_, externalEcs_);
// ↑ externalEcs_ 不为空，会使用外部 ECS

// Ecs::Initialize
if (externalEcs) {
    ecs = externalEcs;  // ← 使用外部 ECS
    useExternalEcs_ = true;
}
```

**结果**：
- ✅ 使用外部 ECS（如 LumeCommon 的 ECS）
- ✅ Component Managers 从外部 ECS 获取
- ✅ 与外部 ECS 共享数据

---

## 6. 创建的 Component Managers 列表

在 `Ecs::Initialize()` 中创建的所有 Managers：

| Manager | 类型 | 用途 |
|---------|------|------|
| `animationComponentManager` | IAnimationComponentManager | 动画组件 |
| `cameraComponentManager` | ICameraComponentManager | 相机组件 |
| `envComponentManager` | IEnvironmentComponentManager | 环境组件 |
| `layerComponentManager` | ILayerComponentManager | 图层组件 |
| `lightComponentManager` | ILightComponentManager | 灯光组件 |
| `materialComponentManager` | IMaterialComponentManager | 材质组件 |
| `meshComponentManager` | IMeshComponentManager | 网格组件 |
| `nameComponentManager` | INameComponentManager | 名称组件 |
| `nodeComponentManager` | INodeComponentManager | 节点组件 |
| `renderMeshComponentManager` | IRenderMeshComponentManager | 渲染网格组件 |
| `rhComponentManager` | IRenderHandleComponentManager | 渲染句柄组件 |
| `transformComponentManager` | ITransformComponentManager | 变换组件 |
| `uriComponentManager` | IUriComponentManager | URI 组件 |
| `renderConfigComponentManager` | IRenderConfigurationComponentManager | 渲染配置组件 |
| `postProcessComponentManager` | IPostProcessComponentManager | 后处理组件 |
| `localMatrixComponentManager` | ILocalMatrixComponentManager | 本地矩阵组件 |
| `worldMatrixComponentManager` | IWorldMatrixComponentManager | 世界矩阵组件 |
| `morphComponentManager` | IMorphComponentManager | 变形组件 |

---

## 7. 总结

### **ECS 创建位置总结**

| 步骤 | 文件 | 行号 | 作用 |
|------|------|------|------|
| 1 | `SceneJS.cpp` | 233 | NAPI 入口 |
| 2 | `scene_manager.cpp` | 118 | 创建 SceneManager |
| 3 | `scene.cpp` | 49 | 创建 InternalScene |
| 4 | `internal_scene.cpp` | 59 | 创建 Ecs 包装器 |
| 5 | `ecs.cpp` | 64 | **创建真正的 ECS 实例** ⭐ |

### **关键代码行**

```cpp
// ecs.cpp:64
ecs = engine.CreateEcs();  // ← ECS 创建位置！
```

### **每个 Scene 都有独立的 ECS**

- ✅ 每个 Scene 创建时都会调用 `Ecs::Initialize()`
- ✅ `Ecs::Initialize()` 会调用 `engine.CreateEcs()`
- ✅ 每个 ECS 有独立的 Component Managers
- ✅ 多个 Scene 之间 ECS 互不影响

---

**文档结束**
