//
// Created on 2026/2/5.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_BUFFER_H
#define DAYNOTE_BUFFER_H

#include <cstddef>
typedef struct {
    float *data;
    size_t length;
} FloatBuffer;

#endif //DAYNOTE_BUFFER_H
