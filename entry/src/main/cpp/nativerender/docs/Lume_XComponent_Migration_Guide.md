# Lume引擎迁移到XComponent渲染指南

## 一、概述

本文档描述如何将Lume 3D渲染引擎从当前的渲染模式迁移到HarmonyOS XComponent渲染方式。XComponent是HarmonyOS提供的Native渲染组件，允许直接使用OpenGL ES进行渲染。

## 二、Scene与渲染连接的核心架构

### 2.1 核心组件关系图

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Application Layer                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│  │  ArkTS/JS    │───►│  NAPI Layer  │───►│  SceneAdapter/       │   │
│  │  UI Code     │    │  (Bridge)    │    │  LumeXComponentMgr   │   │
│  └──────────────┘    └──────────────┘    └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           Scene Layer                                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│  │   IScene     │───►│   ICamera    │───►│   IRenderTarget      │   │
│  │   (场景)     │    │   (相机)     │    │   (渲染目标)         │   │
│  └──────────────┘    └──────────────┘    └──────────────────────┘   │
│         │                   │                      │                 │
│         ▼                   ▼                      ▼                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│  │   INode      │    │ PostProcess  │    │   Swapchain/Bitmap   │   │
│  │   (节点树)   │    │ (后处理)     │    │   (交换链)           │   │
│  └──────────────┘    └──────────────┘    └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          Render Layer                                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│  │ IRenderContext│───►│   IDevice   │───►│   IRenderer          │   │
│  │ (渲染上下文) │    │  (GLES设备) │    │   (渲染器)           │   │
│  └──────────────┘    └──────────────┘    └──────────────────────┘   │
│         │                   │                      │                 │
│         ▼                   ▼                      ▼                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│  │ ShaderManager│    │ GPUResourceManager│ │ RenderNodeGraph    │   │
│  │ (着色器)     │    │ (GPU资源)    │    │   (渲染节点图)       │   │
│  └──────────────┘    └──────────────┘    └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           EGL Layer                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│  │ EGLDisplay   │    │ EGLSurface   │    │   EGLContext         │   │
│  └──────────────┘    └──────────────┘    └──────────────────────┘   │
│                              │                                       │
│                              ▼                                       │
│                      ┌──────────────┐                               │
│                      │ NativeWindow │◄── XComponent提供             │
│                      └──────────────┘                               │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Scene与渲染的连接流程

```
Step 1: 创建Engine和RenderContext
        │
        ▼
Step 2: 创建ApplicationContext (包含RenderContext)
        │
        ▼
Step 3: 创建Scene (通过SceneManager或加载gltf)
        │
        ▼
Step 4: 获取Scene中的Camera
        │
        ▼
Step 5: 创建Swapchain (关联NativeWindow)
        │
        ▼
Step 6: 创建IRenderTarget (Bitmap)，设置Swapchain句柄
        │
        ▼
Step 7: 调用Camera::SetRenderTarget(bitmap)
        │
        ▼
Step 8: 渲染循环: Scene::Update() → RenderContext::RenderFrame()
```

## 三、关键代码详解

### 3.1 初始化Engine和RenderContext

```cpp
// 来自 scene_adapter.cpp InitEngine()

// 1. 创建Engine
CORE_NS::EngineCreateInfo engineCreateInfo{platformCreateInfo, {}, {}};
auto factory = CORE_NS::GetInstance<CORE_NS::IEngineFactory>(CORE_NS::UID_ENGINE_FACTORY);
engineInstance_.engine_.reset(factory->Create(engineCreateInfo).get());

// 2. 初始化Engine
auto& fileManager = engineInstance_.engine_->GetFileManager();
platform.RegisterDefaultPaths(fileManager);
engineInstance_.engine_->Init();

// 3. 配置GLES后端
RENDER_NS::RenderCreateInfo renderCreateInfo{};
RENDER_NS::BackendExtraGLES glExtra{};
Render::DeviceCreateInfo deviceCreateInfo{};

glExtra.depthBits = 24;
glExtra.sharedContext = EGL_NO_CONTEXT;
deviceCreateInfo.backendType = RENDER_NS::DeviceBackendType::OPENGLES;
deviceCreateInfo.backendConfiguration = &glExtra;
renderCreateInfo.deviceCreateInfo = deviceCreateInfo;

// 4. 创建RenderContext
engineInstance_.renderContext_.reset(
    static_cast<RENDER_NS::IRenderContext*>(
        engineInstance_.engine_->GetInterface<CORE_NS::IClassFactory>()
            ->CreateInstance(RENDER_NS::UID_RENDER_CONTEXT)
            .release()));

// 5. 初始化RenderContext
auto result = engineInstance_.renderContext_->Init(renderCreateInfo);
```

### 3.2 创建ApplicationContext（连接Scene和Render的桥梁）

```cpp
// 创建ApplicationContext - 这是Scene与RenderContext之间的桥梁
engineInstance_.applicationContext_ =
    META_NS::GetObjectRegistry().Create<SCENE_NS::IApplicationContext>(
        SCENE_NS::ClassId::ApplicationContext);

// 配置ApplicationContext
SCENE_NS::IApplicationContext::ApplicationContextInfo info{
    engineThread,      // 引擎任务队列
    appThread,         // 应用任务队列
    engineInstance_.renderContext_,  // ★ 关键：RenderContext
    resources,         // 资源管理器
    SCENE_NS::SceneOptions{}
};
engineInstance_.applicationContext_->Initialize(info);
```

