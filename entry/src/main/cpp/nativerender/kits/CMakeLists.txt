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

set(KITS_JS_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(KITS_JS_SOURCES
    src/AnimationJS.cpp
    src/ArrayPropertyProxy.cpp
    src/BaseObjectJS.cpp
    src/BloomJS.cpp
    src/CameraJS.cpp
    src/ColorProxy.cpp
    src/DisposeContainer.cpp
    src/EnvironmentJS.cpp
    src/GeometryJS.cpp
    src/geometry_definition/CubeJS.cpp
    src/geometry_definition/CustomJS.cpp
    src/geometry_definition/GeometryDefinition.cpp
    src/geometry_definition/PlaneJS.cpp
    src/geometry_definition/SphereJS.cpp
    src/ImageJS.cpp
    src/JsObjectCache.cpp
    src/LightJS.cpp
    src/MaterialJS.cpp
    src/MaterialPropertyJS.cpp
    src/MeshJS.cpp
    src/MeshResourceJS.cpp
    src/MorpherJS.cpp
    src/napi/array.cpp
    src/napi/env.cpp
    src/napi/function.cpp
    src/napi/object.cpp
    src/napi/strong_ref.cpp
    src/napi/utils.cpp
    src/napi/value.cpp
    src/napi/weak_ref.cpp
    src/native_module_export.cpp
    src/NodeImpl.cpp
    src/NodeJS.cpp
    src/nodejstaskqueue.cpp
    src/ParamParsing.cpp
    src/PostProcJS.cpp
    src/Promise.cpp
    src/PropertyProxy.cpp
    src/QuatProxy.cpp
    src/Raycast.cpp
    src/register_module.cpp
    src/RenderContextJS.cpp
    src/SamplerJS.cpp
    src/SceneComponentJS.cpp
    src/SceneJS.cpp
    src/SceneResourceImpl.cpp
    src/ShaderJS.cpp
    src/SubMeshJS.cpp
    src/TextNodeJS.cpp
    src/ToneMapJS.cpp
    src/TrueRootObject.cpp
    src/Vec2Proxy.cpp
    src/Vec3Proxy.cpp
    src/Vec4Proxy.cpp
)

# ============================================================================
# Create static library: kits_js_src
# ============================================================================
add_library(kits_js_src STATIC ${KITS_JS_SOURCES})

target_compile_definitions(kits_js_src PUBLIC
    __OHOS_PLATFORM__
    __SCENE_ADAPTER__
    CORE_HAS_GLES_BACKEND=1
    CORE_HAS_VULKAN_BACKEND=1
)

target_include_directories(kits_js_src PUBLIC
    ${KITS_JS_ROOT}/include
    ${KITS_JS_ROOT}/include/napi
    ${KITS_JS_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos
    ${NATIVERENDER_ROOT_PATH}/3d_scene_adapter/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/platform/ohos
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/LumeMeta/include
    ${NATIVERENDER_ROOT_PATH}/LumeScene/include
    ${NATIVERENDER_ROOT_PATH}/LumeEcsSerializer/EcsSerializer/include
    ${NATIVERENDER_ROOT_PATH}/LumeEcsSerializer/Util/include
    ${NATIVERENDER_ROOT_PATH}/LumeFont/api
)

find_library(hilog-lib hilog_ndk.z)
find_library(libnapi-lib ace_napi.z)
find_library(libuv-lib uv)

target_link_libraries(kits_js_src PUBLIC
    LumeBase
    scene_adapter_src
    widget_adapter_src
    ${hilog-lib}
    ${libnapi-lib}
    ${libuv-lib}
)

# ============================================================================
# Create shared library: libscene
# ============================================================================
add_library(libscene SHARED
    $<TARGET_OBJECTS:kits_js_src>
)

target_link_libraries(libscene PUBLIC
    LumeBase
    lib3dSceneAdapter
    ${hilog-lib}
)

target_include_directories(libscene PUBLIC
    ${KITS_JS_ROOT}/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
)