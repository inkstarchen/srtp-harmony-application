
#include "include/vec.h"
#include <cmath>
// 3D向量
Vector3::Vector3() : x(0), y(0), z(0) {}

Vector3::Vector3(double x, double y, double z) : x(x), y(y), z(z) {}

// 向量运算
Vector3 Vector3::operator+(const Vector3& other) const {
    return Vector3(x + other.x, y + other.y, z + other.z);
}

Vector3 Vector3::operator-(const Vector3& other) const {
    return Vector3(x - other.x, y - other.y, z - other.z);
}

Vector3 Vector3::operator*(double scalar) const {
    return Vector3(x * scalar, y * scalar, z * scalar);
}

// 点积
double Vector3::dot(const Vector3& other) const {
    return x * other.x + y * other.y + z * other.z;
}

// 叉积
Vector3 Vector3::cross(const Vector3& other) const {
    return Vector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x
    );
}

// 长度
double Vector3::length() const {
    return std::sqrt(x*x + y*y + z*z);
}

// 归一化
Vector3 Vector3::normalized() const {
    double len = length();
    if (len > 0.0001) {
        return Vector3(x/len, y/len, z/len);
    }
    return Vector3(0, 0, 0);
}