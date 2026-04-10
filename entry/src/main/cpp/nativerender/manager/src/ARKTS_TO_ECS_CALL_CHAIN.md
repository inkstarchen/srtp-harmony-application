# ArkTS 到 C++ ECS 调用链路分析

**文档版本**: 1.0  
**创建日期**: 2026 年 4 月 7 日

---

## 1. 完整架构图

```
┌─────────────────────────────────────────────────────────────────┐
│  ArkTS 层 (应用层)                                               │
│                                                                  │
│  const light = scene.createLight({ name: "Light1" });           │
│  light.color = { r: 1, g: 0, b: 0 };  ← 修改属性                │
│  light.intensity = 5.0;               ← 修改属性                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ NAPI 调用
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  JS Binding 层 (C++)                                             │
│                                                                  │
│  LightJS::SetColor()                                            │
│  LightJS::SetIntensity()                                        │
│      │                                                           │
│      ├─ GetNativeObject() → SCENE_NS::ILight::Ptr               │
│      │                                                           │
│      └─ node->Color()->SetValue(color)  ← Property Handle       │
│          node->Intensity()->SetValue(intensity)                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 接口调用
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Scene API 层 (C++)                                              │
│                                                                  │
│  SCENE_NS::ILight (接口)                                         │
│  ├─ Color() → IPropertyHandle<Math::Vec3>                       │
│  ├─ Intensity() → IPropertyHandle<float>                        │
│  └─ SetValue() → 通知 ECS 更新                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ ECS Component 访问
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ECS 层 (C++)                                                    │
│                                                                  │
│  ECS                                                             │
│  ├─ Entity (Light Entity)                                       │
│  │   └─ LightComponent                                          │
│  │       ├─ color: Vec3                                         │
│  │       └─ intensity: float                                    │
│  │                                                               │
│  └─ ILightComponentManager                                      │
│      └─ Write(entity) → LightComponent&                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 详细调用链路

### **2.1 ArkTS 创建 Light**

```typescript
// ArkTS 代码
import { Scene, LightType } from "libnativerender.so";

// 1. 加载场景
const scene = await Scene.load("scene://default");

// 2. 创建灯光
const light = await scene.createLight({
    name: "MyLight",
    color: { r: 1, g: 0, b: 0 },
    intensity: 5.0
}, LightType.POINT);
```

**C++ 调用链**：

```
ArkTS: scene.createLight(params)
    │
    ▼ NAPI 调用
SceneJS::CreateLight()
    │
    ├─ scene->CreateNode(nodePath, classId)  ← Scene API
    │   │
    │   └─ 返回 SCENE_NS::INode::Ptr
    │
    ├─ CreateFromNativeInstance(env, node, ...)
    │   │
    │   └─ 创建 LightJS 对象
    │       ├─ PointLightJS 构造函数
    │       │   │
    │       │   └─ BaseLight::Create()
    │       │       │
    │       │       └─ 存储 scene_ 引用
    │       │
    │       └─ SetNativeObject(node)  ← 绑定 native 对象
    │
    └─ 返回 LightJS 到 ArkTS
```

---

### **2.2 ArkTS 修改 Light 属性**

```typescript
// ArkTS 代码
light.color = { r: 0, g: 1, b: 0 };      // 修改颜色
light.intensity = 10.0;                   // 修改强度
light.shadowEnabled = true;               // 启用阴影
```

**C++ 调用链**：

```
ArkTS: light.color = { r: 0, g: 1, b: 0 }
    │
    ▼ NAPI Setter 调用
LightJS::SetColor(NapiApi::FunctionContext<Object>& ctx)
    │
    ├─ validateSceneRef()  ← 验证 scene 引用
    │
    ├─ ctx.This().GetNative<SCENE_NS::ILight>()
    │   │
    │   └─ GetNativeObject() → SCENE_NS::ILight::Ptr
    │       │
    │       └─ 从 BaseObject 获取存储的 native 对象
    │
    ├─ node->Color()  ← Scene API Property Handle
    │   │
    │   └─ 返回 IPropertyHandle<Math::Vec3>
    │
    └─ node->Color()->SetValue(obj)
        │
        ├─ ColorProxy::SetValue(obj)
        │   │
        │   ├─ obj.Get("r") → 0.0
        │   ├─ obj.Get("g") → 1.0
        │   └─ obj.Get("b") → 0.0
        │
        └─ property_->SetValue(BASE_NS::Math::Vec3(0, 1, 0))
            │
            ▼
        SCENE_NS::IPropertyHandle::SetValue()
            │
            ├─ 通知 Scene API 属性变化
            │
            └─ 触发 ECS Component 更新
                │
                ▼
            ILightComponentManager::Write(entity)
                │
                └─ LightComponent.color = Vec3(0, 1, 0)  ← 更新 ECS 数据
