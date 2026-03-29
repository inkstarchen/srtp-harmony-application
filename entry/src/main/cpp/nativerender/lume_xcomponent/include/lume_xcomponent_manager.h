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

#ifndef LUME_XCOMPONENT_MANAGER_H
#define LUME_XCOMPONENT_MANAGER_H

#include "lume_xcomponent_types.h"
#include "lume_renderer.h"

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <napi/native_api.h>
#include <arkui/native_node.h>
#include <arkui/native_node_napi.h>
#include <arkui/native_interface.h>

#include <unordered_map>
#include <memory>
#include <string>
#include <mutex>
#include <functional>

namespace LumeXComponent {

// Callback types
using MouseCallback = std::function<void(float x, float y, int32_t action, int32_t button)>;
using KeyCallback = std::function<void(int32_t code, int32_t action)>;
using FocusCallback = std::function<void(bool hasFocus)>;

/**
 * @brief Singleton manager for Lume XComponent rendering using ArkUI SurfaceHolder API
 */
class LumeXComponentManager {
public:
    /**
     * @brief Get singleton instance
     */
    static LumeXComponentManager& GetInstance();

    // Disable copy
    LumeXComponentManager(const LumeXComponentManager&) = delete;
    LumeXComponentManager& operator=(const LumeXComponentManager&) = delete;

    // ========== NAPI Export Interfaces ==========
    static napi_value CreateNativeNode(napi_env env, napi_callback_info info);
    static napi_value BindNode(napi_env env, napi_callback_info info);
    static napi_value UnbindNode(napi_env env, napi_callback_info info);
    static napi_value DrawFrame(napi_env env, napi_callback_info info);
    static napi_value LoadScene(napi_env env, napi_callback_info info);
    static napi_value GetRendererState(napi_env env, napi_callback_info info);
    static napi_value SetFrameRate(napi_env env, napi_callback_info info);
    static napi_value SetNeedSoftKeyboard(napi_env env, napi_callback_info info);
    static napi_value GetContext(napi_env env, napi_callback_info info);
    static napi_value Initialize(napi_env env, napi_callback_info info);
    static napi_value Finalize(napi_env env, napi_callback_info info);

    // ========== SurfaceHolder Static Callbacks (New API) ==========
    static void OnSurfaceCreatedNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnSurfaceChangedNative(OH_ArkUI_SurfaceHolder* holder, uint64_t width, uint64_t height);
    static void OnSurfaceDestroyedNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnSurfaceShowNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnSurfaceHideNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnFrameCallbackNative(ArkUI_NodeHandle node, uint64_t timestamp, uint64_t targetTimestamp);
    static void OnTouchEventNative(ArkUI_NodeEvent* event);

    // ========== Helper Methods ==========
    static std::string NapiGetString(napi_env env, napi_value value);
    LumeRenderer* GetRendererByNode(ArkUI_NodeHandle node);
    LumeRenderer* GetRendererById(const std::string& id);

private:
    // Internal version without locking (must be called with mutex already held)
    LumeRenderer* GetRendererByNodeInternal(ArkUI_NodeHandle node);

private:
    LumeXComponentManager();
    ~LumeXComponentManager();

    // ========== Static Data Maps ==========
    // Node ID -> NodeHandle mapping
    static std::unordered_map<std::string, ArkUI_NodeHandle> nodeHandleMap_;

    // NodeHandle -> SurfaceHolder mapping
    static std::unordered_map<ArkUI_NodeHandle, OH_ArkUI_SurfaceHolder*> surfaceHolderMap_;

    // SurfaceHolder -> SurfaceCallback mapping
    static std::unordered_map<OH_ArkUI_SurfaceHolder*, OH_ArkUI_SurfaceCallback*> callbackMap_;

    // NodeHandle -> Renderer mapping (for quick lookup)
    static std::unordered_map<ArkUI_NodeHandle, LumeRenderer*> rendererMap_;

    // ========== ArkUI Node API ==========
    static ArkUI_NativeNodeAPI_1* GetNodeAPI();

    // Thread safety
    std::mutex mutex_;
};

} // namespace LumeXComponent

#endif // LUME_XCOMPONENT_MANAGER_H