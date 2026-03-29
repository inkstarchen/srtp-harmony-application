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

#include "lume_xcomponent_manager.h"

#include <hilog/log.h>
#include <string>
#include <ace/xcomponent/native_interface_xcomponent.h>
#include "arkui/native_node.h"
#include "arkui/native_node_napi.h"
#include "arkui/native_interface.h"

// Undefine LOG_TAG from hilog before defining our own
#ifdef LOG_TAG
#undef LOG_TAG
#endif
#define LOG_TAG "LumeXComponentMgr"
#define LOGI(...) OH_LOG_Print(LOG_APP, LOG_INFO, 0, LOG_TAG, __VA_ARGS__)
#define LOGE(...) OH_LOG_Print(LOG_APP, LOG_ERROR, 0, LOG_TAG, __VA_ARGS__)
#define LOGD(...) OH_LOG_Print(LOG_APP, LOG_DEBUG, 0, LOG_TAG, __VA_ARGS__)

namespace LumeXComponent {

// ==================== Static Member Initialization ====================

std::unordered_map<std::string, ArkUI_NodeHandle> LumeXComponentManager::nodeHandleMap_;
std::unordered_map<ArkUI_NodeHandle, OH_ArkUI_SurfaceHolder*> LumeXComponentManager::surfaceHolderMap_;
std::unordered_map<OH_ArkUI_SurfaceHolder*, OH_ArkUI_SurfaceCallback*> LumeXComponentManager::callbackMap_;
std::unordered_map<ArkUI_NodeHandle, LumeRenderer*> LumeXComponentManager::rendererMap_;

// ==================== Singleton ====================

LumeXComponentManager& LumeXComponentManager::GetInstance()
{
    static LumeXComponentManager instance;
    return instance;
}

LumeXComponentManager::LumeXComponentManager()
{
    LOGI("LumeXComponentManager created (using ArkUI SurfaceHolder API)");
}

LumeXComponentManager::~LumeXComponentManager()
{
    LOGI("LumeXComponentManager destroyed");

    std::lock_guard<std::mutex> lock(mutex_);

    // Clean up all renderers and holders
    for (auto& pair : surfaceHolderMap_) {
        auto holder = pair.second;

        // Remove and dispose callback
        if (callbackMap_.count(holder)) {
            auto callback = callbackMap_[holder];
            OH_ArkUI_SurfaceHolder_RemoveSurfaceCallback(holder, callback);
            OH_ArkUI_SurfaceCallback_Dispose(callback);
            callbackMap_.erase(holder);
        }

        // Delete renderer
        if (rendererMap_.count(pair.first)) {
            auto renderer = rendererMap_[pair.first];
            renderer->OnSurfaceDestroyed();
            delete renderer;
            rendererMap_.erase(pair.first);
        }

        // Dispose holder
        OH_ArkUI_SurfaceHolder_Dispose(holder);
    }

    surfaceHolderMap_.clear();
    nodeHandleMap_.clear();
}

// ==================== ArkUI Node API Helper ====================

ArkUI_NativeNodeAPI_1* LumeXComponentManager::GetNodeAPI()
{
    static ArkUI_NativeNodeAPI_1* nodeAPI = reinterpret_cast<ArkUI_NativeNodeAPI_1*>(
        OH_ArkUI_QueryModuleInterfaceByName(ARKUI_NATIVE_NODE, "ArkUI_NativeNodeAPI_1"));
    return nodeAPI;
}

// ==================== NAPI String Helper ====================

std::string LumeXComponentManager::NapiGetString(napi_env env, napi_value value)
{
    size_t strSize = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &strSize);
    std::string str;
    str.resize(strSize);
    napi_get_value_string_utf8(env, value, &str[0], strSize + 1, &strSize);
    return str;
}

// ==================== SurfaceHolder Static Callbacks (New API) ====================

