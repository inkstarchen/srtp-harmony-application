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

#include <hilog/log.h>

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

bool LumeRenderer::Initialize(void* window, uint32_t width, uint32_t height,NativeResourceManager* resourceManager)
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

    // Step 1: Initialize EGL (context only - Lume swapchain will create surface)
    if (!InitializeEGL(window)) {
        LOGE("Failed to initialize EGL");
        SetState(RenderState::ERROR);
        return false;
    }

    // Step 2: Initialize Lume Engine (delegates to LumeCommon::InitEngine)
    if (!InitializeLumeEngine(resourceManager)) {
        LOGE("Failed to initialize Lume engine");
        DestroyEGL();
        SetState(RenderState::ERROR);
        return false;
    }

    // Step 3: Notify LumeCommon about window (creates swapchain and render target)
    OHOS::Render3D::TextureInfo textureInfo {};
    textureInfo.width_ = width;
    textureInfo.height_ = height;
    textureInfo.textureId_ = 0U;  // XComponent mode
    textureInfo.nativeWindow_ = window;
    textureInfo.widthScale_ = 1.0f;
    textureInfo.heightScale_ = 1.0f;
    textureInfo.recreateWindow_ = true;

    engine_->OnWindowChange(textureInfo);

    initialized_ = true;
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

    // Notify LumeCommon about window change
    OHOS::Render3D::TextureInfo textureInfo {};
    textureInfo.width_ = width;
    textureInfo.height_ = height;
    textureInfo.textureId_ = 0U;
    textureInfo.nativeWindow_ = window;
    textureInfo.widthScale_ = 1.0f;
    textureInfo.heightScale_ = 1.0f;
    textureInfo.recreateWindow_ = true;

    engine_->OnWindowChange(textureInfo);
}

void LumeRenderer::OnSurfaceDestroyed()
{
    LOGI("OnSurfaceDestroyed: %{public}s", id_.c_str());

    std::lock_guard<std::mutex> lock(renderMutex_);

    if (state_ == RenderState::DESTROYED || state_ == RenderState::UNINITIALIZED) {
        return;
    }

    SetState(RenderState::DESTROYED);

    if (engine_) {
        engine_->DeInitEngine();
        engine_.reset();
    }

    DestroyEGL();
    initialized_ = false;
}

void LumeRenderer::RenderFrame()
{
    std::lock_guard<std::mutex> lock(renderMutex_);

    if (state_ != RenderState::READY && state_ != RenderState::RENDERING) {
        return;
    }

    SetState(RenderState::RENDERING);

    // Delegate rendering to LumeCommon
    if (engine_) {
        engine_->DrawFrame();
    }

    frameCount_++;
    SetState(RenderState::READY);

    // Call render callback
    if (renderCallback_) {
        renderCallback_();
    }
}

void LumeRenderer::RequestRender()
{
    RenderFrame();
}

bool LumeRenderer::InitializeScene(uint32_t key)
{
    LOGI("InitializeScene: %{public}s, key=%{public}u", id_.c_str(), key);

    if (!engine_) {
        LOGE("Engine not initialized");
        return false;
    }

    engine_->InitializeScene(key);
    return true;
}

bool LumeRenderer::LoadScene(const std::string& gltfPath)
{
    LOGI("LoadScene: %{public}s, path=%{public}s", id_.c_str(), gltfPath.c_str());

    if (!engine_) {
        LOGE("Engine not initialized");
        return false;
    }
    InitializeScene(1);
    engine_->LoadSceneModel(gltfPath);

    if (windowInfo_.nativeWindow) {
        OHOS::Render3D::TextureInfo textureInfo {};
        textureInfo.width_ = windowInfo_.width;
        textureInfo.height_ = windowInfo_.height;
        textureInfo.textureId_ = 0U;
        textureInfo.nativeWindow_ = windowInfo_.nativeWindow;
        textureInfo.widthScale_ = 1.0f;
        textureInfo.heightScale_ = 1.0f;
        textureInfo.recreateWindow_ = true;
        engine_->OnWindowChange(textureInfo);
    }
    return true;
}

bool LumeRenderer::LoadEnvModel(const std::string& gltfPath, OHOS::Render3D::BackgroundType type)
{
    LOGI("LoadEnvModel: %{public}s, path=%{public}s", id_.c_str(), gltfPath.c_str());

    if (!engine_) {
        LOGE("Engine not initialized");
        return false;
    }

    engine_->LoadEnvModel(gltfPath, type);
    return true;
}

