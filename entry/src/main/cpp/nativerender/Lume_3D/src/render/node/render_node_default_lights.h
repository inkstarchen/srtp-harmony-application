/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef CORE__RENDER__NODE__RENDER_NODE_DEFAULT_LIGHTS_H
#define CORE__RENDER__NODE__RENDER_NODE_DEFAULT_LIGHTS_H

#include <base/util/uid.h>
#include <core/namespace.h>
#include <render/nodecontext/intf_render_node.h>
#include <render/resource_handle.h>

#include "render/render_node_scene_util.h"

CORE3D_BEGIN_NAMESPACE()

/**
 * @brief 默认灯光渲染节点 - 负责收集和处理场景中的所有灯光数据
 *
 * ============================================================================
 * 【功能概述】
 * ============================================================================
 * 该节点从 IRenderDataStoreDefaultLight 中收集所有灯光数据，
 * 将其排序、分类并写入 GPU 缓冲区，供后续渲染阶段使用。
 *
 * ============================================================================
 * 【输入】
 * ============================================================================
 * 1. IRenderDataStoreDefaultScene - 场景数据存储
 *    - 提供当前场景的相机索引 (scene.cameraIndex)
 *
 * 2. IRenderDataStoreDefaultCamera - 相机数据存储
 *    - 提供相机列表和场景ID，用于灯光排序和筛选
 *
 * 3. IRenderDataStoreDefaultLight - 灯光数据存储（核心输入）
 *    - 提供所有灯光的属性：
 *      - 方向光 (Directional Light)
 *      - 点光源 (Point Light)
 *      - 聚光灯 (Spot Light)
 *    - 提供阴影贴图信息：阴影数量、阴影图集尺寸
 *
 * ============================================================================
 * 【创建与调用】
 * ============================================================================
 * 1. 创建方式：通过 RenderNodeGraph 配置文件 (.rng) 声明
 *    - 文件：core3d_rng_scene.rng
 *    - 配置：
 *      {
 *          "typeName": "RenderNodeDefaultLights",
 *          "nodeName": "CORE3D_RN_SCENE_DL"
 *      }
 *
 * 2. 调用时机：在一帧渲染的早期阶段，通常是 RenderNodeGraph 中的第一个节点
 *    - 执行顺序：Lights -> Cameras -> MaterialObjects -> Shadows -> ...
 *
 * 3. 注册方式：在 static_plugin.cpp 中通过 FillRenderNodeTypeInfo 注册
 *
 * ============================================================================
 * 【输出】
 * ============================================================================
 * 1. lightBufferHandle_ - 灯光数据缓冲区 (Uniform Buffer)
 *    - 缓冲区名称：<SceneDataStoreName>_CORE3D_DM_LIGHT_DATA_BUFFER
 *    - 数据结构：DefaultMaterialLightStruct
 *    - 包含内容：
 *      - 方向光数量和起始索引
 *      - 点光源数量和起始索引
 *      - 聚光灯数量和起始索引
 *      - 阴影图集尺寸信息
 *      - 所有灯光的详细数据数组
 *
 * 2. lightClusterBufferHandle_ - 灯光聚类数据缓冲区 (Storage Buffer)
 *    - 缓冲区名称：<SceneDataStoreName>_CORE3D_DM_LIGHT_CLUSTER_DATA_BUFFER
 *    - 用于基于聚类的灯光剔除优化
 *
 * 输出通过 IRenderNodeGraphShareManager 注册，供其他渲染节点使用。
 *
 * ============================================================================
 * 【被谁使用】
 * ============================================================================
 * 输出的灯光缓冲区被以下渲染节点和 Shader 使用：
 *
 * 1. RenderNodeDefaultShadowRenderSlot - 阴影渲染节点
 *    - 根据灯光信息确定阴影相机设置
 *
 * 2. RenderNodeDefaultMaterialRenderSlot - 材质渲染节点
 *    - 在 Fragment Shader 中访问灯光数据进行光照计算
 *
 * 3. Shader 使用：
 *    - 3d_dm_frag_layout_common.h 中的 uLightData
 *    - 3d_dm_vert_layout_common.h 中的 uLightData
 *    - 3d_cluster_lights.comp 计算着色器
 *
 * ============================================================================
 * 【如何使用】
 * ============================================================================
 * 在 Shader 中绑定灯光缓冲区：
 *
 * // GLSL 示例
 * layout(set = 0, binding = 5) uniform DefaultMaterialLightStruct uLightData;
 *
 * // 访问灯光数据
 * for (uint i = 0; i < uLightData.directionalLightCount; i++) {
 *     DefaultMaterialSingleLightStruct light = uLightData.lights[i];
 *     // 执行光照计算...
 * }
 *
 * ============================================================================
 * 【执行流程】
 * ============================================================================
 * InitNode() -> 创建 GPU 缓冲区
 *     ↓
 * PreExecuteFrame() -> 每帧注册输出句柄
 *     ↓
 * ExecuteFrame() -> 从 DataStore 读取灯光数据
 *                 -> 排序和分类灯光
 *                 -> 写入 GPU 缓冲区
 */
