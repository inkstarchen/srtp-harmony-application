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

# ============================================================================
# 基础配置
# ============================================================================
set(LUME_3D_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(CORE_STATIC_PLUGIN_HEADER "\"${NATIVERENDER_ROOT_PATH}/LumeEngine/src/static_plugin_decl.h\"")

# ============================================================================
# 【重要】嵌入式资产开关
# ============================================================================
# CORE3D_EMBEDDED_ASSETS_ENABLED: 是否将资产编译嵌入到二进制文件中
# - true: 资产文件会被编译成.o文件，直接链接到库中
# - false: 资产文件在运行时从文件系统加载
#
# 当启用时，需要通过 lumeassetcompiler 工具将资产编译成目标文件
set(CORE3D_EMBEDDED_ASSETS_ENABLED true)

# Include directories
include_directories(
    ${LUME_3D_ROOT}
    ${LUME_3D_ROOT}/api
    ${LUME_3D_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)

# ============================================================================
# 源文件定义
# ============================================================================
# Common source files
set(LUME_3D_SOURCES
    version.cpp
    src/graphics_context.cpp

    # plugin
    src/plugin/static_plugin.cpp
    src/plugin/static_registry.cpp
    src/plugin/registry_data.cpp

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
# Note: dynamic_registry.cpp removed - InitRegistry is already defined in static_registry.cpp
set(LUME_3D_PLUGIN_SOURCES
    src/plugin/dynamic_plugin.cpp
    # src/plugin/dynamic_registry.cpp  # Removed - conflicts with static_registry.cpp
)

# ============================================================================
# 【核心】嵌入式资产编译流程
# ============================================================================
#
# 整体流程图：
#
#   ┌─────────────────────────────────────────────────────────────────┐
#   │                    资产编译与链接流程                             │
#   └─────────────────────────────────────────────────────────────────┘
#
#   第一步：构建资产编译工具
#   ┌─────────────────────────────────────────────────────────────────┐
#   │  LumeBinaryCompile/lumeassetcompiler/                           │
#   │         ↓                                                       │
#   │  add_subdirectory() 编译 LumeAssetCompiler 可执行文件            │
#   │         ↓                                                       │
#   │  生成: LumeAssetCompiler (主机工具，在构建机器上运行)             │
#   └─────────────────────────────────────────────────────────────────┘
#
#   第二步：编译资产文件
#   ┌─────────────────────────────────────────────────────────────────┐
#   │  assets/3d/                    (资产源文件目录)                   │
#   │    ├── shaders/                                                 │
#   │    ├── shaderstates/                                            │
#   │    ├── pipelinelayouts/                                         │
#   │    └── ...                                                      │
#   │         ↓                                                       │
#   │  LumeAssetCompiler -arm64-v8a assets/3d output_dir \            │
#   │                    BINARY_DATA_FOR_3D SIZE_OF_DATA_FOR_3D       │
#   │         ↓                                                       │
#   │  生成: rofs3D_64.o  (ELF目标文件，包含资产数据的二进制blob)       │
#   └─────────────────────────────────────────────────────────────────┘
#
#   第三步：链接到库
#   ┌─────────────────────────────────────────────────────────────────┐
#   │  target_sources(lume_3d PRIVATE "${CORE3D_ASSET_OBJECT}")       │
#   │         ↓                                                       │
#   │  将 rofs3D_64.o 链接到 lume_3d 共享库                            │
#   │         ↓                                                       │
#   │  导出符号:                                                       │
#   │    - BINARY_DATA_FOR_3D: 指向资产数据的指针                      │
#   │    - SIZE_OF_DATA_FOR_3D: 资产数据的大小                         │
#   └─────────────────────────────────────────────────────────────────┘
#
#   第四步：运行时使用
#   ┌─────────────────────────────────────────────────────────────────┐
#   │  graphics_context.cpp:                                          │
#   │    fileManager.RegisterFilesystem("rofs3D",                     │
#   │        fileManager.CreateROFilesystem(                          │
#   │            BINARY_DATA_FOR_3D,    // 资产数据指针                │
#   │            SIZE_OF_DATA_FOR_3D    // 资产数据大小                │
#   │        ));                                                      │
#   │         ↓                                                       │
#   │  创建 rofs3D:// 协议，可以像文件系统一样访问嵌入的资产            │
#   └─────────────────────────────────────────────────────────────────┘
#
# ============================================================================
# if(CORE3D_EMBEDDED_ASSETS_ENABLED)

#     # ------------------------------------------------------------------------
#     # 变量定义
#     # ------------------------------------------------------------------------
#     # CORE3D_ROFS: 只读文件系统的协议名称，用于运行时访问资产
#     #   例如: "rofs3D" -> 在代码中使用 "rofs3D://shaders/xxx.shader" 访问
#     set(CORE3D_ROFS "rofs3D")

#     # CORE3D_ASSETS_DIR: 资产源文件目录
#     #   这个目录下的文件会被打包进目标文件
#     set(CORE3D_ASSETS_DIR "${LUME_3D_ROOT}/assets/3d")

#     # CORE3D_GENERATED_DIR: 生成的目标文件输出目录
#     #   编译后的 .o 文件会放在这里
    # set(CORE3D_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated/assets")

#     # ------------------------------------------------------------------------
#     # 第一步：配置资产编译工具
#     # ------------------------------------------------------------------------
#     # LumeAssetCompiler 是一个主机工具(在构建机器上运行)
#     # 它读取资产文件并生成包含二进制数据的目标文件(.o)
#     #
#     # 工具位置: nativerender/LumeBinaryCompile/lumeassetcompiler/
#     set(LUME_ASSET_COMPILER_DIR "${NATIVERENDER_ROOT_PATH}/LumeBinaryCompile/lumeassetcompiler")
#     set(LUME_ASSET_COMPILER_BUILD_DIR "${CMAKE_BINARY_DIR}/LumeBinaryCompile/lumeassetcompiler")

#     # 构建资产编译工具
#     # 这会编译 LumeAssetCompiler 可执行文件
#     if(EXISTS "${LUME_ASSET_COMPILER_DIR}/CMakeLists.txt")
#         # add_subdirectory 会编译工具到构建目录
#         add_subdirectory("${LUME_ASSET_COMPILER_DIR}" "${LUME_ASSET_COMPILER_BUILD_DIR}")

#         # $<TARGET_FILE:LumeAssetCompiler> 是生成器表达式
#         # 在构建时展开为可执行文件的完整路径
#         set(LUME_ASSET_COMPILER "$<TARGET_FILE:LumeAssetCompiler>")
#     endif()

#     # ------------------------------------------------------------------------
#     # 第二步：确定目标架构
#     # ------------------------------------------------------------------------
#     # 根据目标架构选择正确的输出文件名
#     # 不同架构需要不同的目标文件格式(ELF32/ELF64)
#     #
#     # 输出文件命名规则:
#     #   - rofs3D_64.o: 用于64位架构 (arm64-v8a, x86_64)
#     #   - rofs3D_32.o: 用于32位架构 (armeabi-v7a, x86)
#     #
#     # CMAKE_SYSTEM_PROCESSOR 由CMake自动设置，表示目标处理器架构
#     if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
#         # ARM 64位架构 (鸿蒙设备常用)
#         set(ASSET_ARCH_FLAGS "-arm64-v8a")
#         set(ASSET_OBJ_NAME "${CORE3D_ROFS}_64.o")
#     elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
#         # x86 64位架构 (模拟器或PC)
#         set(ASSET_ARCH_FLAGS "-x86_64")
#         set(ASSET_OBJ_NAME "${CORE3D_ROFS}_64.o")
#     elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "i686|x86")
#         # x86 32位架构
#         set(ASSET_ARCH_FLAGS "-x86")
#         set(ASSET_OBJ_NAME "${CORE3D_ROFS}_32.o")
#     elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
#         # ARM 32位架构
#         set(ASSET_ARCH_FLAGS "-armeabi-v7a")
#         set(ASSET_OBJ_NAME "${CORE3D_ROFS}_32.o")
#     else()
#         # 默认使用64位
#         set(ASSET_ARCH_FLAGS "-x86_64")
#         set(ASSET_OBJ_NAME "${CORE3D_ROFS}_64.o")
#     endif()

#     # 目标文件的完整路径
#     # 例如: build/nativerender/Lume_3D/generated/assets/rofs3D_64.o
    set(CORE3D_ASSET_OBJECT "${LUME_3D_ROOT}/assets/rofs3D_64.o")

#     # ------------------------------------------------------------------------
#     # 第三步：定义资产编译命令
#     # ------------------------------------------------------------------------
#     # add_custom_command 定义如何生成目标文件
#     # 只有当输出文件不存在或依赖项改变时才会执行
#     add_custom_command(
#         # OUTPUT: 命令生成的输出文件
#         OUTPUT "${CORE3D_ASSET_OBJECT}"

#         # COMMAND 1: 创建输出目录
#         COMMAND ${CMAKE_COMMAND} -E make_directory "${CORE3D_GENERATED_DIR}"

#         # COMMAND 2: 运行资产编译工具
#         # 参数说明:
#         #   ${ASSET_ARCH_FLAGS}      : 目标架构标志，如 "-arm64-v8a"
#         #   "${CORE3D_ASSETS_DIR}"   : 输入目录，资产源文件位置
#         #   "${CORE3D_GENERATED_DIR}": 输出目录，生成的文件位置
#         #   "BINARY_DATA_FOR_3D"     : 导出的数据符号名称
#         #   "SIZE_OF_DATA_FOR_3D"    : 导出的大小符号名称
#         #   "-extensions"            : 要包含的文件扩展名列表
#         #
#         # LumeAssetCompiler 会在输出目录生成:
#         #   - rofs3D_64.o (ELF目标文件)
#         #
#         # 生成的目标文件包含两个导出符号:
#         #   extern "C" const uint8_t* const BINARY_DATA_FOR_3D;  // 资产数据指针
#         #   extern "C" const size_t SIZE_OF_DATA_FOR_3D;         // 资产数据大小
#         COMMAND ${LUME_ASSET_COMPILER}
#                 ${ASSET_ARCH_FLAGS}
#                 "${CORE3D_ASSETS_DIR}"
#                 "${CORE3D_GENERATED_DIR}"
#                 "BINARY_DATA_FOR_3D"
#                 "SIZE_OF_DATA_FOR_3D"
#                 "-extensions" ".spv;.json;.lsb;.shader;.shadergs;.shadervid;.shaderpl;.rng;.gl;.gles"

#         # DEPENDS: 此命令依赖于 LumeAssetCompiler 工具
#         # 如果工具被重新编译，资产也会重新编译
#         DEPENDS LumeAssetCompiler

#         # WORKING_DIRECTORY: 命令执行的工作目录
#         WORKING_DIRECTORY "${LUME_3D_ROOT}"

#         # COMMENT: 构建时显示的消息
#         COMMENT "Compiling 3D assets with lumeassetcompiler for ${CMAKE_SYSTEM_PROCESSOR}"

#         # VERBATIM: 确保参数被正确传递，不做额外的转义
#         VERBATIM
#     )

#     # ------------------------------------------------------------------------
#     # 创建自定义目标
#     # ------------------------------------------------------------------------
#     # add_custom_target 创建一个顶层目标，确保资产编译总是被执行
#     # ALL 表示这个目标会在默认构建中被构建
#     add_custom_target(lume_3d_assets ALL
#         DEPENDS "${CORE3D_ASSET_OBJECT}"
#     )

#     # 打印配置信息，帮助调试
#     message(STATUS "Embedded assets enabled: ${CORE3D_ASSETS_DIR} -> ${CORE3D_ASSET_OBJECT}")
# endif()

# ============================================================================
# 库构建
# ============================================================================
# 【重要】使用 OBJECT 库而不是 STATIC 库
# OBJECT 库只编译源文件为 .o 文件，不打包成 .a 存档
# 这样 $<TARGET_OBJECTS:...> 生成器表达式才能正确工作

# Create OBJECT library for 3D sources (not STATIC!)
add_library(lume_3d_src OBJECT ${LUME_3D_SOURCES})

# 编译定义
target_compile_definitions(lume_3d_src PUBLIC
    CORE_STATIC_PLUGIN_HEADER=${CORE_STATIC_PLUGIN_HEADER}
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=0
    # 【重要】启用嵌入式资产宏
    # 这会使 graphics_context.cpp 中的 #if (CORE3D_EMBEDDED_ASSETS_ENABLED == 1) 生效
    CORE3D_EMBEDDED_ASSETS_ENABLED=1
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

# OBJECT 库不能直接链接其他库，只能继承 include 目录和编译定义
# 依赖的链接在最终的 SHARED 库层面完成

# ============================================================================
# 【关键】创建 IMPORTED OBJECT 库包含预编译的 rofs_64.o
# ============================================================================
# CMake 的 target_sources 无法正确处理预编译的 .o 文件
# 正确方式：创建 IMPORTED OBJECT 库，通过 IMPORTED_OBJECTS 属性指定 .o 文件
#
if(CORE3D_EMBEDDED_ASSETS_ENABLED AND EXISTS "${CORE3D_ASSET_OBJECT}")
    # 创建 IMPORTED OBJECT 库来包含预编译的资产文件
    add_library(lume_3d_rofs OBJECT IMPORTED GLOBAL)
    set_target_properties(lume_3d_rofs PROPERTIES
        IMPORTED_OBJECTS "${CORE3D_ASSET_OBJECT}"
    )
    message(STATUS "Creating IMPORTED OBJECT library for embedded assets: ${CORE3D_ASSET_OBJECT}")
else()
    message(WARNING "Embedded assets enabled but object file not found: ${CORE3D_ASSET_OBJECT}")
endif()

# Create OBJECT library for plugin sources
add_library(lume_3d_src_plugin OBJECT ${LUME_3D_PLUGIN_SOURCES})
target_compile_definitions(lume_3d_src_plugin PRIVATE CORE_PLUGIN=1)
target_include_directories(lume_3d_src_plugin PRIVATE
    ${LUME_3D_ROOT}
    ${LUME_3D_ROOT}/api
    ${LUME_3D_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)

# ============================================================================
# 创建共享库
# ============================================================================
# 使用 $<TARGET_OBJECTS:...> 将 OBJECT 库的所有 .o 文件链接到共享库
# 【关键】rofs_64.o 必须在 graphics_context.cpp.o 之后链接
# 这样链接器能从前面的对象找到符号定义
if(CORE3D_EMBEDDED_ASSETS_ENABLED AND EXISTS "${CORE3D_ASSET_OBJECT}")
    add_library(lume_3d SHARED
        $<TARGET_OBJECTS:lume_3d_src>
        $<TARGET_OBJECTS:lume_3d_src_plugin>
        $<TARGET_OBJECTS:lume_3d_rofs>  # 添加预编译的资产文件
    )
else()
    add_library(lume_3d SHARED
        $<TARGET_OBJECTS:lume_3d_src>
        $<TARGET_OBJECTS:lume_3d_src_plugin>
    )
endif()

# Allow multiple definitions for json functions (also defined in libAGPEngine)
target_link_options(lume_3d PRIVATE "-Wl,--allow-multiple-definition")

target_link_libraries(lume_3d PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
    lume_render  # lume_render already contains libAGPEngine with whole-archive
)

# Export include directories
target_include_directories(lume_3d PUBLIC
    ${LUME_3D_ROOT}
    ${LUME_3D_ROOT}/api
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)