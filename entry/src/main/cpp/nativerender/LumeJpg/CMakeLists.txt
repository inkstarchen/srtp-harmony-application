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

set(LUMEJPG_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(LUMEJPG_SOURCES
    src/component_dll.cpp
    src/jpg/image_loader_jpg.cpp
)

# ============================================================================
# Create static library: lume_jpg_src
# ============================================================================
add_library(lume_jpg_src STATIC ${LUMEJPG_SOURCES})

target_compile_definitions(lume_jpg_src PUBLIC
    __OHOS_PLATFORM__
    CORE_PLUGIN=1
)

target_include_directories(lume_jpg_src PUBLIC
    ${LUMEJPG_ROOT}/api
    ${LUMEJPG_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/third_party/libjpeg-turbo-3.1.0
    ${NATIVERENDER_ROOT_PATH}/third_party/libjpeg-turbo-3.1.0/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/platform/ohos
)

target_link_libraries(lume_jpg_src PUBLIC
    LumeBase
    lume_engine_src
    turbojpeg_static
)

# ============================================================================
# Create shared library: libJPGPlugin
# ============================================================================
add_library(libJPGPlugin SHARED
    $<TARGET_OBJECTS:lume_jpg_src>
)

target_link_libraries(libJPGPlugin PUBLIC
    LumeBase
    libAGPEngine
    turbojpeg_static
    ${hilog-lib}
)

target_include_directories(libJPGPlugin PUBLIC
    ${LUMEJPG_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)