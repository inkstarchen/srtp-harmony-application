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

set(LUME_FONT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(LUME_FONT_SOURCES
    version.cpp
    src/face_data.cpp
    src/font.cpp
    src/font_buffer.cpp
    src/font_data.cpp
    src/font_manager.cpp
    src/plugin/plugin.cpp
)

# ============================================================================
# Create static library: lume_font_src
# ============================================================================
add_library(lume_font_src STATIC ${LUME_FONT_SOURCES})

target_compile_definitions(lume_font_src PUBLIC
    CORE_PLUGIN=1
)

target_include_directories(lume_font_src PUBLIC
    ${LUME_FONT_ROOT}/api
    ${LUME_FONT_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/libfreetype/include
)

target_link_libraries(lume_font_src PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
    freetype
)

# ============================================================================
# Create static library: libFont
# ============================================================================
add_library(libFont STATIC
    $<TARGET_OBJECTS:lume_font_src>
)

target_include_directories(libFont PUBLIC
    ${LUME_FONT_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/libfreetype/include
)

target_link_libraries(libFont PUBLIC
    freetype
)