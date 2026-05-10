# 物理系统 API 接口使用说明

> **适用对象**：ArkTS 层开发者、物理系统集成者  
> **最后更新**：2026-05-09

---

## 目录

- [1. 物理系统概述](#1-物理系统概述)
- [2. 快速开始](#2-快速开始)
- [3. 核心接口详解](#3-核心接口详解)
- [4. 事件队列系统](#4-事件队列系统)
- [5. FloatBuffer 数据读取](#5-floatbuffer-数据读取)
- [6. 布局系统](#6-布局系统)
- [7. 完整使用示例](#7-完整使用示例)
- [8. 常见问题](#8-常见问题)

---

## 1. 物理系统概述

### 1.1 功能特性

DayNote 物理系统是一个自研的 3D 刚体物理引擎，提供以下核心能力：

| 特性 | 说明 |
|------|------|
| 刚体动力学 | 位置、速度、加速度模拟，重力系统 |
| 碰撞检测 | 球体-球体、OBB-OBB、射线-形状检测 |
| 碰撞响应 | 冲量法求解，支持摩擦系数和恢复系数 |
| 旋转系统 | 四元数旋转，旋转弹簧扰动恢复 |
| 射线检测 | 触摸拾取 3D 物体，返回命中位置和距离 |
| 自适应子步 | 防止快速物体穿透，动态调整模拟精度 |

### 1.2 技术特点

- **SoA 内存布局**：Structure of Arrays 设计，提升缓存命中率
- **零拷贝数据共享**：通过 FloatBuffer 直接引用 C++ 内存
- **事件驱动架构**：优先级队列 + 双缓冲机制
- **NAPI ObjectWrap**：类型安全的跨语言调用

---

## 2. 快速开始

### 2.1 创建物理系统

```typescript
import { PhysicsSystem } from '@ohos.physics';

// 创建物理系统实例，容量为 128 个节点
const physics = new PhysicsSystem(128);
```

**参数说明**：
- `capacity`（可选）：最大节点数量，默认 128
- 容量会在内存分配时对齐到 64 的倍数

### 2.2 添加物理节点

```typescript
const nodeId = physics.addNode({
  position: { x: 0, y: 0, z: 0 },      // 初始位置
  rotation: { x: 0, y: 0, z: 0, w: 1 }, // 初始旋转（四元数）
  scale: { x: 1, y: 1, z: 1 },          // 缩放比例
  extent: { x: 0.5, y: 0.5, z: 0.5 },   // 半长轴尺寸
  shapeType: ShapeType.BOX,             // 碰撞形状类型
  isStatic: false                       // 是否为静态物体
});

console.log('节点 ID:', nodeId);
```

### 2.3 每帧更新

```typescript
// 在渲染循环中调用
const result = physics.update(eventQueue, 0.016); // dt = 16ms (60fps)

// 从 FloatBuffer 读取物理状态
updateSceneFromBuffer(result.bufferData);

// 处理事件结果（如射线检测结果）
handleEventResults(result.results);
```

---

## 3. 核心接口详解

### 3.1 PhysicsSystem 类

#### 构造函数

```typescript
new PhysicsSystem(capacity?: number)
```

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| capacity | number | 否 | 最大节点容量，默认 128 |

**返回值**：PhysicsSystem 实例

---

#### addNode(nodeData: NodeData): number

创建新的物理节点并返回唯一 ID。

**参数**：`NodeData` 结构

```typescript
interface NodeData {
  position: { x: number; y: number; z: number };      // 位置
  rotation: { x: number; y: number; z: number; w: number }; // 旋转（四元数）
  scale: { x: number; y: number; z: number };         // 缩放
  extent: { x: number; y: number; z: number };        // 半长轴尺寸
  shapeType: ShapeType;                               // 形状类型
  isStatic: boolean;                                  // 是否静态
}
```

**ShapeType 枚举**：

```typescript
enum ShapeType {
  BOX = 0,    // OBB（定向包围盒）
  SPHERE = 1  // 球体
}
```

**返回值**：节点 ID（uint32_t），用于后续操作

**注意事项**：
- 动态物体（`isStatic: false`）会受重力和碰撞影响
- 静态物体（`isStatic: true`）位置固定，但可参与碰撞检测
- 节点 ID 会复用已删除节点的空位

---

#### update(eventQueue: EventCommand[][], dt: number): UpdateResult

执行物理模拟步进。

**参数**：

| 参数 | 类型 | 说明 |
|------|------|------|
| eventQueue | EventCommand[][] | 事件队列（双缓冲结构） |
| dt | number | 时间步长（秒），通常 0.016 表示 60fps |

**返回值**：`UpdateResult` 结构

```typescript
interface UpdateResult {
  bufferData: Float32Array;  // 物理状态数据（零拷贝引用）
  results: EventResult[];    // 事件处理结果
}
```

---

#### release(): void

释放物理系统资源，重置所有节点。

**使用场景**：
- 切换场景时
- 应用退出前
- 需要完全重置物理状态时

```typescript
physics.release();
```

---

#### enableLayout(config: LayoutConfig): void

启用自动布局系统，节点会按网格排列。

**参数**：`LayoutConfig` 结构

```typescript
interface LayoutConfig {
  rows: number;          // 行数
  columns: number;       // 列数
  cellWidth: number;     // 格子宽度
  cellHeight: number;    // 格子高度
  cellDepth: number;     // 格子深度
  spacing: number;       // 格子间距
  origin: { x: number; y: number; z: number }; // 布局原点
}
```

**使用示例**：

```typescript
physics.enableLayout({
  rows: 3,
  columns: 3,
  cellWidth: 1.0,
  cellHeight: 1.0,
  cellDepth: 0.5,
  spacing: 0.1,
  origin: { x: -1.5, y: 1.5, z: 0 }
});
```

---

### 3.2 节点属性设置（通过事件队列）

节点属性不能直接修改，必须通过事件队列发送设置请求：

```typescript
// 创建属性设置事件
const event: EventCommand = {
  type: EventType.SET_PROPERTY_REQUEST,
  priority: 0,  // HIGH priority
  nodeId: targetNodeId,
  timestamp: Date.now(),
  data: [
    Property.POS,  // 属性类型
    newX, newY, newPos.z  // 新值
  ]
};

eventQueue.push(event);
```

**可设置的属性**：

| Property | 说明 | data 数组内容 |
|----------|------|--------------|
| `POS` | 位置 | `[x, y, z]` |
| `ROTATION` | 旋转（四元数） | `[x, y, z, w]` |
| `VELOCITY` | 线速度 | `[vx, vy, vz]` |
| `ANGLE_VELOCITY` | 角速度 | `[wx, wy, wz]` |
| `SCALE` | 缩放 | `[sx, sy, sz]` |
| `MASS` | 质量 | `[mass]` |
| `RESTITUTION` | 恢复系数（弹性） | `[restitution]` |
| `FRICTION` | 摩擦系数 | `[friction]` |
| `STATIC` | 是否静态 | `[0 或 1]` |
| `CAN_ROTATE` | 是否可旋转 | `[0 或 1]` |
| `IMPULSE` | 施加冲量 | `[ix, iy, iz]` |
| `ROTATION_SPRING` | 旋转弹簧参数 | `[刚度K, 阻尼D]` |
| `REST_ROTATION` | 旋转弹簧目标 | `[x, y, z, w]`（四元数） |
| `CAMERA` | 相机参数 | `[posX, posY, posZ, fov, ratio]` |

---

## 4. 事件队列系统

### 4.1 事件类型

```typescript
enum EventType {
  TOUCH_DOWN = 100,          // 触摸按下
  TOUCH_MOVE = 101,          // 触摸移动
  TOUCH_UP = 102,            // 触摸释放
  ROTATE_REQUEST = 103,      // 旋转请求
  SET_PROPERTY_REQUEST = 104, // 属性设置
  RESET_GRAVITY = 105,       // 重置重力
  RAYCAST_REQUEST = 106      // 射线检测
}
```

### 4.2 事件优先级

| 优先级 | 值 | 事件类型 | 说明 |
|--------|-----|----------|------|
| HIGH | 0 | TOUCH_DOWN, TOUCH_MOVE, TOUCH_UP, SET_PROPERTY | 立即响应的交互 |
| NORMAL | 1 | RAYCAST_REQUEST, ROTATE_REQUEST | 需要计算的事件 |
| LOW | 2 | RESET_GRAVITY | 后台处理的事件 |

### 4.3 双缓冲机制

事件队列采用双缓冲设计，确保 ArkTS 写入和 C++ 读取不会冲突：

```typescript
// ArkTS 侧写入队列
writeQueue.push(event);

// 每帧交换队列
function swapQueues() {
  const temp = readQueue;
  readQueue = writeQueue;
  writeQueue = temp;
  writeQueue.clear();
}
```

### 4.4 常用事件构建

#### 触摸按下

```typescript
function createTouchDown(posX: number, posY: number): EventCommand {
  return {
    type: EventType.TOUCH_DOWN,
    priority: 0,
    nodeId: 0,
    timestamp: Date.now(),
    data: [posX, posY]
  };
}
```

#### 旋转请求

```typescript
function createRotateRequest(nodeId: number): EventCommand {
  return {
    type: EventType.ROTATE_REQUEST,
    priority: 1,
    nodeId: nodeId,
    timestamp: Date.now(),
    data: []
  };
}
```

#### 射线检测

```typescript
function createRaycast(screenX: number, screenY: number): EventCommand {
  // 转换屏幕坐标到视锥体坐标
  const fx = (2 * screenX / screenWidth) - 1;
  const fy = 1 - (2 * screenY / screenHeight);
  
  return {
    type: EventType.RAYCAST_REQUEST,
    priority: 1,
    nodeId: 0,
    timestamp: Date.now(),
    data: [fx, fy]
  };
}
```

#### 属性设置

```typescript
function createSetPosition(nodeId: number, x: number, y: number, z: number): EventCommand {
  return {
    type: EventType.SET_PROPERTY_REQUEST,
    priority: 0,
    nodeId: nodeId,
    timestamp: Date.now(),
    data: [Property.POS, x, y, z]
  };
}
```

### 4.5 事件结果处理

`update()` 返回的 `results` 数组包含事件处理结果：

```typescript
interface EventResult {
  type: EventType;       // 事件类型
  nodeId: number;        // 相关节点 ID
  timestamp: number;     // 时间戳
  status: number;        // 状态码（1=成功，0=失败）
  data: bigint[];        // 结果数据
}
```

**射线检测结果示例**：

```typescript
results.forEach(result => {
  if (result.type === EventType.RAYCAST_REQUEST && result.status === 1) {
    const hitNodeId = Number(result.data[0]);
    const distance = Number(result.data[1]);
    const hitPosX = Number(result.data[2]);
    const hitPosY = Number(result.data[3]);
    const hitPosZ = Number(result.data[4]);
    
    console.log(`命中节点 ${hitNodeId}，距离 ${distance}`);
  }
});
```

---

## 5. FloatBuffer 数据读取

### 5.1 SoA 内存布局

物理系统使用 Structure of Arrays (SoA) 布局，同类数据连续存储：

```
内存布局示意图：

[pos_x[0], pos_x[1], ..., pos_x[N]]  ← 所有 X 位置
[pos_y[0], pos_y[1], ..., pos_y[N]]  ← 所有 Y 位置
[pos_z[0], pos_z[1], ..., pos_z[N]]  ← 所有 Z 位置
[rot_x[0], rot_x[1], ..., rot_x[N]]  ← 所有 X 旋转
[rot_y[0], rot_y[1], ..., rot_y[N]]  ← 所有 Y 旋转
[rot_z[0], rot_z[1], ..., rot_z[N]]  ← 所有 Z 旋转
[rot_w[0], rot_w[1], ..., rot_w[N]]  ← 所有 W 旋转
[scale_x[0], scale_x[1], ...]        ← 所有 X 缩放
...
```

### 5.2 数据偏移计算

```typescript
const capacity = 128; // 物理系统容量

function getNodePosition(buffer: Float32Array, nodeId: number): {x: number, y: number, z: number} {
  return {
    x: buffer[nodeId],                          // pos_x[nodeId]
    y: buffer[nodeId + capacity * 1],           // pos_y[nodeId]
    z: buffer[nodeId + capacity * 2]            // pos_z[nodeId]
  };
}

function getNodeRotation(buffer: Float32Array, nodeId: number): {x: number, y: number, z: number, w: number} {
  return {
    x: buffer[nodeId + capacity * 3],           // rot_x[nodeId]
    y: buffer[nodeId + capacity * 4],           // rot_y[nodeId]
    z: buffer[nodeId + capacity * 5],           // rot_z[nodeId]
    w: buffer[nodeId + capacity * 6]            // rot_w[nodeId]
  };
}

function getNodeScale(buffer: Float32Array, nodeId: number): {x: number, y: number, z: number} {
  return {
    x: buffer[nodeId + capacity * 7],           // scale_x[nodeId]
    y: buffer[nodeId + capacity * 8],           // scale_y[nodeId]
    z: buffer[nodeId + capacity * 9]            // scale_z[nodeId]
  };
}
```

### 5.3 完整读取示例

```typescript
function updateSceneFromBuffer(bufferData: Float32Array) {
  const capacity = 128;
  
  // 遍历所有活跃节点
  nodeMap.forEach((node, nodeId) => {
    // 读取位置
    const posX = bufferData[nodeId];
    const posY = bufferData[nodeId + capacity * 1];
    const posZ = bufferData[nodeId + capacity * 2];
    
    // 读取旋转
    const rotX = bufferData[nodeId + capacity * 3];
    const rotY = bufferData[nodeId + capacity * 4];
    const rotZ = bufferData[nodeId + capacity * 5];
    const rotW = bufferData[nodeId + capacity * 6];
    
    // 读取缩放
    const scaleX = bufferData[nodeId + capacity * 7];
    const scaleY = bufferData[nodeId + capacity * 8];
    const scaleZ = bufferData[nodeId + capacity * 9];
    
    // 更新场景节点
    node.position = { x: posX, y: posY, z: posZ };
    node.rotation = { x: rotX, y: rotY, z: rotZ, w: rotW };
    node.scale = { x: scaleX, y: scaleY, z: scaleZ };
  });
}
```

### 5.4 性能优化建议

1. **批量读取**：一次读取所有节点数据，避免频繁访问
2. **缓存容量值**：将 `capacity` 存储为常量，避免重复计算
3. **按需读取**：只读取需要的属性，减少不必要的数据访问
4. **使用 DataView 替代**：如果需要不同数据类型，可以使用 DataView

---

## 6. 布局系统

### 6.1 功能说明

布局系统提供自动网格排列功能，适用于：
- 卡片网格布局
- 自动排列的物理对象
- 需要规则间隔的场景

### 6.2 使用流程

```typescript
// 1. 启用布局系统
physics.enableLayout({
  rows: 3,
  columns: 3,
  cellWidth: 1.0,
  cellHeight: 1.0,
  cellDepth: 0.5,
  spacing: 0.1,
  origin: { x: -1.5, y: 1.5, z: 0 }
});

// 2. 添加节点（自动使用布局位置）
for (let i = 0; i < 9; i++) {
  const nodeId = physics.addNode({
    position: { x: 0, y: 0, z: 0 },  // 会被布局位置覆盖
    rotation: { x: 0, y: 0, z: 0, w: 1 },
    scale: { x: 1, y: 1, z: 1 },
    extent: { x: 0.5, y: 0.5, z: 0.5 },  // 会被格子尺寸覆盖
    shapeType: ShapeType.BOX,
    isStatic: true
  });
}

// 3. 禁用布局（可选）
physics.disableLayout();
```

### 6.3 布局系统特性

- **位置覆盖**：布局系统会覆盖 JS 传入的 position
- **尺寸覆盖**：extent 会被格子尺寸覆盖（半长轴）
- **旋转弹簧**：自动启用旋转弹簧系统，扰动后恢复
- **格子占用**：每个格子只能被一个节点占用

---

## 7. 完整使用示例

### 7.1 基础物理模拟场景

```typescript
import { PhysicsSystem, ShapeType, EventType, Property } from '@ohos.physics';

class PhysicsScene {
  private physics: PhysicsSystem;
  private eventQueue: EventCommand[][] = [[], []];
  private capacity: number = 128;
  private nodeMap: Map<number, SceneNode> = new Map();

  constructor() {
    // 创建物理系统
    this.physics = new PhysicsSystem(this.capacity);
  }

  // 初始化场景
  initScene() {
    // 添加地面（静态物体）
    this.physics.addNode({
      position: { x: 0, y: -2, z: 0 },
      rotation: { x: 0, y: 0, z: 0, w: 1 },
      scale: { x: 1, y: 1, z: 1 },
      extent: { x: 10, y: 0.1, z: 10 },
      shapeType: ShapeType.BOX,
      isStatic: true
    });

    // 添加自由落体的球体
    this.physics.addNode({
      position: { x: 0, y: 3, z: 0 },
      rotation: { x: 0, y: 0, z: 0, w: 1 },
      scale: { x: 1, y: 1, z: 1 },
      extent: { x: 0.5, y: 0.5, z: 0.5 },
      shapeType: ShapeType.SPHERE,
      isStatic: false
    });
  }

  // 渲染循环
  onFrame(deltaTime: number) {
    // 交换事件队列
    this.swapQueues();

    // 执行物理模拟
    const result = this.physics.update(this.eventQueue[0], deltaTime);

    // 同步物理状态到场景
    this.updateSceneFromBuffer(result.bufferData);

    // 处理事件结果
    this.handleEventResults(result.results);
  }

  // 触摸事件处理
  onTouchDown(posX: number, posY: number) {
    this.eventQueue[1].push({
      type: EventType.TOUCH_DOWN,
      priority: 0,
      nodeId: 0,
      timestamp: Date.now(),
      data: [posX, posY]
    });
  }

  // 私有方法
  private swapQueues() {
    const temp = this.eventQueue[0];
    this.eventQueue[0] = this.eventQueue[1];
    this.eventQueue[1] = temp;
    this.eventQueue[1].clear();
  }

  private updateSceneFromBuffer(bufferData: Float32Array) {
    this.nodeMap.forEach((node, nodeId) => {
      node.position.x = bufferData[nodeId];
      node.position.y = bufferData[nodeId + this.capacity * 1];
      node.position.z = bufferData[nodeId + this.capacity * 2];
    });
  }

  private handleEventResults(results: EventResult[]) {
    results.forEach(result => {
      // 处理事件结果
    });
  }
}
```

### 7.2 触摸旋转 3D 物体

```typescript
class TouchRotateExample {
  private selectedNodeId: number = 0;
  private lastTouchPos: { x: number, y: number } = { x: 0, y: 0 };

  onTouchDown(posX: number, posY: number) {
    // 发送射线检测
    this.eventQueue[1].push({
      type: EventType.RAYCAST_REQUEST,
      priority: 1,
      nodeId: 0,
      timestamp: Date.now(),
      data: [this.screenToFrustumX(posX), this.screenToFrustumY(posY)]
    });
    
    this.lastTouchPos = { x: posX, y: posY };
  }

  onTouchMove(posX: number, posY: number) {
    if (this.selectedNodeId > 0) {
      // 发送旋转请求
      this.eventQueue[1].push({
        type: EventType.ROTATE_REQUEST,
        priority: 1,
        nodeId: this.selectedNodeId,
        timestamp: Date.now(),
        data: []
      });
    }
    
    this.lastTouchPos = { x: posX, y: posY };
  }

  onEventResults(results: EventResult[]) {
    results.forEach(result => {
      if (result.type === EventType.RAYCAST_REQUEST && result.status === 1) {
        this.selectedNodeId = Number(result.data[0]);
        console.log('选中节点:', this.selectedNodeId);
      }
    });
  }
}
```

---

## 8. 常见问题

### Q1: 为什么节点位置没有更新？

**可能原因**：
1. 节点设置为 `isStatic: true`（静态物体不移动）
2. 没有调用 `update()` 方法
3. FloatBuffer 偏移计算错误

**排查方法**：
```typescript
// 检查节点是否静态
console.log('节点是否静态:', isStatic);

// 检查 update 调用
console.log('Update 返回数据:', result.bufferData.length);

// 打印位置数据
console.log('位置:', getNodePosition(result.bufferData, nodeId));
```

### Q2: 如何实现物体弹跳效果？

调整恢复系数（restitution）：

```typescript
// 设置高恢复系数（0.8 = 很弹）
eventQueue.push({
  type: EventType.SET_PROPERTY_REQUEST,
  priority: 0,
  nodeId: targetId,
  timestamp: Date.now(),
  data: [Property.RESTITUTION, 0.8]
});
```

### Q3: 如何防止物体穿透？

物理系统已内置自适应子步长和速度钳制。如仍有穿透：
1. 减小时间步长 `dt`
2. 增加物体 extent 尺寸
3. 降低物体速度

### Q4: FloatBuffer 数据何时更新？

每次调用 `update()` 后，FloatBuffer 会包含最新的物理状态。Buffer 是零拷贝引用，无需重新分配。

### Q5: 如何重置整个场景？

```typescript
physics.release();
// 重新添加节点
```

---

## 附录：接口速查表

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `new PhysicsSystem(capacity?)` | capacity?: number | PhysicsSystem | 创建物理系统 |
| `addNode(nodeData)` | NodeData | number | 添加节点 |
| `update(events, dt)` | EventCommand[][], number | UpdateResult | 物理步进 |
| `release()` | - | void | 释放资源 |
| `enableLayout(config)` | LayoutConfig | void | 启用布局 |
| `disableLayout()` | - | void | 禁用布局 |

---

**文档维护**：当 NAPI 接口发生变化时，请及时更新本文档
