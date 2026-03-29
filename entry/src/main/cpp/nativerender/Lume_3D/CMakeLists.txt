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

set(LUME_3D_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(CORE_STATIC_PLUGIN_HEADER "\"${NATIVERENDER_ROOT_PATH}/LumeEngine/src/static_plugin_decl.h\"")

# Include directories
include_directories(
    ${LUME_3D_ROOT}
    ${LUME_3D_ROOT}/api
    ${LUME_3D_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)

# Common source files
set(LUME_3D_SOURCES
    version.cpp
    src/graphics_context.cpp

    # plugin
    src/plugin/static_plugin.cpp

    # ecs/components
    src/ecs/components/animation_component_manager.cpp
    src/ecs/components/animation_input_component_manager.cpp
    src/ecs/components/animation_output_component_manager.cpp
    src/ecs/components/animation_state_component_manager.cpp
    src/ecs/components/animation_track_component_manager.cpp
    src/ecs/components/camera_component_manager.cpp
    src/ecs/components/dynamic_environment_blender_manager.cpp
    src/ecs/components/environment_component_manager.cpp
    src/ecs/components/fog_component_manager.cpp
    src/ecs/components/graphics_state_component_manager.cpp
    src/ecs/components/initial_transform_component_manager.cpp
    src/ecs/components/joint_matrices_component_manager.cpp
    src/ecs/components/layer_component_manager.cpp
    src/ecs/components/light_component_manager.cpp
    src/ecs/components/local_matrix_component_manager.cpp
    src/ecs/components/material_component_manager.cpp
    src/ecs/components/mesh_component_manager.cpp
    src/ecs/components/morph_component_manager.cpp
    src/ecs/components/name_component_manager.cpp
    src/ecs/components/node_component_manager.cpp
    src/ecs/components/physical_camera_component_manager.cpp
    src/ecs/components/planar_reflection_component_manager.cpp
    src/ecs/components/post_process_component_manager.cpp
    src/ecs/components/post_process_configuration_component_manager.cpp
    src/ecs/components/previous_joint_matrices_component_manager.cpp
    src/ecs/components/reflection_probe_component_manager.cpp
    src/ecs/components/render_configuration_component_manager.cpp
    src/ecs/components/render_handle_component_manager.cpp
    src/ecs/components/render_mesh_batch_component_manager.cpp
    src/ecs/components/render_mesh_component_manager.cpp
    src/ecs/components/rsdz_model_id_component_manager.cpp
    src/ecs/components/skin_component_manager.cpp
    src/ecs/components/skin_ibm_component_manager.cpp
    src/ecs/components/skin_joints_component_manager.cpp
    src/ecs/components/transform_component_manager.cpp
    src/ecs/components/uri_component_manager.cpp
    src/ecs/components/water_ripple_component_manager.cpp
    src/ecs/components/weather_component_manager.cpp
    src/ecs/components/world_matrix_component_manager.cpp

    # ecs/systems
    src/ecs/systems/animation_playback.cpp
    src/ecs/systems/animation_system.cpp
    src/ecs/systems/local_matrix_system.cpp
    src/ecs/systems/morphing_system.cpp
    src/ecs/systems/node_system.cpp
    src/ecs/systems/render_preprocessor_system.cpp
    src/ecs/systems/render_system.cpp
    src/ecs/systems/skinning_system.cpp
    src/ecs/systems/weather_system.cpp

    # gltf
    src/gltf/gltf2.cpp
    src/gltf/gltf2_exporter.cpp
    src/gltf/gltf2_importer.cpp
    src/gltf/gltf2_loader.cpp
    src/gltf/gltf2_util.cpp

    # property
    src/property/property_handle.cpp

    # render/datastore
    src/render/datastore/render_data_store_default_camera.cpp
    src/render/datastore/render_data_store_default_light.cpp
    src/render/datastore/render_data_store_default_material.cpp
    src/render/datastore/render_data_store_default_scene.cpp
    src/render/datastore/render_data_store_morph.cpp
    src/render/datastore/render_data_store_weather.cpp

    # render/node
    src/render/node/render_node_camera_single_post_process.cpp
    src/render/node/render_node_camera_weather.cpp
    src/render/node/render_node_create_default_camera_gpu_images.cpp
    src/render/node/render_node_default_cameras.cpp
    src/render/node/render_node_default_camera_controller.cpp
    src/render/node/render_node_default_camera_post_process_controller.cpp
    src/render/node/render_node_default_depth_render_slot.cpp
    src/render/node/render_node_default_env.cpp
    src/render/node/render_node_default_environment_blender.cpp
    src/render/node/render_node_default_lights.cpp
    src/render/node/render_node_default_material_deferred_shading.cpp
    src/render/node/render_node_default_material_objects.cpp
    src/render/node/render_node_default_material_render_slot.cpp
    src/render/node/render_node_default_shadows_blur.cpp
    src/render/node/render_node_default_shadow_render_slot.cpp
    src/render/node/render_node_generics.cpp
    src/render/node/render_node_morph.cpp
    src/render/node/render_node_weather_simulation.cpp
    src/render/render_node_scene_util.cpp

    # util
    src/util/json.cpp
    src/util/mesh_builder.cpp
    src/util/mesh_util.cpp
    src/util/picking.cpp
    src/util/property_util.cpp
    src/util/render_util.cpp
    src/util/scene_util.cpp
    src/util/uri_lookup.cpp
)

# Dynamic plugin sources (for shared library)
set(LUME_3D_PLUGIN_SOURCES
    src/plugin/dynamic_plugin.cpp
    src/plugin/dynamic_registry.cpp
)

# Create static library for 3D sources
add_library(lume_3d_src STATIC ${LUME_3D_SOURCES})
target_compile_definitions(lume_3d_src PUBLIC
    CORE_STATIC_PLUGIN_HEADER=${CORE_STATIC_PLUGIN_HEADER}
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=1
)

# Add include directories for dependencies
target_include_directories(lume_3d_src PUBLIC
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/assets
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/ecshelper
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/src
    ${NATIVERENDER_ROOT_PATH}/LumeRender
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/src
)

# Link dependencies
target_link_libraries(lume_3d_src PUBLIC LumeBase lume_engine_src lume_render_src)

# Create static library for plugin sources
add_library(lume_3d_src_plugin STATIC ${LUME_3D_PLUGIN_SOURCES})
target_compile_definitions(lume_3d_src_plugin PRIVATE CORE_PLUGIN=1)
target_include_directories(lume_3d_src_plugin PRIVATE
    ${LUME_3D_ROOT}
    ${LUME_3D_ROOT}/api
    ${LUME_3D_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)

# Link dependencies for plugin
target_link_libraries(lume_3d_src_plugin PRIVATE LumeBase lume_engine_src)

# Create shared library
add_library(lume_3d SHARED
    $<TARGET_OBJECTS:lume_3d_src>
    $<TARGET_OBJECTS:lume_3d_src_plugin>
)

target_link_libraries(lume_3d PUBLIC
    LumeBase
    libAGPEngine
    lume_render
)

# Export include directories
target_include_directories(lume_3d PUBLIC
    ${LUME_3D_ROOT}
    ${LUME_3D_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)