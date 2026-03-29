# Bug 修复记录：XComponent SurfaceHolder API 改造编译错误

## 问题描述

在改造 `lume_xcomponent_manager` 使用 ArkUI SurfaceHolder API 后，编译出现以下错误：

```
error 1: napi_init.cpp:85:42: error: no member named 'Export' in 'LumeXComponent::LumeXComponentManager'
    LumeXComponentManager::GetInstance().Export(env, exports);

error 2-4: lume_xcomponent_manager.cpp: call to non-static member function without an object argument
    auto renderer = GetRendererById(nodeId);  // 在静态函数中调用非静态方法
```

## 根因分析

### 错误 1：Export 方法不存在

**原因**: 新的头文件设计中移除了 `Export` 方法。旧的 `Export` 方法用于通过 `OH_NATIVE_XCOMPONENT_OBJ` 获取 XComponent 对象并注册回调，但新的 SurfaceHolder API 不再需要这种方式。

**旧的交互方式**:
```cpp
void LumeXComponentManager::Export(napi_env env, napi_value exports) {
    napi_value exportInstance;
    napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ, &exportInstance);
    OH_NativeXComponent* nativeXComponent;
    napi_unwrap(env, exportInstance, (void**)&nativeXComponent);
    // 注册回调...
}
```

**新的交互方式**: 所有 NAPI 接口通过静态函数直接导出，不再依赖 `Export` 方法。

### 错误 2-4：静态函数调用非静态方法

**原因**: `GetRendererById` 是非静态成员方法，但在静态 NAPI 函数中直接调用了它，缺少对象实例。

**错误代码**:
```cpp
napi_value LumeXComponentManager::DrawFrame(napi_env env, napi_callback_info info) {
    // ...
    auto renderer = GetRendererById(nodeId);  // 错误：需要通过实例调用
}
```

## 修复方案

### 修复 1：移除 Export 调用 (napi_init.cpp)

**文件**: `nativerender/napi_init.cpp:85`

**修改前**:
```cpp
// Export additional methods for XComponent object
LumeXComponentManager::GetInstance().Export(env, exports);
```

**修改后**:
```cpp
// NAPI methods are already registered above via napi_define_properties
// No need for additional Export call with ArkUI SurfaceHolder API
```

### 修复 2：通过 GetInstance() 调用非静态方法

**文件**: `nativerender/lume_xcomponent/src/lume_xcomponent_manager.cpp`

**修改前** (3 处):
```cpp
// DrawFrame (line 503)
auto renderer = GetRendererById(nodeId);

// LoadScene (line 531)
auto renderer = GetRendererById(nodeId);

// GetRendererState (line 556)
auto renderer = GetRendererById(nodeId);
```

**修改后**:
```cpp
// DrawFrame
auto renderer = GetInstance().GetRendererById(nodeId);

// LoadScene
auto renderer = GetInstance().GetRendererById(nodeId);

// GetRendererState
auto renderer = GetInstance().GetRendererById(nodeId);
```

### 修复 3：消除 LOG_TAG 重定义警告

**文件**: `nativerender/lume_xcomponent/src/lume_xcomponent_manager.cpp:25`

**修改前**:
```cpp
#define LOG_TAG "LumeXComponentMgr"
```

**修改后**:
```cpp
// Undefine LOG_TAG from hilog before defining our own
#ifdef LOG_TAG
#undef LOG_TAG
#endif
#define LOG_TAG "LumeXComponentMgr"
```

## 技术要点

### 静态方法 vs 非静态方法

在 C++ 中：
- **静态方法**: 属于类本身，可直接调用，无需对象实例
- **非静态方法**: 属于对象实例，必须通过对象调用

NAPI 回调函数必须是静态的（或全局函数），因为它们作为函数指针传递给 NAPI。

当静态 NAPI 函数需要访问非静态成员时，必须：
1. 使用单例模式：`GetInstance().Method()`
2. 或将成员也声明为静态

### 新旧 API 对比

| 旧方式 | 新方式 |
|--------|--------|
| `Export()` 获取 XComponent 对象 | NAPI 静态函数直接导出 |
| `OH_NativeXComponent_RegisterCallback` | `OH_ArkUI_SurfaceHolder_AddSurfaceCallback` |
| 自动触发 Surface 回调 | 手动调用 `Initialize()` 触发 |

## 验证

修复后应能正常编译，无错误。

```bash
# 编译命令
hvigorw assembleHap
```

---

## Bug 4：死锁问题 (GetRendererById 调用 GetRendererByNode)

### 问题描述

```cpp
LumeRenderer* LumeXComponentManager::GetRendererByNode(ArkUI_NodeHandle node)
{
    std::lock_guard<std::mutex> lock(mutex_);  // 第一次加锁
    // ...
}

LumeRenderer* LumeXComponentManager::GetRendererById(const std::string& id)
{
    std::lock_guard<std::mutex> lock(mutex_);  // 第二次加锁 (死锁!)
    // ...
    return GetRendererByNode(it->second);  // 调用已持有锁的函数
}
```

### 死锁流程

```
GetRendererById("xxx")
    ↓
    获取 mutex_ 锁 ✓
    ↓
    调用 GetRendererByNode(node)
        ↓
        尝试再次获取 mutex_ 锁 ✗
        ↓
        死锁! (std::mutex 不支持同一线程重复加锁)
```

