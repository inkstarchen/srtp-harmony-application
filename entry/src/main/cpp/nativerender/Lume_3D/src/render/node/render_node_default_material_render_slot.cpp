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

/**
 * @file render_node_default_material_render_slot.cpp
 * @brief 默认材质渲染槽位节点实现
 *
 * ============================================================================
 * 【功能概述】
 * ============================================================================
 * 负责渲染所有网格物体的核心渲染节点。
 *
 * 核心职责：
 * 1. 从 DataStore 获取排序后的子网格列表
 * 2. 管理 Pipeline State Object (PSO) 缓存
 * 3. 绑定全局 Descriptor Sets (Set 0/1/2/3)
 * 4. 执行绘制命令（支持 GPU 实例化、骨骼动画）
 * 5. 处理材质排序和视锥体裁剪
 *
 * ============================================================================
 * 【输入】
 * ============================================================================
 * 1. IRenderDataStoreDefaultMaterial
 *    - 子网格列表 (RenderSubmesh)
 *    - 材质数据
 *    - 自定义资源句柄
 *
 * 2. IRenderDataStoreDefaultCamera
 *    - 相机列表
 *    - 多视图相机索引
 *
 * 3. IRenderDataStoreDefaultLight
 *    - 灯光统计（阴影数量、灯光类型）
 *    - 光照标志
 *
 * 4. JSON 配置
 *    - renderSlot: 渲染槽位（Opaque/Translucent）
 *    - sortType: 排序类型（by_material/back_to_front）
 *    - cullType: 裁剪类型（view_frustum_cull）
 *
 * ============================================================================
 * 【输出】
 * ============================================================================
 * 直接渲染到 RenderPass 的颜色和深度附件，不产生 GPU Buffer 输出。
 *
 * ============================================================================
 * 【Shader 数据识别机制】
 * ============================================================================
 * Shader 通过三种方式识别传入的数据：
 *
 * 1. Descriptor Sets（描述符集）:
 *    - Set 0: 全局数据（相机、环境、灯光）
 *    - Set 1: 每物体数据（网格矩阵、骨骼、材质）- 使用动态偏移
 *    - Set 2: 每材质数据（纹理采样器）
 *    - Set 3: 自定义资源（可选）
 *
 * 2. Dynamic Offsets（动态偏移）:
 *    - Set 1 的绑定使用动态偏移，高效切换每物体数据
 *    - offset = meshIndex * 256 字节
 *
 * 3. Specialization Constants（特化常量）:
 *    - MATERIAL_TYPE: 材质类型（PBR/Unlit/Custom）
 *    - MATERIAL_FLAGS: 材质标志（阴影接收、法线贴图等）
 *    - LIGHTING_FLAGS: 光照标志（VSM阴影、点光源等）
 *    - CAMERA_FLAGS: 相机标志（雾效等）
 *    - SUBMESH_FLAGS: 子网格标志（骨骼、顶点色等）
 *
 * ============================================================================
 * 【执行流程】
 * ============================================================================
 * InitNode() -> 解析配置，创建默认 Shader 数据
 *     ↓
 * PreExecuteFrame() -> （当前为空）
 *     ↓
 * ExecuteFrame() -> 获取 DataStore
 *                 -> 更新当前场景
 *                 -> 开始 RenderPass
 *                 -> 处理子网格列表（排序、裁剪）
 *                 -> 渲染子网格：
 *                    - BindPipeline (PSO)
 *                    - BindSet1And2 (Mesh/Material)
 *                    - BindSet3 (自定义资源)
 *                    - Draw (绘制命令)
 *                 -> 结束 RenderPass
 */

#include "render_node_default_material_render_slot.h"

#include <algorithm>

#include <3d/render/default_material_constants.h>
#include <3d/render/intf_render_data_store_default_camera.h>
#include <3d/render/intf_render_data_store_default_light.h>
#include <3d/render/intf_render_data_store_default_material.h>
#include <3d/render/intf_render_data_store_default_scene.h>
#include <base/math/matrix_util.h>
#include <base/math/vector.h>
#include <core/log.h>
#include <core/namespace.h>
#include <render/datastore/intf_render_data_store.h>
#include <render/datastore/intf_render_data_store_manager.h>
#include <render/datastore/intf_render_data_store_pod.h>
#include <render/datastore/render_data_store_render_pods.h>
#include <render/device/intf_gpu_resource_manager.h>
#include <render/device/intf_shader_manager.h>
#include <render/nodecontext/intf_node_context_descriptor_set_manager.h>
#include <render/nodecontext/intf_node_context_pso_manager.h>
#include <render/nodecontext/intf_pipeline_descriptor_set_binder.h>
#include <render/nodecontext/intf_render_command_list.h>
#include <render/nodecontext/intf_render_node_context_manager.h>
#include <render/nodecontext/intf_render_node_parser_util.h>
#include <render/nodecontext/intf_render_node_util.h>
#include <render/resource_handle.h>

#include "render/default_constants.h"
#include "render/render_node_scene_util.h"

#if (CORE3D_DEV_ENABLED == 1)
#include "render/datastore/render_data_store_default_material.h"
#endif

namespace {
#include <3d/shaders/common/3d_dm_structures_common.h>
#include <render/shaders/common/render_post_process_structs_common.h>
} // namespace

CORE3D_BEGIN_NAMESPACE()
using namespace BASE_NS;
using namespace RENDER_NS;

