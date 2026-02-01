//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#include "include/node.h"

// 构造函数实现
PhysicsNode::PhysicsNode() 
    : name(""), position(Vector3()), velocity(Vector3()), 
      mass(1.0), radius(0.5), isStatic(false) {}

PhysicsNode::PhysicsNode(const std::string& name, const Vector3& position, 
                         double mass, double radius, bool isStatic)
    : name(name), position(position), velocity(Vector3()), 
      mass(mass), radius(radius), isStatic(isStatic) {
    // 确保质量为正
    if (mass <= 0) {
        this->mass = 1.0;
    }
    // 确保半径为非负
    if (radius < 0) {
        this->radius = 0.5;
    }
}

// 预测下一帧位置（不考虑碰撞）
Vector3 PhysicsNode::predictPosition(double deltaTime) const {
    if (isStatic) return position;
    return position + (velocity * deltaTime);
}

// 应用力（改变速度）
void PhysicsNode::applyForce(const Vector3& force, double deltaTime) {
    if (isStatic) return;
    // F = ma => a = F/m
    Vector3 acceleration = force * (1.0 / mass);
    velocity = velocity + (acceleration * deltaTime);
}

// 更新位置
void PhysicsNode::updatePosition(double deltaTime) {
    if (isStatic) return;
    position = position + (velocity * deltaTime);
}

// 设置初始速度
void PhysicsNode::setVelocity(const Vector3& newVelocity) {
    if (!isStatic) {
        velocity = newVelocity;
    }
}

// 获取动能
double PhysicsNode::getKineticEnergy() const {
    if (isStatic) return 0.0;
    return 0.5 * mass * velocity.dot(velocity);
}

// 重置节点
void PhysicsNode::reset() {
    velocity = Vector3();
    // 注意：position 和 其他属性保持原样
}