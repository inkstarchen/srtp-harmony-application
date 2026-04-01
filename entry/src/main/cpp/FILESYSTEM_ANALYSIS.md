# 鸿蒙NDK Filesystem 实现分析文档

> 本文档分析 HarmonyOS NDK 项目中的文件系统抽象层实现

---

## 一、概述

本项目实现了一套完整的文件系统抽象层，采用**基于协议的URI系统**，支持多种存储介质和虚拟文件系统。核心架构如下：

```
┌─────────────────────────────────────────────────────────────┐
│                      FileManager                             │
│  (文件管理器 - 统一入口)                                      │
├─────────────────────────────────────────────────────────────┤
│   RegisterFilesystem()  │  RegisterPath()                   │
│   OpenFile()            │  CreateFile()                     │
│   GetEntry()            │  DeleteFile()                     │
└───────────────────┬─────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┬───────────────────┬──────────────┐
        │                       │                   │              │
┌───────▼───────┐   ┌───────────▼───────────┐ ┌────▼────┐ ┌───────▼───────┐
│ StdFilesystem │   │   ProxyFilesystem     │ │ MemoryFs│ │ OhosFilesystem│
│  (file://)    │   │  (自定义协议代理)      │ │(memory://)│ │(OhosRawFile://)│
└───────────────┘   └───────────────────────┘ └─────────┘ └───────────────┘
        │                       │
        │               ┌───────┴───────┐
        │               │ destinations_ │
        │               │  (搜索路径列表) │
        │               └───────────────┘
```

---

## 二、协议URI系统

### 2.1 支持的协议

| 协议 | 实现类 | 用途 | 示例 |
|------|--------|------|------|
| `file://` | StdFilesystem | 标准OS文件系统I/O | `file:///data/local/tmp/file.txt` |
| `memory://` | MemoryFilesystem | 内存虚拟文件系统 | `memory://config.json` |
| `rofs://` / `corerofs://` | RoFileSystem | 只读嵌入式二进制数据 | `corerofs://core/shaders/` |
| `OhosRawFile://` | OhosFilesystem | 鸿蒙HAP资源RawFile访问 | `OhosRawFile://shaders/vertex.spv` |
| `cache://` | ProxyFilesystem | 缓存目录（外部注册） | `cache://deviceVkCache.bin` |
| 自定义协议 | ProxyFilesystem | 路径映射代理 | `shaders://myshader.spv` |

### 2.2 URI格式规范

```
protocol://path

protocol: 协议名称（不含://）
path: 文件或目录路径（相对或绝对）
```

**解析函数** (`path_tools.cpp`):
```cpp
bool ParseUri(const string_view uri, string_view& protocol, string_view& path);
// "OhosRawFile://shaders/vertex.spv" → protocol="OhosRawFile", path="shaders/vertex.spv"
```

---

## 三、路径访问机制

### 3.1 支持的路径类型

1. **绝对路径**：`file:///data/local/tmp/file.txt`
2. **相对路径**：相对于 `basePath_`（当前工作目录）
3. **协议路径**：`OhosRawFile://shaders/vertex.spv`

### 3.2 根路径设定

**是否需要人为设定根路径：是**

根路径配置位置：
- `platform_create_info.h` - 平台创建信息中的默认配置
- `FileManager` 构造函数 - 初始化 `basePath_`

```cpp
// platform_create_info.h 中的默认配置
BASE_NS::string coreRootPath = "./";
BASE_NS::string appRootPath = "./";

// file_manager.cpp 中FileManager构造函数
FileManager::FileManager() : basePath_(GetCurrentDirectory()) {}
```

**FixPath()方法** 将相对路径解析为绝对路径：
```cpp
string FileManager::FixPath(const string_view pathIn) const
{
    if (IsRelative(pathIn)) {
        return basePath_ + pathIn;
    }
    return string(pathIn);
}
```

### 3.3 可访问路径列表

