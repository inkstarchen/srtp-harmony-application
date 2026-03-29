# XComponent 渲染循环技术文档

## 一、整体架构概览

XComponent渲染系统采用三层架构，使用 **ArkUI SurfaceHolder API** 进行交互：

```
┌─────────────────────────────────────────────────────────────┐
│                    ArkTS/JavaScript 层                       │
│   (调用 NAPI 接口: createNativeNode, BindNode, LoadScene)   │
└─────────────────────────────────────────────────────────────┘
                              ↓ NAPI
┌─────────────────────────────────────────────────────────────┐
│              LumeXComponentManager (单例管理器)              │
│   - 管理 NodeHandle → SurfaceHolder 映射                     │
│   - 管理 LumeRenderer 实例                                    │
│   - 注册 SurfaceHolder 回调函数                               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    LumeRenderer                              │
│   - EGL 初始化与管理                                          │
│   - Lume Engine 初始化                                        │
│   - Swapchain/RenderTarget 管理                              │
│   - 渲染循环执行                                              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  LumeSceneContext                            │
│   - 场景创建/加载                                             │
│   - 相机管理                                                  │
│   - RenderTarget 绑定                                        │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Lume Engine                               │
│   (IEngine → IRenderContext → IApplicationContext)          │
└─────────────────────────────────────────────────────────────┘
```

## 二、ArkUI SurfaceHolder API 交互方式

### 2.1 核心概念

**新方式 (ArkUI SurfaceHolder API)** vs **旧方式 (OH_NativeXComponent_Callback)**

| 特性 | 旧方式 | 新方式 |
|------|--------|--------|
| 回调注册 | `OH_NativeXComponent_RegisterCallback` | `OH_ArkUI_SurfaceHolder_AddSurfaceCallback` |
| 数据存储 | 通过 ID 映射 | `OH_ArkUI_SurfaceHolder_SetUserData` |
| 帧回调 | 无 | `OH_ArkUI_XComponent_RegisterOnFrameCallback` |
| 初始化控制 | 自动触发 | 手动调用 `Initialize` |

### 2.2 核心数据结构

```cpp
// Node ID -> NodeHandle 映射
static std::unordered_map<std::string, ArkUI_NodeHandle> nodeHandleMap_;

// NodeHandle -> SurfaceHolder 映射
static std::unordered_map<ArkUI_NodeHandle, OH_ArkUI_SurfaceHolder*> surfaceHolderMap_;

// SurfaceHolder -> SurfaceCallback 映射
static std::unordered_map<OH_ArkUI_SurfaceHolder*, OH_ArkUI_SurfaceCallback*> callbackMap_;

// NodeHandle -> Renderer 映射
static std::unordered_map<ArkUI_NodeHandle, LumeRenderer*> rendererMap_;
```

## 三、渲染循环生命周期

### 3.1 初始化阶段

**触发时机**: ArkTS 调用 `BindNode` 后，Surface 创建时自动触发

```
ArkTS 调用 createNativeNode(nodeContent, tag)
        ↓
创建 XComponent Node 并设置属性
        ↓
ArkTS 调用 BindNode(nodeId, nodeHandle)
        ↓
    ┌───────────────────────────────────────────────────┐
    │ 1. OH_ArkUI_SurfaceHolder_Create(handle)          │
    │ 2. OH_ArkUI_SurfaceCallback_Create()              │
    │ 3. new LumeRenderer(nodeId)                       │
    │ 4. OH_ArkUI_SurfaceHolder_SetUserData(holder, renderer) │
    │ 5. 注册 Surface 回调:                             │
    │    - OnSurfaceCreatedNative                       │
    │    - OnSurfaceChangedNative                       │
    │    - OnSurfaceDestroyedNative                     │
    │    - OnSurfaceShowNative / OnSurfaceHideNative    │
    │ 6. OH_ArkUI_XComponent_RegisterOnFrameCallback()  │
    │ 7. 注册触摸事件: nodeAPI->registerNodeEvent()     │
    │ 8. OH_ArkUI_SurfaceHolder_AddSurfaceCallback()    │
    └───────────────────────────────────────────────────┘
        ↓
ArkTS 调用 Initialize(nodeId)
        ↓
    ┌───────────────────────────────────────────────────┐
    │ OH_ArkUI_XComponent_SetAutoInitialize(node, true)│
    │ OH_ArkUI_XComponent_Initialize(node)              │
    └───────────────────────────────────────────────────┘
        ↓
OnSurfaceCreatedNative 回调触发
        ↓
    ┌───────────────────────────────────────────────────┐
    │ OH_ArkUI_XComponent_GetNativeWindow(holder)       │
    │ renderer->Initialize(window, width, height)       │
    │   - InitializeEGL()                               │
    │   - InitializeLumeEngine()                        │
    │   - CreateSwapchain()                             │
    │   - CreateRenderTarget()                          │
    └───────────────────────────────────────────────────┘
        ↓
状态变为 RenderState::READY
```

