# Lume XComponent 迁移总结文档

## 一、迁移概述

### 1.1 迁移目的

将 Lume 3D 渲染引擎从当前的 TextureLayer/SurfaceBuffer 渲染模式迁移到 HarmonyOS XComponent 直接渲染方式，简化渲染链路，提高性能和可维护性。

### 1.2 迁移日期

2026-03-26

---

## 二、文件变更

### 2.1 删除的文件/文件夹

| 路径 | 说明 |
|------|------|
| `manager/` | 旧的插件管理器，包含 `plugin_manager.h` 和 `plugin_manager.cpp` |
| `render/` | 旧的渲染实现，包含 `egl_core.h/cpp`、`EGLRender.h/cpp`、`plugin_render.h/cpp`、`EGLConst.h` |
| `common/` | 未使用的公共头文件 |

### 2.2 新增的文件

```
lume_xcomponent/
├── CMakeLists.txt                              # 构建配置
├── include/
│   ├── lume_xcomponent_types.h                 # 类型定义 (枚举、结构体)
│   ├── lume_renderer.h                         # Lume 渲染器头文件
│   ├── lume_scene_context.h                    # Scene 上下文头文件
│   └── lume_xcomponent_manager.h               # XComponent 管理器头文件
└── src/
    ├── lume_renderer.cpp                       # Lume 渲染器实现
    ├── lume_scene_context.cpp                  # Scene 上下文实现
    ├── lume_xcomponent_manager.cpp             # XComponent 管理器实现
    └── napi_init.cpp                           # NAPI 模块注册
```

### 2.3 修改的文件

| 文件 | 修改内容 |
|------|---------|
| `nativerender/CMakeLists.txt` | 移除 manager/render 引用，添加 lume_xcomponent 子目录和链接 |
| `nativerender/napi_init.cpp` | 使用 LumeXComponentManager 导出接口 |
| `3d_scene_adapter/include/scene_adapter/intf_scene_adapter.h` | 清理接口，移除 SurfaceBuffer 相关方法 |
| `3d_scene_adapter/include/scene_adapter/scene_adapter.h` | 移除 TextureLayer、SurfaceBuffer、Fence 相关成员变量 |
| `3d_scene_adapter/src/scene_adapter.cpp` | 移除 OnWindowChange、CreateFenceFD、UpdateSurfaceBuffer、AcquireImage、InitEnvironmentResource、CreateOESTextureHandle 等方法 |
| `3d_widget_adapter/CMakeLists.txt` | 移除不存在的 texture_layer.cpp、graphics_task.cpp 引用 |
| `3d_widget_adapter/include/texture_info.h` | 移除 WindowChangeInfo 结构体，标记 textureId_ 为 deprecated |
| `3d_widget_adapter/include/data_type/constants.h` | 移除未使用的 SurfaceType 枚举 |
| `kits/CMakeLists.txt` | 新增：为 JS 绑定创建 CMake 构建文件 |
| `libnativerender/Index.d.ts` | 更新 TypeScript 声明以匹配新 API，移除废弃的 drawStar，添加 drawFrame、loadScene、RenderState |

---

## 三、架构对比

### 3.1 旧架构 (已删除)

```
┌─────────────────────────────────────────────────────────────────┐
│                        旧架构                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PluginManager (单例)                                           │
│       │                                                         │
│       ├── PluginRender (每个 XComponent 一个实例)               │
│       │       │                                                 │
│       │       └── EGLCore (简单 OpenGL 绘制)                    │
│       │               └── 绘制五角星演示                        │
│       │                                                         │
│       └── OH_NativeXComponent_Callback (基本回调)               │
│                                                                 │
│  功能：简单的 OpenGL ES 演示，绘制五角星                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 新架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        新架构                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  LumeXComponentManager (单例)                                   │
│       │                                                         │
│       ├── LumeRenderer (每个 XComponent 一个实例)               │
│       │       │                                                 │
│       │       ├── EGL 环境 (与 Lume 引擎共享)                   │
│       │       ├── Lume Engine (IEngine, IRenderContext)         │
│       │       ├── ApplicationContext (Scene 桥梁)               │
│       │       ├── Swapchain (连接 NativeWindow)                 │
│       │       └── LumeSceneContext (Scene/Camera 管理)          │
│       │                                                         │
│       ├── OH_NativeXComponent_Callback (基本回调)               │
│       ├── OH_NativeXComponent_MouseEvent_Callback (鼠标回调)    │
│       └── 焦点/键盘事件回调                                     │
│                                                                 │
│  功能：完整的 Lume 3D 渲染引擎集成                              │
│        - Scene 创建与加载 (GLTF)                                │
│        - Camera 管理                                            │
│        - RenderTarget 绑定                                      │
│        - 完整渲染循环                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 四、类设计

### 4.1 LumeXComponentManager

**职责**: XComponent 生命周期管理、渲染器实例管理、NAPI 接口导出

**核心方法**:
```cpp
// NAPI 接口
static napi_value CreateNativeNode(napi_env env, napi_callback_info info);
static napi_value BindNode(napi_env env, napi_callback_info info);
static napi_value UnbindNode(napi_env env, napi_callback_info info);
static napi_value DrawFrame(napi_env env, napi_callback_info info);
static napi_value LoadScene(napi_env env, napi_callback_info info);
static napi_value GetRendererState(napi_env env, napi_callback_info info);
static napi_value SetFrameRate(napi_env env, napi_callback_info info);
static napi_value SetNeedSoftKeyboard(napi_env env, napi_callback_info info);