void LumeXComponentManager::OnSurfaceCreatedNative(OH_ArkUI_SurfaceHolder* holder)
{
    LOGI("OnSurfaceCreatedNative");

    auto window = OH_ArkUI_XComponent_GetNativeWindow(holder);
    auto renderer = reinterpret_cast<LumeRenderer*>(OH_ArkUI_SurfaceHolder_GetUserData(holder));

    if (!renderer || !window) {
        LOGE("OnSurfaceCreatedNative: renderer or window is null");
        return;
    }

    // Find the node handle for this holder
    ArkUI_NodeHandle node = nullptr;
    for (auto& pair : surfaceHolderMap_) {
        if (pair.second == holder) {
            node = pair.first;
            break;
        }
    }

    if (!node) {
        LOGE("OnSurfaceCreatedNative: node not found");
        return;
    }

    // Get window size from node attributes
    auto nodeAPI = GetNodeAPI();
    auto widthAttr = nodeAPI->getAttribute(node, NODE_WIDTH);
    auto heightAttr = nodeAPI->getAttribute(node, NODE_HEIGHT);

    uint32_t width = widthAttr ? static_cast<uint32_t>(widthAttr->value[0].f32) : 800;
    uint32_t height = heightAttr ? static_cast<uint32_t>(heightAttr->value[0].f32) : 600;

    LOGI("OnSurfaceCreatedNative: window=%p, size=%ux%u", window, width, height);

    if (renderer->Initialize(window, width, height)) {
        LOGI("Renderer initialized successfully");
    } else {
        LOGE("Renderer initialization failed");
    }
}

void LumeXComponentManager::OnSurfaceChangedNative(OH_ArkUI_SurfaceHolder* holder, uint64_t width, uint64_t height)
{
    LOGI("OnSurfaceChangedNative: size=%llu x %llu", (unsigned long long)width, (unsigned long long)height);

    auto renderer = reinterpret_cast<LumeRenderer*>(OH_ArkUI_SurfaceHolder_GetUserData(holder));
    if (!renderer) {
        LOGE("OnSurfaceChangedNative: renderer is null");
        return;
    }

    auto window = OH_ArkUI_XComponent_GetNativeWindow(holder);
    renderer->OnSurfaceChanged(window, static_cast<uint32_t>(width), static_cast<uint32_t>(height));
}

void LumeXComponentManager::OnSurfaceDestroyedNative(OH_ArkUI_SurfaceHolder* holder)
{
    LOGI("OnSurfaceDestroyedNative");

    auto renderer = reinterpret_cast<LumeRenderer*>(OH_ArkUI_SurfaceHolder_GetUserData(holder));
    if (renderer) {
        renderer->OnSurfaceDestroyed();
    }
}

void LumeXComponentManager::OnSurfaceShowNative(OH_ArkUI_SurfaceHolder* holder)
{
    LOGI("OnSurfaceShowNative");
}

void LumeXComponentManager::OnSurfaceHideNative(OH_ArkUI_SurfaceHolder* holder)
{
    LOGI("OnSurfaceHideNative");
}

void LumeXComponentManager::OnFrameCallbackNative(ArkUI_NodeHandle node, uint64_t timestamp, uint64_t targetTimestamp)
{
    if (!surfaceHolderMap_.count(node)) {
        return;
    }

    auto holder = surfaceHolderMap_[node];
    auto renderer = reinterpret_cast<LumeRenderer*>(OH_ArkUI_SurfaceHolder_GetUserData(holder));

    if (renderer && renderer->GetState() == RenderState::READY) {
        renderer->RenderFrame();
    }
}

void LumeXComponentManager::OnTouchEventNative(ArkUI_NodeEvent* event)
{
    auto eventType = OH_ArkUI_NodeEvent_GetEventType(event);
    LOGD("OnTouchEventNative: eventType=%d", static_cast<int>(eventType));

    if (eventType == NODE_TOUCH_EVENT) {
        ArkUI_NodeHandle handle = OH_ArkUI_NodeEvent_GetNodeHandle(event);

        if (!surfaceHolderMap_.count(handle)) {
            return;
        }

        auto holder = surfaceHolderMap_[handle];
        auto renderer = reinterpret_cast<LumeRenderer*>(OH_ArkUI_SurfaceHolder_GetUserData(holder));

        if (renderer) {
            // Touch handling for ArkUI nodes
            LOGD("Touch event received on node");
        }
    }
}