void LumeRenderer::SetupCameraViewPort(uint32_t width, uint32_t height)
{
    if (engine_) {
        engine_->SetupCameraViewPort(width, height);
    }
}

void LumeRenderer::SetupCameraTransform(const OHOS::Render3D::Position& position,
                                         const OHOS::Render3D::Vec3& lookAt,
                                         const OHOS::Render3D::Vec3& up,
                                         const OHOS::Render3D::Quaternion& rotation)
{
    if (engine_) {
        engine_->SetupCameraTransform(position, lookAt, up, rotation);
    }
}

void LumeRenderer::SetupCameraViewProjection(float zNear, float zFar, float fovDegrees)
{
    if (engine_) {
        engine_->SetupCameraViewProjection(zNear, zFar, fovDegrees);
    }
}

void LumeRenderer::OnTouchEvent(const OHOS::Render3D::PointerEvent& event)
{
    if (engine_) {
        engine_->OnTouchEvent(event);
    }
}

bool LumeRenderer::NeedsRepaint() const
{
    if (engine_) {
        return engine_->NeedsRepaint();
    }
    return false;
}

// ==================== EGL Management ====================

bool LumeRenderer::InitializeEGL(void* window)
{
    LOGI("InitializeEGL: window=%{public}p (Lume swapchain mode - no surface)", window);

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

    // 4. Create context ONLY (no surface - Lume swapchain will manage window/surface)
    // NOTE: In Lume swapchain mode, we don't create EGL surface here.
    // Lume's Device::CreateSwapchain will create its own surface/swapchain using nativeWindow.
    eglContext_ = eglCreateContext(eglDisplay_, eglConfig_, EGL_NO_CONTEXT, EGL_CONTEXT_ATTRIBS);
    if (eglContext_ == EGL_NO_CONTEXT) {
        LOGE("eglCreateContext failed: %{public}d", eglGetError());
        eglTerminate(eglDisplay_);
        eglDisplay_ = EGL_NO_DISPLAY;
        return false;
    }

    // 5. Make context current without surface (surface will be created by Lume swapchain)
    if (!eglMakeCurrent(eglDisplay_, EGL_NO_SURFACE, EGL_NO_SURFACE, eglContext_)) {
        LOGE("eglMakeCurrent (no surface) failed: %{public}d", eglGetError());
        eglDestroyContext(eglDisplay_, eglContext_);
        eglTerminate(eglDisplay_);
        eglContext_ = EGL_NO_CONTEXT;
        eglDisplay_ = EGL_NO_DISPLAY;
        return false;
    }

    eglInitialized_ = true;
    LOGI("EGL initialized successfully (context only, eglContext_=%{public}p)", eglContext_);
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

// ==================== Lume Engine Management ====================

bool LumeRenderer::InitializeLumeEngine(NativeResourceManager* resourceManager)
{
    LOGI("InitializeLumeEngine");

    // Create Lume engine instance (inherits from LumeCommon)
    engine_ = std::make_unique<OHOS::Render3D::Lume>();
    if (!engine_) {
        LOGE("Failed to create Lume engine instance");
        return false;
    }

    // Note: LoadEngineLib() is not needed in static linking mode.
    // CORE_DYNAMIC is not defined, so GetPluginRegister is a real function
    // that will be linked from libPluginSceneWidget.so at compile time.

    // Prepare platform data
    OHOS::Render3D::PlatformData platformData {};
    platformData.coreRootPath_ = "";
    platformData.corePluginPath_ = "";
    platformData.appRootPath_ = "";
    platformData.appPluginPath_ = "";
    platformData.hapInfo_.hapPath_ = "";
    platformData.hapInfo_.bundleName_ = "";
    platformData.hapInfo_.moduleName_ = "";
    platformData.hapInfo_.resourceManager_ = resourceManager;
    if(platformData.hapInfo_.resourceManager_ == nullptr){
        LOGE("Failed to initialize Lume engine via InitEngine");
    }

    // Initialize engine using LumeCommon's InitEngine method
    // This handles: CreateCoreEngine, CreateRenderContext, CreateGfx3DContext
    if (!engine_->InitEngine(eglContext_, platformData)) {
        LOGE("Failed to initialize Lume engine via InitEngine");
        return false;
    }

    LOGI("Lume engine initialized successfully");
    return true;
}

} // namespace LumeXComponent