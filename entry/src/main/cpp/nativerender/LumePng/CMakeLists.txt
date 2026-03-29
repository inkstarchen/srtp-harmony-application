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

set(LUMEPNG_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(LUMEPNG_SOURCES
    src/component_dll.cpp
    src/png/image_loader_png.cpp
)

# ============================================================================
# Create static library: lume_png_src
# ============================================================================
add_library(lume_png_src STATIC ${LUMEPNG_SOURCES})

target_compile_definitions(lume_png_src PUBLIC
    __OHOS_PLATFORM__
    CORE_PLUGIN=1
)

target_include_directories(lume_png_src PUBLIC
    ${LUMEPNG_ROOT}/api
    ${LUMEPNG_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/third_party/libpng-1.6.44
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/platform/ohos
)

target_link_libraries(lume_png_src PUBLIC
    LumeBase
    lume_engine_src
    png_static
)

# ============================================================================
# Create shared library: libPNGPlugin
# ============================================================================
add_library(libPNGPlugin SHARED
    $<TARGET_OBJECTS:lume_png_src>
)

target_link_libraries(libPNGPlugin PUBLIC
    LumeBase
    libAGPEngine
    png_static
    ${hilog-lib}
)

target_include_directories(libPNGPlugin PUBLIC
    ${LUMEPNG_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)