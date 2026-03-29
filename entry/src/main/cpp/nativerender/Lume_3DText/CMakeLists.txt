# Copyright (c) 2024 Huawei Device Co., Ltd.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 3.18)

set(LUME_3DTEXT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(CORE_STATIC_PLUGIN_HEADER "\"${NATIVERENDER_ROOT_PATH}/LumeEngine/src/static_plugin_decl.h\"")

# ============================================================================
# Source files
# ============================================================================
set(LUME_3DTEXT_SOURCES
    version.cpp
    src/ecs/components/text_component_manager.cpp
    src/ecs/systems/text_system.cpp
    src/plugin/plugin.cpp
)

# ============================================================================
# Create static library: lume_3dtext_src
# ============================================================================
add_library(lume_3dtext_src STATIC ${LUME_3DTEXT_SOURCES})

target_compile_definitions(lume_3dtext_src PUBLIC
    __OHOS_PLATFORM__
    USE_STB_IMAGE=1
    TEXT3D_ENABLE_EXTRUDING=0
    CORE_PLUGIN=1
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=1
    CORE_STATIC_PLUGIN_HEADER=${CORE_STATIC_PLUGIN_HEADER}
)

target_include_directories(lume_3dtext_src PUBLIC
    ${LUME_3DTEXT_ROOT}/api
    ${LUME_3DTEXT_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/ecshelper
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/LumeFont/api
)

target_link_libraries(lume_3dtext_src PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
    lume_3d_src
    lume_font_src
)

# ============================================================================
# Create shared library: libPluginAGP3DText
# ============================================================================
add_library(libPluginAGP3DText SHARED
    $<TARGET_OBJECTS:lume_3dtext_src>
)

target_link_libraries(libPluginAGP3DText PUBLIC
    LumeBase
    libAGPEngine
    lume_render
    lume_3d
    libFont
)

target_include_directories(libPluginAGP3DText PUBLIC
    ${LUME_3DTEXT_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/LumeFont/api
)