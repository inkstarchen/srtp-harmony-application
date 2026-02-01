//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_NODE_H
#define DAYNOTE_NODE_H
#include <string>
#include "../../core/include/vec.h"

// 物理节点
struct PhysicsNode {
    std::string name;
    Vector3 position;
    Vector3 velocity;
    double mass;
    double radius;
    bool isStatic;

    // 构造函数
    PhysicsNode();
    PhysicsNode(const std::string& name, const Vector3& position, double mass, double radius, bool isStatic = false);

    // 预测下一帧位置（不考虑碰撞）
    Vector3 predictPosition(double deltaTime) const;
    
    // 应用力（改变速度）
    void applyForce(const Vector3& force, double deltaTime);
    
    // 更新位置
    void updatePosition(double deltaTime);
    
    // 设置初始速度
    void setVelocity(const Vector3& newVelocity);
    
    // 获取动能
    double getKineticEnergy() const;
    
    // 重置节点
    void reset();
};
#endif //DAYNOTE_NODE_H