| 协议 | 访问范围 | 权限 |
|------|----------|------|
| `file://` | OS文件系统任意路径（受权限限制） | 读写 |
| `memory://` | 内存虚拟路径 | 读写 |
| `rofs://` / `corerofs://` | 嵌入式只读数据包 | 只读 |
| `OhosRawFile://` | HAP包内resources/rawfile目录 | 只读 |
| `cache://` | 应用缓存目录（由平台注册） | 读写 |
| 自定义协议 | 由RegisterPath指定的目标路径 | 继承目标权限 |

---

## 四、代理文件系统 (ProxyFilesystem)

### 4.1 工作原理

`ProxyFilesystem` 作为虚拟文件系统，将协议请求代理到多个目标路径（destinations_）：

```
请求 "shaders://vertex.spv"
        ↓
ProxyFilesystem.OpenFile("vertex.spv")
        ↓
遍历 destinations_ 列表:
  1. 尝试 "OhosRawFile://shaders/vertex.spv" → 找到 ✓
  2. 尝试 "engine://shaders/vertex.spv" （未找到则继续）
        ↓
返回找到的文件
```

### 4.2 核心方法

| 方法 | 功能 |
|------|------|
| `AppendSearchPath(path)` | 添加路径到搜索列表末尾 |
| `PrependSearchPath(path)` | 添加路径到搜索列表开头（优先搜索） |
| `RemoveSearchPath(destination)` | 移除搜索路径 |

### 4.3 文件打开实现

```cpp
IFile::Ptr ProxyFilesystem::OpenFile(const string_view path, const IFile::Mode mode)
{
    auto normalizedPath = NormalizePath(path);
    for (auto&& destination : destinations_) {
        // 拼接目标路径 + 文件路径
        auto file = fileManager_.OpenFile(destination + normalizedPath, mode);
        if (file) {
            return file;  // 找到就返回
        }
    }
    return {};  // 所有路径都没找到
}
```

---

## 五、注册机制详解

### 5.1 核心问题回答

| 问题 | 答案 |
|------|------|
| **是否需要逐个注册文件夹？** | **是的**，每个协议的每个搜索路径都需要单独调用 `RegisterPath()` |
| **注册顺序重要吗？** | 是的，`prepend=true` 会优先搜索，`prepend=false` 会在末尾搜索 |

### 5.2 两种注册方式

#### 方式一：RegisterFilesystem

注册完整的文件系统实现，适用于底层协议：

```cpp
// 注册鸿蒙RawFile文件系统
fileManager.RegisterFilesystem(
    "OhosRawFile",
    IFilesystem::Ptr { new Core::OhosFilesystem(hapPath, bundleName, moduleName, resManager) }
);

// 注册标准文件系统
fileManager.RegisterFilesystem("file", factory->CreateStdFileSystem());

// 注册内存文件系统
fileManager.RegisterFilesystem("memory", factory->CreateMemFileSystem());
```

#### 方式二：RegisterPath

创建或扩展代理文件系统，适用于应用层协议：

```cpp
bool FileManager::RegisterPath(const string_view protocol, const string_view uriIn, bool prepend)
{
    // 检查是否已有该协议的代理
    auto it = proxyFilesystems_.find(protocol);
    if (it != proxyFilesystems_.end()) {
        // 已存在，添加新搜索路径
        if (prepend) {
            it->second->PrependSearchPath(uri);
        } else {
            it->second->AppendSearchPath(uri);
        }
        return true;
    }

    // 创建新的代理协议
    auto pfs = make_unique<ProxyFilesystem>(*this, uri);
    proxyFilesystems_[protocol] = pfs.get();
    RegisterFilesystem(protocol, IFilesystem::Ptr { pfs.release() });
    return true;
}
```

### 5.3 注册流程图