```

---

### **2.3 详细代码分析**

#### **LightJS::SetColor**

```cpp
// LightJS.cpp:170
napi_value BaseLight::GetColor(NapiApi::FunctionContext<>& ctx)
{
    if (!validateSceneRef()) {
        return ctx.GetUndefined();
    }
    auto node = ctx.This().GetNative<SCENE_NS::ILight>();
    if (!node) {
        return ctx.GetUndefined();
    }
    if (colorProxy_ == nullptr) {
        // 创建 Proxy 用于 JS ↔ C++ 类型转换
        colorProxy_ = BASE_NS::make_unique<ColorProxy>(ctx.GetEnv(), node->Color());
    }
    return colorProxy_->Value();
}

void BaseLight::SetColor(NapiApi::FunctionContext<Object>& ctx)
{
    if (!validateSceneRef()) {
        return;
    }
    auto node = ctx.This().GetNative<SCENE_NS::ILight>();
    if (!node) {
        return;
    }
    NapiApi::Object obj = ctx.Arg<0>();  // ArkTS 传入的颜色对象
    if (colorProxy_ == nullptr) {
        colorProxy_ = BASE_NS::make_unique<ColorProxy>(ctx.GetEnv(), node->Color());
    }
    colorProxy_->SetValue(obj);  // ← 类型转换并设置
}
```

#### **ColorProxy 类型转换**

```cpp
// ColorProxy 负责 JS Object ↔ Math::Vec3 转换
class ColorProxy {
    napi_env env_;
    IPropertyHandle<BASE_NS::Math::Vec3>* property_;
    napi_ref colorRef_;  // JS 对象引用
    
public:
    // JS → C++
    void SetValue(NapiApi::Object obj) {
        float r = obj.Get<float>("r").valueOrDefault(0.0f);
        float g = obj.Get<float>("g").valueOrDefault(0.0f);
        float b = obj.Get<float>("b").valueOrDefault(0.0f);
        
        // 调用 Property Handle 设置值
        property_->SetValue(BASE_NS::Math::Vec3(r, g, b));
        // ↑ 这会触发 ECS 更新
    }
    
    // C++ → JS
    napi_value Value() {
        BASE_NS::Math::Vec3 color = property_->GetValue();
        
        NapiApi::Object obj(env_);
        obj.Set("r", color.x_);
        obj.Set("g", color.y_);
        obj.Set("b", color.z_);
        
        return obj.ToNapiValue();
    }
};
```

---

## 3. 关键类解析

### **3.1 BaseObject - JS 包装器基类**

```cpp
// BaseObjectJS.h
class BaseObject {
    // JS 对象引用
    NapiApi::WeakRef jsWrapper_;
    
    // Native 对象指针（关键！）
    META_NS::IObject::Ptr nativeObject_;
    PtrType ptrType_ = PtrType::WEAK;
    
public:
    // 设置 native 对象
    void SetNativeObject(META_NS::IObject::Ptr obj, PtrType type) {
        nativeObject_ = obj;
        ptrType_ = type;
    }
    
    // 获取 native 对象
    template<typename T>
    T GetNativeObject() const {
        return interface_pointer_cast<T>(nativeObject_);
    }
    
    // 获取 JS 包装器
    template<typename T>
    T GetJsWrapper() const {
        return jsWrapper_.GetObject().GetJsWrapper<T>();
    }
};
```

**作用**：
- 存储 JS 对象和 Native 对象的双向引用
- 提供类型转换接口

---

### **3.2 LightJS - 灯光 JS 包装器**

```cpp
// LightJS.h
class BaseLight : public NodeImpl {
    LightType lightType_;
    BASE_NS::unique_ptr<ColorProxy> colorProxy_;
    NapiApi::WeakRef scene_;  // SceneJS 引用
    
public:
    // 属性访问方法（注册到 NAPI）
    static void Init(const char* class_name, napi_env env, 
                     napi_value exports, BASE_NS::vector<napi_property_descriptor>& np) {
        // 注册属性
        np.push_back(TROGetSetProperty<Object, BaseLight, 
                     &BaseLight::GetColor, &BaseLight::SetColor>("color"));
        np.push_back(TROGetSetProperty<float, BaseLight, 
                     &BaseLight::GetIntensity, &BaseLight::SetIntensity>("intensity"));
        np.push_back(TROGetSetProperty<bool, BaseLight, 
                     &BaseLight::GetShadowEnabled, &BaseLight::SetShadowEnabled>("shadowEnabled"));
        
        // 定义 JS 类
        napi_define_class(env, class_name, NAPI_AUTO_LENGTH, ctor, ..., &func);
    }
};
```

---

### **3.3 NodeImpl - 节点实现基类**

```cpp
// NodeImpl.h
class NodeImpl : public SceneResourceImpl {
    enum NodeType { NODE, GEOMETRY, CAMERA, LIGHT, TEXT };
    
