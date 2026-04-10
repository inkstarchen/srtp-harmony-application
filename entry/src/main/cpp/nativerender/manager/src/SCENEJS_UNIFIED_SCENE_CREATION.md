# SceneJS 统一场景创建方案

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 9 日  
**状态**: 方案设计

---

## 1. 核心问题

**当前问题**: `SceneJS::Load()` 和 `LumeXComponentManager::LoadScene()` 存在功能重叠，导致：
1. 场景创建逻辑分散在两处
2. 代码重复维护成本高
3. 架构职责不清晰

**目标**: 将场景创建全权交给 `SceneJS`，通过 `BindNode` 接收场景对象并连接到渲染后端。

---

## 2. 当前架构分析

### 2.1 功能重叠对比

| 功能 | SceneJS::Load | LumeXComponentManager::LoadScene | 重叠度 |
|------|---------------|----------------------------------|--------|
| **SceneManager 创建** | ✅ | ✅ | 🔴 完全重叠 |
| **场景创建** | ✅ `sceneManager->CreateScene()` | ✅ `sceneManager->Create<IScene>()` | 🔴 完全重叠 |
| **GLB 加载** | ✅ (内部) | ✅ `assets->Load()` | 🔴 完全重叠 |
| **ECS 获取** | ✅ (Scene 内部) | ✅ `scene->GetInternalScene()` | 🔴 完全重叠 |
| **JS 对象创建** | ✅ `CreateFromNativeInstance` | ✅ `CreateFromNativeInstance` | 🔴 完全重叠 |
| **环境设置** | ✅ 默认环境 | ✅ 默认环境 | 🔴 完全重叠 |
| **SceneAdapter 创建** | ✅ | ✅ | 🔴 完全重叠 |
| **引擎连接** | ✅ `AttachToEngine` | ✅ `AttachToEngine` | 🔴 完全重叠 |
| **LumeCommon 绑定** | ❌ | ✅ `SetEcs()` + `AttachSceneApiScene()` | 🟢 独有 |
| **渲染初始化** | ❌ | ✅ `InitializeScene()` | 🟢 独有 |

### 2.2 当前调用链路对比

#### **SceneJS::Load 调用链**
```
ArkTS: Scene.load("scene.gltf")
    │
    ▼
SceneJS::Load()
    │
    ├─ CreateSceneManager()
    ├─ sceneManager->CreateScene(uri)
    │   └─ 创建 Scene 和内部 ECS
    ├─ massageScene()
    │   └─ 创建根节点、修复名称、注册到全局
    └─ convertToJs()
        ├─ 创建 JS Scene 对象
        ├─ 设置默认环境
        ├─ 创建 SceneAdapter
        └─ sceneJs->scene_ = sceneAdapter
```

#### **LumeXComponentManager::LoadScene 调用链**
```
ArkTS: renderer.loadScene(nodeId, "scene.gltf")
    │
    ▼
LumeXComponentManager::LoadScene()
    │
    ├─ GetRenderer(nodeId)
    ├─ GetLumeCommon()
    ├─ GetEcs() from LumeCommon
    ├─ CreateSceneManager()
    ├─ createSceneFunc()
    │   └─ 创建 Scene 对象
    ├─ loadGLB()
    │   └─ assets->Load(scene, gltfPath)
    ├─ setupRendering()
    │   ├─ Get Scene's ECS
    │   ├─ lumeCommon->SetEcs(sceneEcs)  ← 关键：绑定 ECS
    │   └─ lumeCommon->InitializeScene()  ← 关键：初始化渲染
    ├─ massageScene()
    └─ convertToJs()
        ├─ lumeCommon->AttachSceneApiScene(scene)  ← 关键：绑定场景
        ├─ 创建 JS Scene 对象
        ├─ 设置默认环境
        ├─ 创建 SceneAdapter
        ├─ sceneAdapter->AttachToEngine(lumeCommon)
        ├─ lumeCommon->SetSceneAdapter(sceneAdapter)
        └─ sceneJs->scene_ = sceneAdapter
```

---

## 3. 方案设计

### 3.1 核心思想

**职责分离**：
- **SceneJS**：负责场景创建、加载、管理（数据层）
- **LumeXComponentManager**：负责渲染后端绑定、ECS 同步（渲染层）

