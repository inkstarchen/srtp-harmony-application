# 渲染引擎与 XComponent 分离架构设计

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 7 日  
**作者**: Development Team  

---

## 目录

1. [概述](#1-概述)
2. [当前架构分析](#2-当前架构分析)
3. [目标架构设计](#3-目标架构设计)
4. [详细设计](#4-详细设计)
5. [接口变更](#5-接口变更)
6. [状态机设计](#6-状态机设计)
7. [使用示例](#7-使用示例)
8. [迁移计划](#8-迁移计划)

---

## 1. 概述

### 1.1 背景

当前 `LumeRenderer` 的实现将渲染引擎的创建与 XComponent 的初始化强耦合在一起。这导致：

- 渲染引擎无法在 XComponent 之外独立存在
- 无法在多个 XComponent 之间共享引擎实例
- 窗口生命周期与引擎生命周期绑定，资源管理不灵活

### 1.2 设计目标

本设计文档描述如何将渲染引擎的创建与 XComponent 分离，实现：

1. **引擎独立性** - 渲染引擎可以在没有 XComponent 的情况下创建和初始化
2. **延迟绑定** - 只在需要时才将引擎绑定到 XComponent 的窗口
3. **灵活切换** - 支持在多个 XComponent 之间切换绑定
4. **资源复用** - 多个 XComponent 可以共享同一个引擎实例
5. **清晰的生命周期** - 引擎生命周期与 XComponent 生命周期解耦

### 1.3 适用范围

本设计适用于：
- `LumeRenderer` 类（XComponent 适配层）
- `LumeCommon` 类（渲染引擎核心）
- `LumeXComponentManager` 类（XComponent 管理器）

---

## 2. 当前架构分析

### 2.1 当前架构

```
┌─────────────────────────────────────────────────────────────┐
│                  LumeXComponentManager                       │
│                          │                                   │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   LumeRenderer                       │    │
│  │  ┌─────────────────────────────────────────────┐    │    │
│  │  │            Initialize()                      │    │    │
│  │  │  1. 创建 EGL 显示和上下文                       │    │    │
│  │  │  2. 创建 EGL Surface (绑定窗口)               │    │    │
│  │  │  3. 初始化 LumeCommon 引擎                     │    │    │
│  │  │  4. 调用 OnWindowChange (创建 swapchain)      │    │    │
│  │  └─────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
│                          │                                   │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   LumeCommon                         │    │
│  │  - ECS 管理                                          │    │
│  │  - 场景管理                                          │    │
│  │  - 渲染系统                                          │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 当前问题

| 问题 | 描述 | 影响 |
|------|------|------|
| **强耦合** | `Initialize()` 同时创建引擎和绑定窗口 | 无法独立创建引擎 |
| **生命周期绑定** | XComponent 销毁时必须销毁引擎 | 无法复用引擎实例 |
| **资源浪费** | 每个 XComponent 都需要独立引擎 | 内存和资源开销大 |
| **初始化顺序限制** | 必须先有 XComponent 才能创建引擎 | 架构灵活性差 |

### 2.3 关键代码分析

**当前 `LumeRenderer::Initialize` 实现：**

```cpp
bool LumeRenderer::Initialize(void* window, uint32_t width, uint32_t height,
                               NativeResourceManager* resourceManager)
{
    // Step 1: 设置窗口信息
    windowInfo_.nativeWindow = window;
    windowInfo_.width = width;
    windowInfo_.height = height;
    
    // Step 2: 初始化 Lume 引擎
    if (!InitializeLumeEngine(resourceManager)) {
        return false;
    }
    
    // Step 3: 立即通知 LumeCommon 窗口信息（创建 swapchain）
    OHOS::Render3D::TextureInfo textureInfo {};
    textureInfo.width_ = width;
    textureInfo.height_ = height;
    textureInfo.nativeWindow_ = window;
    textureInfo.recreateWindow_ = true;
    
    InitializeScene(0);
    engine_->OnWindowChange(textureInfo);  // ← 问题：立即绑定窗口
    
    SetState(RenderState::READY);
    return true;
}
```

**问题分析：**
- `OnWindowChange` 在初始化时立即调用，导致引擎与窗口强绑定
- 没有独立的引擎初始化方法
- 没有绑定/解绑机制

---

## 3. 目标架构设计

### 3.1 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                   应用层 (Application Layer)                 │
│  - ArkTS/JS 业务逻辑                                         │
│  - Scene API 调用                                            │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │
┌─────────────────────────────────────────────────────────────┐
│                  XComponent 适配层                            │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                LumeRenderer                          │   │
│  │  - EGL 共享上下文管理                                 │   │
│  │  - Surface 生命周期                                   │   │
│  │  - 窗口绑定/解绑                                      │   │
│  │  - Swapchain 创建/更新/销毁                           │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ 绑定接口 (BindToXComponent)
                          │
┌─────────────────────────────────────────────────────────────┐
│                   渲染引擎层 (Engine Layer)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                LumeCommon                            │   │
│  │  - ECS 管理 (独立于窗口)                              │   │
│  │  - 场景管理 (独立于窗口)                              │   │
│  │  - 渲染系统 (独立于窗口)                              │   │
│  │  - ApplicationContext                               │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 核心设计原则

1. **单一职责** - `LumeRenderer` 负责 XComponent 适配，`LumeCommon` 负责渲染
2. **依赖倒置** - 引擎层不依赖适配层，适配层依赖引擎层
3. **接口隔离** - 通过清晰的接口进行层间通信
4. **生命周期解耦** - 各层有独立的生命周期管理

### 3.3 关键变更

| 组件 | 变更内容 |
|------|----------|
| `LumeRenderer` | 新增 `InitializeEngine()`, `BindToXComponent()`, `UnbindFromXComponent()` |
| `LumeCommon` | 支持延迟窗口绑定，`OnWindowChange` 可处理 null 窗口 |
| `LumeXComponentManager` | 分离引擎创建和 XComponent 绑定逻辑 |

---

## 4. 详细设计

### 4.1 LumeRenderer 类设计

#### 4.1.1 新增方法

```cpp
class LumeRenderer {
public:
    // ========== 引擎初始化（不绑定窗口）==========
    
    /**
     * @brief 仅初始化渲染引擎，不绑定到 XComponent
     * 
     * 此方法执行以下操作：
     * 1. 初始化 EGL（创建共享上下文，不创建 surface）
     * 2. 初始化 LumeCommon 引擎
     * 3. 设置状态为 INITIALIZED
     * 
     * @param resourceManager 资源管理器，用于加载资产
     * @return true 如果初始化成功
     */
    bool InitializeEngine(NativeResourceManager* resourceManager);
    
    // ========== XComponent 绑定管理 ==========
    
    /**
     * @brief 将渲染引擎绑定到 XComponent
     * 
     * 此方法执行以下操作：
     * 1. 创建 EGL Surface（绑定到 XComponent 窗口）
     * 2. 通知 LumeCommon 创建 swapchain
     * 3. 设置状态为 READY
     * 
     * @param window XComponent 的 native window
     * @param width 窗口宽度
     * @param height 窗口高度
     * @return true 如果绑定成功
     */
    bool BindToXComponent(void* window, uint32_t width, uint32_t height);
    
    /**
     * @brief 从 XComponent 解绑渲染引擎
     * 
     * 此方法执行以下操作：
     * 1. 通知 LumeCommon 销毁 swapchain
     * 2. 销毁 EGL Surface
     * 3. 设置状态为 INITIALIZED（回到已初始化但未绑定状态）
     * 
     * 注意：引擎实例仍然存活，可以重新绑定到其他 XComponent
     */
    void UnbindFromXComponent();
    
    /**
     * @brief 检查是否已绑定到 XComponent
     * @return true 如果已绑定
     */
    bool IsBoundToXComponent() const;
    
    // ========== 状态查询 ==========
    
    /**
     * @brief 获取渲染器当前状态
     * @return 当前状态
     */
    RenderState GetState() const;
};
```

#### 4.1.2 新增成员变量

```cpp
class LumeRenderer {
private:
    // ... 现有成员 ...
    
    // ========== 新增：绑定状态管理 ==========
    
    /** 是否已绑定到 XComponent */
    bool isBoundToXComponent_ = false;
    
    /** 当前绑定状态 */
    RenderState state_ = RenderState::UNINITIALIZED;
};
```

#### 4.1.3 状态枚举扩展

```cpp
enum class RenderState {
    UNINITIALIZED = 0,  // 未初始化
    INITIALIZING = 1,   // 初始化中
    INITIALIZED = 2,    // 已初始化（引擎就绪，未绑定窗口）
    READY = 3,          // 就绪（已绑定窗口，可渲染）
    ERROR = 4,          // 错误状态
    DESTROYED = 5       // 已销毁
};
```

### 4.2 LumeCommon 类设计

#### 4.2.1 OnWindowChange 行为变更

**当前行为：**
```cpp
void LumeCommon::OnWindowChange(const TextureInfo& textureInfo)
{
    // 总是创建/更新 swapchain
    CreateSwapchain(textureInfo.nativeWindow_);
}
```

**新行为：**
```cpp
void LumeCommon::OnWindowChange(const TextureInfo& textureInfo)
{
    if (textureInfo.nativeWindow_ != nullptr) {
        // 有窗口：创建或更新 swapchain
        CreateSwapchain(textureInfo.nativeWindow_);
    } else {
        // 无窗口：销毁 swapchain（如果存在）
        if (swapchainHandle_) {
            DestroySwapchain();
        }
    }
}
```

### 4.3 LumeXComponentManager 使用方式

#### 4.3.1 XComponent 创建流程

```cpp
void LumeXComponentManager::CreateXComponent(const std::string& nodeId)
{
    // Step 1: 创建或获取 LumeRenderer
    auto renderer = GetOrCreateRenderer(nodeId);
    
    // Step 2: 如果引擎未初始化，先初始化引擎
    if (renderer->GetState() == RenderState::UNINITIALIZED) {
        renderer->InitializeEngine(resourceMgr_);
    }
    
    // Step 3: 获取 XComponent 的 native window
    auto window = GetXComponentNativeWindow(nodeId);
    auto width = GetXComponentWidth(nodeId);
    auto height = GetXComponentHeight(nodeId);
    
    // Step 4: 绑定到 XComponent
    renderer->BindToXComponent(window, width, height);
}
```

#### 4.3.2 XComponent 销毁流程

```cpp
void LumeXComponentManager::DestroyXComponent(const std::string& nodeId)
{
    auto renderer = GetRendererById(nodeId);
    if (renderer) {
        // Step 1: 解绑 XComponent（引擎仍然存活）
        renderer->UnbindFromXComponent();
        
        // Step 2: 可选 - 如果不再需要引擎，可以销毁
        // renderer->DestroyEngine();
    }
}
```

#### 4.3.3 场景加载（不依赖 XComponent 绑定）

```cpp
napi_value LumeXComponentManager::LoadScene(napi_env env, napi_callback_info info)
{
    // 解析参数
    std::string nodeId = ExtractNodeId(args[0]);
    std::string gltfPath = ExtractGltfPath(args[1]);
    
    // 获取 renderer（可能还未绑定 XComponent）
    auto renderer = GetRendererById(nodeId);
    if (!renderer) {
        // 如果 renderer 不存在，创建一个但不绑定
        renderer = CreateRenderer(nodeId);
    }
    
    // 确保引擎已初始化
    if (renderer->GetState() == RenderState::UNINITIALIZED) {
        renderer->InitializeEngine(resourceMgr_);
    }
    
    // 获取 LumeCommon 进行场景加载
    auto lumeCommon = renderer->GetLumeCommon();
    
    // ... 后续场景加载逻辑不变 ...
}
```

---

## 5. 接口变更

### 5.1 LumeRenderer 接口变更

| 方法 | 变更类型 | 描述 |
|------|----------|------|
| `Initialize()` | 标记为 Deprecated | 使用 `InitializeEngine()` + `BindToXComponent()` 替代 |
| `InitializeEngine()` | 新增 | 仅初始化引擎，不绑定窗口 |
| `BindToXComponent()` | 新增 | 绑定到 XComponent |
| `UnbindFromXComponent()` | 新增 | 从 XComponent 解绑 |
| `IsBoundToXComponent()` | 新增 | 查询绑定状态 |
| `GetState()` | 扩展 | 返回扩展后的状态枚举 |

### 5.2 LumeCommon 接口变更

| 方法 | 变更类型 | 描述 |
|------|----------|------|
| `OnWindowChange()` | 行为变更 | 支持 null 窗口，用于解绑 |

### 5.3 向后兼容性

为了保持向后兼容，保留现有 `Initialize()` 方法，但内部调用新方法：

```cpp
bool LumeRenderer::Initialize(void* window, uint32_t width, uint32_t height,
                               NativeResourceManager* resourceManager)
{
    // 向后兼容：调用新方法
    if (!InitializeEngine(resourceManager)) {
        return false;
    }
    return BindToXComponent(window, width, height);
}
```

---

## 6. 状态机设计

### 6.1 状态定义

```
┌─────────────────────────────────────────────────────────────┐
│                    LumeRenderer 状态机                       │
│                                                             │
│  UNINITIALIZED ──InitializeEngine()──> INITIALIZED          │
│       │               (失败)             │                  │
│       │              ┌───────────────────┘                  │
│       │              │                                      │
│       │              ▼                                      │
│       │           ERROR ◄────────────────────────┐         │
│       │              │                           │         │
│       │ Destroy()    │ Destroy()                 │         │
│       │              │                           │         │
│       ▼              ▼                           │         │
│   DESTROYED      (清理后)                        │         │
│                      │                           │         │
│                      │ BindToXComponent()        │         │
│                      │ (成功)                    │         │
│                      ▼                           │         │
│                    READY ────────────────────────┘         │
│                      │         OnWindowChange()失败        │
│                      │                                      │
│                      │ UnbindFromXComponent()               │
│                      ▼                                      │
│                  INITIALIZED                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 状态转换表

| 当前状态 | 操作 | 结果状态 | 说明 |
|----------|------|----------|------|
| `UNINITIALIZED` | `InitializeEngine()` 成功 | `INITIALIZED` | 引擎初始化完成 |
| `UNINITIALIZED` | `InitializeEngine()` 失败 | `ERROR` | 初始化失败 |
| `INITIALIZED` | `BindToXComponent()` 成功 | `READY` | 绑定到 XComponent |
| `INITIALIZED` | `BindToXComponent()` 失败 | `ERROR` | 绑定失败 |
| `READY` | `UnbindFromXComponent()` | `INITIALIZED` | 从 XComponent 解绑 |
| `READY` | `OnWindowChange()` 失败 | `ERROR` | 窗口更新失败 |
| `ANY` | `Destroy()` | `DESTROYED` | 销毁渲染器 |

---

## 7. 使用示例

### 7.1 基本使用

```cpp
// 创建渲染器
auto renderer = std::make_unique<LumeRenderer>("renderer_1");

// 初始化引擎（不绑定窗口）
if (!renderer->InitializeEngine(resourceManager)) {
    LOGE("Failed to initialize engine");
    return;
}

// ... 引擎可以独立使用，加载场景等 ...

// 当 XComponent 创建时，绑定窗口
renderer->BindToXComponent(nativeWindow, width, height);

// ... 渲染循环 ...

// 当 XComponent 销毁时，解绑（引擎仍然存活）
renderer->UnbindFromXComponent();

// 可以绑定到另一个 XComponent
renderer->BindToXComponent(newNativeWindow, newWidth, newHeight);
```

### 7.2 多 XComponent 共享引擎

```cpp
// 创建一个共享引擎
auto sharedRenderer = std::make_unique<LumeRenderer>("shared_renderer");
sharedRenderer->InitializeEngine(resourceManager);

// 多个 XComponent 共享同一个引擎
XComponent1->BindToXComponent(sharedRenderer.get(), window1, width1, height1);
XComponent2->BindToXComponent(sharedRenderer.get(), window2, width2, height2);

// 注意：同一时间只能绑定一个 XComponent
// 需要在绑定前调用 UnbindFromXComponent()
```

### 7.3 延迟绑定场景

```cpp
// 在应用启动时初始化引擎（不绑定任何 XComponent）
auto renderer = CreateRenderer();
renderer->InitializeEngine(resourceManager);

// 预加载场景资源
LoadSceneAssets(renderer->GetLumeCommon());

// 当用户导航到 3D 页面时，创建 XComponent 并绑定
CreateXComponent();
renderer->BindToXComponent(xcomponentWindow, width, height);
```

---

## 8. 迁移计划

### 8.1 阶段一：代码准备（1-2 天）

- [ ] 在 `LumeRenderer.h` 中添加新方法声明
- [ ] 在 `LumeRenderer.h` 中添加新成员变量
- [ ] 扩展 `RenderState` 枚举
- [ ] 在 `LumeCommon.cpp` 中修改 `OnWindowChange` 行为

### 8.2 阶段二：实现新方法（2-3 天）

- [ ] 实现 `InitializeEngine()` 方法
- [ ] 实现 `BindToXComponent()` 方法
- [ ] 实现 `UnbindFromXComponent()` 方法
- [ ] 实现 `IsBoundToXComponent()` 方法
- [ ] 实现 `InitializeEGL()` 和 `CleanupEGL()` 辅助方法

### 8.3 阶段三：更新调用方（2-3 天）

- [ ] 修改 `LumeXComponentManager::CreateXComponent()` 使用新 API
- [ ] 修改 `LumeXComponentManager::DestroyXComponent()` 使用新 API
- [ ] 修改 `LumeXComponentManager::LoadScene()` 不依赖绑定状态
- [ ] 更新 `LumeRenderer::OnSurfaceChanged()` 检查绑定状态

### 8.4 阶段四：测试与验证（2-3 天）

- [ ] 单元测试：引擎独立初始化
- [ ] 单元测试：绑定/解绑功能
- [ ] 集成测试：XComponent 创建/销毁流程
- [ ] 性能测试：资源使用情况

### 8.5 阶段五：清理与优化（1-2 天）

- [ ] 将 `Initialize()` 标记为 Deprecated
- [ ] 更新文档和注释
- [ ] 代码审查和重构

### 8.6 总时间估算

**预计总时间**: 8-13 个工作日

---

## 附录

### A. 相关文件

- `lume_renderer.h` - LumeRenderer 头文件
- `lume_renderer.cpp` - LumeRenderer 实现
- `lume_common.h` - LumeCommon 头文件
- `lume_common.cpp` - LumeCommon 实现
- `lume_xcomponent_manager.h` - LumeXComponentManager 头文件
- `lume_xcomponent_manager.cpp` - LumeXComponentManager 实现

### B. 参考文档

- [Lume 渲染引擎架构文档](./LUME_ENGINE_ARCHITECTURE.md)
- [XComponent 集成指南](./XCOMPONENT_INTEGRATION.md)
- [EGL 规范](https://www.khronos.org/egl/)

### C. 术语表

| 术语 | 定义 |
|------|------|
| XComponent | ArkUI 的原生组件，用于自定义渲染 |
| Swapchain | 渲染目标链，用于双缓冲/三缓冲 |
| EGL Surface | EGL 的渲染表面，与原生窗口关联 |
| LumeCommon | Lume 渲染引擎的核心类 |
| LumeRenderer | XComponent 与 Lume 引擎的适配器 |

---

**文档结束**
