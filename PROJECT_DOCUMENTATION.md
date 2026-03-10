# DayNote 项目文档

## 项目介绍

**DayNote** 是一款基于 HarmonyOS 平台开发的笔记应用，采用 **ArkTS + C++** 混合技术方案。应用提供了现代化的笔记编辑体验，集成了 3D 场景展示和物理引擎效果，支持深色/浅色主题切换，并能自适应不同设备屏幕。

### 核心特性

- **笔记编辑**: 支持富文本编辑（加粗、斜体、下划线、文字颜色）
- **图片插入**: 支持从相册选择图片并插入到笔记中
- **3D 场景**: 集成 ArkGraphics3D，支持 3D 场景渲染和交互
- **物理引擎**: 自研 C++ 物理系统，支持刚体动力学和碰撞检测
- **主题系统**: 完整的主题管理系统，支持深色/浅色模式切换
- **自适应布局**: 支持多种设备类型（手机、平板等）

### 技术栈

| 类别 | 技术 |
|------|------|
| 前端框架 | ArkTS (ArkUI 声明式 UI) |
| 原生开发 | C++ (NAPI 绑定) |
| 3D 引擎 | ArkGraphics3D |
| 物理引擎 | 自研 C++ 物理系统 |
| 渲染 API | EGL + OpenGL ES |
| 构建系统 | CMake + Hvigor |
| SDK 版本 | HarmonyOS 6.0.0 (API 20/21) |

---

## 项目结构