**数据流**：
```
SceneJS 创建场景
    │
    │ Scene 对象 (IScene::Ptr)
    ▼
LumeXComponentManager::BindScene()
    │
    ├─ 提取 Scene 的 ECS
    ├─ 同步到 LumeCommon
    ├─ 创建 SceneAdapter
    └─ 连接渲染引擎
```

---

### 3.2 新架构调用链

```
┌─────────────────────────────────────────────────────────────┐
│  方案 A: 纯 SceneJS 创建 (简单场景)                          │
├─────────────────────────────────────────────────────────────┤
│ ArkTS:                                                      │
│   const scene = await Scene.load("scene.gltf");            │
│                                                             │
│ C++:                                                        │
│   SceneJS::Load()                                          │
│   ├─ 创建 Scene + ECS                                      │
│   ├─ 加载 GLB                                              │
│   ├─ 创建 SceneAdapter                                     │
│   └─ 自动连接 GraphicsManager 引擎                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  方案 B: SceneJS 创建 + XComponent 绑定 (复杂应用)           │
├─────────────────────────────────────────────────────────────┤
│ ArkTS:                                                      │
│   // 1. 创建 XComponent                                     │
│   <XComponent type="scene" onXComponentReady={...} />      │
│                                                             │
│   // 2. 创建场景                                            │
│   const scene = await Scene.load("scene.gltf");            │
│                                                             │
│   // 3. 绑定到渲染后端                                      │
│   renderer.bindScene(scene);                               │
│                                                             │
│ C++:                                                        │
│   Step 1: SceneJS::Load()                                  │
│   ├─ 创建 Scene + ECS                                      │
│   ├─ 加载 GLB                                              │
│   └─ 返回 SceneJS 对象                                      │
│                                                             │
│   Step 2: LumeXComponentManager::BindScene()               │
│   ├─ 获取 Scene 的 ECS                                      │
│   ├─ lumeCommon->SetEcs(sceneEcs)                          │
│   ├─ lumeCommon->InitializeScene()                         │
│   ├─ lumeCommon->AttachSceneApiScene(scene)                │
│   ├─ 创建 SceneAdapter                                     │
│   ├─ sceneAdapter->AttachToEngine(lumeCommon)              │
│   └─ lumeCommon->SetSceneAdapter(sceneAdapter)             │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.3 需要新增/修改的接口

#### **新增接口：LumeXComponentManager::BindScene**

```cpp
/**
 * @brief Bind a SceneJS-created scene to XComponent rendering backend
 * @param nodeId The XComponent node ID
 * @param scene The IScene::Ptr from SceneJS::Load
 * @return true if binding succeeded
 */
napi_value LumeXComponentManager::BindScene(napi_env env, napi_callback_info info);
```

**实现逻辑**：
```cpp
napi_value LumeXComponentManager::BindScene(napi_env env, napi_callback_info info)
{
    // 1. 获取参数 (nodeId, scene)
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    std::string nodeId = value2String(env, args[0]);
    SCENE_NS::IScene::Ptr scene = GetSceneFromNapiValue(env, args[1]);
    
    // 2. 获取渲染器
    auto renderer = GetRendererById(nodeId);
    if (!renderer) {
        return RejectPromise(env, "Renderer not found");
    }
    
    // 3. 获取 LumeCommon
    auto lumeCommon = renderer->GetLumeCommon();
    if (!lumeCommon) {
        return RejectPromise(env, "LumeCommon not available");
    }
    
    // 4. 提取 Scene 的 ECS 并绑定
    auto internalScene = scene->GetInternalScene();
    if (!internalScene) {
        return RejectPromise(env, "InternalScene not available");
    }
    
    auto sceneEcs = internalScene->GetEcsContext().GetNativeEcs();
    
    // 5. 同步 ECS 到 LumeCommon
    lumeCommon->SetEcs(sceneEcs);
    lumeCommon->InitializeScene(sceneEcs->GetId());
    
    // 6. 绑定场景到渲染
    lumeCommon->AttachSceneApiScene(scene);
    
    // 7. 创建并绑定 SceneAdapter
#ifdef __SCENE_ADAPTER_XCOMPONENT__
    auto sceneAdapter = std::make_shared<SceneAdapterXComponent>();
    sceneAdapter->AttachToEngine(lumeCommon, 0);
    sceneAdapter->SetSceneObj(interface_pointer_cast<META_NS::IObject>(scene));
    lumeCommon->SetSceneAdapter(sceneAdapter);
    
    // 8. 更新 SceneJS 的 scene_ 成员
    auto jsscene = GetJsWrapperFromScene(scene);
    auto sceneJs = jsscene.GetJsWrapper<SceneJS>();
    if (sceneJs) {
        sceneJs->scene_ = sceneAdapter;
    }
#endif
    
    LOGI("BindScene: Scene bound to XComponent successfully");
    return ResolvePromise(env, true);
}
```

---

#### **修改接口：简化 LoadScene**

**当前 LoadScene** 职责过多，需要简化为只调用 SceneJS::Load：

```cpp
// 修改前：LoadScene 自己创建场景
napi_value LumeXComponentManager::LoadScene(napi_env env, napi_callback_info info)
{
    // ... 大量重复 SceneJS::Load 的逻辑 ...
    auto scene = createSceneFunc();
    scene = loadGLB(scene);
    scene = setupRendering(scene);
    // ...
}

