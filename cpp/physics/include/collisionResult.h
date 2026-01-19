//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_COLLISIONRESULT_H
#define DAYNOTE_COLLISIONRESULT_H

#include "vec.h"
#include "node.h"

// 碰撞结果结构体
struct CollisionResult {
    bool collided = false;
    double depth = 0.0;
    Vector3 normal;
    PhysicsNode* nodeA = nullptr;
    PhysicsNode* nodeB = nullptr;
    
    CollisionResult() = default;
};

#endif //DAYNOTE_COLLISIONRESULT_H
