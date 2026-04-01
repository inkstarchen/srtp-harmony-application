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

set(WIDGET_ADAPTER_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Configuration definitions
# ============================================================================
set(MULTI_ECS_UPDATE_AT_ONCE 0)
set(UNIFY_RENDER 1)
set(DBG_DRAW_PIXEL 0)
set(WIDGET_TRACE_ENABLE 1)

# ============================================================================
# Source files
# ============================================================================
set(WIDGET_ADAPTER_CORE_SOURCES
    core/src/engine_factory.cpp
    core/src/lume/custom/lume_custom_render.cpp
    core/src/lume/custom/shader_input_buffer.cpp
    core/src/lume/lume_common.cpp
    core/src/lume_render_config.cpp
)

set(WIDGET_ADAPTER_OHOS_SOURCES
    core/src/lume/ohos/lume.cpp
    src/ohos/graphics_manager.cpp
)

set(WIDGET_ADAPTER_COMMON_SOURCES
    src/graphics_manager_common.cpp
    src/offscreen_context_helper.cpp
    src/widget_adapter.cpp
)

set(WIDGET_ADAPTER_SOURCES
    ${WIDGET_ADAPTER_CORE_SOURCES}
    ${WIDGET_ADAPTER_OHOS_SOURCES}
    ${WIDGET_ADAPTER_COMMON_SOURCES}
)

# ============================================================================
# Create static library: widget_adapter_src
# ============================================================================
add_library(widget_adapter_src STATIC ${WIDGET_ADAPTER_SOURCES})

target_compile_definitions(widget_adapter_src PUBLIC
    __OHOS_PLATFORM__
    # CORE_DYNAMIC=1 removed - use static linking mode
    CORE_HAS_GLES_BACKEND=1
    CORE_HAS_VULKAN_BACKEND=1
    MULTI_ECS_UPDATE_AT_ONCE=${MULTI_ECS_UPDATE_AT_ONCE}
    UNIFY_RENDER=${UNIFY_RENDER}
    DBG_DRAW_PIXEL=${DBG_DRAW_PIXEL}
    WIDGET_TRACE_ENABLE=${WIDGET_TRACE_ENABLE}
    EGL_EGLEXT_PROTOTYPES
    # GL_GLEXT_PROTOTYPES removed - we use function pointers via eglGetProcAddress instead
    # This prevents function declaration conflicts with our function pointer declarations
    # Use runtime registration approach for static plugins
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=0
    # Engine library names (required by LoadEngineLib)
    LIB_ENGINE_CORE=AGPEngine
    LIB_RENDER=AGPRender
    LIB_CORE3D=AGPCore3D
)

target_include_directories(widget_adapter_src PUBLIC
    ${WIDGET_ADAPTER_ROOT}/include
    ${WIDGET_ADAPTER_ROOT}/include/ohos
    ${WIDGET_ADAPTER_ROOT}/core/include
    ${WIDGET_ADAPTER_ROOT}/core/include/lume
    ${WIDGET_ADAPTER_ROOT}/core/include/lume/ohos
    ${WIDGET_ADAPTER_ROOT}/core/include/ohos
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/platform/ohos
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/gltf
    ${NATIVERENDER_ROOT_PATH}/LumeJpg/api
    ${NATIVERENDER_ROOT_PATH}/LumeJpg/src
    ${NATIVERENDER_ROOT_PATH}/LumePng/api
    ${NATIVERENDER_ROOT_PATH}/LumePng/src
    ${NATIVERENDER_ROOT_PATH}/securec/include
)

find_library(
    hilog-lib
    hilog_ndk.z
)

find_library(
    libace-lib
    ace_ndk.z
)

find_library(
    libnapi-lib
    ace_napi.z
)

find_library(
    libuv-lib
    uv
)

find_library(
    EGL-lib
    EGL
)

find_library(
    GLES-lib
    GLESv3
)

find_library(
    libnative_window-lib
    native_window
)

find_library(
    rawfile-lib
    rawfile.z
)

target_link_libraries(widget_adapter_src PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
    lume_3d_src
    lume_jpg_src
    lume_png_src
    securec
    libPluginSceneWidget  # Provides GetPluginRegister() in static linking mode
    ${hilog-lib}
    ${libace-lib}
    ${libnapi-lib}
    ${libuv-lib}
    ${EGL-lib}
    ${GLES-lib}
    ${libnative_window-lib}
    ${rawfile-lib}  # OHOS RawFile API (OH_ResourceManager_*)
)

# ============================================================================
# Create shared library: lib3dWidgetAdapter
# ============================================================================
add_library(lib3dWidgetAdapter SHARED
    $<TARGET_OBJECTS:widget_adapter_src>
)

# Allow multiple definitions for json functions (also defined in libAGPEngine and other libs)
target_link_options(lib3dWidgetAdapter PRIVATE "-Wl,--allow-multiple-definition")

target_link_libraries(lib3dWidgetAdapter PUBLIC
    LumeBase
    lume_render  # lume_render already contains libAGPEngine with whole-archive
    lume_3d

    # Link static libraries with whole-archive to ensure GetAGPRenderPlugin/GetAGP3DPlugin are available
    "-Wl,--whole-archive"
    lume_render_src
    lume_3d_src
    "-Wl,--no-whole-archive"

    lume_jpg_src
    lume_png_src
    turbojpeg_static
    png_static
    ${hilog-lib}
    ${rawfile-lib}  # OHOS RawFile API (OH_ResourceManager_*)
)

target_include_directories(lib3dWidgetAdapter PUBLIC
    ${WIDGET_ADAPTER_ROOT}/include
    ${WIDGET_ADAPTER_ROOT}/core/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
)