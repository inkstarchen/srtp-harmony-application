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
 * @file render_node_default_env.cpp
 * @brief 默认环境背景渲染节点实现
 *
 * ============================================================================
 * 【功能概述】
 * ============================================================================
 * 负责渲染相机的环境背景，包括：
 * - 天空盒 (Sky)
 * - Cubemap 环境贴图
 * - 2D 全景图 (Equirectangular)
 * - 自定义 Shader 背景
 *
 * ============================================================================
 * 【输入】
 * ============================================================================
 * 1. IRenderDataStoreDefaultScene
 *    - 当前场景信息（相机索引）
 *
 * 2. IRenderDataStoreDefaultCamera
 *    - RenderCamera 列表：包含 environment 配置
 *    - RenderCamera::Environment 包含：
 *      - backgroundType: 背景类型（SKY/CUBEMAP/IMAGE/EQUIRECTANGULAR）
 *      - envMap: 环境贴图句柄
 *      - shader: 自定义着色器
 *      - envMapLodLevel: LOD 级别
 *      - multiEnvIds: 多环境混合 ID
 *
 * 3. JSON 配置
 *    - renderPass: 渲染通道配置
 *    - customCameraName/customCameraId: 自定义相机
 *    - renderSlot: 渲染槽位
 *    - nodeFlags: 节点标志（雾效、后处理等）
 *
 * ============================================================================
 * 【输出】
 * ============================================================================
 * 渲染结果直接写入 RenderPass 的颜色附件（通常是屏幕或中间缓冲区）
 * 不产生额外的 GPU Buffer 输出
 *
 * ============================================================================
 * 【与 RenderNodeDefaultCameras 的关系】
 * ============================================================================
 * RenderNodeDefaultCameras (相机节点):
 *   - 将 Environment 数据写入 GPU Uniform Buffer
 *   - 数据用于 Shader 中的环境光照计算（间接漫反射、高光反射）
 *   - 输出: SCENE_ENVIRONMENT_DATA_BUFFER
 *
 * RenderNodeDefaultEnv (本节点):
 *   - 读取 RenderCamera::Environment 配置
 *   - 渲染环境背景到屏幕
 *   - 不输出 GPU Buffer，直接渲染到 RenderPass
 *
 * 区别：
 *   - Cameras 节点: 计算/存储环境光照数据（用于物体着色）
 *   - Env 节点: 渲染可见的环境背景（天空盒等）
 *
 * ============================================================================
 * 【被谁使用】
 * ============================================================================
 * - 渲染结果直接呈现到屏幕
 * - 后续节点可能在环境背景上叠加其他物体
 *
 * ============================================================================
 * 【执行流程】
 * ============================================================================
 * InitNode() -> 解析配置，创建 DescriptorSet，获取默认资源
 *     ↓
 * PreExecuteFrame() -> （当前为空）
 *     ↓
 * ExecuteFrame() -> 获取当前相机环境配置
 *                 -> 更新 RenderPass
 *                 -> 选择并绑定 Shader (PSO)
 *                 -> 绑定环境贴图
 *                 -> 绘制全屏三角形
 */

#include "render_node_default_env.h"

#include <algorithm>

#include <3d/render/default_material_constants.h>
#include <3d/render/intf_render_data_store_default_camera.h>
#include <3d/render/intf_render_data_store_default_light.h>
#include <3d/render/intf_render_data_store_default_scene.h>
#include <3d/render/render_data_defines_3d.h>
#include <base/containers/string.h>
#include <base/math/matrix.h>
#include <base/math/matrix_util.h>
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

#include "render/default_constants.h"
#include "render/render_node_scene_util.h"

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

// 默认天空着色器路径
constexpr string_view DEFAULT_SKY_SHADER_NAME { "3dshaders://shader/clouds/core3d_dm_env_sky.shader" };

// 后处理重要标志掩码（只取低 8 位）
static constexpr uint32_t POST_PROCESS_IMPORTANT_FLAGS_MASK { 0xffU };

// 固定的自定义 Descriptor Set 索引
static constexpr uint32_t FIXED_CUSTOM_SET3 { 3U };  // 默认环境贴图绑定位置
static constexpr uint32_t FIXED_CUSTOM_SET1 { 1U };  // 兼容旧版本

// ============================================================================
// 辅助结构体
// ============================================================================

/**
 * @brief 帧全局 Descriptor Set 信息
 * 包含 Set 0（相机/材质全局数据）
 */
struct FrameGlobalDescriptorSets {
    RenderHandle set0;      // 全局 Descriptor Set 句柄
    bool valid = false;     // 是否有效
};

/**
 * @brief 获取帧全局 Descriptor Set
 *
 * Set 0 包含所有相机和材质的全局数据：
 * - Camera Matrix Buffer (视图、投影矩阵)
 * - Environment Buffer (环境光照数据)
 * - Light Buffer (灯光数据)
 *
 * 由 RenderNodeDefaultCameraController 创建
 */
