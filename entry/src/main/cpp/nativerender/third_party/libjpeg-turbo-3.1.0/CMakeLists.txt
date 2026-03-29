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

set(LIBJPEG_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# Source files
# ============================================================================
set(LIBJPEG_SOURCES
    ${LIBJPEG_ROOT}/src/jcapimin.c
    ${LIBJPEG_ROOT}/src/jcapistd.c
    ${LIBJPEG_ROOT}/src/jccoefct.c
    ${LIBJPEG_ROOT}/src/jccolor.c
    ${LIBJPEG_ROOT}/src/jcdctmgr.c
    ${LIBJPEG_ROOT}/src/jchuff.c
    ${LIBJPEG_ROOT}/src/jcicc.c
    ${LIBJPEG_ROOT}/src/jcinit.c
    ${LIBJPEG_ROOT}/src/jcmainct.c
    ${LIBJPEG_ROOT}/src/jcmarker.c
    ${LIBJPEG_ROOT}/src/jcmaster.c
    ${LIBJPEG_ROOT}/src/jcomapi.c
    ${LIBJPEG_ROOT}/src/jcparam.c
    ${LIBJPEG_ROOT}/src/jcphuff.c
    ${LIBJPEG_ROOT}/src/jcprepct.c
    ${LIBJPEG_ROOT}/src/jcsample.c
    ${LIBJPEG_ROOT}/src/jctrans.c
    ${LIBJPEG_ROOT}/src/jdapimin.c
    ${LIBJPEG_ROOT}/src/jdapistd.c
    ${LIBJPEG_ROOT}/src/jdatadst.c
    ${LIBJPEG_ROOT}/src/jdatasrc.c
    ${LIBJPEG_ROOT}/src/jdcoefct.c
    ${LIBJPEG_ROOT}/src/jdcolor.c
    ${LIBJPEG_ROOT}/src/jddctmgr.c
    ${LIBJPEG_ROOT}/src/jddiffct.c
    ${LIBJPEG_ROOT}/src/jdhuff.c
    ${LIBJPEG_ROOT}/src/jdicc.c
    ${LIBJPEG_ROOT}/src/jdinput.c
    ${LIBJPEG_ROOT}/src/jdlhuff.c
    ${LIBJPEG_ROOT}/src/jdlossls.c
    ${LIBJPEG_ROOT}/src/jdmainct.c
    ${LIBJPEG_ROOT}/src/jdmarker.c
    ${LIBJPEG_ROOT}/src/jdmaster.c
    ${LIBJPEG_ROOT}/src/jdmerge.c
    ${LIBJPEG_ROOT}/src/jdphuff.c
    ${LIBJPEG_ROOT}/src/jdpostct.c
    ${LIBJPEG_ROOT}/src/jdsample.c
    ${LIBJPEG_ROOT}/src/jdtrans.c
    ${LIBJPEG_ROOT}/src/jerror.c
    ${LIBJPEG_ROOT}/src/jfdctflt.c
    ${LIBJPEG_ROOT}/src/jfdctfst.c
    ${LIBJPEG_ROOT}/src/jfdctint.c
    ${LIBJPEG_ROOT}/src/jidctflt.c
    ${LIBJPEG_ROOT}/src/jidctfst.c
    ${LIBJPEG_ROOT}/src/jidctint.c
    ${LIBJPEG_ROOT}/src/jidctred.c
    ${LIBJPEG_ROOT}/src/jmemmgr.c
    ${LIBJPEG_ROOT}/src/jmemnobs.c
    ${LIBJPEG_ROOT}/src/jquant1.c
    ${LIBJPEG_ROOT}/src/jquant2.c
    ${LIBJPEG_ROOT}/src/jstdhuff.c
    ${LIBJPEG_ROOT}/src/jutils.c
    # TurboJPEG sources
    ${LIBJPEG_ROOT}/src/jaricom.c
    ${LIBJPEG_ROOT}/src/jcarith.c
    ${LIBJPEG_ROOT}/src/jdarith.c
    ${LIBJPEG_ROOT}/src/jdatadst-tj.c
    ${LIBJPEG_ROOT}/src/jdatasrc-tj.c
    ${LIBJPEG_ROOT}/src/turbojpeg.c
    ${LIBJPEG_ROOT}/src/transupp.c
    ${LIBJPEG_ROOT}/src/rdbmp.c
    ${LIBJPEG_ROOT}/src/rdppm.c
    ${LIBJPEG_ROOT}/src/wrbmp.c
    ${LIBJPEG_ROOT}/src/wrppm.c
    ${LIBJPEG_ROOT}/src/jpeg_nbits.c
)

# ARM NEON optimization sources
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    list(APPEND LIBJPEG_SOURCES
        ${LIBJPEG_ROOT}/simd/arm/jccolor-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jcgray-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jcphuff-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jcsample-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jdmerge-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jdsample-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jfdctfst-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jidctred-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jquanti-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jidctfst-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jidctint-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jdcolor-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jfdctint-neon.c
        ${LIBJPEG_ROOT}/simd/arm/aarch64/jchuff-neon.c
        ${LIBJPEG_ROOT}/simd/arm/aarch64/jsimd.c
    )
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
    list(APPEND LIBJPEG_SOURCES
        ${LIBJPEG_ROOT}/simd/arm/jccolor-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jcgray-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jcphuff-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jcsample-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jdmerge-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jdsample-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jfdctfst-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jidctred-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jquanti-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jidctfst-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jidctint-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jdcolor-neon.c
        ${LIBJPEG_ROOT}/simd/arm/jfdctint-neon.c
        ${LIBJPEG_ROOT}/simd/arm/aarch32/jchuff-neon.c
        ${LIBJPEG_ROOT}/simd/arm/aarch32/jsimd.c
    )
else()
    list(APPEND LIBJPEG_SOURCES ${LIBJPEG_ROOT}/src/jsimd_none.c)
endif()

# ============================================================================
# Create static library
# ============================================================================
add_library(turbojpeg_static STATIC ${LIBJPEG_SOURCES})

target_compile_definitions(turbojpeg_static PRIVATE
    HAVE_UNSIGNED_SHORT=1
    C_ARITH_CODING_SUPPORTED=1
    D_ARITH_CODING_SUPPORTED=1
    BMP_SUPPORTED=1
    PPM_SUPPORTED=1
)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm" OR CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    target_compile_definitions(turbojpeg_static PRIVATE NEON_INTRINSICS)
endif()

target_include_directories(turbojpeg_static PUBLIC
    ${LIBJPEG_ROOT}
    ${LIBJPEG_ROOT}/src
)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm" OR CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    target_include_directories(turbojpeg_static PUBLIC ${LIBJPEG_ROOT}/simd/arm)
endif()