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

set(FREETYPE_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# FreeType source files based on ftmodule.h
# ============================================================================
set(FREETYPE_SOURCES
    # base
    src/base/ftbase.c
    src/base/ftinit.c
    src/base/ftsystem.c
    src/base/ftdebug.c
    src/base/ftbitmap.c
    src/base/ftglyph.c
    src/base/ftstroke.c
    src/base/ftsynth.c
    src/base/ftadvanc.c
    src/base/ftcalc.c
    src/base/ftgloadr.c
    src/base/ftobjs.c
    src/base/ftoutln.c
    src/base/ftrfork.c
    src/base/ftsnames.c
    src/base/ftstream.c
    src/base/fttrigon.c
    src/base/ftutil.c
    src/base/ftfntfmt.c
    src/base/ftlcdfil.c
    src/base/ftgasp.c

    # autofit module
    src/autofit/autofit.c

    # truetype module
    src/truetype/truetype.c

    # type1 module
    src/type1/type1.c

    # cff module
    src/cff/cff.c

    # cid module
    src/cid/type1cid.c

    # pfr module
    src/pfr/pfr.c

    # type42 module
    src/type42/type42.c

    # winfonts module
    src/winfonts/winfnt.c

    # pcf module
    src/pcf/pcf.c

    # psaux module
    src/psaux/psaux.c

    # psnames module
    src/psnames/psnames.c

    # pshinter module
    src/pshinter/pshinter.c

    # raster module
    src/raster/raster.c

    # sfnt module
    src/sfnt/sfnt.c

    # smooth module
    src/smooth/smooth.c

    # bdf module
    src/bdf/bdf.c
)

# ============================================================================
# Create static library: freetype
# ============================================================================
add_library(freetype STATIC ${FREETYPE_SOURCES})

target_include_directories(freetype PUBLIC
    ${FREETYPE_ROOT}/include
)

target_compile_definitions(freetype PRIVATE
    FT2_BUILD_LIBRARY
    FT_CONFIG_OPTION_SUBPIXEL_RENDERING
)

# Disable warnings for third-party code
if(MSVC)
    target_compile_options(freetype PRIVATE /W0)
else()
    target_compile_options(freetype PRIVATE
        -Wno-unused-function
        -Wno-unused-parameter
        -Wno-unused-variable
        -Wno-sign-compare
        -Wno-implicit-function-declaration
    )
endif()