# LoadScene 后的渲染流程与 Scene 存储机制

## 目录

1. [渲染是否需要显式调用 Camera？](#1-渲染是否需要显式调用-camera)
2. [Camera 自动查询机制](#2-camera-自动查询机制)
3. [Scene 存储位置与结构](#3-scene-存储位置与结构)
4. [完整数据流转路径](#4-完整数据流转路径)
5. [关键代码位置索引](#5-关键代码位置索引)

---

## 1. 渲染是否需要显式调用 Camera？

### 结论：不需要

`LoadScene()` 之后，渲染流程会**自动查询**场景中的 Camera 信息，无需手动调用。

### 原因分析

渲染采用 **RenderNodeGraph** 管线架构，Camera 数据通过 ECS 系统自动流转到 GPU：

```
用户调用 LoadScene() → GLTF 导入到 ECS → DrawFrame() 自动执行 → RenderNodeGraph 从 ECS 读取 Camera → GPU 渲染
```

---

## 2. Camera 自动查询机制

### 2.1 核心流程

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Camera 数据自动流转路径                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  步骤1: Camera 创建                                                          │
│  ─────────────────                                                           │
│  CreateCamera() [lume_common.cpp:1222]                                      │
│      │                                                                       │
│      ├── sceneUtil.CreateCamera() → 创建 cameraEntity_                       │
│      ├── CameraComponent.sceneFlags |= MAIN_CAMERA_BIT | ACTIVE_RENDER_BIT  │
│      └── TransformComponent → 存储 position, rotation                       │
│                                                                              │
│  步骤2: 每帧更新                                                              │
│  ─────────────────                                                           │
│  Tick() [lume_common.cpp:780]                                               │
│      │                                                                       │
│      ├── orbitCamera_.Update() → 计算轨道相机位置                            │
│      ├── transformManager_->Write(cameraEntity_) → 更新 TransformComponent  │
│      └── CameraComponent 自动同步到 RenderDataStore                          │
│                                                                              │
│  步骤3: 渲染句柄收集                                                          │
│  ─────────────────                                                           │
│  CollectRenderHandles() [lume_common.cpp:1067]                              │
│      │                                                                       │
│      ├── GetGraphicsContext()->GetRenderNodeGraphs(*ecs)                    │
│      └── 自动获取包含 Camera 信息的 RenderNodeGraph                          │
│                                                                              │
│  步骤4: RenderNode 执行                                                       │
│  ─────────────────                                                           │
│  RenderNodeDefaultCameras [render_node_default_cameras.cpp]                 │
│      │                                                                       │
│      ├── 从 RenderDataStoreDefaultCamera 读取所有 Active Camera              │
│      ├── 计算 view/proj/viewProj 矩阵                                        │
│      ├── 计算视锥体裁剪平面                                                   │
│      └── 写入 CameraDataBuffer (GPU Uniform Buffer)                          │
│                                                                              │
│  步骤5: GPU 渲染                                                              │
│  ─────────────────                                                           │
│  Shader 读取 CameraDataBuffer → 使用相机矩阵渲染场景                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 关键代码：CollectRenderHandles

文件: `nativerender/3d_widget_adapter/core/src/lume/lume_common.cpp:1067-1093`

```cpp
void LumeCommon::CollectRenderHandles()
{
    renderHandles_.clear();

    // 优先使用自定义渲染
    if (customRender_) {
        auto rngs = customRender_->GetRenderHandles();
        for (auto r : rngs) {
            renderHandles_.push_back(r);
        }
    }

    // 如果没有自定义渲染，自动从 GraphicsContext 获取
    if (!renderHandles_.empty()) {
        return;
    }

    auto *ecs = ecs_.get();
    // 自动获取 RenderNodeGraph（包含 Camera、Light、Material 等信息）
    BASE_NS::array_view<const RENDER_NS::RenderHandleReference> main = 
        GetGraphicsContext()->GetRenderNodeGraphs(*ecs);
    
    if (main.size() == 0) {
        // GLTF资源还未准备好，不调度渲染
        return;
    }

    // 添加渲染句柄
    for (auto handle : main) {
        renderHandles_.push_back(handle);
    }
}
```

### 2.3 RenderNodeDefaultCameras 如何查询 Camera

文件: `nativerender/Lume_3D/src/render/node/render_node_default_cameras.cpp`

核心逻辑：

```cpp
// ExecuteFrame 中处理所有相机
void RenderNodeDefaultCameras::ExecuteFrame(IRenderCommandList& cmdList)
{
    // 1. 获取 Camera DataStore
    auto& cameraDataStore = GetRenderDataStore<RenderDataStoreDefaultCamera>(...);
    
    // 2.遍历所有 Active Camera
    for (auto& camera : cameraDataStore.GetCameras()) {
        // 3. 计算矩阵
        Math::Mat4X4 view = Math::LookAtRh(position, lookAt, up);
        Math::Mat4X4 proj = Math::Perspective(zNear, zFar, fov, aspect);
        Math::Mat4X4 viewProj = view * proj;
        
        // 4. 计算视锥体
        auto frustum = FrustumUtil::CalculatePlanes(viewProj);
        
        // 5. 写入 GPU Buffer
        cameraDataBuffer.Write(cameraData, offset);
    }
}
```

---

## 3. Scene 存储位置与结构

### 3.1 存储位置概览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Scene 存储架构                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  LumeCommon 类成员变量 [lume_common.h]                                       │
│  ─────────────────────────────────                                           │
│                                                                              │
│  ecs_ (CORE_NS::IEcs::Ptr)                                                  │
│      │                                                                       │
│      │   ┌─────────────────────────────────────────────────────────────┐    │
│      │   │                    ECS 核心存储容器                         │    │
│      │   │                                                             │    │
│      │   │  EntityManager                                             │    │
│      │   │      ├── sceneEntity_          → 场景根实体                 │    │
│      │   │      ├── cameraEntity_         → 相机实体                   │    │
│      │   │      ├── importedSceneEntity_  → GLTF导入的场景实体         │    │
│      │   │      ├── lightEntities_        → 灯光实体列表               │    │
│      │   │      └── postprocessEntity_    → 后处理实体                 │    │
│      │   │                                                             │    │
│      │   │  ComponentManager(s)                                        │    │
│      │   │      ├── sceneManager_        → RenderConfigurationComponent│    │
│      │   │      ├── cameraManager_       → CameraComponent             │    │
│      │   │      ├── transformManager_    → TransformComponent          │    │
│      │   │      ├── materialManager_     → MaterialComponent           │    │
│      │   │      ├── meshManager_         → MeshComponent               │    │
│      │   │      ├── lightManager_        → LightComponent              │    │
│      │   │      ├── renderMeshManager_   → RenderMeshComponent         │    │
│      │   │      └── nodeSystem_          → NodeComponent (层级结构)    │    │
│      │   │                                                             │    │
│      │   │  System(s)                                                  │    │
│      │   │      ├── RenderSystem        → 渲染系统                     │    │
│      │   │      ├── NodeSystem          → 节点层级系统                 │    │
│      │   │      ├── AnimationSystem     → 动画系统                     │    │
│      │   │      └── RenderPreprocessorSystem → 渲染预处理              │    │
│      │   │                                                             │    │
│      │   └─────────────────────────────────────────────────────────────┘    │
│      │                                                                       │
│  importedSceneResources_ (BASE_NS::vector<GLTFResourceData>)               │
│      │                                                                       │
│      │   ┌─────────────────────────────────────────────────────────────┐    │
│      │   │                    GLTF 资源数据                             │    │
│      │   │                                                             │    │
│      │   │  ├── meshes        → Mesh资源引用                           │    │
│      │   │  ├── materials     → Material资源引用                       │    │
│      │   │  ├── animations    → Animation资源引用                      │    │
│      │   │  ├── images        → Image/Texture资源引用                  │    │
│      │   │  └── buffers       → GPU Buffer资源引用                     │    │
│      │   │                                                             │    │
│      │   └─────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 实体层级结构

```
sceneEntity_ (场景根节点)
    │
    ├── RenderConfigurationComponent
    │       ├── environment → sceneEntity_ (环境组件)
    │       ├── renderingFlags → CREATE_RNGS_BIT
    │       └── scene → sceneEntity_
    │
    ├── EnvironmentComponent (可选)
    │       ├── background → CUBEMAP/NONE
    │       ├── irradianceCoefficients → 球谐系数
    │       └── specularFactor → 高光因子
    │
    ├── NodeComponent (通过 nodeSystem_ 管理)
    │       └── parent: nullptr (根节点)
    │
    └── [子节点: GLTF 导入的场景]
            │
            importedSceneEntity_
                │
                ├── MeshComponent(s)
                │       ├── mesh → GPU Mesh Handle
                │       └── material → Material Entity
                │
                ├── MaterialComponent(s)
                │       ├── textures[] → Texture Handles
                │       ├── shader → Shader Handle
                │       └── factors →材质参数
                │
                ├── RenderMeshComponent(s)
                │       ├── mesh → Mesh Entity
                │       ├── material → Material Entity
                │       └── batch → RenderMeshBatch
                │
                ├── TransformComponent(s)
                │       ├── position → Vec3
                │       ├── rotation → Quat
                │       └── scale → Vec3
                │
                ├── NodeComponent(s)
                │       └── parent → sceneEntity_ 或其他节点
                │
                └── [动画节点]
                        │
                        AnimationTrackComponent(s)
                        AnimationComponent(s)
```

### 3.3 LoadSceneModel 存储过程

文件: `nativerender/3d_widget_adapter/core/src/lume/lume_common.cpp:1272-1287`

```cpp
void LumeCommon::LoadSceneModel(const std::string &modelPath)
{
    // 1. 清理旧场景
    UnloadSceneModel();
    //    ├── DestroySceneNodeAndRes(importedSceneEntity_, importedSceneResources_)
    //    ├── animationSystem->DestroyPlayback() → 清理动画
    //    └── importedSceneResources_.clear()

    // 2. 创建场景根实体
    CreateScene();
    //    ├── nodeSystem->CreateNode() → 创建根节点
    //    ├── sceneEntity_ = rootNode->GetEntity()
    //    └── sceneManager_->Create(sceneEntity_) → 创建 RenderConfigurationComponent

    // 3. 加载 GLTF
    GltfImportInfo file{modelPath, AnimateImportedScene, ...};
    loadedScene_ = LoadAndImport(file, importedSceneEntity_, importedSceneResources_);
    //    ├── graphicsContext_->GetGltf().LoadGLTF() → 加载文件
    //    ├── CreateGLTF2Importer() → 创建导入器
    //    ├── ImportGLTF() → 导入资源
    //    ├── ImportGltfScene() → 导入场景节点到 importedSceneEntity_
    //    ├── CreatePlayback() → 创建动画播放器到 animations_
    //    └── res.push_back(gltfImportResult.data) → 存储资源到 importedSceneResources_
}
```

### 3.4 LoadAndImport 详细流程

文件: `nativerender/3d_widget_adapter/core/src/lume/lume_common.cpp:668-741`

```cpp
bool LumeCommon::LoadAndImport(const GltfImportInfo& info, ...)
{
    auto& ecs = *ecs_;
    
    // Step1: 加载 GLTF 文件
    auto gltf = graphicsContext_->GetGltf().LoadGLTF(info.fileName_);
    // 返回: gltf.data →包含 meshes, materials, animations, images 等

    // Step 2: 创建导入器
    auto importer = graphicsContext_->GetGltf().CreateGLTF2Importer(ecs);
    
    // Step 3: 导入所有资源
    importer->ImportGLTF(*gltf.data, info.resourceImportFlags_);
    // 创建: MeshComponent, MaterialComponent, ImageComponent 等
    
    // Step 4: 获取导入结果
    auto gltfImportResult = importer->GetResult();
    res.push_back(gltfImportResult.data);
    // 存储到 importedSceneResources_

    // Step 5: 导入场景节点
    size_t sceneIndex = gltf.data->GetDefaultSceneIndex();
    importedSceneEntity = graphicsContext_->GetGltf().ImportGltfScene(
        sceneIndex, *gltf.data, gltfImportResult.data, ecs, sceneEntity_, info.sceneImportFlags_);
    // 创建: NodeComponent, TransformComponent, RenderMeshComponent 等
    // 父节点设置为 sceneEntity_

    // Step 6: 创建动画播放器
    if (!gltfImportResult.data.animations.empty()) {
        for (const auto& animation : gltfImportResult.data.animations) {
            auto playback = animationSystem->CreatePlayback(animation, *animationRootNode);
            playback->SetPlaybackState(STOP);
            playback->SetRepeatCount(-1);  // 无限循环
            animations_.push_back(playback);
        }
    }
    
    return true;
}
```

---

## 4. 完整数据流转路径

### 4.1 从 LoadScene 到 GPU 渲染的完整链路

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         完整渲染数据流转                                      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  [用户调用]                                                                  │
│      │                                                                       │
│      ▼                                                                       │
│  LoadSceneModel("card.gltf")                                                 │
│      │                                                                       │
│      ├── UnloadSceneModel() → 清理旧场景                                    │
│      ├── CreateScene() → 创建 sceneEntity_                                  │
│      └ LoadAndImport() → GLTF 加载                                          │
│      │       │                                                               │
│      │       ├── LoadGLTF() → 解析 GLTF 文件                                │
│      │       ├── ImportGLTF() → 创建资源组件                                │
│      │       │       ├── MeshComponent → meshManager_                       │
│      │       │       ├── MaterialComponent → materialManager_               │
│      │       │       └── ImageComponent → GPU Texture                       │
│      │       │                                                               │
│      │       ├── ImportGltfScene() → 创建场景节点                           │
│      │       │       ├── NodeComponent → nodeSystem_ (层级)                 │
│      │       │       ├── TransformComponent → transformManager_             │
│      │       │       └ RenderMeshComponent → renderMeshManager_             │
│      │       │       └── parent → sceneEntity_                              │
│      │       │                                                               │
│      │       └── CreatePlayback() → 创建动画                                │
│      │               └ animations_.push_back()                              │
│      │                                                                       │
│      └── importedSceneEntity_ = 导入的场景实体                              │
│          importedSceneResources_ = GLTF 资源数据                            │
│      │                                                                       │
│      ▼                                                                       │
│  [等待帧渲染回调]                                                            │
│      │                                                                       │
│      ▼                                                                       │
│  OnFrameCallbackNative() → 每帧自动触发                                      │
│      │                                                                       │
│      ▼                                                                       │
│  DrawFrame() [lume_common.cpp:743]                                          │
│      │                                                                       │
│      ├── engine_->TickFrame() → ECS 更新                                    │
│      │       ├── ProcessEvents() → 处理事件                                 │
│      │       └ UpdateSystems() → 更新所有系统                               │
│      │       │       ├── NodeSystem → 更新节点层级                          │
│      │       │       ├── RenderSystem → 更新渲染状态                        │
│      │       │       ├── AnimationSystem → 更新动画                         │
│      │       │       └── TransformSystem → 更新变换矩阵                     │
│      │       │                                                               │
│      │       └── 返回 needsRender = true/false                              │
│      │                                                                       │
│      ├── CollectRenderHandles() → 收集渲染句柄                              │
│      │       ├── customRender_->GetRenderHandles() (可选)                   │
│      │       └ GetGraphicsContext()->GetRenderNodeGraphs(*ecs)              │
│      │       │       └── 自动查询 ECS 中的所有渲染数据                       │
│      │       │                                                               │
│      │       └── renderHandles_ → RenderNodeGraph 句柄列表                  │
│      │                                                                       │
│      ├── Tick(deltaTime) → 更新相机                                         │
│      │       ├── orbitCamera_.Update() → 轨道相机计算                       │
│      │       └ transformManager_->Write(cameraEntity_)                      │
│      │       └── CameraComponent 自动同步                                   │
│      │                                                                       │
│      ├── customRender_->OnDrawFrame() (可选)                                │
│      │                                                                       │
│      ▼                                                                       │
│  GetRenderContext()->GetRenderer().RenderFrame(renderHandles_)              │
│      │                                                                       │
│      ▼                                                                       │
│  [RenderNodeGraph 执行]                                                      │
│      │                                                                       │
│      ├── PreExecuteFrame() → 预处理                                         │
│      │       └── 创建 GPU 资源、更新缓冲区                                  │
│      │                                                                       │
│      ├── ExecuteFrame() → 执行渲染节点                                      │
│      │       │                                                               │
│      │       ├── RenderNodeDefaultCameras                                   │
│      │       │       ├── 从 RenderDataStoreDefaultCamera 读取               │
│      │       │       ├── 遍历所有 CameraComponent (active)                  │
│      │       │       ├── 计算 view/proj/viewProj 矩阵                       │
│      │       │       ├── 计算视锥体裁剪                                      │
│      │       │       └── 写入 CameraDataBuffer (GPU)                        │
│      │       │                                                               │
│      │       ├── RenderNodeDefaultLights                                    │
│      │       │       ├── 从 RenderDataStoreDefaultLight 读取                │
│      │       │       ├── 遍历所有 LightComponent                            │
│      │       │       ├── 计算灯光位置、方向、强度                           │
│      │       │       └── 写入 LightDataBuffer (GPU)                        │
│      │       │                                                               │
│      │       ├── RenderNodeDefaultMaterialObjects                           │
│      │       │       ├── 从 RenderDataStoreDefaultMaterial 读取              │
│      │       │       ├── 遍历所有 RenderMeshComponent                       │
│      │       │       ├── 收集 Mesh + Material + Transform                   │
│      │       │       ├── 执行 DrawCalls                                     │
│      │       │       └── 渲染到 ColorTarget                                  │
│      │       │                                                               │
│      │       ├── RenderNodeDefaultEnv                                       │
│      │       │       ├── 从 EnvironmentComponent 读取                       │
│      │       │       ├── 渲染天空盒                                          │
│      │       │       └── 计算间接光照                                        │
│      │       │                                                               │
│      │       └── RenderNodeCameraPostProcessController                      │
│      │               ├── Bloom效果                                           │
│      │               ├── ToneMapping                                         │
│      │               ├── ColorFringe                                         │
│      │               └── 输出到 Swapchain                                    │
│      │                                                                       │
│      ├── PostExecuteFrame() → 后处理                                        │
│      │                                                                       │
│      └── SubmitCommands() → GPU 命令提交                                    │
│      │                                                                       │
│      ▼                                                                       │
│  [GPU 执行]                                                                  │
│      │                                                                       │
│      ├── Vertex Shader → 读取 CameraDataBuffer (viewProj)                  │
│      ├── Fragment Shader →读取 MaterialDataBuffer (textures)               │
│      ├── 光照计算 → 读取 LightDataBuffer                                    │
│      │                                                                       │
│      ▼                                                                       │
│  [图像输出]                                                                  │
│      │                                                                       │
│      ├── Swapchain Present                                                   │
│      └── eglSwapBuffers() → 输出到屏幕                                      │
│      │                                                                       │
│      ▼                                                                       │
│  [完成]                                                                      │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 数据流向图

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   GLTF File     │────▶│   ECS Storage   │────▶│  RenderDataStore│
│                 │     │                 │     │                 │
│ - meshes        │     │ - MeshComponent │     │ - MaterialData  │
│ - materials     │     │ - MaterialComp  │     │ - CameraData    │
│ - animations    │     │ - TransformComp │     │ - LightData     │
│ - cameras       │     │ - CameraComponent│    │ - ObjectData    │
│ - lights        │     │ - LightComponent│     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                      │
                                                      ▼
                                               ┌─────────────────┐
                                               │ RenderNodeGraph │
                                               │                 │
                                               │ - Cameras Node  │
                                               │ - Lights Node   │
                                               │ - Materials Node│
                                               │ - Env Node      │
                                               │ - PostProcess   │
                                               └─────────────────┘
                                                      │
                                                      ▼
                                               ┌─────────────────┐
                                               │   GPU Buffers   │
                                               │                 │
                                               │ - CameraBuffer  │
                                               │ - LightBuffer   │
                                               │ - MaterialBuffer│
                                               │ - ObjectBuffer  │
                                               └─────────────────┘
                                                      │
                                                      ▼
                                               ┌─────────────────┐
                                               │     Shader      │
                                               │                 │
                                               │ - Vertex Shader │
                                               │ - FragmentShader│
                                               └─────────────────┘
                                                      │
                                                      ▼
                                               ┌─────────────────┐
                                               │    Screen       │
                                               └─────────────────┘
```

---

## 5. 关键代码位置索引

### 5.1 Scene 相关

| 功能 | 文件 | 行号 |
|------|------|------|
| LoadSceneModel 入口 | `lume_common.cpp` | 1272-1287 |
| CreateScene | `lume_common.cpp` | 1153-1170 |
| LoadAndImport | `lume_common.cpp` | 668-741 |
| UnloadSceneModel | `lume_common.cpp` | 618-632 |
| DestroySceneNodeAndRes | `lume_common.cpp` | 599-616 |

### 5.2 Camera 相关

| 功能 | 文件 | 行号 |
|------|------|------|
| CreateCamera | `lume_common.cpp` | 1222-1239 |
| SetupCameraTransform | `lume_common.cpp` | 1775-1831 |
| SetupCameraViewPort | `lume_common.cpp` | 1840-1856 |
| SetupCameraViewProjection | `lume_common.cpp` | 1775-1779 |
| Tick (相机更新) | `lume_common.cpp` | 780-799 |

### 5.3 渲染相关

| 功能 | 文件 | 行号 |
|------|------|------|
| DrawFrame | `lume_common.cpp` | 743-778 |
| CollectRenderHandles | `lume_common.cpp` | 1067-1093 |
| RenderNodeDefaultCameras | `render_node_default_cameras.cpp` | 全文件 |

### 5.4 存储结构定义

| 功能 | 文件 | 行号 |
|------|------|------|
| LumeCommon 成员变量 | `lume_common.h` | 210-279 |
| ECS 创建 | `lume_common.cpp` | 1095-1103 |
| SystemGraph 加载 | `lume_common.cpp` | 1105-1151 |

---

## 6. 总结问答

### Q1: LoadScene 后需要手动调用 Camera 吗？

**答：不需要。** 渲染流程会自动通过 RenderNodeGraph 从 ECS 中查询所有带有 `ACTIVE_RENDER_BIT` 标志的 Camera。

### Q2: Camera 信息在哪里被查询？

**答：** 在 `RenderNodeDefaultCameras.ExecuteFrame()` 中，从 `RenderDataStoreDefaultCamera` 读取，该 DataStore 由 ECS 的 CameraComponent 自动同步。

### Q3: Scene 存储在哪里？

**答：** 存储在 ECS 系统中：
- `sceneEntity_` → 场景根实体
- `importedSceneEntity_` → GLTF 导入的场景实体
- `importedSceneResources_` → GLTF 资源数据

### Q4: 如何修改 Camera 位置？

**答：** 调用 `SetupCameraTransform()` 或通过触摸事件 `OnTouchEvent()` 修改，数据会写入 `TransformComponent`，自动流转到渲染管线。

---

**文档版本**: 1.0  
**创建日期**: 2026-04-01  
**相关文档**: [Scene_Control_Interface_and_Render_Pipeline.md](Scene_Control_Interface_and_Render_Pipeline.md)