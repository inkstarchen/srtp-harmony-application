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

#include "graphics_manager_common.h"

#include "3d_widget_adapter_log.h"
#include "engine_factory.h"
#include "i_engine.h"
#include "platform_data.h"

namespace OHOS::Render3D {
// 注意点：需要拿到信息
HapInfo CreateBundleName()
{
    HapInfo hapInfo;
    hapInfo.bundleName_ = "entry";
    hapInfo.moduleName_ = "DayNote";
    hapInfo.resourceManager_ = nullptr;
    hapInfo.hapPath_ = "./";
    WIDGET_LOGD("bundle %s, module %s, hapPath %s",
        hapInfo.bundleName_.c_str(),
        hapInfo.moduleName_.c_str(),
        hapInfo.hapPath_.c_str());
    return hapInfo;
}

GraphicsManagerCommon::~GraphicsManagerCommon()
{
    // should never be called
}

// 注册一个特定渲染后端类型的视窗
void GraphicsManagerCommon::Register(int32_t key, RenderBackend backend)
{
    if (viewTextures_.find(key) != viewTextures_.end()) {
        return;
    }

    viewTextures_.insert(key);
    backends_[key] = backend;
    return;
}


bool GraphicsManagerCommon::LoadEngineLib()
{
    if (engine_ == nullptr) {
        return false;
    }

    if (engineLoaded_) {
        return true;
    }

    auto success = engine_->LoadEngineLib();
    if (success) {
        engineLoaded_ = true;
    }

    return success;
}

// 初始化调用
bool GraphicsManagerCommon::InitEngine(EGLContext eglContext, PlatformData data)
{

    if (engine_ == nullptr) {
        return false;
    }

    if (engineInited_) {
        return true;
    }

    auto success = engine_->InitEngine(eglContext, data);
    if (success) {
        engineInited_ = true;
    }

    return success;
}

// 销毁调用
void GraphicsManagerCommon::DeInitEngine()
{
    if (engineInited_ && engine_ != nullptr) {
        engine_->DeInitEngine();
        engineInited_ = false;
    }
}

// 卸载库调用
void GraphicsManagerCommon::UnloadEngineLib()
{
    if (engineLoaded_ && engine_ != nullptr) {
        engine_->UnloadEngineLib();
        engineLoaded_ = false;
    }
}

// key 是用来确定渲染后端的，还是要看如何调用，总之是要选择GLES的
// 这里的HapInfo是要改成ArkTS传来的各个对象
std::unique_ptr<IEngine> GraphicsManagerCommon::GetEngine(EngineFactory::EngineType type, int32_t key,
    const HapInfo& hapInfo)
{
    if (viewTextures_.size() > 1u) {
        WIDGET_LOGD("view is not unique and view size is %zu", viewTextures_.size());
    }

    auto backend = backends_.find(key);
    if (backend == backends_.end() || backend->second == RenderBackend::UNDEFINE) {
        WIDGET_LOGE("Get engine before register");
        return nullptr;
    }

    if (backend->second != RenderBackend::GLES) {
        WIDGET_LOGE("not support backend yet");
        return nullptr;
    }

    // 相应修改
    hapInfo_ = CreateBundleName();

    // gles context
    if (engine_ == nullptr) {
        // 创建了一个渲染引擎
        engine_ = EngineFactory::CreateEngine(type);
        WIDGET_LOGD("create proto engine");
        if (!LoadEngineLib()) {
            engine_.reset();
            WIDGET_LOGE("load engine lib fail");
            return nullptr;
        }

        if (!InitEngine(EGL_NO_CONTEXT, GetPlatformData(hapInfo_))) {
            WIDGET_LOGE("init engine fail");
            engine_.reset();
            return nullptr;
        }
    } else {
        WIDGET_LOGD("engine is initialized");
    }

    auto client = EngineFactory::CreateEngine(type);
    client->Clone(engine_.get());
    return client;
}
// 默认路径的创建
std::unique_ptr<IEngine> GraphicsManagerCommon::GetEngine(EngineFactory::EngineType type, int32_t key)
{
    
    if (viewTextures_.size() > 1u) {
        WIDGET_LOGD("view is not unique and view size is %zu", viewTextures_.size());
    }

    auto backend = backends_.find(key);
    if (backend == backends_.end() || backend->second == RenderBackend::UNDEFINE) {
        WIDGET_LOGE("Get engine before register");
        return nullptr;
    }

    if (backend->second != RenderBackend::GLES) {
        WIDGET_LOGE("not support backend yet");
        return nullptr;
    }

    // gles context
    if (engine_ == nullptr) {
        engine_ = EngineFactory::CreateEngine(type);
        WIDGET_LOGD("create proto engine");
        if (!LoadEngineLib()) {
            WIDGET_LOGE("load engine lib fail");
            engine_.reset();
            return nullptr;
        }

        if (!InitEngine(EGL_NO_CONTEXT, GetPlatformData())) {
            WIDGET_LOGE("init engine fail");
            engine_.reset();
            return nullptr;
        }
    } else {
        WIDGET_LOGD("engine is initialized");
    }

    auto client = EngineFactory::CreateEngine(type);
    client->Clone(engine_.get());
    return client;
}

EGLContext GraphicsManagerCommon::GetOrCreateOffScreenContext(EGLContext eglContext)
{
    AutoRestore scope;
    return offScreenContextHelper_.CreateOffScreenContext(eglContext);
}

void GraphicsManagerCommon::BindOffScreenContext()
{
    offScreenContextHelper_.BindOffScreenContext();
}

// 销毁一个视窗
void GraphicsManagerCommon::UnRegister(int32_t key)
{
    WIDGET_LOGD("view unregiser %d total %zu", key, viewTextures_.size());

    auto it = viewTextures_.find(key);
    if (it == viewTextures_.end()) {
        WIDGET_LOGE("view unregiser has not regester");
        return;
    }

    viewTextures_.erase(it);
    auto backend = backends_.find(key);
    if (backend != backends_.end()) {
        backends_.erase(backend);
    }

    if (viewTextures_.empty()) {
        // Destroy proto engine
        WIDGET_LOGE("view reset proto engine");
        DeInitEngine();
        engine_.reset();
    }
    // need graphics task exit!!!
}

RenderBackend GraphicsManagerCommon::GetRenderBackendType(int32_t key)
{
    RenderBackend backend = RenderBackend::UNDEFINE;
    auto it = backends_.find(key);
    if (it != backends_.end()) {
        backend = it->second;
    }
    return backend;
}

const HapInfo& GraphicsManagerCommon::GetHapInfo() const
{
    return hapInfo_;
}

// 检查是否有多个ECS存在
bool GraphicsManagerCommon::HasMultiEcs()
{
    return viewTextures_.size() > 1;
}

// // 注销一个ECS系统
// #if defined(MULTI_ECS_UPDATE_AT_ONCE) && (MULTI_ECS_UPDATE_AT_ONCE == 1)
// void GraphicsManagerCommon::UnloadEcs(void* ecs)
// {
//     WIDGET_LOGD("ACE-3D GraphicsService::UnloadEcs()");
//     ecss_.erase(ecs);
// }

// void GraphicsManagerCommon::DrawFrame(void* ecs, void* handles)
// {
//     WIDGET_SCOPED_TRACE("GraphicsManagerCommon::DrawFrame");
//     ecss_[ecs] = handles;
//     WIDGET_LOGD("ACE-3D DrawFrame ecss size %zu", ecss_.size());
// }

// void GraphicsManagerCommon::PerformDraw()
// {
//     WIDGET_SCOPED_TRACE("GraphicsManagerCommon::PerformDraw");
//     if (engine_ == nullptr) {
//         WIDGET_LOGE("ACE-3D PerformDraw but engine is null");
//         return;
//     }

//     WIDGET_LOGD("ACE-3D PerformDraw");
//     engine_->DrawMultiEcs(ecss_);
//     engine_->AddTextureMemoryBarrrier();
//     ecss_.clear();
// }

// void GraphicsManagerCommon::AttachContext(const OHOS::Ace::WeakPtr<OHOS::Ace::PipelineBase>& context)
// {
//     WIDGET_SCOPED_TRACE("GraphicsManagerCommon::AttachContext");
//     static bool once = false;
//     if (once) {
//         return;
//     }

//     auto pipelineContext = context.Upgrade();
//     if (!pipelineContext) {
//         WIDGET_LOGE("ACE-3D GraphicsManagerCommon::AttachContext() GetContext failed.");
//         return;
//     }

//     once = true;
//     pipelineContext->SetGSVsyncCallback([&] {
//         // here we could only push sync task to graphic task, if async manner we
//         // have no chance to update the rendering future
//         PerformDraw();
//     });
// }
// #endif
} // namespace OHOS::Render3D