namespace {
// ============================================================================
// 常量定义
// ============================================================================

// 后处理数据存储类型名称
constexpr string_view POST_PROCESS_DATA_STORE_TYPE_NAME { "RenderDataStorePod" };

// 动态状态：视口和裁剪区域
constexpr DynamicStateEnum DYNAMIC_STATES[] = { CORE_DYNAMIC_STATE_ENUM_VIEWPORT, CORE_DYNAMIC_STATE_ENUM_SCISSOR };

// 动态状态：视口、裁剪区域、片段着色率（用于 FSR）
constexpr DynamicStateEnum DYNAMIC_STATES_FSR[] = { CORE_DYNAMIC_STATE_ENUM_VIEWPORT, CORE_DYNAMIC_STATE_ENUM_SCISSOR,
    CORE_DYNAMIC_STATE_ENUM_FRAGMENT_SHADING_RATE };

// UBO 绑定偏移对齐（256 字节）
constexpr uint32_t UBO_BIND_OFFSET_ALIGNMENT { PipelineLayoutConstants::MIN_UBO_BIND_OFFSET_ALIGNMENT_BYTE_SIZE };

// ========== 渲染哈希计算相关的位移和掩码 ==========
// 哈希用于 PSO 缓存查找，组合多个因素

// 光照标志在哈希中的位置（32-35 位）
static constexpr uint64_t LIGHTING_FLAGS_SHIFT { 32ULL };
static constexpr uint64_t LIGHTING_FLAGS_MASK { 0xF00000000ULL };

// 后处理标志在哈希中的位置（36-39 位）
static constexpr uint64_t POST_PROCESS_FLAGS_SHIFT { 36ULL };
static constexpr uint64_t POST_PROCESS_FLAGS_MASK { 0xF000000000ULL };

// 相机标志在哈希中的位置（40-43 位）
static constexpr uint64_t CAMERA_FLAGS_SHIFT { 40ULL };
static constexpr uint64_t CAMERA_FLAGS_MASK { 0xF0000000000ULL };

// 渲染哈希标志掩码（低 32 位）
static constexpr uint64_t RENDER_HASH_FLAGS_MASK { 0xFFFFffffULL };

// 图元拓扑在哈希中的位置（44-47 位）
static constexpr uint64_t PRIMITIVE_TOPOLOGY_SHIFT { 44ULL };
static constexpr uint64_t PRIMITIVE_TOPOLOGY_MASK { 0xF00000000000ULL };

// 后处理重要标志掩码（只取低 8 位）
static constexpr uint32_t POST_PROCESS_IMPORTANT_FLAGS_MASK { 0xffu };

// 固定的自定义 Descriptor Set 索引
static constexpr uint32_t FIXED_CUSTOM_SET3 { 3u };

// ============================================================================
// 辅助函数
// ============================================================================

/**
 * @brief 获取多视图相机索引
 *
 * 从相机的多视图配置中提取所有子相机的索引
 *
 * @param rds 相机 DataStore
 * @param cam 当前相机
 * @param mvIndices 输出的索引列表
 */
inline void GetMultiViewCameraIndices(
    const IRenderDataStoreDefaultCamera& rds, const RenderCamera& cam, vector<uint32_t>& mvIndices)
{
    CORE_STATIC_ASSERT(RenderSceneDataConstants::MAX_MULTI_VIEW_LAYER_CAMERA_COUNT == 7U);
    const uint32_t inputCount =
        Math::min(cam.multiViewCameraCount, RenderSceneDataConstants::MAX_MULTI_VIEW_LAYER_CAMERA_COUNT);
    mvIndices.clear();
    mvIndices.reserve(inputCount);
    for (uint32_t idx = 0U; idx < inputCount; ++idx) {
        const uint64_t id = cam.multiViewCameraIds[idx];
        if (id != RenderSceneDataConstants::INVALID_ID) {
            mvIndices.push_back(Math::min(rds.GetCameraIndex(id), CORE_DEFAULT_MATERIAL_MAX_CAMERA_COUNT - 1U));
        }
    }
}

/**
 * @brief 计算 Shader 数据和子网格的组合哈希
 *
 * 哈希组合了以下因素，用于 PSO 缓存查找：
 * - renderHash: 渲染配置（材质标志等）
 * - lightingFlags: 光照标志
 * - cameraShaderFlags: 相机着色器标志
 * - postProcessFlags: 后处理标志
 * - inputAssembly: 输入装配（图元拓扑）
 *
 * @return 组合哈希值
 */
inline uint64_t HashShaderDataAndSubmesh(const uint64_t shaderDataHash, const uint32_t renderHash,
    const IRenderDataStoreDefaultLight::LightingFlags lightingFlags, const RenderCamera::ShaderFlags& cameraShaderFlags,
    const PostProcessConfiguration::PostProcessEnableFlags postProcessFlags, const GraphicsState::InputAssembly& ia)
{
    const uint32_t ppEnabled = (postProcessFlags > 0);
    const uint64_t iaHash = uint32_t(ia.enablePrimitiveRestart) | (ia.primitiveTopology << 1U);

    // 组合所有标志到哈希中
    uint64_t hash = ((uint64_t)renderHash & RENDER_HASH_FLAGS_MASK) |
                    (((uint64_t)lightingFlags << LIGHTING_FLAGS_SHIFT) & LIGHTING_FLAGS_MASK) |
                    (((uint64_t)ppEnabled << POST_PROCESS_FLAGS_SHIFT) & POST_PROCESS_FLAGS_MASK) |
                    (((uint64_t)cameraShaderFlags << CAMERA_FLAGS_SHIFT) & CAMERA_FLAGS_MASK) |
                    (((uint64_t)iaHash << PRIMITIVE_TOPOLOGY_SHIFT) & PRIMITIVE_TOPOLOGY_MASK);
    HashCombine(hash, shaderDataHash);
    return hash;
}

/**
 * @brief 判断是否需要反转绕序
 *
 * 考虑场景和相机的绕序翻转设置，决定最终的绕序方向
 */
inline bool IsInverseWinding(const RenderSubmeshFlags submeshFlags, const RenderSceneFlags sceneRenderingFlags,
    const RenderCamera::Flags cameraRenderingFlags)
{
    const bool flipWinding = (sceneRenderingFlags & RENDER_SCENE_FLIP_WINDING_BIT) |
                             (cameraRenderingFlags & RenderCamera::CAMERA_FLAG_INVERSE_WINDING_BIT);
    const bool isNegative = flipWinding
                                ? !((submeshFlags & RenderSubmeshFlagBits::RENDER_SUBMESH_INVERSE_WINDING_BIT) > 0)
                                : ((submeshFlags & RenderSubmeshFlagBits::RENDER_SUBMESH_INVERSE_WINDING_BIT) > 0);
    return isNegative;
}

/**
 * @brief 绑定顶点缓冲区并执行绘制
 *
 * 支持以下绘制模式：
 * - 索引绘制 / 非索引绘制
 * - 直接绘制 / 间接绘制
 */
void BindVertextBufferAndDraw(IRenderCommandList& cmdList, const RenderSubmesh& currSubmesh)
{
    // 绑定顶点缓冲区
    if (currSubmesh.buffers.vertexBufferCount > 0U) {
        cmdList.BindVertexBuffers({ currSubmesh.buffers.vertexBuffers, currSubmesh.buffers.vertexBufferCount });
    }

    const auto& dc = currSubmesh.drawCommand;
    const VertexBuffer& iArgs = currSubmesh.buffers.indirectArgsBuffer;
    const bool indirectDraw = RenderHandleUtil::IsValid(iArgs.bufferHandle);

    // 根据是否有索引缓冲区选择绘制方式
    if ((currSubmesh.buffers.indexBuffer.byteSize > 0U) &&
        RenderHandleUtil::IsValid(currSubmesh.buffers.indexBuffer.bufferHandle)) {
        // 索引绘制
        cmdList.BindIndexBuffer(currSubmesh.buffers.indexBuffer);
        if (indirectDraw) {
            // 间接索引绘制（用于 GPU 驱动的裁剪等）
            cmdList.DrawIndexedIndirect(
                iArgs.bufferHandle, iArgs.bufferOffset, dc.drawCountIndirect, dc.strideIndirect);
        } else {
            // 直接索引绘制
            cmdList.DrawIndexed(dc.indexCount, dc.instanceCount, 0, 0, 0);
        }
    } else {
        // 非索引绘制
        if (indirectDraw) {
            cmdList.DrawIndirect(iArgs.bufferHandle, iArgs.bufferOffset, dc.drawCountIndirect, dc.strideIndirect);
        } else {
            cmdList.Draw(dc.vertexCount, dc.instanceCount, 0, 0);
        }
    }
}

/**
 * @brief 获取子网格材质标志
 *
 * 根据场景状态修改材质标志（如移除阴影接收标志）
 */
RenderDataDefaultMaterial::SubmeshMaterialFlags GetSubmeshMaterialFlags(
    const RenderDataDefaultMaterial::SubmeshMaterialFlags& submeshMaterialFlags,
    const IRenderDataStoreDefaultMaterial& dataStoreMaterial, const bool instanced, const bool hasShadows)
{
    RenderDataDefaultMaterial::SubmeshMaterialFlags materialFlags = submeshMaterialFlags;

    // 如果场景中没有阴影，移除阴影接收标志
    if (!hasShadows) {
        materialFlags.renderMaterialFlags &= (~RenderMaterialFlagBits::RENDER_MATERIAL_SHADOW_RECEIVER_BIT);
        materialFlags.renderHash = dataStoreMaterial.GenerateRenderHash(materialFlags);
    }
    return materialFlags;
}

/**
 * @brief 获取帧全局 Descriptor Sets
 *
 * 获取 Shader 需要的所有全局资源：
 * - Set 0: 相机相关数据（每相机）
 * - Set 1: 网格/材质数据（动态偏移）
 * - Set 2: 材质纹理资源（每材质）
 * - Set 2Default: 默认材质资源
 *
 * 这些 Descriptor Sets 由 RenderNodeDefaultCameraController 创建
 */
RenderNodeDefaultMaterialRenderSlot::FrameGlobalDescriptorSets GetFrameGlobalDescriptorSets(
    IRenderNodeContextManager* rncm, const SceneRenderDataStores& stores, const string& cameraName)
{
    RenderNodeDefaultMaterialRenderSlot::FrameGlobalDescriptorSets fgds;
    if (rncm) {
        // 每帧重新获取全局 Descriptor Sets
        const INodeContextDescriptorSetManager& dsMgr = rncm->GetDescriptorSetManager();
        const string_view us = stores.dataStoreNameScene;

        // Set 0: 相机数据（每相机一个）
        fgds.set0 = dsMgr.GetGlobalDescriptorSet(
            us + DefaultMaterialMaterialConstants::MATERIAL_SET0_GLOBAL_DESCRIPTOR_SET_PREFIX_NAME + cameraName);

        // Set 1: 网格矩阵和材质数据
        fgds.set1 = dsMgr.GetGlobalDescriptorSet(
            us + DefaultMaterialMaterialConstants::MATERIAL_SET1_GLOBAL_DESCRIPTOR_SET_NAME);

        // Set 2: 材质纹理资源（每个材质一个）
        fgds.set2 = dsMgr.GetGlobalDescriptorSets(
            us + DefaultMaterialMaterialConstants::MATERIAL_RESOURCES_GLOBAL_DESCRIPTOR_SET_NAME);

        // Set 2 默认资源（用于无效材质索引）
        fgds.set2Default = dsMgr.GetGlobalDescriptorSet(
            us + DefaultMaterialMaterialConstants::MATERIAL_DEFAULT_RESOURCE_GLOBAL_DESCRIPTOR_SET_NAME);

#if (CORE3D_VALIDATION_ENABLED == 1)
        if (fgds.set2.empty()) {
            CORE_LOG_ONCE_W("core3d_global_descriptor_set_render_slot_issues",
                "CORE3D_VALIDATION: Global descriptor set for default material env not found");
        }
#endif

        // 验证必需的 Descriptor Sets 是否有效
        fgds.valid = RenderHandleUtil::IsValid(fgds.set0) && RenderHandleUtil::IsValid(fgds.set1) &&
                     RenderHandleUtil::IsValid(fgds.set2Default);
        if (!fgds.valid) {
            CORE_LOG_ONCE_E("core3d_global_descriptor_set_rs_all_issues",
                "Global descriptor set 0/1/2 for default material not "
                "found (RenderNodeDefaultCameraController needed)");
        }
    }
    return fgds;
}
} // namespace

/**
 * @brief 初始化节点 - 解析配置，创建默认 Shader 数据
 *
 * 步骤：
 * 1. 解析 JSON 输入配置
 * 2. 获取场景数据存储名称
 * 3. 创建渲染通道
 * 4. 创建默认 Shader 数据
 * 5. 获取默认采样器
 */
void RenderNodeDefaultMaterialRenderSlot::InitNode(IRenderNodeContextManager& renderNodeContextMgr)
{
    // 保存上下文管理器引用
    renderNodeContextMgr_ = &renderNodeContextMgr;

    // 解析 JSON 配置
    ParseRenderNodeInputs();

    // 获取场景渲染数据存储名称
    const auto& renderNodeGraphData = renderNodeContextMgr_->GetRenderNodeGraphData();
    stores_ = RenderNodeSceneUtil::GetSceneRenderDataStores(
        renderNodeContextMgr, renderNodeGraphData.renderNodeGraphDataStoreName);

    // 初始化状态
    currentScene_ = {};
    allShaderData_ = {};

    // 检查后处理配置
    if ((jsonInputs_.nodeFlags & RenderSceneFlagBits::RENDER_SCENE_DIRECT_POST_PROCESS_BIT) &&
        jsonInputs_.renderDataStore.dataStoreName.empty()) {
        CORE_LOG_V("%s: render data store post process configuration not set in render node graph",
            renderNodeContextMgr_->GetName().data());
    }

    // 创建渲染通道
    rngRenderPass_ = renderNodeContextMgr_->GetRenderNodeUtil().CreateRenderPass(inputRenderPass_);

    // 创建默认 Shader 数据（Shader、Pipeline Layout、特化常量）
    CreateDefaultShaderData();

    // 获取默认采样器
    auto& gpuResourceMgr = renderNodeContextMgr.GetGpuResourceManager();
    defaultSamplers_.cubemapHandle =
        gpuResourceMgr.GetSamplerHandle(DefaultMaterialGpuResourceConstants::CORE_DEFAULT_RADIANCE_CUBEMAP_SAMPLER);
    defaultSamplers_.linearHandle = gpuResourceMgr.GetSamplerHandle("CORE_DEFAULT_SAMPLER_LINEAR_CLAMP");
    defaultSamplers_.nearestHandle = gpuResourceMgr.GetSamplerHandle("CORE_DEFAULT_SAMPLER_NEAREST_CLAMP");
    defaultSamplers_.linearMipHandle = gpuResourceMgr.GetSamplerHandle("CORE_DEFAULT_SAMPLER_LINEAR_MIPMAP_CLAMP");
    defaultColorPrePassHandle_ = gpuResourceMgr.GetImageHandle("CORE_DEFAULT_GPU_IMAGE");
}

