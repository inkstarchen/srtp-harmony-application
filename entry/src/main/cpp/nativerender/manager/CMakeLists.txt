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
    src/lume_xcomponent_manager.cpp
    src/lume_renderer.cpp
    # src/lume_scene_context.cpp  # Removed: scene management is now handled by LumeCommon
)

# ============================================================================
# Create shared library
# ============================================================================
add_library(manager SHARED ${LUME_XCOMPONENT_SOURCES})

# ============================================================================
# Compile definitions
# ============================================================================
target_compile_definitions(manager PUBLIC
    __OHOS_PLATFORM__
    OHOS_PLATFORM
    CORE_HAS_GLES_BACKEND=1
    # Use runtime registration approach for static plugins
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=0
    # Engine library names (required by LoadEngineLib)
    LIB_ENGINE_CORE=AGPEngine
    LIB_RENDER=AGPRender
    LIB_CORE3D=AGPCore3D
)

# ============================================================================
# Include directories
# ============================================================================
target_include_directories(manager PUBLIC
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
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/custom
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
# Allow multiple definitions since lume_engine_src is linked by multiple libraries
# and libAGPEngine contains the same code
target_link_options(manager PRIVATE "-Wl,--allow-multiple-definition")

target_link_libraries(manager PUBLIC
    render
    # Lume engine libraries
    LumeBase

    # lume_render and lume_3D are shared libraries that already contain
    # libAGPEngine with whole-archive. They provide GetPluginRegister() and
    # the static plugin registration.
    lume_render
    lume_3d

    libMetaObject
    EcsSerializer
    libPluginSceneWidget

    # 3d_widget_adapter (contains LumeCommon and Lume implementation)
    widget_adapter_src

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