### 3.2 渲染帧循环

**触发方式**: 帧回调自动触发或手动调用 `DrawFrame`

```
OnFrameCallbackNative(node, timestamp, targetTimestamp)
        ↓
获取 holder 和 renderer
        ↓
if (renderer->GetState() == RenderState::READY)
    renderer->RenderFrame()
        ↓
    ┌───────────────────────────────────────┐
    │ RenderFrame() 执行流程:               │
    │ 1. MakeCurrent() - 绑定 EGL Context   │
    │ 2. UpdateViewport()                   │
    │ 3. SceneContext Update                │
    │ 4. RenderContext 渲染                 │
    │ 5. SwapBuffers()                      │
    └───────────────────────────────────────┘
```

### 3.3 Surface 变化处理

```
OnSurfaceChangedNative(holder, width, height)
        ↓
renderer->OnSurfaceChanged(window, width, height)
        ↓
    ┌───────────────────────────────────────┐
    │ 1. 更新 windowInfo_                   │
    │ 2. DestroySwapchain()                 │
    │ 3. DestroyRenderTarget()              │
    │ 4. CreateSwapchain(new_window)        │
    │ 5. CreateRenderTarget()               │
    │ 6. UpdateViewport()                   │
    └───────────────────────────────────────┘
```

### 3.4 销毁阶段

**触发时机**: ArkTS 调用 `UnbindNode`

```
UnbindNode(nodeId)
        ↓
    ┌───────────────────────────────────────────────────┐
    │ 1. OH_ArkUI_XComponent_UnregisterOnFrameCallback()│
    │ 2. OH_ArkUI_SurfaceHolder_RemoveSurfaceCallback() │
    │ 3. OH_ArkUI_SurfaceCallback_Dispose()             │
    │ 4. renderer->OnSurfaceDestroyed()                 │
    │ 5. delete renderer                                │
    │ 6. OH_ArkUI_SurfaceHolder_Dispose()               │
    │ 7. 清理映射                                       │
    └───────────────────────────────────────────────────┘
```

## 四、NAPI 接口说明

### 4.1 LumeXComponentManager 接口

| 方法 | 参数 | 说明 |
|------|------|------|
| `createNativeNode` | nodeContent, tag | 创建 XComponent Node |
| `BindNode` | nodeId, nodeHandle | 绑定节点，创建 SurfaceHolder |
| `UnbindNode` | nodeId | 解绑节点，清理资源 |
| `Initialize` | nodeId | 初始化 XComponent |
| `Finalize` | nodeId | 销毁 XComponent |
| `LoadScene` | nodeId, gltfPath | 加载 GLTF 场景 |
| `DrawFrame` | nodeId | 手动绘制一帧 |
| `SetFrameRate` | nodeId, min, max, expected | 设置帧率范围 |
| `SetNeedSoftKeyboard` | nodeId, need | 设置是否需要软键盘 |
| `GetRendererState` | nodeId | 获取渲染器状态 |

### 4.2 SurfaceHolder 静态回调

| 回调函数 | 说明 |
|----------|------|
| `OnSurfaceCreatedNative` | Surface 创建，初始化 EGL 和 Lume |
| `OnSurfaceChangedNative` | Surface 大小变化 |
| `OnSurfaceDestroyedNative` | Surface 销毁 |
| `OnSurfaceShowNative` | Surface 显示 |
| `OnSurfaceHideNative` | Surface 隐藏 |
| `OnFrameCallbackNative` | 帧回调，驱动渲染循环 |
| `OnTouchEventNative` | 触摸事件处理 |

## 五、创建相机和物体的方法

### 5.1 方式一：加载 GLTF 场景 (推荐)

**ArkTS 调用:**
```typescript
import nativeModule from 'libentry.so';

// 1. 创建 XComponent Node
nativeModule.createNativeNode(nodeContent, "myXComponent");

// 2. 绑定节点
nativeModule.bindNode("myXComponent", nodeHandle);

// 3. 初始化
nativeModule.initialize("myXComponent");

// 4. 加载 GLTF 场景
const success = nativeModule.loadScene("myXComponent", "models/scene.gltf");
```

