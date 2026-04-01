/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#include <core/plugin/intf_plugin.h>
#include <render/implementation_uids.h>
#include <render/namespace.h>

// Forward declaration of RegisterStaticPlugin function
CORE_BEGIN_NAMESPACE()
namespace StaticPluginRegistry {
void RegisterStaticPlugin(const CORE_NS::IPlugin& plugin);
}
class IPluginRegister;
CORE_END_NAMESPACE()

RENDER_BEGIN_NAMESPACE()
const char* GetVersionInfo();
CORE_NS::PluginToken RegisterInterfaces(CORE_NS::IPluginRegister&);
void UnregisterInterfaces(CORE_NS::PluginToken);
RENDER_END_NAMESPACE()

// Define plugin data with external linkage (no anonymous namespace, no static)
extern "C" const CORE_NS::IPlugin AGPRender_pluginData = {
    { CORE_NS::IPlugin::UID },
    // name of plugin.
    "AGP Render",
    // Version information of the plugin.
    { RENDER_NS::UID_RENDER_PLUGIN, RENDER_NS::GetVersionInfo },
    RENDER_NS::RegisterInterfaces,
    RENDER_NS::UnregisterInterfaces,
    {},
};

// Registration function with external linkage
extern "C" void AGPRender_RegisterStaticPlugin()
{
    CORE_NS::StaticPluginRegistry::RegisterStaticPlugin(AGPRender_pluginData);
}
