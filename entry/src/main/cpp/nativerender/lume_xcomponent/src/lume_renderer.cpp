/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "lume_renderer.h"
#include "lume_scene_context.h"

#include <hilog/log.h>

// Lume engine headers
#include <core/intf_engine.h>
#include <core/engine_info.h>
#include <core/implementation_uids.h>
#include <core/io/intf_file_manager.h>
#include <core/os/intf_platform.h>
#include <core/plugin/intf_plugin_register.h>

#include <meta/interface/intf_meta_object_lib.h>
#include <meta/interface/intf_task_queue_registry.h>
#include <meta/interface/intf_task_queue.h>
#include <meta/interface/intf_object_registry.h>
#include <meta/api/make_callback.h>
#include <meta/ext/object.h>

#include <scene/interface/intf_scene.h>
#include <scene/interface/intf_camera.h>
#include <scene/ext/intf_render_resource.h>
#include <scene/interface/intf_application_context.h>

#include <render/implementation_uids.h>
#include <render/gles/intf_device_gles.h>
#include <render/intf_renderer.h>
#include <render/intf_render_context.h>

#include <jpg/implementation_uids.h>
#include <png/implementation_uids.h>

#define LOG_TAG "LumeRenderer"
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, 0, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0, LOG_TAG, __VA_ARGS__)
#define LOGD(...) OH_LOG_Print(LOG_APP, LOG_DEBUG, 0, LOG_TAG, __VA_ARGS__)

