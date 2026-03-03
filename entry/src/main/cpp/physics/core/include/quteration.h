//
// Created on 2026/2/1.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_QUTERATION_H
#define DAYNOTE_QUTERATION_H
#pragma once

#include <cmath>
#include "vec.h"

// =======================
// Quaternion
// =======================
struct Quaternion {
    double x, y, z, w; // (x, y, z) = vector part, w = scalar part

    // 构造
    Quaternion() : x(0.0), y(0.0), z(0.0), w(1.0) {}
    Quaternion(double x, double y, double z, double w)
        : x(x), y(y), z(z), w(w) {}

    // 单位四元数
    static Quaternion identity() {
        return Quaternion(0.0, 0.0, 0.0, 1.0);
    }

    // 从轴角创建
    static Quaternion fromAxisAngle(const Vector3& axis, double angleRad) {
        Vector3 n = axis.normalized();
        double half = angleRad * 0.5;
        double s = std::sin(half);

        return Quaternion(
            n.x * s,
            n.y * s,
            n.z * s,
            std::cos(half)
        );
    }

    // 四元数乘法（旋转叠加）
    Quaternion operator*(const Quaternion& other) const {
        return Quaternion(
            w * other.x + x * other.w + y * other.z - z * other.y,
            w * other.y - x * other.z + y * other.w + z * other.x,
            w * other.z + x * other.y - y * other.x + z * other.w,
            w * other.w - x * other.x - y * other.y - z * other.z
        );
    }

    // 共轭
    Quaternion conjugate() const {
        return Quaternion(-x, -y, -z, w);
    }

    // 归一化
    Quaternion normalized() const {
        double len = std::sqrt(x*x + y*y + z*z + w*w);
        if (len > 1e-8) {
            double inv = 1.0 / len;
            return Quaternion(x * inv, y * inv, z * inv, w * inv);
        }
        return identity();
    }

    // 使用四元数旋转向量
    Vector3 rotate(const Vector3& v) const {
        Quaternion qv(v.x, v.y, v.z, 0.0);
        Quaternion r = (*this) * qv * conjugate();
        return Vector3(r.x, r.y, r.z);
    }
};

#endif //DAYNOTE_QUTERATION_H
