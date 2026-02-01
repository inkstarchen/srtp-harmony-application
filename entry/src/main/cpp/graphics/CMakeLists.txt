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

add_library(entry SHARED napi_init.cpp  napi_helpers.h napi_helpers.cpp physics/simulator.cpp physics/node.cpp core/vec.cpp)
target_link_libraries(entry PUBLIC libace_napi.z.so libhilog_ndk.z.so libEGL.so)