/**
 * @brief 前帧预处理
 *
 * 当前为空实现。
 * 可用于：
 * - 重新创建所需的 GPU 资源
 * - 预加载材质数据
 * - 准备实例化缓冲区
 */
void RenderNodeDefaultMaterialRenderSlot::PreExecuteFrame()
{
    // re-create needed gpu resources
}

/**
 * @brief 执行帧 - 渲染所有子网格
 *
 * 核心流程：
 * 1. 获取所有 DataStore
 * 2. 更新当前场景状态
 * 3. 开始 RenderPass
 * 4. 处理子网格列表（排序、裁剪）
 * 5. 渲染子网格
 * 6. 结束 RenderPass
 */
void RenderNodeDefaultMaterialRenderSlot::ExecuteFrame(IRenderCommandList& cmdList)
{
    // ========== 获取 DataStore ==========
    const auto& renderDataStoreMgr = renderNodeContextMgr_->GetRenderDataStoreManager();
    const auto* dataStoreScene =
        static_cast<IRenderDataStoreDefaultScene*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameScene));
    const auto* dataStoreMaterial = static_cast<IRenderDataStoreDefaultMaterial*>(
        renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameMaterial));
    const auto* dataStoreCamera =
        static_cast<IRenderDataStoreDefaultCamera*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameCamera));
    const auto* dataStoreLight =
        static_cast<IRenderDataStoreDefaultLight*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameLight));

    const bool validRenderDataStore = dataStoreScene && dataStoreMaterial && dataStoreCamera && dataStoreLight;

    // 更新当前场景状态
    if (validRenderDataStore) {
        UpdateCurrentScene(*dataStoreScene, *dataStoreCamera, *dataStoreLight);
    } else {
        CORE_LOG_E("invalid render data stores in RenderNodeDefaultMaterialRenderSlot");
    }

    // ========== 开始 RenderPass ==========
#if (CORE3D_VALIDATION_ENABLED == 1)
    RENDER_DEBUG_MARKER_COL_SCOPE(
        cmdList, "3DMaterial" + jsonInputs_.renderSlotName, DefaultDebugConstants::DEFAULT_DEBUG_COLOR);
#else
    RENDER_DEBUG_MARKER_COL_SCOPE(cmdList, "3DMaterial", DefaultDebugConstants::DEFAULT_DEBUG_COLOR);
#endif

    cmdList.BeginRenderPass(renderPass_.renderPassDesc, renderPass_.subpassStartIndex, renderPass_.subpassDesc);

    // ========== 渲染子网格 ==========
    if (validRenderDataStore) {
        const auto cameras = dataStoreCamera->GetCameras();
        const auto scene = dataStoreScene->GetScene();

        const bool hasShaders = allShaderData_.slotHasShaders;
        const bool hasCamera =
            (!cameras.empty() && (currentScene_.cameraIdx < (uint32_t)cameras.size())) ? true : false;

        // 处理子网格列表（排序、裁剪）
        ProcessSlotSubmeshes(*dataStoreCamera, *dataStoreMaterial);
        const bool hasSubmeshes = (!sortedSlotSubmeshes_.empty());

        if (hasShaders && hasCamera && hasSubmeshes) {
            // 更新后处理配置
            UpdatePostProcessConfiguration();
            // 渲染所有子网格
            RenderSubmeshes(cmdList, *dataStoreMaterial, *dataStoreCamera);
        }
    }

    // ========== 结束 RenderPass ==========
    cmdList.EndRenderPass();
}

/**
 * @brief 渲染子网格 - 遍历并绘制所有可见的子网格
 *
 * 步骤：
 * 1. 获取全局 Descriptor Sets
 * 2. 设置动态状态（视口、裁剪区域）
 * 3. 遍历排序后的子网格列表
 * 4. 对每个子网格：
 *    - 检查层遮罩和场景 ID
 *    - 绑定 Pipeline (PSO)
 *    - 绑定 Set 1 和 Set 2（网格、材质数据）
 *    - 绑定 Set 3（自定义资源，可选）
 *    - 执行绘制
 *
 * @param cmdList 渲染命令列表
 * @param dataStoreMaterial 材质 DataStore
 * @param dataStoreCamera 相机 DataStore
 */
void RenderNodeDefaultMaterialRenderSlot::RenderSubmeshes(IRenderCommandList& cmdList,
    const IRenderDataStoreDefaultMaterial& dataStoreMaterial, const IRenderDataStoreDefaultCamera& dataStoreCamera)
{
    // 获取全局 Descriptor Sets（每帧重新获取）
    const FrameGlobalDescriptorSets fgds = GetFrameGlobalDescriptorSets(renderNodeContextMgr_, stores_, cameraName_);
    if (!fgds.valid) {
        return; // 无法继续渲染
    }

    // 设置动态状态
    cmdList.SetDynamicStateViewport(currentScene_.viewportDesc);
    cmdList.SetDynamicStateScissor(currentScene_.scissorDesc);
    if (fsrEnabled_) {
        cmdList.SetDynamicStateFragmentShadingRate(
            { 1u, 1u }, FragmentShadingRateCombinerOps { CORE_FRAGMENT_SHADING_RATE_COMBINER_OP_REPLACE,
                            CORE_FRAGMENT_SHADING_RATE_COMBINER_OP_REPLACE });
    }

    // 渲染状态
    PipelineInfo pipelineInfo;
    uint32_t currMaterialIndex = ~0u;      // 当前绑定的材质索引
    bool initialBindDone = false;          // 是否已完成首次绑定

    // 获取子网格数据
    const auto& submeshMaterialFlags = dataStoreMaterial.GetSubmeshMaterialFlags();
    const auto& submeshes = dataStoreMaterial.GetSubmeshes();
    const auto& customResourceHandles = dataStoreMaterial.GetCustomResourceHandles();
    const uint64_t camLayerMask = currentScene_.camera.layerMask;
    const uint64_t camScene = currentScene_.camera.sceneId;

    // ========== 遍历排序后的子网格列表 ==========
    for (const auto& ssp : sortedSlotSubmeshes_) {
        const uint32_t submeshIndex = ssp.submeshIndex;
        const auto& currSubmesh = submeshes[submeshIndex];

        // 检查场景 ID 是否匹配
        if (currSubmesh.layers.sceneId != camScene) {
            continue;
        }

        // 检查层遮罩是否有交集
        if (((camLayerMask & currSubmesh.layers.layerMask) == 0U) ||
            ((jsonInputs_.nodeFlags & RENDER_SCENE_DISCARD_MATERIAL_BIT) &&
                (submeshMaterialFlags[submeshIndex].extraMaterialRenderingFlags &
                    RenderExtraRenderingFlagBits::RENDER_EXTRA_RENDERING_DISCARD_BIT))) {
            continue;
        }

        // 获取材质标志
        const auto materialSubmeshFlags = GetSubmeshMaterialFlags(submeshMaterialFlags[submeshIndex], dataStoreMaterial,
            (currSubmesh.drawCommand.instanceCount > 1U), currentScene_.hasShadow);
        const RenderSubmeshFlags submeshFlags = currSubmesh.submeshFlags | jsonInputs_.nodeSubmeshExtraFlags;

        // ========== 绑定 Pipeline ==========
        BindPipeline(cmdList, ssp, materialSubmeshFlags, submeshFlags, currSubmesh.buffers.inputAssembly, pipelineInfo);

        // 首次绑定 Set 0（全局数据）
        if (!initialBindDone) {
            cmdList.BindDescriptorSet(0, fgds.set0);
        }

        // ========== 绑定 Set 1 和 Set 2 ==========
        currMaterialIndex = BindSet1And2(cmdList, currSubmesh, submeshFlags, initialBindDone, fgds, currMaterialIndex);
        initialBindDone = true;

        // ========== 绑定 Set 3（自定义资源） ==========
        if (pipelineInfo.boundCustomSetNeed) {
            // 检查是否有自定义资源
            if ((currSubmesh.indices.materialIndex >= static_cast<uint32_t>(customResourceHandles.size())) ||
                (customResourceHandles[currSubmesh.indices.materialIndex].resourceHandleCount == 0U) ||
                !UpdateAndBindSet3(cmdList, customResourceHandles[currSubmesh.indices.materialIndex])) {
#if (CORE3D_VALIDATION_ENABLED == 1)
                CORE_LOG_ONCE_W("material_render_slot_custom_set3_issue",
                    "invalid bindings with custom shader descriptor set 3 (render node: %s)",
                    renderNodeContextMgr_->GetName().data());
#endif
                continue; // 跳过此子网格
            }
        }

        // ========== 执行绘制 ==========
        BindVertextBufferAndDraw(cmdList, currSubmesh);
    }
}

/**
 * @brief 绑定 Pipeline - 根据子网格配置获取或创建 PSO
 *
 * PSO 选择基于：
 * - Shader 句柄
 * - Graphics State 句柄
 * - 材质标志
 * - 光照标志
 * - 相机标志
 * - 输入装配（图元拓扑）
 *
 * 使用哈希缓存已创建的 PSO，避免重复创建
 */
