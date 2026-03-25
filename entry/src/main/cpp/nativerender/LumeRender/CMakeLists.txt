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
project(LumeRender)

set(LUME_RENDER_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# Build options
option(RENDER_LOG_ENABLED "Enable render logging" ON)
option(RENDER_VALIDATION_ENABLED "Enable render validation" OFF)
option(RENDER_BUILD_GLES "Build GLES backend" ON)

# Include directories
include_directories(
    ${LUME_RENDER_ROOT}
    ${LUME_RENDER_ROOT}/api
    ${LUME_RENDER_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)

# Common definitions
set(RENDER_DEFINITIONS
    RENDER_PUBLIC=
    RENDER_OPTIMIZE_FOR_INTEGRATED_GPU=1
    RENDER_DEV_ENABLED=0
    RENDER_PERF_ENABLED=0
    RENDER_TESTS_ENABLED=0
    RENDER_LOG_TO_CONSOLE=1
    RENDER_LOG_TO_FILE
    RENDER_LOG_TO_DEBUG_OUTPUT=0
    RENDER_DEBUG_GPU_RESOURCE_IDS=0
    RENDER_DEBUG_MARKERS_ENABLED=0
    RENDER_DEBUG_COMMAND_MARKERS_ENABLED=0
    RENDER_GL_FLIP_Y_SWAPCHAIN=0
    RENDER_GPU_TIMESTAMP_QUERIES_ENABLED=0
    RENDER_VULKAN_RT_ENABLED=0
    RENDER_EMBEDDED_ASSETS_ENABLED=1
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=1
    __OHOS_PLATFORM__
)

if(RENDER_BUILD_GLES)
    list(APPEND RENDER_DEFINITIONS RENDER_HAS_GLES_BACKEND=1)
endif()

if(RENDER_LOG_ENABLED)
    list(APPEND RENDER_DEFINITIONS
        PLUGIN_LOG_DISABLED=0
        PLUGIN_LOG_DEBUG=1
    )
else()
    list(APPEND RENDER_DEFINITIONS
        PLUGIN_LOG_DISABLED=1
        PLUGIN_LOG_DEBUG=0
    )
endif()

if(RENDER_VALIDATION_ENABLED)
    list(APPEND RENDER_DEFINITIONS
        RENDER_VALIDATION_ENABLED=1
        RENDER_VULKAN_VALIDATION_ENABLED=0
        RENDER_GL_DEBUG=1
    )
endif()

# Common source files
set(RENDER_SOURCES
    src/plugin/static_plugin.cpp
    src/plugin/static_registry.cpp
    src/plugin/registry_data.cpp
    src/renderer.cpp
    src/render_context.cpp
    src/render_graph.cpp
    src/resource_handle_impl.cpp
    src/default_engine_constants.h

    # datastore
    src/datastore/render_data_store_default_acceleration_structure_staging.cpp
    src/datastore/render_data_store_default_gpu_resource_data_copy.cpp
    src/datastore/render_data_store_default_staging.cpp
    src/datastore/render_data_store_manager.cpp
    src/datastore/render_data_store_pod.cpp
    src/datastore/render_data_store_post_process.cpp
    src/datastore/render_data_store_render_post_processes.cpp
    src/datastore/render_data_store_shader_passes.cpp

    # device
    src/device/device.cpp
    src/device/gpu_program_util.cpp
    src/device/gpu_resource_cache.cpp
    src/device/gpu_resource_handle_util.cpp
    src/device/gpu_resource_manager.cpp
    src/device/gpu_resource_util.cpp
    src/device/shader_manager.cpp
    src/device/shader_pipeline_binder.cpp
    src/device/shader_reflection_data.cpp

    # loader
    src/loader/pipeline_layout_loader.cpp
    src/loader/render_data_configuration_loader.cpp
    src/loader/render_data_loader.cpp
    src/loader/render_node_graph_loader.cpp
    src/loader/shader_data_loader.cpp
    src/loader/shader_loader.cpp
    src/loader/shader_state_loader.cpp
    src/loader/shader_state_loader_util.cpp
    src/loader/vertex_input_declaration_loader.cpp

    # node
    src/node/render_node_back_buffer.cpp
    src/node/render_node_bloom.cpp
    src/node/render_node_combined_post_process.cpp
    src/node/render_node_compute_generic.cpp
    src/node/render_node_create_gpu_buffers.cpp
    src/node/render_node_create_gpu_images.cpp
    src/node/render_node_default_acceleration_structure_staging.cpp
    src/node/render_node_end_frame_staging.cpp
    src/node/render_node_fullscreen_generic.cpp
    src/node/render_node_mip_chain_post_process.cpp
    src/node/render_node_render_post_processes_generic.cpp
    src/node/render_node_shader_passes_generic.cpp
    src/node/render_node_single_post_process.cpp
    src/node/render_node_staging.cpp
    src/node/render_staging.cpp

    # nodecontext
    src/nodecontext/node_context_descriptor_set_manager.cpp
    src/nodecontext/node_context_pso_manager.cpp
    src/nodecontext/pipeline_descriptor_set_binder.cpp
    src/nodecontext/render_barrier_list.cpp
    src/nodecontext/render_command_list.cpp
    src/nodecontext/render_node_context_manager.cpp
    src/nodecontext/render_node_copy_util.cpp
    src/nodecontext/render_node_graph_manager.cpp
    src/nodecontext/render_node_manager.cpp
    src/nodecontext/render_node_parser_util.cpp
    src/nodecontext/render_node_post_process_util.cpp
    src/nodecontext/render_node_util.cpp

    # perf
    src/perf/cpu_timer.cpp
    src/perf/gpu_query_manager.cpp

    # postprocesses
    src/postprocesses/render_post_process_bloom.cpp
    src/postprocesses/render_post_process_bloom_node.cpp
    src/postprocesses/render_post_process_blur.cpp
    src/postprocesses/render_post_process_blur_node.cpp
    src/postprocesses/render_post_process_combined.cpp
    src/postprocesses/render_post_process_combined_node.cpp
    src/postprocesses/render_post_process_dof.cpp
    src/postprocesses/render_post_process_dof_node.cpp
    src/postprocesses/render_post_process_flare.cpp
    src/postprocesses/render_post_process_flare_node.cpp
    src/postprocesses/render_post_process_fxaa.cpp
    src/postprocesses/render_post_process_fxaa_node.cpp
    src/postprocesses/render_post_process_motion_blur.cpp
    src/postprocesses/render_post_process_motion_blur_node.cpp
    src/postprocesses/render_post_process_taa.cpp
    src/postprocesses/render_post_process_taa_node.cpp
    src/postprocesses/render_post_process_upscale.cpp
    src/postprocesses/render_post_process_upscale_node.cpp

    # util
    src/util/json.cpp
    src/util/render_frame_util.cpp
    src/util/render_util.cpp
)

# OHOS platform sources
list(APPEND RENDER_SOURCES
    src/device/ohos/platform_hardware_buffer.cpp
)

# GLES backend sources
if(RENDER_BUILD_GLES)
    list(APPEND RENDER_SOURCES
        src/gles/gpu_buffer_gles.cpp
        src/gles/gpu_image_gles.cpp
        src/gles/gpu_program_gles.cpp
        src/gles/gpu_query_gles.cpp
        src/gles/gpu_resource_util_gles.cpp
        src/gles/gpu_sampler_gles.cpp
        src/gles/gpu_semaphore_gles.cpp
        src/gles/node_context_descriptor_set_manager_gles.cpp
        src/gles/node_context_pool_manager_gles.cpp
        src/gles/pipeline_state_object_gles.cpp
        src/gles/render_backend_gles.cpp
        src/gles/render_frame_sync_gles.cpp
        src/gles/shader_module_gles.cpp
        src/gles/spirv_cross_helpers_gles.cpp
        src/gles/swapchain_gles.cpp
        # GLES generic platform
        src/gles/generic/platform_device_gles.cpp
        # GLES OHOS platform
        src/gles/ohos/platform_device_gles.cpp
    )
endif()

# Dynamic plugin sources (for shared library)
set(RENDER_PLUGIN_SOURCES
    src/plugin/dynamic_plugin.cpp
    src/plugin/dynamic_registry.cpp
)

# Create static library for render sources
add_library(lume_render_src STATIC ${RENDER_SOURCES})
target_compile_definitions(lume_render_src PUBLIC ${RENDER_DEFINITIONS})
target_compile_options(lume_render_src PRIVATE
    -Wno-nullability-completeness
    -Wno-ignored-qualifiers
    -Wno-switch
)

# Add include directories for base and engine headers
target_include_directories(lume_render_src PUBLIC
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)

# Link LumeBase for header dependencies
target_link_libraries(lume_render_src PUBLIC LumeBase)

# Create static library for plugin sources
add_library(lume_render_src_plugin STATIC ${RENDER_PLUGIN_SOURCES})
target_compile_definitions(lume_render_src_plugin PRIVATE CORE_PLUGIN=1)
target_include_directories(lume_render_src_plugin PRIVATE
    ${LUME_RENDER_ROOT}
    ${LUME_RENDER_ROOT}/api
    ${LUME_RENDER_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)

# Link LumeBase for header dependencies
target_link_libraries(lume_render_src_plugin PRIVATE LumeBase)

# Find EGL and GLES libraries
find_library(EGL-lib EGL)
find_library(GLES-lib GLESv3)

# Create shared library
add_library(lume_render SHARED
    $<TARGET_OBJECTS:lume_render_src>
    $<TARGET_OBJECTS:lume_render_src_plugin>
)

target_link_libraries(lume_render PUBLIC
    ${EGL-lib}
    ${GLES-lib}
    LumeBase
)

# Linker flags for static plugin
if(NOT WIN32)
    target_link_options(lume_render PRIVATE
        "-Wl,--undefined=AGPRender_StaticPlugin"
    )
endif()

# Export include directories
target_include_directories(lume_render PUBLIC
    ${LUME_RENDER_ROOT}
    ${LUME_RENDER_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)