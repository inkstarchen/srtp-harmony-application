//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_INERTIAL_H
#define DAYNOTE_INERTIAL_H

#include "math/matrix.h"
#include "math/quteration.h"
Vector3 computeBoxInvInertiaBody(
    const Vector3& extent,
    float invMass
);

Matrix3 computeInvInertiaWorld(
    const Matrix3& invInertial,
    const Quaternion& rot
);

#endif //DAYNOTE_INERTIAL_H