void RenderNodeDefaultMaterialRenderSlot::BindPipeline(IRenderCommandList& cmdList, const SlotSubmeshIndex& ssp,
    const RenderDataDefaultMaterial::SubmeshMaterialFlags& renderSubmeshMaterialFlags,
    const RenderSubmeshFlags submeshFlags, const GraphicsState::InputAssembly& inputAssembly,
    PipelineInfo& pipelineInfo)
{
    // 构建 Shader 状态数据
    ShaderStateData ssd { ssp.shaderHandle, ssp.gfxStateHandle, 0 };
    ssd.hash = (ssd.shader.id << 32U) | (ssd.gfxState.id & 0xFFFFffff);

    // 计算组合哈希（包含材质、光照、相机标志等）
    ssd.hash = HashShaderDataAndSubmesh(ssd.hash, renderSubmeshMaterialFlags.renderHash, currentScene_.lightingFlags,
        currentScene_.cameraShaderFlags, currentRenderPPConfiguration_.flags.x, inputAssembly);

    // 检查是否需要切换 PSO
    if (ssd.hash != pipelineInfo.boundShaderHash) {
        // 获取或创建 PSO
        const PsoAndInfo psoAndInfo = GetSubmeshPso(ssd, inputAssembly, renderSubmeshMaterialFlags, submeshFlags,
            currentScene_.lightingFlags, currentScene_.cameraShaderFlags);

        // 如果 PSO 改变，重新绑定
        if (psoAndInfo.pso != pipelineInfo.boundPsoHandle) {
            pipelineInfo.boundShaderHash = ssd.hash;
            pipelineInfo.boundPsoHandle = psoAndInfo.pso;
            cmdList.BindPipeline(pipelineInfo.boundPsoHandle);
            pipelineInfo.boundCustomSetNeed = psoAndInfo.set3;
        }
    }
}

/**
 * @brief 绑定 Set 1 和 Set 2 - 网格矩阵和材质数据
 *
 * Set 1 使用动态偏移来高效切换每物体数据：
 * - Binding 0: Mesh Matrix（世界矩阵、上一帧矩阵）
 * - Binding 1: Skin Joint（骨骼关节矩阵）
 * - Binding 2-4: Material Data（材质因子、用户数据）
 *
 * Set 2 是每材质的纹理资源
 *
 * @return 当前绑定的材质索引
 */
uint32_t RenderNodeDefaultMaterialRenderSlot::BindSet1And2(IRenderCommandList& cmdList,
    const RenderSubmesh& currSubmesh, const RenderSubmeshFlags submeshFlags, const bool initialBindDone,
    const FrameGlobalDescriptorSets& fgds, uint32_t currMaterialIndex)

{
    // ========== 计算动态偏移 ==========
    // Set 1 使用动态偏移，每个绑定有不同的偏移

    // 材质帧偏移（用于材质数据）
    const uint32_t currMatOffset = currSubmesh.indices.materialFrameOffset * UBO_BIND_OFFSET_ALIGNMENT;

    // 动态偏移数组：
    // [0] Mesh Matrix 偏移
    // [1] Skin Joint 偏移
    // [2] Material 偏移
    // [3] Material User Data 偏移
    // [4] Material User Data 2 偏移
    const uint32_t dynamicOffsets[] = { currSubmesh.indices.meshIndex * UBO_BIND_OFFSET_ALIGNMENT,
        (submeshFlags & RenderSubmeshFlagBits::RENDER_SUBMESH_SKIN_BIT)
            ? currSubmesh.indices.skinJointIndex * static_cast<uint32_t>(sizeof(DefaultMaterialSkinStruct))
            : 0U,
        currMatOffset, currMatOffset, currMatOffset };

    // ========== 准备绑定数据 ==========
    IRenderCommandList::BindDescriptorSetData bindSets[2U] {};
    uint32_t bindSetCount = 0U;

    // Set 1: Mesh/Material 数据（带动态偏移）
    bindSets[bindSetCount++] = { fgds.set1, dynamicOffsets };

    // Set 2: 材质纹理资源（仅在材质改变时绑定）
    if ((!initialBindDone) || (currMaterialIndex != currSubmesh.indices.materialIndex)) {
        currMaterialIndex = currSubmesh.indices.materialIndex;

        // 获取当前材质的 Set 2 句柄
        const RenderHandle set2Handle =
            (currMaterialIndex < fgds.set2.size()) ? fgds.set2[currMaterialIndex] : fgds.set2Default;
        bindSets[bindSetCount++] = { set2Handle, {} };
    }

    // 绑定 Set 1 和可能的 Set 2
    cmdList.BindDescriptorSets(1U, { bindSets, bindSetCount });
    return currMaterialIndex;
}

/**
 * @brief 更新并绑定 Set 3 - 自定义资源
 *
 * 当材质使用自定义 Shader 时，需要绑定用户自定义的资源。
 * 资源可以是：Buffer、Image、Sampler
 *
 * @param cmdList 渲染命令列表
 * @param customResourceData 自定义资源数据
 * @return 是否成功绑定
 */
bool RenderNodeDefaultMaterialRenderSlot::UpdateAndBindSet3(
    IRenderCommandList& cmdList, const RenderDataDefaultMaterial::CustomResourceData& customResourceData)
{
    IRenderNodeGpuResourceManager& gpuResourceMgr = renderNodeContextMgr_->GetGpuResourceManager();
    INodeContextDescriptorSetManager& descriptorSetMgr = renderNodeContextMgr_->GetDescriptorSetManager();
    const IRenderNodeShaderManager& shaderMgr = renderNodeContextMgr_->GetShaderManager();

    // 获取 Pipeline Layout
    // 如果默认 Pipeline Layout 有 Set 3，使用默认的
    // 否则从自定义 Shader 获取
    RenderHandle currPlHandle = allShaderData_.defaultPlSet3
                                    ? allShaderData_.defaultPlHandle
                                    : shaderMgr.GetPipelineLayoutHandleByShaderHandle(customResourceData.shaderHandle);
    if (!RenderHandleUtil::IsValid(currPlHandle)) {
        currPlHandle = shaderMgr.GetReflectionPipelineLayoutHandle(customResourceData.shaderHandle);
    }

    const PipelineLayout& plRef = shaderMgr.GetPipelineLayout(currPlHandle);

    // 检查 Set 3 是否有绑定
    if (plRef.descriptorSetLayouts[FIXED_CUSTOM_SET3].bindings.empty()) {
        return false; // 不需要 Set 3
    }

    const auto& descBindings = plRef.descriptorSetLayouts[FIXED_CUSTOM_SET3].bindings;

    // 创建单帧 Descriptor Set
    const RenderHandle descSetHandle = descriptorSetMgr.CreateOneFrameDescriptorSet(descBindings);
    if (!RenderHandleUtil::IsValid(descSetHandle) || (descBindings.size() != customResourceData.resourceHandleCount)) {
        return false;
    }

    // 创建 Descriptor Set Binder
    IDescriptorSetBinder::Ptr binderPtr = descriptorSetMgr.CreateDescriptorSetBinder(descSetHandle, descBindings);
    if (!binderPtr) {
        return false;
    }

    auto& binder = *binderPtr;

    // 根据资源类型绑定
    for (uint32_t idx = 0; idx < customResourceData.resourceHandleCount; ++idx) {
        CORE_ASSERT(idx < descBindings.size());
        const RenderHandle& currRes = customResourceData.resourceHandles[idx];

        if (gpuResourceMgr.IsGpuBuffer(currRes)) {
            // Buffer 资源
            binder.BindBuffer(idx, currRes, 0);
        } else if (gpuResourceMgr.IsGpuImage(currRes)) {
            // Image 资源
            if (descBindings[idx].descriptorType == DescriptorType::CORE_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER) {
                // 需要采样器的 Image
                binder.BindImage(idx, currRes, defaultSamplers_.linearMipHandle);
            } else {
                // 纯 Image
                binder.BindImage(idx, currRes);
            }
        } else if (gpuResourceMgr.IsGpuSampler(currRes)) {
            // Sampler 资源
            binder.BindSampler(idx, currRes);
        }
    }

    // 检查绑定有效性
    if (!binder.GetDescriptorSetLayoutBindingValidity()) {
        return false;
    }

    // 更新并绑定 Descriptor Set
    cmdList.UpdateDescriptorSet(binder.GetDescriptorSetHandle(), binder.GetDescriptorSetLayoutBindingResources());
    cmdList.BindDescriptorSet(FIXED_CUSTOM_SET3, binder.GetDescriptorSetHandle());
    return true;
}

/**
 * @brief 获取子网格的 PSO (Pipeline State Object)
 *
 * 从 PSO 缓存中查找匹配的 PSO，如果没有找到则创建新的 PSO。
 *
 * PSO 缓存机制：
 * - 使用 shaderIdToData 映射存储哈希到 PSO 索引
 * - perShaderData 存储每个 Shader 的 PSO 数据
 *
 * @param ssd Shader State Data（包含 Shader 和 Graphics State 句柄及哈希）
 * @param ia Input Assembly（图元拓扑和索引类型）
 * @param submeshMaterialFlags 子网格材质标志
 * @param submeshFlags 子网格标志（骨骼、切线等）
 * @param lightingFlags 光照标志
 * @param cameraShaderFlags 相机 Shader 标志
 * @return PSO 句柄和是否需要 Set 3 的信息
 */