### 3.3 创建Scene并设置渲染目标

```cpp
// 来自 scene_adapter.cpp OnWindowChange()

// 1. 创建Swapchain（关联NativeWindow）
RENDER_NS::SwapchainCreateInfo swapchainCreateInfo {
    0U,
    RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_COLOR_BUFFER_BIT |
    RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_DEPTH_BUFFER_BIT,
    RENDER_NS::ImageUsageFlagBits::CORE_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
    {
        reinterpret_cast<uintptr_t>(nativeWindow),  // ★ XComponent提供的NativeWindow
        {},
    }
};
swapchainHandle_ = device.CreateSwapchainHandle(swapchainCreateInfo, swapchainHandle_, {});

// 2. 创建RenderTarget (Bitmap)
auto& obr = META_NS::GetObjectRegistry();
bitmap_ = obr.Create<SCENE_NS::IRenderTarget>(SCENE_NS::ClassId::Bitmap, doc);

// 3. 将Swapchain句柄设置给RenderTarget
if (auto i = interface_cast<SCENE_NS::IRenderResource>(bitmap_)) {
    i->SetRenderHandle(swapchainHandle_);  // ★ 关键连接
}

// 4. 获取Scene中的Camera并设置RenderTarget
if (auto scene = interface_pointer_cast<SCENE_NS::IScene>(sceneWidgetObj_)) {
    auto cams = scene->GetCameras().GetResult();
    for (auto c : cams) {
        // ★ 关键：将RenderTarget绑定到Camera
        AttachSwapchain(interface_pointer_cast<META_NS::IObject>(c));
    }
}
```

### 3.4 AttachSwapchain详解

```cpp
void SceneAdapter::AttachSwapchain(META_NS::IObject::Ptr cameraObj)
{
    auto camera = interface_pointer_cast<SCENE_NS::ICamera>(cameraObj);
    if (!camera) {
        return;
    }
    if (!bitmap_ || !camera->IsActive()) {
        camera->SetRenderTarget({});  // 清除渲染目标
        return;
    }
    // ★ 核心：将Bitmap(RenderTarget)设置给Camera
    // 这建立了Camera → RenderTarget → Swapchain → NativeWindow的渲染链路
    camera->SetRenderTarget(bitmap_);
}
```

### 3.5 渲染循环

```cpp
void SceneAdapter::RenderFunction()
{
    auto rc = engineInstance_.renderContext_;
    auto scene = interface_pointer_cast<SCENE_NS::IScene>(sceneWidgetObj_);

    // 1. 更新Scene（更新变换、动画等）
    scene->GetInternalScene()->Update(false);

    // 2. 执行渲染
    // RenderContext内部会：
    //   - 遍历所有活跃Camera
    //   - 每个Camera渲染到其RenderTarget
    //   - 最终输出到Swapchain
    //   - eglSwapBuffers()
}
```

## 四、XComponent迁移实现

### 4.1 当前架构与目标架构对比

```
【当前：通过TextureLayer/SurfaceBuffer】
ArkTS ComponentWidget
    │
    ▼
TextureLayer (管理SurfaceBuffer)
    │
    ▼
NativeWindow (通过OH_NativeWindow)
    │
    ▼
Swapchain → Camera.RenderTarget

【目标：直接使用XComponent】
ArkTS XComponent
    │
    ▼
OH_NativeXComponent_Callback
    │
    ├─ OnSurfaceCreated → 获取NativeWindow
    ├─ OnSurfaceChanged → 调整尺寸
    └─ OnSurfaceDestroyed → 释放资源
    │
    ▼
Swapchain → Camera.RenderTarget
```

### 4.2 XComponent获取NativeWindow的关键代码

```cpp
// XComponent回调中获取NativeWindow
void OnSurfaceCreatedCB(OH_NativeXComponent* component, void* window)
{
    // window 就是 NativeWindow (EGLNativeWindowType)
    // 可以直接用于创建EGLSurface或Swapchain

    // 方式1：直接用于EGL
    EGLNativeWindowType eglWindow = (EGLNativeWindowType)window;
    eglSurface_ = eglCreateWindowSurface(eglDisplay_, eglConfig_, eglWindow, NULL);

    // 方式2：用于Lume Swapchain
    RENDER_NS::SwapchainCreateInfo swapchainCreateInfo {
        0U,
        RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_COLOR_BUFFER_BIT,
        RENDER_NS::ImageUsageFlagBits::CORE_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        {
            reinterpret_cast<uintptr_t>(window),  // 直接使用
            {},
        }
    };
    swapchainHandle_ = device.CreateSwapchainHandle(swapchainCreateInfo, ...);
}
```

## 五、迁移步骤

### 步骤1：创建XComponent管理器

创建文件 `nativerender/lume_xcomponent/lume_xcomponent_manager.h`:

