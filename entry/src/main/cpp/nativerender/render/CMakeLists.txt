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

set(RENDER_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(RENDER_SOURCES
    EGLRender.cpp
    egl_core.cpp
    plugin_render.cpp
)

# ============================================================================
# Create static library
# ============================================================================
add_library(render STATIC ${RENDER_SOURCES})

# ============================================================================
# Include directories
# ============================================================================
target_include_directories(render PUBLIC
    ${RENDER_ROOT}
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/manager/include
)

# ============================================================================
# Find libraries
# ============================================================================
find_library(EGL-lib EGL)
find_library(GLES-lib GLESv3)
find_library(hilog-lib hilog_ndk.z)

# ============================================================================
# Link libraries
# ============================================================================
target_link_libraries(render PUBLIC
    ${EGL-lib}
    ${GLES-lib}
    ${hilog-lib}
    libnative_window.so
)