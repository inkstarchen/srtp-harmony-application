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
#include <3d/implementation_uids.h>
#include <3d/namespace.h>
#include <render/implementation_uids.h>

// Forward declaration of RegisterStaticPlugin function
CORE_BEGIN_NAMESPACE()
namespace StaticPluginRegistry {
void RegisterStaticPlugin(const CORE_NS::IPlugin& plugin);
}
class IPluginRegister;
CORE_END_NAMESPACE()

CORE3D_BEGIN_NAMESPACE()
CORE_NS::PluginToken RegisterInterfaces3D(CORE_NS::IPluginRegister&);
void UnregisterInterfaces3D(CORE_NS::PluginToken);
const char* GetVersionInfo();
CORE3D_END_NAMESPACE()

// Plugin dependencies
constexpr BASE_NS::Uid PLUGIN_DEPENDENCIES[] = { RENDER_NS::UID_RENDER_PLUGIN };

// Define plugin data with external linkage (no anonymous namespace, no static)
extern "C" const CORE_NS::IPlugin AGP3D_pluginData = {
    { CORE_NS::IPlugin::UID },
    // name of plugin.
    "AGP 3D (core)",
    // Version information of the plugin.
    { CORE3D_NS::UID_3D_PLUGIN, CORE3D_NS::GetVersionInfo },
    CORE3D_NS::RegisterInterfaces3D,
    CORE3D_NS::UnregisterInterfaces3D,
    { PLUGIN_DEPENDENCIES },
};

// Registration function with external linkage
extern "C" void AGP3D_RegisterStaticPlugin()
{
    CORE_NS::StaticPluginRegistry::RegisterStaticPlugin(AGP3D_pluginData);
}
