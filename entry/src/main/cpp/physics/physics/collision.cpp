//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#include <cfloat>
#include "collision.h"
#include "utils.h"
#include "physicalSystem.h"

namespace Collision {
static void getOBBAxis(
    Quaternion rot,
    Vector3 axis[3])
{
    float xx = rot.x * rot.x;
    float yy = rot.y * rot.y;
    float zz = rot.z * rot.z;

    float xy = rot.x * rot.y;
    float xz = rot.x * rot.z;
    float yz = rot.y * rot.z;

    float wx = rot.w * rot.x;
    float wy = rot.w * rot.y;
    float wz = rot.w * rot.z;

    axis[0] = {
        1 - 2*(yy + zz),
        2*(xy + wz),
        2*(xz - wy)
    };

    axis[1] = {
        2*(xy - wz),
        1 - 2*(xx + zz),
        2*(yz + wx)
    };

    axis[2] = {
        2*(xz + wy),
        2*(yz - wx),
        1 - 2*(xx + yy)
    };
}

// 用于 SOA 的 OBB 顶点计算
inline void getOBBVerticesSOA(
    const PhysicsSystem& physics, uint32_t id,
    Vector3 out[8])
{
    Vector3 axis[3];
    getOBBAxis(
        Quaternion{
            physics.rot_x[id], physics.rot_y[id],
            physics.rot_z[id], physics.rot_w[id]
        }, axis
    );

    Vector3 center{physics.pos_x[id], physics.pos_y[id], physics.pos_z[id]};
    float ex = physics.extent_x[id], ey = physics.extent_y[id], ez = physics.extent_z[id];
    int idx = 0;
    for(int ix=-1; ix<=1; ix+=2)
        for(int iy=-1; iy<=1; iy+=2)
            for(int iz=-1; iz<=1; iz+=2)
                out[idx++] = center + axis[0]*ex*ix + axis[1]*ey*iy + axis[2]*ez*iz;
}

// Sphere-Sphere Contact
inline void generateContactSphereSphereSOA(
    const PhysicsSystem& physics,
    uint32_t idA, uint32_t idB,
    Contact& c)
{
    Vector3 d{physics.pos_x[idB]-physics.pos_x[idA],
              physics.pos_y[idB]-physics.pos_y[idA],
              physics.pos_z[idB]-physics.pos_z[idA]};
    float dist = sqrtf(d.x*d.x+d.y*d.y+d.z*d.z);
    float r = physics.extent_x[idA]+physics.extent_x[idB];
    if(dist<1e-6f) return;
    Vector3 n = d/dist;  // n 从 A 指向 B，需要翻转
    c.normal = n * -1.0f;  // 法线指向 A（从 B 指向 A）
    c.penetration = r - dist;
    c.point = Vector3{
        physics.pos_x[idA] + (-n.x)*physics.extent_x[idA],
        physics.pos_y[idA] + (-n.y)*physics.extent_x[idA],
        physics.pos_z[idA] + (-n.z)*physics.extent_x[idA]
    };
}

// Sphere vs OBB (SOA)
inline void generateContactSphereOBBSOA(
    const PhysicsSystem& physics,
    uint32_t sphereId, uint32_t boxId,
    Contact& c)
{
    // Sphere center
    Vector3 p{physics.pos_x[sphereId], physics.pos_y[sphereId], physics.pos_z[sphereId]};

    // Box center
    Vector3 center{physics.pos_x[boxId], physics.pos_y[boxId], physics.pos_z[boxId]};

    // OBB 局部轴
    Vector3 axis[3];
    Collision::getOBBAxis(
        Quaternion{physics.rot_x[boxId], physics.rot_y[boxId],
                   physics.rot_z[boxId], physics.rot_w[boxId]},
        axis
    );

    // Project Sphere center onto OBB
    float qx = center.x, qy = center.y, qz = center.z;
    float d[3] = {static_cast<float>(p.x - center.x), static_cast<float>(p.y - center.y), static_cast<float>(p.z - center.z)};
    float extent[3] = {physics.extent_x[boxId], physics.extent_y[boxId], physics.extent_z[boxId]};

    for(int i=0;i<3;i++){
        float dist = d[0]*axis[i].x + d[1]*axis[i].y + d[2]*axis[i].z;
        dist = clamp(dist, -extent[i], extent[i]);
        qx += axis[i].x * dist;
        qy += axis[i].y * dist;
        qz += axis[i].z * dist;
    }

    Vector3 closest{qx,qy,qz};
    Vector3 diff = p - closest;
    float dist2 = diff.dot(diff);
    float r = physics.extent_x[sphereId];

    if(dist2 > r*r) return; // no contact

    float dist = sqrtf(dist2);
    Vector3 n = dist>1e-6f ? diff/dist : Vector3{1,0,0};

    c.normal = n;
    c.penetration = r - dist;
    c.point = closest; // 接触点在 OBB 表面最靠近球的点
}

// OBB-OBB Contact (完备版)
inline void generateContactOBBOBBSOA(
    const PhysicsSystem& physics,
    uint32_t idA, uint32_t idB,
    Contact& c)
{
    // 1. 获取 OBB 轴和中心
    Vector3 axisA[3], axisB[3];
    Collision::getOBBAxis(
        Quaternion{physics.rot_x[idA], physics.rot_y[idA], physics.rot_z[idA], physics.rot_w[idA]}, axisA);
    Collision::getOBBAxis(
        Quaternion{physics.rot_x[idB], physics.rot_y[idB], physics.rot_z[idB], physics.rot_w[idB]}, axisB);

    Vector3 centerA{physics.pos_x[idA], physics.pos_y[idA], physics.pos_z[idA]};
    Vector3 centerB{physics.pos_x[idB], physics.pos_y[idB], physics.pos_z[idB]};
    Vector3 tVec = centerB - centerA;

    float R[3][3], AbsR[3][3];
    const float EPSILON = 1e-6f;
    for(int i=0;i<3;i++)
        for(int j=0;j<3;j++){
            R[i][j] = axisA[i].dot(axisB[j]);
            AbsR[i][j] = fabsf(R[i][j])+EPSILON;
        }

    float t[3] = { static_cast<float>(tVec.dot(axisA[0])),
                   static_cast<float>(tVec.dot(axisA[1])),
                   static_cast<float>(tVec.dot(axisA[2])) };
    float extentA[3] = {physics.extent_x[idA], physics.extent_y[idA], physics.extent_z[idA]};
    float extentB[3] = {physics.extent_x[idB], physics.extent_y[idB], physics.extent_z[idB]};

    float minPen = FLT_MAX;
    Vector3 bestAxis;
    int bestAxisType = -1; // 0=A face, 1=B face, 2=cross
    int bestAxisIndex = -1;

    // A 的 3 个面法线轴
    for(int i=0;i<3;i++){
        float ra = extentA[i];
        float rb = extentB[0]*AbsR[i][0]+extentB[1]*AbsR[i][1]+extentB[2]*AbsR[i][2];
        float pen = ra+rb - fabsf(t[i]);
        if(pen<0) return; // 分离轴，无碰撞
        if(pen<minPen){
            minPen=pen;
            bestAxis = t[i]>0 ? axisA[i]*-1.0f : axisA[i];
            bestAxisType = 0;
            bestAxisIndex = i;
        }
    }

    // B 的 3 个面法线轴
    for(int i=0;i<3;i++){
        float ra = extentA[0]*AbsR[0][i]+extentA[1]*AbsR[1][i]+extentA[2]*AbsR[2][i];
        float rb = extentB[i];
        float val = t[0]*R[0][i]+t[1]*R[1][i]+t[2]*R[2][i];
        float pen = ra+rb - fabsf(val);
        if(pen<0) return;
        if(pen<minPen){
            minPen=pen;
            bestAxis = val>0 ? axisB[i]*-1.0f : axisB[i];
            bestAxisType = 1;
            bestAxisIndex = i;
        }
    }

    // 9 个交叉轴 (A_i × B_j)
    for(int i=0;i<3;i++){
        for(int j=0;j<3;j++){
            Vector3 cross = axisA[i].cross(axisB[j]);
            float crossLen = cross.length();
            if(crossLen < EPSILON) continue; // 平行轴，跳过
            cross = cross / crossLen;

            // 投影到交叉轴
            float ra = extentA[(i+1)%3]*AbsR[(i+2)%3][j] + extentA[(i+2)%3]*AbsR[(i+1)%3][j];
            float rb = extentB[(j+1)%3]*AbsR[i][(j+2)%3] + extentB[(j+2)%3]*AbsR[i][(j+1)%3];
            
            // 计算 t 在交叉轴上的投影
            float val = fabsf(
                t[(i+2)%3]*R[(i+1)%3][j] - t[(i+1)%3]*R[(i+2)%3][j]
            );
            float pen = ra+rb - val;
            if(pen<0) return;
            if(pen<minPen){
                minPen=pen;
                // 法线方向：确保指向 A
                float dot = cross.dot(tVec);
                bestAxis = dot>0 ? cross*-1.0f : cross;
                bestAxisType = 2;
                bestAxisIndex = i*3+j;
            }
        }
    }

    c.normal = bestAxis;
    c.penetration = minPen;

    // 2. 生成接触点 - 使用参考面-入射面方法
    Vector3 vertsA[8], vertsB[8];
    getOBBVerticesSOA(physics, idA, vertsA);
    getOBBVerticesSOA(physics, idB, vertsB);

    // 确定参考面（reference face）和入射面（incident face）
    // 参考面是法线方向上面积最大的面
    Vector3 refAxis[4]; // 参考面的 4 条边方向
    Vector3 incidentVerts[8];
    int incidentCount = 0;

    if(bestAxisType == 0){
        // A 的面作为参考面
        int idx = bestAxisIndex;
        Vector3 refNormal = axisA[idx];
        float refDist = refNormal.dot(centerA) - extentA[idx];

        // 找出 B 在参考面法线方向上穿透的顶点
        for(int i=0;i<8;i++){
            float dist = refNormal.dot(vertsB[i]) - refDist;
            if(dist > 0){ // 穿透参考面
                incidentVerts[incidentCount++] = vertsB[i];
            }
        }

        // 如果没找到穿透顶点，使用最近顶点
        if(incidentCount == 0){
            float minDist = FLT_MAX;
            for(int i=0;i<8;i++){
                float dist = fabsf(refNormal.dot(vertsB[i]) - refDist);
                if(dist < minDist){
                    minDist = dist;
                    incidentVerts[0] = vertsB[i];
                    incidentCount = 1;
                }
            }
        }
    } else {
        // B 的面作为参考面
        int idx = bestAxisIndex;
        Vector3 refNormal = axisB[idx];
        float refDist = refNormal.dot(centerB) - extentB[idx];

        // 找出 A 在参考面法线方向上穿透的顶点
        for(int i=0;i<8;i++){
            float dist = refNormal.dot(vertsA[i]) - refDist;
            if(dist > 0){
                incidentVerts[incidentCount++] = vertsA[i];
            }
        }

        if(incidentCount == 0){
            float minDist = FLT_MAX;
            for(int i=0;i<8;i++){
                float dist = fabsf(refNormal.dot(vertsA[i]) - refDist);
                if(dist < minDist){
                    minDist = dist;
                    incidentVerts[0] = vertsA[i];
                    incidentCount = 1;
                }
            }
        }
    }

    // 3. 计算接触点 - 取穿透顶点的平均
    if(incidentCount > 0){
        Vector3 avg{0,0,0};
        for(int i=0;i<incidentCount;i++){
            avg += incidentVerts[i];
        }
        c.point = avg * (1.0f / (float)incidentCount);
    } else {
        // fallback: 两个 OBB 中心的中间点
        c.point = (centerA + centerB) * 0.5f;
    }
}

Vector3 getVelocityAtPoint(const PhysicsSystem& physics, uint32_t id, const Vector3& point)
{
    // r = point - pos
    float rx = point.x - physics.pos_x[id];
    float ry = point.y - physics.pos_y[id];
    float rz = point.z - physics.pos_z[id];

    // angVel × r
    float vx = physics.angVel_x[id] * rz - physics.angVel_z[id] * ry;
    float vy = physics.angVel_z[id] * rx - physics.angVel_x[id] * rz;
    float vz = physics.angVel_x[id] * ry - physics.angVel_y[id] * rx;

    // add linear velocity
    vx += physics.vel_x[id];
    vy += physics.vel_y[id];
    vz += physics.vel_z[id];

    return Vector3{vx, vy, vz};
}


bool AABBvsAABB(
    const Vector3& aPos, const Vector3& aExt,
    const Vector3& bPos, const Vector3& bExt)
{
    return
        std::abs(aPos.x - bPos.x) <= (aExt.x + bExt.x) &&
        std::abs(aPos.y - bPos.y) <= (aExt.y + bExt.y) &&
        std::abs(aPos.z - bPos.z) <= (aExt.z + bExt.z);
}

bool AABBvsSphere(
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

// Sphere vs Sphere
bool SpherevsSphere(const PhysicsSystem& physics, uint32_t idA, uint32_t idB)
{
    float dx = physics.pos_x[idB] - physics.pos_x[idA];
    float dy = physics.pos_y[idB] - physics.pos_y[idA];
    float dz = physics.pos_z[idB] - physics.pos_z[idA];

    float r = physics.extent_x[idA] + physics.extent_x[idB];

    return dx*dx + dy*dy + dz*dz <= r*r;
}

// Sphere vs OBB
bool SpherevsOBB(const PhysicsSystem& physics, uint32_t sphereId, uint32_t boxId)
{
    float px = physics.pos_x[sphereId];
    float py = physics.pos_y[sphereId];
    float pz = physics.pos_z[sphereId];

    float cx = physics.pos_x[boxId];
    float cy = physics.pos_y[boxId];
    float cz = physics.pos_z[boxId];

    float dx = px - cx;
    float dy = py - cy;
    float dz = pz - cz;

    // 计算 OBB 的局部轴
    Vector3 axis[3];
    getOBBAxis(Quaternion{
        physics.rot_x[boxId], physics.rot_y[boxId],
        physics.rot_z[boxId], physics.rot_w[boxId]
    }, axis);

    // 投影到盒子轴上
    float qx = cx, qy = cy, qz = cz;
    float extent[3] = { physics.extent_x[boxId], physics.extent_y[boxId], physics.extent_z[boxId] };
    float d[3] = { dx, dy, dz };

    for(int i=0; i<3; i++){
        float dist = d[0]*axis[i].x + d[1]*axis[i].y + d[2]*axis[i].z;
        dist = clamp(dist, -extent[i], extent[i]);
        qx += axis[i].x * dist;
        qy += axis[i].y * dist;
        qz += axis[i].z * dist;
    }

    float diffx = px - qx;
    float diffy = py - qy;
    float diffz = pz - qz;

    float r = physics.extent_x[sphereId];

    return diffx*diffx + diffy*diffy + diffz*diffz <= r*r;
}

// OBB vs Sphere
bool OBBvsSphere(const PhysicsSystem& physics, uint32_t boxId, uint32_t sphereId)
{
    // 直接调用 SpherevsOBB，顺序翻转即可
    return SpherevsOBB(physics, sphereId, boxId);
}

// OBB vs OBB
bool OBBvsOBB(const PhysicsSystem& physics, uint32_t idA, uint32_t idB)
{
    // 取盒子 A 的轴
    Vector3 axisA[3];
    getOBBAxis(Quaternion{
        physics.rot_x[idA], physics.rot_y[idA],
        physics.rot_z[idA], physics.rot_w[idA]
    }, axisA);

    // 取盒子 B 的轴
    Vector3 axisB[3];
    getOBBAxis(Quaternion{
        physics.rot_x[idB], physics.rot_y[idB],
        physics.rot_z[idB], physics.rot_w[idB]
    }, axisB);

    float R[3][3], AbsR[3][3];
    const float EPSILON = 1e-6f;

    for(int i=0; i<3; i++){
        for(int j=0; j<3; j++){
            R[i][j] = axisA[i].x*axisB[j].x + axisA[i].y*axisB[j].y + axisA[i].z*axisB[j].z;
            AbsR[i][j] = fabsf(R[i][j]) + EPSILON;
        }
    }

    // 平移向量 t = B.pos - A.pos
    float tvec[3] = {
        physics.pos_x[idB] - physics.pos_x[idA],
        physics.pos_y[idB] - physics.pos_y[idA],
        physics.pos_z[idB] - physics.pos_z[idA]
    };

    float t[3] = {
        static_cast<float>(tvec[0]*axisA[0].x + tvec[1]*axisA[0].y + tvec[2]*axisA[0].z),
        static_cast<float>(tvec[0]*axisA[1].x + tvec[1]*axisA[1].y + tvec[2]*axisA[1].z),
        static_cast<float>(tvec[0]*axisA[2].x + tvec[1]*axisA[2].y + tvec[2]*axisA[2].z)
    };

    float extentA[3] = { physics.extent_x[idA], physics.extent_y[idA], physics.extent_z[idA] };
    float extentB[3] = { physics.extent_x[idB], physics.extent_y[idB], physics.extent_z[idB] };

    float ra, rb;

    // A face normals
    for(int i=0;i<3;i++){
        ra = extentA[i];
        rb = extentB[0]*AbsR[i][0] + extentB[1]*AbsR[i][1] + extentB[2]*AbsR[i][2];
        if(fabsf(t[i]) > ra + rb) return false;
    }

    // B face normals
    for(int i=0;i<3;i++){
        ra = extentA[0]*AbsR[0][i] + extentA[1]*AbsR[1][i] + extentA[2]*AbsR[2][i];
        rb = extentB[i];
        float val = fabsf(t[0]*R[0][i] + t[1]*R[1][i] + t[2]*R[2][i]);
        if(val > ra + rb) return false;
    }

    // Cross products
    for(int i=0;i<3;i++){
        for(int j=0;j<3;j++){
            ra = extentA[(i+1)%3]*AbsR[(i+2)%3][j] + extentA[(i+2)%3]*AbsR[(i+1)%3][j];
            rb = extentB[(j+1)%3]*AbsR[i][(j+2)%3] + extentB[(j+2)%3]*AbsR[i][(j+1)%3];
            float val = fabsf(
                t[(i+2)%3]*R[(i+1)%3][j] - t[(i+1)%3]*R[(i+2)%3][j]
            );
            if(val > ra + rb) return false;
        }
    }

    return true;
}

}

void ContactDispatch::dispatch(const PhysicsSystem &physics, uint32_t A, uint32_t B, Contact &c)
{
   ContactFunc f = table[physics.shapeType[A]][physics.shapeType[B]];
    if(f) f(physics, A, B, c);
}

void ContactDispatch::initContactDispatch()
{
    table[SHAPE_SPHERE][SHAPE_SPHERE]   = Collision::generateContactSphereSphereSOA;
    table[SHAPE_BOX][SHAPE_BOX]         = Collision::generateContactOBBOBBSOA;
    table[SHAPE_BOX][SHAPE_SPHERE]      = [](const PhysicsSystem& p,uint32_t a,uint32_t b,Contact& c){
        Collision::generateContactSphereOBBSOA(p,b,a,c);
        c.normal = c.normal * -1.0f; // 翻转法线指向 Box->Sphere
    };
    table[SHAPE_SPHERE][SHAPE_BOX]  = Collision::generateContactSphereOBBSOA; // 可以复用 Sphere->OBB
}

bool CollisionDispatch::dispatch(const PhysicsSystem &physics, const uint32_t A, const uint32_t B)
{
    CollisionFunc f = table[physics.shapeType[A]][physics.shapeType[B]];
    if(!f) return false;
    return f(physics, A, B);
}

void CollisionDispatch::initCollisionDispatch()
{
    CollisionDispatch::table[SHAPE_SPHERE][SHAPE_SPHERE] = Collision::SpherevsSphere;

    CollisionDispatch::table[SHAPE_BOX][SHAPE_BOX] = Collision::OBBvsOBB;

    CollisionDispatch::table[SHAPE_BOX][SHAPE_SPHERE] = Collision::OBBvsSphere;
    CollisionDispatch::table[SHAPE_SPHERE][SHAPE_BOX] = Collision::SpherevsOBB;
}

CollisionFunc CollisionDispatch::table[SHAPE_COUNT][SHAPE_COUNT] = {};
CollisionDispatch::Initializer CollisionDispatch::_initializer;

ContactFunc ContactDispatch::table[SHAPE_COUNT][SHAPE_COUNT] = {};
ContactDispatch::Initializer ContactDispatch::_initializer;