// 疑惑点： 这里的GlobalDescriptorSet是谁在什么阶段创建的，是每个节点一个的还是全局共享的
FrameGlobalDescriptorSets GetFrameGlobalDescriptorSets(
    IRenderNodeContextManager* rncm, const SceneRenderDataStores& stores, const string& cameraName)
{
    FrameGlobalDescriptorSets fgds;
    if (rncm) {
        // 每帧重新获取全局 Descriptor Sets
        const INodeContextDescriptorSetManager& dsMgr = rncm->GetDescriptorSetManager();
        const string_view us = stores.dataStoreNameScene;

        // 获取 Material Set 0（由 CameraController 创建）
        fgds.set0 = dsMgr.GetGlobalDescriptorSet(
            us + DefaultMaterialMaterialConstants::MATERIAL_SET0_GLOBAL_DESCRIPTOR_SET_PREFIX_NAME + cameraName);
        fgds.valid = RenderHandleUtil::IsValid(fgds.set0);

        if (!fgds.valid) {
            CORE_LOG_ONCE_E("core3d_global_descriptor_set_env_all_issues",
                "Global descriptor set 0 for default material not "
                "found (RenderNodeDefaultCameraController needed)");
        }
    }
    return fgds;
}

/**
 * @brief 输入环境数据句柄
 * 包含需要绑定的环境贴图资源
 */
struct InputEnvironmentDataHandles {
    RenderHandle cubeHandle;         // Cubemap 句柄
    RenderHandle cubeBlenderHandle;  // 混合 Cubemap 句柄（多环境混合）
    RenderHandle texHandle;          // 2D 纹理句柄
    float lodLevel { 0.0f };         // LOD 级别
};

/**
 * @brief 获取环境数据句柄
 *
 * 根据相机的环境配置，确定需要绑定的环境贴图：
 * - BG_TYPE_IMAGE: 2D 纹理作为背景
 * - BG_TYPE_EQUIRECTANGULAR: 全景图（2D）
 * - BG_TYPE_CUBEMAP: Cubemap 纹理
 * - 多环境混合: 使用两个 Cubemap 进行混合
 *
 * @param dsCamera 相机 DataStore
 * @param gpuResourceMgr GPU 资源管理器
 * @param defaultImages 默认图像资源（后备）
 * @param cam 当前相机数据
 * @return 环境数据句柄
 */
//疑惑点：这个defaultImage是谁传进来的，谁组织的
InputEnvironmentDataHandles GetEnvironmentDataHandles(const IRenderDataStoreDefaultCamera& dsCamera,
    IRenderNodeGpuResourceManager& gpuResourceMgr, const RenderNodeDefaultEnv::DefaultImages& defaultImages,
    const RenderCamera& cam)
{
    InputEnvironmentDataHandles iedh;

    // 初始化为默认图像
    iedh.texHandle = defaultImages.texHandle;
    iedh.cubeHandle = defaultImages.cubeHandle;
    iedh.cubeBlenderHandle = defaultImages.cubeHandle;

    const auto& env = cam.environment;
    const bool dynCubemap = (env.multiEnvCount > 0U);

    // 如果有环境贴图或多环境混合
    if (env.envMap || dynCubemap) {
        const RenderHandle handle = env.envMap.GetHandle();
        const GpuImageDesc desc = gpuResourceMgr.GetImageDescriptor(handle);

        // 根据背景类型选择正确的贴图类型
        if ((env.backgroundType == RenderCamera::Environment::BG_TYPE_IMAGE) ||
            (env.backgroundType == RenderCamera::Environment::BG_TYPE_EQUIRECTANGULAR)) {
            // 2D 图像或全景图
            if (desc.imageViewType == CORE_IMAGE_VIEW_TYPE_2D) {
                iedh.texHandle = handle;
            } else {
                CORE_LOG_ONCE_E("inv_env_2d_bg_type", "invalid environment map, type does not match background type");
            }
        } else if (env.backgroundType == RenderCamera::Environment::BG_TYPE_CUBEMAP) {
            // Cubemap
            bool valid = false;
            if (desc.imageViewType == CORE_IMAGE_VIEW_TYPE_CUBE) {
                iedh.cubeHandle = handle;
                valid = true;
            }

            // 多环境混合：获取两个环境的 Cubemap
            if (dynCubemap && (env.multiEnvCount >= 2U)) {
                CORE_STATIC_ASSERT(DefaultMaterialCameraConstants::MAX_CAMERA_MULTI_ENVIRONMENT_COUNT >= 2U);
                const RenderCamera::Environment env1 = dsCamera.GetEnvironment(env.multiEnvIds[0U]);
                const RenderCamera::Environment env2 = dsCamera.GetEnvironment(env.multiEnvIds[1U]);
                iedh.cubeHandle = env1.envMap.GetHandle();
                iedh.cubeBlenderHandle = env2.envMap.GetHandle();
                valid = true;
            }

            if (!valid) {
                CORE_LOG_ONCE_E("inv_env_cu_bg_type", "invalid environment map, type does not match background type");
            }
        }
        iedh.lodLevel = env.envMapLodLevel;
    }
    return iedh;
}
} // namespace

/**
 * @brief 初始化节点 - 解析配置，创建资源
 *
 * 步骤：
 * 1. 解析 JSON 输入配置（renderPass、camera、renderSlot 等）
 * 2. 获取场景数据存储名称
 * 3. 获取默认 GPU 资源（默认 Cubemap、默认纹理、采样器）
 * 4. 创建渲染通道（RenderPass）
 * 5. 获取默认 Shader 和 Pipeline Layout
 * 6. 创建 Descriptor Sets
 *
 * 默认资源说明：
 * - CORE_DEFAULT_SKYBOX_CUBEMAP: 默认天空盒 Cubemap
 * - CORE_DEFAULT_MATERIAL_BASE_COLOR: 默认白色纹理
 * - CORE_DEFAULT_RADIANCE_CUBEMAP_SAMPLER: Cubemap 采样器
 */