RenderNodeDefaultMaterialRenderSlot::PsoAndInfo RenderNodeDefaultMaterialRenderSlot::GetSubmeshPso(
    const ShaderStateData& ssd, const GraphicsState::InputAssembly& ia,
    const RenderDataDefaultMaterial::SubmeshMaterialFlags& submeshMaterialFlags, const RenderSubmeshFlags submeshFlags,
    const IRenderDataStoreDefaultLight::LightingFlags lightingFlags, const RenderCamera::ShaderFlags cameraShaderFlags)
{
    // ========== 1. 查找 PSO 缓存 ==========
    // 使用 Shader State Data 的哈希查找缓存
    if (const auto dataIter = allShaderData_.shaderIdToData.find(ssd.hash);
        dataIter != allShaderData_.shaderIdToData.cend()) {
        // 缓存命中：返回已有的 PSO
        const auto& ref = allShaderData_.perShaderData[dataIter->second];
        return { ref.psoHandle, ref.needsCustomSetBindings };
    }

    // ========== 2. 创建新 PSO ==========
    // 缓存未命中：创建新的 PSO 并缓存
    return CreateNewPso(ssd, ia, submeshMaterialFlags, submeshFlags, lightingFlags, cameraShaderFlags);
}

/**
 * @brief 更新后处理配置
 *
 * 当节点启用了 RENDER_SCENE_DIRECT_POST_PROCESS_BIT 时，
 * 从 RenderDataStorePod 中读取 PostProcessConfiguration。
 *
 * 配置用于：
 * - 设置特化常量中的 POST_PROCESS_FLAGS
 * - 控制后处理效果的行为
 *
 * 典型用法：在阴影渲染节点中禁用某些后处理
 */
void RenderNodeDefaultMaterialRenderSlot::UpdatePostProcessConfiguration()
{
    // 检查是否启用了直接后处理标志
    if (jsonInputs_.nodeFlags & RenderSceneFlagBits::RENDER_SCENE_DIRECT_POST_PROCESS_BIT) {
        if (!jsonInputs_.renderDataStore.dataStoreName.empty()) {
            auto const& dsMgr = renderNodeContextMgr_->GetRenderDataStoreManager();
            if (const IRenderDataStore* ds = dsMgr.GetRenderDataStore(jsonInputs_.renderDataStore.dataStoreName); ds) {
                // 检查数据存储类型是否为 PostProcess
                if (jsonInputs_.renderDataStore.typeName == POST_PROCESS_DATA_STORE_TYPE_NAME) {
                    auto const dataStore = static_cast<const IRenderDataStorePod*>(ds);
                    // 获取配置数据
                    auto const dataView = dataStore->Get(jsonInputs_.renderDataStore.configurationName);
                    if (dataView.data() && (dataView.size_bytes() == sizeof(PostProcessConfiguration))) {
                        const PostProcessConfiguration* data = (const PostProcessConfiguration*)dataView.data();
                        // 转换为渲染后处理配置
                        currentRenderPPConfiguration_ =
                            renderNodeContextMgr_->GetRenderNodeUtil().GetRenderPostProcessConfiguration(*data);
                        // 只保留重要标志位
                        currentRenderPPConfiguration_.flags.x =
                            (currentRenderPPConfiguration_.flags.x & POST_PROCESS_IMPORTANT_FLAGS_MASK);
                    }
                }
            }
        }
    }
}

/**
 * @brief 更新当前场景状态
 *
 * 每帧执行前调用，更新当前场景的相机、视口、灯光等信息。
 *
 * 步骤：
 * 1. 更新 RenderPass（如果有可变句柄）
 * 2. 获取当前相机（场景相机或自定义相机）
 * 3. 获取环境贴图句柄
 * 4. 设置视口和裁剪区域
 * 5. 获取灯光信息（阴影类型、光照标志）
 * 6. 根据多视图模式重置渲染槽位
 *
 * @param dataStoreScene 场景数据存储
 * @param dataStoreCamera 相机数据存储
 * @param dataStoreLight 灯光数据存储
 */
void RenderNodeDefaultMaterialRenderSlot::UpdateCurrentScene(const IRenderDataStoreDefaultScene& dataStoreScene,
    const IRenderDataStoreDefaultCamera& dataStoreCamera, const IRenderDataStoreDefaultLight& dataStoreLight)
{
    // ========== 1. 更新 RenderPass ==========
    // 如果有可变的 RenderPass 句柄，重新创建
    if (jsonInputs_.hasChangeableRenderPassHandles) {
        const auto& renderNodeUtil = renderNodeContextMgr_->GetRenderNodeUtil();
        inputRenderPass_ = renderNodeUtil.CreateInputRenderPass(jsonInputs_.renderPass);
        rngRenderPass_ = renderNodeContextMgr_->GetRenderNodeUtil().CreateRenderPass(inputRenderPass_);
    }
    // 获取默认 RNG 基础的 RenderPass 设置
    renderPass_ = rngRenderPass_;

    // ========== 2. 获取当前相机 ==========
    const auto scene = dataStoreScene.GetScene();
    bool hasCustomCamera = false;
    bool isNamedCamera = false; // NOTE: legacy support will be removed
    uint32_t cameraIdx = scene.cameraIndex;

    // 检查是否指定了自定义相机
    if (jsonInputs_.customCameraId != INVALID_CAM_ID) {
        cameraIdx = dataStoreCamera.GetCameraIndex(jsonInputs_.customCameraId);
        hasCustomCamera = true;
    } else if (!(jsonInputs_.customCameraName.empty())) {
        cameraIdx = dataStoreCamera.GetCameraIndex(jsonInputs_.customCameraName);
        hasCustomCamera = true;
        isNamedCamera = true;
    }

    // 存储当前帧相机
    if (const auto cameras = dataStoreCamera.GetCameras(); cameraIdx < (uint32_t)cameras.size()) {
        currentScene_.camera = cameras[cameraIdx];
    }

    // ========== 3. 获取环境贴图句柄 ==========
    const auto camHandles = RenderNodeSceneUtil::GetSceneCameraImageHandles(
        *renderNodeContextMgr_, stores_.dataStoreNameScene, currentScene_.camera.name, currentScene_.camera);
    currentScene_.cameraEnvRadianceHandle = camHandles.radianceCubemap;

    // 获取预处理颜色目标（如果有）
    if (!currentScene_.camera.prePassColorTargetName.empty()) {
        currentScene_.prePassColorTarget =
            renderNodeContextMgr_->GetGpuResourceManager().GetImageHandle(currentScene_.camera.prePassColorTargetName);
    }

    // ========== 4. 更新 RenderPass 的 LoadOp ==========
    // renderpass needs to be valid (created in init)
    if (hasCustomCamera) {
        // 使用自定义相机时，可能覆盖 LoadOp
        RenderNodeSceneUtil::UpdateRenderPassFromCustomCamera(currentScene_.camera, isNamedCamera, renderPass_);
    } else {
        RenderNodeSceneUtil::UpdateRenderPassFromCamera(currentScene_.camera, renderPass_);
    }

    // 设置视口和裁剪区域
    currentScene_.viewportDesc = RenderNodeSceneUtil::CreateViewportFromCamera(currentScene_.camera);
    currentScene_.scissorDesc = RenderNodeSceneUtil::CreateScissorFromCamera(currentScene_.camera);

    // ========== 5. 获取灯光信息 ==========
    const IRenderDataStoreDefaultLight::LightCounts lightCounts = dataStoreLight.GetLightCounts();
    currentScene_.hasShadow = (lightCounts.shadowCount > 0) ? true : false;
    currentScene_.cameraIdx = cameraIdx;
    currentScene_.shadowTypes = dataStoreLight.GetShadowTypes();
    currentScene_.lightingFlags = dataStoreLight.GetLightingFlags();
    currentScene_.cameraShaderFlags = currentScene_.camera.shaderFlags;

    // ========== 6. 处理雾效标志 ==========
    // 如果节点配置禁用雾效，清除雾效标志
    if (jsonInputs_.nodeFlags & RenderSceneFlagBits::RENDER_SCENE_DISABLE_FOG_BIT) {
        currentScene_.cameraShaderFlags &= (~RenderCamera::ShaderFlagBits::CAMERA_SHADER_FOG_BIT);
    }

    // ========== 7. 处理多视图 ==========
    GetMultiViewCameraIndices(dataStoreCamera, currentScene_.camera, currentScene_.mvCameraIndices);

    // 根据多视图模式重置渲染槽位数据
    if (renderPass_.subpassDesc.viewMask > 1U) {
        // 多视图模式：使用多视图渲染槽位
        ResetRenderSlotData(jsonInputs_.shaderRenderSlotMultiviewId, true);
    } else {
        // 单视图模式：使用基础渲染槽位
        ResetRenderSlotData(jsonInputs_.shaderRenderSlotBaseId, false);
    }
}

/**
 * @brief 创建默认 Shader 数据
 *
 * 从渲染槽位获取默认的：
 * - Shader 句柄
 * - Graphics State 句柄
 * - Pipeline Layout
 * - Vertex Input Declaration
 * - 特化常量
 *
 * 这些默认值用于没有自定义 Shader 的材质
 */
