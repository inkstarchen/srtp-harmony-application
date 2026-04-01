/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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
#include <vector>

#include "common/common.h"
#include <lume_xcomponent_manager.h>

// Forward declaration for FileSystemTest methods
// void RegisterFileSystemTestMethods(std::vector<napi_property_descriptor>& props);

namespace LumeXComponent {
// 在napi_init.cpp文件中，Init方法注册接口函数，从而将封装的C++方法传递出来，供ArkTS侧调用
EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    // 初始化开始
    OH_LOG_Print(LOG_APP, LOG_INFO, LOG_PRINT_DOMAIN, "Init", "Init begins");
    if ((env == nullptr) || (exports == nullptr)) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_PRINT_DOMAIN, "Init", "env or exports is null");
        return nullptr;
    }

    // Register methods using vector for dynamic addition
    std::vector<napi_property_descriptor> descVec;

    // XComponent methods
    descVec.push_back({"createNativeNode", nullptr, LumeXComponentManager::createNativeNode, nullptr, nullptr, nullptr,
         napi_default, nullptr });
    descVec.push_back({"getStatus", nullptr, LumeXComponentManager::GetXComponentStatus, nullptr, nullptr,
         nullptr, napi_default, nullptr});
    descVec.push_back({"drawPattern", nullptr, LumeXComponentManager::NapiDrawPattern, nullptr, nullptr,
         nullptr, napi_default, nullptr});
    descVec.push_back({"getContext", nullptr, LumeXComponentManager::GetContext, nullptr, nullptr, nullptr,
        napi_default, nullptr });
    descVec.push_back({"bindNode", nullptr, LumeXComponentManager::BindNode, nullptr, nullptr, nullptr, napi_default, nullptr});
    descVec.push_back({"unbindNode", nullptr, LumeXComponentManager::UnbindNode, nullptr, nullptr, nullptr, napi_default, nullptr});
    descVec.push_back({"setFrameRate", nullptr, LumeXComponentManager::SetFrameRate, nullptr, nullptr, nullptr, napi_default, nullptr});
    descVec.push_back({"setNeedSoftKeyboard", nullptr, LumeXComponentManager::SetNeedSoftKeyboard, nullptr, nullptr, nullptr, napi_default,
         nullptr});
    descVec.push_back({"initialize", nullptr, LumeXComponentManager::Initialize, nullptr, nullptr, nullptr, napi_default, nullptr});
    descVec.push_back({"finalize", nullptr, LumeXComponentManager::Finalize, nullptr, nullptr, nullptr, napi_default, nullptr});
    descVec.push_back({"drawStar", nullptr, LumeXComponentManager::DrawStar, nullptr, nullptr, nullptr, napi_default, nullptr});
    descVec.push_back({"loadScene", nullptr, LumeXComponentManager::LoadScene,nullptr, nullptr, nullptr, napi_default, nullptr});

    // Register FileSystemTest methods
    // RegisterFileSystemTestMethods(descVec);

    if (napi_define_properties(env, exports, descVec.size(), descVec.data()) != napi_ok) {
        OH_LOG_Print(LOG_APP, LOG_ERROR, LOG_PRINT_DOMAIN, "Init", "napi_define_properties failed");
        return nullptr;
    }
    LumeXComponentManager::GetInstance().Export(env, exports);
    return exports;
}
EXTERN_C_END

// 编写接口的描述信息，根据实际需要可以修改对应参数
static napi_module nativerenderModule = { .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    // 入口函数
    .nm_register_func = Init, // 指定加载对应模块时的回调函数
    // 模块名称
    .nm_modname = "nativerender", // 指定模块名称，对于XComponent相关开发，这个名称必须和ArkTS侧XComponent中libraryname的值保持一致
    .nm_priv = ((void*)0),
    .reserved = { 0 } };

// __attribute__((constructor))修饰的方法由系统自动调用，使用Node-API接口napi_module_register()传入模块描述信息进行模块注册
extern "C" __attribute__((constructor)) void RegisterModule(void)
{
    napi_module_register(&nativerenderModule);
}
} // namespace NativeXComponentSample