// ==================== Renderer Helper Methods ====================

// Internal version without locking (must be called with mutex already held)
LumeRenderer* LumeXComponentManager::GetRendererByNodeInternal(ArkUI_NodeHandle node)
{
    auto it = rendererMap_.find(node);
    return it != rendererMap_.end() ? it->second : nullptr;
}

LumeRenderer* LumeXComponentManager::GetRendererByNode(ArkUI_NodeHandle node)
{
    std::lock_guard<std::mutex> lock(mutex_);
    return GetRendererByNodeInternal(node);
}

LumeRenderer* LumeXComponentManager::GetRendererById(const std::string& id)
{
    std::lock_guard<std::mutex> lock(mutex_);
    LOGI("GetRendererById: id=%s", id.c_str());
    auto it = nodeHandleMap_.find(id);
    if (it != nodeHandleMap_.end()) {
        return GetRendererByNodeInternal(it->second);
    }
    return nullptr;
}

// ==================== NAPI Export Interfaces ====================

napi_value LumeXComponentManager::CreateNativeNode(napi_env env, napi_callback_info info)
{
    LOGI("CreateNativeNode");

    size_t argCnt = 2;
    napi_value args[2] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    // Get NodeContentHandle
    ArkUI_NodeContentHandle nodeContentHandle = nullptr;
    OH_ArkUI_GetNodeContentFromNapiValue(env, args[0], &nodeContentHandle);

    // Get tag string
    std::string tag = NapiGetString(env, args[1]);
    LOGI("CreateNativeNode tag: %s", tag.c_str());

    // Set user data
    int32_t ret = OH_ArkUI_NodeContent_SetUserData(nodeContentHandle, new std::string(tag));
    if (ret != ARKUI_ERROR_CODE_NO_ERROR) {
        LOGE("setUserData failed error=%d", ret);
    }

    auto nodeAPI = GetNodeAPI();
    if (nodeAPI && nodeAPI->createNode && nodeAPI->addChild) {
        // Register node content event callback
        auto nodeContentEvent = [](ArkUI_NodeContentEvent* event) {
            ArkUI_NodeContentHandle handle = OH_ArkUI_NodeContentEvent_GetNodeContentHandle(event);
            std::string* userData = reinterpret_cast<std::string*>(OH_ArkUI_NodeContent_GetUserData(handle));

            if (OH_ArkUI_NodeContentEvent_GetEventType(event) == NODE_CONTENT_EVENT_ON_ATTACH_TO_WINDOW) {
                // Create XComponent node
                auto api = LumeXComponentManager::GetNodeAPI();

                // Create column container
                ArkUI_NodeHandle column = api->createNode(ARKUI_NODE_COLUMN);

                // Create XComponent node
                ArkUI_NodeHandle xc = api->createNode(ARKUI_NODE_XCOMPONENT);

                // Set XComponent type to surface
                ArkUI_NumberValue typeValue[] = {ARKUI_XCOMPONENT_TYPE_SURFACE};
                ArkUI_AttributeItem typeItem = {typeValue, 1};
                api->setAttribute(xc, NODE_XCOMPONENT_TYPE, &typeItem);

                // Set XComponent id
                std::string nodeTag = userData ? *userData : "default";
                ArkUI_AttributeItem idItem = {nullptr, 0, nodeTag.c_str()};
                api->setAttribute(xc, NODE_XCOMPONENT_ID, &idItem);

                // Set size
                ArkUI_NumberValue sizeValue[] = {480.0f}; // width
                ArkUI_AttributeItem widthItem = {sizeValue, 1};
                api->setAttribute(xc, NODE_WIDTH, &widthItem);

                sizeValue[0].f32 = 480.0f; // height
                ArkUI_AttributeItem heightItem = {sizeValue, 1};
                api->setAttribute(xc, NODE_HEIGHT, &heightItem);

                // Set focusable
                ArkUI_NumberValue focusable[] = {1};
                ArkUI_AttributeItem focusableItem = {focusable, 1};
                api->setAttribute(xc, NODE_FOCUSABLE, &focusableItem);

                // Add XComponent to column
                api->addChild(column, xc);

                // Store node handle
                LumeXComponentManager::nodeHandleMap_[nodeTag] = xc;

                // Add to content
                OH_ArkUI_NodeContent_AddNode(handle, column);

                // Clean up userData
                if (userData) {
                    delete userData;
                    OH_ArkUI_NodeContent_SetUserData(handle, nullptr);
                }

                LOGI("XComponent node created: %s", nodeTag.c_str());
            }
        };

        OH_ArkUI_NodeContent_RegisterCallback(nodeContentHandle, nodeContentEvent);
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value LumeXComponentManager::BindNode(napi_env env, napi_callback_info info)
{
    LOGI("BindNode");

    size_t argCnt = 2;
    napi_value args[2] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    // Get nodeId
    std::string nodeId = NapiGetString(env, args[0]);
    LOGI("BindNode nodeId: %{public}s", nodeId.c_str());

    // Get node handle
    ArkUI_NodeHandle handle;
    OH_ArkUI_GetNodeHandleFromNapiValue(env, args[1], &handle);

    if (!handle) {
        LOGE("Failed to get node handle");
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }
    LOGI("BindNode node handle: %{public}p", handle);
    // Create SurfaceHolder
    OH_ArkUI_SurfaceHolder* holder = OH_ArkUI_SurfaceHolder_Create(handle);
    LOGI("HOLDER %{public}p", holder);
    // Store node handle
    nodeHandleMap_[nodeId] = handle;
    if (!holder) {
        LOGE("Failed to create SurfaceHolder");
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }
    surfaceHolderMap_[handle] = holder;
  
    // Create SurfaceCallback
    auto callback = OH_ArkUI_SurfaceCallback_Create();
    if (!callback) {
        LOGE("Failed to create SurfaceCallback");
        OH_ArkUI_SurfaceHolder_Dispose(holder);
        surfaceHolderMap_.erase(handle);
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }
    callbackMap_[holder] = callback;
    LOGI("Create SurfaceCallback");
    // Create LumeRenderer
    auto renderer = new LumeRenderer(nodeId);
    OH_ArkUI_SurfaceHolder_SetUserData(holder, renderer);
    rendererMap_[handle] = renderer;

    // Register Surface callbacks
    OH_ArkUI_SurfaceCallback_SetSurfaceCreatedEvent(callback, LumeXComponentManager::OnSurfaceCreatedNative);
    OH_ArkUI_SurfaceCallback_SetSurfaceChangedEvent(callback, OnSurfaceChangedNative);
    OH_ArkUI_SurfaceCallback_SetSurfaceDestroyedEvent(callback, OnSurfaceDestroyedNative);
    OH_ArkUI_SurfaceCallback_SetSurfaceShowEvent(callback, OnSurfaceShowNative);
    OH_ArkUI_SurfaceCallback_SetSurfaceHideEvent(callback, OnSurfaceHideNative);

    // Register frame callback
    OH_ArkUI_XComponent_RegisterOnFrameCallback(handle, OnFrameCallbackNative);

    // Register touch event
    auto nodeAPI = GetNodeAPI();
    if (nodeAPI) {
        nodeAPI->addNodeEventReceiver(handle, OnTouchEventNative);
        nodeAPI->registerNodeEvent(handle, NODE_TOUCH_EVENT, 0, nullptr);
    }

    // Add SurfaceCallback to holder
    OH_ArkUI_SurfaceHolder_AddSurfaceCallback(holder, callback);

    LOGI("BindNode completed successfully: %s", nodeId.c_str());

    napi_value result;
    napi_get_boolean(env, true, &result);
    return result;
}

napi_value LumeXComponentManager::UnbindNode(napi_env env, napi_callback_info info)
{
    LOGI("UnbindNode");

    size_t argCnt = 1;
    napi_value args[1] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);
    LOGI("UnbindNode nodeId: %s", nodeId.c_str());

    std::lock_guard<std::mutex> lock(GetInstance().mutex_);

    // Find node handle
    auto nodeIt = nodeHandleMap_.find(nodeId);
    if (nodeIt == nodeHandleMap_.end()) {
        LOGE("Node not found: %s", nodeId.c_str());
        napi_value result;
        napi_get_undefined(env, &result);
        return result;
    }

    ArkUI_NodeHandle node = nodeIt->second;

    // Unregister frame callback
    OH_ArkUI_XComponent_UnregisterOnFrameCallback(node);

    // Find holder
    auto holderIt = surfaceHolderMap_.find(node);
    if (holderIt != surfaceHolderMap_.end()) {
        auto holder = holderIt->second;

        // Remove and dispose callback
        auto callbackIt = callbackMap_.find(holder);
        if (callbackIt != callbackMap_.end()) {
            auto callback = callbackIt->second;
            OH_ArkUI_SurfaceHolder_RemoveSurfaceCallback(holder, callback);
            OH_ArkUI_SurfaceCallback_Dispose(callback);
            callbackMap_.erase(callbackIt);
        }

        // Delete renderer
        auto rendererIt = rendererMap_.find(node);
        if (rendererIt != rendererMap_.end()) {
            auto renderer = rendererIt->second;
            renderer->OnSurfaceDestroyed();
            delete renderer;
            rendererMap_.erase(rendererIt);
        }

        // Dispose holder
        OH_ArkUI_SurfaceHolder_Dispose(holder);
        surfaceHolderMap_.erase(holderIt);
    }

    // Remove from maps
    nodeHandleMap_.erase(nodeIt);

    LOGI("UnbindNode completed: %s", nodeId.c_str());

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value LumeXComponentManager::DrawFrame(napi_env env, napi_callback_info info)
{
    size_t argCnt = 1;
    napi_value args[1] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);
    LOGD("DrawFrame nodeId: %s", nodeId.c_str());

    auto renderer = GetInstance().GetRendererById(nodeId);
    if (renderer) {
        renderer->RenderFrame();
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value LumeXComponentManager::LoadScene(napi_env env, napi_callback_info info)
{
    LOGI("LoadScene");

    size_t argCnt = 2;
    napi_value args[2] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);
    std::string gltfPath = NapiGetString(env, args[1]);

    LOGI("LoadScene nodeId: %{public}s, path: %{public}s", nodeId.c_str(), gltfPath.c_str());

    bool success = false;
    auto renderer = GetInstance().GetRendererById(nodeId);
    if (renderer) {
        LOGE("Renderer found");
        success = renderer->LoadScene(gltfPath);
    } else {
        LOGE("Renderer not found");
    }

    napi_value result;
    napi_get_boolean(env, success, &result);
    return result;
}

napi_value LumeXComponentManager::GetRendererState(napi_env env, napi_callback_info info)
{
    size_t argCnt = 1;
    napi_value args[1] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);

    int32_t state = static_cast<int32_t>(RenderState::UNINITIALIZED);
    auto renderer = GetInstance().GetRendererById(nodeId);
    if (renderer) {
        state = static_cast<int32_t>(renderer->GetState());
    }

    napi_value result;
    napi_create_int32(env, state, &result);
    return result;
}

napi_value LumeXComponentManager::SetFrameRate(napi_env env, napi_callback_info info)
{
    LOGI("SetFrameRate");

    size_t argCnt = 4;
    napi_value args[4] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);

    int32_t min = 0;
    napi_get_value_int32(env, args[1], &min);

    int32_t max = 0;
    napi_get_value_int32(env, args[2], &max);

    int32_t expected = 0;
    napi_get_value_int32(env, args[3], &expected);

    LOGI("SetFrameRate nodeId: %s, min=%d, max=%d, expected=%d", nodeId.c_str(), min, max, expected);

    std::lock_guard<std::mutex> lock(GetInstance().mutex_);

    auto it = nodeHandleMap_.find(nodeId);
    if (it != nodeHandleMap_.end()) {
        OH_NativeXComponent_ExpectedRateRange range {
            .min = min,
            .max = max,
            .expected = expected
        };
        OH_ArkUI_XComponent_SetExpectedFrameRateRange(it->second, range);
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value LumeXComponentManager::SetNeedSoftKeyboard(napi_env env, napi_callback_info info)
{
    LOGI("SetNeedSoftKeyboard");

    size_t argCnt = 2;
    napi_value args[2] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);

    bool needSoftKeyboard = false;
    napi_get_value_bool(env, args[1], &needSoftKeyboard);

    LOGI("SetNeedSoftKeyboard nodeId: %s, need=%d", nodeId.c_str(), needSoftKeyboard);

    std::lock_guard<std::mutex> lock(GetInstance().mutex_);

    auto it = nodeHandleMap_.find(nodeId);
    if (it != nodeHandleMap_.end()) {
        OH_ArkUI_XComponent_SetNeedSoftKeyboard(it->second, needSoftKeyboard);
    }

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value LumeXComponentManager::GetContext(napi_env env, napi_callback_info info)
{
    LOGI("GetContext");

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value LumeXComponentManager::Initialize(napi_env env, napi_callback_info info)
{
    LOGI("Initialize");

    size_t argCnt = 1;
    napi_value args[1] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);
    LOGI("Initialize nodeId: %s", nodeId.c_str());

    std::lock_guard<std::mutex> lock(GetInstance().mutex_);

    auto it = nodeHandleMap_.find(nodeId);
    if (it == nodeHandleMap_.end()) {
        LOGE("Node not found: %s", nodeId.c_str());
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }

    ArkUI_NodeHandle node = it->second;

    // Set auto initialize
    bool autoInitialize = true;
    OH_ArkUI_XComponent_SetAutoInitialize(node, autoInitialize);

    // Initialize XComponent
    OH_ArkUI_XComponent_Initialize(node);

    // Check initialization status
    bool isInitialized = false;
    OH_ArkUI_XComponent_IsInitialized(node, &isInitialized);

    LOGI("XComponent initialized: %d", isInitialized);

    // Optional: render first frame
    auto holderIt = surfaceHolderMap_.find(node);
    if (holderIt != surfaceHolderMap_.end()) {
        auto renderer = reinterpret_cast<LumeRenderer*>(OH_ArkUI_SurfaceHolder_GetUserData(holderIt->second));
        if (renderer && renderer->GetState() == RenderState::READY) {
            renderer->RenderFrame();
        }
    }

    napi_value result;
    napi_get_boolean(env, isInitialized, &result);
    return result;
}

napi_value LumeXComponentManager::Finalize(napi_env env, napi_callback_info info)
{
    LOGI("Finalize");

    size_t argCnt = 1;
    napi_value args[1] = {nullptr};

    if (napi_get_cb_info(env, info, &argCnt, args, nullptr, nullptr) != napi_ok) {
        LOGE("napi_get_cb_info failed");
        return nullptr;
    }

    std::string nodeId = NapiGetString(env, args[0]);
    LOGI("Finalize nodeId: %s", nodeId.c_str());

    std::lock_guard<std::mutex> lock(GetInstance().mutex_);

    auto it = nodeHandleMap_.find(nodeId);
    if (it == nodeHandleMap_.end()) {
        LOGE("Node not found: %s", nodeId.c_str());
        napi_value result;
        napi_get_boolean(env, false, &result);
        return result;
    }

    ArkUI_NodeHandle node = it->second;

    // Get renderer and cleanup
    auto holderIt = surfaceHolderMap_.find(node);
    if (holderIt != surfaceHolderMap_.end()) {
        auto renderer = reinterpret_cast<LumeRenderer*>(OH_ArkUI_SurfaceHolder_GetUserData(holderIt->second));
        if (renderer) {
            renderer->OnSurfaceDestroyed();
        }
    }

    // Finalize XComponent
    OH_ArkUI_XComponent_Finalize(node);

    LOGI("XComponent finalized: %s", nodeId.c_str());

    napi_value result;
    napi_get_boolean(env, true, &result);
    return result;
}

} // namespace LumeXComponent