void RenderNodeDefaultMaterialRenderSlot::CreateDefaultShaderData()
{
    allShaderData_ = {};

    const auto& shaderMgr = renderNodeContextMgr_->GetShaderManager();

    // 获取渲染槽位的默认 Shader 和 Graphics State
    const IShaderManager::RenderSlotData shaderRsd = shaderMgr.GetRenderSlotData(jsonInputs_.shaderRenderSlotId);
    allShaderData_.defaultShaderHandle = shaderRsd.shader.GetHandle();
    allShaderData_.defaultStateHandle = shaderRsd.graphicsState.GetHandle();

    // 获取默认 Pipeline Layout
    allShaderData_.defaultPlHandle =
        (shaderRsd.pipelineLayout)
            ? shaderRsd.pipelineLayout.GetHandle()
            : shaderMgr.GetPipelineLayoutHandle(DefaultMaterialShaderConstants::PIPELINE_LAYOUT_FORWARD);
    allShaderData_.defaultPipelineLayout = shaderMgr.GetPipelineLayout(allShaderData_.defaultPlHandle);
    allShaderData_.defaultTmpPipelineLayout = allShaderData_.defaultPipelineLayout;

    // 获取默认 Vertex Input Declaration
    allShaderData_.defaultVidHandle = (shaderRsd.vertexInputDeclaration)
                                          ? shaderRsd.vertexInputDeclaration.GetHandle()
                                          : shaderMgr.GetVertexInputDeclarationHandle(
                                                DefaultMaterialShaderConstants::VERTEX_INPUT_DECLARATION_FORWARD);

    // 检查默认 Pipeline Layout 是否有 Set 3
    if (!allShaderData_.defaultPipelineLayout.descriptorSetLayouts[FIXED_CUSTOM_SET3].bindings.empty()) {
        allShaderData_.defaultPlSet3 = true;
    }

    // 获取特化常量
    if (shaderMgr.IsShader(allShaderData_.defaultShaderHandle)) {
        allShaderData_.slotHasShaders = true;
        const ShaderSpecializationConstantView& sscv =
            shaderMgr.GetReflectionSpecialization(allShaderData_.defaultShaderHandle);
        allShaderData_.defaultSpecilizationConstants.resize(sscv.constants.size());
        for (uint32_t idx = 0; idx < (uint32_t)allShaderData_.defaultSpecilizationConstants.size(); ++idx) {
            allShaderData_.defaultSpecilizationConstants[idx] = sscv.constants[idx];
        }
        specializationData_.maxSpecializationCount =
            Math::min(static_cast<uint32_t>(allShaderData_.defaultSpecilizationConstants.size()),
                SpecializationData::MAX_FLAG_COUNT);
    } else {
        CORE_LOG_I("RenderNode: %s, no default shaders for render slot id %u", renderNodeContextMgr_->GetName().data(),
            jsonInputs_.shaderRenderSlotId);
    }

    // 如果状态槽位与 Shader 槽位不同，获取状态槽位的 Graphics State
    if (jsonInputs_.shaderRenderSlotId != jsonInputs_.stateRenderSlotId) {
        const IShaderManager::RenderSlotData stateRsd = shaderMgr.GetRenderSlotData(jsonInputs_.stateRenderSlotId);
        if (stateRsd.graphicsState) {
            allShaderData_.defaultStateHandle = stateRsd.graphicsState.GetHandle();
        } else {
            CORE_LOG_I("RenderNode: %s, no default state for render slot id %u",
                renderNodeContextMgr_->GetName().data(), jsonInputs_.stateRenderSlotId);
        }
    }
}

namespace {
// updates graphics state based on params
inline GraphicsState GetNewGraphicsState(const IRenderNodeShaderManager& shaderMgr, const RenderHandle& handle,
    const bool inverseWinding, const bool customInputAssembly, const GraphicsState::InputAssembly& ia)
{
    // we create a new graphics state based on current
    GraphicsState gfxState = shaderMgr.GetGraphicsState(handle);
    // update state
    if (inverseWinding) {
        gfxState.rasterizationState.frontFace = FrontFace::CORE_FRONT_FACE_CLOCKWISE;
    }
    if (customInputAssembly) {
        gfxState.inputAssembly = ia;
    }
    return gfxState;
}
} // namespace

/**
 * @brief 创建新的 PSO
 *
 * 当 PSO 缓存中找不到匹配的 PSO 时，创建新的 PSO。
 *
 * 步骤：
 * 1. 确定 Shader 句柄（自定义或默认）
 * 2. 确定 Graphics State 句柄
 * 3. 获取 Pipeline Layout
 * 4. 计算特化常量
 * 5. 获取或创建 PSO
 * 6. 缓存 PSO
 *
 * @return PSO 句柄和是否需要 Set 3
 */
RenderNodeDefaultMaterialRenderSlot::PsoAndInfo RenderNodeDefaultMaterialRenderSlot::CreateNewPso(
    const ShaderStateData& ssd, const GraphicsState::InputAssembly& ia,
    const RenderDataDefaultMaterial::SubmeshMaterialFlags& submeshMatFlags, const RenderSubmeshFlags submeshFlags,
    const IRenderDataStoreDefaultLight::LightingFlags lightingFlags, const RenderCamera::ShaderFlags camShaderFlags)
{
    const auto& shaderMgr = renderNodeContextMgr_->GetShaderManager();

    RenderHandle currShader;
    RenderHandle currVid;
    RenderHandle currState;

    // ========== 确定 Shader ==========
    if (RenderHandleUtil::GetHandleType(ssd.shader) == RenderHandleType::SHADER_STATE_OBJECT) {
        // 如果没有显式指定 Shader，使用传入的 Shader
        if (!jsonInputs_.explicitShader) {
            currShader = ssd.shader;
        }

        // 尝试获取渲染槽位变体
        const RenderHandle slotShader = shaderMgr.GetShaderHandle(ssd.shader, jsonInputs_.shaderRenderSlotId);
        if (RenderHandleUtil::IsValid(slotShader)) {
            currShader = slotShader;
        }

        // 如果没有 Graphics State，尝试从 Shader 获取
        if (!RenderHandleUtil::IsValid(ssd.gfxState)) {
            const auto gfxStateHandle = shaderMgr.GetGraphicsStateHandleByShaderHandle(currShader);
            if (shaderMgr.GetRenderSlotId(gfxStateHandle) == jsonInputs_.stateRenderSlotId) {
                currState = gfxStateHandle;
            }
        }

        // 获取 Vertex Input Declaration
        currVid = shaderMgr.GetVertexInputDeclarationHandleByShaderHandle(currShader);
    }

    // ========== 确定 Graphics State ==========
    if (RenderHandleUtil::GetHandleType(ssd.gfxState) == RenderHandleType::GRAPHICS_STATE) {
        const RenderHandle slotState = shaderMgr.GetGraphicsStateHandle(ssd.gfxState, jsonInputs_.stateRenderSlotId);
        if (RenderHandleUtil::IsValid(slotState)) {
            currState = slotState;
        }
    }

    // ========== 获取 Pipeline Layout ==========
    bool needsCustomSet = false;
    const PipelineLayout& pl = GetEvaluatedPipelineLayout(currShader, needsCustomSet);

    // ========== 回退到默认值 ==========
    currShader = RenderHandleUtil::IsValid(currShader) ? currShader : allShaderData_.defaultShaderHandle;
    currVid = RenderHandleUtil::IsValid(currVid) ? currVid : allShaderData_.defaultVidHandle;
    currState = RenderHandleUtil::IsValid(currState) ? currState : allShaderData_.defaultStateHandle;

    // ========== 创建 PSO ==========
    auto& psoMgr = renderNodeContextMgr_->GetPsoManager();
    RenderHandle psoHandle;

    // 检查是否需要修改 Graphics State（绕序翻转或自定义图元拓扑）
    const bool inverseWinding = IsInverseWinding(submeshFlags, jsonInputs_.nodeFlags, currentScene_.camera.flags);
    const bool customIa = (ia.primitiveTopology != CORE_PRIMITIVE_TOPOLOGY_MAX_ENUM) || (ia.enablePrimitiveRestart);
    const VertexInputDeclarationView vid = shaderMgr.GetVertexInputDeclarationView(currVid);

    if (inverseWinding || customIa) {
        // 需要修改 Graphics State
        const GraphicsState state = GetNewGraphicsState(shaderMgr, currState, inverseWinding, customIa, ia);
        const auto spec = GetShaderSpecView(state, submeshMatFlags, submeshFlags, lightingFlags, camShaderFlags);
        psoHandle = psoMgr.GetGraphicsPsoHandle(currShader, state, pl, vid, spec, GetDynamicStates());
    } else {
        // 使用默认 Graphics State
        const GraphicsState& state = shaderMgr.GetGraphicsState(currState);
        const auto spec = GetShaderSpecView(state, submeshMatFlags, submeshFlags, lightingFlags, camShaderFlags);
        psoHandle = psoMgr.GetGraphicsPsoHandle(currShader, state, pl, vid, spec, GetDynamicStates());
    }

    // ========== 缓存 PSO ==========
    allShaderData_.perShaderData.push_back(PerShaderData { currShader, psoHandle, currState, needsCustomSet });
    allShaderData_.shaderIdToData[ssd.hash] = (uint32_t)allShaderData_.perShaderData.size() - 1;

    return { psoHandle, needsCustomSet };
}

/**
 * @brief 获取 Shader 特化常量视图
 *
 * 设置特化常量的值，用于 Shader 编译时选择不同的代码路径：
 *
 * 顶点着色器：
 * - SUBMESH_FLAGS: 切线、顶点色、骨骼、第二 UV
 * - MATERIAL_FLAGS: 阴影接收、法线贴图、透明等
 *
 * 片元着色器：
 * - MATERIAL_TYPE: PBR/Unlit/Custom
 * - MATERIAL_FLAGS: 材质标志
 * - LIGHTING_FLAGS: VSM 阴影、点光源、聚光灯
 * - POST_PROCESS_FLAGS: 后处理标志
 * - CAMERA_FLAGS: 雾效等
 */