class RenderNodeDefaultLights final : public RENDER_NS::IRenderNode {
public:
    RenderNodeDefaultLights() = default;
    ~RenderNodeDefaultLights() override = default;

    /**
     * @brief 初始化节点 - 创建灯光数据 GPU 缓冲区
     *
     * 执行内容：
     * 1. 获取场景数据存储引用
     * 2. 创建灯光数据 Uniform Buffer (DefaultMaterialLightStruct)
     * 3. 创建灯光聚类 Storage Buffer
     * 4. 将缓冲区句柄注册到 RenderNodeGraph 共享管理器
     */
    void InitNode(RENDER_NS::IRenderNodeContextManager& renderNodeContextMgr) override;

    /**
     * @brief 每帧预处理 - 更新输出句柄注册
     *
     * 每帧执行，确保输出缓冲区句柄对其他节点可见
     */
    void PreExecuteFrame() override;

    /**
     * @brief 执行帧 - 收集灯光数据并写入 GPU 缓冲区
     *
     * 执行内容：
     * 1. 从 IRenderDataStoreDefaultLight 获取所有灯光
     * 2. 从 IRenderDataStoreDefaultCamera 获取相机信息
     * 3. 根据场景 ID 排序灯光（优先当前场景的灯光）
     * 4. 分类统计：方向光、点光源、聚光灯
     * 5. 写入 DefaultMaterialLightStruct 结构到 GPU 缓冲区
     */
    void ExecuteFrame(RENDER_NS::IRenderCommandList& cmdList) override;

    /**
     * @brief 获取执行标志
     * @return 0 表示始终执行（期望场景中可能有灯光或需要重置 GPU 数据）
     */
    ExecuteFlags GetExecuteFlags() const override
    {
        // expect to have lights or need to reset GPU data
        return 0U;
    }

    // ==================== 插件/工厂接口 ====================
    /** 节点唯一标识符 */
    static constexpr BASE_NS::Uid UID { "8757af6a-adde-471f-b475-8f8c0962d8b6" };
    /** 节点类型名称 - 用于 .rng 配置文件匹配 */
    static constexpr const char* const TYPE_NAME = "RenderNodeDefaultLights";
    /** 后端标志 */
    static constexpr IRenderNode::BackendFlags BACKEND_FLAGS = IRenderNode::BackendFlagBits::BACKEND_FLAG_BITS_DEFAULT;
    /** 节点类型 */
    static constexpr IRenderNode::ClassType CLASS_TYPE = IRenderNode::ClassType::CLASS_TYPE_NODE;
    /** 工厂方法：创建节点实例 */
    static IRenderNode* Create();
    /** 工厂方法：销毁节点实例 */
    static void Destroy(IRenderNode* instance);

private:
    /** 渲染节点上下文管理器 - 提供资源管理、数据存储访问等功能 */
    RENDER_NS::IRenderNodeContextManager* renderNodeContextMgr_ { nullptr };

    /** 场景渲染数据存储引用 - 包含 Scene、Camera、Light 数据存储的名称 */
    SceneRenderDataStores stores_;

    /** 灯光数据缓冲区句柄 - 存储 DefaultMaterialLightStruct */
    RENDER_NS::RenderHandleReference lightBufferHandle_;

    /** 灯光聚类数据缓冲区句柄 - 存储聚类剔除数据 */
    RENDER_NS::RenderHandleReference lightClusterBufferHandle_;
};
CORE3D_END_NAMESPACE()

#endif // CORE__RENDER__NODE__RENDER_NODE_DEFAULT_LIGHTS_H
