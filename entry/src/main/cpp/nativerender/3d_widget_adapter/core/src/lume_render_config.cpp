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

#include <sstream>
#include <string>

#include "lume_render_config.h"

namespace OHOS::Render3D {
LumeRenderConfig& LumeRenderConfig::GetInstance()
{
    static LumeRenderConfig renderConfig;

    if (!renderConfig.initialized_) {
        renderConfig.renderBackend_ = "gles";  // Vulkan disabled - default to GLES

        renderConfig.systemGraph_ = "rofs3D://systemGraph.json";

        renderConfig.initialized_ = true;
    }

    return renderConfig;
}

} // namespace OHOS::Render3D
