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

#ifndef LUME_XCOMPONENT_TYPES_H
#define LUME_XCOMPONENT_TYPES_H

#include <cstdint>
#include <string>
#include <functional>

namespace LumeXComponent {

/**
 * @brief Render state enumeration
 */
enum class RenderState {
    UNINITIALIZED = 0,
    INITIALIZING,
    READY,
    RENDERING,
    ERROR,
    DESTROYED
};

/**
 * @brief Window information structure
 */
struct WindowInfo {
    void* nativeWindow = nullptr;
    uint32_t width = 0;
    uint32_t height = 0;
    float scaleX = 1.0f;
    float scaleY = 1.0f;
};

/**
 * @brief Render configuration structure
 */
struct RenderConfig {
    int32_t depthBits = 24;
    int32_t stencilBits = 8;
    bool sRGB = true;
    bool enableVSync = true;
};

/**
 * @brief Touch event types
 */
enum class TouchEventType : int32_t {
    DOWN = 0,
    UP = 1,
    MOVE = 2,
    CANCEL = 3
};

/**
 * @brief Touch event data
 */
struct TouchEvent {
    float x = 0.0f;
    float y = 0.0f;
    int32_t id = 0;
    TouchEventType type = TouchEventType::DOWN;
};

/**
 * @brief Render callback type
 */
using RenderCallback = std::function<void()>;

/**
 * @brief Touch callback type
 */
using TouchCallback = std::function<void(const TouchEvent&)>;

/**
 * @brief Scene load callback type
 */
using SceneLoadCallback = std::function<void(bool success)>;

} // namespace LumeXComponent

#endif // LUME_XCOMPONENT_TYPES_H