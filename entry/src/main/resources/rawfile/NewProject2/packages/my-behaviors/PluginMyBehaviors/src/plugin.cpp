/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2022-2022. All rights reserved.
 * Description: Plugin registration base for a behavior.
 */

#include <core/plugin/intf_plugin_decl.h>
#include <core/log.h>
#include "plugin_generated.h"

//
// Plugin specific callbacks.
//

namespace {

void Register(CORE_NS::IPluginRegister& pluginRegistry) {
 RegisterBehaviors(pluginRegistry);
}

void Unregister(CORE_NS::IPluginRegister& token) {
  UnregisterBehaviors(token);
}

} // namespace

//
// Plugin registration magic.
//

CORE_BEGIN_NAMESPACE()
class IPluginRegister;
class IInterfaceRegister;

#if defined(CORE_PLUGIN) && (CORE_PLUGIN == 1)
IPluginRegister* gPluginRegistry{ nullptr };
IPluginRegister& GetPluginRegister()
{
    return *gPluginRegistry;
}
#endif
CORE_END_NAMESPACE()

namespace PLUGIN_NS {
const char* GetVersionInfo()
{
    return PLUGIN_VERSION;
}

CORE_NS::PluginToken RegisterInterfaces(CORE_NS::IPluginRegister& pluginRegistry)
{
#if defined(CORE_PLUGIN) && (CORE_PLUGIN == 1)
    CORE_NS::gPluginRegistry = &pluginRegistry;
#endif
    CORE_LOG_I("Plugin Registered '%s'", PLUGIN_NAME);

    Register(pluginRegistry);
    return &pluginRegistry;
}

void UnregisterInterfaces(CORE_NS::PluginToken token)
{
    auto& pluginRegistry = *static_cast<CORE_NS::IPluginRegister*>(token);
    Unregister(pluginRegistry);
}
} // namespace PLUGIN_NS

namespace {
extern "C" {
PLUGIN_DATA(PLUGIN_NS){ { CORE_NS::IPlugin::UID }, PLUGIN_NAME, { UID_THIS_PLUGIN, PLUGIN_NS::GetVersionInfo },
    PLUGIN_NS::RegisterInterfaces, PLUGIN_NS::UnregisterInterfaces, BASE_NS::array_view<const BASE_NS::Uid>() };
DEFINE_STATIC_PLUGIN(PLUGIN_NS);
}
} // namespace