// 修改后：LoadScene 委托给 SceneJS
napi_value LumeXComponentManager::LoadScene(napi_env env, napi_callback_info info)
{
    // 1. 获取参数
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    std::string nodeId = value2String(env, args[0]);
    std::string gltfPath = value2String(env, args[1]);
    
    // 2. 直接调用 SceneJS::Load (复用现有逻辑)
    // SceneJS::Load 会处理：
    // - SceneManager 创建
    // - Scene 创建
    // - GLB 加载
    // - JS 对象创建
    // - SceneAdapter 创建
    auto sceneJsValue = SceneJS::Load(env, gltfPath);
    
    // 3. 提取 Scene 对象
    SCENE_NS::IScene::Ptr scene = GetSceneFromNapiValue(env, sceneJsValue);
    
    // 4. 绑定到渲染后端
    return BindScene(nodeId, scene);
}
```

---

### 3.4 ArkTS 侧 API 变更

#### **当前 API**
```typescript
// 方式 1: 使用 Scene.load (SceneJS)
const scene = await Scene.load("scene.gltf");

// 方式 2: 使用 renderer.loadScene (LumeXComponentManager)
const success = await renderer.loadScene(nodeId, "scene.gltf");
```

#### **新 API (推荐)**
```typescript
// 统一使用 Scene.load 创建场景
const scene = await Scene.load("scene.gltf");

// 显式绑定到 XComponent 渲染
await renderer.bindScene(scene);

// 或者链式调用
const scene = await Scene.load("scene.gltf");
await scene.bindToRenderer(renderer);
```

---

### 3.5 BindNode 与 BindScene 的关系

```
┌─────────────────────────────────────────────────────────────┐
│  BindNode vs BindScene                                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  BindNode:                                                  │
│  ├─ 功能：绑定 XComponent UI 节点到渲染管理器                │
│  ├─ 时机：XComponent 创建时调用一次                         │
│  ├─ 输入：nodeId, nodeHandle, resourceManager              │
│  └─ 输出：LumeRenderer 实例                                 │
│                                                             │
│  BindScene:                                                 │
│  ├─ 功能：绑定 Scene 对象到渲染后端                         │
│  ├─ 时机：场景加载后调用                                    │
│  ├─ 输入：nodeId (from BindNode), scene (from Scene.load) │
│  └─ 输出：绑定成功/失败                                     │
│                                                             │
│  调用顺序：                                                 │
│  1. BindNode(nodeId) → 创建渲染后端                        │
│  2. Scene.load("scene.gltf") → 创建场景                    │
│  3. BindScene(nodeId, scene) → 连接场景和渲染              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. 实现步骤

### 4.1 代码修改清单

| 文件 | 修改内容 | 优先级 |
|------|----------|--------|
| `lume_xcomponent_manager.h` | 新增 `BindScene()` 声明 | P0 |
| `lume_xcomponent_manager.cpp` | 实现 `BindScene()` | P0 |
| `lume_xcomponent_manager.cpp` | 简化 `LoadScene()` 委托给 SceneJS | P1 |
| `SceneJS.cpp` | 导出 `Load()` 供其他模块调用 | P1 |
| `SceneJS.h` | 新增静态方法 `Load(env, uri)` | P1 |
| `index.ets` (ArkTS) | 新增 `renderer.bindScene(scene)` | P0 |

---

### 4.2 详细实现

#### **Step 1: 新增 BindScene 方法**

