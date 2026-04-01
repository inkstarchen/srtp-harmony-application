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

#ifndef LUME_RENDERER_H
#define LUME_RENDERER_H

#include "lume_xcomponent_types.h"

#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <rawfile/raw_file_manager.h>
#include <memory>
#include <mutex>
#include <string>

// Lume adapter headers
#include "3d_widget_adapter/core/include/lume/ohos/lume.h"
#include "3d_widget_adapter/include/i_engine.h"
#include "3d_widget_adapter/include/ohos/platform_data.h"
#include "3d_widget_adapter/include/texture_info.h"

namespace LumeXComponent {

/**
 * @brief LumeRenderer is a pure adapter that bridges XComponent lifecycle
 *        events to LumeCommon (the actual rendering engine).
 *
 * Responsibilities:
 * - EGL context management (provides shared context to LumeCommon)
 * - XComponent lifecycle adaptation (Initialize, OnSurfaceChanged, OnSurfaceDestroyed)
 * - State management and thread safety
 * - Callback management
 *
 * All rendering logic is delegated to LumeCommon via IEngine interface.
 */
class LumeRenderer {
public:
    explicit LumeRenderer(const std::string& id);
    ~LumeRenderer();

    // Disable copy
    LumeRenderer(const LumeRenderer&) = delete;
    LumeRenderer& operator=(const LumeRenderer&) = delete;

    // ========== Lifecycle (XComponent Adapter) ==========
    /**
     * @brief Initialize renderer with native window
     * @param window Native window from XComponent
     * @param width Window width
     * @param height Window height
     * @return true if successful
     */
    bool Initialize(void* window, uint32_t width, uint32_t height, NativeResourceManager* resourceManager);

    /**
     * @brief Handle surface changed event
     */
    void OnSurfaceChanged(void* window, uint32_t width, uint32_t height);

    /**
     * @brief Handle surface destroyed event
     */
    void OnSurfaceDestroyed();

    // ========== Rendering ==========
    /**
     * @brief Render a frame (delegates to LumeCommon::DrawFrame)
     */
    void RenderFrame();

    /**
     * @brief Request a render (for next frame)
     */
    void RequestRender();

    // ========== Scene Management (delegates to LumeCommon) ==========
    /**
     * @brief Initialize scene with a unique key
     */
    bool InitializeScene(uint32_t key);

    /**
     * @brief Load scene from GLTF file
     */
    bool LoadScene(const std::string& gltfPath);

    /**
     * @brief Load environment model
     */
    bool LoadEnvModel(const std::string& gltfPath, OHOS::Render3D::BackgroundType type);

    // ========== Camera Setup (delegates to LumeCommon) ==========
    void SetupCameraViewPort(uint32_t width, uint32_t height);
    void SetupCameraTransform(const OHOS::Render3D::Position& position,
                              const OHOS::Render3D::Vec3& lookAt,
                              const OHOS::Render3D::Vec3& up,
                              const OHOS::Render3D::Quaternion& rotation);
    void SetupCameraViewProjection(float zNear, float zFar, float fovDegrees);

    // ========== Touch Events (delegates to LumeCommon) ==========
    void OnTouchEvent(const OHOS::Render3D::PointerEvent& event);

    // ========== State Query ==========
    RenderState GetState() const { return state_; }
    uint32_t GetWidth() const { return windowInfo_.width; }
    uint32_t GetHeight() const { return windowInfo_.height; }
    const std::string& GetId() const { return id_; }
    bool NeedsRepaint() const;

    // ========== Callbacks ==========
    void SetRenderCallback(RenderCallback callback) { renderCallback_ = std::move(callback); }
    void SetTouchCallback(TouchCallback callback) { touchCallback_ = std::move(callback); }

    // ========== Configuration ==========
    void SetRenderConfig(const RenderConfig& config) { renderConfig_ = config; }

    // ========== Accessors ==========
    OHOS::Render3D::IEngine* GetLumeEngine() const { return engine_.get(); }

private:
    // ========== EGL Management ==========
    bool InitializeEGL(void* window);
    void DestroyEGL();

    // ========== Lume Engine Management ==========
    bool InitializeLumeEngine(NativeResourceManager* resourceManager);

    // ========== Helper Methods ==========
    void SetState(RenderState state) { state_ = state; }

private:
    std::string id_;
    RenderState state_ = RenderState::UNINITIALIZED;
    WindowInfo windowInfo_;
    RenderConfig renderConfig_;

    // EGL related (provides shared context to LumeCommon)
    EGLDisplay eglDisplay_ = EGL_NO_DISPLAY;
    EGLSurface eglSurface_ = EGL_NO_SURFACE;
    EGLContext eglContext_ = EGL_NO_CONTEXT;
    EGLConfig eglConfig_ = nullptr;
    EGLNativeWindowType eglWindow_ = nullptr;
    bool eglInitialized_ = false;

    // Lume engine (all rendering logic is delegated to LumeCommon)
    std::unique_ptr<OHOS::Render3D::Lume> engine_;

    // Callbacks
    RenderCallback renderCallback_;
    TouchCallback touchCallback_;

    // Thread safety
    std::mutex renderMutex_;

    // Frame count
    uint64_t frameCount_ = 0;
    bool initialized_ = false;
};

} // namespace LumeXComponent

#endif // LUME_RENDERER_H