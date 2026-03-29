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

#ifndef LUME_SCENE_CONTEXT_H
#define LUME_SCENE_CONTEXT_H

#include "lume_xcomponent_types.h"

#include <memory>
#include <string>
#include <vector>

// Lume engine headers
#include <scene/interface/intf_scene.h>
#include <scene/interface/intf_camera.h>
#include <scene/interface/intf_render_target.h>
#include <scene/interface/intf_application_context.h>
#include <base/containers/string.h>
#include <base/containers/unordered_map.h>

namespace LumeXComponent {

/**
 * @brief Scene context that manages scene, camera, and render target binding
 */
class LumeSceneContext {
public:
    LumeSceneContext();
    ~LumeSceneContext();

    // Disable copy
    LumeSceneContext(const LumeSceneContext&) = delete;
    LumeSceneContext& operator=(const LumeSceneContext&) = delete;

    // ========== Scene Creation/Loading ==========
    /**
     * @brief Create an empty scene
     * @return true if successful
     */
    bool CreateEmptyScene();

    /**
     * @brief Load scene from GLTF file
     * @param path Path to GLTF file
     * @return true if successful
     */
    bool LoadFromGLTF(const std::string& path);

    // ========== Camera Management ==========
    /**
     * @brief Create a camera with given name
     * @param name Camera name
     * @return true if successful
     */
    bool CreateCamera(const std::string& name);

    /**
     * @brief Set active camera by name
     * @param name Camera name
     */
    void SetActiveCamera(const std::string& name);

    /**
     * @brief Set camera field of view
     * @param fov Field of view in degrees
     */
    void SetCameraFoV(float fov);

    /**
     * @brief Set camera near plane
     * @param near Near plane distance
     */
    void SetCameraNearPlane(float near);

    /**
     * @brief Set camera far plane
     * @param far Far plane distance
     */
    void SetCameraFarPlane(float far);

    /**
     * @brief Set camera render target size
     * @param width Width in pixels
     * @param height Height in pixels
     */
    void SetCameraRenderTargetSize(uint32_t width, uint32_t height);

    // ========== RenderTarget Binding ==========
    /**
     * @brief Bind render target to active camera
     * @param renderTarget Render target to bind
     * @return true if successful
     */
    bool BindRenderTargetToCamera(SCENE_NS::IRenderTarget::Ptr renderTarget);

    // ========== Update ==========
    /**
     * @brief Update the scene (call each frame)
     */
    void Update();

    // ========== Accessors ==========
    SCENE_NS::IScene* GetScene() const { return scene_.get(); }
    SCENE_NS::ICamera* GetActiveCamera() const { return activeCamera_.get(); }
    SCENE_NS::IRenderTarget* GetRenderTarget() const { return renderTarget_.get(); }
    bool IsInitialized() const { return initialized_; }

    // ========== Scene Access ==========
    /**
     * @brief Get camera by name
     * @param name Camera name
     * @return Camera pointer or nullptr
     */
    SCENE_NS::ICamera* GetCamera(const std::string& name) const;

    /**
     * @brief Get all cameras in scene
     * @return Vector of camera pointers
     */
    std::vector<SCENE_NS::ICamera*> GetAllCameras() const;

private:
    // Scene objects
    SCENE_NS::IScene::Ptr scene_;
    SCENE_NS::ICamera::Ptr activeCamera_;
    SCENE_NS::IRenderTarget::Ptr renderTarget_;

    // Camera map for quick lookup - use BASE_NS::unordered_map for BASE_NS::string key support
    BASE_NS::unordered_map<BASE_NS::string, SCENE_NS::ICamera::Ptr> cameraMap_;

    // State
    bool initialized_ = false;
};

} // namespace LumeXComponent

#endif // LUME_SCENE_CONTEXT_H