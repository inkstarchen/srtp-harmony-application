# the minimum version of CMake.

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
add_definitions(-DOHOS_PLATFORM)

# FileSystem test module
set(FILESYSTEM_TEST_SOURCES
    ${NATIVERENDER_ROOT_PATH}/../filesystem_test/filesystem_test.cpp
    ${NATIVERENDER_ROOT_PATH}/../filesystem_test/napi_filesystem_test.cpp
)

include_directories(
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include
    ${NATIVERENDER_ROOT_PATH}/render
    ${NATIVERENDER_ROOT_PATH}/manager/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/securec/include

    # FileSystem test
    ${NATIVERENDER_ROOT_PATH}/../filesystem_test

    # 3d_widget_adapter headers (required for napi_init.cpp -> lume_xcomponent_manager.h -> lume_renderer.h)
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/include/ohos
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/custom
    ${NATIVERENDER_ROOT_PATH}/3d_widget_adapter/core/include/lume/ohos
)

# Add subdirectories in dependency order
add_subdirectory(third_party)
add_subdirectory(securec)
# add_subdirectory(libfreetype)  # Temporarily disabled

# ============================================================================
# 【资产编译工具】
# ============================================================================
# LumeAssetCompiler 是主机工具，用于将资产编译成 ELF 目标文件
# 该工具必须在交叉编译之前在主机上构建
# 输出: LumeAssetCompiler 可执行文件 (运行在构建机器上)
add_subdirectory(LumeBinaryCompile/lumeassetcompiler)

add_subdirectory(LumeBase)
add_subdirectory(LumeEngine)
add_subdirectory(LumeRender)
add_subdirectory(Lume_3D)
# add_subdirectory(LumeFont)      # Temporarily disabled
# add_subdirectory(Lume_3DText)   # Temporarily disabled
add_subdirectory(LumeJpg)
add_subdirectory(LumePng)
add_subdirectory(LumeMeta)
add_subdirectory(LumeEcsSerializer)
add_subdirectory(LumeScene)
add_subdirectory(3d_widget_adapter)
add_subdirectory(3d_scene_adapter)
add_subdirectory(kits)
# add_subdirectory(lume_xcomponent)

add_subdirectory(render)
add_subdirectory(manager)

add_library(nativerender SHARED
    napi_init.cpp
    # ${FILESYSTEM_TEST_SOURCES}
)

find_library(
    # Sets the name of the path variable.
    EGL-lib
    # Specifies the name of the NDK library that
    # you want CMake to locate.
    EGL
)

find_library(
    # Sets the name of the path variable.
    GLES-lib
    # Specifies the name of the NDK library that
    # you want CMake to locate.
    GLESv3
)

find_library(
    # Sets the name of the path variable.
    hilog-lib
    # Specifies the name of the NDK library that
    # you want CMake to locate.
    hilog_ndk.z
)

find_library(
    # Sets the name of the path variable.
    libace-lib
    # Specifies the name of the NDK library that
    # you want CMake to locate.
    ace_ndk.z
)

find_library(
    # Sets the name of the path variable.
    libnapi-lib
    # Specifies the name of the NDK library that
    # you want CMake to locate.
    ace_napi.z
)

find_library(
    # Sets the name of the path variable.
    libuv-lib
    # Specifies the name of the NDK library that
    # you want CMake to locate.
    uv
)

target_link_libraries(nativerender PUBLIC
    ${EGL-lib} ${GLES-lib} ${hilog-lib} ${libace-lib} ${libnapi-lib} ${libuv-lib} libnative_window.so
    LumeBase
    lume_render  # lume_render already contains libAGPEngine with whole-archive
    lume_3d
    # libFont               # Temporarily disabled
    # libPluginAGP3DText    # Temporarily disabled
    libMetaObject
    EcsSerializer
    libPluginSceneWidget
    render
    manager
    )