// 疑惑点：它直接获取图像和采样器资源，这些资源是谁创建的
// 疑惑点：ParseJSON的数据是从哪里读取的？（需要溯源检查）
void RenderNodeDefaultEnv::InitNode(IRenderNodeContextManager& renderNodeContextMgr)
{
    // 保存上下文管理器引用
    renderNodeContextMgr_ = &renderNodeContextMgr;

    // 解析 JSON 配置输入
    ParseRenderNodeInputs();

    // 获取场景渲染数据存储名称
    const auto& renderNodeGraphData = renderNodeContextMgr_->GetRenderNodeGraphData();
    stores_ = RenderNodeSceneUtil::GetSceneRenderDataStores(
        renderNodeContextMgr, renderNodeGraphData.renderNodeGraphDataStoreName);

    // 初始化当前场景状态
    currentScene_ = {};
    currentBgType_ = { RenderCamera::Environment::BG_TYPE_NONE };

    // 检查后处理配置是否有效
    if ((jsonInputs_.nodeFlags & RenderSceneFlagBits::RENDER_SCENE_DIRECT_POST_PROCESS_BIT) &&
        jsonInputs_.renderDataStore.dataStoreName.empty()) {
        CORE_LOG_V("%s: render data store post process configuration not set in render node graph",
            renderNodeContextMgr_->GetName().data());
    }

    // 获取 GPU 资源管理器
    auto& gpuResourceMgr = renderNodeContextMgr.GetGpuResourceManager();

    // 获取默认采样器和图像资源
    cubemapSampler =
        gpuResourceMgr.GetSamplerHandle(DefaultMaterialGpuResourceConstants::CORE_DEFAULT_RADIANCE_CUBEMAP_SAMPLER);
    defaultImages_.texHandle =
        gpuResourceMgr.GetImageHandle(DefaultMaterialGpuResourceConstants::CORE_DEFAULT_MATERIAL_BASE_COLOR);
    defaultImages_.cubeHandle =
        gpuResourceMgr.GetImageHandle(DefaultMaterialGpuResourceConstants::CORE_DEFAULT_SKYBOX_CUBEMAP);

    // 创建渲染通道
    rngRenderPass_ = renderNodeContextMgr.GetRenderNodeUtil().CreateRenderPass(inputRenderPass_);

    // 获取 Shader 和 Pipeline Layout
    const auto& shaderMgr = renderNodeContextMgr.GetShaderManager();
    const IShaderManager::RenderSlotData shaderRsd = shaderMgr.GetRenderSlotData(jsonInputs_.renderSlotId);
    defaultShaderData_.shader = shaderRsd.shader.GetHandle();
    defaultShaderData_.pl = shaderRsd.pipelineLayout.GetHandle();
    defaultShaderData_.plData = shaderMgr.GetPipelineLayout(defaultShaderData_.pl);

    // 获取默认天空着色器
    defaultSkyShader_ = shaderMgr.GetShaderHandle(DEFAULT_SKY_SHADER_NAME);

    // 创建 Descriptor Sets
    CreateDescriptorSets();
}

/**
 * @brief 每帧预处理
 * 当前为空实现，可在需要时重新创建 GPU 资源
 */
void RenderNodeDefaultEnv::PreExecuteFrame()
{
    // 重新创建需要的 GPU 资源（当前无操作）
}

/**
 * @brief 执行帧 - 渲染环境背景
 *
 * 核心流程：
 * 1. 从 DataStore 获取场景、相机、灯光数据
 * 2. 更新当前场景状态（相机、视口等）
 * 3. 开始 RenderPass
 * 4. 如果背景类型不是 NONE，渲染环境背景
 * 5. 结束 RenderPass
 *
 * 渲染条件：
 * - 相机的 environment.backgroundType != BG_TYPE_NONE
 * - 相机的 layerMask 与 environment.layerMask 有交集
 */
void RenderNodeDefaultEnv::ExecuteFrame(IRenderCommandList& cmdList)
{
    // 获取渲染数据存储管理器
    const auto& renderDataStoreMgr = renderNodeContextMgr_->GetRenderDataStoreManager();

    // 获取三个关键数据存储
    const auto* dataStoreScene =
        static_cast<IRenderDataStoreDefaultScene*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameScene));
    const auto* dataStoreCamera =
        static_cast<IRenderDataStoreDefaultCamera*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameCamera));
    const auto* dataStoreLight =
        static_cast<IRenderDataStoreDefaultLight*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameLight));

    // 更新当前场景（相机、视口等）
    if (dataStoreLight && dataStoreCamera && dataStoreScene) {
        UpdateCurrentScene(*dataStoreScene, *dataStoreCamera);
    }

    // 调试标记
    RENDER_DEBUG_MARKER_COL_SCOPE(cmdList, "3DEnv", DefaultDebugConstants::DEFAULT_DEBUG_COLOR);

    // 开始渲染通道
    cmdList.BeginRenderPass(renderPass_.renderPassDesc, renderPass_.subpassStartIndex, renderPass_.subpassDesc);

    // 检查是否需要渲染环境背景
    if (dataStoreCamera && currentScene_.camera.environment.backgroundType != RenderCamera::Environment::BG_TYPE_NONE) {
        // 检查层遮罩是否匹配
        if (currentScene_.camera.layerMask & currentScene_.camera.environment.layerMask) {
            // 更新后处理配置
            UpdatePostProcessConfiguration();
            // 渲染环境数据
            RenderData(*dataStoreCamera, cmdList);
        }
    }

    // 结束渲染通道
    cmdList.EndRenderPass();
}

