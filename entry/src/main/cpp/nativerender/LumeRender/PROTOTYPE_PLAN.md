# LumeRender 最小原型移植计划

## 目标
先构建基础渲染能力，再移植高层设计。

---

## GL 文件辐射图

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           GL 文件辐射图 - 由内到外                               │
└─────────────────────────────────────────────────────────────────────────────────┘

                              ╔═══════════════════╗
                              ║   OpenGL/GLES     ║
                              ║   Native API      ║
                              ╚══════════╤════════╝
                                         │
     ┌───────────────────────────────────┼───────────────────────────────────┐
     │                                   │                                   │
     ▼                                   ▼                                   ▼
┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐
│  【第0层】      │              │  【第0层】      │              │  【第0层】      │
│  函数指针声明    │              │  EGL 上下文     │              │  平台设备       │
│                 │              │                 │              │                 │
│ gl_functions.h  │              │ egl_state.h     │              │ platform_device │
│                 │              │ egl_state.cpp   │              │ _gles.cpp       │
│ 声明所有PFNGL*  │              │                 │              │                 │
│ 函数指针        │              │ eglInitialize   │              │ OH_NativeBuffer │
│                 │              │ eglCreateContext│              │ EGLImage互操作  │
│                 │              │ eglMakeCurrent  │              │                 │
└────────┬────────┘              └────────┬────────┘              └────────┬────────┘
         │                                │                                │
         │                                │                                │
         └────────────────────────────────┼────────────────────────────────┘
                                          │
                                          ▼
                              ╔══════════════════════════╗
                              ║      【第1层】           ║
                              ║      设备核心层          ║
                              ║                          ║
                              ║   device_gles.h          ║
                              ║   device_gles.cpp        ║
                              ║                          ║
                              ║ • GL状态缓存管理         ║
                              ║ • 资源创建/销毁入口      ║
                              ║ • Shader编译             ║
                              ║ • VAO/FBO管理           ║
                              ╚══════════╤═══════════════╝
                                         │
         ┌───────────────────────────────┼───────────────────────────────┐
         │                               │                               │
         ▼                               ▼                               ▼
┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐
│  【第2层】      │              │  【第2层】      │              │  【第2层】      │
│  资源管理       │              │  管线状态       │              │  渲染后端       │
│                 │              │                 │              │                 │
│ gpu_buffer_gles │              │ pipeline_state  │              │ render_backend  │
│ gpu_image_gles  │              │ _object_gles    │              │ _gles          │
│ gpu_sampler_gles│              │                 │              │                 │
│ gpu_program_gles│              │ 顶点格式转换    │              │ glDrawArrays    │
│ gpu_query_gles  │              │ 状态绑定        │              │ glDispatch      │
│ gpu_semaphore   │              │                 │              │ Compute         │
│ _gles           │              │                 │              │                 │
└────────┬────────┘              └────────┬────────┘              └────────┬────────┘
         │                                │                                │
         │                                │                                │
         ▼                                ▼                                ▼
┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐
│  【第2层-依赖】 │              │  【第2层-依赖】 │              │  【第2层-依赖】 │
│                 │              │                 │              │                 │
│ spirv_cross_    │              │ shader_module   │              │ render_frame_   │
│ helpers_gles    │              │ _gles           │              │ sync_gles       │
│                 │              │                 │              │                 │
│ SPIRV→GLSL转换  │              │ Shader反射解析  │              │ glFinish        │
└─────────────────┘              └─────────────────┘              └─────────────────┘

         │                                │                                │
         └────────────────────────────────┼────────────────────────────────┘
                                          │
                                          ▼
                              ╔══════════════════════════╗
                              ║      【第3层】           ║
                              ║      平台抽象层          ║
                              ║                          ║
                              ║   swapchain_gles         ║
                              ║   node_context_pool_     ║
                              ║   manager_gles           ║
                              ║                          ║
                              ║   交换链、上下文池管理   ║
                              ╚══════════╤═══════════════╝
                                         │
                                         ▼
                              ╔══════════════════════════╗
                              ║      【第4层】           ║
                              ║      高层接口            ║
                              ║                          ║
                              ║   render_context.cpp     ║
                              ║   render_data_loader     ║
                              ║   shader_state_loader    ║
                              ║                          ║
                              ║   场景管理、资源加载      ║
                              ╚══════════════════════════╝
