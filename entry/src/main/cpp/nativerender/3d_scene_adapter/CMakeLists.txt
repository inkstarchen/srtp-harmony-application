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

set(SCENE_ADAPTER_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(SCENE_ADAPTER_SOURCES
    src/scene_adapter.cpp
    src/scene_bridge.cpp
)

# ============================================================================
# Create static library: scene_adapter_src
# ============================================================================
add_library(scene_adapter_src STATIC ${SCENE_ADAPTER_SOURCES})

target_compile_definitions(scene_adapter_src PUBLIC
    __OHOS_PLATFORM__
    __SCENE_ADAPTER__
    CORE_DYNAMIC=1
    CORE_HAS_GLES_BACKEND=1
    CORE_HAS_VULKAN_BACKEND=1
)

target_include_directories(scene_adapter_src PUBLIC
    ${SCENE_ADAPTER_ROOT}/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/ohos
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/ohos
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/platform/ohos
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/gltf
    ${NATIVERENDER_ROOT_PATH}/LumeMeta/include
    ${NATIVERENDER_ROOT_PATH}/LumeEcsSerializer/EcsSerializer/include
    ${NATIVERENDER_ROOT_PATH}/LumeScene/include
    ${NATIVERENDER_ROOT_PATH}/LumeJpg/api
    ${NATIVERENDER_ROOT_PATH}/LumePng/api
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

target_link_libraries(scene_adapter_src PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
    lume_3d_src
    lume_meta_src
    lume_scene_src
    ecs_serializer_src
    runtime_utils_src
    widget_adapter_src
    lume_jpg_src
    lume_png_src
    securec
    ${hilog-lib}
    ${libace-lib}
    ${libnapi-lib}
    ${libuv-lib}
    ${EGL-lib}
    ${GLES-lib}
    ${libnative_window-lib}
)

# ============================================================================
# Create shared library: lib3dSceneAdapter
# ============================================================================
add_library(lib3dSceneAdapter SHARED
    $<TARGET_OBJECTS:scene_adapter_src>
)

target_link_libraries(lib3dSceneAdapter PUBLIC
    LumeBase
    libAGPEngine
    lume_render
    lume_3d
    libMetaObject
    EcsSerializer
    libPluginSceneWidget
    lib3dWidgetAdapter
    ${hilog-lib}
    ${libnapi-lib}
)

target_include_directories(lib3dSceneAdapter PUBLIC
    ${SCENE_ADAPTER_ROOT}/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/LumeMeta/include
    ${NATIVERENDER_ROOT_PATH}/LumeEcsSerializer/EcsSerializer/include
    ${NATIVERENDER_ROOT_PATH}/LumeScene/include
)