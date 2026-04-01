# Scene控制接口与渲染流程完整指南

## 目录

1. [架构概览](#1-架构概览)
2. [当前已暴露的NAPI接口](#2-当前已暴露的napi接口)
3. [Scene控制接口设计](#3-scene控制接口设计)
4. [渲染流程详解](#4-渲染流程详解)
5. [RenderNodeGraph管线](#5-rendernodegraph管线)
6. [使用教程](#6-使用教程)
7. [关键文件路径](#7-关键文件路径)

---

## 1. 架构概览

### 1.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ArkTS / JavaScript Layer                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  NativePage.ets                                                              │
│  - native.bindNode() → 创建渲染容器                                          │
│  - native.loadScene() → 加载场景模型                                         │
│  - native.setupCamera() → 设置相机参数                                       │
│  - native.requestRender() → 触发渲染                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ NAPI (libnativerender.so)
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Native C++ Layer                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    LumeXComponentManager                              │  │
│  │  - createNativeNode() → 创建XComponent节点                            │  │
│  │  - bindNode() → 绑定渲染器到节点                                       │  │
│  │  - unbindNode() → 解绑节点                                             │  │
│  │  - loadScene() → 加载GLTF场景                                          │  │
│  │  - setupCameraPosition() → 设置相机位置                                │  │
│  │  - requestRender() → 手动触发渲染                                      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│              │                                                               │
│              ▼                                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                       LumeRenderer                                    │  │
│  │  - Initialize() → 初始化EGL环境和Lume引擎                             │  │
│  │  - RenderFrame() → 执行帧渲染                                          │  │
│  │  - LoadScene() → 加载场景模型                                          │  │
│  │  - SetupCameraTransform() → 设置相机变换                              │  │
│  │  - SetupCameraViewport() → 设置视口大小                               │  │
│  │  - SetupCameraProjection() → 设置投影参数                             │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│              │                                                               │
│              ▼                                                               │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    LumeCommon (IEngine实现)                           │  │
│  │  - InitEngine() → 创建CoreEngine/RenderContext/Gfx3DContext           │  │
│  │  - InitializeScene() → 创建ECS/加载SystemGraph/创建Camera             │  │
│  │  - LoadSceneModel() → 加载GLTF模型                                    │  │
│  │  - DrawFrame() → 核心渲染入口                                          │  │
│  │  - SetupCameraTransform/Viewport/Projection() → 相机控制              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Lume Engine Core                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   CORE::IEngine │  │  IRenderContext │  │ IGraphicsContext│             │
│  │   (ECS System)  │  │   (Renderer)    │  │    (3D Context) │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│              │                  │                    │                       │
│              └──────────────────┼────────────────────┘                       │
│                                 ▼                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     Render Node Graph Pipeline                         │  │
│  │                                                                         │  │
│  │  RenderNodeDefaultCameras → RenderNodeDefaultLights →                 │  │
│  │  RenderNodeDefaultMaterialObjects → RenderNodeDefaultEnv →            │  │
│  │  RenderNodeCameraPostProcessController                                 │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                 │                                            │
│                                 ▼                                            │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                          GPU / Swapchain                               │  │
│  │  - GLES Device → GPU命令提交                                           │  │
│  │  - EGL Surface → 图像输出到屏幕                                        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 核心类关系

```cpp
// 接口层次结构
IEngine (抽象接口)
    ↑
    └── LumeCommon (实现类)
           ↑
           └── LumeRenderer (适配器，持有Lume实例)
                  ↑
                  └── LumeXComponentManager (NAPI桥接)

// Scene适配器层次
ISceneAdapter (抽象接口)
    ↑
    └── SceneAdapter (实现类)
           - LoadPluginsAndInit()
           - RenderFrame()
           - SetSceneObj()
```

---

## 2. 当前已暴露的NAPI接口

### 2.1 接口列表

| 方法名 | 功能 | 实现状态 |
|--------|------|----------|
| `createNativeNode` | 创建XComponent节点 | ✅ 已实现 |
| `bindNode` | 绑定渲染器到节点 | ✅ 已实现 |
| `unbindNode` | 解绑节点 | ✅ 已实现 |
| `initialize` | 初始化XComponent | ✅ 已实现 |
| `finalize` | 销毁XComponent | ✅ 已实现 |
| `setFrameRate` | 设置帧率范围 | ✅ 已实现 |
| `setNeedSoftKeyboard` | 设置软键盘需求 | ✅ 已实现 |
| `getStatus` | 获取XComponent状态 | ✅ 已实现 |
| `drawPattern` | 绘制测试图案 | ✅ 已实现 |
| `loadScene` | 加载场景模型 | ❌ 待实现 |
| `loadEnvModel` | 加载环境模型 | ❌ 待实现 |
| `setupCameraPosition` | 设置相机位置 | ❌ 待实现 |
| `setupCameraProjection` | 设置相机投影 | ❌ 待实现 |
| `setupCameraViewport` | 设置视口大小 | ❌ 待实现 |
| `requestRender` | 手动触发渲染 | ❌ 待实现 |

### 2.2 NAPI注册代码位置

文件: `nativerender/napi_init.cpp`

```cpp
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"createNativeNode", nullptr, LumeXComponentManager::createNativeNode, ...},
        {"bindNode", nullptr, LumeXComponentManager::BindNode, ...},
        {"unbindNode", nullptr, LumeXComponentManager::UnbindNode, ...},
        {"initialize", nullptr, LumeXComponentManager::Initialize, ...},
        {"finalize", nullptr, LumeXComponentManager::Finalize, ...},
        {"setFrameRate", nullptr, LumeXComponentManager::SetFrameRate, ...},
        // ... 其他接口
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
```

---

## 3. Scene控制接口设计

### 3.1 IEngine接口定义

文件: `nativerender/3d_widget_adapter/include/i_engine.h`

```cpp
class IEngine {
public:
    // 引擎生命周期
    virtual bool LoadEngineLib() = 0;
    virtual bool InitEngine(EGLContext eglContext, const PlatformData& data) = 0;
    virtual void DeInitEngine() = 0;
    virtual void UnloadEngineLib() = 0;
    virtual void Clone(IEngine* proto) = 0;

    // 场景初始化
    virtual void InitializeScene(uint32_t key) = 0;

    // 相机控制
    virtual void SetupCameraViewPort(uint32_t width, uint32_t height) = 0;
    virtual void SetupCameraTransform(const Position& position,
        const Vec3& lookAt, const Vec3& up, const Quaternion& rotation) = 0;
    virtual void SetupCameraViewProjection(float zNear, float zFar, float fovDegrees) = 0;

    // 模型加载
    virtual void LoadSceneModel(const std::string& modelPath) = 0;
    virtual void LoadEnvModel(const std::string& modelPath, BackgroundType type) = 0;
    virtual void UnloadSceneModel() = 0;
    virtual void UnloadEnvModel() = 0;

    // 事件处理
    virtual void OnTouchEvent(const PointerEvent& event) = 0;
    virtual void OnWindowChange(const TextureInfo& textureInfo) = 0;

    // 渲染
    virtual void DrawFrame() = 0;
    virtual bool NeedsRepaint() = 0;

    // 更新接口
    virtual void UpdateGeometries(const std::vector<std::shared_ptr<Geometry>>& shapes) = 0;
    virtual void UpdateGLTFAnimations(const std::vector<std::shared_ptr<GLTFAnimation>>& animations) = 0;
    virtual void UpdateLights(const std::vector<std::shared_ptr<Light>>& lights) = 0;
    virtual void UpdateCustomRender(const std::shared_ptr<CustomRenderDescriptor>& customRender) = 0;
};
```

### 3.2 ISceneAdapter接口定义

文件: `nativerender/3d_scene_adapter/include/scene_adapter/intf_scene_adapter.h`

```cpp
class ISceneAdapter {
public:
    // 初始化
    virtual bool LoadPluginsAndInit() = 0;

    // 渲染
    virtual void RenderFrame(bool needsSyncPaint = false) = 0;

    // 生命周期
    virtual void Deinit() = 0;
    virtual bool NeedsRepaint() = 0;

    // Scene对象设置
    virtual void SetSceneObj(META_NS::IObject::Ptr sceneObj) {};

    virtual ~ISceneAdapter() = default;
};
```

### 3.3 待实现的NAPI接口设计

```cpp
// 在 napi_init.cpp 中添加以下接口注册
napi_property_descriptor sceneDesc[] = {
    // Scene加载
    {"loadScene", nullptr, LumeXComponentManager::LoadScene, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"loadEnvModel", nullptr, LumeXComponentManager::LoadEnvModel, nullptr, nullptr, nullptr, napi_default, nullptr},

    // 相机控制
    {"setupCameraPosition", nullptr, LumeXComponentManager::SetupCameraPosition, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setupCameraProjection", nullptr, LumeXComponentManager::SetupCameraProjection, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"setupCameraViewport", nullptr, LumeXComponentManager::SetupCameraViewport, nullptr, nullptr, nullptr, napi_default, nullptr},

    // 渲染控制
    {"requestRender", nullptr, LumeXComponentManager::RequestRender, nullptr, nullptr, nullptr, napi_default, nullptr},

    // 灯光控制
    {"updateLights", nullptr, LumeXComponentManager::UpdateLights, nullptr, nullptr, nullptr, napi_default, nullptr},

    // 动画控制
    {"playAnimation", nullptr, LumeXComponentManager::PlayAnimation, nullptr, nullptr, nullptr, napi_default, nullptr},
    {"stopAnimation", nullptr, LumeXComponentManager::StopAnimation, nullptr, nullptr, nullptr, napi_default, nullptr},
};
```

---

## 4. 渲染流程详解

### 4.1 从ArkTS调用到图像输出的完整链路

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ 步骤1: ArkTS层创建XComponent渲染容器                                         │
│                                                                              │
│ 调用: native.bindNode(nodeId, xComponent)                                   │
│                                                                              │
│ 执行流程:                                                                    │
│ 1. LumeXComponentManager::BindNode()                                        │
│ 2. OH_ArkUI_SurfaceHolder_Create(handle) → 创建SurfaceHolder                │
│ 3. new LumeRenderer(nodeId) → 创建渲染适配器                                │
│ 4. 注册回调:                                                                 │
│    - OnSurfaceCreatedNative → Surface创建回调                               │
│    - OnSurfaceChangedNative → Surface变化回调                               │
│    - OnSurfaceDestroyedNative → Surface销毁回调                             │
│    - OnFrameCallbackNative → 帧渲染回调                                     │
│    - OnTouchEventNative → 触摸事件回调                                       │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 步骤2: Surface创建回调 - 初始化渲染环境                                      │
│                                                                              │
│ 调用: OnSurfaceCreatedNative(holder)                                        │
│                                                                              │
│ 执行流程:                                                                    │
│ 1. OH_ArkUI_XComponent_GetNativeWindow(holder) → 获取NativeWindow          │
│ 2. LumeRenderer::Initialize(window, width, height)                          │
│    ├── InitializeEGL(window)                                                │
│    │   ├── eglGetDisplay() → 获取EGL显示                                    │
│    │   ├── eglInitialize() → 初始化EGL                                      │
│    │   ├── eglChooseConfig() → 选择EGL配置                                  │
│    │   ├── eglCreateWindowSurface() → 创建EGL Surface                       │
│    │   ├── eglCreateContext() → 创建EGL上下文                               │
│    │   └── eglMakeCurrent() → 绑定EGL上下文                                 │
│    ├── InitializeLumeEngine()                                               │
│    │   └── new Lume() → 创建Lume实例                                        │
│    │       └── LumeCommon::InitEngine(eglContext, platformData)             │
│    │           ├── CreateCoreEngine() → 创建CORE::IEngine                  │
│    │           ├── CreateRenderContext() → 创建IRenderContext               │
│    │           └── CreateGfx3DContext() → 创建IGraphicsContext              │
│    └── InitializeScene(key)                                                 │
│        └── LumeCommon::InitializeScene(key)                                 │
│            ├── CreateEcs(key) → 创建ECS系统                                 │
│            ├── LoadSystemGraph() → 加载系统图                               │
│            └── CreateCamera() → 创建默认相机                                │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 步骤3: 加载场景模型 [需要手动调用]                                           │
│                                                                              │
│ 调用: native.loadScene(nodeId, 'dir/card.gltf')                             │
│                                                                              │
│ 执行流程:                                                                    │
│ 1. LumeRenderer::LoadScene(gltfPath)                                        │
│ 2. LumeCommon::LoadSceneModel(gltfPath)                                     │
│    ├── UnloadSceneModel() → 清理旧场景                                      │
│    ├── CreateScene() → 创建场景实体                                         │
│    ├── LoadAndImport() → GLTF加载                                           │
│    │   ├── graphicsContext_->GetGltf().LoadGLTF() → 加载GLTF文件            │
│    │   ├── CreateGLTF2Importer() → 创建导入器                               │
│    │   ├── ImportGLTF() → 导入GLTF数据                                      │
│    │   ├── ImportGltfScene() → 导入场景节点                                 │
│    │   └── CreatePlayback() → 创建动画播放器                                │
│    └── importedSceneEntity_ → 存储场景实体                                   │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 步骤4: 设置相机参数 [可选]                                                   │
│                                                                              │
│ 调用: native.setupCameraPosition(nodeId, x, y, z, lookAt, up)               │
│       native.setupCameraProjection(nodeId, zNear, zFar, fov)                │
│                                                                              │
│ 执行流程:                                                                    │
│ 1. LumeRenderer::SetupCameraTransform()                                     │
│ 2. LumeCommon::SetupCameraTransform()                                       │
│    ├── 转换position到Vec3                                                   │
│    ├── 计算LookAt矩阵 → cameraRotation_                                     │
│    ├── orbitCamera_.SetOrbitFromEye() → 设置轨道相机                        │
│    └── cameraUpdated_ = true → 标记相机更新                                 │
│                                                                              │
│ 3. LumeCommon::SetupCameraViewProjection()                                  │
│    ├── zNear_, zFar_, fovDegrees_ 存储                                      │
│    └── cameraManager_更新相机组件                                           │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 步骤5: 帧渲染回调 - 自动执行                                                 │
│                                                                              │
│ 调用: OnFrameCallbackNative(node, timestamp) → 每帧自动触发                 │
│                                                                              │
│ 执行流程:                                                                    │
│ 1. LumeRenderer::RenderFrame()                                              │
│ 2. LumeCommon::DrawFrame()                                                  │
│    ├── engine_->TickFrame() → ECS帧更新                                     │
│    │   ├── ProcessEvents() → 处理事件                                       │
│    │   ├── UpdateSystems() → 更新系统                                       │
│    │   └── needsRender = true/false → 是否需要渲染                          │
│    ├── CollectRenderHandles() → 收集渲染句柄                                │
│    │   ├── customRender_->GetRenderHandles() → 自定义渲染句柄               │
│    │   └── GetGraphicsContext()->GetRenderNodeGraphs() → 标准渲染句柄        │
│    ├── Tick(deltaTime) → 更新相机轨道                                       │
│    │   ├── orbitCamera_.Update() → 轨道相机更新                             │
│    │   ├── transformManager_->Write() → 写入变换组件                        │
│    │   └── cameraPosition_/rotation更新                                     │
│    ├── customRender_->OnDrawFrame() → 自定义渲染回调                        │
│    ├── GetRenderContext()->GetRenderer().RenderFrame() → GPU渲染             │
│    │   └── 执行RenderNodeGraph                                              │
│    └── AddTextureMemoryBarrrier() → GPU内存屏障                             │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 步骤6: RenderNodeGraph执行                                                   │
│                                                                              │
│ 执行流程:                                                                    │
│ IRenderer::RenderFrame(handles)                                             │
│ ├── PreExecuteFrame() → 每帧预处理                                          │
│ │   └── 创建GPU资源、更新缓冲区                                             │
│ ├── ExecuteFrame() → 并行执行渲染节点                                       │
│ │   ├── RenderNodeDefaultCameras                                           │
│ │   │   ├── 计算视图矩阵 (view)                                             │
│ │   │   ├── 计算投影矩阵 (proj + TAA抖动)                                   │
│ │   │   ├── 计算视图-投影矩阵 (viewProj)                                    │
│ │   │   ├── 计算视锥体裁剪平面                                              │
│ │   │   └── 写入CameraDataBuffer (GPU)                                      │
│ │   ├── RenderNodeDefaultLights                                            │
│ │   │   ├── 处理灯光数据                                                    │
│ │   │   ├── 设置阴影参数                                                    │
│ │   │   └── 写入LightDataBuffer                                             │
│ │   ├── RenderNodeDefaultMaterialObjects                                   │
│ │   │   ├── 渲染物体                                                        │
│ │   │   ├── 材质处理                                                        │
│ │   │   └── 执行DrawCalls                                                   │
│ │   ├── RenderNodeDefaultEnv                                               │
│ │   │   ├── 环境贴图采样                                                    │
│ │   │   ├── 天空盒渲染                                                      │
│ │   │   └── 间接光照计算                                                    │
│ │   └── RenderNodeCameraPostProcessController                              │
│ │       ├── Bloom效果                                                       │
│ │       ├── ToneMapping                                                     │
│ │       ├── ColorFringe                                                     │
│ │       └── 最终输出                                                        │
│ ├── PostExecuteFrame() → 帧后处理                                           │
│ └── SubmitCommands() → GPU命令提交                                          │
└──────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│ 步骤7: 图像输出                                                              │
│                                                                              │
│ 执行流程:                                                                    │
│ 1. GPU命令执行完成                                                           │
│ 2. Swapchain呈现                                                             │
│    ├── device_->Present() → 呈现Swapchain                                   │
│    └── eglSwapBuffers() → EGL Surface交换                                   │
│ 3. 图像输出到屏幕                                                            │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 DrawFrame核心代码分析

文件: `nativerender/3d_widget_adapter/core/src/lume/lume_common.cpp`

```cpp
void LumeCommon::DrawFrame() {
    // Skip conditions
    if ((activateProductBasis_ || activateProductContentBasis_) && useMultiSwapChain_ &&
        GraphicsManager::GetInstance().GetUseBasisEngine()) {
        return;
    }
    if (!loadedScene_ && !hasShaderInput_) {
        WIDGET_LOGD("skip draw frame");
        return;
    }

    auto* ecs = ecs_.get();

    // Step 1: ECS Frame Update
    if (const bool needsRender = engine_->TickFrame(BASE_NS::array_view(&ecs, 1)); needsRender) {

        // Step 2: Collect Render Handles
        CollectRenderHandles();

        // Step 3: Scene Update (Camera Orbit)
        const Core::EngineTime et = engine_->GetEngineTime();
        Tick(et.deltaTimeUs);

        // Step 4: Custom Render Callback
        if (customRender_) {
            customRender_->OnDrawFrame();
        }

        // Step 5: Execute GPU Rendering
        GetRenderContext()->GetRenderer().RenderFrame(
            BASE_NS::array_view(renderHandles_.data(), renderHandles_.size()));

        // Step 6: Memory Barrier
        if (textureInfo_.textureId_ == 0U && textureInfo_.nativeWindow_) {
            return;
        }
        AddTextureMemoryBarrrier();
    }
}
```

### 4.3 Tick函数 - 相机轨道更新

```cpp
void LumeCommon::Tick(const uint64_t deltaTime) {
    if (transformManager_ && sceneManager_ && CORE_NS::EntityUtil::IsValid(cameraEntity_)) {
        orbitCamera_.Update(deltaTime);

        auto const position = orbitCamera_.GetCameraPosition();
        auto const rotation = orbitCamera_.GetCameraRotation();

        // Check if camera needs update
        if (cameraUpdated_ || position != cameraPosition_ ||
            (rotation.x != cameraRotation_.x) || ...) {
            cameraPosition_ = position;
            cameraRotation_ = rotation;

            // Write to TransformComponent
            auto cameraTransform = transformManager_->Write(cameraEntity_);
            cameraTransform->position = position;
            cameraTransform->rotation = rotation;
            cameraUpdated_ = false;
        }
    }
}
```

---

## 5. RenderNodeGraph管线

### 5.1 渲染节点类型

| 节点类型 | 功能 | 输入 | 输出 |
|----------|------|------|------|
| RenderNodeCreateDefaultCamera | 创建GPU图像资源 | - | GpuImages |
| RenderNodeDefaultCameras | 计算相机矩阵 | CameraDataStore | CameraDataBuffer |
| RenderNodeDefaultLights | 处理灯光数据 | LightDataStore | LightDataBuffer |
| RenderNodeDefaultMaterialObjects | 渲染物体 | MaterialDataStore | DrawCalls |
| RenderNodeDefaultEnv | 环境渲染 | EnvDataStore | 环境输出 |
| RenderNodeCameraPostProcessController | 后处理 | ColorTarget | 最终图像 |

### 5.2 RenderNodeDefaultCameras详细流程

文件: `nativerender/Lume_3D/src/render/node/render_node_default_cameras.cpp`

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ InitNode() - 初始化阶段                                                      │
│                                                                              │
│ 1. 获取工具和数据存储:                                                       │
│    - FrustumUtil → 视锥体工具                                                │
│    - SceneRenderDataStores → 数据存储名称                                   │
│                                                                              │
│ 2. 创建GPU缓冲区:                                                            │
│    - CameraDataBuffer (Uniform Buffer) → 存储相机矩阵                       │
│    - EnvironmentBuffer (Uniform Buffer) → 存储环境数据                      │
│                                                                              │
│ 3. 注册输出句柄:                                                             │
│    - RenderNodeGraphShareManager.Register()                                 │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ PreExecuteFrame() - 每帧预处理                                               │
│                                                                              │
│ 1. 重新注册输出句柄 (环形缓冲区偏移变化)                                     │
│ 2. 清空Cubemap相机列表                                                       │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│ ExecuteFrame() - 每帧执行                                                    │
│                                                                              │
│ 1. 获取DataStore:                                                            │
│    - RenderDataStoreDefaultCamera                                            │
│    - RenderDataStoreDefaultLight                                             │
│                                                                              │
│ 2. 处理相机数据:                                                             │
│    ┌─────────────────────────────────────────────────────────────────────┐  │
│    │ 对于每个相机:                                                        │  │
│    │  ├── 计算视图矩阵 (view)                                             │  │
│    │  │   └── Math::LookAtRh(position, lookAt, up)                       │  │
│    │  ├── 计算投影矩阵 (proj + TAA抖动)                                   │  │
│    │  │   └── Math::Perspective(zNear, zFar, fov)                        │  │
│    │  │   └── 添加TAA抖动偏移                                             │  │
│    │  ├── 计算视图-投影矩阵 (viewProj)                                    │  │
│    │  │   └── view * proj                                                 │  │
│    │  ├── 计算阴影偏移矩阵                                                │  │
│    │  ├── 计算视锥体裁剪平面                                              │  │
│    │  │   └── FrustumUtil.CalculatePlanes(viewProj)                      │  │
│    │  └── 写入GPU Buffer                                                   │  │
│    │      └── cameraDataBuffer.Write(data, offset)                       │  │
│    └─────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│ 3. 处理Cubemap相机 (环境反射):                                               │
│    ├── 生成5个额外方向的相机                                                │
│    └── 应用方向旋转矩阵                                                      │
│                                                                              │
│ 4. 处理环境数据:                                                             │
│    ├── 间接高光因子 (specularFactor)                                        │
│    ├── 间接漫反射因子 (diffuseFactor)                                       │
│    ├── 球谐系数 (irradianceCoefficients)                                    │
│    └── 写入EnvironmentBuffer                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 CameraDataBuffer数据结构

```cpp
struct CameraData {
    Math::Mat4X4 view;           // 视图矩阵
    Math::Mat4X4 proj;           // 投影矩阵
    Math::Mat4X4 viewProj;       // 视图-投影矩阵
    Math::Mat4X4 viewInv;        // 视图矩阵逆
    Math::Mat4X4 projInv;        // 投影矩阵逆
    Math::Mat4X4 viewProjInv;    // 视图-投影矩阵逆
    Math::Vec4 position;         // 相机位置
    Math::Vec4 lookAt;           // 观察目标
    Math::Vec4 up;               // 上方向
    float zNear;                 // 近裁剪面
    float zFar;                  // 远裁剪面
    float fov;                   // 视场角
    float aspect;                // 宽高比
    // ... 其他参数
};
```

---

## 6. 使用教程

### 6.1 基础渲染流程使用

```typescript
// NativePage.ets
import native from 'libnativerender.so';
import { FrameNode, NodeController, typeNode, UIContext } from '@kit.ArkUI';

class MyNodeController extends NodeController {
  public xComponent: typeNode.XComponent | undefined;
  public xComponentId: string = 'xcp_' + (new Date().getTime());
  private isBound: boolean = false;

  makeNode(uiContext: UIContext): FrameNode | null {
    // 1. 创建XComponent节点
    this.xComponent = typeNode.createNode(uiContext, 'XComponent', {
      type: XComponentType.SURFACE
    });
    this.xComponent.attribute
      .id(this.xComponentId)
      .width(400)
      .height(400)
      .focusable(true);

    // 2. 绑定渲染器
    native.bindNode(this.xComponentId, this.xComponent);
    this.isBound = true;

    return this.xComponent;
  }

  aboutToDisappear(): void {
    // 7. 解绑清理
    if (this.isBound) {
      native.unbindNode(this.xComponentId);
    }
    this.xComponent?.dispose();
  }
}

@Entry
@Component
struct NativePage {
  @State xComponentId: string = 'xcp_' + (new Date().getTime());
  controller: MyNodeController = new MyNodeController(this.xComponentId);

  build() {
    Column() {
      // 创建渲染容器
      NodeContainer(this.controller)
        .width(400)
        .height(400)

      // 3. 加载场景模型
      Button('加载场景')
        .onClick(() => {
          native.loadScene(this.xComponentId, 'dir/card.gltf');
        })

      // 4. 设置相机位置
      Button('设置相机位置')
        .onClick(() => {
          native.setupCameraPosition(
            this.xComponentId,
            0, 3, 5,    // position (x, y, z) - 相机位置
            0, 0, 0,    // lookAt (x, y, z) - 观察目标
            0, 1, 0     // up (x, y, z) - 上方向
          );
        })

      // 5. 设置相机投影
      Button('设置相机投影')
        .onClick(() => {
          native.setupCameraProjection(
            this.xComponentId,
            0.1,  // zNear - 近裁剪面
            100,  // zFar - 远裁剪面
            60    // fov - 视场角(度)
          );
        })

      // 6. 手动触发渲染
      Button('渲染一帧')
        .onClick(() => {
          native.requestRender(this.xComponentId);
        })
    }
  }
}
```

### 6.2 完整渲染流程步骤说明

```
步骤编号  │  操作                │  调用方法              │  内部执行
─────────┼─────────────────────┼──────────────────────┼──────────────────────────────
    1    │  创建XComponent容器  │  native.bindNode()    │  创建EGL环境、初始化Lume引擎
    2    │  自动触发Surface创建 │  OnSurfaceCreatedNative │  InitializeEGL + InitializeLumeEngine
    3    │  初始化场景          │  InitializeScene()    │  CreateEcs + LoadSystemGraph + CreateCamera
    4    │  加载场景模型        │  native.loadScene()   │  LoadSceneModel → GLTF加载
    5    │  设置相机参数        │  native.setupCamera*  │  SetupCameraTransform/Projection
    6    │  帧渲染(自动)        │  OnFrameCallbackNative │  DrawFrame → RenderNodeGraph
    7    │  清理资源            │  native.unbindNode()  │  OnSurfaceDestroyed → Deinit
```

### 6.3 渲染链嵌入位置图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Scene控制如何嵌入渲染链                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Scene控制接口                ECS组件更新                  渲染管线输入       │
│  ─────────────               ─────────────               ─────────────       │
│                                                                              │
│  LoadSceneModel()      →     MeshComponent          →    RenderMeshBatch     │
│                         →     MaterialComponent      →    MaterialDataStore   │
│                         →     AnimationComponent     →    AnimationPlayback   │
│                                                                              │
│  SetupCameraTransform() →    TransformComponent     →    CameraDataBuffer    │
│                         →     CameraComponent        →    视图/投影矩阵       │
│                                                                              │
│  UpdateLights()         →     LightComponent        →    LightDataBuffer     │
│                         →     TransformComponent     →    灯光位置/方向       │
│                                                                              │
│  UpdateGeometries()     →     RenderMeshComponent   →    DrawCalls           │
│                         →     MeshComponent          →    几何数据            │
│                                                                              │
│  customRender_          →     自定义渲染节点         →    额外渲染通道        │
│                         →     ShaderInputBuffer      →    自定义Shader输入    │
│                                                                              │
│  ────────────────────────────────────────────────────────────────────────   │
│                              ↓                                               │
│  ────────────────────────────────────────────────────────────────────────   │
│                        RenderNodeGraph执行                                   │
│  ────────────────────────────────────────────────────────────────────────   │
│  RenderNodeDefaultCameras → 读取CameraDataBuffer → 计算相机矩阵             │
│  RenderNodeDefaultLights  → 读取LightDataBuffer  → 处理灯光                 │
│  RenderNodeDefaultMaterial → 读取MaterialDataStore → 渲染物体               │
│  RenderNodeDefaultEnv     → 读取EnvDataStore     → 环境渲染                 │
│  RenderNodePostProcess    → 后处理效果            → 最终图像                 │
│                              ↓                                               │
│  ────────────────────────────────────────────────────────────────────────   │
│                        GPU执行 → Swapchain → 图像输出                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.4 高级用法 - 自定义渲染

```typescript
// 使用自定义渲染节点
Button('启用自定义渲染')
  .onClick(() => {
    native.updateCustomRender(this.xComponentId, {
      uri: 'custom://my_render_node_graph.rng',
      shaderPath: 'shaders://my_shader.shader',
      imageTextures: ['textures://noise.png'],
      needsFrameCallback: true
    });
  })

// 更新Shader输入
Button('更新Shader参数')
  .onClick(() => {
    native.updateShaderInputBuffer(this.xComponentId, {
      time: performance.now(),
      resolution: [400, 400],
      customData: [1.0, 0.5, 0.3, 0.7]
    });
  })
```

---

## 7. 关键文件路径

### 7.1 核心文件列表

| 模块 | 文件路径 | 功能 |
|------|----------|------|
| NAPI入口 | `nativerender/napi_init.cpp` | ArkTS接口注册 |
| XComponent管理器 | `nativerender/manager/src/lume_xcomponent_manager.cpp` | NAPI方法实现 |
| XComponent管理器头文件 | `nativerender/manager/include/lume_xcomponent_manager.h` | 接口声明 |
| 渲染适配器 | `nativerender/manager/include/lume_renderer.h` | LumeRenderer类 |
| 渲染适配器实现 | `nativerender/manager/src/lume_renderer.cpp` | 渲染适配实现 |
| 引擎接口 | `nativerender/3d_widget_adapter/include/i_engine.h` | IEngine抽象接口 |
| 核心渲染实现 | `nativerender/3d_widget_adapter/core/src/lume/lume_common.cpp` | DrawFrame实现 |
| Lume通用头文件 | `nativerender/3d_widget_adapter/core/include/lume/lume_common.h` | LumeCommon类 |
| Scene适配器接口 | `nativerender/3d_scene_adapter/include/scene_adapter/intf_scene_adapter.h` | ISceneAdapter接口 |
| Scene适配器实现 | `nativerender/3d_scene_adapter/src/scene_adapter/scene_adapter.cpp` | SceneAdapter实现 |
| TypeScript类型定义 | `nativerender/Index.d.ts` | ArkTS类型定义 |

### 7.2 Lume Engine核心文件

| 模块 | 文件路径 | 功能 |
|------|----------|------|
| 相机渲染节点 | `nativerender/Lume_3D/src/render/node/render_node_default_cameras.cpp` | 相机矩阵计算 |
| 灯光渲染节点 | `nativerender/Lume_3D/src/render/node/render_node_default_lights.cpp` | 灯光处理 |
| 环境渲染节点 | `nativerender/Lume_3D/src/render/node/render_node_default_env.cpp` | 环境渲染 |
| 材质渲染节点 | `nativerender/Lume_3D/src/render/node/render_node_default_material_render_slot.cpp` | 材质渲染 |
| 渲染节点接口 | `nativerender/LumeRender/api/render/nodecontext/intf_render_node.h` | IRenderNode接口 |
| 渲染器接口 | `nativerender/LumeRender/api/render/intf_renderer.h` | IRenderer接口 |

### 7.3 ArkTS使用示例

| 文件 | 路径 | 功能 |
|------|------|------|
| NativePage示例 | `ets/pages/NativePage.ets` | XComponent基础使用 |
| SceneProxy示例 | `ets/core/scene3D/GlobalSceneProxy.ets` | 高级Scene控制 |

---

## 附录A: 数据类型定义

### A.1 相机参数类型

```cpp
// Position - 位置参数
struct Position {
    float x, y, z;
    float distance;     // 轨道距离
    bool isAngular;     // 是否为角度坐标
};

// Vec3 - 三维向量
struct Vec3 {
    float x, y, z;
};

// Quaternion - 四元数
struct Quaternion {
    float x, y, z, w;
};
```

### A.2 触摸事件类型

```cpp
enum PointerEventType {
    PRESSED,    // 按下
    RELEASED,   // 释放
    MOVED,      // 移动
    CANCELLED   // 取消
};

struct PointerEvent {
    int32_t pointerId;
    int32_t buttonIndex;
    float x, y;
    float deltaX, deltaY;
    PointerEventType eventType;
    float force;      // 按压力度
};
```

---

## 附录B: GLTF加载参数

```cpp
struct GltfImportInfo {
    const char* fileName_;
    TargetType target_;
    uint32_t resourceImportFlags_;
    uint32_t sceneImportFlags_;
};

// 导入标志
constexpr uint32_t CORE_GLTF_IMPORT_RESOURCE_FLAG_BITS_ALL = 0xFFFFFFFF;
constexpr uint32_t CORE_GLTF_IMPORT_COMPONENT_FLAG_BITS_ALL = 0xFFFFFFFF;

// 目标类型
enum TargetType {
    AnimateImportedScene,  // 动画导入场景
    DefaultScene           // 默认场景
};
```

---

**文档版本**: 1.0
**最后更新**: 2026-03-31
**作者**: Claude Code Assistant