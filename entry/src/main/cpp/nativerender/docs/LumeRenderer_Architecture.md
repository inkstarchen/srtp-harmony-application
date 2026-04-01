# LumeRenderer 与 LumeCommon 架构设计

## 概述

本文档说明 `LumeRenderer` 和 `LumeCommon` 的职责划分，以及为什么采用这种架构。

## 架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      XComponent (OHOS)                          │
│                   (Native Window Callbacks)                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LumeRenderer                               │
│                    (Pure Adapter)                               │
│                                                                 │
│  职责：                                                         │
│  - XComponent 生命周期适配                                      │
│  - EGL 环境管理                                                 │
│  - 状态管理和线程安全                                           │
│  - 回调管理                                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 委托所有渲染逻辑
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       LumeCommon                                │
│                   (Rendering Engine)                            │
│                                                                 │
│  职责：                                                         │
│  - 引擎核心初始化 (CreateCoreEngine)                            │
│  - 渲染上下文管理 (CreateRenderContext)                         │
│  - 3D 图形上下文 (CreateGfx3DContext)                           │
│  - Swapchain 创建和管理                                         │
│  - 场景/相机/灯光管理                                           │
│  - GLTF 加载                                                    │
│  - 动画系统                                                     │
│  - 自定义渲染                                                   │
│  - 触摸事件处理                                                 │
│  - 帧渲染                                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Lume Engine Core                           │
│              (CORE_NS::IEngine, RENDER_NS, etc.)                │
└─────────────────────────────────────────────────────────────────┘
```

## 职责划分

### LumeRenderer (适配器层)

| 职责 | 说明 |
|------|------|
| **XComponent 生命周期适配** | 将 OHOS XComponent 的回调转换为引擎操作 |
| **EGL 环境管理** | 创建独立的 EGL context，提供给 LumeCommon 作为共享 context |
| **状态管理** | 跟踪渲染器状态 (UNINITIALIZED, INITIALIZING, READY, RENDERING, DESTROYED) |
| **线程安全** | 使用 mutex 保护并发访问 |
| **回调管理** | 管理用户自定义的回调函数 |

**关键设计：**
- `LumeRenderer` 不包含任何渲染逻辑
- 所有渲染操作都委托给 `LumeCommon`
- 只持有 `std::unique_ptr<Lume>` 作为引擎实例

### LumeCommon (引擎层)

| 职责 | 说明 |
|------|------|
| **引擎核心初始化** | `InitEngine()` 包含 CreateCoreEngine, CreateRenderContext, CreateGfx3DContext |
| **Swapchain 管理** | `CreateSwapchain()`, `DestroySwapchain()` |
| **场景管理** | `InitializeScene()`, `LoadSceneModel()`, `LoadEnvModel()` |
| **相机管理** | `CreateCamera()`, `SetupCameraViewPort()`, `OrbitCameraHelper` |
| **灯光管理** | `CreateLight()`, `UpdateLights()` |
| **GLTF 加载** | `LoadAndImport()` |
| **动画系统** | `UpdateGLTFAnimations()`, `ProcessGLTFAnimations()` |
| **自定义渲染** | `UpdateCustomRender()`, `LumeCustomRender` |
| **触摸事件** | `OnTouchEvent()` |
| **帧渲染** | `DrawFrame()`, `CollectRenderHandles()` |

## 调用流程

### 初始化流程

```
LumeRenderer::Initialize(window, width, height)
    │
    ├─► InitializeEGL(window)
    │       创建 EGL display, surface, context
    │
    ├─► InitializeLumeEngine()
    │       engine_ = std::make_unique<Lume>()
    │       │
    │       └─► engine_->InitEngine(eglContext_, platformData)
    │               │
    │               └─► LumeCommon::InitEngine()
    │                       ├─► CreateCoreEngine()
    │                       │       └─► CreatePluginRegistry()  ← 静态链接，直接调用
    │                       ├─► CreateRenderContext()
    │                       └─► CreateGfx3DContext()
    │
    └─► engine_->OnWindowChange(textureInfo)
            创建 Swapchain 和 RenderTarget
```

**静态链接模式**：本项目使用静态链接模式（不定义 `CORE_DYNAMIC=1`），`GetPluginRegister()` 和 `CreatePluginRegistry()` 是实际函数，直接从 `libPluginSceneWidget.so` 链接，不需要运行时动态加载（`dlopen`）。

### 渲染流程

```
LumeRenderer::RenderFrame()
    │
    └─► engine_->DrawFrame()
            │
            └─► LumeCommon::DrawFrame()
                    ├─► engine_->TickFrame()
                    ├─► Tick(deltaTime)
                    ├─► customRender_->OnDrawFrame()
                    └─► renderContext_->GetRenderer().RenderFrame()
```

### 窗口变化流程

```
LumeRenderer::OnSurfaceChanged(window, width, height)
    │
    └─► engine_->OnWindowChange(textureInfo)
            │
            └─► LumeCommon::OnWindowChange()
                    ├─► SetupCustomRenderTarget()
                    ├─► SetupCameraViewPort()
                    └─► customRender_->OnSizeChange()
```

## 为什么这样设计？

### 问题：职责重复

重构前，`LumeRenderer` 和 `LumeCommon` 都有：
- Swapchain 创建逻辑
- RenderTarget 创建逻辑
- 场景初始化逻辑
- 帧渲染逻辑

这导致：
1. **代码冗余**：两套相似但不完全相同的实现
2. **维护困难**：修改一处需要同步另一处
3. **职责不清**：难以确定哪个类负责什么

### 解决方案：纯适配器模式

将 `LumeRenderer` 设计为纯适配器：
- 只处理 XComponent 特有的 EGL 管理和生命周期适配
- 所有渲染逻辑委托给 `LumeCommon`

### 好处

1. **职责清晰**：
   - `LumeRenderer`：平台适配
   - `LumeCommon`：渲染引擎

2. **代码复用**：
   - `LumeCommon` 可以被其他平台/场景复用
   - `LumeRenderer` 只需要很少的代码

3. **易于维护**：
   - 修改渲染逻辑只需要改 `LumeCommon`
   - 修改平台适配只需要改 `LumeRenderer`

4. **易于测试**：
   - `LumeCommon` 可以独立测试
   - `LumeRenderer` 可以 mock `LumeCommon` 进行测试

## 文件结构

```
nativerender/
├── manager/
│   ├── include/
│   │   └── lume_renderer.h          # 适配器头文件
│   └── src/
│       ├── lume_renderer.cpp        # 适配器实现
│       └── lume_xcomponent_manager.cpp
│
└── 3d_widget_adapter/
    ├── include/
    │   ├── i_engine.h               # 引擎接口
    │   ├── texture_info.h           # 纹理/窗口信息
    │   └── ohos/
    │       └── platform_data.h      # 平台数据
    └── core/
        ├── include/lume/
        │   ├── lume_common.h        # 引擎基类
        │   └── ohos/
        │       └── lume.h           # OHOS 特化
        └── src/lume/
            └── lume_common.cpp      # 引擎实现
```

## 相关文档

- [3d_widget_adapter_dependency_fix.md](./3d_widget_adapter_dependency_fix.md) - 依赖问题修复
- [Lume_XComponent_Migration_Guide.md](./Lume_XComponent_Migration_Guide.md) - 迁移指南

## 日期

2026-03-29