//
// Created on 2026/1/19.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_SIMULATOR_H
#define DAYNOTE_SIMULATOR_H

#include <vector>
#include "collisionResult.h"
#include "node.h"

class PhysicsSimulator {
private:
    std::vector<PhysicsNode> nodes;
    double gravity = 9.8;     // 重力加速度

public:
    // 构造函数
    PhysicsSimulator();
    PhysicsSimulator(double gravity);
    
    // 设置重力
    void setGravity(double newGravity);
    double getGravity() const;
    
    // 碰撞检测
    CollisionResult checkSphereCollision(const PhysicsNode& a, 
                                        const PhysicsNode& b,
                                        double deltaTime);
    
    // 弹性碰撞响应（动量守恒）
    void applyCollisionResponse(PhysicsNode& a, PhysicsNode& b, 
                               const Vector3& normal, double deltaTime);
    
    // 主更新函数
    void update(double deltaTime);
    
    // 带优化的更新函数（包含重力、碰撞检测和处理）
    void updateWithPhysics(double deltaTime, int collisionIterations = 4);
    
    // 添加节点
    void addNode(const PhysicsNode& node);
    void addNode(const std::string& name, const Vector3& position, 
                double mass, double radius, bool isStatic = false);
    
    void setNodes(const std::vector<PhysicsNode> node_array);
    
    // 节点管理
    const std::vector<PhysicsNode>& getNodes() const;
    std::vector<PhysicsNode>& getMutableNodes();
    size_t getNodeCount() const;
    
    // 获取/设置节点
    PhysicsNode* getNodeByName(const std::string& name);
    bool removeNodeByName(const std::string& name);
    void clearAllNodes();
    
    // 工具函数
    void applyGravity(double deltaTime);
    std::vector<CollisionResult> detectAllCollisions(double deltaTime);
    void processCollisions(std::vector<CollisionResult>& collisions, 
                          double deltaTime, int iterations = 1);
    
    // 空间优化版本（可选）
    std::vector<CollisionResult> detectCollisionsWithOptimization(double deltaTime);
};
#endif //DAYNOTE_SIMULATOR_H