```
DayNote/
├── AppScope/                          # 应用全局配置
│   ├── app.json5                      # 应用包名、版本等元信息
│   └── resources/                     # 应用级资源
│
├── entry/                             # 主模块 (Entry Module)
│   ├── src/main/
│   │   ├── cpp/                       # C++ 原生代码
│   │   │   ├── physics/               # 物理引擎库
│   │   │   │   ├── math/              # 数学库 (向量、矩阵、四元数)
│   │   │   │   ├── physics/           # 物理系统核心
│   │   │   │   ├── event_queue/       # 事件队列系统
│   │   │   │   ├── dynamics/          # 动力学计算
│   │   │   │   └── napi_init.cpp      # NAPI 入口
│   │   │   └── nativerender/          # 原生渲染库
│   │   │       ├── render/            # EGL 渲染核心
│   │   │       ├── manager/           # 插件管理器
│   │   │       └── napi_init.cpp      # NAPI 入口
│   │   │
│   │   ├── ets/                       # ArkTS 前端代码
│   │   │   ├── pages/                 # 页面
│   │   │   │   ├── Index.ets          # 主入口页面
│   │   │   │   ├── NotePage.ets       # 笔记编辑页面
│   │   │   │   ├── NativePage.ets     # 原生功能演示页
│   │   │   │   ├── DiaryHomePage.ets  # 日记主页
│   │   │   │   ├── TestPage.ets       # 测试页面
│   │   │   │   └── PlayGround.ets     # 3D 物理游乐场
│   │   │   │
│   │   │   ├── entryability/          # 应用入口
│   │   │   │   ├── EntryAbility.ets   # 主 Ability
│   │   │   │   └── EntryBackupAbility.ets  # 备份 Ability
│   │   │   │
│   │   │   ├── feature/               # 功能模块
│   │   │   │   ├── Banner/            # 横幅通知
│   │   │   │   ├── Calendar/          # 日历功能
│   │   │   │   ├── Note/              # 笔记核心功能
│   │   │   │   │   ├── NoteViewModel.ets    # 笔记视图模型
│   │   │   │   │   ├── NoteState.ets        # 笔记状态
│   │   │   │   │   ├── NoteService.ets      # 笔记服务
│   │   │   │   │   ├── EditorController.ets # 编辑器控制器
│   │   │   │   │   ├── model/               # 数据模型
│   │   │   │   │   ├── utils/               # 工具函数
│   │   │   │   │   └── component/           # 组件
│   │   │   │   ├── SideBar/           # 侧边栏
│   │   │   │   ├── mainDisplay/       # 主显示区
│   │   │   │   ├── SlideList/         # 滑动列表
│   │   │   │   └── TestComponent/     # 测试组件
│   │   │   │
│   │   │   ├── core/                  # 核心模块
│   │   │   │   ├── math/              # 数学工具
│   │   │   │   │   ├── vec.ets        # 向量类型
│   │   │   │   │   └── mathUtil.ets   # 数学工具函数
│   │   │   │   └── scene3D/           # 3D 场景
│   │   │   │       ├── GlobalSceneProxy.ets  # 场景代理单例
│   │   │   │       ├── EventQueue.ets        # 事件队列
│   │   │   │       ├── PhysicsSystemManager.ets  # 物理系统管理
│   │   │   │       ├── PhysicsAdapter.ets    # 物理适配器
│   │   │   │       ├── TouchRotate.ets       # 触摸旋转
│   │   │   │       └── Utils.ets             # 3D 工具
│   │   │   │
│   │   │   ├── theme/                 # 主题系统
│   │   │   │   ├── config/            # 配置
│   │   │   │   │   ├── ThemeConfig.ets       # 主题配置
│   │   │   │   │   ├── DeviceConfig.ets      # 设备配置
│   │   │   │   │   └── BreakpointsConfig.ets # 断点配置
│   │   │   │   ├── core/              # 核心
│   │   │   │   │   ├── ThemeManager.ets      # 主题管理器
│   │   │   │   │   └── DeviceAdapter.ets     # 设备适配器
│   │   │   │   ├── hooks/             # 钩子函数
│   │   │   │   │   ├── useTheme.ets          # 主题 Hook
│   │   │   │   │   └── useDevice.ets         # 设备 Hook
│   │   │   │   └── tokens/            # 设计令牌
│   │   │   │       ├── ColorTokens.ets       # 颜色令牌
│   │   │   │       ├── SizeTokens.ets        # 尺寸令牌
│   │   │   │       └── SpacingTokens.ets     # 间距令牌
│   │   │   │
│   │   │   └── shared/                # 共享工具
│   │   │       ├── utils/             # 工具函数
│   │   │       │   ├── ColorUtil.ets         # 颜色工具
│   │   │       │   ├── ImageUtils.ets        # 图像工具
│   │   │       │   ├── TouchManager.ets      # 触摸管理
│   │   │       │   ├── PosLimiter.ets        # 位置限制器
│   │   │       │   ├── Rubber.ets            # 弹性效果
│   │   │       │   ├── file.ets              # 文件操作
│   │   │       │   └── Time/                 # 时间工具
│   │   │       └── ui/                # UI 工具
│   │   │           └── uiUtils.ets           # UI 工具函数
│   │   │
│   │   ├── resources/                 # 资源文件
│   │   │   ├── base/                  # 基础资源
│   │   │   │   ├── element/           # 元素资源
│   │   │   │   ├── media/             # 媒体资源
│   │   │   │   └── profile/           # 配置文件
│   │   │   ├── dark/                  # 深色模式资源
│   │   │   └── rawfile/               # 原始文件 (3D 场景资源)
│   │   │       ├── NewProject/        # 3D 场景项目 1
│   │   │       └── NewProject2/       # 3D 场景项目 2
│   │   │
│   │   ├── module.json5               # 模块配置
│   │   └── README.md                  # 模块说明
│   │
│   ├── build-profile.json5            # 构建配置
│   ├── oh-package.json5               # 依赖配置
│   └── hvigorfile.ts                  # 构建脚本
│
├── build-profile.json5                # 项目级构建配置
├── oh-package.json5                   # 项目级依赖配置
└── hvigorfile.ts                      # 项目构建脚本
```

---

## 核心模块说明

### 1. 笔记模块 (`feature/note/`)

**核心文件**:
- `NoteViewModel.ets` - 笔记视图模型，管理笔记状态和编辑操作
- `NoteState.ets` - 笔记状态管理
- `NoteService.ets` - 笔记文件读写服务
- `EditorController.ets` - 富文本编辑器控制器

