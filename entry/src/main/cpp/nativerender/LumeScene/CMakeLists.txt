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

set(LUME_SCENE_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(CORE_STATIC_PLUGIN_HEADER "\"${NATIVERENDER_ROOT_PATH}/LumeEngine/src/static_plugin_decl.h\"")

# ============================================================================
# Source files
# ============================================================================
set(LUME_SCENE_SOURCES
    # asset
    src/asset/asset_object.cpp

    # component
    src/component/animation_component.cpp
    src/component/camera_component.cpp
    src/component/environment_component.cpp
    src/component/generic_component.cpp
    src/component/layer_component.cpp
    src/component/light_component.cpp
    src/component/material_component.cpp
    src/component/mesh_component.cpp
    src/component/node_component.cpp
    src/component/postprocess_component.cpp
    # src/component/text_component.cpp    # Temporarily disabled (LumeFont/Lume_3DText disabled)
    src/component/transform_component.cpp

    # core
    src/core/camera.cpp
    src/core/ecs.cpp
    src/core/ecs_listener.cpp
    src/core/ecs_object.cpp
    src/core/internal_scene.cpp

    # ecs_component
    src/ecs_component/entity_owner_component_manager.cpp

    # mesh
    src/mesh/mesh.cpp
    src/mesh/mesh_creator.cpp
    src/mesh/sampler.cpp
    src/mesh/submesh.cpp
    src/mesh/texture.cpp

    # node
    src/node/camera_node.cpp
    src/node/light_node.cpp
    src/node/mesh_node.cpp
    src/node/node.cpp
    src/node/startable_handler.cpp
    # src/node/text_node.cpp    # Temporarily disabled (LumeFont/Lume_3DText disabled)

    # postprocess
    src/postprocess/bloom.cpp
    src/postprocess/postprocess.cpp
    src/postprocess/tonemap.cpp

    # resource
    src/resource/ecs_animation.cpp
    src/resource/environment.cpp
    src/resource/image.cpp
    src/resource/material.cpp
    src/resource/render_resource.cpp
    src/resource/render_resource_manager.cpp
    src/resource/resource_types.cpp
    src/resource/shader.cpp

    # resource/types
    src/resource/types/animation_type.cpp
    src/resource/types/environment_type.cpp
    src/resource/types/gltf_scene_type.cpp
    src/resource/types/image_type.cpp
    src/resource/types/material_type.cpp
    src/resource/types/postprocess_type.cpp
    src/resource/types/scene_type.cpp
    src/resource/types/shader_type.cpp

    # serialization
    src/serialization/scene_exporter.cpp
    src/serialization/scene_importer.cpp

    # core sources
    src/plugin.cpp
    src/register_anys.cpp
    src/register_engine_access.cpp
    src/register_serializers.cpp
    src/render_configuration.cpp
    src/scene.cpp
    src/scene_manager.cpp
)

# ============================================================================
# Create static library: lume_scene_src
# ============================================================================
add_library(lume_scene_src STATIC ${LUME_SCENE_SOURCES})

target_compile_definitions(lume_scene_src PUBLIC
    __OHOS_PLATFORM__
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=0
    CORE_STATIC_PLUGIN_HEADER=${CORE_STATIC_PLUGIN_HEADER}
)

target_include_directories(lume_scene_src PUBLIC
    ${LUME_SCENE_ROOT}/include
    ${LUME_SCENE_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/ecshelper
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    # ${NATIVERENDER_ROOT_PATH}/LumeFont/api        # Temporarily disabled
    # ${NATIVERENDER_ROOT_PATH}/Lume_3DText/api     # Temporarily disabled
    ${NATIVERENDER_ROOT_PATH}/LumeMeta/include
    ${NATIVERENDER_ROOT_PATH}/LumeEcsSerializer/EcsSerializer/include
    ${NATIVERENDER_ROOT_PATH}/LumeEcsSerializer/Util/include
)

target_link_libraries(lume_scene_src PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
    lume_3d_src
    # lume_font_src       # Temporarily disabled
    # lume_3dtext_src     # Temporarily disabled
    lume_meta_src
    ecs_serializer_src
    runtime_utils_src
)

# ============================================================================
# Create shared library: libPluginSceneWidget
# ============================================================================
add_library(libPluginSceneWidget SHARED
    $<TARGET_OBJECTS:lume_scene_src>
)

# Allow multiple definitions for json functions (also defined in libAGPEngine and other libs)
target_link_options(libPluginSceneWidget PRIVATE "-Wl,--allow-multiple-definition")

target_link_libraries(libPluginSceneWidget PUBLIC
    LumeBase
    lume_render  # lume_render already contains libAGPEngine with whole-archive
    lume_3d
    # libFont               # Temporarily disabled
    # libPluginAGP3DText    # Temporarily disabled
    libMetaObject
    EcsSerializer
)

target_include_directories(libPluginSceneWidget PUBLIC
    ${LUME_SCENE_ROOT}/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    # ${NATIVERENDER_ROOT_PATH}/LumeFont/api        # Temporarily disabled
    # ${NATIVERENDER_ROOT_PATH}/Lume_3DText/api     # Temporarily disabled
    ${NATIVERENDER_ROOT_PATH}/LumeMeta/include
)