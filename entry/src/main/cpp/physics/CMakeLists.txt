# the minimum version of CMake.

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include
                    ${NATIVERENDER_ROOT_PATH}/physics/include
                    ${NATIVERENDER_ROOT_PATH}/math
                    ${NATIVERENDER_ROOT_PATH}/dynamics/include)

add_definitions("-DLOG_DOMAIN=0x0000")
add_definitions("-DLOG_TAG=\"testTag\"")

add_library(physics SHARED napi_init.cpp  napi_helpers.h napi_helpers.cpp
    physics/physicalSystem.cpp physics/include/physicalSystem.h
    dynamics/Inertial.cpp physics/collision.cpp physics/include/shape.h physics/include/contact.h math/utils.h physics/include/body.h)
target_link_libraries(physics PUBLIC libace_napi.z.so libhilog_ndk.z.so libEGL.so)