    // Proxy 用于类型转换
    BASE_NS::unique_ptr<Vec3Proxy> posProxy_;
    BASE_NS::unique_ptr<Vec3Proxy> sclProxy_;
    BASE_NS::unique_ptr<QuatProxy> rotProxy_;
    
public:
    // 位置属性
    napi_value GetPosition(NapiApi::FunctionContext<>& fc) {
        auto node = fc.This().GetNative<SCENE_NS::INode>();
        if (!node) return fc.GetUndefined();
        
        if (!posProxy_) {
            posProxy_ = BASE_NS::make_unique<Vec3Proxy>(fc.GetEnv(), node->Position());
        }
        return posProxy_->Value();  // JS Object {x, y, z}
    }
    
    void SetPosition(NapiApi::FunctionContext<NapiApi::Object>& fc) {
        auto node = fc.This().GetNative<SCENE_NS::INode>();
        if (!node) return;
        
        NapiApi::Object obj = fc.Arg<0>();  // {x, y, z}
        if (!posProxy_) {
            posProxy_ = BASE_NS::make_unique<Vec3Proxy>(fc.GetEnv(), node->Position());
        }
        posProxy_->SetValue(obj);  // ← 更新 ECS
    }
};
```

---

### **3.4 Scene API Property Handle**

```cpp
// Scene API 属性句柄
template<typename T>
class IPropertyHandle {
public:
    // 获取值
    virtual T GetValue() const = 0;
    
    // 设置值（会触发 ECS 更新）
    virtual void SetValue(const T& value) = 0;
    
    // 注册变化回调
    virtual void AddListener(Listener listener) = 0;
};

// 使用示例
SCENE_NS::ILight::Ptr light = ...;
IPropertyHandle<BASE_NS::Math::Vec3>* colorProp = light->Color();

// 读取
BASE_NS::Math::Vec3 color = colorProp->GetValue();

// 写入（触发 ECS 更新）
colorProp->SetValue(BASE_NS::Math::Vec3(1, 0, 0));
// ↑ 这会通知 ECS：LightComponent.color 发生变化
```

---

## 4. ECS 更新流程

### **4.1 Property Handle 如何更新 ECS**

```cpp
// Scene API 内部实现
class LightPropertyHandle : public IPropertyHandle<BASE_NS::Math::Vec3> {
    SCENE_NS::ILight* light_;  // 接口指针
    ILightComponentManager* manager_;  // ECS Manager
    
public:
    void SetValue(const BASE_NS::Math::Vec3& color) override {
        // 1. 获取 Light 对应的 Entity
        Entity lightEntity = light_->GetEntity();
        
        // 2. 写入 ECS Component
        auto handle = manager_->Write(lightEntity);
        if (handle) {
            handle->color = color;  // ← 直接修改 ECS 数据
        }
        
        // 3. 通知监听器（可选）
        NotifyListeners(color);
    }
};
```

---

### **4.2 ECS 数据流**

```
┌─────────────────────────────────────────────────────────────┐
│  ECS 内存布局                                                │
│                                                              │
│  ILightComponentManager                                      │
│  ├─ components_: vector<LightComponent>                      │
│  │   [0] LightComponent { color: (1,0,0), intensity: 5.0 }  │
│  │   [1] LightComponent { color: (0,1,0), intensity: 3.0 }  │
│  │   [2] LightComponent { color: (0,0,1), intensity: 8.0 }  │
│  │                                                            │
│  └─ entityToIndex_: { Entity1→0, Entity2→1, Entity3→2 }     │
│                                                              │
│  当 ArkTS 调用 light.color = {r:0, g:1, b:0} 时：             │
│  1. LightJS::SetColor()                                      │
│  2. GetNativeObject() → ILight                               │
│  3. light->Color()->SetValue(Vec3(0,1,0))                    │
│  4. manager_->Write(entity) → LightComponent&                │
│  5. component.color = Vec3(0,1,0)  ← 直接修改内存            │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. 完整调用链路示例