ShaderSpecializationConstantDataView RenderNodeDefaultMaterialRenderSlot::GetShaderSpecView(
    const RENDER_NS::GraphicsState& gfxState, const RenderDataDefaultMaterial::SubmeshMaterialFlags& submeshMatFlags,
    const RenderSubmeshFlags submeshFlags, const IRenderDataStoreDefaultLight::LightingFlags lightingFlags,
    const RenderCamera::ShaderFlags camShaderFlags)
{
    // 合并材质标志
    RenderMaterialFlags combinedMaterialFlags = submeshMatFlags.renderMaterialFlags;

    // 如果第一个颜色附件没有混合，标记为不透明
    if (gfxState.colorBlendState.colorAttachmentCount > 0) {
        combinedMaterialFlags |= (gfxState.colorBlendState.colorAttachments[0].enableBlend)
                                     ? 0u
                                     : RenderMaterialFlagBits::RENDER_MATERIAL_OPAQUE_BIT;
    }

    // 设置特化常量
    for (uint32_t idx = 0; idx < specializationData_.maxSpecializationCount; ++idx) {
        const auto& ref = allShaderData_.defaultSpecilizationConstants[idx];
        const uint32_t constantId = ref.offset / sizeof(uint32_t);

        // 顶点着色器特化常量
        if (ref.shaderStage == ShaderStageFlagBits::CORE_SHADER_STAGE_VERTEX_BIT) {
            if (ref.id == CORE_DM_CONSTANT_ID_SUBMESH_FLAGS) {
                specializationData_.flags[constantId] = submeshFlags;
            } else if (ref.id == CORE_DM_CONSTANT_ID_MATERIAL_FLAGS) {
                specializationData_.flags[constantId] = combinedMaterialFlags;
            }
        }
        // 片元着色器特化常量
        else if (ref.shaderStage == ShaderStageFlagBits::CORE_SHADER_STAGE_FRAGMENT_BIT) {
            if (ref.id == CORE_DM_CONSTANT_ID_MATERIAL_TYPE) {
                specializationData_.flags[constantId] = static_cast<uint32_t>(submeshMatFlags.materialType);
            } else if (ref.id == CORE_DM_CONSTANT_ID_MATERIAL_FLAGS) {
                specializationData_.flags[constantId] = combinedMaterialFlags;
            } else if (ref.id == CORE_DM_CONSTANT_ID_LIGHTING_FLAGS) {
                specializationData_.flags[constantId] = lightingFlags;
            } else if (ref.id == CORE_DM_CONSTANT_ID_POST_PROCESS_FLAGS) {
                specializationData_.flags[constantId] = currentRenderPPConfiguration_.flags.x;
            } else if (ref.id == CORE_DM_CONSTANT_ID_CAMERA_FLAGS) {
                specializationData_.flags[constantId] = camShaderFlags;
            }
        }
    }

    return { { allShaderData_.defaultSpecilizationConstants.data(), specializationData_.maxSpecializationCount },
        { specializationData_.flags, specializationData_.maxSpecializationCount } };
}

/**
 * @brief 处理渲染槽位的子网格列表
 *
 * 根据渲染槽位配置，从材质数据存储中获取子网格列表：
 * - 按 renderSlotId 筛选子网格
 * - 按 sortType 排序（by_material/by_distance）
 * - 按 cullType 裁剪（view_frustum_cull/none）
 * - 排除 nodeMaterialDiscardFlags 指定的材质
 *
 * @param dataStoreCamera 相机数据存储
 * @param dataStoreMaterial 材质数据存储
 *
 * 输出：sortedSlotSubmeshes_ - 排序后的子网格列表
 */
void RenderNodeDefaultMaterialRenderSlot::ProcessSlotSubmeshes(
    const IRenderDataStoreDefaultCamera& dataStoreCamera, const IRenderDataStoreDefaultMaterial& dataStoreMaterial)
{
    // currentScene has been updated prior, has the correct camera (scene camera or custom camera)
    // 构建渲染槽位信息
    const IRenderNodeSceneUtil::RenderSlotInfo rsi { jsonInputs_.renderSlotId, jsonInputs_.sortType,
        jsonInputs_.cullType, jsonInputs_.nodeMaterialDiscardFlags };

    // 获取排序后的子网格列表
    RenderNodeSceneUtil::GetRenderSlotSubmeshes(dataStoreCamera, dataStoreMaterial, currentScene_.cameraIdx,
        currentScene_.mvCameraIndices, rsi, sortedSlotSubmeshes_);
}

/**
 * @brief 获取动态状态列表
 *
 * 根据是否启用 Fragment Shading Rate (FSR)，返回不同的动态状态列表：
 * - FSR 启用时：包含 Viewport、Scissor、Fragment Shading Rate
 * - FSR 禁用时：仅包含 Viewport、Scissor
 *
 * 动态状态允许在绘制命令之间修改 Pipeline State，
 * 而不需要创建新的 PSO。
 *
 * @return 动态状态数组视图
 */
array_view<const DynamicStateEnum> RenderNodeDefaultMaterialRenderSlot::GetDynamicStates() const
{
    if (fsrEnabled_) {
        // FSR 启用时：包含额外的 Fragment Shading Rate 状态
        return { DYNAMIC_STATES_FSR, countof(DYNAMIC_STATES_FSR) };
    } else {
        // 默认：Viewport 和 Scissor
        return { DYNAMIC_STATES, countof(DYNAMIC_STATES) };
    }
}

/**
 * @brief 解析渲染节点 JSON 输入配置
 *
 * 从渲染节点图 (.rng) JSON 配置中解析所有输入参数：
 *
 * 解析内容：
 * - renderPass: 渲染通道配置
 * - customCameraName/customCameraId: 自定义相机
 * - renderDataStore: 数据存储配置
 * - renderSlotSortType: 排序类型 (by_material/by_distance/front_to_back/etc.)
 * - renderSlotCullType: 裁剪类型 (view_frustum_cull/none)
 * - nodeFlags: 节点标志（雾效、后处理等）
 * - nodeMaterialDiscardFlags: 材质丢弃标志
 * - renderSlot: 渲染槽位名称（如 CORE3D_RS_DM_FW_OPAQUE）
 * - shaderRenderSlot: Shader 槽位（可选）
 * - stateRenderSlot: Graphics State 槽位（可选）
 * - shaderMultiviewRenderSlot: 多视图 Shader 槽位（可选）
 *
 * 自动处理：
 * - 如果有 velocity 附件，自动添加 RENDER_SUBMESH_VELOCITY_BIT
 * - 如果有 fragment shading rate 附件，启用 FSR
 * - 自动评估雾效标志
 */
void RenderNodeDefaultMaterialRenderSlot::ParseRenderNodeInputs()
{
    const IRenderNodeParserUtil& parserUtil = renderNodeContextMgr_->GetRenderNodeParserUtil();
    const auto jsonVal = renderNodeContextMgr_->GetNodeJson();

    // ========== 解析基础配置 ==========
    jsonInputs_.renderPass = parserUtil.GetInputRenderPass(jsonVal, "renderPass");
    jsonInputs_.customCameraName = parserUtil.GetStringValue(jsonVal, "customCameraName");
    jsonInputs_.customCameraId = parserUtil.GetUintValue(jsonVal, "customCameraId");
    jsonInputs_.renderDataStore = parserUtil.GetRenderDataStore(jsonVal, "renderDataStore");

    // ========== 解析渲染槽位配置 ==========
    jsonInputs_.sortType = parserUtil.GetRenderSlotSortType(jsonVal, "renderSlotSortType");
    jsonInputs_.cullType = parserUtil.GetRenderSlotCullType(jsonVal, "renderSlotCullType");

    // ========== 解析节点标志 ==========
    jsonInputs_.nodeFlags = static_cast<uint32_t>(parserUtil.GetUintValue(jsonVal, "nodeFlags"));
    if (jsonInputs_.nodeFlags == ~0u) {
        jsonInputs_.nodeFlags = 0;
    }
    jsonInputs_.nodeMaterialDiscardFlags =
        static_cast<uint32_t>(parserUtil.GetUintValue(jsonVal, "nodeMaterialDiscardFlags"));
    if (jsonInputs_.nodeMaterialDiscardFlags == ~0u) {
        jsonInputs_.nodeMaterialDiscardFlags = 0;
    }

    // ========== 自动检测 velocity 附件 ==========
    // 如果有 velocity 附件，添加速度计算标志
    for (const auto& ref : jsonInputs_.renderPass.attachments) {
        if (ref.name == DefaultMaterialRenderNodeConstants::CORE_DM_CAMERA_VELOCITY_NORMAL) {
            jsonInputs_.nodeSubmeshExtraFlags |= RenderSubmeshFlagBits::RENDER_SUBMESH_VELOCITY_BIT;
        }
    }

    // ========== 解析渲染槽位 ID ==========
    const auto& shaderMgr = renderNodeContextMgr_->GetShaderManager();
    jsonInputs_.renderSlotName = parserUtil.GetStringValue(jsonVal, "renderSlot");
    jsonInputs_.renderSlotId = shaderMgr.GetRenderSlotId(jsonInputs_.renderSlotName);
    jsonInputs_.shaderRenderSlotId = jsonInputs_.renderSlotId;
    jsonInputs_.stateRenderSlotId = jsonInputs_.renderSlotId;

    // 解析 Shader 渲染槽位（可选）
    const string shaderRenderSlot = parserUtil.GetStringValue(jsonVal, "shaderRenderSlot");
    if (!shaderRenderSlot.empty()) {
        const uint32_t renderSlotId = shaderMgr.GetRenderSlotId(shaderRenderSlot);
        if (renderSlotId != ~0U) {
            jsonInputs_.shaderRenderSlotId = renderSlotId;
            jsonInputs_.initialExplicitShader = true;
            jsonInputs_.explicitShader = true;
        }
    }
    jsonInputs_.shaderRenderSlotBaseId = jsonInputs_.shaderRenderSlotId;

    // 解析 State 渲染槽位（可选）
    const string stateRenderSlot = parserUtil.GetStringValue(jsonVal, "stateRenderSlot");
    if (!stateRenderSlot.empty()) {
        const uint32_t renderSlotId = shaderMgr.GetRenderSlotId(stateRenderSlot);
        jsonInputs_.stateRenderSlotId = (renderSlotId != ~0U) ? renderSlotId : jsonInputs_.renderSlotId;
    }

    // 解析多视图渲染槽位（可选）
    const string shaderMultiviewRenderSlot = parserUtil.GetStringValue(jsonVal, "shaderMultiviewRenderSlot");
    if (!shaderMultiviewRenderSlot.empty()) {
        jsonInputs_.shaderRenderSlotMultiviewId = shaderMgr.GetRenderSlotId(shaderMultiviewRenderSlot);
    }

    // ========== 评估雾效标志 ==========
    EvaluateFogBits();

    // ========== 检查 Fragment Shading Rate ==========
    const auto& renderNodeUtil = renderNodeContextMgr_->GetRenderNodeUtil();
    inputRenderPass_ = renderNodeUtil.CreateInputRenderPass(jsonInputs_.renderPass);

    // 如果有 FSR 附件，启用 FSR
    if ((inputRenderPass_.fragmentShadingRateAttachmentIndex < inputRenderPass_.attachments.size()) &&
        RenderHandleUtil::IsValid(
            inputRenderPass_.attachments[inputRenderPass_.fragmentShadingRateAttachmentIndex].handle)) {
        fsrEnabled_ = true;
    }

    // 检查是否有可变的 RenderPass 资源
    jsonInputs_.hasChangeableRenderPassHandles = renderNodeUtil.HasChangeableResources(jsonInputs_.renderPass);

    // ========== 设置相机名称 ==========
    if (jsonInputs_.customCameraId != INVALID_CAM_ID) {
        cameraName_ = to_string(jsonInputs_.customCameraId);
    } else if (!(jsonInputs_.customCameraName.empty())) {
        cameraName_ = jsonInputs_.customCameraName;
    }
}

