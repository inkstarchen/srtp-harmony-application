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

#include "lume_scene_context.h"

#include <hilog/log.h>

// Lume headers
#include <scene/interface/intf_scene.h>
#include <scene/interface/intf_camera.h>
#include <scene/interface/intf_render_target.h>
#include <scene/interface/intf_application_context.h>
#include <scene/interface/intf_scene_manager.h>
#include <scene/ext/intf_internal_scene.h>

#include <meta/interface/intf_object_registry.h>
#include <meta/interface/intf_object.h>

#define LOG_TAG "LumeSceneContext"
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, 0, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0, LOG_TAG, __VA_ARGS__)
#define LOGD(...) OH_LOG_Print(LOG_APP, LOG_DEBUG, 0, LOG_TAG, __VA_ARGS__)

using namespace SCENE_NS;

namespace LumeXComponent {

LumeSceneContext::LumeSceneContext()
{
    LOGI("LumeSceneContext created");
}

LumeSceneContext::~LumeSceneContext()
{
    LOGI("LumeSceneContext destroyed");

    if (activeCamera_) {
        activeCamera_->SetActive(false);
    }

    cameraMap_.clear();
    scene_.reset();
    renderTarget_.reset();
}

bool LumeSceneContext::CreateEmptyScene()
{
    LOGI("CreateEmptyScene");

    auto applicationContext = SCENE_NS::GetDefaultApplicationContext();

    if (!applicationContext) {
        LOGE("No default application context");
        return false;
    }

    auto sceneManager = applicationContext->GetSceneManager();
    if (!sceneManager) {
        LOGE("No scene manager");
        return false;
    }

    auto sceneResult = sceneManager->CreateScene();
    if (!sceneResult) {
        LOGE("Failed to create scene");
        return false;
    }

    scene_ = sceneResult.GetResult();
    if (!scene_) {
        LOGE("Scene result is null");
        return false;
    }

    initialized_ = true;
    LOGI("Empty scene created successfully");
    return true;
}

bool LumeSceneContext::LoadFromGLTF(const std::string& path)
{
    LOGI("LoadFromGLTF: %{public}s", path.c_str());

    auto applicationContext = SCENE_NS::GetDefaultApplicationContext();

    if (!applicationContext) {
        LOGE("No default application context");
        return false;
    }

    auto sceneManager = applicationContext->GetSceneManager();
    if (!sceneManager) {
        LOGE("No scene manager");
        return false;
    }

    // Create scene from GLTF - convert std::string to BASE_NS::string_view via c_str()
    auto sceneResult = sceneManager->CreateScene(BASE_NS::string_view(path.c_str()));
    if (!sceneResult) {
        LOGE("Failed to load scene from: %{public}s", path.c_str());
        return false;
    }

    scene_ = sceneResult.GetResult();
    if (!scene_) {
        LOGE("Scene result is null");
        return false;
    }

    // Get cameras from loaded scene
    auto cameras = scene_->GetCameras().GetResult();
    LOGI("Scene loaded, cameras count: %{public}zu", cameras.size());

    for (auto& camera : cameras) {
        // Get camera name through IObject interface
        auto obj = interface_cast<META_NS::IObject>(camera);
        auto name = obj ? obj->GetName() : BASE_NS::string("unnamed");
        cameraMap_[name] = camera;
        LOGI("Found camera: %{public}s", name.c_str());
    }

    // Set first camera as active
    if (!cameras.empty()) {
        activeCamera_ = cameras[0];
        activeCamera_->SetActive(true);
        auto obj = interface_cast<META_NS::IObject>(activeCamera_);
        auto activeName = obj ? obj->GetName() : BASE_NS::string("unnamed");
        LOGI("Active camera set: %{public}s", activeName.c_str());
    }

    initialized_ = true;
    LOGI("Scene loaded successfully from: %{public}s", path.c_str());
    return true;
}

bool LumeSceneContext::CreateCamera(const std::string& name)
{
    LOGI("CreateCamera: %{public}s", name.c_str());

    if (!scene_) {
        LOGE("No scene available");
        return false;
    }

    // Create camera node - convert std::string to BASE_NS::string_view via c_str()
    auto cameraResult = scene_->CreateNode<ICamera>(BASE_NS::string_view(name.c_str()));
    if (!cameraResult) {
        LOGE("Failed to create camera: %{public}s", name.c_str());
        return false;
    }

    auto camera = cameraResult.GetResult();
    if (!camera) {
        LOGE("Camera result is null");
        return false;
    }

    // Configure default camera settings using property setters
    camera->FoV()->SetValue(60.0f);
    camera->NearPlane()->SetValue(0.1f);
    camera->FarPlane()->SetValue(1000.0f);
    camera->Projection()->SetValue(CameraProjection::PERSPECTIVE);

    // Use c_str() to construct BASE_NS::string from const char*
    cameraMap_[BASE_NS::string(name.c_str())] = camera;

    // Set as active if no active camera
    if (!activeCamera_) {
        activeCamera_ = camera;
        camera->SetActive(true);
        LOGI("Set as active camera: %{public}s", name.c_str());
    }

    LOGI("Camera created: %{public}s", name.c_str());
    return true;
}

void LumeSceneContext::SetActiveCamera(const std::string& name)
{
    LOGI("SetActiveCamera: %{public}s", name.c_str());

    auto it = cameraMap_.find(BASE_NS::string(name.c_str()));
    if (it == cameraMap_.end()) {
        LOGE("Camera not found: %{public}s", name.c_str());
        return;
    }

    // Deactivate current camera
    if (activeCamera_) {
        activeCamera_->SetActive(false);
    }

    // Set new active camera
    activeCamera_ = it->second;
    activeCamera_->SetActive(true);

    LOGI("Active camera changed to: %{public}s", name.c_str());
}

void LumeSceneContext::SetCameraFoV(float fov)
{
    if (activeCamera_) {
        activeCamera_->FoV()->SetValue(fov);
    }
}

void LumeSceneContext::SetCameraNearPlane(float near)
{
    if (activeCamera_) {
        activeCamera_->NearPlane()->SetValue(near);
    }
}

void LumeSceneContext::SetCameraFarPlane(float far)
{
    if (activeCamera_) {
        activeCamera_->FarPlane()->SetValue(far);
    }
}

void LumeSceneContext::SetCameraRenderTargetSize(uint32_t width, uint32_t height)
{
    if (activeCamera_) {
        activeCamera_->RenderTargetSize()->SetValue({width, height});
    }
}

bool LumeSceneContext::BindRenderTargetToCamera(IRenderTarget::Ptr renderTarget)
{
    LOGI("BindRenderTargetToCamera");

    if (!activeCamera_) {
        LOGE("No active camera");
        return false;
    }

    if (!renderTarget) {
        LOGE("Invalid render target");
        return false;
    }

    auto result = activeCamera_->SetRenderTarget(renderTarget);
    if (!result.GetResult()) {
        LOGE("Failed to set render target");
        return false;
    }

    renderTarget_ = renderTarget;
    LOGI("Render target bound to camera");
    return true;
}

void LumeSceneContext::Update()
{
    if (!scene_) {
        return;
    }

    auto internalScene = scene_->GetInternalScene();
    if (internalScene) {
        internalScene->Update(false);
    }
}

SCENE_NS::ICamera* LumeSceneContext::GetCamera(const std::string& name) const
{
    auto it = cameraMap_.find(BASE_NS::string(name.c_str()));
    if (it != cameraMap_.end()) {
        return it->second.get();
    }
    return nullptr;
}

std::vector<SCENE_NS::ICamera*> LumeSceneContext::GetAllCameras() const
{
    std::vector<SCENE_NS::ICamera*> cameras;
    for (const auto& pair : cameraMap_) {
        cameras.push_back(pair.second.get());
    }
    return cameras;
}

} // namespace LumeXComponent