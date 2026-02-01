//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_VEC_H
#define DAYNOTE_VEC_H
// 3D向量
struct Vector3 {
    double x, y, z;

    Vector3();
    Vector3(double x, double y, double z);

    // 向量运算
    Vector3 operator+(const Vector3& other) const;
    Vector3 operator-(const Vector3& other) const;
    Vector3 operator*(double scalar) const;

    // 点积
    double dot(const Vector3& other) const;

    // 叉积
    Vector3 cross(const Vector3& other) const;

    // 长度
    double length() const;

    // 归一化
    Vector3 normalized() const;
};
#endif //DAYNOTE_VEC_H
