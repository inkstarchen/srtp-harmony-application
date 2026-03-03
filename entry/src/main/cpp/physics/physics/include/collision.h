//
// Created on 2026/2/5.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_COLLISION_H
#define DAYNOTE_COLLISION_H
#include <algorithm>
#pragma once
#include <cmath>
#include "vec.h"

inline float clamp(float v, float minv, float maxv) {
    return std::max(minv, std::min(v, maxv));
}

namespace Collision {

inline bool AABBvsAABB(
    const Vector3& aPos, const Vector3& aExt,
    const Vector3& bPos, const Vector3& bExt)
{
    return
        std::abs(aPos.x - bPos.x) <= (aExt.x + bExt.x) &&
        std::abs(aPos.y - bPos.y) <= (aExt.y + bExt.y) &&
        std::abs(aPos.z - bPos.z) <= (aExt.z + bExt.z);
}

inline bool AABBvsSphere(
    const Vector3& boxPos, const Vector3& boxExt,
    const Vector3& spherePos, float radius)
{
    Vector3 closest;
    closest.x = clamp(
        spherePos.x,
        boxPos.x - boxExt.x,
        boxPos.x + boxExt.x);

    closest.y = clamp(
        spherePos.y,
        boxPos.y - boxExt.y,
        boxPos.y + boxExt.y);

    closest.z = clamp(
        spherePos.z,
        boxPos.z - boxExt.z,
        boxPos.z + boxExt.z);

    Vector3 delta = spherePos - closest;
    return delta.dot(delta) <= radius * radius;
}

}
#endif //DAYNOTE_COLLISION_H