```

### 文件依赖关系表

| 文件 | 直接依赖 | GL函数类别 |
|------|---------|-----------|
| `gl_functions.h` | 无 | 声明 |
| `egl_state.cpp` | `gl_functions.h` | eglXXX |
| `device_gles.cpp` | `egl_state`, `gl_functions` | glCreateXXX, glDeleteXXX |
| `gpu_buffer_gles.cpp` | `device_gles` | glGenBuffers, glBufferData |
| `gpu_image_gles.cpp` | `device_gles` | glGenTextures, glTexStorage |
| `gpu_program_gles.cpp` | `device_gles`, `spirv_cross` | glCreateProgram, glLinkProgram |
| `render_backend_gles.cpp` | `device_gles`, 所有资源 | glDrawXXX, glDispatchCompute |

---

## 移植路线图

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                           移植路线图                                           │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  阶段1: 基础设施 (必做)                                                        │
│  ══════════════════════════                                                    │
│  ├─ gl_functions.h          ← 函数指针声明，直接复制修改                       │
│  ├─ egl_state.h/cpp         ← EGL上下文，核心基础                              │
│  └─ device_gles.h/cpp       ← 设备初始化，状态缓存                             │
│                                                                                │
│  阶段2: 资源管理                                                               │
│  ════════════════                                                             │
│  ├─ gpu_buffer_gles         ← Buffer管理 (VBO/UBO)                            │
│  ├─ gpu_image_gles          ← Texture管理                                     │
│  ├─ gpu_sampler_gles        ← Sampler状态                                     │
│  └─ gpu_program_gles        ← Shader程序                                      │
│                                                                                │
│  阶段3: 渲染管线                                                               │
│  ════════════════                                                             │
│  ├─ render_backend_gles     ← 绘制命令                                        │
│  ├─ pipeline_state_object   ← 管线状态                                        │
│  └─ swapchain_gles          ← 交换链                                          │
│                                                                                │
│  阶段4: 高层功能 (可选)                                                        │
│  ═════════════════════                                                        │
│  ├─ spirv_cross_helpers     ← SPIRV编译 (如果不用SPIRV可跳过)                  │
│  ├─ render_context          ← 渲染上下文                                      │
│  └─ render_data_loader      ← 资源加载器                                      │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 阶段1: 最小原型 (预计 3-5 天)

### 1.1 文件清单
```
prototype/
├── CMakeLists.txt
├── src/
│   ├── main.cpp                    # 入口
│   ├── gl_functions.h              # 从 Lume 复制，精简
│   ├── egl_state.h/cpp             # 从 Lume 复制
│   ├── device_gles.h/cpp           # 从 Lume 复制，精简
│   ├── shader_simple.h/cpp          # 简化版 shader 编译
│   └── renderer_simple.cpp          # 三角形渲染测试
└── shaders/
    ├── basic.vert                   # 简单顶点着色器
    └── basic.frag                   # 简单片元着色器
```

### 1.2 核心功能
- [ ] EGL 上下文创建
- [ ] GL 函数指针加载
- [ ] Shader 编译链接着色
- [ ] 绘制一个三角形

### 1.3 验证标准
- NDK 编译通过
- 在 HarmonyOS 设备上显示一个彩色三角形

---

## 阶段2: 资源管理 (预计 5-7 天)

### 2.1 新增文件
```
src/
├── gpu_buffer_gles.h/cpp       # Buffer 管理
├── gpu_image_gles.h/cpp        # Texture 管理
├── gpu_sampler_gles.h/cpp      # Sampler 管理
└── gpu_program_gles.h/cpp      # Program 完整实现
```

### 2.2 核心功能
- [ ] VBO 创建和绑定
- [ ] UBO 创建和绑定
- [ ] Texture2D 加载
- [ ] Sampler 状态设置
- [ ] Uniform 绑定

### 2.3 验证标准
- 绘制一个带纹理的立方体
- 支持基础光照

---

## 阶段3: 渲染管线 (预计 7-10 天)

### 3.1 新增文件
```
src/
├── render_backend_gles.h/cpp       # 绘制命令
├── pipeline_state_object_gles.h/cpp # 管线状态
├── swapchain_gles.h/cpp             # 交换链
└── gpu_query_gles.h/cpp             # GPU 查询
```

### 3.2 核心功能
- [ ] Draw call 封装
- [ ] 管线状态管理 (blend, depth, stencil)
- [ ] 多渲染目标支持
- [ ] GPU 时间查询

### 3.3 验证标准
- 支持多 Pass 渲染
- 支持后处理效果

---

## 阶段4: 高层功能 (按需)

### 4.1 可选文件
- spirv_cross_helpers_gles.cpp - SPIRV 编译
- render_context.cpp - 渲染上下文
- render_data_loader.cpp - 资源加载
- node_context_pool_manager_gles.cpp - 上下文池

### 4.2 决策点
- 如果使用 SPIRV 着色器，需要移植 spirv_cross
- 如果使用场景图，需要移植 render_context 和 loader

---

## 文件精简策略

### 从 gl_functions.h 精简
原始文件约 500+ 行，原型只需:
```cpp
// 只保留核心函数
PFNGLCREATESHADERPROC glCreateShader;
PFNGLSHADERSOURCEPROC glShaderSource;
PFNGLCOMPILESHADERPROC glCompileShader;
PFNGLCREATEPROGRAMPROC glCreateProgram;
PFNGLATTACHSHADERPROC glAttachShader;
PFNGLLINKPROGRAMPROC glLinkProgram;
PFNGLUSEPROGRAMPROC glUseProgram;
PFNGLGENBUFFERSPROC glGenBuffers;
PFNGLBINDBUFFERPROC glBindBuffer;
PFNGLBUFFERDATAPROC glBufferData;
PFNGLGENVERTEXARRAYSPROC glGenVertexArrays;
PFNGLBINDVERTEXARRAYPROC glBindVertexArray;
// ... 约 50 个函数
```

### 从 device_gles.cpp 精简
原始文件可能有数千行，原型只需:
- 设备初始化
- Shader 创建/销毁
- Buffer 创建/销毁
- VAO 创建/销毁
- 状态缓存基础

---

## 依赖图

```
                    gl_functions.h
                          │
                          ▼
                    egl_state.cpp
                          │
                          ▼
                   device_gles.cpp
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
   gpu_buffer_gles  gpu_program_gles  render_backend_gles
          │               │               │
          └───────────────┴───────────────┘
                          │
                          ▼
                    应用层代码
