# Component Manager 详解

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 7 日

---

## 1. 什么是 Component Manager？

在 ECS（Entity-Component-System）架构中，**Component Manager** 负责管理特定类型 Component 的**存储和访问**。

---

## 2. ECS 架构回顾

```
┌─────────────────────────────────────────────────────────────┐
│  ECS 架构                                                    │
│                                                              │
│  Entity (实体) - 唯一 ID，表示场景中的对象                    │
│      │                                                       │
│      ├─ 附加多个 Components                                  │
│      │   ├─ TransformComponent (位置、旋转、缩放)            │
│      │   ├─ CameraComponent (相机参数)                       │
│      │   ├─ LightComponent (灯光参数)                        │
│      │   └─ MeshComponent (网格数据)                         │
│      │                                                       │
│      └─ 被 Systems 查询和处理                                 │
│          ├─ RenderSystem (渲染)                              │
│          ├─ AnimationSystem (动画)                           │
│          └─ NodeSystem (节点变换)                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Component Manager 的作用

### **3.1 数据存储**

每个 Component Manager 管理**一种类型**的所有 Component 实例：

```cpp
// ITransformComponentManager 管理所有 TransformComponent
class ITransformComponentManager : public IComponentManager {
    // 内部存储
    std::vector<TransformComponent> components_;  // 所有 Transform 数据
    std::unordered_map<Entity, size_t> entityToIndex_;  // Entity → Component 索引
    
public:
    // 创建 Component
    void Create(Entity entity) {
        components_.emplace_back();
        entityToIndex_[entity] = components_.size() - 1;
    }
    
    // 读取 Component（只读）
    ScopedHandle<const TransformComponent> Read(Entity entity) const {
        auto it = entityToIndex_.find(entity);
        if (it != entityToIndex_.end()) {
            return ScopedHandle<const TransformComponent>(&components_[it->second]);
        }
        return {};
    }
    
    // 写入 Component（可修改）
    ScopedHandle<TransformComponent> Write(Entity entity) {
        auto it = entityToIndex_.find(entity);
        if (it != entityToIndex_.end()) {
            return ScopedHandle<TransformComponent>(&components_[it->second]);
        }
        return {};
    }
    
    // 销毁 Component
    void Destroy(Entity entity) {
        auto it = entityToIndex_.find(entity);
        if (it != entityToIndex_.end()) {
            components_.erase(components_.begin() + it->second);
            entityToIndex_.erase(it);
        }
    }
};
```

### **3.2 组件数据示例**

```cpp
// TransformComponent 定义
BEGIN_COMPONENT(ITransformComponentManager, TransformComponent)
    DEFINE_PROPERTY(BASE_NS::Math::Vec3, position, "Position", 0, ARRAY_VALUE(0.f, 0.f, 0.f))
    DEFINE_PROPERTY(BASE_NS::Math::Quat, rotation, "Rotation", 0, ARRAY_VALUE(0.f, 0.f, 0.f, 1.f))
    DEFINE_PROPERTY(BASE_NS::Math::Vec3, scale, "Scale", 0, ARRAY_VALUE(1.f, 1.f, 1.f))
END_COMPONENT(...)

// 内存布局（连续存储）
ITransformComponentManager {
    components_: [
        TransformComponent { position: (0,0,0),  rotation: (0,0,0,1), scale: (1,1,1) },  // Entity 1
        TransformComponent { position: (1,2,3),  rotation: (0,0.7,0,0.7), scale: (2,2,2) }, // Entity 2
        TransformComponent { position: (-5,0,10), rotation: (0,0,0,1), scale: (1,1,1) },  // Entity 3
        ...
    ]
}
```

---

## 4. LumeCommon 中的 Component Managers

### **4.1 持有的 Managers**

```cpp
class LumeCommon {
    // 这些指针在 LoadSystemGraph 时从 ecs_ 获取
    CORE3D_NS::ITransformComponentManager* transformManager_;      // 管理所有 Transform
    CORE3D_NS::ICameraComponentManager* cameraManager_;            // 管理所有 Camera
    CORE3D_NS::IRenderConfigurationComponentManager* sceneManager_; // 管理所有 Scene 配置
    CORE3D_NS::ILightComponentManager* lightManager_;              // 管理所有 Light
    CORE3D_NS::IPostProcessComponentManager* postprocessManager_;  // 管理所有 PostProcess
    
