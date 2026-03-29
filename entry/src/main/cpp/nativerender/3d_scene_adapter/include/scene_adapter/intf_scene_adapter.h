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

#ifndef OHOS_RENDER_3D_INTF_SCENE_ADAPTER_H
#define OHOS_RENDER_3D_INTF_SCENE_ADAPTER_H

#include <memory>
#include <meta/interface/intf_object.h>

namespace OHOS::Render3D {

/**
 * @brief Scene adapter interface for engine initialization and lifecycle management.
 *
 * This interface provides the core functionality needed by kits/js for Scene operations.
 * Rendering is handled separately by lume_xcomponent for XComponent mode.
 */
class ISceneAdapter {
public:
    /**
     * @brief Load plugins and initialize the Lume engine
     * @return true if successful
     */
    virtual bool LoadPluginsAndInit() = 0;

    /**
     * @brief Render a frame
     * @param needsSyncPaint Whether to wait for render completion
     */
    virtual void RenderFrame(bool needsSyncPaint = false) = 0;

    /**
     * @brief Deinitialize and release resources
     */
    virtual void Deinit() = 0;

    /**
     * @brief Check if repaint is needed
     * @return true if repaint needed
     */
    virtual bool NeedsRepaint() = 0;

    /**
     * @brief Set scene object for rendering
     * @param sceneObj Scene object pointer
     */
    virtual void SetSceneObj(META_NS::IObject::Ptr sceneObj) {};

    virtual ~ISceneAdapter() = default;
};

} // namespace OHOS::Render3D

#endif // OHOS_RENDER_3D_INTF_SCENE_ADAPTER_H