### 5.2 方式二：创建空场景并手动添加相机

**C++ 层扩展接口:**
```cpp
// 在 LumeXComponentManager 中添加 NAPI 接口
napi_value CreateEmptyScene(napi_env env, napi_callback_info info) {
    std::string nodeId = NapiGetString(env, args[0]);
    auto renderer = GetRendererById(nodeId);
    if (renderer) {
        renderer->CreateScene();
    }
    return nullptr;
}

napi_value CreateCamera(napi_env env, napi_callback_info info) {
    std::string nodeId = NapiGetString(env, args[0]);
    std::string cameraName = NapiGetString(env, args[1]);
    auto renderer = GetRendererById(nodeId);
    if (renderer && renderer->GetSceneContext()) {
        renderer->GetSceneContext()->CreateCamera(cameraName);
    }
    return nullptr;
}
```

## 六、完整使用示例

### ArkTS 侧调用:
```typescript
import nativeModule from 'libentry.so';

// 1. 创建 XComponent Node (在 NodeContent 中)
nativeModule.createNativeNode(nodeContent, "lumeRender");

// 2. 获取 NodeHandle 后绑定
nativeModule.bindNode("lumeRender", nodeHandle);

// 3. 初始化 XComponent
nativeModule.initialize("lumeRender");

// 4. 加载 GLTF 场景
const success = nativeModule.loadScene("lumeRender", "models/scene.gltf");

// 5. 设置帧率 (自动渲染)
nativeModule.setFrameRate("lumeRender", 30, 60, 60);

// 6. 销毁时解绑
nativeModule.unbindNode("lumeRender");
```

### 扩展相机控制接口:
```cpp
// 在 LumeXComponentManager 中添加
napi_value SetCameraFoV(napi_env env, napi_callback_info info) {
    size_t argCnt = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr);

    std::string nodeId = NapiGetString(env, args[0]);
    double fov;
    napi_get_value_double(env, args[1], &fov);

    auto renderer = GetRendererById(nodeId);
    if (renderer && renderer->GetSceneContext()) {
        renderer->GetSceneContext()->SetCameraFoV(static_cast<float>(fov));
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}
```

## 七、文件结构

```
nativerender/lume_xcomponent/
├── include/
│   ├── lume_xcomponent_types.h    # 类型定义
│   ├── lume_xcomponent_manager.h  # 管理器头文件 (SurfaceHolder API)
│   ├── lume_renderer.h            # 渲染器头文件
│   └── lume_scene_context.h       # 场景上下文头文件
└── src/
    ├── lume_xcomponent_manager.cpp # 管理器实现 + NAPI 绑定
    ├── lume_renderer.cpp           # 渲染器实现
    └── lume_scene_context.cpp      # 场景上下文实现
```

## 八、依赖关系

- **ArkUI NDK**:
  - `OH_ArkUI_SurfaceHolder`: Surface 持有者
  - `OH_ArkUI_SurfaceCallback`: Surface 回调
  - `OH_ArkUI_XComponent`: XComponent 控制
  - `ArkUI_NativeNodeAPI_1`: 节点操作 API
- **EGL/GLES**: OpenGL ES 3.0 渲染
- **Lume Engine**:
  - `IEngine`: 核心引擎
  - `IRenderContext`: 渲染上下文
  - `IApplicationContext`: 应用上下文
  - `IScene`: 场景管理
  - `ICamera`: 相机控制
  - `IRenderTarget`: 渲染目标
- **NAPI**: Node-API 绑定层

## 九、与 plugin_manager.cpp 的对应关系

改造后的 `lume_xcomponent_manager` 与 `plugin_manager.cpp` 保持一致的交互方式：

| plugin_manager | lume_xcomponent_manager |
|----------------|-------------------------|
| `EGLRender` | `LumeRenderer` |
| `BindNode` 创建 SurfaceHolder | `BindNode` 创建 SurfaceHolder |
| `OnSurfaceCreatedNative` | `OnSurfaceCreatedNative` |
| `OnFrameCallbackNative` | `OnFrameCallbackNative` |
| `OH_ArkUI_SurfaceHolder_SetUserData` | `OH_ArkUI_SurfaceHolder_SetUserData` |

核心差异：`LumeRenderer` 集成了完整的 Lume Engine 渲染管线，而 `EGLRender` 是简单的 EGL 绘制示例。