**lume_xcomponent_manager.h**
```cpp
class LumeXComponentManager {
public:
    // 新增方法
    static napi_value BindScene(napi_env env, napi_callback_info info);
    
    // 辅助方法
    static SCENE_NS::IScene::Ptr GetSceneFromNapiValue(napi_env env, napi_value value);
    static NapiApi::Object GetJsWrapperFromScene(SCENE_NS::IScene::Ptr scene);
};
```

**lume_xcomponent_manager.cpp**
```cpp
napi_value LumeXComponentManager::BindScene(napi_env env, napi_callback_info info)
{
    LOGI("BindScene: Begin");
    
    // 1. 获取参数
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok) {
        LOGE("BindScene: napi_get_cb_info failed");
        return nullptr;
    }
    
    std::string nodeId = value2String(env, args[0]);
    napi_value sceneValue = args[1];
    
    // 2. 从 NAPI 值提取 Scene 对象
    SCENE_NS::IScene::Ptr scene = GetSceneFromNapiValue(env, sceneValue);
    if (!scene) {
        LOGE("BindScene: Failed to get scene from NAPI value");
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }
    
    LOGI("BindScene: nodeId=%{public}s, scene=%{public}p", nodeId.c_str(), scene.get());
    
    // 3. 获取渲染器
    auto renderer = GetRendererById(nodeId);
    if (!renderer) {
        LOGE("BindScene: Renderer not found");
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }
    
    // 4. 获取 LumeCommon
    auto lumeCommon = renderer->GetLumeCommon();
    if (!lumeCommon) {
        LOGE("BindScene: LumeCommon not available");
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }
    
    // 5. 提取 Scene 的 ECS
    auto internalScene = scene->GetInternalScene();
    if (!internalScene) {
        LOGE("BindScene: InternalScene not available");
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }
    
    auto sceneEcs = internalScene->GetEcsContext().GetNativeEcs();
    LOGI("BindScene: Got Scene ECS, ecsId=%{public}llu", sceneEcs->GetId());
    
    // 6. 同步 ECS 到 LumeCommon
    lumeCommon->SetEcs(sceneEcs);
    lumeCommon->InitializeScene(sceneEcs->GetId());
    LOGI("BindScene: ECS synchronized to LumeCommon");
    
    // 7. 绑定场景到渲染
    lumeCommon->AttachSceneApiScene(scene);
    LOGI("BindScene: Scene attached to LumeCommon");
    
    // 8. 创建并绑定 SceneAdapter
#ifdef __SCENE_ADAPTER_XCOMPONENT__
    auto sceneAdapter = std::make_shared<SceneAdapterXComponent>();
    if (sceneAdapter->AttachToEngine(lumeCommon, 0)) {
        LOGI("BindScene: SceneAdapterXComponent attached to engine");
    }
    sceneAdapter->SetSceneObj(interface_pointer_cast<META_NS::IObject>(scene));
    lumeCommon->SetSceneAdapter(sceneAdapter);
    
    // 9. 更新 SceneJS 的 scene_ 成员
    auto jsscene = GetJsWrapperFromScene(scene);
    auto sceneJs = jsscene.GetJsWrapper<SceneJS>();
    if (sceneJs) {
        sceneJs->scene_ = sceneAdapter;
        LOGI("BindScene: SceneJS::scene_ updated");
    }
#endif
    
    LOGI("BindScene: Completed successfully");
    napi_value result;
    napi_get_boolean(env, true, &result);
    return result;
}

// 辅助方法实现
SCENE_NS::IScene::Ptr LumeXComponentManager::GetSceneFromNapiValue(napi_env env, napi_value value)
{
    // 从 NAPI 对象提取 nativeObject_ 成员
    NapiApi::Object obj(value);
    auto nativeObj = obj.GetNative<void*>("nativeObject_");
    if (!nativeObj) {
        return nullptr;
    }
    
    // 转换为 IScene::Ptr
    auto baseObj = static_cast<BaseObject*>(nativeObj);
    if (!baseObj) {
        return nullptr;
    }
    
    return interface_pointer_cast<SCENE_NS::IScene>(baseObj->GetInstanceImpl(SCENE_NS::ClassId::Scene));
}

NapiApi::Object LumeXComponentManager::GetJsWrapperFromScene(SCENE_NS::IScene::Ptr scene)
{
    // 使用 CreateFromNativeInstance 或从缓存获取
    // 这里假设 scene 已经有 JS 包装器
    return NapiApi::Object(); // 实际实现需要查找 JS 包装器
}
```

