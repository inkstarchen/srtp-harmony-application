#
# Copyright (C) 2023 Huawei Technologies Co, Ltd.
#

cmake_minimum_required(VERSION 3.19)
project(ProjectRunner)
set(target_name ProjectRunner)
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

option(CORE_PERF_ENABLED "Build app with performance profiling support enabled" ON)

include(app_runner.cmake)

#
# Import libraries from project package dependencies.
#

get_filename_component(_PACKAGES_DIR "${CMAKE_CURRENT_LIST_DIR}/../../packages" ABSOLUTE)

# Find all directories under packages that contain a package.json file.
file(GLOB
    _PACKAGE_FILES
    LIST_DIRECTORIES false
    CONFIGURE_DEPENDS
    "${_PACKAGES_DIR}/*/package.json"
)
include(runtime_tools)
foreach(_PACKAGE_FILE ${_PACKAGE_FILES})
    add_runtime_package("${_PACKAGE_FILE}")
endforeach()

# Add all package directories that contain a CMakeLists.txt file.
file(GLOB
    _PACKAGE_CMAKE_FILES
    LIST_DIRECTORIES false
    CONFIGURE_DEPENDS
    "${_PACKAGES_DIR}/*/CMakeLists.txt"
)
foreach(_PACKAGE_CMAKE_FILE ${_PACKAGE_CMAKE_FILES})
    get_filename_component(_PACKAGE_DIR ${_PACKAGE_CMAKE_FILE} DIRECTORY)
    get_filename_component(_PACKAGE_NAME ${_PACKAGE_DIR} NAME)
    add_subdirectory(${_PACKAGE_DIR} "packages/${_PACKAGE_NAME}")
endforeach()


#
# Deploy a standalone executable application from the project.
#

# Convert the properties pointing to binary plugins to variables.
get_property(_APP_BINARIES GLOBAL PROPERTY APP_BINARIES)
get_property(_APP_PLUGIN_BINARIES GLOBAL PROPERTY APP_PLUGIN_BINARIES)
get_property(_PACKAGE_PLUGIN_BINARIES GLOBAL PROPERTY PACKAGE_PLUGIN_BINARIES)
get_property(_PACKAGE_PLUGIN_TARGETS GLOBAL PROPERTY PACKAGE_PLUGIN_TARGETS)
get_property(PLUGIN_UIDS GLOBAL PROPERTY PACKAGE_PLUGIN_UIDS)
get_property(PLUGIN_PATHS GLOBAL PROPERTY PACKAGE_PLUGIN_PATHS)

# Create a comma separated list of (quoted) plugin uids/paths that can be used in the runtime-config.json.
list(TRANSFORM PLUGIN_UIDS PREPEND "\"" OUTPUT_VARIABLE _PLUGIN_UIDS_ARRAY)
list(TRANSFORM _PLUGIN_UIDS_ARRAY APPEND "\"")
list(JOIN _PLUGIN_UIDS_ARRAY "," PLUGIN_UIDS_ARRAY)

list(TRANSFORM PLUGIN_PATHS PREPEND "\"" OUTPUT_VARIABLE _PLUGIN_PATHS_ARRAY)
list(TRANSFORM _PLUGIN_PATHS_ARRAY APPEND "\"")
list(JOIN _PLUGIN_PATHS_ARRAY "," PLUGIN_PATHS_ARRAY)

# Define an ouput directory based on the target architecture and some helpers vars.
get_filename_component(_OUTPUT_BIN_DIR "${CMAKE_CURRENT_LIST_DIR}/../../bin/windows" ABSOLUTE)
set(ARCH_PATH "$<CONFIG>/$<$<EQUAL:${CMAKE_SIZEOF_VOID_P},4>:x86>$<$<EQUAL:${CMAKE_SIZEOF_VOID_P},8>:Win64>")
file(TO_NATIVE_PATH "${ARCH_PATH}" ARCH_PATH_NATIVE)
set(_OUTPUT_ARCH_DIR "${_OUTPUT_BIN_DIR}/${ARCH_PATH}")
set(_TEMP_ARCH_DIR "${CMAKE_BINARY_DIR}/bin/windows/${ARCH_PATH}")

# Create a runtime-config file (extra step to support generator expressions).
configure_file(runtime-config.json.in "${CMAKE_BINARY_DIR}/runtime-config.json.gen")
file(GENERATE OUTPUT "${_TEMP_ARCH_DIR}/runtime-config.json" INPUT "${CMAKE_BINARY_DIR}/runtime-config.json.gen")
# Create a runtime  launch command.
set(_LAUNCH_FILE "launch$<IF:$<CONFIG:Release>,,$<CONFIG>>.cmd") # Add the config name to the end (if it's not Release).
configure_file(launch.cmd.in "${CMAKE_BINARY_DIR}/launch.cmd.gen")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/${_LAUNCH_FILE}.out" INPUT "${CMAKE_BINARY_DIR}/launch.cmd.gen")

# Don't try to copy if the list of files to copy is empty.
if(_APP_BINARIES)
    set(_COPY_APP_BINARIES_CMD ${CMAKE_COMMAND} -E copy_if_different ${_APP_BINARIES} "${_OUTPUT_ARCH_DIR}/")
endif()
if(_APP_PLUGIN_BINARIES)
    set(_COPY_APP_PLUGIN_BINARIES_CMD ${CMAKE_COMMAND} -E copy_if_different ${_APP_PLUGIN_BINARIES} "${_OUTPUT_ARCH_DIR}/plugins/")
endif()

# Copy the binary dependencies to the binary output dir.
add_custom_target(${target_name} ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_OUTPUT_ARCH_DIR}/plugins"
    COMMAND ${_COPY_APP_BINARIES_CMD}
    COMMAND ${_COPY_APP_PLUGIN_BINARIES_CMD}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_TEMP_ARCH_DIR}/runtime-config.json" "${_OUTPUT_ARCH_DIR}/runtime-config.json"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_BINARY_DIR}/${_LAUNCH_FILE}.out" "${_OUTPUT_BIN_DIR}/${_LAUNCH_FILE}"
    BYPRODUCTS ${_OUTPUT_BIN_DIR}
)
if (_PACKAGE_PLUGIN_TARGETS)
    add_dependencies(${target_name} ${_PACKAGE_PLUGIN_TARGETS})
endif()


# Enable running and debugging the runtime app directly from Visual Studio (and set the runtime as the "Startup Project").
set_property(DIRECTORY ${CMAKE_CURRENT_LIST_DIR} PROPERTY VS_STARTUP_PROJECT ${target_name})
set_target_properties(${target_name} PROPERTIES
    VS_DEBUGGER_COMMAND "${_OUTPUT_ARCH_DIR}/AppRunner.exe"
    VS_DEBUGGER_COMMAND_ARGUMENTS "-lume_config=\"file:///${_OUTPUT_ARCH_DIR}/runtime-config.json\" -project_path=\"${CMAKE_CURRENT_LIST_DIR}/../../\" -cache_path=\"${_OUTPUT_ARCH_DIR}/cache\""
    VS_DEBUGGER_WORKING_DIRECTORY "${_OUTPUT_ARCH_DIR}"
)