// XComponent 回调
void OnSurfaceCreated(OH_NativeXComponent* component, void* window);
void OnSurfaceChanged(OH_NativeXComponent* component, void* window);
void OnSurfaceDestroyed(OH_NativeXComponent* component, void* window);
void DispatchTouchEvent(OH_NativeXComponent* component, void* window);
void OnMouseEvent(OH_NativeXComponent* component, void* window);
void OnHoverEvent(OH_NativeXComponent* component, bool isHover);
void OnFocusEvent(OH_NativeXComponent* component, void* window);
void OnBlurEvent(OH_NativeXComponent* component, void* window);
void OnKeyEvent(OH_NativeXComponent* component, void* window);
```

### 4.2 LumeRenderer

**职责**: EGL 环境管理、Lume 引擎初始化、渲染循环控制

**核心方法**:
```cpp
bool Initialize(void* window, uint32_t width, uint32_t height);
void OnSurfaceChanged(void* window, uint32_t width, uint32_t height);
void OnSurfaceDestroyed();
void RenderFrame();
bool CreateScene();
bool LoadScene(const std::string& gltfPath);
```

**核心成员**:
```cpp
// EGL
EGLDisplay eglDisplay_;
EGLSurface eglSurface_;
EGLContext eglContext_;

// Lume Engine
CORE_NS::IEngine::Ptr engine_;
RENDER_NS::IRenderContext::Ptr renderContext_;
SCENE_NS::IApplicationContext::Ptr applicationContext_;

// Swapchain & RenderTarget
RENDER_NS::RenderHandleReference swapchainHandle_;
SCENE_NS::IRenderTarget::Ptr renderTarget_;
```

### 4.3 LumeSceneContext

**职责**: Scene 创建/加载、Camera 管理、RenderTarget 绑定

**核心方法**:
```cpp
bool CreateEmptyScene();
bool LoadFromGLTF(const std::string& path);
bool CreateCamera(const std::string& name);
void SetActiveCamera(const std::string& name);
bool BindRenderTargetToCamera(SCENE_NS::IRenderTarget::Ptr renderTarget);
void Update();
```

---

## 五、渲染链路

### 5.1 完整渲染流程

```
┌────────────────────────────────────────────────────────────────────┐
│                     渲染链路                                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  XComponent (ArkTS)                                                │
│       │ OnLoad()                                                   │
│       ▼                                                            │
│  createNativeNode() → LumeXComponentManager                        │
│       │ RegisterXComponent()                                       │
│       ▼                                                            │
│  OnSurfaceCreated(window)                                          │
│       │                                                            │
│       ├─► LumeRenderer::Initialize()                               │
│       │       ├─► InitializeEGL(window)                            │
│       │       │       └─► eglCreateWindowSurface, eglCreateContext │
│       │       ├─► InitializeLumeEngine()                           │
│       │       │       ├─► Create Engine                           │
│       │       │       ├─► Create RenderContext (共享 EGL Context) │
│       │       │       ├─► Create ApplicationContext               │
│       │       │       └─► Load Plugins (SCENE, JPG, PNG)         │
│       │       ├─► CreateSwapchain(window)                         │
│       │       │       └─► device.CreateSwapchainHandle            │
│       │       └─► CreateRenderTarget()                            │
│       │               └─► Bitmap → Camera::SetRenderTarget        │
│       ▼                                                            │
│  RenderFrame()                                                     │
│       ├─► scene->GetInternalScene()->Update()                     │
│       ├─► renderContext->GetRenderer().RenderFrame()              │
│       └─► eglSwapBuffers()                                        │
│               │                                                    │
│               ▼                                                    │
│         屏幕显示                                                   │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### 5.2 关键连接点

