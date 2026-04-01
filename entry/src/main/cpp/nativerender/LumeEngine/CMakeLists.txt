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

set(LUME_ENGINE_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# Build options
option(CORE_LOG_ENABLED "Enable core logging" ON)
# option(CORE_DEV_ENABLED "Enable dev mode" OFF)
option(USE_STB_IMAGE "Use stb image" ON)
# option(USE_LIB_PNG_JPEG "Use lib png jpeg" OFF)
option(LUME_OHOS_BUILD "Build for OHOS platform" ON)
option(CORE_EMBEDDED_ASSETS_ENABLED "Enable embedded assets for core engine" ON)

# Set library names
set(LIB_ENGINE_CORE "AGPEngine")
set(LIB_RENDER "AGPRender")
set(LIB_CORE3D "AGPCore3D")
set(CORE_ROFS "rofs")

# ============================================================================
# 【嵌入式资产配置】
# ============================================================================
#
# 预编译资产文件配置
#
# 符号名称:
#   - BINARYDATAFORCORE: 指向核心资产数据的指针
#   - SIZEOFDATAFORCORE: 核心资产数据的大小
#
# 协议名称:
#   - corerofs:// 用于访问嵌入的核心资产
#   - engine:// 映射到 corerofs://core/
#
# 依赖关系:
#   shaders:// → engine://shaders/
#   engine:// → corerofs://core/
#
# 使用方式:
#   1. 使用 LumeAssetCompiler 编译资产目录:
#      LumeAssetCompiler -arch aarch64 assets/core output_dir BINARYDATAFORCORE SIZEOFDATAFORCORE
#   2. 将生成的 .o 文件放到 assets/ 目录下，命名为 rofs_core_64.o (64位)
#
set(CORE_ASSET_OBJECT "${LUME_ENGINE_ROOT}/assets/rofscore_64.o")

# 打印配置信息
if(CORE_EMBEDDED_ASSETS_ENABLED)
    if(EXISTS "${CORE_ASSET_OBJECT}")
        message(STATUS "LumeEngine: Using embedded assets from ${CORE_ASSET_OBJECT}")
    else()
        message(WARNING "LumeEngine: Embedded assets enabled but file not found: ${CORE_ASSET_OBJECT}")
    endif()
else()
    message(STATUS "LumeEngine: Embedded assets disabled")
endif()

# ============================================================================
# Config: lume_base_api
# ============================================================================
set(LUME_BASE_API_INCLUDE_DIRS
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
)


# ============================================================================
# Config: lume_engine_api
# ============================================================================
set(LUME_ENGINE_API_INCLUDE_DIRS
    ${LUME_ENGINE_ROOT}/api
)

# ============================================================================
# Config: ecshelper
# ============================================================================
set(LUME_COMPONENT_HELP_INCLUDE_DIRS
    ${LUME_ENGINE_ROOT}/ecshelper
)

# ============================================================================
# Config: lume_default
# ============================================================================

list(APPEND LUME_DEFAULT_DEFINITIONS
    LIB_ENGINE_CORE=${LIB_ENGINE_CORE}
    LIB_RENDER=${LIB_RENDER}
    LIB_CORE3D=${LIB_CORE3D}
)

# ============================================================================
# Config: lume_engine_config
# ============================================================================
# External paths - adjust these to your project structure
set(LUME_CORE_PATH ${NATIVERENDER_ROOT_PATH}/LumeEngine)
# set(STB_IMAGE_PATH ${NATIVERENDER_ROOT_PATH}/3rdparty/stb)

set(LUME_ENGINE_CONFIG_INCLUDE_DIRS
    # ${LUME_CORE_PATH}/3rdparty/
    ${LUME_CORE_PATH}/src/
    # ${LUME_CORE_PATH}/asserts/
    # ${STB_IMAGE_PATH}
)


# ============================================================================
# Source files for lume_engine_src
# ============================================================================
set(LUME_ENGINE_SOURCES
    src/ecs/ecs.cpp
    src/ecs/entity_manager.cpp
    src/ecs/entity_manager.h
    src/engine.cpp
    src/engine.h
    src/engine_factory.cpp
    src/engine_factory.h
    src/image/image_loader_manager.cpp
    src/image/image_loader_manager.h
    src/image/loaders/gl_util.h
    src/image/loaders/image_loader_ktx.cpp
    src/image/loaders/image_loader_ktx.h
    src/io/dev/file_monitor.cpp
    src/io/dev/file_monitor.h
    src/io/filesystem_api.cpp
    src/io/file_manager.cpp
    src/io/file_manager.h
    src/io/memory_file.cpp
    src/io/memory_file.h
    src/io/memory_filesystem.cpp
    src/io/memory_filesystem.h
    src/io/path_tools.cpp
    src/io/path_tools.h
    src/io/proxy_directory.cpp
    src/io/proxy_directory.h
    src/io/proxy_filesystem.cpp
    src/io/proxy_filesystem.h
    src/io/rofs_filesystem.cpp
    src/io/rofs_filesystem.h
    src/io/std_directory.cpp
    src/io/std_directory.h
    src/io/std_file.cpp
    src/io/std_file.h
    src/io/std_filesystem.cpp
    src/io/std_filesystem.h
    src/loader/json_util.h
    src/loader/system_graph_loader.cpp
    src/loader/system_graph_loader.h
    src/log/logger.cpp
    src/log/logger.h
    src/log/logger_output.cpp
    src/log/logger_output.h
    src/os/intf_library.h
    src/os/platform.h
    src/perf/performance_data_manager.cpp
    src/perf/performance_data_manager.h
    src/plugin_registry.cpp
    src/plugin_registry.h
    src/static_plugin_decl.h
    src/threading/dispatcher_impl.cpp
    src/threading/dispatcher_impl.h
    src/threading/dispatcher_task_queue.cpp
    src/threading/dispatcher_task_queue.h
    src/threading/parallel_impl.cpp
    src/threading/parallel_impl.h
    src/threading/parallel_task_queue.cpp
    src/threading/parallel_task_queue.h
    src/threading/sequential_impl.cpp
    src/threading/sequential_impl.h
    src/threading/sequential_task_queue.cpp
    src/threading/sequential_task_queue.h
    src/threading/task_queue.cpp
    src/threading/task_queue.h
    src/threading/task_queue_factory.cpp
    src/threading/task_queue_factory.h
    src/util/frustum_util.cpp
    src/util/frustum_util.h
    src/util/linear_allocator.h
    src/util/string_util.h
    src/version.cpp

    # ecshelper
    ecshelper/ComponentTools/component_query.cpp
)

# OHOS platform sources
if(LUME_OHOS_BUILD)
    list(APPEND LUME_ENGINE_SOURCES
        src/os/ohos/library_ohos.cpp
        src/os/ohos/library_ohos.h
        src/os/ohos/logger_output.cpp
        src/os/ohos/ohos_file.cpp
        src/os/ohos/ohos_file.h
        src/os/ohos/ohos_filesystem.cpp
        src/os/ohos/ohos_filesystem.h
        src/os/ohos/platform_ohos.cpp
        src/os/ohos/platform_ohos.h
    )
endif()

# STB image sources
if(USE_STB_IMAGE)
    list(APPEND LUME_ENGINE_SOURCES
        src/image/loaders/image_loader_stb_image.cpp
        src/image/loaders/image_loader_stb_image.h
    )
endif()

# ============================================================================
# 库构建
# ============================================================================
# 【重要】使用 OBJECT 库而不是 STATIC 库
# OBJECT 库只编译源文件为 .o 文件，不打包成 .a 存档
# 这样 $<TARGET_OBJECTS:...> 生成器表达式才能正确工作

# Create OBJECT library for engine sources (not STATIC!)
add_library(lume_engine_src OBJECT ${LUME_ENGINE_SOURCES})

target_include_directories(lume_engine_src PUBLIC
    ${LUME_ENGINE_CONFIG_INCLUDE_DIRS}
    ${LUME_ENGINE_API_INCLUDE_DIRS}
    ${LUME_BASE_API_INCLUDE_DIRS}
    ${LUME_COMPONENT_HELP_INCLUDE_DIRS}
)

target_compile_definitions(lume_engine_src PUBLIC
    ${LUME_ENGINE_CONFIG_DEFINITIONS}
    ${LUME_ENGINE_API_DEFINITIONS}
    ${LUME_BASE_API_DEFINITIONS}
    ${LUME_DEFAULT_DEFINITIONS}
    __OHOS_PLATFORM__
    CORE_PLUGIN=1
    # Use runtime registration approach (not compiler-generated sections)
    # This must match the approach used by lume_render_src and lume_3d_src
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=0
    # 【重要】启用嵌入式资产宏
    # 这会使 engine.cpp 中的 #if (CORE_EMBEDDED_ASSETS_ENABLED == 1) 生效
    CORE_EMBEDDED_ASSETS_ENABLED=1
)

# OBJECT 库不能直接链接其他库，只能继承 include 目录和编译定义
# 依赖的链接在最终的库层面完成

# ============================================================================
# 【关键】创建 IMPORTED OBJECT 库包含预编译的 rofs_core_64.o
# ============================================================================
# CMake 的 target_sources 无法正确处理预编译的 .o 文件
# 正确方式：创建 IMPORTED OBJECT 库，通过 IMPORTED_OBJECTS 属性指定 .o 文件
#
if(CORE_EMBEDDED_ASSETS_ENABLED AND EXISTS "${CORE_ASSET_OBJECT}")
    # 创建 IMPORTED OBJECT 库来包含预编译的资产文件
    add_library(lume_engine_rofs OBJECT IMPORTED GLOBAL)
    set_target_properties(lume_engine_rofs PROPERTIES
        IMPORTED_OBJECTS "${CORE_ASSET_OBJECT}"
    )
    message(STATUS "LumeEngine: Creating IMPORTED OBJECT library for embedded assets: ${CORE_ASSET_OBJECT}")
else()
    message(WARNING "LumeEngine: Embedded assets enabled but object file not found: ${CORE_ASSET_OBJECT}")
endif()

# Find OHOS libraries
if(LUME_OHOS_BUILD)
    find_library(hilog-lib hilog_ndk.z)
endif()

# ============================================================================
# Create static library: libAGPEngine
# ============================================================================
# 使用 $<TARGET_OBJECTS:...> 将 OBJECT 库的所有 .o 文件链接
# 【关键】rofs_core_64.o 必须在其他对象之后链接
if(CORE_EMBEDDED_ASSETS_ENABLED AND EXISTS "${CORE_ASSET_OBJECT}")
    add_library(libAGPEngine STATIC
        $<TARGET_OBJECTS:lume_engine_src>
        $<TARGET_OBJECTS:lume_engine_rofs>  # 添加预编译的资产文件
    )
else()
    add_library(libAGPEngine STATIC
        $<TARGET_OBJECTS:lume_engine_src>
    )
endif()

target_include_directories(libAGPEngine PUBLIC
    ${LUME_ENGINE_CONFIG_INCLUDE_DIRS}
    ${LUME_ENGINE_API_INCLUDE_DIRS}
    ${LUME_BASE_API_INCLUDE_DIRS}
    ${LUME_COMPONENT_HELP_INCLUDE_DIRS}
)

target_compile_definitions(libAGPEngine PUBLIC
    ${LUME_ENGINE_CONFIG_DEFINITIONS}
    ${LUME_ENGINE_API_DEFINITIONS}
    ${LUME_BASE_API_DEFINITIONS}
    ${LUME_DEFAULT_DEFINITIONS}
)

# Link LumeBase for header dependencies
target_link_libraries(libAGPEngine PUBLIC LumeBase)

# Link OHOS libraries
if(LUME_OHOS_BUILD)
    target_link_libraries(libAGPEngine PUBLIC ${hilog-lib})
endif()


# ============================================================================
# Create interface library: AGPBaseApi (header-only)
# ============================================================================
add_library(AGPBaseApi INTERFACE)

target_include_directories(AGPBaseApi INTERFACE
    ${LUME_BASE_API_INCLUDE_DIRS}
)

target_compile_definitions(AGPBaseApi INTERFACE
    ${LUME_BASE_API_DEFINITIONS}
)

# Link LumeBase for header dependencies
target_link_libraries(AGPBaseApi INTERFACE LumeBase)

# ============================================================================
# Create interface library: AGPEngineApi (header-only)
# ============================================================================
add_library(AGPEngineApi INTERFACE)

target_include_directories(AGPEngineApi INTERFACE
    ${LUME_ENGINE_API_INCLUDE_DIRS}
)

target_compile_definitions(AGPEngineApi INTERFACE
    ${LUME_ENGINE_API_DEFINITIONS}
)

# Link LumeBase for header dependencies
target_link_libraries(AGPEngineApi INTERFACE LumeBase)

# ============================================================================
# Create interface library: AGPEcshelperApi (header-only)
# ============================================================================
add_library(AGPEcshelperApi INTERFACE)

target_include_directories(AGPEcshelperApi INTERFACE
    ${LUME_COMPONENT_HELP_INCLUDE_DIRS}
)

# Link LumeBase and Engine API for header dependencies
target_link_libraries(AGPEcshelperApi INTERFACE LumeBase AGPEngineApi)

# ============================================================================
# Export include directories for parent project
# ============================================================================
set(LUME_ENGINE_INCLUDE_DIRS
    ${LUME_ENGINE_ROOT}
    ${LUME_ENGINE_ROOT}/api
    ${LUME_BASE_API_INCLUDE_DIRS}
    PARENT_SCOPE
)