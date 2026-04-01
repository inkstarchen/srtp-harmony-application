# GL 函数指针内存访问错误分析

## 问题描述

使用 `eglGetProcAddress` 在运行时加载 GL 扩展函数时，赋值操作导致段错误：

```
Reason: Signal: SIGSEGV(SEGV_ACCERR) @ 0x0000005a9b13ac88
```

- `SEGV_ACCERR` 表示内存地址有效，但访问被拒绝（只读）
- 变量地址 `0x0000005a9b13ac88` 是有效且可访问的

## 关键观察

```cpp
// 这行代码正常工作 - 编译时初始化
PFNGLBUFFERSTORAGEEXTPROC glBufferStorageEXT = nullptr;

// 这行代码崩溃 - 运行时赋值
glBufferStorageEXT = (PFNGLBUFFERSTORAGEEXTPROC)eglGetProcAddress("glBufferStorageEXT");
```

既然 `nullptr` 可以在编译时初始化赋值，为什么 `eglGetProcAddress` 的结果在运行时赋值会崩溃？

## 根本原因分析

### ELF 内存段

| 段 | 用途 | 可读 | 可写 |
|---------|---------|----------|----------|
| `.text` | 代码 | 是 | 否 |
| `.rodata` | 只读数据（常量） | 是 | 否 |
| `.data` | 已初始化的读写数据 | 是 | 是 |
| `.bss` | 未初始化的读写数据 | 是 | 是 |

### 编译时 vs 运行时赋值

**编译时初始化（`a b = nullptr;`）：**
- 值由编译器直接写入目标文件
- 链接器根据变量特性决定放置位置
- 如果用"常量"值初始化，链接器可能将其优化到 `.rodata`

**运行时赋值（`b = value;`）：**
- 需要实际的内存写指令
- 如果内存在 `.rodata` 中，写入操作会导致 SIGSEGV

### 为什么链接器选择 .rodata

当使用 `$<TARGET_OBJECTS:...>` 链接时：
1. 目标文件从静态库中提取
2. 链接器看到用 `nullptr`（常量）初始化的全局变量
3. 链接器可能将其优化放置到 `.rodata`
4. 结果：地址有效，但内存被写保护

## 解决方案

### 方案：未初始化变量

将已初始化变量改为未初始化的全局变量：

```cpp
// 修改前（可能进入 .rodata）
#define declare(a, b) a b = nullptr;

// 修改后（进入 .bss，可写）
#define declare(a, b) a b;
```

未初始化的全局变量会被放置在 `.bss` 段：
- 由运行时加载器自动初始化为零
- 保证可写
- 不会有编译时常量优化

### 替代方案：强制指定段属性

```cpp
// 强制放置在 .data 段
#define declare(a, b) __attribute__((section(".data"))) a b = nullptr;
```

## 相关问题

### GL_GLEXT_PROTOTYPES 宏

在 `gl2ext.h` 中：
```c
#ifdef GL_GLEXT_PROTOTYPES
GL_APICALL void GL_APIENTRY glBufferStorageEXT(...);
#endif
```

如果定义了 `GL_GLEXT_PROTOTYPES`：
- `glBufferStorageEXT` 被声明为函数（不是函数指针）
- 与我们的函数指针声明冲突

**解决方案：** 从 CMakeLists.txt 的编译定义中移除 `GL_GLEXT_PROTOTYPES`。

### 声明与定义的一致性

确保声明和定义的链接方式一致：

```cpp
// 声明（gl_functions.h）
#define declare(a, b) extern a b

// 定义（egl_state.cpp）
#define declare(a, b) a b;
```

不要使用 `extern "C"` 块 — 函数指针是 C++ 变量，不是 C 函数。

## 总结

| 问题 | 原因 | 解决方案 |
|-------|-------|----------|
| 赋值时 SIGSEGV | 变量在 `.rodata` 中 | 使用未初始化变量（进入 `.bss`） |
| 函数声明冲突 | 定义了 `GL_GLEXT_PROTOTYPES` | 从编译定义中移除 |
| 链接方式不匹配 | 声明和定义的 `extern` 不一致 | 使用一致的简单 `extern` |

