# ArkTS 到 C++ 统一事件队列实现总结

## 一、已实现的功能

### 1. C++ 端组件

#### event_queue.h - 事件队列头文件
位置：`cpp/physics/event_queue/event_queue.h`

定义的数据结构：
- `EventType` 枚举：定义 6 种事件类型（NONE, TOUCH_DOWN, TOUCH_MOVE, TOUCH_UP, RAYCAST_REQUEST, ROTATE_REQUEST）
- `EventCommand` 结构体：40 字节的事件数据
- `EventQueue` 结构体：共享内存环形缓冲区（64 个事件容量）
- `EventQueueOps` 命名空间：提供线程安全的队列操作（push/pop/processAll）

关键特性：
- 使用 `alignas(64)` 确保缓存行对齐，避免伪共享
- 使用 `std::atomic` 和内存顺序（memory_order）确保正确的内存同步
- SPSC（单生产者单消费者）无锁设计

#### PhysicsSystem 扩展
位置：`cpp/physics/physics/physicalSystem.cpp` 和 `physicalSystem.h`

新增方法：
- `CreateEventQueue()`: 创建共享内存事件队列并返回 ArrayBuffer 给 ArkTS
- `GetSelectedNodeId()`: 获取当前选中的节点 ID
- `processEventQueue(float dt)`: 在 step() 中调用，处理所有待处理事件
- `processRaycast(float touchX, float touchY)`: 处理射线投射请求
- `processRotate(float deltaX, float deltaY)`: 处理旋转请求

事件处理流程集成：
```cpp
void PhysicsSystem::step(float dt) {
    // 1. 处理事件队列（新增）
    processEventQueue(dt);

    // 2. 碰撞检测
    detectCollisions();
    // ... 其他物理步骤
}
```

### 2. ArkTS 端组件

#### EventTypes.ets
位置：`ets/core/scene3D/EventTypes.ets`

定义：
- `EventType` 枚举（与 C++ 端一致）
- `EventCommand` 接口

#### EventQueue.ets
位置：`ets/core/scene3D/EventQueue.ets`

`EventQueueManager` 类提供的方法：
- `init(physicsSystem: PhysicsSystem)`: 初始化共享内存
- `pushTouchDown(x, y)`: 推送 Touch Down 事件
- `pushTouchMove(x, y, dx, dy)`: 推送 Touch Move 事件
- `pushTouchUp()`: 推送 Touch Up 事件
- `pushRaycastRequest(x, y)`: 推送 Raycast 请求
- `pushRotateRequest(nodeId, dx, dy)`: 推送 Rotate 请求
- `flush()`: 确保内存可见性
- `count()`: 获取队列中的事件数量

#### PhysicsSystemManager 扩展
位置：`ets/core/scene3D/PhysicsSystemManager.ets`

新增方法：
- `getPhysicsSystem()`: 获取底层 PhysicsSystem 实例
- `getNodeById(id: number)`: 根据物理 ID 查找节点
- `getSelectedNodeId()`: 获取 C++ 端选中的节点 ID

#### SceneProxy 扩展
位置：`ets/core/scene3D/SceneProxy.ets`

修改：
- 添加 `eventQueue: EventQueueManager` 成员
- 在 `update()` 中同步选中的节点 ID 到 `touchRotate.target`

#### PlayGround 修改
位置：`ets/pages/PlayGround.ets`

修改前（旧方案）：
```typescript
.onTouch(async (event) => {
  if(event.type == TouchType.Down){
    // 直接使用 ArkGraphics3D 的 raycast
    let result = await this.sceneProxy.camera?.raycast(...);
    this.sceneProxy.touchRotate.target = result[0].node;
  }
  if(event.type == TouchType.Move){
    // 直接调用 C++ setRotation
    this.sceneProxy.physicalSystem.setRotation(id, ...);
  }
})
```

修改后（新方案）：
```typescript
.onTouch((event) => {
  if(event.type == TouchType.Down){
    // 通过事件队列发送 Raycast 请求
    this.sceneProxy.eventQueue.pushRaycastRequest(fx, fy);
  }
  if(event.type == TouchType.Move){
    // 通过事件队列发送 Rotate 请求
    this.sceneProxy.eventQueue.pushRotateRequest(id, dx, dy);
  }
})
```

## 二、数据流图

