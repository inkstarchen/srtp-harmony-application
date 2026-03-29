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

set(LUME_ECS_SERIALIZER_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files: runtime_utils
# ============================================================================
set(RUNTIME_UTILS_SOURCES
    Util/src/util/io_util.cpp
    Util/src/util/json.cpp
    Util/src/util/path_util.cpp
)

# ============================================================================
# Source files: ecs_serializer
# ============================================================================
set(ECS_SERIALIZER_SOURCES
    EcsSerializer/src/ecs_serializer/asset_migration.cpp
    EcsSerializer/src/ecs_serializer/ecs_asset_loader.cpp
    EcsSerializer/src/ecs_serializer/ecs_asset_manager.cpp
    EcsSerializer/src/ecs_serializer/ecs_serializer.cpp
    EcsSerializer/src/ecs_serializer/entity_collection.cpp
)

# ============================================================================
# Create static library: runtime_utils_src
# ============================================================================
add_library(runtime_utils_src STATIC ${RUNTIME_UTILS_SOURCES})

target_include_directories(runtime_utils_src PUBLIC
    ${LUME_ECS_SERIALIZER_ROOT}/Util/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
)

target_link_libraries(runtime_utils_src PUBLIC LumeBase lume_engine_src)

# ============================================================================
# Create static library: ecs_serializer_src
# ============================================================================
add_library(ecs_serializer_src STATIC ${ECS_SERIALIZER_SOURCES})

target_include_directories(ecs_serializer_src PUBLIC
    ${LUME_ECS_SERIALIZER_ROOT}/EcsSerializer/include
    ${LUME_ECS_SERIALIZER_ROOT}/Util/include
    ${LUME_ECS_SERIALIZER_ROOT}/EcsSerializer/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/ecshelper
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
)

target_link_libraries(ecs_serializer_src PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
    lume_3d_src
    runtime_utils_src
)

# ============================================================================
# Create static library: EcsSerializer (combined)
# ============================================================================
add_library(EcsSerializer STATIC
    $<TARGET_OBJECTS:runtime_utils_src>
    $<TARGET_OBJECTS:ecs_serializer_src>
)

target_include_directories(EcsSerializer PUBLIC
    ${LUME_ECS_SERIALIZER_ROOT}/Util/include
    ${LUME_ECS_SERIALIZER_ROOT}/EcsSerializer/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/Lume_3D/api
)