/**
 * @brief 渲染环境数据 - 绑定资源并绘制
 *
 * 步骤：
 * 1. 获取帧全局 Descriptor Set（Set 0）
 * 2. 设置动态状态（视口、裁剪区域、FSR）
 * 3. 选择 Shader（默认天空 vs 环境着色器）
 * 4. 获取或创建 PSO（Pipeline State Object）
 * 5. 绑定 Pipeline 和 Descriptor Sets
 * 6. 更新环境贴图绑定（Set 3）
 * 7. 如果有自定义资源，绑定自定义 Set
 * 8. 绘制全屏三角形（3 个顶点）
 *
 * Shader 选择逻辑：
 * - BG_TYPE_SKY: 使用 defaultSkyShader_（天空着色器）
 * - 其他类型: 使用 defaultShaderData_.shader（环境着色器）
 * - 自定义: 使用 environment.shader（用户指定）
 */
void RenderNodeDefaultEnv::RenderData(const IRenderDataStoreDefaultCamera& dsCamera, IRenderCommandList& cmdList)
{
    // 获取帧全局 Descriptor Sets（每帧重新获取）
    FrameGlobalDescriptorSets fgds = GetFrameGlobalDescriptorSets(renderNodeContextMgr_, stores_, cameraName_);
    if (!fgds.valid) {
        return;
    }

    auto& gpuResourceMgr = renderNodeContextMgr_->GetGpuResourceManager();

    // 设置动态状态
    cmdList.SetDynamicStateViewport(currentScene_.viewportDesc);
    cmdList.SetDynamicStateScissor(currentScene_.scissorDesc);

    // 如果启用 FSR，设置片段着色率
    if (fsrEnabled_) {
        cmdList.SetDynamicStateFragmentShadingRate(
            { 1u, 1u }, FragmentShadingRateCombinerOps { CORE_FRAGMENT_SHADING_RATE_COMBINER_OP_REPLACE,
                            CORE_FRAGMENT_SHADING_RATE_COMBINER_OP_REPLACE });
    }

    const RenderCamera::Environment& renderEnv = currentScene_.camera.environment;

    // ========== 选择 Shader ==========
    // 天空类型使用天空着色器，其他使用默认着色器
    const RenderHandle defaultShader = (renderEnv.backgroundType == RenderCamera::Environment::BG_TYPE_SKY)
                                           ? defaultSkyShader_
                                           : defaultShaderData_.shader;
    const RenderHandle shaderHandle = renderEnv.shader ? renderEnv.shader.GetHandle() : defaultShader;

    // ========== 获取/创建 PSO ==========
    // 检查是否需要重新创建 PSO
    if ((renderEnv.backgroundType != currentBgType_) || (currShaderData_.shader.id != shaderHandle.id) ||
        (currentCameraShaderFlags_ != currentScene_.cameraShaderFlags) ||
        (!RenderHandleUtil::IsValid(currShaderData_.pso))) {
        currentBgType_ = currentScene_.camera.environment.backgroundType;
        currentCameraShaderFlags_ = currentScene_.cameraShaderFlags;
        currShaderData_ = GetPso(shaderHandle, currentBgType_, currentRenderPPConfiguration_);
    }

    // ========== 绑定 Pipeline 和 Descriptor Sets ==========
    cmdList.BindPipeline(currShaderData_.pso);
    cmdList.BindDescriptorSet(0U, fgds.set0);  // 绑定全局 Set 0

    // ========== 绑定环境贴图 (Set 3) ==========
    if ((!currShaderData_.customSet) && builtInSet3_) {
        // 获取环境贴图句柄
        const auto envDataHandles =
            GetEnvironmentDataHandles(dsCamera, gpuResourceMgr, defaultImages_, currentScene_.camera);

        // 绑定环境贴图到 Set 3
        auto& binder = *builtInSet3_;
        {
            uint32_t bindingIndex = 0;
            // binding 0: 2D 纹理（全景图或图像）
            binder.BindImage(bindingIndex++, envDataHandles.texHandle, cubemapSampler);
            // binding 1: Cubemap（主环境）
            binder.BindImage(bindingIndex++, envDataHandles.cubeHandle, cubemapSampler);
            // binding 2: Cubemap（混合环境）
            binder.BindImage(bindingIndex++, envDataHandles.cubeBlenderHandle, cubemapSampler);
        }

        // 更新并绑定 Descriptor Set
        cmdList.UpdateDescriptorSet(binder.GetDescriptorSetHandle(), binder.GetDescriptorSetLayoutBindingResources());
        cmdList.BindDescriptorSet(FIXED_CUSTOM_SET3, binder.GetDescriptorSetHandle());
    }

    // ========== 绑定自定义资源 ==========
    bool validDraw = true;
    if (currShaderData_.customSet) {
        // 使用自定义 Shader 资源
        validDraw = (renderEnv.customResourceHandles[0]) ? true : false;
        validDraw = validDraw && UpdateAndBindCustomSet(cmdList, renderEnv);
    }

    // ========== 绘制全屏三角形 ==========
    if (validDraw) {
        // 全屏三角形：3 个顶点，1 个实例
        // Shader 使用 vertex ID 生成顶点位置，无需顶点缓冲
        cmdList.Draw(3u, 1u, 0u, 0u);
    }
}

