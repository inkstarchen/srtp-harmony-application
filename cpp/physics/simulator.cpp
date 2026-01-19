#include "simulator.h"
#include <algorithm>

// 构造函数
PhysicsSimulator::PhysicsSimulator() : gravity(9.8) {}

PhysicsSimulator::PhysicsSimulator(double gravity) : gravity(gravity) {}

// 设置重力
void PhysicsSimulator::setGravity(double newGravity) {
    gravity = newGravity;
}

double PhysicsSimulator::getGravity() const {
    return gravity;
}

// 检测球体碰撞
CollisionResult PhysicsSimulator::checkSphereCollision(const PhysicsNode& a, 
                                                      const PhysicsNode& b,
                                                      double deltaTime) {
    CollisionResult result;

    // 静态物体不参与相互碰撞
    if (a.isStatic && b.isStatic) return result;

    // 预测位置
    Vector3 posA = a.predictPosition(deltaTime);
    Vector3 posB = b.predictPosition(deltaTime);

    // 计算距离
    Vector3 delta = posA - posB;
    double distance = delta.length();
    double minDistance = a.radius + b.radius;

    // 检查碰撞
    if (distance < minDistance && distance > 0.0001) {
        result.collided = true;
        result.depth = minDistance - distance;
        result.normal = delta.normalized();
        // 注意：这里使用了const_cast，确保原始代码中的node是非const
        result.nodeA = const_cast<PhysicsNode*>(&a);
        result.nodeB = const_cast<PhysicsNode*>(&b);
    }

    return result;
}

// 弹性碰撞响应（动量守恒）
void PhysicsSimulator::applyCollisionResponse(PhysicsNode& a, PhysicsNode& b, 
                                             const Vector3& normal, double deltaTime) {
    // 注释掉的return语句会阻止碰撞响应执行
    // return;
    
    if (a.isStatic && b.isStatic) return;

    // 相对速度
    Vector3 relativeVel = b.velocity - a.velocity;
    double velAlongNormal = relativeVel.dot(normal);

    // 如果物体正在分离，不做处理
    if (velAlongNormal > 0) return;

    // 恢复系数（0.8表示80%的动能保留）
    double restitution = 0.8;

    // 计算冲量
    double impulseScalar = -(1 + restitution) * velAlongNormal;

    if (!a.isStatic && !b.isStatic) {
        // 两个都是动态物体
        impulseScalar /= (1/a.mass + 1/b.mass);

        Vector3 impulse = normal * impulseScalar;
        a.velocity = a.velocity - impulse * (1/a.mass);
        b.velocity = b.velocity + impulse * (1/b.mass);
    } else if (a.isStatic) {
        // a是静态物体
        impulseScalar /= (1/b.mass);
        b.velocity = b.velocity + normal * impulseScalar * (1/b.mass);
    } else {
        // b是静态物体
        impulseScalar /= (1/a.mass);
        a.velocity = a.velocity - normal * impulseScalar * (1/a.mass);
    }

    // 位置修正（防止穿透）- 暂时注释掉
    // Vector3 correction = normal * (result.depth / (1/a.mass + 1/b.mass) * 0.2);
    // if (!a.isStatic) a.position = a.position - correction * (1/a.mass);
    // if (!b.isStatic) b.position = b.position + correction * (1/b.mass);
}

// 主更新函数（简单版本）
void PhysicsSimulator::update(double deltaTime) {
    // 简单更新位置
    for (auto& node : nodes) {
        if (!node.isStatic) {
            node.updatePosition(deltaTime);
        }
    }
}

// 带优化的更新函数（包含重力、碰撞检测和处理）
void PhysicsSimulator::updateWithPhysics(double deltaTime, int collisionIterations) {
    // 应用重力
    applyGravity(deltaTime);
    
    // 碰撞检测
    std::vector<CollisionResult> collisions = detectAllCollisions(deltaTime);
    
    // 处理碰撞（多次迭代提高稳定性）
    processCollisions(collisions, deltaTime, collisionIterations);
    
    // 更新位置
    update(deltaTime);
}



// 添加节点
void PhysicsSimulator::addNode(const PhysicsNode& node) {
    nodes.push_back(node);
}

void PhysicsSimulator::addNode(const std::string& name, const Vector3& position, 
                              double mass, double radius, bool isStatic) {
    nodes.emplace_back(name, position, mass, radius, isStatic);
}

void PhysicsSimulator::setNodes(const std::vector<PhysicsNode> node_array) {
    nodes = node_array;
}

// 获取所有节点
const std::vector<PhysicsNode>& PhysicsSimulator::getNodes() const {
    return nodes;
}

std::vector<PhysicsNode>& PhysicsSimulator::getMutableNodes() {
    return nodes;
}

size_t PhysicsSimulator::getNodeCount() const {
    return nodes.size();
}

// 获取/设置节点
PhysicsNode* PhysicsSimulator::getNodeByName(const std::string& name) {
    auto it = std::find_if(nodes.begin(), nodes.end(), 
                          [&name](const PhysicsNode& node) {
                              return node.name == name;
                          });
    return (it != nodes.end()) ? &(*it) : nullptr;
}

bool PhysicsSimulator::removeNodeByName(const std::string& name) {
    auto it = std::remove_if(nodes.begin(), nodes.end(), 
                            [&name](const PhysicsNode& node) {
                                return node.name == name;
                            });
    if (it != nodes.end()) {
        nodes.erase(it, nodes.end());
        return true;
    }
    return false;
}

void PhysicsSimulator::clearAllNodes() {
    nodes.clear();
}

// 工具函数
void PhysicsSimulator::applyGravity(double deltaTime) {
    for (auto& node : nodes) {
        if (!node.isStatic) {
            // 应用重力（假设重力沿y轴负方向）
            node.applyForce(Vector3(0, -gravity * node.mass, 0), deltaTime);
        }
    }
}

std::vector<CollisionResult> PhysicsSimulator::detectAllCollisions(double deltaTime) {
    std::vector<CollisionResult> collisions;
    
    // 简单实现：检测所有物体对（可以优化为八叉树或BVH）
    for (size_t i = 0; i < nodes.size(); i++) {
        for (size_t j = i + 1; j < nodes.size(); j++) {
            auto result = checkSphereCollision(nodes[i], nodes[j], deltaTime);
            if (result.collided) {
                collisions.push_back(result);
            }
        }
    }
    
    return collisions;
}

void PhysicsSimulator::processCollisions(std::vector<CollisionResult>& collisions, 
                                        double deltaTime, int iterations) {
    for (int iter = 0; iter < iterations; iter++) {
        for (auto& collision : collisions) {
            if (collision.nodeA && collision.nodeB) {
                applyCollisionResponse(*collision.nodeA, *collision.nodeB, 
                                      collision.normal, deltaTime);
            }
        }
    }
}

// 空间优化版本（示例，需要更复杂的实现）
std::vector<CollisionResult> PhysicsSimulator::detectCollisionsWithOptimization(double deltaTime) {
    std::vector<CollisionResult> collisions;
    
    // 简单的空间分割优化：按位置分桶
    // TODO: 实现网格或八叉树优化
    
    // 临时使用朴素方法
    return detectAllCollisions(deltaTime);
}