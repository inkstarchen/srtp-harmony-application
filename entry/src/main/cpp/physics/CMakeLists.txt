# the minimum version of CMake.

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include
                    ${NATIVERENDER_ROOT_PATH}/core/include
                    ${NATIVERENDER_ROOT_PATH}/physics/include)

add_definitions("-DLOG_DOMAIN=0x0000")
add_definitions("-DLOG_TAG=\"testTag\"")

add_library(physics SHARED napi_init.cpp  napi_helpers.h napi_helpers.cpp
    core/include/quteration.h
    physics/include/physicalSystem.h physics/physicalSystem.cpp
    core/include/buffer.h physics/include/collision.h)
target_link_libraries(physics PUBLIC libace_napi.z.so libhilog_ndk.z.so libEGL.so)