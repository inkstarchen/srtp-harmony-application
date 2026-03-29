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

#ifndef OHOS_RENDER_3D_SCENE_ADAPTER_H
#define OHOS_RENDER_3D_SCENE_ADAPTER_H

#include "intf_scene_adapter.h"

#include <meta/interface/intf_object.h>

#include <base/containers/array_view.h>
#include <base/containers/shared_ptr.h>

#include <core/intf_engine.h>
#include <core/ecs/intf_system_graph_loader.h>
#include <core/engine_info.h>
#include <core/implementation_uids.h>
#include <core/io/intf_file_manager.h>
#include <core/namespace.h>
#include <core/os/intf_platform.h>
#include <core/plugin/intf_plugin_register.h>
#include <core/property/intf_property_handle.h>

#include <3d/ecs/systems/intf_node_system.h>

#include <meta/interface/intf_meta_object_lib.h>
#include <meta/interface/intf_task_queue_registry.h>
#include <meta/interface/intf_task_queue.h>
#include <meta/interface/intf_object.h>
#include <meta/interface/intf_object_registry.h>
#include <meta/interface/intf_task_queue.h>
#include <meta/base/interface_macros.h>
#include <meta/api/make_callback.h>
#include <meta/ext/object.h>

#include <scene/base/namespace.h>
#include <scene/interface/intf_scene.h>
#include <scene/interface/intf_mesh.h>
#include <scene/interface/intf_material.h>

#include <render/implementation_uids.h>
#include <render/gles/intf_device_gles.h>
#include <render/intf_renderer.h>
#include <render/intf_render_context.h>

#include <ohos/platform_data.h>

namespace OHOS::Render3D {

/**
 * @brief Scene adapter for Lume engine initialization and lifecycle management.
 *
 * This class handles:
 * - Lume engine initialization
 * - Plugin loading (SCENE, JPG, PNG)
 * - Render context creation
 * - Application context setup
 *
 * For XComponent rendering, use lume_xcomponent module.
 * This adapter is primarily used by kits/js for Scene API operations.
 */
class SceneAdapter : public ISceneAdapter {
public:
    SceneAdapter();
    ~SceneAdapter() override;

    // ========== ISceneAdapter Interface ==========
    bool LoadPluginsAndInit() override;
    void RenderFrame(bool needsSyncPaint = false) override;
    void Deinit() override;
    bool NeedsRepaint() override;

    void SetNeedsRepaint(bool needsRepaint);
    void SetSceneObj(META_NS::IObject::Ptr pt) override;

    // ========== Static Lifecycle Methods ==========
    static void ShutdownPluginRegistry();
    static void DeinitRenderThread();

protected:
    // ========== Engine Initialization ==========
    static bool LoadEngineLib();
    static bool LoadPlugins(const CORE_NS::PlatformCreateInfo& platformCreateInfo);
    static bool InitEngine(CORE_NS::PlatformCreateInfo platformCreateInfo);

    // ========== Rendering ==========
    void RenderFunction();
    void CreateRenderFunction();
    void PropSync();
    void AttachSwapchain(META_NS::IObject::Ptr camera);

protected:
    // Scene object reference (set by kits/js)
    META_NS::IObject::Ptr sceneWidgetObj_;

    // Render target
    SCENE_NS::IRenderTarget::Ptr bitmap_;
    RENDER_NS::RenderHandleReference swapchainHandle_;

    // Render state
    bool needsRepaint_ = true;
    bool onWindowChanged_ = false;

    // Task queues
    META_NS::ITaskQueueTask::Ptr singleFrameAsync_;
    META_NS::ITaskQueueWaitableTask::Ptr singleFrameSync_;
    META_NS::ITaskQueueWaitableTask::Ptr propSyncSync_;
};

} // namespace OHOS::Render3D

#endif // OHOS_RENDER_3D_SCENE_ADAPTER_H