```cpp
#ifndef LUME_XCOMPONENT_MANAGER_H
#define LUME_XCOMPONENT_MANAGER_H

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <napi/native_api.h>
#include <unordered_map>
#include <memory>
#include <EGL/egl.h>

// Lume引擎头文件
#include <core/intf_engine.h>
#include <render/intf_render_context.h>

namespace LumeXComponent {

class LumeRenderer;

class LumeXComponentManager {
public:
    static LumeXComponentManager& GetInstance();

    // NAPI导出接口
    static napi_value CreateNativeNode(napi_env env, napi_callback_info info);
    static napi_value BindNode(napi_env env, napi_callback_info info);
    static napi_value UnbindNode(napi_env env, napi_callback_info info);
    static napi_value DrawFrame(napi_env env, napi_callback_info info);

    // XComponent回调
    void OnSurfaceCreated(OH_NativeXComponent* component, void* window);
    void OnSurfaceChanged(OH_NativeXComponent* component, void* window);
    void OnSurfaceDestroyed(OH_NativeXComponent* component, void* window);
    void DispatchTouchEvent(OH_NativeXComponent* component, void* window);

    // 渲染器管理
    LumeRenderer* GetRenderer(const std::string& id);
    void RegisterXComponent(const std::string& id, OH_NativeXComponent* component);

private:
    LumeXComponentManager() = default;
    ~LumeXComponentManager();

    static OH_NativeXComponent_Callback xcomponentCallback_;

    std::unordered_map<std::string, OH_NativeXComponent*> xcomponentMap_;
    std::unordered_map<std::string, std::unique_ptr<LumeRenderer>> rendererMap_;
};

} // namespace LumeXComponent

#endif // LUME_XCOMPONENT_MANAGER_H
```

### 步骤2：创建Lume渲染器

创建文件 `nativerender/lume_xcomponent/lume_renderer.h`:

```cpp
#ifndef LUME_RENDERER_H
#define LUME_RENDERER_H

#include <EGL/egl.h>
#include <memory>

// Lume引擎
#include <core/intf_engine.h>
#include <render/intf_render_context.h>
#include <render/gles/intf_device_gles.h>

namespace LumeXComponent {

class LumeRenderer {
public:
    LumeRenderer();
    ~LumeRenderer();

    // EGL初始化
    bool InitializeEGL(void* window);
    void DestroyEGL();

    // Lume引擎初始化
    bool InitializeLume();
    void DeinitializeLume();

    // 渲染
    void OnSurfaceCreated(void* window);
    void OnSurfaceChanged(int width, int height);
    void OnSurfaceDestroyed();
    void DrawFrame();

    // 尺寸
    void SetSize(int width, int height) { width_ = width; height_ = height; }

private:
    // EGL相关
    EGLDisplay eglDisplay_ = EGL_NO_DISPLAY;
    EGLSurface eglSurface_ = EGL_NO_SURFACE;
    EGLContext eglContext_ = EGL_NO_CONTEXT;
    EGLConfig eglConfig_ = nullptr;
    EGLNativeWindowType eglWindow_ = nullptr;

    // Lume引擎相关
    CORE_NS::IEngine::Ptr engine_;
    RENDER_NS::IRenderContext::Ptr renderContext_;

    // 窗口尺寸
    int width_ = 0;
    int height_ = 0;

    // 状态
    bool eglInitialized_ = false;
    bool lumeInitialized_ = false;
};

} // namespace LumeXComponent

#endif // LUME_RENDERER_H
```

### 步骤3：实现EGL初始化

创建文件 `nativerender/lume_xcomponent/lume_renderer.cpp`:

```cpp
#include "lume_renderer.h"
#include <hilog/log.h>
#include <GLES3/gl3.h>

using namespace LumeXComponent;
using namespace CORE_NS;
using namespace RENDER_NS;

namespace {
    // EGL配置
    const EGLint EGL_ATTRIBS[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_STENCIL_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_NONE
    };

    const EGLint EGL_CONTEXT_ATTRIBS[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };
}

LumeRenderer::LumeRenderer() {}

LumeRenderer::~LumeRenderer() {
    DeinitializeLume();
    DestroyEGL();
}

bool LumeRenderer::InitializeEGL(void* window) {
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "InitializeEGL");

    eglWindow_ = (EGLNativeWindowType)window;

    // 1. 获取EGL Display
    eglDisplay_ = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (eglDisplay_ == EGL_NO_DISPLAY) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "eglGetDisplay failed");
        return false;
    }

    // 2. 初始化EGL
    EGLint major, minor;
    if (!eglInitialize(eglDisplay_, &major, &minor)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "eglInitialize failed");
        return false;
    }

    // 3. 选择配置
    EGLint numConfigs;
    if (!eglChooseConfig(eglDisplay_, EGL_ATTRIBS, &eglConfig_, 1, &numConfigs)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "eglChooseConfig failed");
        return false;
    }

    // 4. 创建Surface
    eglSurface_ = eglCreateWindowSurface(eglDisplay_, eglConfig_, eglWindow_, nullptr);
    if (eglSurface_ == EGL_NO_SURFACE) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "eglCreateWindowSurface failed");
        return false;
    }

    // 5. 创建Context
    eglContext_ = eglCreateContext(eglDisplay_, eglConfig_, EGL_NO_CONTEXT, EGL_CONTEXT_ATTRIBS);
    if (eglContext_ == EGL_NO_CONTEXT) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "eglCreateContext failed");
        return false;
    }

    // 6. 绑定Context
    if (!eglMakeCurrent(eglDisplay_, eglSurface_, eglSurface_, eglContext_)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "eglMakeCurrent failed");
        return false;
    }

    eglInitialized_ = true;
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "EGL initialized successfully");
    return true;
}

void LumeRenderer::DestroyEGL() {
    if (!eglInitialized_) return;

    eglMakeCurrent(eglDisplay_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

    if (eglSurface_ != EGL_NO_SURFACE) {
        eglDestroySurface(eglDisplay_, eglSurface_);
        eglSurface_ = EGL_NO_SURFACE;
    }

    if (eglContext_ != EGL_NO_CONTEXT) {
        eglDestroyContext(eglDisplay_, eglContext_);
        eglContext_ = EGL_NO_CONTEXT;
    }

    if (eglDisplay_ != EGL_NO_DISPLAY) {
        eglTerminate(eglDisplay_);
        eglDisplay_ = EGL_NO_DISPLAY;
    }

    eglInitialized_ = false;
}
```