```
┌─────────────────────────────────────────────────────────────┐
│                     ArkTS 端 (UI Thread)                     │
│  ┌──────────────┐                                           │
│  │  PlayGround  │                                           │
│  │  onTouch()   │                                           │
│  └──────┬───────┘                                           │
│         │                                                   │
│         ▼                                                   │
│  ┌──────────────┐     ┌─────────────────┐                   │
│  │ EventQueue   │────▶│  Shared Memory  │                   │
│  │ Manager      │push │  (ArrayBuffer)  │                   │
│  └──────────────┘     └────────┬────────┘                   │
└────────────────────────────────│────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                      C++ 端 (Physics Thread)                  │
│  ┌─────────────────┐     ┌─────────────────┐                 │
│  │ EventQueue      │◀────│  Shared Memory  │                 │
│  │ processQueue()  │pop  │                 │                 │
│  └────────┬────────┘     └─────────────────┘                 │
│           │                                                   │
│           ▼                                                   │
│  ┌────────────────┐    ┌──────────────────┐                  │
│  │ processRaycast │    │  processRotate   │                  │
│  │ (选中节点)      │    │  (旋转节点)       │                  │
│  └────────────────┘    └──────────────────┘                  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              PhysicsSystem::step(dt)                 │   │
│  │  1. processEventQueue()                              │   │
│  │  2. detectCollisions()                               │   │
│  │  3. buildContacts()                                  │   │
│  │  4. solveContacts()                                  │   │
│  │  5. integrateVelocity(dt)                            │   │
│  │  6. positionalCorrection()                           │   │
│  │  7. integratePosition(dt)                            │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                  ArkTS 端 (Sync Back)                        │
│  ┌─────────────────┐     ┌─────────────────┐                 │
│  │ SceneProxy.     │     │  PhysicsSystem  │                 │
│  │ update()        │◀────│  updateNodeData │                 │
│  │ - 同步选中节点   │     │  (位置/旋转)     │                 │
│  └─────────────────┘     └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## 三、使用方法

### 1. 初始化（自动完成）

```typescript
// 在 SceneProxy 构造函数中自动初始化
constructor(ui: UIContext) {
  // ...
  this.eventQueue.init(this.physicalSystem.getPhysicsSystem());
}
```

### 2. 发送事件

```typescript
// 在 onTouch 或其他事件处理中
// Raycast 请求
this.sceneProxy.eventQueue.pushRaycastRequest(normalizedX, normalizedY);

// Rotate 请求
this.sceneProxy.eventQueue.pushRotateRequest(nodeId, deltaX, deltaY);

// Touch 事件（可选，用于状态管理）
this.sceneProxy.eventQueue.pushTouchDown(x, y);
this.sceneProxy.eventQueue.pushTouchMove(x, y, dx, dy);
this.sceneProxy.eventQueue.pushTouchUp();
```

### 3. 获取选中节点

```typescript
// 在 SceneProxy.update() 中自动同步
let selectedId = this.physicalSystem.getSelectedNodeId();
if (selectedId !== 0) {
  let selectedNode = this.physicalSystem.getNodeById(selectedId);
  if (selectedNode) {
    this.touchRotate.target = selectedNode;
  }
}
```

## 四、性能优势

### 旧方案问题
1. 每次 Touch 事件都立即调用 NAPI 方法
2. Raycast 使用 ArkGraphics3D 的异步 API
3. 多次跨边界调用（ArkTS → C++）

### 新方案优势
1. **批量处理**：多个事件在一次 step() 中处理
2. **零拷贝**：共享内存通信，无需数据复制
3. **无锁设计**：SPSC 环形缓冲区，无锁竞争
4. **减少跨边界调用**：仅初始化时一次调用，后续通过共享内存通信

## 五、扩展性

### 添加新事件类型

1. 在 `event_queue.h` 中添加枚举值：
```cpp
enum class EventType : uint8_t {
    // ...
    PAN_REQUEST = 6,
    SCALE_REQUEST = 7
};
```

2. 在 `processEventQueue()` 中添加处理逻辑：
```cpp
case EventType::PAN_REQUEST:
    processPan(cmd.nodeId, cmd.touchX, cmd.touchY);
    break;
```

3. 在 ArkTS 端添加推送方法：
```typescript
pushPanRequest(nodeId: number, x: number, y: number): void {
    const command: EventCommand = {
        type: EventType.PAN_REQUEST,
        nodeId: nodeId,
        touchX: x,
        touchY: y,
        // ...
    };
    this.pushEvent(command);
}
```

## 六、注意事项

1. **队列容量**：当前设置为 64 个事件，如果丢弃事件频繁可增加容量
2. **内存对齐**：修改 EventCommand 结构后需确保 ArkTS 端偏移量一致
3. **线程安全**：目前设计为单生产者单消费者，不支持多线程写入
4. **Raycast 精度**：当前实现使用简化的 AABB 检测，可根据需要改进

## 七、后续优化方向

1. **更精确的 Raycast**：使用 Minkowski 差或 GJK 算法
2. **事件优先级**：区分高优先级（输入）和低优先级（异步请求）事件
3. **事件批处理**：支持一次推送多个事件
4. **调试功能**：添加事件统计（丢弃数量、平均延迟等）
