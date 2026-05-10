//
// Created on 2026/5/9.
// 射线检测模块：独立的射线-AABB/OBB/球体相交测试

#ifndef DAYNOTE_RAYCAST_H
#define DAYNOTE_RAYCAST_H

#include "vec.h"
#include "quaternion.h"
#include <cstdint>
#include <cfloat>
#include <cmath>
#include <algorithm>

// ============================================================
// 射线 - AABB 相交测试（slab 方法）
// 用于未旋转的包围盒快速检测
// ============================================================
inline bool raycastAABB(
    const Vector3& origin,
    const Vector3& dir,
    const Vector3& center,
    const Vector3& halfExtent,
    double& tmin,
    double& tmax
) {
    tmin = 0.0;
    tmax = FLT_MAX;

    Vector3 bmin(center.x - halfExtent.x, center.y - halfExtent.y, center.z - halfExtent.z);
    Vector3 bmax(center.x + halfExtent.x, center.y + halfExtent.y, center.z + halfExtent.z);

    for (int i = 0; i < 3; i++) {
        double o = origin[i];
        double d = dir[i];

        if (std::abs(d) < 1e-8) {
            // 射线平行于 slab
            if (o < bmin[i] || o > bmax[i]) {
                return false;
            }
        } else {
            double t1 = (bmin[i] - o) / d;
            double t2 = (bmax[i] - o) / d;

            if (t1 > t2) std::swap(t1, t2);

            tmin = std::max(tmin, t1);
            tmax = std::min(tmax, t2);

            if (tmin > tmax) {
                return false;
            }
        }
    }

    return true;
}

// ============================================================
// 获取 OBB 的三个轴（从四元数旋转）
// ============================================================
inline void getOBBAxis(
    const Quaternion& rot,
    Vector3 axis[3]
) {
    float xx = rot.x * rot.x;
    float yy = rot.y * rot.y;
    float zz = rot.z * rot.z;

    float xy = rot.x * rot.y;
    float xz = rot.x * rot.z;
    float yz = rot.y * rot.z;

    float wx = rot.w * rot.x;
    float wy = rot.w * rot.y;
    float wz = rot.w * rot.z;

    axis[0] = Vector3(
        1.0f - 2.0f * (yy + zz),
        2.0f * (xy + wz),
        2.0f * (xz - wy)
    );

    axis[1] = Vector3(
        2.0f * (xy - wz),
        1.0f - 2.0f * (xx + zz),
        2.0f * (yz + wx)
    );

    axis[2] = Vector3(
        2.0f * (xz + wy),
        2.0f * (yz - wx),
        1.0f - 2.0f * (xx + yy)
    );
}

// ============================================================
// 射线 - 球体相交测试
// ============================================================
inline bool raycastSphere(
    const Vector3& origin,
    const Vector3& dir,
    const Vector3& center,
    float radius,
    double& t
) {
    Vector3 oc = origin - center;
    double a = dir.dot(dir);
    double b = 2.0 * oc.dot(dir);
    double c = oc.dot(oc) - static_cast<double>(radius) * static_cast<double>(radius);

    double discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0) return false;

    double sqrtDisc = std::sqrt(discriminant);
    double t0 = (-b - sqrtDisc) / (2.0 * a);
    double t1 = (-b + sqrtDisc) / (2.0 * a);

    if (t0 > 0) { t = t0; return true; }
    if (t1 > 0) { t = t1; return true; }
    return false;
}

// ============================================================
// 射线 - OBB 相交测试（变换到局部空间后用 slab 方法）
// ============================================================
inline bool raycastOBB(
    const Vector3& origin,
    const Vector3& dir,
    const Vector3& center,
    const Quaternion& rotation,
    const Vector3& halfExtent,
    double& t
) {
    // 计算 OBB 的三个轴
    Vector3 axis[3];
    getOBBAxis(rotation, axis);

    // 将射线变换到 OBB 局部空间
    Vector3 p = origin - center;
    Vector3 localOrigin;
    localOrigin.x = p.dot(axis[0]);
    localOrigin.y = p.dot(axis[1]);
    localOrigin.z = p.dot(axis[2]);

    Vector3 localDir;
    localDir.x = dir.dot(axis[0]);
    localDir.y = dir.dot(axis[1]);
    localDir.z = dir.dot(axis[2]);

    // 使用 slab 方法在局部空间进行射线-AABB 测试
    double tmin = 0.0, tmax = FLT_MAX;

    for (int i = 0; i < 3; i++) {
        double o = localOrigin[i];
        double d = localDir[i];
        float e = static_cast<float>(halfExtent[i]);

        if (std::abs(d) < 1e-8) {
            // 射线平行于 slab
            if (o < -e || o > e) return false;
        } else {
            double t1 = (-e - o) / d;
            double t2 = (e - o) / d;
            if (t1 > t2) std::swap(t1, t2);
            tmin = std::max(tmin, t1);
            tmax = std::min(tmax, t2);
            if (tmin > tmax) return false;
        }
    }

    t = tmin;
    return tmin >= 0;
}

#endif // DAYNOTE_RAYCAST_H