/**
 * @brief 更新并绑定自定义 Descriptor Set
 *
 * 当使用自定义 Shader 时，需要绑定用户提供的自定义资源。
 * 资源可以是：Buffer、Image、Sampler
 *
 * @param cmdList 渲染命令列表
 * @param renderEnv 相机环境配置
 * @return 是否成功绑定
 */
bool RenderNodeDefaultEnv::UpdateAndBindCustomSet(
    IRenderCommandList& cmdList, const RenderCamera::Environment& renderEnv)
{
    CORE_ASSERT(currShaderData_.customSet);

    IRenderNodeGpuResourceManager& gpuResourceMgr = renderNodeContextMgr_->GetGpuResourceManager();
    INodeContextDescriptorSetManager& descriptorSetMgr = renderNodeContextMgr_->GetDescriptorSetManager();
    const IRenderNodeShaderManager& shaderMgr = renderNodeContextMgr_->GetShaderManager();

    // 获取自定义 Shader 的 Pipeline Layout
    RenderHandle currPlHandle = shaderMgr.GetPipelineLayoutHandleByShaderHandle(renderEnv.shader.GetHandle());

    // 如果 Shader 没有关联 Pipeline Layout，使用反射获取
    if (!RenderHandleUtil::IsValid(currPlHandle)) {
        currPlHandle = shaderMgr.GetReflectionPipelineLayoutHandle(renderEnv.shader.GetHandle());
    }

    // 如果反射也没有，使用默认 Pipeline Layout
    if (!RenderHandleUtil::IsValid(currPlHandle)) {
        currPlHandle = defaultShaderData_.pl;
    }

    // 统计有效的自定义资源数量
    uint32_t validResCount = 0;
    for (uint32_t idx = 0; idx < RenderSceneDataConstants::MAX_ENV_CUSTOM_RESOURCE_COUNT; ++idx) {
        if (renderEnv.customResourceHandles[idx]) {
            validResCount++;
        } else {
            break;
        }
    }

    const array_view<const RenderHandleReference> customResourceHandles(renderEnv.customResourceHandles, validResCount);
    const PipelineLayout& plRef = shaderMgr.GetPipelineLayout(currPlHandle);
    const auto& descBindings = plRef.descriptorSetLayouts[currShaderData_.customSetIndex].bindings;

    // 创建单帧 Descriptor Set
    const RenderHandle descSetHandle = descriptorSetMgr.CreateOneFrameDescriptorSet(descBindings);
    if (!RenderHandleUtil::IsValid(descSetHandle) || (descBindings.size() != customResourceHandles.size())) {
        return false;
    }

    // 创建 Descriptor Set Binder
    IDescriptorSetBinder::Ptr binderPtr = descriptorSetMgr.CreateDescriptorSetBinder(descSetHandle, descBindings);
    if (!binderPtr) {
        return false;
    }

    bool valid = false;
    auto& binder = *binderPtr;

    // 根据资源类型绑定到对应位置
    for (uint32_t idx = 0; idx < static_cast<uint32_t>(customResourceHandles.size()); ++idx) {
        CORE_ASSERT(idx < descBindings.size());
        const RenderHandle currRes = customResourceHandles[idx].GetHandle();

        if (gpuResourceMgr.IsGpuBuffer(currRes)) {
            // Buffer 资源
            binder.BindBuffer(idx, currRes, 0);
        } else if (gpuResourceMgr.IsGpuImage(currRes)) {
            // Image 资源
            if (descBindings[idx].descriptorType == DescriptorType::CORE_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER) {
                // 需要采样器的 Image
                binder.BindImage(idx, currRes, cubemapSampler);
            } else {
                // 纯 Image
                binder.BindImage(idx, currRes);
            }
        } else if (gpuResourceMgr.IsGpuSampler(currRes)) {
            // Sampler 资源
            binder.BindSampler(idx, currRes);
        }
    }

    // 检查绑定有效性并更新
    if (binder.GetDescriptorSetLayoutBindingValidity()) {
        cmdList.UpdateDescriptorSet(binder.GetDescriptorSetHandle(), binder.GetDescriptorSetLayoutBindingResources());
        cmdList.BindDescriptorSet(currShaderData_.customSetIndex, binder.GetDescriptorSetHandle());
        valid = true;
    }

    if (!valid) {
#if (CORE3D_VALIDATION_ENABLED == 1)
        CORE_LOG_ONCE_W("default_env_custom_res_issue",
            "invalid bindings with custom shader descriptor set 1 or 3 (render node: %s)",
            renderNodeContextMgr_->GetName().data());
#endif
    }
    return valid;
}

/**
 * @brief 更新当前场景状态
 *
 * 从 DataStore 获取当前相机信息，更新：
 * - RenderPass 配置（清除值等）
 * - 视口和裁剪区域
 * - 相机 Shader 标志（雾效等）
 *
 * @param dataStoreScene 场景 DataStore
 * @param dataStoreCamera 相机 DataStore
 */
