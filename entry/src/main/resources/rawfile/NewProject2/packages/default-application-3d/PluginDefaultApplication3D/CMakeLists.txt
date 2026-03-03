#
# Copyright (C) 2023 Huawei Technologies Co, Ltd.
#

find_package(DefaultApplication3D REQUIRED GLOBAL)

# This package will just use the binary provided by the SDK directly and does not contain the library itself.

# Pass the plugin binary location to the runtime.
set_property(GLOBAL APPEND PROPERTY APP_PLUGIN_BINARIES $<TARGET_FILE:PluginDefaultApplication3D>)
