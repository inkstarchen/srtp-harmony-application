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

#include <hilog/log.h>
#include <napi/native_api.h>

#include "lume_xcomponent/include/lume_xcomponent_manager.h"

using namespace LumeXComponent;

#define LOG_PRINT_DOMAIN 0xFF00

/**
 * @brief NAPI module initialization
 */
EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_PRINT_DOMAIN, "Init", "LumeXComponent Init begins");

    if ((env == nullptr) || (exports == nullptr)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_PRINT_DOMAIN, "Init", "env or exports is null");
        return nullptr;
    }

    // Define exported properties
    napi_property_descriptor desc[] = {
        // Native node creation
        {"createNativeNode", nullptr, LumeXComponentManager::CreateNativeNode,
         nullptr, nullptr, nullptr, napi_default, nullptr},

        // Node binding
        {"bindNode", nullptr, LumeXComponentManager::BindNode,
         nullptr, nullptr, nullptr, napi_default, nullptr},
        {"unbindNode", nullptr, LumeXComponentManager::UnbindNode,
         nullptr, nullptr, nullptr, napi_default, nullptr},

        // Rendering
        {"drawFrame", nullptr, LumeXComponentManager::DrawFrame,
         nullptr, nullptr, nullptr, napi_default, nullptr},
        {"drawPattern", nullptr, LumeXComponentManager::DrawFrame,
         nullptr, nullptr, nullptr, napi_default, nullptr},

        // Scene management
        {"loadScene", nullptr, LumeXComponentManager::LoadScene,
         nullptr, nullptr, nullptr, napi_default, nullptr},

        // State query
        {"getStatus", nullptr, LumeXComponentManager::GetRendererState,
         nullptr, nullptr, nullptr, napi_default, nullptr},

        // Configuration
        {"setFrameRate", nullptr, LumeXComponentManager::SetFrameRate,
         nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setNeedSoftKeyboard", nullptr, LumeXComponentManager::SetNeedSoftKeyboard,
         nullptr, nullptr, nullptr, napi_default, nullptr},

        // Lifecycle
        {"getContext", nullptr, LumeXComponentManager::GetContext,
         nullptr, nullptr, nullptr, napi_default, nullptr},
        {"initialize", nullptr, LumeXComponentManager::Initialize,
         nullptr, nullptr, nullptr, napi_default, nullptr},
        {"finalize", nullptr, LumeXComponentManager::Finalize,
         nullptr, nullptr, nullptr, napi_default, nullptr},
    };

    if (napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc) != napi_ok) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_PRINT_DOMAIN, "Init", "napi_define_properties failed");
        return nullptr;
    }

    // NAPI methods are already registered above via napi_define_properties
    // No need for additional Export call with ArkUI SurfaceHolder API

    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_PRINT_DOMAIN, "Init", "LumeXComponent Init complete");
    return exports;
}
EXTERN_C_END

/**
 * @brief NAPI module definition
 */
static napi_module nativerenderModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "nativerender",  // Module name, must match ArkTS XComponent libraryname
    .nm_priv = nullptr,
    .reserved = {0}
};

/**
 * @brief Register module (called automatically at startup)
 */
extern "C" __attribute__((constructor)) void RegisterModule(void)
{
    napi_module_register(&nativerenderModule);
}