# LumeRender 渲染流程分析及自定义2D平面方案

## 一、渲染流程概览

### 一帧渲染的完整流程

```
┌─────────────────────────────────────────────────────────────────┐
│ Phase 1: 准备阶段                                                 │
│   - Tick() 时间更新                                               │
│   - CommitFrameData() 数据提交                                    │
│   - FrameStart() 设备帧开始                                       │
├─────────────────────────────────────────────────────────────────┤
│ Phase 2: 节点执行阶段 (RenderNodeGraph)                           │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ 1. RenderNodeDefaultLights        - 收集光照数据          │   │
│   │ 2. RenderNodeDefaultCameras       - 设置相机              │   │
│   │ 3. RenderNodeDefaultMaterialObjects - 处理材质物体        │   │
│   │ 4. RenderNodeMorph                - 形态目标               │   │
│   │ 5. RenderNodeDefaultShadowRenderSlot - 【阴影贴图渲染】    │   │
│   │ 6. RenderNodeDefaultShadowsBlur   - VSM阴影模糊            │   │
│   │ 7. RenderNodeDefaultEnvironmentBlender - 环境处理         │   │
│   │ 8. RenderNodeDefaultMaterialRenderSlot - 【主要物体渲染】  │   │
│   │ 9. RenderNodeDefaultDepthRenderSlot - 深度预处理          │   │
│   │ 10. RenderNodeDefaultEnv          - 环境反射/天空盒        │   │
│   │ 11. RenderNodeDefaultLights       - 光照计算               │   │
│   │ 12. RenderNodeCameraPostProcessController - 【后处理控制】 │   │
│   └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│ Phase 3: 后端执行 - 提交GPU命令                     │
├─────────────────────────────────────────────────────────────────┤
│ Phase 4: 呈现 - 提交到交换链                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、关键阶段详解

### 1. 阴影贴图渲染时机

**RenderNode:** `RenderNodeDefaultShadowRenderSlot`

**执行位置:** 在主场景渲染**之前**执行

**流程:**
```
灯光数据收集 → 相机设置 → 阴影贴图渲染 → 阴影模糊(VSM) → 主场景渲染
```

**关键文件:**
- `nativerender/Lume_3D/src/render/node/render_node_default_shadow_render_slot.cpp`

**阴影贴图创建:**
- 深度缓冲: `CORE3D_DM_SHADOW_DEPTH_BUFFER` (D16_UNORM)
- VSM颜色缓冲: `CORE3D_DM_VSM_SHADOW_COLOR_BUFFER` (R16G16_SFLOAT)

**物体参与阴影的条件:**
```cpp
// MaterialComponent 中的标志
MaterialComponent::LightingFlagBits::SHADOW_CASTER_BIT    // 投射阴影
MaterialComponent::LightingFlagBits::SHADOW_RECEIVER_BIT  // 接收阴影
```

### 2. 主要网格物体渲染时机

**RenderNode:** `RenderNodeDefaultMaterialRenderSlot`

**执行位置:** 在阴影贴图渲染之后、后处理之前

**渲染内容:**
- 所有带有 RenderMeshComponent 的实体
- 按材质排序进行批处理
- 应用阴影计算结果

### 3. 后处理执行时机

**RenderNode:** `RenderNodeDefaultCameraPostProcessController`

**执行位置:** 在所有场景渲染完成后

**后处理链顺序:**
```
1. TAA (时间抗锯齿) - 需要 depth + history
2. Upscale (可选)
3. Lens Flare (镜头光晕)
4. Bloom (高光溢出)
5. Combined Post Process (色调映射 + 暗角 + 抖动 + 颜色转换)
6. FXAA (快速抗锯齿)
7. Motion Blur (运动模糊)
8. DOF (景深)
```

---

## 三、添加2D平面方案

### 方案: 使用 IMeshUtil 创建 Plane 并参与阴影

**步骤:**

1. **创建材质并设置阴影标志**
2. **使用 MeshUtil.GeneratePlane 创建网格**
3. **创建可渲染实体**
4. **设置纹理映射**

**关键代码:**
```cpp
// 1. 获取 MeshUtil
auto& meshUtil = graphicsContext.GetMeshUtil();

// 2. 创建材质
Entity materialEntity = ecs.GetEntityManager().Create();
materialManager->Create(materialEntity);
if (auto matHandle = materialManager->Write(materialEntity); matHandle) {
    // 启用阴影投射和接收
    matHandle->materialLightingFlags =
        MaterialComponent::LightingFlagBits::SHADOW_CASTER_BIT |
        MaterialComponent::LightingFlagBits::SHADOW_RECEIVER_BIT;

    // 设置纹理
    matHandle->textures[0].image = yourTextureHandle;
}

// 3. 创建 Plane Mesh
Entity planeEntity = meshUtil.GeneratePlane(ecs, "MyPlane", materialEntity, width, depth);

// 4. 设置位置 (可选)
auto nodeManager = GetManager<INodeComponentManager>(ecs);
if (auto nodeHandle = nodeManager->Write(planeEntity); nodeHandle) {
    nodeHandle->position = Math::Vec3(x, y, z);
}
```

---

## 四、关键文件汇总

| 功能 | 文件路径 |
|------|----------|
| 渲染器核心 | `nativerender/LumeRender/src/renderer.cpp` |
| 阴影渲染节点 | `nativerender/Lume_3D/src/render/node/render_node_default_shadow_render_slot.cpp` |
| 材质渲染节点 | `nativerender/Lume_3D/src/render/node/render_node_default_material_render_slot.cpp` |
| 后处理控制器 | `nativerender/Lume_3D/src/render/node/render_node_default_camera_post_process_controller.cpp` |
| Mesh工具类 | `nativerender/Lume_3D/src/util/mesh_util.cpp` |
| 材质组件 | `nativerender/Lume_3D/api/3d/ecs/components/material_component.h` |
| 渲染节点图配置 | `nativerender/Lume_3D/assets/3d/rendernodegraphs/core3d_rng_scene.rng` |

---

## 五、验证方案

1. **创建 Plane 并验证可见性**
   - 运行应用确认 Plane 正确渲染
   - 检查纹理映射是否正确

2. **验证阴影参与**
   - 添加一个光源并启用阴影
   - 确认 Plane 投射阴影到其他物体
   - 确认其他物体投射阴影到 Plane

3. **调试工具**
   - 使用 RenderDoc 或类似工具检查阴影贴图
   - 验证阴影贴图中包含 Plane 的深度信息