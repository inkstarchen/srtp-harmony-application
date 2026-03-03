//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_VEC_H
#define DAYNOTE_VEC_H

#pragma once
#include <cmath>

#pragma once

#include <cmath>

// =======================
// Vector3
// =======================
struct Vector3 {
    double x, y, z;

    // 构造
    Vector3() : x(0.0), y(0.0), z(0.0) {}
    Vector3(double x, double y, double z) : x(x), y(y), z(z) {}

    // ===== 基本运算 =====
    Vector3 operator+(const Vector3& other) const {
        return Vector3(x + other.x, y + other.y, z + other.z);
    }

    Vector3 operator-(const Vector3& other) const {
        return Vector3(x - other.x, y - other.y, z - other.z);
    }

    Vector3 operator*(double scalar) const {
        return Vector3(x * scalar, y * scalar, z * scalar);
    }

    Vector3 operator/(double scalar) const {
        return Vector3(x / scalar, y / scalar, z / scalar);
    }

    Vector3& operator+=(const Vector3& other) {
        x += other.x; y += other.y; z += other.z;
        return *this;
    }

    Vector3& operator-=(const Vector3& other) {
        x -= other.x; y -= other.y; z -= other.z;
        return *this;
    }

    Vector3& operator*=(double scalar) {
        x *= scalar; y *= scalar; z *= scalar;
        return *this;
    }

    Vector3& operator/=(double scalar) {
        x /= scalar; y /= scalar; z /= scalar;
        return *this;
    }

    Vector3 operator-() const {
        return Vector3(-x, -y, -z);
    }

    // ===== 向量性质 =====
    double dot(const Vector3& other) const {
        return x * other.x + y * other.y + z * other.z;
    }

    Vector3 cross(const Vector3& other) const {
        return Vector3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        );
    }

    double lengthSquared() const {
        return dot(*this);
    }

    double length() const {
        return std::sqrt(lengthSquared());
    }

    Vector3 normalized() const {
        double len = length();
        if (len > 1e-8) {
            return (*this) / len;
        }
        return Vector3(0.0, 0.0, 0.0);
    }

    // ===== 常用工具 =====
    static Vector3 RotateAroundAxis(
        const Vector3& v,
        const Vector3& axis,
        double angleRad
    ) {
        // Rodrigues' rotation formula
        Vector3 n = axis.normalized();
        double cosA = std::cos(angleRad);
        double sinA = std::sin(angleRad);

        return v * cosA
             + n.cross(v) * sinA
             + n * (n.dot(v)) * (1.0 - cosA);
    }
};

// 标量在左侧
inline Vector3 operator*(double scalar, const Vector3& v) {
    return v * scalar;
}
#pragma once

#include <cmath>

// =======================
// Vector2
// =======================
struct Vector2 {
    double x, y;

    // 构造
    Vector2() : x(0.0), y(0.0) {}
    Vector2(double x, double y) : x(x), y(y) {}

    // ===== 向量运算（成员函数：隐式 inline） =====
    Vector2 operator+(const Vector2& other) const {
        return Vector2(x + other.x, y + other.y);
    }

    Vector2 operator-(const Vector2& other) const {
        return Vector2(x - other.x, y - other.y);
    }

    Vector2 operator*(double scalar) const {
        return Vector2(x * scalar, y * scalar);
    }

    Vector2 operator/(double scalar) const {
        return Vector2(x / scalar, y / scalar);
    }

    Vector2& operator+=(const Vector2& other) {
        x += other.x; y += other.y;
        return *this;
    }

    Vector2& operator-=(const Vector2& other) {
        x -= other.x; y -= other.y;
        return *this;
    }

    Vector2& operator*=(double scalar) {
        x *= scalar; y *= scalar;
        return *this;
    }

    Vector2& operator/=(double scalar) {
        x /= scalar; y /= scalar;
        return *this;
    }

    Vector2 operator-() const {
        return Vector2(-x, -y);
    }

    // ===== 向量性质 =====
    double dot(const Vector2& other) const {
        return x * other.x + y * other.y;
    }

    double lengthSquared() const {
        return dot(*this);
    }

    double length() const {
        return std::sqrt(lengthSquared());
    }

    Vector2 normalized() const {
        double len = length();
        if (len > 1e-8) {
            return (*this) / len;
        }
        return Vector2(0.0, 0.0);
    }
};

// 标量在左侧
inline Vector2 operator*(double scalar, const Vector2& v) {
    return v * scalar;
}


// =======================
// Vector4
// =======================
struct Vector4 {
    double x, y, z, w;

    // 构造
    Vector4() : x(0.0), y(0.0), z(0.0), w(0.0) {}
    Vector4(double x, double y, double z, double w)
        : x(x), y(y), z(z), w(w) {}

    // ===== 向量运算 =====
    Vector4 operator+(const Vector4& other) const {
        return Vector4(x + other.x, y + other.y, z + other.z, w + other.w);
    }

    Vector4 operator-(const Vector4& other) const {
        return Vector4(x - other.x, y - other.y, z - other.z, w - other.w);
    }

    Vector4 operator*(double scalar) const {
        return Vector4(x * scalar, y * scalar, z * scalar, w * scalar);
    }

    Vector4 operator/(double scalar) const {
        return Vector4(x / scalar, y / scalar, z / scalar, w / scalar);
    }

    Vector4& operator+=(const Vector4& other) {
        x += other.x; y += other.y; z += other.z; w += other.w;
        return *this;
    }

    Vector4& operator-=(const Vector4& other) {
        x -= other.x; y -= other.y; z -= other.z; w -= other.w;
        return *this;
    }

    Vector4& operator*=(double scalar) {
        x *= scalar; y *= scalar; z *= scalar; w *= scalar;
        return *this;
    }

    Vector4& operator/=(double scalar) {
        x /= scalar; y /= scalar; z /= scalar; w /= scalar;
        return *this;
    }

    Vector4 operator-() const {
        return Vector4(-x, -y, -z, -w);
    }

    // ===== 向量性质 =====
    double dot(const Vector4& other) const {
        return x * other.x + y * other.y + z * other.z + w * other.w;
    }

    double lengthSquared() const {
        return dot(*this);
    }

    double length() const {
        return std::sqrt(lengthSquared());
    }

    Vector4 normalized() const {
        double len = length();
        if (len > 1e-8) {
            return (*this) / len;
        }
        return Vector4(0.0, 0.0, 0.0, 0.0);
    }
};

// 标量在左侧
inline Vector4 operator*(double scalar, const Vector4& v) {
    return v * scalar;
}

#endif //DAYNOTE_VEC_H