### 步骤4：实现Lume引擎初始化

继续在 `lume_renderer.cpp` 中添加:

```cpp
bool LumeRenderer::InitializeLume() {
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "InitializeLume");

    // 1. 创建引擎
    engine_ = CORE_NS::IEngine::Get(CORE_NS::IEngine::UID_ENGINE);
    if (!engine_) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to get engine");
        return false;
    }

    // 2. 配置平台信息
    CORE_NS::PlatformCreateInfo platformCreateInfo{};
    // 设置必要的平台回调

    // 3. 初始化引擎
    if (!engine_->Init()) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Engine init failed");
        return false;
    }

    // 4. 创建渲染上下文
    RENDER_NS::RenderCreateInfo renderCreateInfo{};
    RENDER_NS::BackendExtraGLES glesConfig{};

    glesConfig.depthBits = 24;
    glesConfig.sharedContext = eglContext_; // 使用已创建的EGL Context

    RENDER_NS::DeviceCreateInfo deviceCreateInfo{};
    deviceCreateInfo.backendType = RENDER_NS::DeviceBackendType::OPENGLES;
    deviceCreateInfo.backendConfiguration = &glesConfig;

    renderCreateInfo.deviceCreateInfo = deviceCreateInfo;

    // 5. 获取渲染上下文
    renderContext_ = engine_->GetInterface<RENDER_NS::IRenderContext>();
    if (!renderContext_) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to get render context");
        return false;
    }

    // 6. 初始化渲染上下文
    auto result = renderContext_->Init(renderCreateInfo);
    if (result != RENDER_NS::RenderResultCode::RENDER_SUCCESS) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Render context init failed");
        return false;
    }

    // 7. 加载必要插件
    // JPG, PNG, Scene等插件

    lumeInitialized_ = true;
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "Lume initialized successfully");
    return true;
}

void LumeRenderer::DeinitializeLume() {
    if (!lumeInitialized_) return;

    renderContext_.reset();
    engine_.reset();
    lumeInitialized_ = false;
}
```

### 步骤5：实现渲染循环

继续在 `lume_renderer.cpp` 中添加:

```cpp
void LumeRenderer::OnSurfaceCreated(void* window) {
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "OnSurfaceCreated");

    // 1. 初始化EGL
    if (!InitializeEGL(window)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to initialize EGL");
        return;
    }

    // 2. 初始化Lume
    if (!InitializeLume()) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to initialize Lume");
        return;
    }
}

void LumeRenderer::OnSurfaceChanged(int width, int height) {
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer",
                 "OnSurfaceChanged: %d x %d", width, height);

    width_ = width;
    height_ = height;

    // 更新视口
    glViewport(0, 0, width, height);

    // 通知Lume尺寸变化
    if (renderContext_) {
        // renderContext_->SetViewport(width, height);
    }
}

void LumeRenderer::OnSurfaceDestroyed() {
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "OnSurfaceDestroyed");

    DeinitializeLume();
    DestroyEGL();
}

void LumeRenderer::DrawFrame() {
    if (!eglInitialized_ || !lumeInitialized_) {
        return;
    }

    // 绑定EGL Context
    if (!eglMakeCurrent(eglDisplay_, eglSurface_, eglSurface_, eglContext_)) {
        return;
    }

    // 清屏
    glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // 调用Lume渲染
    if (renderContext_) {
        // renderContext_->RenderFrame();
    }

    // 交换缓冲区
    eglSwapBuffers(eglDisplay_, eglSurface_);
}
```

### 步骤6：实现XComponent管理器

创建文件 `nativerender/lume_xcomponent/lume_xcomponent_manager.cpp`:

```cpp
#include "lume_xcomponent_manager.h"
#include "lume_renderer.h"
#include <hilog/log.h>

using namespace LumeXComponent;

// 静态成员
OH_NativeXComponent_Callback LumeXComponentManager::xcomponentCallback_;

// C回调函数
static void OnSurfaceCreatedCB(OH_NativeXComponent* component, void* window) {
    auto* manager = &LumeXComponentManager::GetInstance();
    manager->OnSurfaceCreated(component, window);
}

static void OnSurfaceChangedCB(OH_NativeXComponent* component, void* window) {
    auto* manager = &LumeXComponentManager::GetInstance();
    manager->OnSurfaceChanged(component, window);
}

static void OnSurfaceDestroyedCB(OH_NativeXComponent* component, void* window) {
    auto* manager = &LumeXComponentManager::GetInstance();
    manager->OnSurfaceDestroyed(component, window);
}

static void DispatchTouchEventCB(OH_NativeXComponent* component, void* window) {
    auto* manager = &LumeXComponentManager::GetInstance();
    manager->DispatchTouchEvent(component, window);
}

LumeXComponentManager& LumeXComponentManager::GetInstance() {
    static LumeXComponentManager instance;
    return instance;
}

LumeXComponentManager::~LumeXComponentManager() {
    rendererMap_.clear();
}

void LumeXComponentManager::RegisterXComponent(const std::string& id, OH_NativeXComponent* component) {
    xcomponentMap_[id] = component;

    // 设置回调
    xcomponentCallback_.OnSurfaceCreated = OnSurfaceCreatedCB;
    xcomponentCallback_.OnSurfaceChanged = OnSurfaceChangedCB;
    xcomponentCallback_.OnSurfaceDestroyed = OnSurfaceDestroyedCB;
    xcomponentCallback_.DispatchTouchEvent = DispatchTouchEventCB;

    OH_NativeXComponent_RegisterCallback(component, &xcomponentCallback_);
}

void LumeXComponentManager::OnSurfaceCreated(OH_NativeXComponent* component, void* window) {
    char idStr[OH_XCOMPONENT_ID_LEN_MAX + 1] = {};
    uint64_t idSize = OH_XCOMPONENT_ID_LEN_MAX + 1;
    OH_NativeXComponent_GetXComponentId(component, idStr, &idSize);

    std::string id(idStr);
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeXComponentManager",
                 "OnSurfaceCreated: %s", id.c_str());

    auto renderer = std::make_unique<LumeRenderer>();
    renderer->OnSurfaceCreated(window);
    rendererMap_[id] = std::move(renderer);
}

void LumeXComponentManager::OnSurfaceChanged(OH_NativeXComponent* component, void* window) {
    char idStr[OH_XCOMPONENT_ID_LEN_MAX + 1] = {};
    uint64_t idSize = OH_XCOMPONENT_ID_LEN_MAX + 1;
    OH_NativeXComponent_GetXComponentId(component, idStr, &idSize);

    std::string id(idStr);

    uint64_t width, height;
    OH_NativeXComponent_GetXComponentSize(component, window, &width, &height);

    auto it = rendererMap_.find(id);
    if (it != rendererMap_.end()) {
        it->second->OnSurfaceChanged(static_cast<int>(width), static_cast<int>(height));
    }
}

void LumeXComponentManager::OnSurfaceDestroyed(OH_NativeXComponent* component, void* window) {
    char idStr[OH_XCOMPONENT_ID_LEN_MAX + 1] = {};
    uint64_t idSize = OH_XCOMPONENT_ID_LEN_MAX + 1;
    OH_NativeXComponent_GetXComponentId(component, idStr, &idSize);

    std::string id(idStr);
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeXComponentManager",
                 "OnSurfaceDestroyed: %s", id.c_str());

    auto it = rendererMap_.find(id);
    if (it != rendererMap_.end()) {
        it->second->OnSurfaceDestroyed();
        rendererMap_.erase(it);
    }
}

void LumeXComponentManager::DispatchTouchEvent(OH_NativeXComponent* component, void* window) {
    // 处理触摸事件
    OH_NativeXComponent_TouchEvent touchEvent;
    OH_NativeXComponent_GetTouchEvent(component, window, &touchEvent);

    // 传递给渲染器处理
}

LumeRenderer* LumeXComponentManager::GetRenderer(const std::string& id) {
    auto it = rendererMap_.find(id);
    return it != rendererMap_.end() ? it->second.get() : nullptr;
}

// NAPI导出
napi_value LumeXComponentManager::CreateNativeNode(napi_env env, napi_callback_info info) {
    // 参考现有plugin_manager.cpp实现
    return nullptr;
}

napi_value LumeXComponentManager::BindNode(napi_env env, napi_callback_info info) {
    // 参考现有plugin_manager.cpp实现
    return nullptr;
}

napi_value LumeXComponentManager::UnbindNode(napi_env env, napi_callback_info info) {
    // 参考现有plugin_manager.cpp实现
    return nullptr;
}

napi_value LumeXComponentManager::DrawFrame(napi_env env, napi_callback_info info) {
    // 触发渲染
    return nullptr;
}
```

### 步骤7：创建CMakeLists.txt

创建文件 `nativerender/lume_xcomponent/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.18)

set(LUME_XCOMPONENT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

set(LUME_XCOMPONENT_SOURCES
    lume_xcomponent_manager.cpp
    lume_renderer.cpp
)

add_library(lume_xcomponent STATIC ${LUME_XCOMPONENT_SOURCES})

target_include_directories(lume_xcomponent PUBLIC
    ${LUME_XCOMPONENT_ROOT}
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/platform/ohos
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
)

target_link_libraries(lume_xcomponent PUBLIC
    LumeBase
    libAGPEngine
    lume_render
    ${EGL-lib}
    ${GLES-lib}
    ${hilog-lib}
)

target_compile_definitions(lume_xcomponent PUBLIC
    __OHOS_PLATFORM__
)
```

### 步骤8：NAPI模块初始化

创建文件 `nativerender/lume_xcomponent/napi_init.cpp`:

```cpp
#include <napi/native_api.h>
#include "lume_xcomponent_manager.h"

using namespace LumeXComponent;

static napi_value Export(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        DECLARE_NAPI_FUNCTION("createNativeNode", LumeXComponentManager::CreateNativeNode),
        DECLARE_NAPI_FUNCTION("bindNode", LumeXComponentManager::BindNode),
        DECLARE_NAPI_FUNCTION("unbindNode", LumeXComponentManager::UnbindNode),
        DECLARE_NAPI_FUNCTION("drawFrame", LumeXComponentManager::DrawFrame),
    };

    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Export,
    .nm_modname = "lume_xcomponent",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterModule(void) {
    napi_module_register(&demoModule);
}
```