```cpp
// 1. EGL Context 共享 (关键!)
glesConfig.sharedContext = eglContext_;  // Lume 与 XComponent 共享 EGL Context

// 2. Swapchain 创建
RENDER_NS::SwapchainCreateInfo swapchainCreateInfo{
    0U,
    RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_COLOR_BUFFER_BIT |
    RENDER_NS::SwapchainFlagBits::CORE_SWAPCHAIN_DEPTH_BUFFER_BIT,
    RENDER_NS::ImageUsageFlagBits::CORE_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
    {
        reinterpret_cast<uintptr_t>(nativeWindow),  // XComponent 提供的 NativeWindow
        {},
    }
};

// 3. Camera RenderTarget 绑定
auto bitmap = obr.Create<SCENE_NS::IRenderTarget>(SCENE_NS::ClassId::Bitmap, doc);
if (auto renderResource = interface_cast<SCENE_NS::IRenderResource>(bitmap)) {
    renderResource->SetRenderHandle(swapchainHandle_);
}
camera->SetRenderTarget(bitmap);
```

---

## 六、NAPI 接口

### 6.1 导出接口列表

| 接口名 | 参数 | 说明 |
|--------|------|------|
| `createNativeNode` | (contentHandle, id) | 创建 Native XComponent 节点 |
| `bindNode` | (nodeHandle, id) | 绑定节点到渲染器 |
| `unbindNode` | (id) | 解绑节点 |
| `drawFrame` | (id) | 绘制一帧 |
| `drawPattern` | (id) | 绘制一帧 (兼容旧接口) |
| `loadScene` | (id, gltfPath) | 加载 GLTF 场景 |
| `getStatus` | (id) | 获取渲染器状态 |
| `setFrameRate` | (id, rate) | 设置帧率 |
| `setNeedSoftKeyboard` | (id, need) | 设置软键盘需求 |
| `getContext` | () | 获取上下文 (兼容) |
| `initialize` | () | 初始化 (兼容) |
| `finalize` | () | 反初始化 (兼容) |

### 6.2 ArkTS 调用示例

```typescript
import nativerender from 'nativerender';

@Entry
@Component
struct LumeScenePage {
  private xcomponentController: XComponentController = new XComponentController();
  private nodeId: string = 'lume_scene_1';

  build() {
    Column() {
      XComponent({
        id: this.nodeId,
        type: XComponentType.SURFACE,
        controller: this.xcomponentController
      })
        .onLoad(() => {
          // 创建 Native 节点
          nativerender.createNativeNode(this.xcomponentController, this.nodeId);
        })
        .width('100%')
        .height('100%')

      Row() {
        Button('Load Scene')
          .onClick(() => {
            nativerender.loadScene(this.nodeId, 'models/scene.gltf');
          })

        Button('Draw Frame')
          .onClick(() => {
            nativerender.drawFrame(this.nodeId);
          })

        Button('Set 60 FPS')
          .onClick(() => {
            nativerender.setFrameRate(this.nodeId, 60);
          })
      }
    }
  }
}
```

---

## 七、功能对比

| 功能 | 旧实现 (manager/render) | 新实现 (lume_xcomponent) |
|------|------------------------|-------------------------|
| **渲染能力** | 简单 OpenGL 演示 (五角星) | 完整 Lume 3D 渲染引擎 |
| **场景支持** | 无 | Scene 创建、GLTF 加载 |
| **相机管理** | 无 | Camera 创建、配置、激活 |
| **渲染目标** | 直接 EGL Surface | RenderTarget → Swapchain → NativeWindow |
| **触摸事件** | 基本支持 | 完整支持 + 工具类型、倾斜角度 |
| **鼠标事件** | 支持 | 支持 + 修饰键状态 |
| **键盘事件** | 支持 | 支持 + NumLock/CapsLock/ScrollLock |
| **焦点事件** | 支持 | 支持 (Focus/Blur) |
| **帧率控制** | 有示例代码 | 完整实现 |
| **软键盘** | 有示例代码 | 完整实现 |
| **引擎架构** | 无引擎概念 | IEngine → IRenderContext → IApplicationContext |

---

## 八、注意事项

### 8.1 EGL Context 共享

```cpp
// 关键：Lume 需要共享 XComponent 的 EGL Context
RENDER_NS::BackendExtraGLES glesConfig{};
glesConfig.sharedContext = eglContext_;  // 从 XComponent 获取
```

### 8.2 线程安全