```
RegisterPath("shaders", "OhosRawFile://shaders", false)
        ↓
检查 proxyFilesystems_["shaders"]
        ↓
    ┌───┴───┐
    │不存在  │存在
    ↓        ↓
创建新      调用 AppendSearchPath()
ProxyFilesystem    或 PrependSearchPath()
    ↓
RegisterFilesystem("shaders", proxyFs)
```

### 5.4 实际使用示例

```cpp
// ========== 来自 scene_adapter.cpp ==========
// 注册shader相关路径
engineInstance_.engine_->GetFileManager().RegisterPath("shaders", "OhosRawFile://shaders", false);
engineInstance_.engine_->GetFileManager().RegisterPath("appshaders", "OhosRawFile://shaders", false);
engineInstance_.engine_->GetFileManager().RegisterPath("apppipelinelayouts", "OhosRawFile:///pipelinelayouts/", true);
engineInstance_.engine_->GetFileManager().RegisterPath("fonts", "OhosRawFile:///fonts", true);

// ========== 来自 engine.cpp ==========
// 注册引擎核心路径
fileManager_->RegisterPath("engine", "corerofs://core/", false);
fileManager_->RegisterPath("shaders", "engine://shaders/", false);
fileManager_->RegisterPath("shaderstates", "engine://shaderstates/", false);
fileManager_->RegisterPath("vertexinputdeclarations", "engine://vertexinputdeclarations/", false);
fileManager_->RegisterPath("pipelinelayouts", "engine://pipelinelayouts/", false);
fileManager_->RegisterPath("renderdataconfigurations", "engine://renderdataconfigurations/", false);

// ========== 来自 render_context.cpp ==========
// 注册渲染器路径
constexpr RegisterPathStrings RENDER_DATA_PATHS[] = {
    { "rendershaders", "rofsRndr://shaders/" },
    { "rendershaderstates", "rofsRndr://shaderstates/" },
    { "rendervertexinputdeclarations", "rofsRndr://vertexinputdeclarations/" },
    { "renderpipelinelayouts", "rofsRndr://pipelinelayouts/" },
    { "renderrenderdataconfigurations", "rofsRndr://renderdataconfigurations/" },
    { "renderrendernodegraphs", "rofsRndr://rendernodegraphs/" },
};
```

---

## 六、鸿蒙特定实现 (OhosFilesystem)

### 6.1 使用的鸿蒙NDK API

需要包含的头文件：
```cpp
#include "rawfile/raw_file_manager.h"
#include "rawfile/raw_file.h"
#include "rawfile/raw_dir.h"
```

### 6.2 核心API函数

| 函数 | 用途 |
|------|------|
| `OH_ResourceManager_OpenRawFile()` | 打开HAP资源中的raw文件 |
| `OH_ResourceManager_ReadRawFile()` | 读取文件内容 |
| `OH_ResourceManager_GetRawFileSize()` | 获取文件大小 |
| `OH_ResourceManager_CloseRawFile()` | 关闭文件 |
| `OH_ResourceManager_OpenRawDir()` | 打开目录 |
| `OH_ResourceManager_GetRawFileCount()` | 获取目录中文件数量 |
| `OH_ResourceManager_GetRawFileName()` | 按索引获取文件名 |
| `OH_ResourceManager_CloseRawDir()` | 关闭目录 |

### 6.3 平台初始化注册

```cpp
// platform_ohos.cpp
BASE_NS::string PlatformOHOS::RegisterDefaultPaths(IFileManager& fileManager) const
{
    const BASE_NS::string hapPath = plat_.hapPath;
    const BASE_NS::string bundleName = plat_.bundleName;
    const BASE_NS::string moduleName = plat_.moduleName;
    auto resManager = plat_.resourceManager;

    // 1. 注册鸿蒙RawFile文件系统
    fileManager.RegisterFilesystem(
        "OhosRawFile",
        IFilesystem::Ptr { new Core::OhosFilesystem(hapPath, bundleName, moduleName, resManager) }
    );
    CORE_LOG_I("Registered hapFilesystem by Platform: 'hapPath:%s bundleName:%s moduleName:%s'",
               hapPath.c_str(), bundleName.c_str(), moduleName.c_str());

    // 2. 注册缓存路径（可写）
    fileManager.RegisterPath("cache", plat_.filesDir, true);

    // 3. 注册其他应用路径
    fileManager.RegisterPath("app", plat_.filesDir, true);
    fileManager.RegisterPath("tmp", plat_.tempDir, true);

    return plat_.filesDir;
}
```