## 六、ArkTS调用示例

```typescript
// index.ets
import lumeXComponent from 'lume_xcomponent';

@Entry
@Component
struct Index {
  private xcomponentController: XComponentController = new XComponentController();

  build() {
    Column() {
      XComponent({
        id: 'lume_xcomponent',
        type: XComponentType.SURFACE,
        controller: this.xcomponentController
      })
        .onLoad(() => {
          lumeXComponent.createNativeNode(this.xcomponentController, 'lume_xcomponent');
        })
        .width('100%')
        .height('100%')
    }
  }
}
```

## 七、Scene创建与渲染连接完整示例

### 7.1 扩展LumeRenderer支持Scene

更新 `lume_renderer.h` 添加Scene相关成员：

```cpp
// lume_renderer.h 中添加

#include <scene/interface/intf_scene.h>
#include <scene/interface/intf_camera.h>
#include <scene/interface/intf_render_target.h>
#include <scene/interface/intf_application_context.h>

class LumeRenderer {
public:
    // ... 之前的代码 ...

    // Scene相关方法
    bool CreateScene();
    bool LoadScene(const std::string& path);
    void SetScene(SCENE_NS::IScene::Ptr scene);

    // 获取Scene
    SCENE_NS::IScene::Ptr GetScene() const { return scene_; }

private:
    // ... 之前的成员 ...

    // Scene相关成员
    SCENE_NS::IApplicationContext::Ptr applicationContext_;
    SCENE_NS::IScene::Ptr scene_;
    SCENE_NS::ICamera::Ptr mainCamera_;
    SCENE_NS::IRenderTarget::Ptr renderTarget_;
    RENDER_NS::RenderHandleReference swapchainHandle_;
};
```

### 7.2 完整的Lume初始化（包含Scene支持）

```cpp
// lume_renderer.cpp

bool LumeRenderer::InitializeLume() {
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "InitializeLume");

    // ========== Step 1: 创建引擎工厂和引擎 ==========
    auto factory = CORE_NS::GetInstance<CORE_NS::IEngineFactory>(CORE_NS::UID_ENGINE_FACTORY);
    if (!factory) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to get engine factory");
        return false;
    }

    CORE_NS::PlatformCreateInfo platformCreateInfo{
        "",   // coreRootPath
        "",   // corePluginPath
        "",   // appRootPath
        "",   // appPluginPath
        "",   // hapPath
        "",   // bundleName
        "",   // moduleName
        nullptr  // resourceManager
    };

    CORE_NS::EngineCreateInfo engineCreateInfo{platformCreateInfo, {}, {}};
    engine_ = CORE_NS::IEngine::Ptr(factory->Create(engineCreateInfo).get(), CORE_NS::IEngine::Ptr::ref_count);

    if (!engine_) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to create engine");
        return false;
    }

    // ========== Step 2: 初始化引擎 ==========
    auto& fileManager = engine_->GetFileManager();
    auto& platform = engine_->GetPlatform();
    platform.RegisterDefaultPaths(fileManager);
    engine_->Init();

    // ========== Step 3: 创建RenderContext (GLES) ==========
    RENDER_NS::RenderCreateInfo renderCreateInfo{};
    RENDER_NS::BackendExtraGLES glesConfig{};
    Render::DeviceCreateInfo deviceCreateInfo{};

    // 重要：使用已创建的EGL Context
    glesConfig.depthBits = 24;
    glesConfig.sharedContext = eglContext_;  // ★ 关键：共享XComponent的EGL Context

    deviceCreateInfo.backendType = RENDER_NS::DeviceBackendType::OPENGLES;
    deviceCreateInfo.backendConfiguration = &glesConfig;
    renderCreateInfo.deviceCreateInfo = deviceCreateInfo;

    // 创建RenderContext
    renderContext_ = RENDER_NS::IRenderContext::Ptr(
        engine_->GetInterface<CORE_NS::IClassFactory>()
            ->CreateInstance(RENDER_NS::UID_RENDER_CONTEXT).release(),
        RENDER_NS::IRenderContext::Ptr::ref_count);

    auto result = renderContext_->Init(renderCreateInfo);
    if (result != RENDER_NS::RenderResultCode::RENDER_SUCCESS) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "RenderContext init failed");
        return false;
    }

    // ========== Step 4: 加载必要插件 ==========
    BASE_NS::vector<BASE_NS::Uid> plugins = {
        SCENE_NS::UID_SCENE_PLUGIN,  // Scene插件
        JPGPlugin::UID_JPG_PLUGIN,   // JPG图片支持
        PNGPlugin::UID_PNG_PLUGIN,   // PNG图片支持
    };

    auto& pluginRegister = CORE_NS::GetPluginRegister();
    if (!pluginRegister.LoadPlugins(plugins)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to load plugins");
        return false;
    }

    // ========== Step 5: 创建ApplicationContext ==========
    // 这是Scene与RenderContext之间的桥梁
    auto& obr = META_NS::GetObjectRegistry();

    auto resources = obr.Create<CORE_NS::IResourceManager>(META_NS::ClassId::FileResourceManager);
    resources->SetFileManager(CORE_NS::IFileManager::Ptr(&fileManager));

    applicationContext_ = obr.Create<SCENE_NS::IApplicationContext>(SCENE_NS::ClassId::ApplicationContext);
    if (applicationContext_) {
        SCENE_NS::IApplicationContext::ApplicationContextInfo info{
            nullptr,  // engineThread
            nullptr,  // appThread
            renderContext_,
            resources,
            SCENE_NS::SceneOptions{}
        };
        applicationContext_->Initialize(info);
    }

    // ========== Step 6: 加载着色器 ==========
    constexpr RENDER_NS::IShaderManager::ShaderFilePathDesc shaderDesc{ "shaders://" };
    fileManager.RegisterPath("shaders", "OhosRawFile://shaders", false);
    renderContext_->GetDevice().GetShaderManager().LoadShaderFiles(shaderDesc);

    lumeInitialized_ = true;
    OH_LOG_Print(LOG_APP, LOG_INFO, 0, "LumeRenderer", "Lume initialized successfully");
    return true;
}
```