```

---

## 下一步行动

1. 复制 `gl_functions.h` 到原型目录
2. 精简到只保留 GLES 3.0 核心函数
3. 复制 `egl_state.h/cpp`
4. 创建简化的 `device_gles`
5. 编写三角形测试

---

## 完整依赖辐射图

### DeviceGLES 依赖辐射图

详见 [DEVICE_GLES_DEPENDENCIES.md](../../docs/DEVICE_GLES_DEPENDENCIES.md)

```
                              ┌─────────────────────────────────────────────────────────┐
                              │                    device_gles.h                         │
                              │                   (核心设备抽象层)                        │
                              └─────────────────────────────────────────────────────────┘
                                                         │
           ┌─────────────────────────────────────────────┼─────────────────────────────────────────────┐
           │                                             │                                             │
           ▼                                             ▼                                             ▼
┌──────────────────────┐                    ┌──────────────────────┐                    ┌──────────────────────┐
│   C++ 标准库          │                    │    Lume Base 库       │                    │   Lume Render 接口    │
│   [保留]             │                    │    [保留]             │                    │   [精简]             │
└──────────────────────┘                    └──────────────────────┘                    └──────────────────────┘
           │                                             │                                             │
           ▼                                             ▼                                             ▼
┌──────────────────────┐                    ┌──────────────────────┐                    ┌──────────────────────┐
│ • <cstddef>          │                    │ • string_view        │                    │ • pipeline_state_desc│
│ • <cstdint>          │                    │ • unique_ptr         │                    │ • intf_device_gles   │
│ • <mutex>            │                    │ • vector             │                    │ • resource_handle    │
│ • <algorithm>        │                    │ • vector (math)      │                    │ • namespace          │
└──────────────────────┘                    │ • compile_time_hashes│                    └──────────────────────┘
                                            └──────────────────────┘
                                                         │
           ┌─────────────────────────────────────────────┼─────────────────────────────────────────────┐
           │                                             │                                             │
           ▼                                             ▼                                             ▼
┌──────────────────────┐                    ┌──────────────────────┐                    ┌──────────────────────┐
│  device/device.h     │                    │  egl_state.h         │                    │  gles/swapchain_gles │
│  [保留] 设备基类      │                    │  [保留] EGL 管理     │                    │  [保留] 交换链        │
└──────────────────────┘                    └──────────────────────┘                    └──────────────────────┘
```

### RenderContext 依赖辐射图

详见 [RENDER_CONTEXT_DEPENDENCIES.md](../../docs/RENDER_CONTEXT_DEPENDENCIES.md)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                   RenderContext                                      │
│                              (渲染上下文顶层管理器)                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│  职责:                                                                               │
│  • 创建和管理渲染设备 (Device)                                                        │
│  • 管理渲染生命周期 (Init/Shutdown)                                                   │
│  • 注册后处理效果插件                                                                 │
│  • 提供接口查询服务                                                                   │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                              │
               ┌──────────────────────────────┼──────────────────────────────┐
               │                              │                              │
               ▼                              ▼                              ▼
    ┌─────────────────────┐       ┌─────────────────────┐       ┌─────────────────────┐
    │     Core 引擎层      │       │    Render 设备层    │       │   高层渲染系统       │
    │     [精简]          │       │     [保留]          │       │     [删除]          │
    └─────────────────────┘       └─────────────────────┘       └─────────────────────┘
               │                              │                              │
               ▼                              ▼                              ▼
    ┌─────────────────────┐       ┌─────────────────────┐       ┌─────────────────────┐
    │ • IEngine           │       │ • Device            │       │ • Renderer          │
    │ • IFileManager      │       │ • DeviceGLES        │       │ • RenderNodeGraph   │
    │ • IClassRegister    │       │ • SwapchainGLES     │       │ • RenderDataStore   │
    │ • IPluginRegister   │       │                     │       │ • RenderUtil        │
    └─────────────────────┘       └─────────────────────┘       │ • PostProcess*      │
                                                                └─────────────────────┘
```

