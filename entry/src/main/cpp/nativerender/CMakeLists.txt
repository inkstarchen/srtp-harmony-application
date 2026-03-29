# the minimum version of CMake.

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
add_definitions(-DOHOS_PLATFORM)

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include
    ${NATIVERENDER_ROOT_PATH}/lume_xcomponent/include
    ${NATIVERENDER_ROOT_PATH}/LumeBase/api
    ${NATIVERENDER_ROOT_PATH}/LumeEngine/api
    ${NATIVERENDER_ROOT_PATH}/LumeRender/api
    ${NATIVERENDER_ROOT_PATH}/securec/include
)

# Add subdirectories in dependency order
add_subdirectory(third_party)
add_subdirectory(securec)
# add_subdirectory(libfreetype)  # Temporarily disabled
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
add_subdirectory(lume_xcomponent)

# Main nativerender library - now uses lume_xcomponent for XComponent rendering
add_library(nativerender SHARED
    napi_init.cpp
)

find_library(EGL-lib EGL)
find_library(GLES-lib GLESv3)
find_library(hilog-lib hilog_ndk.z)
find_library(libace-lib ace_ndk.z)
find_library(libnapi-lib ace_napi.z)
find_library(libuv-lib uv)

target_link_libraries(nativerender PUBLIC
    ${EGL-lib} ${GLES-lib} ${hilog-lib} ${libace-lib} ${libnapi-lib} ${libuv-lib} libnative_window.so
    LumeBase
    libAGPEngine
    lume_render
    lume_3d
    # libFont               # Temporarily disabled
    # libPluginAGP3DText    # Temporarily disabled
    libMetaObject
    EcsSerializer
    libPluginSceneWidget
    lume_xcomponent
)