### **示例：ArkTS 修改灯光颜色**

```typescript
// ArkTS
light.color = { r: 1, g: 0.5, b: 0 };
```

**C++ 调用栈**：

```
0. NAPI 入口
   └─ napi_set_named_property(env, lightObj, "color", value)

1. LightJS::SetColor(NapiApi::FunctionContext<Object>& ctx)
   ├─ validateSceneRef()  ✓
   ├─ ctx.This().GetNative<SCENE_NS::ILight>()
   │  └─ BaseObject::GetNativeObject() → ILight::Ptr
   ├─ node->Color() → IPropertyHandle<Vec3>*
   └─ colorProxy_->SetValue(obj)
      ├─ obj.Get<float>("r") → 1.0
      ├─ obj.Get<float>("g") → 0.5
      ├─ obj.Get<float>("b") → 0.0
      └─ property_->SetValue(Vec3(1.0, 0.5, 0.0))

2. LightPropertyHandle::SetValue(const Vec3& color)
   ├─ light_->GetEntity() → Entity123
   ├─ manager_->Write(Entity123) → ScopedHandle<LightComponent>
   └─ handle->color = Vec3(1.0, 0.5, 0.0)  ← ECS 数据更新

3. ECS 系统检测到变化
   └─ RenderSystem::Update()
      ├─ 检测到 LightComponent 变化
      ├─ 更新 RenderLight 数据
      └─ 标记需要重新渲染
```

---

## 6. 关键数据流图

```
ArkTS 层
   │
   │ light.color = { r: 1, g: 0.5, b: 0 }
   ▼
┌─────────────────────────────────────────────────────────┐
│ LightJS (JS Wrapper)                                    │
│ ├─ scene_: WeakRef<SceneJS>                             │
│ ├─ nativeObject_: ILight::Ptr  ← 存储 Native 对象         │
│ └─ colorProxy_: ColorProxy  ← 类型转换                  │
└─────────────────────────────────────────────────────────┘
   │
   │ GetNativeObject()
   ▼
┌─────────────────────────────────────────────────────────┐
│ SCENE_NS::ILight (Scene API Interface)                  │
│ ├─ Color() → IPropertyHandle<Vec3>                      │
│ ├─ Intensity() → IPropertyHandle<float>                 │
│ └─ Type() → IPropertyHandle<LightType>                  │
└─────────────────────────────────────────────────────────┘
   │
   │ SetValue()
   ▼
┌─────────────────────────────────────────────────────────┐
│ ILightComponentManager (ECS Manager)                    │
│ ├─ components_: vector<LightComponent>                  │
│ ├─ Write(entity) → LightComponent&                      │
│ └─ 直接修改内存：component.color = Vec3(1, 0.5, 0)     │
└─────────────────────────────────────────────────────────┘
   │
   │ ECS System 检测变化
   ▼
┌─────────────────────────────────────────────────────────┐
│ RenderSystem (ECS System)                               │
│ ├─ Update() 检测 Component 变化                          │
│ ├─ 收集变化的 Light 数据                                 │
│ └─ 更新 RenderNodeGraph                                  │
└─────────────────────────────────────────────────────────┘
```

---

## 7. 总结

### **调用链路总结**

| 层级 | 组件 | 职责 |
|------|------|------|
| **ArkTS** | Light, Node | 应用层接口 |
| **NAPI** | LightJS, NodeJS | JS ↔ C++ 桥接 |
| **Scene API** | ILight, IPropertyHandle | 属性访问接口 |
| **ECS Manager** | ILightComponentManager | Component 存储和访问 |
| **ECS Data** | LightComponent | 实际数据 |

### **关键机制**

1. **双向引用** - BaseObject 存储 JS 和 Native 对象的引用
2. **Property Handle** - Scene API 提供统一的属性访问接口
3. **Proxy 转换** - ColorProxy/Vec3Proxy 负责 JS ↔ C++ 类型转换
4. **直接内存访问** - Component Manager 直接修改 ECS 内存
5. **变化通知** - Property Handle 通知 ECS System 数据变化

### **性能优化**

- Proxy 对象缓存（不重复创建）
- 直接内存访问（无拷贝）
- 延迟更新（System 按需查询）

---

**文档结束**