---

## 替代方案：直接使用系统函数声明

### 原理

在 `gl2ext.h` 中，扩展函数声明受 `GL_GLEXT_PROTOTYPES` 宏控制：

```c
#ifdef GL_GLEXT_PROTOTYPES
GL_APICALL void GL_APIENTRY glBufferStorageEXT(GLenum target, GLsizeiptr size, const void *data, GLbitfield flags);
#endif
```

### 方案对比

| 方案 | 实现方式 | 优点 | 缺点 |
|------|----------|------|------|
| **动态加载** | `eglGetProcAddress` + 函数指针 | 可检测扩展是否支持，可用后备方案 | 代码复杂，需处理内存段问题 |
| **直接调用** | 定义 `GL_GLEXT_PROTOTYPES`，直接调用系统声明 | 简单，无额外代码 | 设备必须支持扩展，否则崩溃 |

### 直接调用方案实现

**1. 在 CMakeLists.txt 中添加宏定义：**

```cmake
target_compile_definitions(your_target PRIVATE
    GL_GLEXT_PROTOTYPES
    EGL_EGLEXT_PROTOTYPES
)
```

**2. 直接调用扩展函数：**

```cpp
#include <GLES2/gl2ext.h>

// 直接调用，无需函数指针
if (hasExtension("GL_EXT_buffer_storage")) {
    glBufferStorageEXT(target, size, data, flags);
} else {
    glBufferData(target, size, data, usage);  // 后备方案
}
```

**3. 移除 gl_functions.h 中的 declare 声明：**

```cpp
// 注释掉或删除这些行
// declare(PFNGLBUFFERSTORAGEEXTPROC, glBufferStorageEXT);
// declare(PFNGLEGLIMAGETARGETTEXTURE2DOESPROC, glEGLImageTargetTexture2DOES);
```

**4. 移除 egl_state.cpp 中的函数指针定义和加载：**

不需要 `#define declare(a, b) a b;` 和重包含 `gl_functions.h` 的代码。

### 使用条件

**适合使用直接调用方案：**
- 目标设备确定支持所需扩展
- 不需要兼容不支持扩展的设备
- 追求代码简洁

**适合使用动态加载方案：**
- 需要兼容多种设备
- 需要检测扩展是否可用
- 需要后备方案处理不支持的情况

### 完整示例

**egl_state.cpp 简化版（直接调用方案）：**

```cpp
#include <GLES3/gl3.h>
#include <GLES2/gl2ext.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>

// 不需要函数指针定义
// 不需要 GlInitialize 中的 eglGetProcAddress 调用

void EGLState::GlInitialize()
{
    // 只需要获取设备信息和扩展列表
    plat_.deviceName = reinterpret_cast<const char*>(glGetString(GL_RENDERER));
    plat_.driverVersion = reinterpret_cast<const char*>(glGetString(GL_VERSION));
    FillExtensions(extensions_);
    SetSwapInterval(1);
}
```

**gpu_buffer_gles.cpp 使用：**

```cpp
void GpuBufferGLES::CreateBuffer(...)
{
    // 直接调用，系统头文件已声明
    if (device_.HasExtension("GL_EXT_buffer_storage")) {
        glBufferStorageEXT(target, size, nullptr, flags);
    } else {
        glBufferData(target, size, nullptr, GL_DYNAMIC_DRAW);
    }
}
```

### 注意事项

1. **链接问题**：如果设备不支持扩展，链接阶段可能失败（静态链接）或运行时崩溃（动态链接）

2. **EGL 扩展**：同样需要 `EGL_EGLEXT_PROTOTYPES` 来启用 EGL 扩展函数声明

3. **平台差异**：不同平台的 GLES 实现可能不同，需要测试验证