### 6.4 OhosFilesystem 限制

| 特性 | 说明 |
|------|------|
| **访问范围** | 仅限HAP包内 `resources/rawfile/` 目录 |
| **权限** | 只读 |
| **路径格式** | `OhosRawFile://相对路径`（相对于rawfile目录） |
| **目录操作** | 支持列出目录内容，但不支持创建/删除 |

---

## 七、核心接口文档

### 7.1 IFilesystem 接口

```cpp
class IFilesystem {
public:
    // 文件操作
    virtual IFile::Ptr OpenFile(BASE_NS::string_view path, IFile::Mode mode) = 0;
    virtual IFile::Ptr CreateFile(BASE_NS::string_view path) = 0;
    virtual bool DeleteFile(BASE_NS::string_view path) = 0;
    virtual bool FileExists(BASE_NS::string_view path) const = 0;

    // 目录操作
    virtual IDirectory::Entry GetEntry(BASE_NS::string_view uri) = 0;
    virtual IDirectory::Ptr OpenDirectory(BASE_NS::string_view path) = 0;
    virtual IDirectory::Ptr CreateDirectory(BASE_NS::string_view path) = 0;
    virtual bool DeleteDirectory(BASE_NS::string_view path) = 0;
    virtual bool DirectoryExists(BASE_NS::string_view path) const = 0;

    // 其他操作
    virtual bool Rename(BASE_NS::string_view fromPath, BASE_NS::string_view toPath) = 0;
    virtual BASE_NS::vector<BASE_NS::string> GetUriPaths(BASE_NS::string_view uri) const = 0;
};
```

### 7.2 IFileManager 接口

```cpp
class IFileManager {
public:
    // 注册方法
    virtual bool RegisterFilesystem(BASE_NS::string_view protocol, IFilesystem::Ptr filesystem) = 0;
    virtual bool RegisterPath(BASE_NS::string_view protocol, BASE_NS::string_view uri, bool prepend = false) = 0;
    virtual bool RegisterAssetPath(BASE_NS::string_view uri) = 0;

    // 文件操作
    virtual IFile::Ptr OpenFile(BASE_NS::string_view uri) = 0;
    virtual IFile::Ptr CreateFile(BASE_NS::string_view uri) = 0;
    virtual bool DeleteFile(BASE_NS::string_view uri) = 0;

    // 目录操作
    virtual IDirectory::Entry GetEntry(BASE_NS::string_view uri) = 0;
    virtual IDirectory::Ptr OpenDirectory(BASE_NS::string_view uri) = 0;
    virtual IDirectory::Ptr CreateDirectory(BASE_NS::string_view uri) = 0;

    // 路径解析
    virtual BASE_NS::string ResolvePath(BASE_NS::string_view uri) const = 0;
};
```

### 7.3 IFile 接口

```cpp
class IFile {
public:
    enum class Mode {
        READ_ONLY,
        READ_WRITE,
        WRITE_ONLY,
        APPEND
    };

    virtual size_t Read(void* buffer, size_t size) = 0;
    virtual size_t Write(const void* buffer, size_t size) = 0;
    virtual size_t GetLength() const = 0;
    virtual bool Seek(size_t position) = 0;
    virtual size_t GetCurrentPosition() const = 0;
    virtual void Close() = 0;
};
```

---

## 八、使用示例

### 8.1 基础文件读取

```cpp
// 读取shader文件
auto fileManager = engine->GetFileManager();
auto file = fileManager.OpenFile("shaders://vertex.spv");
if (file) {
    vector<uint8_t> data(file->GetLength());
    file->Read(data.data(), data.size());
    // 使用数据...
}
```

