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
project(securec C)

set(SECUREC_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# Source files
set(SECUREC_SOURCES
    src/fscanf_s.c
    src/fwscanf_s.c
    src/gets_s.c
    src/memcpy_s.c
    src/memmove_s.c
    src/memset_s.c
    src/scanf_s.c
    src/secinput.h
    src/securecutil.c
    src/securecutil.h
    src/secureinput_a.c
    src/secureinput_w.c
    src/secureprintoutput.h
    src/secureprintoutput_a.c
    src/secureprintoutput_w.c
    src/snprintf_s.c
    src/sprintf_s.c
    src/sscanf_s.c
    src/strcat_s.c
    src/strcpy_s.c
    src/strncat_s.c
    src/strncpy_s.c
    src/strtok_s.c
    src/swprintf_s.c
    src/swscanf_s.c
    src/vfscanf_s.c
    src/vfwscanf_s.c
    src/vscanf_s.c
    src/vsnprintf_s.c
    src/vsprintf_s.c
    src/vsscanf_s.c
    src/vswprintf_s.c
    src/vswscanf_s.c
    src/vwscanf_s.c
    src/wcscat_s.c
    src/wcscpy_s.c
    src/wcsncat_s.c
    src/wcsncpy_s.c
    src/wcstok_s.c
    src/wmemcpy_s.c
    src/wmemmove_s.c
    src/wscanf_s.c
)

# Create static library
add_library(securec STATIC ${SECUREC_SOURCES})

target_include_directories(securec PUBLIC
    ${SECUREC_ROOT}/include
)

# Compile options
target_compile_options(securec PRIVATE
    -Wno-unused-parameter
    -Wno-implicit-function-declaration
)

# Export include directory for parent scope
set(SECUREC_INCLUDE_DIR ${SECUREC_ROOT}/include PARENT_SCOPE)