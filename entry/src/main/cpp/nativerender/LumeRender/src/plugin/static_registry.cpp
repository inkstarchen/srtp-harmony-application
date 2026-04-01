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

#include <core/namespace.h>
#include <core/plugin/intf_plugin.h>

// Forward declaration of RegisterStaticPlugin function
CORE_BEGIN_NAMESPACE()
namespace StaticPluginRegistry {
void RegisterStaticPlugin(const CORE_NS::IPlugin& plugin);
}
class IPluginRegister;
CORE_END_NAMESPACE()

// Plugin data defined in registry_data.cpp (compiled separately)
extern "C" const CORE_NS::IPlugin AGPRender_pluginData;

// Store plugin registry pointer for GetPluginRegister() access
namespace {
static CORE_NS::IPluginRegister* gPluginRegistry { nullptr };
} // namespace

// Provide GetPluginRegister() for this module
CORE_BEGIN_NAMESPACE()
IPluginRegister& GetPluginRegister()
{
    return *gPluginRegistry;
}
CORE_END_NAMESPACE()

extern "C" void InitRegistry(CORE_NS::IPluginRegister& pluginRegistry)
{
    // Save plugin registry pointer for GetPluginRegister() access
    gPluginRegistry = &pluginRegistry;

    // Register the plugin using data from registry_data.cpp
    CORE_NS::StaticPluginRegistry::RegisterStaticPlugin(AGPRender_pluginData);
}
