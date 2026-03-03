#
# Copyright (C) 2023 Huawei Technologies Co, Ltd.
#

cmake_minimum_required(VERSION 3.19)
project(PluginMyBehaviors LANGUAGES CXX)
set(target_name ${PROJECT_NAME})

find_package(LumeSDK REQUIRED)

find_package(RuntimeFrameworkApi REQUIRED)
find_package(LumeUiToolkitUserApi REQUIRED)
find_package(LumeSceneAPI REQUIRED)
find_package(AGP3DAPI)

add_library(${target_name} SHARED)

target_sources(${target_name} PRIVATE
    # Add any own source files here.
)

include(plugin_generated.cmake)

source_group(src "src")

target_include_directories(${target_name} PRIVATE src)

target_link_libraries(${target_name} PRIVATE
    Runtime::FrameworkApi
    LumeUi::ToolkitUserApi
    LumeScene::API
    AGP3D::AGP3DAPI
)

target_compile_definitions(${target_name} PRIVATE CORE_PLUGIN=1)

set_property(TARGET ${target_name} PROPERTY CXX_STANDARD 17)
set_property(TARGET ${target_name} PROPERTY CXX_EXTENSIONS OFF)

set_target_properties(${target_name} PROPERTIES FOLDER Plugins)

add_custom_command(TARGET ${target_name} POST_BUILD
    COMMAND echo ------------------------------------------------------------------------------------------
    COMMAND echo Load / reload the plugin in Lume Studio by clicking the reload button in the Add-ons panel
    COMMAND echo ------------------------------------------------------------------------------------------
)

#
# Deploy the built binary for this plugin to the location defined in the plugin.json.
#
include(runtime_tools)
# This will look for a target that has the same name as the plugin in the json and copy the
# Built target binary to the location specified by the json.
deploy_package_plugin("${CMAKE_CURRENT_LIST_DIR}/plugin.json")