### 8.2 创建缓存文件

```cpp
// 创建缓存目录（如果不存在）
if (fileManager.GetEntry("cache://").type != IDirectory::Entry::Type::DIRECTORY) {
    fileManager.CreateDirectory("cache://");
}

// 写入缓存文件
auto cacheFile = fileManager.CreateFile("cache://my_cache.bin");
if (cacheFile) {
    cacheFile->Write(data.data(), data.size());
}
```

### 8.3 注册自定义协议

```cpp
// 注册应用资源路径
fileManager.RegisterPath("myassets", "OhosRawFile://custom_resources", true);
fileManager.RegisterPath("myassets", "file:///data/local/tmp/assets", false);

// 访问时按注册顺序搜索
auto file = fileManager.OpenFile("myassets://config.json");
// 先搜索 OhosRawFile://custom_resources/config.json
// 再搜索 file:///data/local/tmp/assets/config.json
```

### 8.4 GetPipelineCacheUri 使用

```cpp
// render_context.cpp 中的实现
string_view GetPipelineCacheUri(DeviceBackendType backendType)
{
    switch (backendType) {
        case DeviceBackendType::VULKAN:
            return "cache://deviceVkCache.bin";
        case DeviceBackendType::OPENGLES:
            return "cache://deviceGLESCache.bin";
        case DeviceBackendType::OPENGL:
            return "cache://deviceGLCache.bin";
        default:
            break;
    }
    return "";
}

// 读取缓存
if (auto file = fileManager_->OpenFile(GetPipelineCacheUri(device_->GetBackendType())); file) {
    vector<uint8_t> cacheData(file->GetLength());
    file->Read(cacheData.data(), cacheData.size());
    device_->InitializePipelineCache(cacheData);
}

// 写入缓存
vector<uint8_t> cacheData = device_->GetPipelineCache();
if (auto file = fileManager_->CreateFile(GetPipelineCacheUri(device_->GetBackendType())); file) {
    file->Write(cacheData.data(), cacheData.size());
}
```

---

## 九、总结

### 核心问题答案汇总

| 问题 | 答案 | 详细说明 |
|------|------|----------|
| **能访问哪些路径** | 协议URI系统 | 支持 file/memory/rofs/OhosRawFile/cache 等协议 |
| **绝对路径还是特定路径** | 两者都支持 | 相对路径基于 basePath_ 解析，绝对路径直接使用 |
| **是否需要设定根路径** | 是 | 通过平台配置或 FileManager 的 basePath_ |
| **是否需要逐个注册文件夹** | 是 | 每个协议的每个搜索路径都需要单独调用 RegisterPath() |

### 核心文件路径

| 文件 | 路径 |
|------|------|
| IFilesystem接口 | `LumeEngine/api/core/io/intf_file_system.h` |
| IFileManager接口 | `LumeEngine/api/core/io/intf_file_manager.h` |
| FileManager实现 | `LumeEngine/src/io/file_manager.cpp` |
| ProxyFilesystem实现 | `LumeEngine/src/io/proxy_filesystem.cpp` |
| OhosFilesystem实现 | `LumeEngine/src/os/ohos/ohos_filesystem.cpp` |
| 平台初始化 | `LumeEngine/src/os/ohos/platform_ohos.cpp` |

---

## 十、最佳实践建议

1. **优先使用协议路径**：避免硬编码绝对路径，使用协议URI提高代码可移植性
2. **注册顺序很重要**：使用 `prepend=true` 让高频访问路径优先搜索
3. **缓存路径需验证**：写入前检查 `cache://` 目录是否存在
4. **资源路径分离**：将只读资源（OhosRawFile）和可写数据（cache/app）分开注册
5. **统一注册位置**：在平台初始化或引擎启动时集中注册所有路径

---

*文档生成日期: 2026-03-31*