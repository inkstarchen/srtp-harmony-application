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

set(LUME_RENDER_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(CORE_STATIC_PLUGIN_HEADER "\"${NATIVERENDER_ROOT_PATH}/LumeEngine/src/static_plugin_decl.h\"")

# Build options
option(RENDER_LOG_ENABLED "Enable render logging" ON)
option(RENDER_BUILD_GLES "Build GLES backend" ON)
option(RENDER_EMBEDDED_ASSETS_ENABLED "Enable embedded assets for render" ON)

# Include directories
include_directories(
    ${LUME_RENDER_ROOT}
    ${LUME_RENDER_ROOT}/api
    ${LUME_RENDER_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)

if(RENDER_BUILD_GLES)
    list(APPEND RENDER_DEFINITIONS RENDER_HAS_GLES_BACKEND=1)
endif()

# ============================================================================
# 【嵌入式资产配置】
# ============================================================================
#
# 预编译资产文件配置
#
# 符号名称:
#   - BINARYDATAFORRENDER: 指向资产数据的指针
#   - SIZEOFDATAFORRENDER: 资产数据的大小
#
# 协议名称:
#   - rofsRndr:// 用于访问嵌入的渲染资产
#
# 使用方式:
#   1. 使用 LumeAssetCompiler 编译 assets/render 目录:
#      LumeAssetCompiler -arch aarch64 assets/render output_dir BINARYDATAFORRENDER SIZEOFDATAFORRENDER
#   2. 将生成的 .o 文件放到 assets/ 目录下，命名为 rofs_render_64.o (64位) 或 rofs_render_32.o (32位)
#
set(RENDER_ROFS "rofsRndr")
set(RENDER_ASSET_OBJECT "${LUME_RENDER_ROOT}/assets/rofsrender_64.o")

# 打印配置信息
if(RENDER_EMBEDDED_ASSETS_ENABLED)
    if(EXISTS "${RENDER_ASSET_OBJECT}")
        message(STATUS "LumeRender: Using embedded assets from ${RENDER_ASSET_OBJECT}")
    else()
        message(WARNING "LumeRender: Embedded assets enabled but file not found: ${RENDER_ASSET_OBJECT}")
    endif()
endif()

# Common source files
set(RENDER_SOURCES
    version.cpp
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
    src/node/core_render_node_factory.cpp
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
    src/nodecontext/render_node_graph_share_manager.cpp
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
    src/util/property_util.cpp
    src/util/render_frame_util.cpp
    src/util/render_util.cpp
    src/util/shader_saver.cpp
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api/core/property_tools/property_data.cpp

    # plugin - static registration (now compiled as separate files)
    src/plugin/static_plugin.cpp
    src/plugin/static_registry.cpp
    src/plugin/registry_data.cpp
)

# OHOS platform sources
list(APPEND RENDER_SOURCES
    src/device/ohos/platform_hardware_buffer.cpp
)

# GLES backend sources
if(RENDER_BUILD_GLES)
    list(APPEND RENDER_SOURCES
        src/gles/device_gles.cpp
        src/gles/egl_state.cpp
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
        # GLES OHOS platform
        src/gles/ohos/platform_device_gles.cpp
    )
endif()

# Dynamic plugin sources (for shared library)
# Note: dynamic_registry.cpp removed - InitRegistry is already defined in static_registry.cpp
# which is compiled in lume_render_src. Both cannot be linked together.
set(RENDER_PLUGIN_SOURCES
    src/plugin/dynamic_plugin.cpp
    # src/plugin/dynamic_registry.cpp  # Removed - conflicts with static_registry.cpp
)

# ============================================================================
# 库构建
# ============================================================================
# 【重要】使用 OBJECT 库而不是 STATIC 库
# OBJECT 库只编译源文件为 .o 文件，不打包成 .a 存档
# 这样 $<TARGET_OBJECTS:...> 生成器表达式才能正确工作

# Create OBJECT library for render sources (not STATIC!)
add_library(lume_render_src OBJECT ${RENDER_SOURCES})
target_compile_definitions(lume_render_src PUBLIC
    ${RENDER_DEFINITIONS}
    CORE_STATIC_PLUGIN_HEADER=${CORE_STATIC_PLUGIN_HEADER}
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=0
    # 【重要】启用嵌入式资产宏
    # 这会使 static_plugin.cpp 中的 #if (RENDER_EMBEDDED_ASSETS_ENABLED == 1) 生效
    RENDER_EMBEDDED_ASSETS_ENABLED=1
)

# Add include directories for base and engine headers
target_include_directories(lume_render_src PUBLIC
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)

# OBJECT 库不能直接链接其他库，只能继承 include 目录和编译定义
# 依赖的链接在最终的 SHARED 库层面完成

# ============================================================================
# 【关键】创建 IMPORTED OBJECT 库包含预编译的 rofs_render_64.o
# ============================================================================
# CMake 的 target_sources 无法正确处理预编译的 .o 文件
# 正确方式：创建 IMPORTED OBJECT 库，通过 IMPORTED_OBJECTS 属性指定 .o 文件
#
if(RENDER_EMBEDDED_ASSETS_ENABLED AND EXISTS "${RENDER_ASSET_OBJECT}")
    # 创建 IMPORTED OBJECT 库来包含预编译的资产文件
    add_library(lume_render_rofs OBJECT IMPORTED GLOBAL)
    set_target_properties(lume_render_rofs PROPERTIES
        IMPORTED_OBJECTS "${RENDER_ASSET_OBJECT}"
    )
    message(STATUS "LumeRender: Creating IMPORTED OBJECT library for embedded assets: ${RENDER_ASSET_OBJECT}")
else()
    message(WARNING "LumeRender: Embedded assets enabled but object file not found: ${RENDER_ASSET_OBJECT}")
endif()

# Create OBJECT library for plugin sources
add_library(lume_render_src_plugin OBJECT ${RENDER_PLUGIN_SOURCES})
target_compile_definitions(lume_render_src_plugin PRIVATE CORE_PLUGIN=1)
target_include_directories(lume_render_src_plugin PRIVATE
    ${LUME_RENDER_ROOT}
    ${LUME_RENDER_ROOT}/api
    ${LUME_RENDER_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)

# Find EGL and GLES libraries
find_library(EGL-lib EGL)
find_library(GLES-lib GLESv3)
find_library(hilog-lib hilog_ndk.z)
find_library(rawfile-lib rawfile.z)

# ============================================================================
# 创建共享库
# ============================================================================
# 使用 $<TARGET_OBJECTS:...> 将 OBJECT 库的所有 .o 文件链接到共享库
# 【关键】rofs_render_64.o 必须在其他对象之后链接
# 这样链接器能从前面的对象找到符号定义
if(RENDER_EMBEDDED_ASSETS_ENABLED AND EXISTS "${RENDER_ASSET_OBJECT}")
    add_library(lume_render SHARED
        $<TARGET_OBJECTS:lume_render_src>
        $<TARGET_OBJECTS:lume_render_src_plugin>
        $<TARGET_OBJECTS:lume_render_rofs>  # 添加预编译的资产文件
    )
else()
    add_library(lume_render SHARED
        $<TARGET_OBJECTS:lume_render_src>
        $<TARGET_OBJECTS:lume_render_src_plugin>
    )
endif()

# Allow multiple definitions for json functions (also defined in libAGPEngine)
target_link_options(lume_render PRIVATE "-Wl,--allow-multiple-definition")

target_link_libraries(lume_render PUBLIC
    ${EGL-lib}
    ${GLES-lib}
    ${hilog-lib}
    ${rawfile-lib}
    libnative_buffer.so
    libnative_window.so
    LumeBase
    lume_engine_src
    # Link libAGPEngine with whole-archive so that RegisterStaticPlugin and
    # static plugin constructors are linked together
    "-Wl,--whole-archive"
    libAGPEngine
    "-Wl,--no-whole-archive"
)

# Export include directories
target_include_directories(lume_render PUBLIC
    ${LUME_RENDER_ROOT}
    ${LUME_RENDER_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)