---

#### **Step 2: 简化 LoadScene 方法**

```cpp
napi_value LumeXComponentManager::LoadScene(napi_env env, napi_callback_info info)
{
    LOGI("LoadScene: Delegating to SceneJS");
    
    // 1. 获取参数
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok) {
        LOGE("LoadScene: napi_get_cb_info failed");
        return nullptr;
    }
    
    std::string nodeId = value2String(env, args[0]);
    std::string gltfPath = value2String(env, args[1]);
    
    LOGI("LoadScene: nodeId=%{public}s, path=%{public}s", nodeId.c_str(), gltfPath.c_str());
    
    // 2. 调用 SceneJS::Load (复用现有逻辑)
    // 注意：需要修改 SceneJS::Load 使其可以从外部调用
    auto promise = Promise(env);
    
    // 3. 在 Load 完成后绑定到渲染
    // 这里需要修改 SceneJS::Load 的 convertToJs 回调
    // 或者在 ArkTS 侧手动调用 bindScene
    
    // 简化方案：返回 SceneJS::Load 的结果，让 ArkTS 侧调用 bindScene
    return SceneJS::Load(env, gltfPath);
}
```

---

#### **Step 3: 修改 SceneJS.h 导出 Load 方法**

**SceneJS.h**
```cpp
class SceneJS : public BaseObject {
public:
    // 新增静态方法，供外部调用
    static napi_value Load(napi_env env, const std::string& uri);
    
    // 原有方法保持不变
    static napi_value Load(NapiApi::FunctionContext<>& ctx);
    // ...
};
```

**SceneJS.cpp**
```cpp
// 新增重载方法
napi_value SceneJS::Load(napi_env env, const std::string& uri)
{
    // 创建 FunctionContext 并调用原有 Load 方法
    // 或者直接复制原有逻辑
    // 这里为了简化，直接调用原有方法
    
    // 需要构造合适的 FunctionContext
    // 或者提取核心逻辑到独立方法
    return Load(/* 构造 context */);
}
```

---

### 4.3 ArkTS 侧实现

**index.ets (或 Scene.ets)**
```typescript
// 新增 bindScene 方法
export class Renderer {
  private nodeId: string;
  
  constructor(nodeId: string) {
    this.nodeId = nodeId;
  }
  
  /**
   * @brief Bind a Scene to this renderer
   * @param scene The Scene object from Scene.load()
   */
  async bindScene(scene: Scene): Promise<boolean> {
    return await nativeRenderer.bindScene(this.nodeId, scene);
  }
  
  /**
   * @brief Load scene and bind to renderer in one call
   * @param gltfPath Path to GLB/GLTF file
   */
  async loadScene(gltfPath: string): Promise<Scene> {
    const scene = await Scene.load(gltfPath);
    await this.bindScene(scene);
    return scene;
  }
}

// 使用示例
const renderer = new Renderer(xComponentId);

// 方式 1: 分离调用
const scene = await Scene.load("scene.gltf");
await renderer.bindScene(scene);

// 方式 2: 链式调用
const scene = await renderer.loadScene("scene.gltf");
```

---

## 5. 迁移指南

### 5.1 旧代码迁移

#### **旧代码**
```typescript
// 使用 renderer.loadScene
const success = await renderer.loadScene(nodeId, "scene.gltf");
```

#### **新代码**
```typescript
// 方式 1: 使用统一 API
const scene = await Scene.load("scene.gltf");
await renderer.bindScene(scene);

// 方式 2: 使用便捷方法
const scene = await renderer.loadScene("scene.gltf");
```

---

### 5.2 C++ 侧迁移

#### **旧代码**
```cpp
// LumeXComponentManager::LoadScene 包含完整场景创建逻辑
napi_value LumeXComponentManager::LoadScene(...) {
    // 1. 创建 SceneManager
    auto sceneManager = CreateSceneManager(...);
    // 2. 创建 Scene
    auto scene = sceneManager->Create<IScene>();
    // 3. 加载 GLB
    assets->Load(scene, gltfPath);
    // 4. 同步 ECS
    lumeCommon->SetEcs(sceneEcs);
    // 5. 绑定渲染
    lumeCommon->AttachSceneApiScene(scene);
    // ...
}
```

