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

#ifndef OHOS_RENDER_3D_TEXTURE_INFO_H
#define OHOS_RENDER_3D_TEXTURE_INFO_H

#include <cstdint>

namespace OHOS::Render3D {

/**
 * @brief Texture/Window information for rendering.
 *
 * In XComponent mode, nativeWindow_ is provided by XComponent callback.
 * textureId_ is deprecated and should be 0.
 */
struct TextureInfo {
    uint32_t width_ = 0U;
    uint32_t height_ = 0U;
    uint32_t textureId_ = 0U;  // Deprecated: Always 0 in XComponent mode
    void* nativeWindow_ = nullptr;
    float widthScale_ = 1.0f;
    float heightScale_ = 1.0f;
    float customRatio_ = 0.1f;
    bool recreateWindow_ = true;
};

} // namespace OHOS::Render3D
#endif // OHOS_RENDER_3D_TEXTURE_INFO_H