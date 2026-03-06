//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_UTILS_H
#define DAYNOTE_UTILS_H
#include <algorithm>
inline float clamp(float v, float minv, float maxv) {
    return std::max(minv, std::min(v, maxv));
}
#endif //DAYNOTE_UTILS_H