### 7.3 创建Swapchain并连接到Scene

```cpp
// 在OnSurfaceCreated中调用
void LumeRenderer::OnSurfaceCreated(void* window) {
    // 1. 初始化EGL
    if (!InitializeEGL(window)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "EGL init failed");
        return;
    }

    // 2. 初始化Lume
    if (!InitializeLume()) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Lume init failed");
        return;
    }

    // 3. 创建Swapchain（关联NativeWindow）
    CreateSwapchain(window);
}

void LumeRenderer::CreateSwapchain(void* window) {
    auto& device = renderContext_->GetDevice();

    // ★ 关键：使用XComponent提供的NativeWindow创建Swapchain
    RENDER_NS::SwapchainCreateInfo swapchainCreateInfo{
        0U,
        RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_COLOR_BUFFER_BIT |
        RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_DEPTH_BUFFER_BIT,
        RENDER_NS::ImageUsageFlagBits::CORE_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        {
            reinterpret_cast<uintptr_t>(window),  // NativeWindow
            {},  // instance (not needed for GLES)
        }
    };

    swapchainHandle_ = device.CreateSwapchainHandle(swapchainCreateInfo, {}, {});

    // 4. 创建RenderTarget (Bitmap)
    auto& obr = META_NS::GetObjectRegistry();
    auto doc = interface_pointer_cast<META_NS::IMetadata>(obr.GetDefaultObjectContext());

    renderTarget_ = obr.Create<SCENE_NS::IRenderTarget>(SCENE_NS::ClassId::Bitmap, doc);

    // ★ 关键：将Swapchain句柄设置给RenderTarget
    if (auto renderResource = interface_cast<SCENE_NS::IRenderResource>(renderTarget_)) {
        renderResource->SetRenderHandle(swapchainHandle_);
    }
}

void LumeRenderer::OnSurfaceChanged(int width, int height) {
    width_ = width;
    height_ = height;

    // 更新相机视口
    if (mainCamera_) {
        mainCamera_->SetRenderTargetSize({static_cast<uint32_t>(width), static_cast<uint32_t>(height)});
    }
}
```

### 7.4 创建和加载Scene

```cpp
// 方式1：创建空Scene
bool LumeRenderer::CreateScene() {
    if (!applicationContext_) {
        return false;
    }

    // 通过SceneManager创建Scene
    auto sceneManager = applicationContext_->GetSceneManager();
    if (!sceneManager) {
        return false;
    }

    scene_ = sceneManager->Create().get_result();
    if (!scene_) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to create scene");
        return false;
    }

    // 创建相机
    auto rootNode = scene_->GetRootNode().get_result();
    mainCamera_ = scene_->CreateNode<SCENE_NS::ICamera>("MainCamera").get_result();

    if (mainCamera_) {
        // 设置相机参数
        mainCamera_->SetFoV(60.0f);
        mainCamera_->SetNearPlane(0.1f);
        mainCamera_->SetFarPlane(100.0f);
        mainCamera_->SetActive(true);

        // ★ 关键：将RenderTarget绑定到Camera
        // 这建立了渲染链路：Camera → RenderTarget → Swapchain → NativeWindow
        mainCamera_->SetRenderTarget(renderTarget_);
    }

    return true;
}

// 方式2：从gltf加载Scene
bool LumeRenderer::LoadScene(const std::string& gltfPath) {
    if (!applicationContext_) {
        return false;
    }

    auto sceneManager = applicationContext_->GetSceneManager();
    if (!sceneManager) {
        return false;
    }

    // 加载gltf文件
    SCENE_NS::SceneDesc sceneDesc;
    sceneDesc.path = gltfPath;

    scene_ = sceneManager->Load(sceneDesc).get_result();
    if (!scene_) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0, "LumeRenderer", "Failed to load scene from %s", gltfPath.c_str());
        return false;
    }

    // 获取Scene中的相机
    auto cameras = scene_->GetCameras().get_result();
    if (!cameras.empty()) {
        mainCamera_ = cameras[0];
        mainCamera_->SetActive(true);

        // ★ 关键：将RenderTarget绑定到第一个相机
        mainCamera_->SetRenderTarget(renderTarget_);
    }

    return true;
}
```

### 7.5 渲染循环