void RenderNodeDefaultEnv::UpdateCurrentScene(
    const IRenderDataStoreDefaultScene& dataStoreScene, const IRenderDataStoreDefaultCamera& dataStoreCamera)
{
    // 如果有可变的 RenderPass 句柄，重新创建
    if (jsonInputs_.hasChangeableRenderPassHandles) {
        const auto& renderNodeUtil = renderNodeContextMgr_->GetRenderNodeUtil();
        inputRenderPass_ = renderNodeUtil.CreateInputRenderPass(jsonInputs_.renderPass);
        rngRenderPass_ = renderNodeContextMgr_->GetRenderNodeUtil().CreateRenderPass(inputRenderPass_);
    }

    // 获取基础 RenderPass
    renderPass_ = rngRenderPass_;

    // ========== 获取当前相机 ==========
    const auto scene = dataStoreScene.GetScene();
    bool hasCustomCamera = false;
    bool isNamedCamera = false;  // 注意：遗留支持，将来会移除
    uint32_t cameraIdx = scene.cameraIndex;

    // 检查是否有自定义相机 ID
    if (jsonInputs_.customCameraId != INVALID_CAM_ID) {
        cameraIdx = dataStoreCamera.GetCameraIndex(jsonInputs_.customCameraId);
        hasCustomCamera = true;
    } else if (!(jsonInputs_.customCameraName.empty())) {
        // 检查是否有自定义相机名称
        cameraIdx = dataStoreCamera.GetCameraIndex(jsonInputs_.customCameraName);
        hasCustomCamera = true;
        isNamedCamera = true;
    }

    // 存储当前帧相机
    if (const auto cameras = dataStoreCamera.GetCameras(); cameraIdx < (uint32_t)cameras.size()) {
        currentScene_.camera = cameras[cameraIdx];
    }

    // ========== 更新 RenderPass ==========
    // RenderPass 需要在 InitNode 中创建
    if (hasCustomCamera) {
        // 使用基于相机的清除配置
        RenderNodeSceneUtil::UpdateRenderPassFromCustomCamera(currentScene_.camera, isNamedCamera, renderPass_);
    } else {
        RenderNodeSceneUtil::UpdateRenderPassFromCamera(currentScene_.camera, renderPass_);
    }

    // ========== 创建视口和裁剪区域 ==========
    currentScene_.viewportDesc = RenderNodeSceneUtil::CreateViewportFromCamera(currentScene_.camera);
    currentScene_.scissorDesc = RenderNodeSceneUtil::CreateScissorFromCamera(currentScene_.camera);

    // 环境背景总是使用最大深度值（在所有物体后面）
    currentScene_.viewportDesc.minDepth = 1.0f;
    currentScene_.viewportDesc.maxDepth = 1.0f;

    // ========== 更新 Shader 标志 ==========
    currentScene_.cameraShaderFlags = currentScene_.camera.shaderFlags;

    // 如果节点配置禁用雾效，移除雾效标志
    if (jsonInputs_.nodeFlags & RenderSceneFlagBits::RENDER_SCENE_DISABLE_FOG_BIT) {
        currentScene_.cameraShaderFlags &= (~RenderCamera::ShaderFlagBits::CAMERA_SHADER_FOG_BIT);
    }

    // 如果需要多视图，重置渲染槽位数据
    ResetRenderSlotData(renderPass_.subpassDesc.viewMask > 1U);
}

/**
 * @brief 获取或创建 Pipeline State Object (PSO)
 *
 * PSO 包含：
 * - Shader 状态
 * - Graphics State（混合、深度测试等）
 * - Pipeline Layout
 * - Specialization Constants（特化常量）
 *
 * 特化常量设置：
 * - MATERIAL_TYPE: 材质类型（环境背景为 0）
 * - MATERIAL_FLAGS: 材质标志
 * - LIGHTING_FLAGS: 光照标志
 * - POST_PROCESS_FLAGS: 后处理标志
 * - CAMERA_FLAGS: 相机标志（雾效等）
 * - ENV_TYPE: 环境类型（SKY/CUBEMAP/IMAGE 等）
 *
 * @param shaderHandle Shader 句柄
 * @param bgType 背景类型
 * @param renderPostProcessConfiguration 后处理配置
 * @return ShaderData 包含 PSO 和相关信息
 */
