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

#include "scene_adapter/scene_adapter.h"

#include <dlfcn.h>
#include <memory>
#include <mutex>
#include <string_view>

#include "napi/native_api.h"
#include <arkui/native_node_napi.h>

#include <base/containers/array_view.h>
#include <base/containers/shared_ptr.h>

#include <core/intf_engine.h>
#include <core/ecs/intf_system_graph_loader.h>
#include <core/engine_info.h>
#include <core/image/intf_image_loader_manager.h>
#include <core/implementation_uids.h>
#include <core/io/intf_file_manager.h>
#include <core/namespace.h>
#include <core/os/intf_platform.h>
#include <core/plugin/intf_plugin_register.h>
#include <core/property/intf_property_handle.h>

#include <jpg/implementation_uids.h>

#include <meta/interface/intf_meta_object_lib.h>
#include <meta/interface/intf_task_queue_registry.h>
#include <meta/interface/intf_task_queue.h>
#include <meta/interface/intf_object.h>
#include <meta/interface/intf_object_registry.h>
#include <meta/interface/intf_task_queue.h>
#include <meta/base/interface_macros.h>
#include <meta/api/make_callback.h>
#include <meta/ext/object.h>

#include <png/implementation_uids.h>
#include <scene/base/namespace.h>
#include <scene/interface/intf_scene.h>
#include <3d/ecs/components/environment_component.h>
#include <3d/ecs/components/render_handle_component.h>
#include <3d/ecs/components/uri_component.h>
#include <scene/ext/intf_internal_scene.h>
#include <scene/interface/intf_mesh.h>
#include <scene/interface/intf_material.h>
#include <scene/ext/intf_render_resource.h>
#include <scene/interface/intf_camera.h>
#include <scene/ext/intf_internal_scene.h>
#include <scene/ext/intf_ecs_context.h>
#include <scene/interface/intf_application_context.h>

#include <scene/ext/intf_ecs_object_access.h>

#include <sys/resource.h>

#include <render/implementation_uids.h>
#include <render/gles/intf_device_gles.h>
#include <render/intf_renderer.h>
#include <render/intf_render_context.h>

#include "3d_widget_adapter_log.h"