namespace LumeXComponent {

// EGL configuration
namespace {
    constexpr EGLint EGL_ATTRIBS[] = {
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

    constexpr EGLint EGL_CONTEXT_ATTRIBS[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };

    constexpr BASE_NS::Uid ENGINE_THREAD { "2070e705-d061-40e4-bfb7-90fad2c280af" };
    constexpr BASE_NS::Uid APP_THREAD { "b2e8cef3-453a-4651-b564-5190f8b5190d" };
}

LumeRenderer::LumeRenderer(const std::string& id)
    : id_(id)
{
    LOGI("LumeRenderer created: %{public}s", id_.c_str());
}

LumeRenderer::~LumeRenderer()
{
    LOGI("LumeRenderer destroyed: %{public}s", id_.c_str());
    OnSurfaceDestroyed();
}

bool LumeRenderer::Initialize(void* window, uint32_t width, uint32_t height)
{
    LOGI("Initialize: %{public}s, window=%{public}p, size=%{public}ux%{public}u",
         id_.c_str(), window, width, height);

    std::lock_guard<std::mutex> lock(renderMutex_);

    if (state_ != RenderState::UNINITIALIZED) {
        LOGE("Renderer already initialized");
        return false;
    }

    SetState(RenderState::INITIALIZING);
    windowInfo_.nativeWindow = window;
    windowInfo_.width = width;
    windowInfo_.height = height;

    // Step 1: Initialize EGL
    if (!InitializeEGL(window)) {
        LOGE("Failed to initialize EGL");
        SetState(RenderState::ERROR);
        return false;
    }

    // Step 2: Initialize Lume Engine
    if (!InitializeLumeEngine()) {
        LOGE("Failed to initialize Lume engine");
        DestroyEGL();
        SetState(RenderState::ERROR);
        return false;
    }

    // Step 3: Create Swapchain
    if (!CreateSwapchain(window)) {
        LOGE("Failed to create swapchain");
        DeinitializeLumeEngine();
        DestroyEGL();
        SetState(RenderState::ERROR);
        return false;
    }

    // Step 4: Create RenderTarget
    if (!CreateRenderTarget()) {
        LOGE("Failed to create render target");
        DestroySwapchain();
        DeinitializeLumeEngine();
        DestroyEGL();
        SetState(RenderState::ERROR);
        return false;
    }

    SetState(RenderState::READY);
    LOGI("LumeRenderer initialized successfully: %{public}s", id_.c_str());
    return true;
}

void LumeRenderer::OnSurfaceChanged(void* window, uint32_t width, uint32_t height)
{
    LOGI("OnSurfaceChanged: %{public}s, size=%{public}ux%{public}u", id_.c_str(), width, height);

    std::lock_guard<std::mutex> lock(renderMutex_);

    if (state_ == RenderState::UNINITIALIZED || state_ == RenderState::DESTROYED) {
        return;
    }

    windowInfo_.nativeWindow = window;
    windowInfo_.width = width;
    windowInfo_.height = height;

    // Recreate swapchain with new window
    DestroySwapchain();
    DestroyRenderTarget();

    if (CreateSwapchain(window) && CreateRenderTarget()) {
        UpdateViewport();

        // Update camera render target size
        if (sceneContext_ && sceneContext_->GetActiveCamera()) {
            sceneContext_->GetActiveCamera()->RenderTargetSize()->SetValue(
                {width, height});
        }
    }
}

void LumeRenderer::OnSurfaceDestroyed()
{
    LOGI("OnSurfaceDestroyed: %{public}s", id_.c_str());

    std::lock_guard<std::mutex> lock(renderMutex_);

    if (state_ == RenderState::DESTROYED || state_ == RenderState::UNINITIALIZED) {
        return;
    }

    SetState(RenderState::DESTROYED);

    DestroyRenderTarget();
    DestroySwapchain();
    DeinitializeLumeEngine();
    DestroyEGL();

    sceneContext_.reset();
}

void LumeRenderer::RenderFrame()
{
    std::lock_guard<std::mutex> lock(renderMutex_);

    if (state_ != RenderState::READY && state_ != RenderState::RENDERING) {
        return;
    }

    SetState(RenderState::RENDERING);

    if (!MakeCurrent()) {
        LOGE("Failed to make EGL context current");
        SetState(RenderState::ERROR);
        return;
    }

    // Update viewport
    UpdateViewport();

    // Update scene
    if (sceneContext_) {
        sceneContext_->Update();

        // Bind render target to active camera
        auto camera = sceneContext_->GetActiveCamera();
        if (camera && renderTarget_) {
            camera->SetRenderTarget(renderTarget_);
        }
    }

    // Render
    if (renderContext_) {
        renderContext_->GetRenderer().RenderFrame({});
    }

    // Swap buffers
    SwapBuffers();

    frameCount_++;
    SetState(RenderState::READY);

    // Call render callback
    if (renderCallback_) {
        renderCallback_();
    }
}

void LumeRenderer::RequestRender()
{
    // This could trigger a render request on the engine thread
    // For now, just call RenderFrame directly
    RenderFrame();
}

bool LumeRenderer::CreateScene()
{
    LOGI("CreateScene: %{public}s", id_.c_str());

    if (!applicationContext_) {
        LOGE("Application context not initialized");
        return false;
    }

    sceneContext_ = std::make_shared<LumeSceneContext>();
    if (!sceneContext_->CreateEmptyScene()) {
        LOGE("Failed to create empty scene");
        return false;
    }

    // Create default camera
    if (!sceneContext_->CreateCamera("MainCamera")) {
        LOGE("Failed to create camera");
        return false;
    }

    return true;
}

bool LumeRenderer::LoadScene(const std::string& gltfPath)
{
    LOGI("LoadScene: %{public}s, path=%{public}s", id_.c_str(), gltfPath.c_str());

    if (!applicationContext_) {
        LOGE("Application context not initialized");
        return false;
    }

    sceneContext_ = std::make_shared<LumeSceneContext>();
    if (!sceneContext_->LoadFromGLTF(gltfPath)) {
        LOGE("Failed to load scene from: %{public}s", gltfPath.c_str());
        return false;
    }

    return true;
}

void LumeRenderer::SetSceneContext(std::shared_ptr<LumeSceneContext> context)
{
    sceneContext_ = context;
}

// ==================== EGL Management ====================

bool LumeRenderer::InitializeEGL(void* window)
{
    LOGI("InitializeEGL: window=%{public}p", window);

    eglWindow_ = reinterpret_cast<EGLNativeWindowType>(window);

    // 1. Get EGL Display
    eglDisplay_ = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (eglDisplay_ == EGL_NO_DISPLAY) {
        LOGE("eglGetDisplay failed");
        return false;
    }

    // 2. Initialize EGL
    EGLint major, minor;
    if (!eglInitialize(eglDisplay_, &major, &minor)) {
        LOGE("eglInitialize failed");
        eglDisplay_ = EGL_NO_DISPLAY;
        return false;
    }

    LOGI("EGL version: %{public}d.%{public}d", major, minor);

    // 3. Choose config
    EGLint numConfigs;
    if (!eglChooseConfig(eglDisplay_, EGL_ATTRIBS, &eglConfig_, 1, &numConfigs)) {
        LOGE("eglChooseConfig failed");
        eglTerminate(eglDisplay_);
        eglDisplay_ = EGL_NO_DISPLAY;
        return false;
    }

    // 4. Create window surface
    eglSurface_ = eglCreateWindowSurface(eglDisplay_, eglConfig_, eglWindow_, nullptr);
    if (eglSurface_ == EGL_NO_SURFACE) {
        LOGE("eglCreateWindowSurface failed: %{public}d", eglGetError());
        eglTerminate(eglDisplay_);
        eglDisplay_ = EGL_NO_DISPLAY;
        return false;
    }

    // 5. Create context
    eglContext_ = eglCreateContext(eglDisplay_, eglConfig_, EGL_NO_CONTEXT, EGL_CONTEXT_ATTRIBS);
    if (eglContext_ == EGL_NO_CONTEXT) {
        LOGE("eglCreateContext failed: %{public}d", eglGetError());
        eglDestroySurface(eglDisplay_, eglSurface_);
        eglTerminate(eglDisplay_);
        eglSurface_ = EGL_NO_SURFACE;
        eglDisplay_ = EGL_NO_DISPLAY;
        return false;
    }

    // 6. Make current
    if (!eglMakeCurrent(eglDisplay_, eglSurface_, eglSurface_, eglContext_)) {
        LOGE("eglMakeCurrent failed: %{public}d", eglGetError());
        eglDestroyContext(eglDisplay_, eglContext_);
        eglDestroySurface(eglDisplay_, eglSurface_);
        eglTerminate(eglDisplay_);
        eglContext_ = EGL_NO_CONTEXT;
        eglSurface_ = EGL_NO_SURFACE;
        eglDisplay_ = EGL_NO_DISPLAY;
        return false;
    }

    eglInitialized_ = true;
    LOGI("EGL initialized successfully");
    return true;
}

void LumeRenderer::DestroyEGL()
{
    if (!eglInitialized_) {
        return;
    }

    LOGI("DestroyEGL");

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

bool LumeRenderer::MakeCurrent()
{
    if (!eglInitialized_) {
        return false;
    }

    return eglMakeCurrent(eglDisplay_, eglSurface_, eglSurface_, eglContext_);
}

void LumeRenderer::SwapBuffers()
{
    if (eglInitialized_ && eglSurface_ != EGL_NO_SURFACE) {
        eglSwapBuffers(eglDisplay_, eglSurface_);
    }
}

// ==================== Lume Engine Management ====================

bool LumeRenderer::InitializeLumeEngine()
{
    LOGI("InitializeLumeEngine");

    auto& tr = META_NS::GetTaskQueueRegistry();
    auto& obr = META_NS::GetObjectRegistry();

    // Create task queues
    engineThread_ = tr.GetTaskQueue(ENGINE_THREAD);
    if (!engineThread_) {
        engineThread_ = obr.Create<META_NS::ITaskQueue>(META_NS::ClassId::ThreadedTaskQueue);
        tr.RegisterTaskQueue(engineThread_, ENGINE_THREAD);
    }

    appThread_ = tr.GetTaskQueue(APP_THREAD);
    if (!appThread_) {
        appThread_ = obr.Create<META_NS::ITaskQueue>(META_NS::ClassId::ThreadedTaskQueue);
        tr.RegisterTaskQueue(appThread_, APP_THREAD);
    }

    // Create engine
    CORE_NS::PlatformCreateInfo platformCreateInfo {
        "",   // coreRootPath
        "",   // corePluginPath
        "",   // appRootPath
        "",   // appPluginPath
        "",   // hapPath
        "",   // bundleName
        "",   // moduleName
        nullptr  // resourceManager
    };

    CORE_NS::EngineCreateInfo engineCreateInfo {platformCreateInfo, {}, {}};

    auto factory = CORE_NS::GetInstance<CORE_NS::IEngineFactory>(CORE_NS::UID_ENGINE_FACTORY);
    if (!factory) {
        LOGE("Failed to get engine factory");
        return false;
    }

    engine_.reset(factory->Create(engineCreateInfo).get());
    if (!engine_) {
        LOGE("Failed to create engine");
        return false;
    }

    // Initialize engine
    auto& fileManager = engine_->GetFileManager();
    auto& platform = engine_->GetPlatform();
    platform.RegisterDefaultPaths(fileManager);
    engine_->Init();

    // Create RenderContext
    RENDER_NS::RenderCreateInfo renderCreateInfo {};
    RENDER_NS::BackendExtraGLES glExtra {};
    Render::DeviceCreateInfo deviceCreateInfo {};

    glExtra.depthBits = renderConfig_.depthBits;
    glExtra.sharedContext = eglContext_;  // Share EGL context with XComponent

    deviceCreateInfo.backendType = RENDER_NS::DeviceBackendType::OPENGLES;
    deviceCreateInfo.backendConfiguration = &glExtra;
    renderCreateInfo.deviceCreateInfo = deviceCreateInfo;

    renderContext_.reset(
        static_cast<RENDER_NS::IRenderContext*>(
            engine_->GetInterface<CORE_NS::IClassFactory>()
                ->CreateInstance(RENDER_NS::UID_RENDER_CONTEXT)
                .release()));

    auto result = renderContext_->Init(renderCreateInfo);
    if (result != RENDER_NS::RenderResultCode::RENDER_SUCCESS) {
        LOGE("Failed to initialize render context");
        return false;
    }

    // Load plugins
    BASE_NS::vector<BASE_NS::Uid> plugins = {
        SCENE_NS::UID_SCENE_PLUGIN,
        JPGPlugin::UID_JPG_PLUGIN,
        PNGPlugin::UID_PNG_PLUGIN,
    };

    if (!CORE_NS::GetPluginRegister().LoadPlugins(plugins)) {
        LOGE("Failed to load plugins");
        return false;
    }

    // Create ApplicationContext
    auto resources = obr.Create<CORE_NS::IResourceManager>(META_NS::ClassId::FileResourceManager);
    resources->SetFileManager(CORE_NS::IFileManager::Ptr(&fileManager));

    applicationContext_ = obr.Create<SCENE_NS::IApplicationContext>(SCENE_NS::ClassId::ApplicationContext);
    if (applicationContext_) {
        SCENE_NS::IApplicationContext::ApplicationContextInfo info {
            engineThread_,
            appThread_,
            renderContext_,
            resources,
            SCENE_NS::SceneOptions {}
        };
        applicationContext_->Initialize(info);
    }

    // Register shader paths
    engine_->GetFileManager().RegisterPath("shaders", "OhosRawFile://shaders", false);
    renderContext_->GetDevice().GetShaderManager().LoadShaderFiles({ "shaders://" });

    lumeInitialized_ = true;
    LOGI("Lume engine initialized successfully");
    return true;
}

void LumeRenderer::DeinitializeLumeEngine()
{
    if (!lumeInitialized_) {
        return;
    }

    LOGI("DeinitializeLumeEngine");

    applicationContext_.reset();
    renderContext_.reset();
    engine_.reset();

    lumeInitialized_ = false;
}

bool LumeRenderer::LoadPlugins()
{
    // Plugins are loaded in InitializeLumeEngine
    return true;
}

bool LumeRenderer::CreateSwapchain(void* window)
{
    LOGI("CreateSwapchain: window=%{public}p", window);

    if (!renderContext_) {
        LOGE("Render context not initialized");
        return false;
    }

    auto& device = renderContext_->GetDevice();

    RENDER_NS::SwapchainCreateInfo swapchainCreateInfo {
        0U,
        RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_COLOR_BUFFER_BIT |
        RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_DEPTH_BUFFER_BIT,
        RENDER_NS::ImageUsageFlagBits::CORE_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        {
            reinterpret_cast<uintptr_t>(window),
            {},
        }
    };

    swapchainHandle_ = device.CreateSwapchainHandle(swapchainCreateInfo, {}, {});

    if (!swapchainHandle_) {
        LOGE("Failed to create swapchain handle");
        return false;
    }

    LOGI("Swapchain created successfully");
    return true;
}

void LumeRenderer::DestroySwapchain()
{
    if (swapchainHandle_ && renderContext_) {
        renderContext_->GetDevice().DestroySwapchain(swapchainHandle_);
        swapchainHandle_ = {};
    }
}

bool LumeRenderer::CreateRenderTarget()
{
    LOGI("CreateRenderTarget");

    if (!swapchainHandle_) {
        LOGE("Swapchain not created");
        return false;
    }

    auto& obr = META_NS::GetObjectRegistry();
    auto doc = interface_pointer_cast<META_NS::IMetadata>(obr.GetDefaultObjectContext());

    renderTarget_ = obr.Create<SCENE_NS::IRenderTarget>(SCENE_NS::ClassId::Bitmap, doc);

    if (!renderTarget_) {
        LOGE("Failed to create render target");
        return false;
    }

    // Set swapchain handle to render target
    if (auto renderResource = interface_cast<SCENE_NS::IRenderResource>(renderTarget_)) {
        renderResource->SetRenderHandle(swapchainHandle_);
    }

    LOGI("Render target created successfully");
    return true;
}

void LumeRenderer::DestroyRenderTarget()
{
    renderTarget_.reset();
}

void LumeRenderer::UpdateViewport()
{
    if (windowInfo_.width > 0 && windowInfo_.height > 0) {
        glViewport(0, 0, windowInfo_.width, windowInfo_.height);
    }
}

} // namespace LumeXComponent