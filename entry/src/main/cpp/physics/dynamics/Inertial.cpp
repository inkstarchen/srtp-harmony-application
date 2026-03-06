//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#include "Inertial.h"

Vector3 computeBoxInvInertiaBody(Vector3 extent, float invMass)
{
    float w = extent.x * 2.0f;
    float h = extent.y * 2.0f;
    float d = extent.z * 2.0f;

    float ix = 12.0f * invMass / (h*h + d*d);
    float iy = 12.0f * invMass / (w*w + d*d);
    float iz = 12.0f * invMass / (w*w + h*h);

    return Vector3(ix,iy,iz);
}

Matrix3 computeInvInertiaWorld(
    const Matrix3& invInertial,
    const Quaternion& rot)
{
    Matrix3 R = quaternionToMatrix(rot);

    return R * invInertial * R.transpose();
}