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

set(LIBPNG_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(LIBPNG_SOURCES
    ${LIBPNG_ROOT}/png.c
    ${LIBPNG_ROOT}/pngerror.c
    ${LIBPNG_ROOT}/pngget.c
    ${LIBPNG_ROOT}/pngmem.c
    ${LIBPNG_ROOT}/pngpread.c
    ${LIBPNG_ROOT}/pngread.c
    ${LIBPNG_ROOT}/pngrio.c
    ${LIBPNG_ROOT}/pngrtran.c
    ${LIBPNG_ROOT}/pngrutil.c
    ${LIBPNG_ROOT}/pngset.c
    ${LIBPNG_ROOT}/pngtrans.c
    ${LIBPNG_ROOT}/pngwio.c
    ${LIBPNG_ROOT}/pngwrite.c
    ${LIBPNG_ROOT}/pngwtran.c
    ${LIBPNG_ROOT}/pngwutil.c
)

# ============================================================================
# Create static library
# ============================================================================
add_library(png_static STATIC ${LIBPNG_SOURCES})

target_compile_definitions(png_static PRIVATE
    PNG_ARM_NEON_OPT=0
)

target_include_directories(png_static PUBLIC
    ${LIBPNG_ROOT}
)

# Link zlib from NDK
target_link_libraries(png_static PUBLIC z)