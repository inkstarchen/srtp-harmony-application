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

#include <memory>
#include <mutex>
#include <string>

// Lume engine headers
#include <core/intf_engine.h>
#include <render/intf_render_context.h>
#include <render/device/intf_shader_manager.h>
#include <render/resource_handle.h>
#include <meta/interface/intf_task_queue.h>
#include <scene/interface/intf_application_context.h>
#include <scene/interface/intf_render_target.h>

namespace LumeXComponent {

class LumeSceneContext;

/**
 * @brief Lume renderer class that handles EGL and Lume engine initialization
 */
class LumeRenderer {
public:
    explicit LumeRenderer(const std::string& id);
    ~LumeRenderer();

    // Disable copy
    LumeRenderer(const LumeRenderer&) = delete;
    LumeRenderer& operator=(const LumeRenderer&) = delete;

    // ========== Lifecycle ==========
    /**
     * @brief Initialize renderer with native window
     * @param window Native window from XComponent
     * @param width Window width
     * @param height Window height
     * @return true if successful
     */
    bool Initialize(void* window, uint32_t width, uint32_t height);

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
     * @brief Render a frame
     */
    void RenderFrame();

    /**
     * @brief Request a render (for next frame)
     */
    void RequestRender();

    // ========== Scene Management ==========
    /**
     * @brief Create an empty scene
     * @return true if successful
     */
    bool CreateScene();

    /**
     * @brief Load scene from GLTF file
     * @param gltfPath Path to GLTF file
     * @return true if successful
     */
    bool LoadScene(const std::string& gltfPath);

    /**
     * @brief Set scene context
     */
    void SetSceneContext(std::shared_ptr<LumeSceneContext> context);

    /**
     * @brief Get scene context
     */
    LumeSceneContext* GetSceneContext() const { return sceneContext_.get(); }

    // ========== State Query ==========
    RenderState GetState() const { return state_; }
    uint32_t GetWidth() const { return windowInfo_.width; }
    uint32_t GetHeight() const { return windowInfo_.height; }
    const std::string& GetId() const { return id_; }

    // ========== Callbacks ==========
    void SetRenderCallback(RenderCallback callback) { renderCallback_ = std::move(callback); }
    void SetTouchCallback(TouchCallback callback) { touchCallback_ = std::move(callback); }

    // ========== Configuration ==========
    void SetRenderConfig(const RenderConfig& config) { renderConfig_ = config; }

    // ========== Accessors ==========
    CORE_NS::IEngine* GetEngine() const { return engine_.get(); }
    RENDER_NS::IRenderContext* GetRenderContext() const { return renderContext_.get(); }
    SCENE_NS::IApplicationContext* GetApplicationContext() const { return applicationContext_.get(); }

private:
    // ========== EGL Management ==========
    bool InitializeEGL(void* window);
    void DestroyEGL();
    bool MakeCurrent();
    void SwapBuffers();

    // ========== Lume Engine Management ==========
    bool InitializeLumeEngine();
    void DeinitializeLumeEngine();
    bool LoadPlugins();
    bool CreateSwapchain(void* window);
    void DestroySwapchain();
    bool CreateRenderTarget();
    void DestroyRenderTarget();

    // ========== Helper Methods ==========
    void UpdateViewport();
    void SetState(RenderState state) { state_ = state; }

private:
    std::string id_;
    RenderState state_ = RenderState::UNINITIALIZED;
    WindowInfo windowInfo_;
    RenderConfig renderConfig_;

    // EGL related
    EGLDisplay eglDisplay_ = EGL_NO_DISPLAY;
    EGLSurface eglSurface_ = EGL_NO_SURFACE;
    EGLContext eglContext_ = EGL_NO_CONTEXT;
    EGLConfig eglConfig_ = nullptr;
    EGLNativeWindowType eglWindow_ = nullptr;
    bool eglInitialized_ = false;

    // Lume engine related
    CORE_NS::IEngine::Ptr engine_;
    BASE_NS::shared_ptr<RENDER_NS::IRenderContext> renderContext_;
    SCENE_NS::IApplicationContext::Ptr applicationContext_;
    META_NS::ITaskQueue::Ptr engineThread_;
    META_NS::ITaskQueue::Ptr appThread_;

    // Swapchain and RenderTarget
    RENDER_NS::RenderHandleReference swapchainHandle_;
    SCENE_NS::IRenderTarget::Ptr renderTarget_;

    // Scene context
    std::shared_ptr<LumeSceneContext> sceneContext_;

    // Callbacks
    RenderCallback renderCallback_;
    TouchCallback touchCallback_;

    // Thread safety
    std::mutex renderMutex_;

    // Frame count
    uint64_t frameCount_ = 0;
    bool lumeInitialized_ = false;
};

} // namespace LumeXComponent

#endif // LUME_RENDERER_H