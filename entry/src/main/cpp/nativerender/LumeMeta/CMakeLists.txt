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

set(LUME_META_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(CORE_STATIC_PLUGIN_HEADER "\"${NATIVERENDER_ROOT_PATH}/LumeEngine/src/static_plugin_decl.h\"")

# ============================================================================
# Source files
# ============================================================================
set(LUME_META_SOURCES
    # animation
    src/animation/animation_controller.cpp
    src/animation/animation_state.cpp
    src/animation/interpolator.cpp
    src/animation/keyframe_animation.cpp
    src/animation/modifiers/loop.cpp
    src/animation/modifiers/reverse.cpp
    src/animation/modifiers/speed.cpp
    src/animation/parallel_animation.cpp
    src/animation/property_animation.cpp
    src/animation/sequential_animation.cpp
    src/animation/staggered_animation_state.cpp
    src/animation/track_animation.cpp
    src/animation/track_animation_state.cpp

    # container
    src/container/container.cpp
    src/container/container_base.cpp
    src/container/flat_container.cpp
    src/container/object_container.cpp
    src/container/object_flat_container.cpp

    # curves
    src/curves/bezier_curve.cpp
    src/curves/easing_curve.cpp

    # engine
    src/engine/engine_input_property_manager.cpp
    src/engine/engine_value.cpp
    src/engine/engine_value_manager.cpp

    # loaders
    src/loaders/class_content_loader.cpp
    src/loaders/csv_parser.cpp
    src/loaders/csv_string_resource_loader.cpp
    src/loaders/json_content_loader.cpp

    # model
    src/model/composite_object_provider.cpp
    src/model/container_data_model.cpp
    src/model/content_loader_object_provider.cpp
    src/model/instantiating_object_provider.cpp
    src/model/object_provider_base.cpp

    # property
    src/property/bind.cpp
    src/property/dependencies.cpp
    src/property/property.cpp
    src/property/stack_property.cpp

    # resource
    src/resource/file_resource_manager.cpp
    src/resource/object_resource.cpp

    # serialization/backend
    src/serialization/backend/debug_output.cpp
    src/serialization/backend/json_input.cpp
    src/serialization/backend/json_output.cpp

    # serialization
    src/serialization/exporter.cpp
    src/serialization/importer.cpp
    src/serialization/json_exporter.cpp
    src/serialization/json_importer.cpp
    src/serialization/metav1_compat.cpp

    # core sources
    src/attachment_container.cpp
    src/call_context.cpp
    src/class_registry.cpp
    src/connector.cpp
    src/container_observer.cpp
    src/content_object.cpp
    src/functions.cpp
    src/future.cpp
    src/manual_clock.cpp
    src/meta_object_lib.cpp
    src/number.cpp
    src/object_context.cpp
    src/object_data_container.cpp
    src/object_hierarchy_observer.cpp
    src/object_registry.cpp
    src/plugin.cpp
    src/polling_task_queue.cpp
    src/proxy_object.cpp
    src/random.cpp
    src/ref_uri_util.cpp
    src/register_anys.cpp
    src/register_default_anims.cpp
    src/register_default_objs.cpp
    src/register_engine_access.cpp
    src/register_entities.cpp
    src/register_value_serializers.cpp
    src/startable_object_controller.cpp
    src/system_clock.cpp
    src/threaded_task_queue.cpp
)

# ============================================================================
# Create static library: lume_meta_src
# ============================================================================
add_library(lume_meta_src STATIC ${LUME_META_SOURCES})

target_compile_definitions(lume_meta_src PUBLIC
    __OHOS_PLATFORM__
    CORE_USE_COMPILER_GENERATED_STATIC_LIST=1
    CORE_STATIC_PLUGIN_HEADER=${CORE_STATIC_PLUGIN_HEADER}
)

target_include_directories(lume_meta_src PUBLIC
    ${LUME_META_ROOT}/include
    ${LUME_META_ROOT}/src
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/ecshelper
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)

target_link_libraries(lume_meta_src PUBLIC
    LumeBase
    lume_engine_src
    lume_render_src
)

# ============================================================================
# Create static library: libMetaObject
# ============================================================================
add_library(libMetaObject STATIC
    $<TARGET_OBJECTS:lume_meta_src>
)

target_include_directories(libMetaObject PUBLIC
    ${LUME_META_ROOT}/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
)