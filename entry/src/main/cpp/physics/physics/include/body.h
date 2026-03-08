//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_BODY_H
#define DAYNOTE_BODY_H
#include "matrix.h"
#include "quteration.h"
#include "shape.h"
#include "vec.h"
struct Body
{
    ShapeType type;
    Vector3 pos;
    Quaternion rot;

    Vector3 vel;
    Vector3 angVel;

    Vector3 extent;

    float invMass;

    Matrix3 invInertia;
    Matrix3 invInertialWorld;
};
#endif //DAYNOTE_BODY_H