/**
 * @brief 重置渲染槽位数据
 *
 * 当切换到多视图模式或恢复单视图模式时，需要重置渲染槽位数据。
 *
 * 如果渲染槽位 ID 发生变化：
 * 1. 更新 shaderRenderSlotId
 * 2. 设置 explicitShader 标志（多视图需要显式 Shader）
 * 3. 重新创建默认 Shader 数据（清空 PSO 缓存）
 *
 * @param shaderRenderSlotId 新的渲染槽位 ID
 * @param multiView 是否为多视图模式
 */
void RenderNodeDefaultMaterialRenderSlot::ResetRenderSlotData(const uint32_t shaderRenderSlotId, const bool multiView)
{
    // can be reset to multi-view usage or reset back to default usage
    // 检查是否需要切换渲染槽位
    if (shaderRenderSlotId != jsonInputs_.shaderRenderSlotId) {
        jsonInputs_.shaderRenderSlotId = shaderRenderSlotId;
        // 多视图模式或初始显式 Shader 时，设置显式标志
        jsonInputs_.explicitShader = jsonInputs_.initialExplicitShader || multiView;
        // 重新创建默认 Shader 数据（清空 PSO 缓存）
        CreateDefaultShaderData();
    }
}

/**
 * @brief 评估雾效标志位
 *
 * 根据节点配置和渲染槽位自动设置雾效行为。
 *
 * 规则：
 * 1. 如果 nodeFlags 中已显式设置了 ENABLE_FOG 或 DISABLE_FOG，不做处理
 * 2. 如果没有显式设置，检查是否为默认的不透明/半透明渲染槽位
 * 3. 如果是默认渲染槽位（CORE3D_RS_DM_FW_OPAQUE/TRANSLUCENT），自动启用雾效
 *
 * 这样可以：
 * - 阴影渲染节点自动禁用雾效（不同渲染槽位）
 * - 主场景渲染节点自动启用雾效（默认渲染槽位）
 * - 特殊节点可以显式控制雾效
 */
void RenderNodeDefaultMaterialRenderSlot::EvaluateFogBits()
{
    // if no explicit bits set we check default render slot usages
    // 如果没有显式设置雾效标志，检查默认渲染槽位
    if ((jsonInputs_.nodeFlags & (RENDER_SCENE_ENABLE_FOG_BIT | RENDER_SCENE_DISABLE_FOG_BIT)) == 0) {
        // check default render slots
        // 获取默认的不透明和半透明渲染槽位 ID
        const uint32_t opaqueSlotId = renderNodeContextMgr_->GetShaderManager().GetRenderSlotId(
            DefaultMaterialShaderConstants::RENDER_SLOT_FORWARD_OPAQUE);
        const uint32_t translucentSlotId = renderNodeContextMgr_->GetShaderManager().GetRenderSlotId(
            DefaultMaterialShaderConstants::RENDER_SLOT_FORWARD_TRANSLUCENT);

        // 如果当前渲染槽位是默认的不透明或半透明槽位，自动启用雾效
        if ((jsonInputs_.renderSlotId == opaqueSlotId) || (jsonInputs_.renderSlotId == translucentSlotId)) {
            jsonInputs_.nodeFlags |= RenderSceneFlagBits::RENDER_SCENE_ENABLE_FOG_BIT;
        }
    }
}

/**
 * @brief 获取评估后的 Pipeline Layout
 *
 * 根据 Shader 情况返回合适的 Pipeline Layout：
 * - 如果 Shader 需要 Set 3（自定义资源），返回修改后的临时 Pipeline Layout
 * - 否则返回默认 Pipeline Layout
 *
 * Set 3 处理：
 * - 自定义 Shader 可能需要额外的 Descriptor Set（Set 3）
 * - 需要将 Shader 的 Set 3 布局合并到默认 Pipeline Layout 中
 * - 这允许材质使用自定义资源（Buffer、Texture、Sampler）
 *
 * @param currShader 当前 Shader 句柄（可能无效）
 * @param needsCustomSet 输出参数：是否需要自定义 Set 3
 * @return 评估后的 Pipeline Layout
 */
const PipelineLayout& RenderNodeDefaultMaterialRenderSlot::GetEvaluatedPipelineLayout(
    const RenderHandle& currShader, bool& needsCustomSet)
{
    // the inputs need to be in certain "state"
    // currShader is valid if there's custom shader
    // 输入需要处于特定状态：currShader 仅在有自定义 Shader 时有效

    const auto& shaderMgr = renderNodeContextMgr_->GetShaderManager();

    // 清除临时 Pipeline Layout 的自定义 Set 3
    auto& tmpPl = allShaderData_.defaultTmpPipelineLayout;

    // 辅助函数：更新自定义 Pipeline Layout 的 Set 3
    auto UpdateCustomPl = [](const DescriptorSetLayout& dsl, PipelineLayout& tmpPl) {
        if (!dsl.bindings.empty()) {
            tmpPl.descriptorSetLayouts[FIXED_CUSTOM_SET3] = dsl;
            return true;
        }
        return false;
    };

    // 检查是否需要 Set 3
    // 条件：有有效的 Shader，或默认 Pipeline Layout 本身有 Set 3
    const bool def3NoShader = ((!RenderHandleUtil::IsValid(currShader)) && (allShaderData_.defaultPlSet3));
    if (RenderHandleUtil::IsValid(currShader) || def3NoShader) {
        const RenderHandle shader = def3NoShader ? allShaderData_.defaultShaderHandle : currShader;
        RenderHandle reflPl;
        RenderHandle currPl = shaderMgr.GetPipelineLayoutHandleByShaderHandle(shader);

        // 从 Shader 的 Pipeline Layout 获取 Set 3
        if (RenderHandleUtil::IsValid(currPl)) {
            const auto& plSet = shaderMgr.GetPipelineLayout(currPl).descriptorSetLayouts[FIXED_CUSTOM_SET3];
            needsCustomSet = UpdateCustomPl(plSet, tmpPl);
        }

        // 如果没有 Pipeline Layout，从反射数据获取
        if ((!needsCustomSet) && (!RenderHandleUtil::IsValid(currPl))) {
            reflPl = shaderMgr.GetReflectionPipelineLayoutHandle(shader);
            const auto& plSet = shaderMgr.GetPipelineLayout(reflPl).descriptorSetLayouts[FIXED_CUSTOM_SET3];
            needsCustomSet = UpdateCustomPl(plSet, tmpPl);
        }

#if (CORE3D_VALIDATION_ENABLED == 1)
        // 验证 Shader 与默认 Pipeline Layout 的兼容性
        {
            if (!RenderHandleUtil::IsValid(reflPl)) {
                reflPl = shaderMgr.GetReflectionPipelineLayoutHandle(shader);
            }
            const IShaderManager::CompatibilityFlags flags =
                shaderMgr.GetCompatibilityFlags(allShaderData_.defaultPlHandle, reflPl);
            if (flags == 0) {
                const auto idDesc = shaderMgr.GetIdDesc(shader);
                CORE_LOG_W("Compatibility issue with 3D default material shaders (name: %s, path: %s)",
                    idDesc.displayName.c_str(), idDesc.path.c_str());
            }
        }
#endif
    }

    // return modified custom pipeline layout or the default
    // 返回修改后的自定义 Pipeline Layout 或默认 Pipeline Layout
    if (needsCustomSet) {
        return allShaderData_.defaultTmpPipelineLayout;
    } else {
        return allShaderData_.defaultPipelineLayout;
    }
}

// ============================================================================
// 工厂方法 - 用于插件注册和节点创建
// ============================================================================

/**
 * @brief 创建 RenderNodeDefaultMaterialRenderSlot 实例
 *
 * 工厂方法，由 RenderNodeGraphManager 在创建节点时调用。
 * 注册在 RenderNodeTypeInfo::createNode 中。
 *
 * @return 新创建的渲染节点实例
 */
RENDER_NS::IRenderNode* RenderNodeDefaultMaterialRenderSlot::Create()
{
    return new RenderNodeDefaultMaterialRenderSlot();
}

/**
 * @brief 销毁 RenderNodeDefaultMaterialRenderSlot 实例
 *
 * 工厂方法，由 RenderNodeGraphManager 在销毁节点时调用。
 * 注册在 RenderNodeTypeInfo::destroyNode 中。
 *
 * @param instance 要销毁的节点实例
 */
void RenderNodeDefaultMaterialRenderSlot::Destroy(IRenderNode* instance)
{
    delete static_cast<RenderNodeDefaultMaterialRenderSlot*>(instance);
}

CORE3D_END_NAMESPACE()