### 层级依赖总图

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                    层级依赖总图                                       │
└─────────────────────────────────────────────────────────────────────────────────────┘

层级 0: 平台原生 API
├── GLES 3.x (移动端)                    [必须]
├── OpenGL 4.x (桌面)                    [可选]
└── EGL / WGL (上下文管理)               [必须]
        │
        ▼
层级 1: 函数加载层
├── gl_functions.h  ─────────── 函数指针声明        [必须实现]
├── gl_loader.cpp   ─────────── 函数指针加载        [必须实现]
        │
        ▼
层级 2: 资源封装层
├── gpu_buffer_gles   ───────── Buffer (glGenBuffers, glBufferData)     [必须]
├── gpu_image_gles    ───────── Texture (glGenTextures, glTexStorage2D) [必须]
├── gpu_sampler_gles  ───────── Sampler (glGenSamplers, glSamplerParameteri) [必须]
├── gpu_program_gles  ───────── Program (glCreateProgram, glAttachShader)    [必须]
└── shader_module_gles ──────── Shader (glCreateShader, glCompileShader)     [必须]
        │
        ▼
层级 3: 设备抽象层
├── device_gles.h     ───────── 设备接口，资源工厂    [必须]
├── device_gles.cpp   ───────── 设备实现，状态缓存    [必须]
├── egl_state.h       ───────── EGL 上下文生命周期    [必须]
└── swapchain_gles    ───────── 显示交换链            [必须]
        │
        ▼
层级 4: 管理器层 [原型可选]
├── gpu_resource_manager ────── 资源池管理            [精简]
└── shader_manager       ────── Shader 加载/缓存      [精简]
        │
        ▼
层级 5: 上下文层 [原型精简]
├── render_context        ───── 渲染上下文            [精简]
└── render_data_loader    ───── 资源加载器            [删除]
        │
        ▼
层级 6: 高层渲染层 [原型删除]
├── render_backend        ───── 渲染调度              [删除]
├── pipeline_state_object ───── PSO 缓存              [删除]
├── node_context_*        ───── 描述符/上下文管理     [删除]
└── post_process_*        ───── 后处理效果            [删除]
```

---

## 精简统计汇总

| 模块 | 原始文件数 | 精简后 | 精简比例 |
|------|-----------|--------|---------|
| **gl_functions.h** | ~500 行 | ~80 行 | 84% |
| **device_gles.h** | ~450 行 | ~120 行 | 73% |
| **device_gles.cpp** | ~2000 行 | ~550 行 | 72% |
| **render_context.h** | ~355 行 | ~50 行 | 86% |
| **render_context.cpp** | ~600 行 | ~80 行 | 87% |
| **格式定义** | ~150 种 | ~15 种 | 90% |
| **后处理效果** | 18 个文件 | 0 | 100% |
| **头文件依赖总数** | 43 个 | 6 个 | 86% |

---

## 相关文档

| 文档 | 路径 | 内容 |
|------|------|------|
| DeviceGLES 依赖分析 | [docs/DEVICE_GLES_DEPENDENCIES.md](../../docs/DEVICE_GLES_DEPENDENCIES.md) | 设备层依赖详情 |
| RenderContext 依赖分析 | [docs/RENDER_CONTEXT_DEPENDENCIES.md](../../docs/RENDER_CONTEXT_DEPENDENCIES.md) | 上下文层依赖详情 |
| DeviceGLES 注释版头文件 | [docs/device_gles_annotated.h](../../docs/device_gles_annotated.h) | 带标注的精简版 |
| DeviceGLES 注释版源文件 | [docs/device_gles_annotated.cpp](../../docs/device_gles_annotated.cpp) | 带标注的精简版 |