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
project(LumeBase)

set(LUME_BASE_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# Build options
option(BASE_TESTS_ENABLED "Enable base tests" OFF)
option(BASE_WARNINGS_AS_ERRORS "Treat warnings as errors" OFF)
option(CORE_LOG_ENABLED "Enable core logging" ON)

# ============================================================================
# Definitions for LumeBase
# ============================================================================
set(LUME_BASE_DEFINITIONS
    BASE_TESTS_ENABLED=${BASE_TESTS_ENABLED}
    BASE_WARNINGS_AS_ERRORS=${BASE_WARNINGS_AS_ERRORS}
)

if(CORE_LOG_ENABLED)
    list(APPEND LUME_BASE_DEFINITIONS
        CORE_LOG_DISABLED=0
        CORE_LOG_DEBUG=1
    )
else()
    list(APPEND LUME_BASE_DEFINITIONS
        CORE_LOG_DISABLED=1
        CORE_LOG_DEBUG=0
    )
endif()

# ============================================================================
# Create interface library for header-only LumeBase
# ============================================================================
add_library(LumeBase INTERFACE)

target_include_directories(LumeBase INTERFACE
    ${LUME_BASE_ROOT}/api
)

target_compile_definitions(LumeBase INTERFACE
    ${LUME_BASE_DEFINITIONS}
)

# ============================================================================
# Export variables for parent project
# ============================================================================
set(LUME_BASE_INCLUDE_DIRS
    ${LUME_BASE_ROOT}/api
    PARENT_SCOPE
)

set(LUME_BASE_DEFINITIONS
    ${LUME_BASE_DEFINITIONS}
    PARENT_SCOPE
)