**功能**:
- 笔记的创建、读取、更新、删除
- 富文本格式（加粗、斜体、下划线、颜色）
- 图片插入和管理
- 笔记数据持久化

### 2. 3D 场景模块 (`core/scene3D/`)

**核心文件**:
- `GlobalSceneProxy.ets` - 3D 场景单例代理
- `EventQueue.ets` - 事件队列管理
- `PhysicsSystemManager.ets` - 物理系统管理器

**功能**:
- 3D 场景加载和渲染
- 物理引擎集成
- 事件处理和节点管理

### 3. 主题系统 (`theme/`)

**核心文件**:
- `ThemeManager.ets` - 主题管理器（单例）
- `DeviceAdapter.ets` - 设备适配器（单例）
- `ColorTokens.ets` - 颜色令牌

**功能**:
- 深色/浅色主题切换
- 设备类型检测
- 响应式断点管理

### 4. C++ 物理引擎 (`cpp/physics/`)

**核心文件**:
- `napi_init.cpp` - NAPI 入口
- `physics/physicalSystem.cpp` - 物理系统核心
- `math/` - 数学库（向量、矩阵、四元数）

**功能**:
- 刚体动力学模拟
- 碰撞检测
- 事件队列系统

---

## 代码规范

### 命名约定

1. **文件和目录**: 使用驼峰命名法（PascalCase）
   - ✅ `NoteViewModel.ets`, `ThemeManager.ets`
   - ❌ `noteViewModel.ets`, `themeManager.ets`

2. **类和结构体**: 使用帕斯卡命名法（PascalCase）
   - ✅ `class PhysicsSystem`, `struct MainPage`
   - ❌ `class physicsSystem`, `struct mainPage`

3. **变量和函数**: 使用驼峰命名法（camelCase）
   - ✅ `noteViewModel`, `getController()`
   - ❌ `NoteViewModel`, `GetController()`

4. **常量和枚举**: 使用大写字母和下划线
   - ✅ `DEFAULT_THEME`, `MAX_COUNT`
   - ❌ `defaultTheme`, `maxCount`

### 代码组织结构

```typescript
// 1. 导入语句（按类别分组）
import { ... } from "...";

// 2. 枚举和类型定义
enum MyEnum { ... }

// 3. 组件定义
@Entry
@ComponentV2
export struct MyComponent {
  // 3.1 装饰器属性（按功能分组）
  @Local deviceManager: DeviceAdapter = ...;
  @Local themeState: ThemeState = ...;

  // 3.2 普通属性
  screenWidth: number = 100;

  // 3.3 生命周期方法
  aboutToAppear(): void { ... }
  aboutToDisappear(): void { ... }

  // 3.4 业务方法
  private handleAction(): void { ... }

  // 3.5 build 方法
  build() { ... }
}
```

### 已修复的问题

1. **拼写错误**:
   - `NoteVeiwModel.ets` → `NoteViewModel.ets`
   - `quteration.h` → `quaternion.h`

2. **清理的冗余代码**:
   - 删除空目录 `feature/mainDisplay/Component/`
   - 删除非源码文件 `工具栏显示.jpg`
   - 删除未引用的 `Rubber.ets` 文件

---

## 编译和运行

### 环境要求

- DevEco Studio 6.0+
- HarmonyOS SDK 6.0.0 (API 20/21)
- Node.js 18+
- CMake 3.18+

### 编译步骤

1. 打开 DevEco Studio
2. 导入项目（Open Project）
3. 同步依赖（Sync Project）
4. 构建项目（Build > Make Project）

### 运行步骤

1. 连接 HarmonyOS 设备或启动模拟器
2. 点击运行按钮（Run）
3. 选择目标设备

---

## 项目维护者

- 开发者：InkStar Chen
- 仓库：https://github.com/inkstarchen/srtp-harmony-application

---

## 许可证

本项目采用 MIT 许可证。