#### **新代码**
```cpp
// LumeXComponentManager::LoadScene 委托给 SceneJS
napi_value LumeXComponentManager::LoadScene(...) {
    // 1. 调用 SceneJS::Load
    auto sceneJsValue = SceneJS::Load(env, gltfPath);
    
    // 2. 提取 Scene 并绑定
    auto scene = GetSceneFromNapiValue(env, sceneJsValue);
    return BindScene(nodeId, scene);
}

// 新增 BindScene 方法
napi_value LumeXComponentManager::BindScene(...) {
    // 只处理渲染绑定逻辑
    lumeCommon->SetEcs(sceneEcs);
    lumeCommon->AttachSceneApiScene(scene);
    // ...
}
```

---

## 6. 优势分析

### 6.1 架构优势

| 方面 | 改进前 | 改进后 |
|------|--------|--------|
| **职责分离** | 场景创建逻辑分散 | SceneJS 统一负责场景创建 |
| **代码复用** | 重复逻辑维护两份 | SceneJS 逻辑被复用 |
| **扩展性** | 修改需同步两处 | 只需修改 SceneJS |
| **测试** | 需要测试两个入口 | 主要测试 SceneJS |
| **文档** | 需要说明两个方法 | 统一说明 Scene.load |

### 6.2 开发体验

| 方面 | 改进前 | 改进后 |
|------|--------|--------|
| **API 一致性** | Scene.load vs renderer.loadScene | 统一使用 Scene.load |
| **学习成本** | 需要理解两个方法的区别 | 只需理解 Scene.load + bindScene |
| **错误处理** | 两处错误处理逻辑 | 统一错误处理 |

---

## 7. 风险评估

### 7.1 兼容性风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 现有代码使用 renderer.loadScene | 中 | 保留 LoadScene 方法，内部委托给 SceneJS |
| SceneJS::Load 的并发调用 | 低 | 原有逻辑已支持并发 |
| ECS 同步时序问题 | 中 | 在 BindScene 中增加同步检查 |

### 7.2 性能风险

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 额外的场景对象提取 | 低 | 只是指针操作，开销可忽略 |
| SceneAdapter 重复创建 | 低 | 确保只创建一次 |

---

## 8. 测试计划

### 8.1 单元测试

```cpp
// 测试 SceneJS::Load
TEST(SceneJSTest, LoadScene) {
    auto scene = SceneJS::Load(env, "test.gltf");
    ASSERT_NE(scene, nullptr);
}

// 测试 BindScene
TEST(BindSceneTest, BindValidScene) {
    auto scene = SceneJS::Load(env, "test.gltf");
    auto result = BindScene(nodeId, scene);
    ASSERT_TRUE(result);
}

// 测试 ECS 同步
TEST(BindSceneTest, EcsSynchronization) {
    auto scene = SceneJS::Load(env, "test.gltf");
    BindScene(nodeId, scene);
    
    auto lumeCommon = renderer->GetLumeCommon();
    ASSERT_EQ(lumeCommon->GetEcs(), scene->GetInternalScene()->GetEcs());
}
```

### 8.2 集成测试

```typescript
// 测试完整流程
@ohosTest.testCase
async function testSceneLoadAndBind() {
    // 1. 创建 XComponent
    const nodeId = await createXComponent();
    
    // 2. 加载场景
    const scene = await Scene.load('test.gltf');
    
    // 3. 绑定渲染
    const success = await renderer.bindScene(scene);
    
    // 4. 验证渲染
    expect(success).assertTrue();
    expect(scene).toBeDefined();
}
```

---

## 9. 总结

### 9.1 核心变更

1. **新增** `LumeXComponentManager::BindScene()` - 专门处理场景与渲染后端的绑定
2. **简化** `LumeXComponentManager::LoadScene()` - 委托给 SceneJS::Load
3. **导出** `SceneJS::Load()` - 供其他模块调用

### 9.2 架构收益

- ✅ 职责清晰：SceneJS 负责场景，LumeXComponent 负责渲染
- ✅ 代码复用：消除重复逻辑
- ✅ 易于维护：单一场景创建入口
- ✅ 向后兼容：保留原有 API

### 9.3 后续工作

- [ ] 实现 `BindScene()` 方法
- [ ] 简化 `LoadScene()` 方法
- [ ] 更新 ArkTS 侧 API
- [ ] 编写单元测试
- [ ] 更新文档

---

**文档结束**