#define ENGINE_SERVICE_PRIORITY (-20)
namespace OHOS::Render3D {
#define RETURN_IF_NULL(ptr)                                  \
    do {                                                     \
        if (!(ptr)) {                                        \
            WIDGET_LOGE("%s is null in %s", #ptr, __func__); \
            return;                                          \
        }                                                    \
    } while (0)

#define RETURN_FALSE_IF_NULL(ptr)                            \
    do {                                                     \
        if (!(ptr)) {                                        \
            WIDGET_LOGE("%s is null in %s", #ptr, __func__); \
            return false;                                    \
        }                                                    \
    } while (0)

HapInfo GetHapInfo()
{
    
    HapInfo hapInfo;
    hapInfo.bundleName_ = "entry";
    hapInfo.moduleName_ = "DayNote";
    hapInfo.resourceManager_ = nullptr;
    hapInfo.hapPath_ = "./";
    hapInfo.hapPath_ = "./" + hapInfo.moduleName_ + ".hap";
    WIDGET_LOGD("bundle %s, module %s, hapPath %s",
        hapInfo.bundleName_.c_str(),
        hapInfo.moduleName_.c_str(),
        hapInfo.hapPath_.c_str());

    return hapInfo;
}

using IntfPtr = META_NS::SharedPtrIInterface;
using IntfWeakPtr = META_NS::WeakPtrIInterface;

struct EngineInstance {
    void *libHandle_ = nullptr;
    SCENE_NS::IApplicationContext::Ptr applicationContext_;
    BASE_NS::shared_ptr<RENDER_NS::IRenderContext> renderContext_;
    BASE_NS::shared_ptr<CORE_NS::IEngine> engine_;
};

static EngineInstance engineInstance_;
static std::mutex mute;
static HapInfo hapInfo_;
META_NS::ITaskQueue::Ptr engineThread;
META_NS::ITaskQueue::Ptr ioThread;
META_NS::ITaskQueue::Ptr releaseThread;
META_NS::ITaskQueue::Token renderTask {};

void LockCompositor()
{
    mute.lock();
}

void UnlockCompositor()
{
    mute.unlock();
}

static constexpr BASE_NS::Uid ENGINE_THREAD { "2070e705-d061-40e4-bfb7-90fad2c280af" };
static constexpr BASE_NS::Uid APP_THREAD { "b2e8cef3-453a-4651-b564-5190f8b5190d" };
static constexpr BASE_NS::Uid IO_QUEUE { "be88e9a0-9cd8-45ab-be48-937953dc258f" };
static constexpr BASE_NS::Uid JS_RELEASE_THREAD { "3784fa96-b25b-4e9c-bbf1-e897d36f73af" };

template<typename T>
bool LoadFunc(T &fn, const char *fName, void* handle)
{
    // Use union to safely convert void* to function pointer
    // This is well-defined in C++11+ for function pointer types
    union {
        void* ptr;
        T fnPtr;
    } converter;
    converter.ptr = dlsym(handle, fName);
    fn = converter.fnPtr;
    if (fn == nullptr) {
        WIDGET_LOGE("%s open %s", __func__, dlerror());
        return false;
    }
    return true;
}

SceneAdapter::~SceneAdapter()
{
}

SceneAdapter::SceneAdapter()
{
    WIDGET_LOGD("scene adapter Impl create");
}

bool SceneAdapter::LoadEngineLib()
{
    if (engineInstance_.libHandle_ != nullptr) {
        WIDGET_LOGD("%s, already loaded", __func__);
        return true;
    }

    #define TO_STRING(name) #name
    #define LIB_NAME(name) TO_STRING(name)
    constexpr std::string_view lib { LIB_NAME(LIB_ENGINE_CORE)".so" };
    engineInstance_.libHandle_ = dlopen(lib.data(), RTLD_LAZY);

    if (engineInstance_.libHandle_ == nullptr) {
        WIDGET_LOGE("%s, open lib fail %s", __func__, dlerror());
    }
    #undef TO_STRING
    #undef LIB_NAME

    #define LOAD_FUNC(fn, name) LoadFunc<decltype(fn)>(fn, name, engineInstance_.libHandle_)
    if (!(LOAD_FUNC(CORE_NS::CreatePluginRegistry,
        "_ZN4Core20CreatePluginRegistryERKNS_18PlatformCreateInfoE")
        && LOAD_FUNC(CORE_NS::GetPluginRegister, "_ZN4Core17GetPluginRegisterEv")
        && LOAD_FUNC(CORE_NS::IsDebugBuild, "_ZN4Core12IsDebugBuildEv")
        && LOAD_FUNC(CORE_NS::GetVersion, "_ZN4Core13GetVersionRevEv"))) {
        return false;
    }
    #undef LOAD_FUNC

    return true;
}

bool SceneAdapter::LoadPlugins(const CORE_NS::PlatformCreateInfo& platformCreateInfo)
{
    if (engineInstance_.libHandle_) {
        WIDGET_LOGI("%s, already loaded", __func__);
        return true;
    }
    if (!LoadEngineLib()) {
        return false;
    }
    WIDGET_LOGD("load engine suceess!");

    BASE_NS::vector<BASE_NS::Uid> DefaultPluginVector = {
        SCENE_NS::UID_SCENE_PLUGIN,
        JPGPlugin::UID_JPG_PLUGIN,
        PNGPlugin::UID_PNG_PLUGIN,
    };
    const BASE_NS::array_view<BASE_NS::Uid> DefaultPluginList(DefaultPluginVector.data(), DefaultPluginVector.size());
    CORE_NS::CreatePluginRegistry(platformCreateInfo);
    if (!CORE_NS::GetPluginRegister().LoadPlugins(DefaultPluginList)) {
        WIDGET_LOGE("fail to load scene widget plugin");
        return false;
    }
    WIDGET_LOGI("load plugin success");
    return true;
}

bool SceneAdapter::InitEngine(CORE_NS::PlatformCreateInfo platformCreateInfo)
{
    auto& tr = META_NS::GetTaskQueueRegistry();
    auto& obr = META_NS::GetObjectRegistry();

    engineThread = tr.GetTaskQueue(ENGINE_THREAD);
    if (!engineThread) {
        engineThread = obr.Create<META_NS::ITaskQueue>(META_NS::ClassId::ThreadedTaskQueue);
        tr.RegisterTaskQueue(engineThread, ENGINE_THREAD);
    }
    ioThread = tr.GetTaskQueue(IO_QUEUE);
    if (!ioThread) {
        ioThread = obr.Create<META_NS::ITaskQueue>(META_NS::ClassId::ThreadedTaskQueue);
        tr.RegisterTaskQueue(ioThread, IO_QUEUE);
    }
    releaseThread = tr.GetTaskQueue(JS_RELEASE_THREAD);
    if (!releaseThread) {
        auto &obr = META_NS::GetObjectRegistry();
        releaseThread = obr.Create<META_NS::ITaskQueue>(META_NS::ClassId::ThreadedTaskQueue);
        tr.RegisterTaskQueue(releaseThread, JS_RELEASE_THREAD);
    }

    bool inited = false;
    auto initCheck = META_NS::MakeCallback<META_NS::ITaskQueueWaitableTask>([&inited]() {
        inited = (engineInstance_.engine_ != nullptr);
        return META_NS::IAny::Ptr {};
    });
    engineThread->AddWaitableTask(initCheck)->Wait();
    if (inited) {
        WIDGET_LOGI("engine already inited");
        return true;
    }

    auto engineInit = META_NS::MakeCallback<META_NS::ITaskQueueWaitableTask>([platformCreateInfo]() {
        setpriority(0, 0, ENGINE_SERVICE_PRIORITY);
        auto &obr = META_NS::GetObjectRegistry();
        CORE_NS::EngineCreateInfo engineCreateInfo{platformCreateInfo, {}, {}};
        if (auto factory = CORE_NS::GetInstance<CORE_NS::IEngineFactory>(CORE_NS::UID_ENGINE_FACTORY)) {
            engineInstance_.engine_.reset(factory->Create(engineCreateInfo).get());
        } else {
            WIDGET_LOGE("could not get engine factory");
            return META_NS::IAny::Ptr {};
        }
        if (!engineInstance_.engine_) {
            WIDGET_LOGE("get engine fail");
            return META_NS::IAny::Ptr {};
        }
        auto &fileManager = engineInstance_.engine_->GetFileManager();
        const auto &platform = engineInstance_.engine_->GetPlatform();
        platform.RegisterDefaultPaths(fileManager);
        engineInstance_.engine_->Init();

        RENDER_NS::RenderCreateInfo renderCreateInfo{};
        RENDER_NS::BackendExtraGLES glExtra{};
        Render::DeviceCreateInfo deviceCreateInfo{};

        WIDGET_LOGI("backend gles");
        glExtra.depthBits = 24;
        glExtra.sharedContext = EGL_NO_CONTEXT;
        deviceCreateInfo.backendType = RENDER_NS::DeviceBackendType::OPENGLES;
        deviceCreateInfo.backendConfiguration = &glExtra;
        renderCreateInfo.applicationInfo = {};
        renderCreateInfo.deviceCreateInfo = deviceCreateInfo;

        engineInstance_.renderContext_.reset(
            static_cast<RENDER_NS::IRenderContext *>(
                engineInstance_.engine_->GetInterface<CORE_NS::IClassFactory>()
                    ->CreateInstance(RENDER_NS::UID_RENDER_CONTEXT)
                    .release()));

        auto rrc = engineInstance_.renderContext_->Init(renderCreateInfo);
        if (rrc != RENDER_NS::RenderResultCode::RENDER_SUCCESS) {
            WIDGET_LOGE("Failed to create render context");
            return META_NS::IAny::Ptr {};
        }

        auto engineThread = META_NS::GetTaskQueueRegistry().GetTaskQueue(ENGINE_THREAD);
        auto appThread = engineThread;
        auto doc = interface_cast<META_NS::IMetadata>(obr.GetDefaultObjectContext());
        if (doc == nullptr) {
            WIDGET_LOGE("nullptr from interface_cast");
            return META_NS::IAny::Ptr {};
        }
        auto flags = META_NS::ObjectFlagBits::INTERNAL | META_NS::ObjectFlagBits::NATIVE;

        doc->AddProperty(META_NS::ConstructProperty<IntfPtr>("EngineQueue", nullptr, flags));
        doc->AddProperty(META_NS::ConstructProperty<IntfPtr>("AppQueue", nullptr, flags));
        doc->AddProperty(META_NS::ConstructArrayProperty<IntfWeakPtr>("Scenes", {}, flags));

        auto resources =
            META_NS::GetObjectRegistry().Create<CORE_NS::IResourceManager>(
                    META_NS::ClassId::FileResourceManager);
        resources->SetFileManager(CORE_NS::IFileManager::Ptr(&fileManager));

        engineInstance_.applicationContext_ =
            META_NS::GetObjectRegistry().Create<SCENE_NS::IApplicationContext>(
                    SCENE_NS::ClassId::ApplicationContext);
        if (engineInstance_.applicationContext_) {
            SCENE_NS::IApplicationContext::ApplicationContextInfo info{
                engineThread, appThread, engineInstance_.renderContext_,
                    resources, SCENE_NS::SceneOptions{}};
            engineInstance_.applicationContext_->Initialize(info);
        }

        doc->GetProperty<META_NS::SharedPtrIInterface>("EngineQueue")->SetValue(engineThread);
        doc->GetProperty<META_NS::SharedPtrIInterface>("AppQueue")->SetValue(appThread);
        doc->AddProperty(META_NS::ConstructProperty<SCENE_NS::IRenderContext::Ptr>(
                    "RenderContext", engineInstance_.applicationContext_->GetRenderContext(), flags));

        WIDGET_LOGD("register shader paths");
        static constexpr const RENDER_NS::IShaderManager::ShaderFilePathDesc desc { "shaders://" };
        engineInstance_.engine_->GetFileManager().RegisterPath("shaders", "OhosRawFile://shaders", false);
        engineInstance_.renderContext_->GetDevice().GetShaderManager().LoadShaderFiles(desc);

        engineInstance_.engine_->GetFileManager().RegisterPath("appshaders", "OhosRawFile://shaders", false);
        engineInstance_.engine_->GetFileManager().RegisterPath("apppipelinelayouts",
            "OhosRawFile:///pipelinelayouts/", true);
        engineInstance_.engine_->GetFileManager().RegisterPath("fonts", "OhosRawFile:///fonts", true);

        static constexpr const RENDER_NS::IShaderManager::ShaderFilePathDesc desc1 { "appshaders://" };
        engineInstance_.renderContext_->GetDevice().GetShaderManager().LoadShaderFiles(desc1);

        engineInstance_.renderContext_->GetRenderer().RenderFrame({});
        WIDGET_LOGI("init engine success");
        return META_NS::IAny::Ptr {};
    });
    engineThread->AddWaitableTask(engineInit)->Wait();
    return true;
}

void SceneAdapter::SetSceneObj(META_NS::IObject::Ptr pt)
{
    WIDGET_LOGD("SceneAdapter::SetSceneObj");
    sceneWidgetObj_ = pt;
}

bool SceneAdapter::LoadPluginsAndInit()
{
    LockCompositor();
    WIDGET_LOGI("scene adapter loadPlugins");

    if (hapInfo_.hapPath_ == "") {
        hapInfo_ = GetHapInfo();
    }

    #define TO_STRING(name) #name
    #define PLATFORM_PATH_NAME(name) TO_STRING(name)
    CORE_NS::PlatformCreateInfo platformCreateInfo {
        PLATFORM_PATH_NAME(PLATFORM_CORE_ROOT_PATH),
        PLATFORM_PATH_NAME(PLATFORM_CORE_PLUGIN_PATH),
        PLATFORM_PATH_NAME(PLATFORM_APP_ROOT_PATH),
        PLATFORM_PATH_NAME(PLATFORM_APP_PLUGIN_PATH),
        hapInfo_.hapPath_.c_str(),
        hapInfo_.bundleName_.c_str(),
        hapInfo_.moduleName_.c_str(),
        hapInfo_.resourceManager_
    };
    #undef TO_STRING
    #undef PLATFORM_PATH_NAME
    if (!LoadPlugins(platformCreateInfo)) {
        UnlockCompositor();
        return false;
    }

    if (!InitEngine(platformCreateInfo)) {
        UnlockCompositor();
        return false;
    }

    CreateRenderFunction();
    UnlockCompositor();
    return true;
}

void SceneAdapter::CreateRenderFunction()
{
    propSyncSync_ = META_NS::MakeCallback<META_NS::ITaskQueueWaitableTask>([this]() {
        PropSync();
        return META_NS::IAny::Ptr {};
    });
    singleFrameAsync_ = META_NS::MakeCallback<META_NS::ITaskQueueTask>([this]() {
        RenderFunction();
        return 0;
    });
    singleFrameSync_ = META_NS::MakeCallback<META_NS::ITaskQueueWaitableTask>([this]() {
        RenderFunction();
        return META_NS::IAny::Ptr {};
    });
}

void SceneAdapter::DeinitRenderThread()
{
    RETURN_IF_NULL(engineThread);
    if (renderTask) {
        engineThread->CancelTask(renderTask);
        renderTask = nullptr;
    }
    auto engine_deinit = META_NS::MakeCallback<META_NS::ITaskQueueWaitableTask>([]() {
        auto &obr = META_NS::GetObjectRegistry();
        auto doc = interface_cast<META_NS::IMetadata>(obr.GetDefaultObjectContext());
        if (doc == nullptr) {
            WIDGET_LOGE("nullptr from interface_cast");
            return META_NS::IAny::Ptr {};
        }
        {
            auto p1 = doc->GetProperty<IntfPtr>("EngineQueue");
            doc->RemoveProperty(p1);
            auto p2 = doc->GetProperty<IntfPtr>("AppQueue");
            doc->RemoveProperty(p2);
            auto p3 = doc->GetProperty<IntfPtr>("RenderContext");
            doc->RemoveProperty(p3);
        }

        doc->GetArrayProperty<IntfWeakPtr>("Scenes")->Reset();
        engineInstance_.applicationContext_.reset();
        engineInstance_.renderContext_.reset();
        engineInstance_.engine_.reset();

        return META_NS::IAny::Ptr{};
    });
    engineThread->AddWaitableTask(engine_deinit)->Wait();
    auto &tr = META_NS::GetTaskQueueRegistry();
    tr.UnregisterTaskQueue(ENGINE_THREAD);
    engineThread.reset();
    tr.UnregisterTaskQueue(IO_QUEUE);
    ioThread.reset();
    tr.UnregisterTaskQueue(JS_RELEASE_THREAD);
    releaseThread.reset();
}

void SceneAdapter::ShutdownPluginRegistry()
{
    if (engineInstance_.libHandle_ == nullptr) {
        return;
    }
    dlclose(engineInstance_.libHandle_);
    engineInstance_.libHandle_ = nullptr;

    CORE_NS::GetPluginRegister = nullptr;
    CORE_NS::CreatePluginRegistry = nullptr;
    CORE_NS::IsDebugBuild = nullptr;
    CORE_NS::GetVersion = nullptr;
}

void SceneAdapter::PropSync()
{
    auto scene = interface_pointer_cast<SCENE_NS::IScene>(sceneWidgetObj_);
    if (!scene) {
        return;
    }
    auto internal = scene->GetInternalScene();
    if (!internal) {
        return;
    }
    internal->SyncProperties();
}

void SceneAdapter::RenderFunction()
{
    
    auto rc = engineInstance_.renderContext_;
    RETURN_IF_NULL(rc);
    RETURN_IF_NULL(sceneWidgetObj_);
    auto scene = interface_pointer_cast<SCENE_NS::IScene>(sceneWidgetObj_);
    RETURN_IF_NULL(scene);

    auto cams = scene->GetCameras().GetResult();
    for (auto c : cams) {
        if (!bitmap_ && c->IsActive()) {
            c->SetActive(false);
        }
        AttachSwapchain(interface_pointer_cast<META_NS::IObject>(c));
    }

    scene->GetInternalScene()->Update(false);
    rc->GetRenderer().RenderDeferredFrame();

    for (auto& cam : cams) {
        if (!bitmap_ && !cam->IsActive()) {
            cam->SetActive(true);
        }
    }
}

void SceneAdapter::RenderFrame(bool needsSyncPaint)
{
    if (!engineThread) {
        WIDGET_LOGE("no engineThread for Render");
        return;
    }
    if (renderTask) {
        engineThread->CancelTask(renderTask);
        renderTask = nullptr;
    }

    if (!singleFrameAsync_ || !singleFrameSync_ || !propSyncSync_) {
        CreateRenderFunction();
    }

    if (propSyncSync_) {
        
        engineThread->AddWaitableTask(propSyncSync_)->Wait();
    }

    if (!needsSyncPaint && singleFrameAsync_) {
        renderTask = engineThread->AddTask(singleFrameAsync_);
    } else if (singleFrameSync_) {
        engineThread->AddWaitableTask(singleFrameSync_)->Wait();
    } else {
        WIDGET_LOGE("No render function available.");
    }
}

bool SceneAdapter::NeedsRepaint()
{
    return needsRepaint_;
}

void SceneAdapter::SetNeedsRepaint(bool needsRepaint)
{
    needsRepaint_ = needsRepaint;
}

void SceneAdapter::Deinit()
{
    RETURN_IF_NULL(engineThread);
    WIDGET_LOGI("SceneAdapter::Deinit");
    auto func = META_NS::MakeCallback<META_NS::ITaskQueueWaitableTask>([this]() {
        if (swapchainHandle_) {
            auto& device = engineInstance_.renderContext_->GetDevice();
            device.DestroySwapchain(swapchainHandle_);
        }
        swapchainHandle_ = {};
        if (bitmap_) {
            bitmap_.reset();
        }
        return META_NS::IAny::Ptr {};
    });
    engineThread->AddWaitableTask(func)->Wait();

    sceneWidgetObj_.reset();
    singleFrameAsync_.reset();
    singleFrameSync_.reset();
    propSyncSync_.reset();
    needsRepaint_ = false;
    onWindowChanged_ = false;
}

void SceneAdapter::AttachSwapchain(META_NS::IObject::Ptr cameraObj)
{
    auto camera = interface_pointer_cast<SCENE_NS::ICamera>(cameraObj);
    if (!camera) {
        WIDGET_LOGE("cast cameraObj failed in AttachSwapchain.");
        return;
    }
    if (!bitmap_ || !camera->IsActive()) {
        camera->SetRenderTarget({});
        return;
    }
    camera->SetRenderTarget(bitmap_);
}

}  // namespace OHOS::Render3D