    CORE3D_NS::IMaterialComponentManager* materialManager_;        // 管理所有 Material
    CORE3D_NS::IMeshComponentManager* meshManager_;                // 管理所有 Mesh
    CORE3D_NS::INameComponentManager* nameManager_;                // 管理所有 Name
    CORE3D_NS::IUriComponentManager* uriManager_;                  // 管理所有 URI
    CORE3D_NS::IRenderHandleComponentManager* gpuHandleManager_;   // 管理所有 GPU Handle
    CORE3D_NS::INodeSystem* nodeSystem_;                           // 处理节点层级
    CORE3D_NS::IRenderMeshComponentManager* renderMeshManager_;    // 管理所有 RenderMesh
};
```

### **4.2 获取方式**

```cpp
void LumeCommon::LoadSystemGraph(BASE_NS::string sysGraph)
{
    auto& ecs = *ecs_;  // ← 从当前的 ecs_ 获取
    
    // 通过 ECS 获取 Component Manager
    // 每个 ECS 有自己独立的 Component Manager 实例
    transformManager_ = CORE_NS::GetManager<CORE3D_NS::ITransformComponentManager>(ecs);
    cameraManager_ = CORE_NS::GetManager<CORE3D_NS::ICameraComponentManager>(ecs);
    sceneManager_ = CORE_NS::GetManager<CORE3D_NS::IRenderConfigurationComponentManager>(ecs);
    lightManager_ = CORE_NS::GetManager<CORE3D_NS::ILightComponentManager>(ecs);
    postprocessManager_ = CORE_NS::GetManager<CORE3D_NS::IPostProcessComponentManager>(ecs);
    // ...
}
```

---

## 5. Component Manager 的使用方式

### **5.1 读取 Component（只读）**

```cpp
// 读取相机的参数
auto cameraHandle = cameraManager_->Read(cameraEntity_);
if (cameraHandle) {
    float fov = cameraHandle->fov;
    float near = cameraHandle->nearPlane;
    float far = cameraHandle->farPlane;
    // 只能读取，不能修改
}
```

### **5.2 写入 Component（可修改）**

```cpp
// 修改相机的参数
auto cameraHandle = cameraManager_->Write(cameraEntity_);
if (cameraHandle) {
    cameraHandle->fov = 60.0f;        // ← 修改
    cameraHandle->nearPlane = 0.1f;   // ← 修改
    cameraHandle->farPlane = 1000.0f; // ← 修改
}
```

### **5.3 创建 Component**

```cpp
// 为 Entity 创建 TransformComponent
transformManager_->Create(entity);

// 创建后设置初始值
auto handle = transformManager_->Write(entity);
if (handle) {
    handle->position = BASE_NS::Math::Vec3(0, 0, 0);
    handle->rotation = BASE_NS::Math::Quat(0, 0, 0, 1);
    handle->scale = BASE_NS::Math::Vec3(1, 1, 1);
}
```

### **5.4 销毁 Component**

```cpp
// 销毁 Entity 的 Component
transformManager_->Destroy(entity);
```

---

## 6. 实际使用示例

### **6.1 SetupCameraTransform**

```cpp
// lume_common.cpp
void LumeCommon::SetupCameraTransform(
    const Position& position, const Vec3& lookAt, const Vec3& up, const Quaternion& rotation)
{
    // 检查 Manager 是否有效
    if (transformManager_ && sceneManager_ && CORE_NS::EntityUtil::IsValid(cameraEntity_)) {
        // 写入相机的 TransformComponent
        auto cameraTransform = transformManager_->Write(cameraEntity_);
        if (cameraTransform) {
            // 修改位置
            cameraTransform->position = BASE_NS::Math::Vec3(
                position.x_, position.y_, position.z_);
            
            // 修改旋转
            cameraTransform->rotation = BASE_NS::Math::Quat(
                rotation.x_, rotation.y_, rotation.z_, rotation.w_);
        }
        
        // 写入相机的 CameraComponent
        if (auto cameraHandle = cameraManager_->Read(cameraEntity_); cameraHandle) {
            // 计算 lookAt 矩阵
            BASE_NS::Math::Mat4X4 lookAtMat = BASE_NS::Math::MakeLookAtMatrix(
                BASE_NS::Math::Vec3(position.x_, position.y_, position.z_),
                BASE_NS::Math::Vec3(lookAt.x_, lookAt.y_, lookAt.z_),
                BASE_NS::Math::Vec3(up.x_, up.y_, up.z_));
            
            // 更新相机参数
            // ...
        }
    }
}
```

**使用的 Managers**：
- `transformManager_` → 修改 `TransformComponent`
- `cameraManager_` → 读取/修改 `CameraComponent`

---

### **6.2 UpdateLights**

```cpp
// lume_common.cpp
void LumeCommon::UpdateLights(const std::vector<std::shared_ptr<Light>>& lights)
{
    // 遍历所有灯光
    for (size_t i = 0; i < lights.size(); i++) {
        if (i < lightEntities_.size() && CORE_NS::EntityUtil::IsValid(lightEntities_[i])) {
            // 写入 LightComponent
            if (auto oldLC = lightManager_->Write(lightEntities_.at(i)); oldLC) {
                // 修改灯光参数
                oldLC->color = BASE_NS::Math::Vec3(
                    lights[i]->color_.r_, lights[i]->color_.g_, lights[i]->color_.b_);
                oldLC->intensity = lights[i]->intensity_;
                oldLC->type = static_cast<LightType>(lights[i]->type_);
                oldLC->castsShadow = lights[i]->shadow_;
            }
            
            // 写入 TransformComponent
            if (auto tc = transformManager_->Write(lightEntities_.at(i)); tc) {
                // 修改位置
                tc->position = lights[i]->position_;
                // 修改旋转
                tc->rotation = lights[i]->rotation_;
            }
        }
    }
}
```

**使用的 Managers**：
- `lightManager_` → 修改 `LightComponent`
- `transformManager_` → 修改 `TransformComponent`

---

### **6.3 LoadEnvModel**

```cpp
// lume_common.cpp
void LumeCommon::LoadEnvModel(const std::string& modelPath, BackgroundType type)
{
    // 获取场景配置
    auto sceneComponent = sceneManager_->Write(sceneEntity_);
    if (sceneComponent) {
        // 获取环境 Manager
        auto envManager = CORE_NS::GetManager<CORE3D_NS::IEnvironmentComponentManager>(*ecs_);
        
        // 创建或修改 EnvironmentComponent
        envManager->Create(sceneComponent->environment);
        auto envHandle = envManager->Write(sceneComponent->environment);
        if (envHandle) {
            // 设置环境参数
            envHandle->backgroundType = static_cast<EnvBackgroundType>(type);
            envHandle->backgroundUri = modelPath;
        }
    }
}
```

**使用的 Managers**：
- `sceneManager_` → 写入 `RenderConfigurationComponent`
- `envManager` → 创建/修改 `EnvironmentComponent`

---

## 7. 多 ECS 切换时的问题

### **7.1 问题演示**

```cpp
// 初始化 ECS1
auto ecs1 = engine_->CreateEcs();
LoadSystemGraph(ecs1, "render_system.json");
// cameraManager_ = ecs1 的 CameraManager

