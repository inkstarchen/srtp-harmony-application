# 物理系统文档索引

> **物理系统定位**：自研 C++ 物理引擎，为 DayNote 提供刚体动力学、碰撞检测与响应、射线检测等核心能力

---

## 📚 文档导航

### 1. [API 接口使用说明](./API接口使用说明.md)

**适用对象**：ArkTS 层开发者、物理系统集成者

**内容概览**：
- 物理系统初始化与生命周期管理
- 节点创建与属性设置接口
- 事件队列使用规范（触摸、射线、旋转等）
- FloatBuffer 数据读取指南
- 布局系统接口
- 完整使用示例

**何时查阅**：
- 需要在 ArkTS 中使用物理系统时
- 了解如何创建节点、发送事件、读取物理状态时
- 集成物理系统到业务代码时

---

### 2. [内部模块实现](./内部模块实现.md)

**适用对象**：C++ 物理引擎维护者、性能优化者

**内容概览**：
- SoA 内存布局设计与优化
- 物理模拟流水线架构
- 碰撞检测算法实现（SAT、射线检测）
- 碰撞响应机制（冲量法、摩擦、恢复系数）
- 旋转弹簧系统
- 自适应子步长与防穿透策略
- NAPI 绑定层实现

**何时查阅**：
- 需要修改物理引擎核心算法时
- 进行性能优化或调试碰撞问题时
- 理解物理系统内部工作原理时

---

### 3. [射线检测模块](../cpp/physics/physics/include/raycast.h)

**适用对象**：需要理解射线检测算法的开发者

**内容概览**：
- 射线-AABB 相交测试（slab 方法）
- 射线-OBB 相交测试（局部空间变换）
- 射线-球体相交测试
- OBB 轴提取（四元数旋转矩阵）

**代码位置**：`cpp/physics/physics/include/raycast.h`

---

## 🚀 快速开始

### 场景 1：在 ArkTS 中使用物理系统

```typescript
// 1. 创建物理系统
const physics = new PhysicsSystem(128);

// 2. 添加节点
const nodeId = physics.addNode({
  position: { x: 0, y: 0, z: 0 },
  rotation: { x: 0, y: 0, z: 0, w: 1 },
  scale: { x: 1, y: 1, z: 1 },
  extent: { x: 0.5, y: 0.5, z: 0.5 },
  shapeType: ShapeType.BOX,
  isStatic: false
});

// 3. 每帧更新
const result = physics.update(eventQueue, 0.016);
// 从 result.bufferData 读取物理状态
```

👉 详细教程：[API 接口使用说明 →](./API接口使用说明.md)

---

### 场景 2：修改碰撞检测算法

```cpp
// 1. 打开 collision.cpp
// 2. 找到 CollisionDispatch::table 矩阵
// 3. 添加新的碰撞函数对

// 示例：添加球体-OBB 碰撞
CollisionDispatch::table[SHAPE_SPHERE][SHAPE_BOX] = testSphereOBB;
```

👉 详细说明：[内部模块实现 →](./内部模块实现.md)

---

### 场景 3：添加新的射线检测形状

```cpp
// 1. 在 raycast.h 中添加射线检测函数
inline bool raycastNewShape(...) {
    // 实现射线检测算法
}

// 2. 在 PhysicsSystem::processRaycast 中调用
```

👉 算法参考：[raycast.h 源码 →](../cpp/physics/physics/include/raycast.h)

---

## 📊 物理系统架构概览

```
┌─────────────────────────────────────────────────────────┐
│                    ArkTS 应用层                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ PhysicsSystemManager.ets                          │   │
│  │ - 节点注册/注销                                   │   │
│  │ - 事件队列构建                                    │   │
│  │ - FloatBuffer 读取                                │   │
│  └────────────────────┬─────────────────────────────┘   │
└───────────────────────┼─────────────────────────────────┘
                        │ NAPI 调用
┌───────────────────────▼─────────────────────────────────┐
│                  C++ 物理引擎层                          │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  NAPI 绑定层 (bindings.h/cpp)                     │  │
│  │  - New / AddNode / Update / Release              │  │
│  └────────────────────┬─────────────────────────────┘  │
│                       │                                 │
│  ┌────────────────────▼─────────────────────────────┐  │
│  │  PhysicsSystem 核心类                             │  │
│  │                                                   │  │
│  │  ┌──────────────┐  ┌──────────────────────────┐  │  │
│  │  │ SoA 内存布局  │  │ 事件处理系统              │  │  │
│  │  │ (连续内存)    │  │ - 优先级队列              │  │  │
│  │  │ - 位置数组    │  │ - 事件分发                │  │  │
│  │  │ - 旋转数组    │  │ - 结果返回                │  │  │
│  │  │ - 速度数组    │  └──────────────────────────┘  │  │
│  │  │ - 力的数组    │                                 │  │
│  │  └──────┬───────┘                                 │  │
│  │         │                                          │  │
│  │  ┌──────▼──────────────────────────────────────┐  │  │
│  │  │ 物理模拟流水线                               │  │  │
│  │  │                                              │  │  │
│  │  │  1. 碰撞检测 (detectCollisions)              │  │  │
│  │  │  2. 构建接触点 (buildContacts)               │  │  │
│  │  │  3. 解算接触点 (solveContacts)               │  │  │
│  │  │  4. 应用旋转弹簧 (applyRotationSprings)      │  │  │
│  │  │  5. 速度积分 (integrateVelocity)             │  │  │
│  │  │  6. 速度限制 (clampVelocity)                 │  │  │
│  │  │  7. 位置修正 (positionalCorrection)          │  │  │
│  │  │  8. 位置积分 (integratePosition)             │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ 射线检测模块 (raycast.h)                      │  │  │
│  │  │ - raycastAABB (slab 方法)                     │  │  │
│  │  │ - raycastOBB (局部空间变换)                   │  │  │
│  │  │ - raycastSphere (二次方程求解)                │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 核心文件清单

| 文件路径 | 说明 | 文档参考 |
|---------|------|---------|
| `cpp/physics/physics/include/physicalSystem.h` | PhysicsSystem 类声明 | [内部模块实现](./内部模块实现.md) |
| `cpp/physics/physics/physicalSystem.cpp` | PhysicsSystem 实现 | [内部模块实现](./内部模块实现.md) |
| `cpp/physics/physics/include/raycast.h` | 射线检测算法 | [射线检测模块](../cpp/physics/physics/include/raycast.h) |
| `cpp/physics/physics/include/bindings.h` | NAPI 绑定接口 | [API 接口使用说明](./API接口使用说明.md) |
| `cpp/physics/physics/include/collision.h` | 碰撞分发器 | [内部模块实现](./内部模块实现.md) |
| `cpp/physics/physics/collision.cpp` | 碰撞检测实现 | [内部模块实现](./内部模块实现.md) |
| `cpp/physics/physics/include/contact.h` | 接触点结构体 | [内部模块实现](./内部模块实现.md) |
| `cpp/physics/physics/include/shape.h` | 形状类型枚举 | [API 接口使用说明](./API接口使用说明.md) |

---

## 📖 相关文档

- [系统架构文档](../系统架构文档.md) - DayNote 整体架构
- [2D3D交互融合功能设计文档](../2D3D交互融合功能设计文档.md) - 2D/3D 交互设计

---

## 📝 文档维护说明

- **API 接口使用说明**：当 NAPI 接口发生变化时更新
- **内部模块实现**：当物理引擎核心算法修改时更新
- **新增文档**：如需详细说明某个子系统（如布局系统、事件队列），可在本目录下创建新文档并更新本索引

---

**最后更新**：2026-05-09