RenderNodeDefaultEnv::ShaderData RenderNodeDefaultEnv::GetPso(const RenderHandle shaderHandle,
    const RenderCamera::Environment::BackgroundType bgType,
    const RenderPostProcessConfiguration& renderPostProcessConfiguration)
{
    ShaderData sd;

    if (RenderHandleUtil::GetHandleType(shaderHandle) == RenderHandleType::SHADER_STATE_OBJECT) {
        const auto& shaderMgr = renderNodeContextMgr_->GetShaderManager();

        // 获取特化常量反射信息
        const ShaderSpecializationConstantView sscv = shaderMgr.GetReflectionSpecialization(shaderHandle);
        vector<uint32_t> flags(sscv.constants.size());

        // 设置特化常量值
        for (const auto& ref : sscv.constants) {
            const uint32_t constantId = ref.offset / sizeof(uint32_t);

            if (ref.shaderStage == ShaderStageFlagBits::CORE_SHADER_STAGE_FRAGMENT_BIT) {
                if (ref.id == CORE_DM_CONSTANT_ID_MATERIAL_TYPE) {
                    flags[constantId] = 0U;
                } else if (ref.id == CORE_DM_CONSTANT_ID_MATERIAL_FLAGS) {
                    flags[constantId] = 0U;
                } else if (ref.id == CORE_DM_CONSTANT_ID_LIGHTING_FLAGS) {
                    flags[constantId] = 0U;
                } else if (ref.id == CORE_DM_CONSTANT_ID_POST_PROCESS_FLAGS) {
                    // 后处理标志（取低 8 位）
                    flags[constantId] = currentRenderPPConfiguration_.flags.x;
                } else if (ref.id == CORE_DM_CONSTANT_ID_CAMERA_FLAGS) {
                    // 相机标志（雾效、多视图等）
                    flags[constantId] = currentCameraShaderFlags_;
                } else if (ref.id == CORE_DM_CONSTANT_ID_ENV_TYPE) {
                    // 环境类型（决定 Shader 如何渲染背景）
                    flags[constantId] = (uint32_t)bgType;
                }
            }
        }

        const ShaderSpecializationConstantDataView specialization { sscv.constants, flags };

        // 使用默认 Pipeline Layout（Set 0 是默认材质管线 Set）
        // 注意：不能使用反射的 Pipeline Layout，因为它需要匹配真实的 Pipeline Layout
        RenderHandle plHandle = defaultShaderData_.pl;

        const RenderHandle gfxHandle = shaderMgr.GetGraphicsStateHandleByShaderHandle(shaderHandle);

        // ========== 检查是否需要自定义资源绑定 ==========
        // 如果不是默认 Shader，检查是否有自定义 Descriptor Set
        if (!((shaderHandle == defaultShaderData_.shader) || (shaderHandle == defaultSkyShader_))) {
            plHandle = shaderMgr.GetPipelineLayoutHandleByShaderHandle(shaderHandle);
            if (!RenderHandleUtil::IsValid(plHandle)) {
                plHandle = shaderMgr.GetReflectionPipelineLayoutHandle(shaderHandle);
            }

            const auto& plData = shaderMgr.GetPipelineLayout(plHandle);

            // 检查 Set 3 或 Set 1 是否有绑定（自定义资源）
            if (!plData.descriptorSetLayouts[FIXED_CUSTOM_SET3].bindings.empty()) {
                sd.customSet = true;
                sd.customSetIndex = FIXED_CUSTOM_SET3;
            } else if (!plData.descriptorSetLayouts[FIXED_CUSTOM_SET1].bindings.empty()) {
                // 兼容旧引擎版本
                sd.customSet = true;
                sd.customSetIndex = FIXED_CUSTOM_SET1;
            }
        }

        // 获取或创建 Graphics PSO
        sd.pso = renderNodeContextMgr_->GetPsoManager().GetGraphicsPsoHandle(
            shaderHandle, gfxHandle, plHandle, {}, specialization, GetDynamicStates());
        sd.shader = shaderHandle;
    }
    return sd;
}

void RenderNodeDefaultEnv::CreateDescriptorSets()
{
    auto& descriptorSetMgr = renderNodeContextMgr_->GetDescriptorSetManager();
    {
        // automatic calculation
        const auto& renderNodeUtil = renderNodeContextMgr_->GetRenderNodeUtil();
        const DescriptorCounts dc = renderNodeUtil.GetDescriptorCounts(defaultShaderData_.plData);
        descriptorSetMgr.ResetAndReserve(dc);
    }
    {
        const uint32_t set = 3U;
        const RenderHandle descriptorSetHandle = descriptorSetMgr.CreateDescriptorSet(set, defaultShaderData_.plData);
        builtInSet3_ = descriptorSetMgr.CreateDescriptorSetBinder(
            descriptorSetHandle, defaultShaderData_.plData.descriptorSetLayouts[set].bindings);
    }
}

void RenderNodeDefaultEnv::UpdatePostProcessConfiguration()
{
    if (jsonInputs_.nodeFlags & RenderSceneFlagBits::RENDER_SCENE_DIRECT_POST_PROCESS_BIT) {
        if (!jsonInputs_.renderDataStore.dataStoreName.empty()) {
            auto const& dsMgr = renderNodeContextMgr_->GetRenderDataStoreManager();
            if (const IRenderDataStore* ds = dsMgr.GetRenderDataStore(jsonInputs_.renderDataStore.dataStoreName); ds) {
                if (jsonInputs_.renderDataStore.typeName == POST_PROCESS_DATA_STORE_TYPE_NAME) {
                    auto const dataStore = static_cast<const IRenderDataStorePod*>(ds);
                    auto const dataView = dataStore->Get(jsonInputs_.renderDataStore.configurationName);
                    if (dataView.data() && (dataView.size_bytes() == sizeof(PostProcessConfiguration))) {
                        const PostProcessConfiguration* data = (const PostProcessConfiguration*)dataView.data();
                        currentRenderPPConfiguration_ =
                            renderNodeContextMgr_->GetRenderNodeUtil().GetRenderPostProcessConfiguration(*data);
                        currentRenderPPConfiguration_.flags.x =
                            (currentRenderPPConfiguration_.flags.x & POST_PROCESS_IMPORTANT_FLAGS_MASK);
                    }
                }
            }
        }
    }
}