- XComponent 回调在 UI 线程执行
- Lume 渲染需要在专用渲染线程
- 使用 `std::mutex` 保护共享数据

### 8.3 资源生命周期

- `OnSurfaceDestroyed` 中必须释放所有资源
- Swapchain 必须在 Surface 销毁前销毁
- EGL Context 需要正确释放

---

## 九、双系统架构

迁移后，系统分为两个独立模块，各司其职：

### 9.1 lume_xcomponent (XComponent 渲染)

**职责**: 直接渲染到 XComponent Surface

```
ArkTS XComponent
       │
       ▼
LumeXComponentManager (单例)
       │
       ├── LumeRenderer (每个 XComponent 一个实例)
       │       ├── EGL 环境 (独立)
       │       ├── Lume Engine (共享引擎实例)
       │       ├── Swapchain (连接 NativeWindow)
       │       └── LumeSceneContext (Scene/Camera 管理)
       │
       └── XComponent 回调 (触摸/鼠标/键盘/焦点)
```

**NAPI 接口**:
- `createNativeNode` - 创建 Native 节点
- `loadScene` - 加载 GLTF 场景
- `drawFrame` - 绘制帧
- `setFrameRate` - 设置帧率

### 9.2 3d_scene_adapter + kits/js (Scene API 操作)

**职责**: 为 ArkTS 提供 Scene 操作 API

```
ArkTS Scene API (kits/js)
       │
       ▼
SceneAdapter (单例)
       ├── LoadPluginsAndInit() - 引擎初始化
       ├── RenderFrame() - 渲染帧
       ├── Deinit() - 反初始化
       └── SetSceneObj() - 设置 Scene 对象
       │
       ▼
共享引擎实例
```

**kits/js 接口** (保留用于 Scene 操作):
- `createScene` - 创建 Scene
- `loadScene` - 加载场景
- `createCamera` - 创建相机
- Scene 对象操作 (材质、网格、动画等)

### 9.3 共享资源

两个模块共享以下引擎实例:

```cpp
static EngineInstance engineInstance_;
    ├── engine_          // CORE_NS::IEngine
    ├── renderContext_   // RENDER_NS::IRenderContext
    └── applicationContext_ // SCENE_NS::IApplicationContext
```

### 9.4 使用场景

| 场景 | 使用模块 |
|------|---------|
| XComponent 直接渲染 | `lume_xcomponent` |
| ArkTS Scene API 操作 | `kits/js` → `SceneAdapter` |
| 自定义渲染管线 | 两者结合使用 |

---

## 十、3d_widget_adapter 模块说明

### 10.1 模块职责

`3d_widget_adapter` 是一个独立的 Lume 引擎封装层，提供：

- `IEngine` 接口 - 引擎抽象接口
- `LumeCommon` - Lume 引擎实现封装
- `GraphicsManager` - 引擎实例管理
- `WidgetAdapter` - 面向用户的适配器
- `OffScreenContextHelper` - 离屏 EGL Context 管理

### 10.2 与 XComponent 的兼容性

`LumeCommon` 已经兼容 XComponent 架构：

```cpp
// SetupCustomRenderTarget() - 根据纹理 ID 判断模式
if (info.textureId_ == 0U && info.nativeWindow_) {
    CreateSwapchain(info.nativeWindow_);  // XComponent 模式
} else {
    // 纹理模式 (已弃用)
}

// DrawFrame() - 在 Swapchain 模式下跳过纹理内存屏障
if (textureInfo_.textureId_ == 0U && textureInfo_.nativeWindow_) {
    return;  // XComponent 模式，不需要纹理内存屏障
}
AddTextureMemoryBarrrier();  // 仅纹理模式需要
```

### 10.3 TextureInfo 结构体

```cpp
struct TextureInfo {
    uint32_t width_ = 0U;
    uint32_t height_ = 0U;
    uint32_t textureId_ = 0U;  // Deprecated: XComponent 模式下总是 0
    void* nativeWindow_ = nullptr;  // XComponent 提供的 NativeWindow
    float widthScale_ = 1.0f;
    float heightScale_ = 1.0f;
    float customRatio_ = 0.1f;
    bool recreateWindow_ = true;
};
```

### 10.4 依赖关系

```
3d_scene_adapter
    └── 依赖 widget_adapter_src (3d_widget_adapter)
```

---

## 十一、参考文档

- [Lume_XComponent_Migration_Guide.md](Lume_XComponent_Migration_Guide.md) - 迁移指南
- HarmonyOS XComponent 开发指导
- OpenGL ES 3.0 规范
- EGL 规范