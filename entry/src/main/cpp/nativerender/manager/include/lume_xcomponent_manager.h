/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#ifndef NATIVE_XCOMPONENT_PLUGIN_MANAGER_H
#define NATIVE_XCOMPONENT_PLUGIN_MANAGER_H

#include <ace/xcomponent/native_interface_xcomponent.h>
#include <cstdint>
#include <rawfile/raw_file.h> 
#include <rawfile/raw_file_manager.h> 
#include <js_native_api.h>
#include <js_native_api_types.h>
#include <napi/native_api.h>
#include <string>
#include <mutex>
#include <unordered_map>
#include "../render/egl_core.h"
#include "render/EGLRender.h"
#include "arkui/native_node.h"
#include "arkui/native_node_napi.h"

#include "../render/plugin_render.h"

// Forward declaration
namespace LumeXComponent {
class LumeRenderer;
}
// [Start plugin_manager_h_part]
// plugin_manager.h
namespace LumeXComponent {
// [StartExclude plugin_manager_h_part]
constexpr const int FIRST_ARG = 1;
constexpr const int SECOND_ARG = 2;
constexpr const int THIRD_ARG = 3;
constexpr const int FRAME_COUNT = 50;
// [Start plugin_manager_h]
// 在头文件中定义LumeXComponentManager类
// [EndExclude plugin_manager_h_part]
class LumeXComponentManager {
public:
    // [StartExclude plugin_manager_h_part]
    static OH_NativeXComponent_Callback callback_;
    LumeXComponentManager();
    ~LumeXComponentManager();

    static LumeXComponentManager& GetInstance();
    static napi_value createNativeNode(napi_env env, napi_callback_info info);
    static napi_value GetXComponentStatus(napi_env env, napi_callback_info info);
    static napi_value NapiDrawPattern(napi_env env, napi_callback_info info);
    static napi_value LoadScene(napi_env env, napi_callback_info info);
    // [StartExclude plugin_manager_h]
    static napi_value GetContext(napi_env env, napi_callback_info info);
    // [EndExclude plugin_manager_h_part]
    static napi_value BindNode(napi_env env, napi_callback_info info);
    static napi_value UnbindNode(napi_env env, napi_callback_info info);
    static napi_value SetFrameRate(napi_env env, napi_callback_info info);
    static napi_value SetNeedSoftKeyboard(napi_env env, napi_callback_info info);
    // [StartExclude plugin_manager_h_part]
    static napi_value Initialize(napi_env env, napi_callback_info info);
    static napi_value Finalize(napi_env env, napi_callback_info info);
    static napi_value DrawStar(napi_env env, napi_callback_info info);
    // [EndExclude plugin_manager_h]
    // CApi XComponent
    void OnSurfaceChanged(OH_NativeXComponent* component, void* window);
    void OnSurfaceDestroyed(OH_NativeXComponent* component, void* window);
    void DispatchTouchEvent(OH_NativeXComponent* component, void* window);
    void OnSurfaceCreated(OH_NativeXComponent* component, void* window);
    // [StartExclude plugin_manager_h]
    void SetNativeXComponent(std::string& id, OH_NativeXComponent* nativeXComponent);
    PluginRender* GetRender(std::string& id);
    void Export(napi_env env, napi_value exports);
    // [EndExclude plugin_manager_h]

    // ========== SurfaceHolder Static Callbacks (New API) ==========
    static void OnSurfaceCreatedNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnSurfaceChangedNative(OH_ArkUI_SurfaceHolder* holder, uint64_t width, uint64_t height);
    static void OnSurfaceDestroyedNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnSurfaceShowNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnSurfaceHideNative(OH_ArkUI_SurfaceHolder* holder);
    static void OnFrameCallbackNative(ArkUI_NodeHandle node, uint64_t timestamp, uint64_t targetTimestamp);
    static void OnTouchEventNative(ArkUI_NodeEvent* event);

    LumeRenderer* GetRendererById(const std::string& id);

private:
    static LumeXComponentManager LumeXComponentManager_;
    static NativeResourceManager* resourceMgr_;
    std::unordered_map<std::string, OH_NativeXComponent*> nativeXComponentMap_;
    // [StartExclude plugin_manager_h]
    std::unordered_map<std::string, PluginRender*> pluginRenderMap_;
    // [EndExclude plugin_manager_h]
    std::unordered_map<std::string, LumeXComponentManager*> LumeXComponentManagerMap_;
    // [EndExclude plugin_manager_h_part]

public:
    // [StartExclude plugin_manager_h_part]
    EGLCore *eglcore_;
    uint64_t width_;
    uint64_t height_;
    
    OH_NativeXComponent_TouchEvent touchEvent_;
    static int32_t hasDraw_;
    static int32_t hasChangeColor_;
    // [EndExclude plugin_manager_h_part]
    // [StartExclude plugin_manager_h]
    // ========== Static Data Maps ==========
    // Node ID -> NodeHandle mapping
    static std::unordered_map<std::string, ArkUI_NodeHandle> nodeHandleMap_;

    // NodeHandle -> SurfaceHolder mapping
    static std::unordered_map<ArkUI_NodeHandle, OH_ArkUI_SurfaceHolder*> surfaceHolderMap_;

    // SurfaceHolder -> SurfaceCallback mapping
    static std::unordered_map<OH_ArkUI_SurfaceHolder*, OH_ArkUI_SurfaceCallback*> callbackMap_;

    // NodeHandle -> Renderer mapping (for quick lookup)
    static std::unordered_map<ArkUI_NodeHandle, LumeRenderer*> rendererMap_;
    static ArkUI_AccessibilityProvider *provider_;
    // [EndExclude plugin_manager_h]

private:
    LumeRenderer* GetRendererByNodeInternal(ArkUI_NodeHandle node);
private:
    // ========== ArkUI Node API ==========
    static ArkUI_NativeNodeAPI_1* GetNodeAPI();

    std::mutex mutex_;
};
// [End plugin_manager_h]
} // namespace NativeXComponentSample
// [End plugin_manager_h_part]
#endif // NATIVE_XCOMPONENT_PLUGIN_MANAGER_H
