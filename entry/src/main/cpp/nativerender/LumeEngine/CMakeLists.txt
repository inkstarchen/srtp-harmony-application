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
project(LumeEngine)

set(LUME_ENGINE_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# Build options
option(CORE_LOG_ENABLED "Enable core logging" ON)
option(CORE_DEV_ENABLED "Enable dev mode" OFF)
option(USE_STB_IMAGE "Use stb image" ON)
option(USE_LIB_PNG_JPEG "Use lib png jpeg" OFF)
option(LUME_OHOS_BUILD "Build for OHOS platform" ON)

# Build type
set(BUILDTYPE "Debug")
if(CMAKE_BUILD_TYPE)
    set(BUILDTYPE ${CMAKE_BUILD_TYPE})
endif()

# Set library names
set(LIB_ENGINE_CORE "AGPEngine")
set(LIB_RENDER "AGPRender")
set(LIB_CORE3D "AGPCore3D")
set(CORE_ROFS "rofs")

# ============================================================================
# Config: lume_base_api
# ============================================================================
set(LUME_BASE_API_INCLUDE_DIRS
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
)

set(LUME_BASE_API_DEFINITIONS
    BASE_TESTS_ENABLED=0
    BASE_WARNINGS_AS_ERRORS=0
)

if(CORE_LOG_ENABLED)
    list(APPEND LUME_BASE_API_DEFINITIONS
        CORE_LOG_DISABLED=0
        CORE_LOG_DEBUG=1
    )
else()
    list(APPEND LUME_BASE_API_DEFINITIONS
        CORE_LOG_DISABLED=1
        CORE_LOG_DEBUG=0
    )
endif()

# ============================================================================
# Config: lume_engine_api
# ============================================================================
set(LUME_ENGINE_API_INCLUDE_DIRS
    ${LUME_ENGINE_ROOT}/api
)

if(LUME_OHOS_BUILD)
    list(APPEND LUME_ENGINE_API_INCLUDE_DIRS
        ${LUME_ENGINE_ROOT}/api/platform/ohos/
    )
endif()

set(LUME_ENGINE_API_DEFINITIONS
    CORE_BUILD_BASE=1
    CORE_HIDE_SYMBOLS=1
    CORE_PERF_ENABLED=0
    CORE_USE_COMPILER_GENERATED_STATIC=1
)

if(BUILDTYPE STREQUAL "Release" OR BUILDTYPE STREQUAL "MinSizeRel" OR BUILDTYPE STREQUAL "RelWithDebInfo")
    list(APPEND LUME_ENGINE_API_DEFINITIONS
        CORE_LOG_NO_DEBUG=0
    )
endif()

# ============================================================================
# Config: lume_default
# ============================================================================
set(LUME_DEFAULT_C_FLAGS
    -Wno-unused-function
    -Wno-unused-parameter
    -Wno-sign-compare
    -Wno-unused-variable
    -Wno-unused-private-field
    -Wno-tautological-unsigned-zero-compare
    -Wno-logical-op-parentheses
    -fno-rtti
    -fvisibility=hidden
    -ffunction-sections
    -fdata-sections
    -fno-asynchronous-unwind-tables
    -fno-unwind-tables
    -fno-exceptions
)

set(LUME_DEFAULT_CXX_FLAGS
    -std=c++17
    -Wno-thread-safety-attributes
    -fvisibility=hidden
    -fdata-sections
    -ffunction-sections
    -fno-rtti
    -fvisibility-inlines-hidden
    -fno-asynchronous-unwind-tables
    -fno-unwind-tables
    -fno-exceptions
)

set(LUME_DEFAULT_LINKER_FLAGS
    -fuse-ld=lld
    -flto=thin
    -Wl,--gc-sections
    -Wl,--exclude-libs,ALL
)

set(LUME_DEFAULT_DEFINITIONS)
if(LUME_OHOS_BUILD)
    list(APPEND LUME_DEFAULT_DEFINITIONS
        __OHOS_PLATFORM__
    )
endif()

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
set(STB_IMAGE_PATH ${NATIVERENDER_ROOT_PATH}/3rdparty/stb)

set(LUME_ENGINE_CONFIG_INCLUDE_DIRS
    ${LUME_CORE_PATH}/3rdparty/
    ${LUME_CORE_PATH}/src/
    ${LUME_CORE_PATH}/asserts/
    ${STB_IMAGE_PATH}
)

set(LUME_ENGINE_CONFIG_DEFINITIONS
    CORE_TESTS_ENABLED=0
    CORE_HIDE_SYMBOLS=1
    CORE_WARNINGS_AS_ERRORS=0
    CORE_DEV_ENABLED=${CORE_DEV_ENABLED}
    CORE_LOG_TO_CONSOLE=1
    CORE_LOG_TO_DEBUG_OUTPUT=1
    CORE_LOG_TO_FILE=0
    CORE_VALIDATION_ENABLED=0
    CORE_DYNAMIC=0
    CORE_BUILDTYPE=${BUILDTYPE}
    CORE_PUBLIC=__attribute__((visibility(\"default\")))
    USE_STB_IMAGE=${USE_STB_IMAGE}
    USE_LIB_PNG_JPEG=${USE_LIB_PNG_JPEG}
    CORE_EMBEDDED_ASSETS_ENABLED=1
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
# Create static library: lume_engine_src
# ============================================================================
add_library(lume_engine_src STATIC ${LUME_ENGINE_SOURCES})

target_include_directories(lume_engine_src PUBLIC
    ${LUME_ENGINE_CONFIG_INCLUDE_DIRS}
    ${LUME_ENGINE_API_INCLUDE_DIRS}
    ${LUME_BASE_API_INCLUDE_DIRS}
)

target_compile_definitions(lume_engine_src PUBLIC
    ${LUME_ENGINE_CONFIG_DEFINITIONS}
    ${LUME_ENGINE_API_DEFINITIONS}
    ${LUME_BASE_API_DEFINITIONS}
    ${LUME_DEFAULT_DEFINITIONS}
)

target_compile_options(lume_engine_src PRIVATE
    ${LUME_DEFAULT_C_FLAGS}
    $<$<COMPILE_LANGUAGE:CXX>:${LUME_DEFAULT_CXX_FLAGS}>
)

# Link LumeBase for header dependencies
target_link_libraries(lume_engine_src PUBLIC LumeBase)

# Find OHOS libraries
if(LUME_OHOS_BUILD)
    find_library(hilog-lib hilog_ndk.z)

    target_link_libraries(lume_engine_src PUBLIC
        ${hilog-lib}
    )
endif()

# ============================================================================
# Create static library: libAGPEngine
# ============================================================================
add_library(libAGPEngine STATIC
    $<TARGET_OBJECTS:lume_engine_src>
)

target_include_directories(libAGPEngine PUBLIC
    ${LUME_ENGINE_CONFIG_INCLUDE_DIRS}
    ${LUME_ENGINE_API_INCLUDE_DIRS}
    ${LUME_BASE_API_INCLUDE_DIRS}
)

target_compile_definitions(libAGPEngine PUBLIC
    ${LUME_ENGINE_CONFIG_DEFINITIONS}
    ${LUME_ENGINE_API_DEFINITIONS}
    ${LUME_BASE_API_DEFINITIONS}
    ${LUME_DEFAULT_DEFINITIONS}
)

# Link LumeBase for header dependencies
target_link_libraries(libAGPEngine PUBLIC LumeBase)

# ============================================================================
# Config: lume_component_help_config
# ============================================================================
set(LUME_COMPONENT_HELP_INCLUDE_DIRS
    ${LUME_ENGINE_ROOT}/ecshelper
)

# ============================================================================
# Source files for lume_component_help_src
# ============================================================================
set(LUME_COMPONENT_HELP_SOURCES
    ecshelper/ComponentTools/base_manager.inl
    ecshelper/ComponentTools/base_manager.h
    ecshelper/ComponentTools/component_query.h
    ecshelper/ComponentTools/component_query.cpp
)

# ============================================================================
# Create static library: lume_component_help_src
# ============================================================================
add_library(lume_component_help_src STATIC ${LUME_COMPONENT_HELP_SOURCES})

target_include_directories(lume_component_help_src PUBLIC
    ${LUME_COMPONENT_HELP_INCLUDE_DIRS}
    ${LUME_ENGINE_API_INCLUDE_DIRS}
    ${LUME_BASE_API_INCLUDE_DIRS}
)

target_compile_definitions(lume_component_help_src PUBLIC
    ${LUME_BASE_API_DEFINITIONS}
    ${LUME_ENGINE_API_DEFINITIONS}
)

target_compile_options(lume_component_help_src PRIVATE
    -Wno-unused-function
)

# Link LumeBase for header dependencies
target_link_libraries(lume_component_help_src PUBLIC LumeBase)

# ============================================================================
# Create static library: libComponentHelper
# ============================================================================
add_library(libComponentHelper STATIC
    $<TARGET_OBJECTS:lume_component_help_src>
)

target_include_directories(libComponentHelper PUBLIC
    ${LUME_COMPONENT_HELP_INCLUDE_DIRS}
    ${LUME_ENGINE_API_INCLUDE_DIRS}
    ${LUME_BASE_API_INCLUDE_DIRS}
)

target_compile_definitions(libComponentHelper PUBLIC
    ${LUME_BASE_API_DEFINITIONS}
    ${LUME_ENGINE_API_DEFINITIONS}
    ${LUME_DEFAULT_DEFINITIONS}
)

target_compile_options(libComponentHelper PRIVATE
    ${LUME_DEFAULT_C_FLAGS}
    $<$<COMPILE_LANGUAGE:CXX>:${LUME_DEFAULT_CXX_FLAGS}>
)

# Link LumeBase for header dependencies
target_link_libraries(libComponentHelper PUBLIC LumeBase)

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