array_view<const DynamicStateEnum> RenderNodeDefaultEnv::GetDynamicStates() const
{
    if (fsrEnabled_) {
        return { DYNAMIC_STATES_FSR, countof(DYNAMIC_STATES_FSR) };
    } else {
        return { DYNAMIC_STATES, countof(DYNAMIC_STATES) };
    }
}

void RenderNodeDefaultEnv::ParseRenderNodeInputs()
{
    const IRenderNodeParserUtil& parserUtil = renderNodeContextMgr_->GetRenderNodeParserUtil();
    const auto jsonVal = renderNodeContextMgr_->GetNodeJson();
    jsonInputs_.renderPass = parserUtil.GetInputRenderPass(jsonVal, "renderPass");
    jsonInputs_.customCameraName = parserUtil.GetStringValue(jsonVal, "customCameraName");
    jsonInputs_.customCameraId = parserUtil.GetUintValue(jsonVal, "customCameraId");
    jsonInputs_.renderDataStore = parserUtil.GetRenderDataStore(jsonVal, "renderDataStore");

    jsonInputs_.nodeFlags = static_cast<uint32_t>(parserUtil.GetUintValue(jsonVal, "nodeFlags"));
    if (jsonInputs_.nodeFlags == ~0u) {
        jsonInputs_.nodeFlags = 0;
    }

    const auto& shaderMgr = renderNodeContextMgr_->GetShaderManager();
    jsonInputs_.renderSlotId = shaderMgr.GetRenderSlotId(parserUtil.GetStringValue(jsonVal, "renderSlot"));
    jsonInputs_.shaderRenderSlotMultiviewId =
        shaderMgr.GetRenderSlotId(parserUtil.GetStringValue(jsonVal, "shaderMultiviewRenderSlot"));
    if (jsonInputs_.renderSlotId == ~0U) {
        jsonInputs_.renderSlotId =
            shaderMgr.GetRenderSlotId(DefaultMaterialShaderConstants::RENDER_SLOT_FORWARD_ENVIRONMENT);
    }
    if (jsonInputs_.shaderRenderSlotMultiviewId == ~0U) {
        jsonInputs_.shaderRenderSlotMultiviewId =
            shaderMgr.GetRenderSlotId(DefaultMaterialShaderConstants::RENDER_SLOT_FORWARD_ENVIRONMENT + "_MV");
    }

    EvaluateFogBits();

    const auto& renderNodeUtil = renderNodeContextMgr_->GetRenderNodeUtil();
    inputRenderPass_ = renderNodeUtil.CreateInputRenderPass(jsonInputs_.renderPass);
    if ((inputRenderPass_.fragmentShadingRateAttachmentIndex < inputRenderPass_.attachments.size()) &&
        RenderHandleUtil::IsValid(
            inputRenderPass_.attachments[inputRenderPass_.fragmentShadingRateAttachmentIndex].handle)) {
        fsrEnabled_ = true;
    }
    jsonInputs_.hasChangeableRenderPassHandles = renderNodeUtil.HasChangeableResources(jsonInputs_.renderPass);

    if (jsonInputs_.customCameraId != INVALID_CAM_ID) {
        cameraName_ = to_string(jsonInputs_.customCameraId);
    } else if (!(jsonInputs_.customCameraName.empty())) {
        cameraName_ = jsonInputs_.customCameraName;
    }
}

void RenderNodeDefaultEnv::ResetRenderSlotData(const bool enableMultiview)
{
    // can be reset to multi-view usage or reset back to default usage
    if (enableMultiView_ != enableMultiview) {
        enableMultiView_ = enableMultiview;
        const auto& shaderMgr = renderNodeContextMgr_->GetShaderManager();
        defaultShaderData_ = {};
        const IShaderManager::RenderSlotData shaderRsd = shaderMgr.GetRenderSlotData(jsonInputs_.renderSlotId);
        defaultShaderData_.shader = shaderRsd.shader.GetHandle();
        defaultShaderData_.pl = shaderRsd.pipelineLayout.GetHandle();
        defaultShaderData_.plData = shaderMgr.GetPipelineLayout(defaultShaderData_.pl);
        if (enableMultiView_) {
            const IShaderManager::RenderSlotData shaderRsdMv =
                shaderMgr.GetRenderSlotData(jsonInputs_.shaderRenderSlotMultiviewId);
            defaultShaderData_.shader = shaderRsdMv.shader.GetHandle();
        }
    }
}

void RenderNodeDefaultEnv::EvaluateFogBits()
{
    // if no explicit bits set we check default render slot usages
    if ((jsonInputs_.nodeFlags & (RENDER_SCENE_ENABLE_FOG_BIT | RENDER_SCENE_DISABLE_FOG_BIT)) == 0) {
        jsonInputs_.nodeFlags |= RenderSceneFlagBits::RENDER_SCENE_ENABLE_FOG_BIT;
    }
}

// for plugin / factory interface
RENDER_NS::IRenderNode* RenderNodeDefaultEnv::Create()
{
    return new RenderNodeDefaultEnv();
}

void RenderNodeDefaultEnv::Destroy(IRenderNode* instance)
{
    delete static_cast<RenderNodeDefaultEnv*>(instance);
}
CORE3D_END_NAMESPACE()