### 根因

`std::mutex` 是**非递归锁**，同一线程重复加锁会导致死锁。

### 修复方案

创建一个不加锁的内部版本：

```cpp
// Internal version without locking (must be called with mutex already held)
LumeRenderer* LumeXComponentManager::GetRendererByNodeInternal(ArkUI_NodeHandle node)
{
    auto it = rendererMap_.find(node);
    return it != rendererMap_.end() ? it->second : nullptr;
}

LumeRenderer* LumeXComponentManager::GetRendererByNode(ArkUI_NodeHandle node)
{
    std::lock_guard<std::mutex> lock(mutex_);
    return GetRendererByNodeInternal(node);  // 调用内部版本
}

LumeRenderer* LumeXComponentManager::GetRendererById(const std::string& id)
{
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = nodeHandleMap_.find(id);
    if (it != nodeHandleMap_.end()) {
        return GetRendererByNodeInternal(it->second);  // 调用内部版本，不再加锁
    }
    return nullptr;
}
```

### 为什么不用 `std::recursive_mutex`？

虽然 `std::recursive_mutex` 可以解决死锁问题，但：
1. 效率较低（递归锁需要维护锁计数）
2. 通常表示设计有问题，应该避免深层嵌套加锁
3. 内部版本模式更清晰，职责分明

### 教训

当调用链中存在锁嵌套时，应设计**内部不加锁版本**供已持有锁的函数调用。

---

## Bug 5：Failed to create SurfaceHolder

### 问题描述

调用 `native.bindNode()` 时，日志输出：
```
Failed to create SurfaceHolder
```

对应 C++ 代码位置：
```cpp
// lume_xcomponent_manager.cpp:376-381
OH_ArkUI_SurfaceHolder* holder = OH_ArkUI_SurfaceHolder_Create(handle);
if (!holder) {
    LOGE("Failed to create SurfaceHolder");
    return false;
}
```

### 根因分析

**调用顺序错误**：在 ArkTS 端的 `MyNodeController.makeNode()` 中，`bindNode` 在节点尚未附加到 UI 树时就被调用：

```typescript
// NativePage.ets (错误顺序)
this.xComponent = typeNode.createNode(uiContext, 'XComponent', { type: XComponentType.SURFACE });
this.xComponent.attribute
  .id(this.xComponentId)
  .focusable(true)
  .focusOnTouch(true)
native.bindNode(this.xComponentId, this.xComponent)  // ❌ 先调用了 bindNode
try {
  this.column.appendChild(this.xComponent);          // 后才附加到 UI 树
}
```

**关键点**：`OH_ArkUI_SurfaceHolder_Create` 需要 XComponent 节点**已经附加到窗口**才能成功创建 SurfaceHolder。节点未附加时，内部状态未初始化，创建会返回 `nullptr`。

### 修复方案

使用 `onAttach` 事件监听，确保节点附加到窗口后再调用 `bindNode`：

```typescript
class MyNodeController extends NodeController {
  public xComponent: typeNode.XComponent | undefined = undefined;
  public xComponentId: string = 'xcp' + (new Date().getTime());
  private isBound: boolean = false;  // 防止重复绑定

  makeNode(uiContext: UIContext): FrameNode | null {
    this.node = new FrameNode(uiContext);
    this.column = typeNode.createNode(uiContext, 'Column');
    this.column.initialize()
      .width('100%')
      .height('100%');
    this.node.appendChild(this.column);

    this.xComponent = typeNode.createNode(uiContext, 'XComponent', { type: XComponentType.SURFACE });
    this.xComponent.attribute
      .id(this.xComponentId)
      .focusable(true)
      .focusOnTouch(true)
      .onAttach(() => {
        // ✓ 等待节点附加到窗口后再绑定
        if (!this.isBound && this.xComponent) {
          console.info('XComponent attached to window, binding node...');
          native.bindNode(this.xComponentId, this.xComponent);
          this.isBound = true;
        }
      });

    this.column.appendChild(this.xComponent);  // 先附加，触发 onAttach
    return this.node;
  }

  aboutToDisappear(): void {
    if (this.isBound) {
      native.unbindNode(this.xComponentId);
      this.isBound = false;
    }
    this.node?.removeChild(this.xComponent);
    this.xComponent?.dispose();
  }
}
```

### 修复要点

1. **添加 `isBound` 状态标志** - 防止重复绑定
2. **使用 `onAttach` 事件** - 在节点真正附加到窗口后调用 `bindNode`
3. **优化解绑逻辑** - 只有已绑定时才解绑

### 正确的执行流程

```
makeNode() 调用
    ↓
创建 XComponent 节点
    ↓
设置 onAttach 监听
    ↓
appendChild() → 附加到 UI 树
    ↓
onAttach 事件触发
    ↓
native.bindNode() → OH_ArkUI_SurfaceHolder_Create 成功 ✓
```

### 教训

ArkUI 的很多 API（如 SurfaceHolder）依赖于节点的生命周期状态。在调用这些 API 前，必须确保节点已处于正确的状态（如已附加到窗口）。使用事件监听是处理这类依赖的可靠方式。