// 初始化 ECS2
auto ecs2 = engine_->CreateEcs();
LoadSystemGraph(ecs2, "render_system.json");
// cameraManager_ = ecs2 的 CameraManager

// 切换到 ECS1 渲染
lumeCommon->ecs_ = ecs1;
CollectRenderHandles();  // 从 ecs1 获取 handles
RenderFrame();           // 渲染 ecs1 的场景

// 问题：调用修改方法
SetupCameraTransform(...);
// ⚠️ cameraManager_ 仍然指向 ecs2！
// ⚠️ 修改的是 ecs2 的相机，不是 ecs1 的！
```

### **7.2 解决方案**

#### 方案 1: 切换 ECS 后重新获取 Managers

```cpp
void LumeCommon::SwitchActiveEcs(uint64_t ecsId)
{
    auto it = ecsMap_.find(ecsId);
    if (it == ecsMap_.end()) {
        return;
    }
    
    ecs_ = it->second;
    auto& ecs = *ecs_;
    
    // 重新获取所有 Managers
    transformManager_ = CORE_NS::GetManager<CORE3D_NS::ITransformComponentManager>(ecs);
    cameraManager_ = CORE_NS::GetManager<CORE3D_NS::ICameraComponentManager>(ecs);
    sceneManager_ = CORE_NS::GetManager<CORE3D_NS::IRenderConfigurationComponentManager>(ecs);
    lightManager_ = CORE_NS::GetManager<CORE3D_NS::ILightComponentManager>(ecs);
    postprocessManager_ = CORE_NS::GetManager<CORE3D_NS::IPostProcessComponentManager>(ecs);
    // ...
}
```

#### 方案 2: 动态获取（推荐）

```cpp
// 不存储指针，使用时动态获取
void LumeCommon::SetupCameraTransform(...)
{
    if (!ecs_) return;
    
    // 动态获取 Manager
    auto* transformManager = CORE_NS::GetManager<CORE3D_NS::ITransformComponentManager>(*ecs_);
    auto* cameraManager = CORE_NS::GetManager<CORE3D_NS::ICameraComponentManager>(*ecs_);
    
    // 使用获取的 Manager
    auto cameraTransform = transformManager->Write(cameraEntity_);
    // ...
}
```

---

## 8. 总结

### **Component Manager 的作用**

| 作用 | 说明 |
|------|------|
| **数据存储** | 连续存储同类型 Component，提高缓存命中率 |
| **组件访问** | 提供 Read/Write 接口，安全访问 Component |
| **生命周期管理** | Create/Destroy Component |
| **查询支持** | 为 System 提供高效的 Component 查询 |

### **LumeCommon 中的 Managers**

| Manager | 管理的 Component | 用途 |
|---------|-----------------|------|
| `transformManager_` | TransformComponent | 位置、旋转、缩放 |
| `cameraManager_` | CameraComponent | 相机参数 |
| `sceneManager_` | RenderConfigurationComponent | 场景配置 |
| `lightManager_` | LightComponent | 灯光参数 |
| `postprocessManager_` | PostProcessComponent | 后处理效果 |
| `materialManager_` | MaterialComponent | 材质参数 |
| `meshManager_` | MeshComponent | 网格数据 |

### **多 ECS 切换注意事项**

⚠️ **Component Manager 指针不会自动切换！**

- 如果**只读渲染**（不调用修改方法），可以不处理
- 如果**需要修改场景**，必须在切换 ECS 后重新获取 Managers

---

**文档结束**