```cpp
void LumeRenderer::DrawFrame() {
    if (!eglInitialized_ || !lumeInitialized_ || !scene_) {
        return;
    }

    // 绑定EGL Context
    if (!eglMakeCurrent(eglDisplay_, eglSurface_, eglSurface_, eglContext_)) {
        return;
    }

    // ========== Step 1: 更新Scene ==========
    // 更新场景中的变换、动画、物理等
    auto internalScene = scene_->GetInternalScene();
    if (internalScene) {
        internalScene->Update(false);  // false = 非同步更新
    }

    // ========== Step 2: 执行渲染 ==========
    // RenderContext会自动：
    // 1. 遍历所有活跃的Camera
    // 2. 每个Camera渲染到其RenderTarget
    // 3. 最终输出到Swapchain
    // 4. 内部调用eglSwapBuffers()
    auto& renderer = renderContext_->GetRenderer();
    RENDER_NS::RenderFrameData frameData{};

    // 如果有SurfaceBuffer同步
    // frameData.frameIndex = currentFrameIndex;

    renderer.RenderFrame(frameData);

    // ========== Step 3: 交换缓冲区 ==========
    // 注意：如果RenderContext没有自动交换，需要手动调用
    // eglSwapBuffers(eglDisplay_, eglSurface_);
}
```

### 7.6 完整的渲染链路总结

```
┌─────────────────────────────────────────────────────────────────┐
│                    Scene → Render 连接链路                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  XComponent (ArkTS)                                             │
│       │                                                         │
│       ▼ OnSurfaceCreated(window)                                │
│  ┌─────────────────┐                                            │
│  │  NativeWindow   │ ◄─── OH_NativeXComponent提供               │
│  └─────────────────┘                                            │
│       │                                                         │
│       ▼ CreateSwapchain(window)                                 │
│  ┌─────────────────┐                                            │
│  │   Swapchain     │ ◄─── RENDER_NS::SwapchainHandle            │
│  └─────────────────┘                                            │
│       │                                                         │
│       ▼ SetRenderHandle()                                       │
│  ┌─────────────────┐                                            │
│  │  RenderTarget   │ ◄─── SCENE_NS::IRenderTarget (Bitmap)      │
│  │    (Bitmap)     │                                            │
│  └─────────────────┘                                            │
│       │                                                         │
│       ▼ Camera::SetRenderTarget()                               │
│  ┌─────────────────┐                                            │
│  │     Camera      │ ◄─── SCENE_NS::ICamera                     │
│  └─────────────────┘                                            │
│       │                                                         │
│       ▼ 属于                                                     │
│  ┌─────────────────┐                                            │
│  │     Scene       │ ◄─── SCENE_NS::IScene                      │
│  └─────────────────┘                                            │
│       │                                                         │
│       ▼ Scene::Update() + RenderFrame()                         │
│  ┌─────────────────┐                                            │
│  │  RenderContext  │ ◄─── RENDER_NS::IRenderContext             │
│  └─────────────────┘                                            │
│       │                                                         │
│       ▼ 内部调用                                                 │
│  ┌─────────────────┐                                            │
│  │ eglSwapBuffers │ ◄─── 最终输出到屏幕                          │
│  └─────────────────┘                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 八、关键注意事项

### 8.1 EGL Context共享

Lume引擎需要共享EGL Context。在初始化时确保:

```cpp
// 创建共享Context
glesConfig.sharedContext = eglContext_;
```

### 8.2 插件加载

确保加载必要的插件:

```cpp
BASE_NS::vector<BASE_NS::Uid> plugins = {
    SCENE_NS::UID_SCENE_PLUGIN,
    JPGPlugin::UID_JPG_PLUGIN,
    PNGPlugin::UID_PNG_PLUGIN,
};
engine_->LoadPlugins(plugins);
```

### 8.3 资源路径

配置资源搜索路径:

```cpp
auto& fileManager = engine_->GetFileManager();
fileManager.AddPath("resources://");
```

### 8.4 线程安全

XComponent回调在UI线程执行，渲染应在专门的渲染线程:

```cpp
// 使用任务队列
auto taskQueue = engine_->GetTaskQueueRegistry()->GetTaskQueue();
taskQueue->Execute([]() { /* 渲染逻辑 */ });
```

## 九、文件结构

```
nativerender/
├── lume_xcomponent/
│   ├── CMakeLists.txt
│   ├── lume_xcomponent_manager.h
│   ├── lume_xcomponent_manager.cpp
│   ├── lume_renderer.h
│   ├── lume_renderer.cpp
│   └── napi_init.cpp
├── manager/          # 现有参考实现
│   ├── plugin_manager.h
│   └── plugin_manager.cpp
└── render/           # 现有EGL实现
    ├── egl_core.h
    ├── EGLRender.h
    └── ...
```

## 十、调试建议

1. **EGL初始化失败**: 检查EGL配置属性是否与设备兼容
2. **渲染黑屏**: 确认glViewport正确设置，检查着色器编译
3. **Context丢失**: 在`OnSurfaceDestroyed`中正确释放资源
4. **性能问题**: 使用帧率控制 `OH_ArkUI_XComponent_SetExpectedFrameRateRange`

## 十一、参考资料

- HarmonyOS XComponent开发指导: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ndk-xcomponent-V5
- OpenGL ES 3.0规范: https://www.khronos.org/opengles/
- EGL规范: https://www.khronos.org/registry/EGL/