//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_SHAPE_H
#define DAYNOTE_SHAPE_H
#include <cstdint>
enum ShapeType : int32_t {
    SHAPE_BOX = 0,
    SHAPE_SPHERE,
    SHAPE_COUNT
};
#endif //DAYNOTE_SHAPE_H
