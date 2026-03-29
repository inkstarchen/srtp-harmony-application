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

set(LUME_XCOMPONENT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(LUME_XCOMPONENT_SOURCES
    src/lume_renderer.cpp
    src/lume_scene_context.cpp
    src/lume_xcomponent_manager.cpp
)

# ============================================================================
# Create shared library
# ============================================================================
add_library(lume_xcomponent SHARED ${LUME_XCOMPONENT_SOURCES})

# ============================================================================
# Compile definitions
# ============================================================================
target_compile_definitions(lume_xcomponent PUBLIC
    __OHOS_PLATFORM__
    OHOS_PLATFORM
    # CORE_DYNAMIC=1 removed - we link against libPluginSceneWidget which provides the actual functions
    CORE_HAS_GLES_BACKEND=1
)

# ============================================================================
# Include directories
# ============================================================================
target_include_directories(lume_xcomponent PUBLIC
    ${LUME_XCOMPONENT_ROOT}/include

    # Lume engine headers
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/platform/ohos
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/LumeMeta/include
    ${NATIVERENDER_ROOT_PATH}/LumeScene/include
    ${NATIVERENDER_ROOT_PATH}/LumeJpg/api
    ${NATIVERENDER_ROOT_PATH}/LumePng/api
    ${NATIVERENDER_ROOT_PATH}/LumeFont/api

    # Adapter headers
    ${NATIVERENDER_ROOT_PATH}/3d_scene_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/ohos
)

# ============================================================================
# Find libraries
# ============================================================================
find_library(EGL-lib EGL)
find_library(GLES-lib GLESv3)
find_library(hilog-lib hilog_ndk.z)
find_library(libace-lib ace_ndk.z)
find_library(libnapi-lib ace_napi.z)
find_library(libuv-lib uv)
find_library(rawfile-lib rawfile.z)  # OHOS RawFile API for resource access

# ============================================================================
# Link libraries
# ============================================================================
target_link_libraries(lume_xcomponent PUBLIC
    # Lume engine libraries
    LumeBase
    libAGPEngine
    lume_engine_src
    lume_render_src
    lume_3d_src
    libMetaObject
    EcsSerializer
    libPluginSceneWidget

    # Image loader plugins (for PNG/JPG support)
    lume_jpg_src
    lume_png_src
    turbojpeg_static
    png_static

    # System libraries
    ${EGL-lib}
    ${GLES-lib}
    ${hilog-lib}
    ${libace-lib}
    ${libnapi-lib}
    ${libuv-lib}
    ${rawfile-lib}  # OHOS RawFile API (OH_ResourceManager_*)
    libnative_window.so
)