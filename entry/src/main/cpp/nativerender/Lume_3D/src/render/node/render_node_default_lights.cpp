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
 * @file render_node_default_lights.cpp
 * @brief 默认灯光渲染节点实现
 *
 * 执行流程：
 * 1. InitNode: 创建灯光数据 GPU 缓冲区
 * 2. PreExecuteFrame: 注册输出句柄
 * 3. ExecuteFrame: 从 DataStore 读取灯光数据，排序分类后写入 GPU 缓冲区
 */

#include "render_node_default_lights.h"

#include <algorithm>

#include <3d/render/default_material_constants.h>
#include <3d/render/intf_render_data_store_default_camera.h>
#include <3d/render/intf_render_data_store_default_light.h>
#include <3d/render/intf_render_data_store_default_scene.h>
#include <base/math/matrix_util.h>
#include <core/log.h>
#include <core/namespace.h>
#include <render/datastore/intf_render_data_store.h>
#include <render/datastore/intf_render_data_store_manager.h>
#include <render/device/intf_gpu_resource_manager.h>
#include <render/nodecontext/intf_render_node_context_manager.h>
#include <render/nodecontext/intf_render_node_graph_share_manager.h>

// NOTE: do not include in header
#include "render_light_helper.h"

namespace {
// 包含 GPU 端的灯光数据结构定义
#include <3d/shaders/common/3d_dm_structures_common.h>
} // namespace

CORE3D_BEGIN_NAMESPACE()
using namespace BASE_NS;
using namespace RENDER_NS;

namespace {
/**
 * @brief 映射 GPU 缓冲区到 CPU 内存
 * @tparam DataType 目标数据类型
 * @param gpuResourceManager GPU 资源管理器
 * @param handle 缓冲区句柄
 * @return 映射后的数据指针
 */
template<typename DataType>
DataType* MapBuffer(IRenderNodeGpuResourceManager& gpuResourceManager, const RenderHandle handle)
{
    return reinterpret_cast<DataType*>(gpuResourceManager.MapBuffer(handle));
}
} // namespace

/**
 * @brief 初始化节点 - 创建 GPU 缓冲区资源
 *
 * 步骤：
 * 1. 保存渲染节点上下文管理器引用
 * 2. 获取场景数据存储名称（Scene、Camera、Light）
 * 3. 创建灯光数据 Uniform Buffer
 * 4. 创建灯光聚类 Storage Buffer
 * 5. 注册输出句柄供其他节点使用
 */
// 疑惑点: GPU资源创建是如何创建、InitNode调用点，Output注册
void RenderNodeDefaultLights::InitNode(IRenderNodeContextManager& renderNodeContextMgr)
{
    // 保存上下文管理器引用
    renderNodeContextMgr_ = &renderNodeContextMgr;

    // 获取场景渲染数据存储名称
    // stores_ 包含：dataStoreNameScene, dataStoreNameCamera, dataStoreNameLight 等
    const auto& renderNodeGraphData = renderNodeContextMgr_->GetRenderNodeGraphData();
    stores_ = RenderNodeSceneUtil::GetSceneRenderDataStores(
        renderNodeContextMgr, renderNodeGraphData.renderNodeGraphDataStoreName);

    // 生成缓冲区名称：<SceneDataStoreName>_CORE3D_DM_LIGHT_DATA_BUFFER
    const string bufferName =
        stores_.dataStoreNameScene.c_str() + DefaultMaterialLightingConstants::LIGHT_DATA_BUFFER_NAME;
    const string clusterBufferName =
        stores_.dataStoreNameScene.c_str() + DefaultMaterialLightingConstants::LIGHT_CLUSTER_DATA_BUFFER_NAME;

    // 获取 GPU 资源管理器
    auto& gpuResourceMgr = renderNodeContextMgr.GetGpuResourceManager();

    // 创建灯光数据 Uniform Buffer
    // - 用途：Uniform Buffer (可在 Shader 中作为 uniform 访问)
    // - 内存属性：HOST_VISIBLE (CPU 可映射) + HOST_COHERENT (无需显式刷新)
    // - 创建标志：DYNAMIC_RING_BUFFER (环形缓冲，支持每帧更新)
    // - 大小：DefaultMaterialLightStruct 结构大小
    lightBufferHandle_ = gpuResourceMgr.Create(
        bufferName, {
                        CORE_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                        (CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT | CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT),
                        CORE_ENGINE_BUFFER_CREATION_DYNAMIC_RING_BUFFER,
                        sizeof(DefaultMaterialLightStruct),
                    });

    // 创建灯光聚类 Storage Buffer
    // - 用途：Storage Buffer (可在 Shader 中作为 storage 访问)
    // - 大小：聚类数量 * sizeof(uint32_t)
    lightClusterBufferHandle_ = gpuResourceMgr.Create(
        clusterBufferName, {
                               CORE_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                               (CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT | CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT),
                               CORE_ENGINE_BUFFER_CREATION_DYNAMIC_RING_BUFFER,
                               sizeof(uint32_t) * CORE_DEFAULT_MATERIAL_MAX_CLUSTERS_COUNT,
                           });

    // 注册输出句柄到 RenderNodeGraph 共享管理器
    // 其他渲染节点可以通过这些句柄访问灯光缓冲区
    if (lightBufferHandle_ && lightClusterBufferHandle_) {
        IRenderNodeGraphShareManager& rngShareMgr = renderNodeContextMgr_->GetRenderNodeGraphShareManager();
        const RenderHandle handles[] = { lightBufferHandle_.GetHandle(), lightClusterBufferHandle_.GetHandle() };
        rngShareMgr.RegisterRenderNodeOutputs(handles);
    }
}

/**
 * @brief 每帧预处理 - 重新注册输出句柄
 *
 * 每帧都需要重新注册输出句柄，确保动态环形缓冲区的当前帧句柄对其他节点可见
 */
// 疑惑点：为什么要每帧重新注册，是因为每帧都会删除掉旧的handle吗
void RenderNodeDefaultLights::PreExecuteFrame()
{
    if (lightBufferHandle_) {
        IRenderNodeGraphShareManager& rngShareMgr = renderNodeContextMgr_->GetRenderNodeGraphShareManager();
        const RenderHandle handle = lightBufferHandle_.GetHandle();
        rngShareMgr.RegisterRenderNodeOutputs({ &handle, 1u });
    }
}

/**
 * @brief 执行帧 - 收集灯光数据并写入 GPU 缓冲区
 *
 * 核心逻辑：
 * 1. 从三个 DataStore 获取数据：
 *    - IRenderDataStoreDefaultScene: 当前场景信息
 *    - IRenderDataStoreDefaultCamera: 相机列表和场景ID
 *    - IRenderDataStoreDefaultLight: 所有灯光数据
 *
 * 2. 灯光排序：
 *    - 根据场景ID排序，优先处理当前场景的灯光
 *    - 限制最大灯光数量为 CORE_DEFAULT_MATERIAL_MAX_LIGHT_COUNT
 *
 * 3. 分类统计：
 *    - 方向光 (Directional Light)
 *    - 点光源 (Point Light)
 *    - 聚光灯 (Spot Light)
 *
 * 4. 写入 GPU 缓冲区：
 *    - 灯光元数据（数量、索引）
 *    - 阴影图集信息
 *    - 每个灯光的详细数据
 */
// 疑惑点：这里的RenderDataStoreManager是所有node共享的吗，所以才能获得已经共享的三个关键数据
// 疑惑点：阴影图集信息又是什么时候注册，什么时候更新的呢？
// 疑惑点：这里的mapbuffer做了什么事情（需要溯源研究）
void RenderNodeDefaultLights::ExecuteFrame(IRenderCommandList& cmdList)
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

    // 验证数据存储有效性
    if (dataStoreScene && dataStoreLight && dataStoreCamera) {
        auto& gpuResourceMgr = renderNodeContextMgr_->GetGpuResourceManager();

        // 获取当前场景信息
        const auto scene = dataStoreScene->GetScene();
        const uint32_t sceneCameraIdx = scene.cameraIndex;  // 当前场景的主相机索引

        // 获取灯光和相机列表
        const auto& lights = dataStoreLight->GetLights();
        const auto& cameras = dataStoreCamera->GetCameras();
        const bool validCamera = (sceneCameraIdx < static_cast<uint32_t>(cameras.size()));

        // 获取阴影图集信息
        const Math::Vec4 shadowAtlasSizeInvSize = RenderLightHelper::GetShadowAtlasSizeInvSize(*dataStoreLight);
        const uint32_t shadowCount = dataStoreLight->GetLightCounts().shadowCount;

        // 映射灯光数据缓冲区到 CPU 内存
        if (auto data = MapBuffer<uint8_t>(gpuResourceMgr, lightBufferHandle_.GetHandle()); data) {
            // 注意：不要从映射的缓冲区读取数据（只用于写入）

            RenderLightHelper::LightCounts lightCounts;

            // 限制灯光数量为最大值
            const uint32_t lightCount = std::min(CORE_DEFAULT_MATERIAL_MAX_LIGHT_COUNT, (uint32_t)lights.size());

            // 获取当前场景ID，用于灯光排序
            const uint32_t sceneId = validCamera ? cameras[sceneCameraIdx].sceneId : 0U;

            // 对灯光进行排序：优先当前场景的灯光，然后按类型排序
            vector<RenderLightHelper::SortData> sortedFlags =
                RenderLightHelper::SortLights(lights, lightCount, sceneId);

            // 指向灯光数组起始位置（跳过头部元数据）
            auto* singleLightStruct =
                reinterpret_cast<DefaultMaterialSingleLightStruct*>(data + RenderLightHelper::LIGHT_LIST_OFFSET);

            // 遍历排序后的灯光，分类统计并写入缓冲区
            for (const auto& sortData : sortedFlags) {
                using UsageFlagBits = RenderLight::LightUsageFlagBits;

                // 根据灯光类型统计数量
                if (sortData.lightUsageFlags & UsageFlagBits::LIGHT_USAGE_DIRECTIONAL_LIGHT_BIT) {
                    lightCounts.directionalLightCount++;
                } else if (sortData.lightUsageFlags & UsageFlagBits::LIGHT_USAGE_POINT_LIGHT_BIT) {
                    lightCounts.pointLightCount++;
                } else if (sortData.lightUsageFlags & UsageFlagBits::LIGHT_USAGE_SPOT_LIGHT_BIT) {
                    lightCounts.spotLightCount++;
                }

                // 复制单个灯光数据到缓冲区
                RenderLightHelper::CopySingleLight(lights[sortData.index], shadowCount, singleLightStruct++);
            }

            // 写入灯光元数据到缓冲区头部
            DefaultMaterialLightStruct* lightStruct = reinterpret_cast<DefaultMaterialLightStruct*>(data);

            // 方向光：起始索引为 0，数量为统计值
            lightStruct->directionalLightBeginIndex = 0;
            lightStruct->directionalLightCount = lightCounts.directionalLightCount;

            // 点光源：紧跟方向光之后
            lightStruct->pointLightBeginIndex = lightCounts.directionalLightCount;
            lightStruct->pointLightCount = lightCounts.pointLightCount;

            // 聚光灯：紧跟点光源之后
            lightStruct->spotLightBeginIndex = lightCounts.directionalLightCount + lightCounts.pointLightCount;
            lightStruct->spotLightCount = lightCounts.spotLightCount;

            // 填充字段（对齐用）
            lightStruct->pad0 = 0;
            lightStruct->pad1 = 0;

            // 聚类相关（当前未使用）
            lightStruct->clusterSizes = Math::UVec4(0, 0, 0, 0);
            lightStruct->clusterFactors = Math::Vec4(0.0f, 0.0f, 0.0f, 0.0f);

            // 阴影图集尺寸信息：.xy = 尺寸, .zw = 1.0/尺寸
            lightStruct->atlasSizeInvSize = shadowAtlasSizeInvSize;

            // 额外因子（可用于自定义扩展）
            lightStruct->additionalFactors = { 0.0f, 0.0f, 0.0f, 0.0f };

            // 解除缓冲区映射
            gpuResourceMgr.UnmapBuffer(lightBufferHandle_.GetHandle());
        }
    }
}

// ==================== 工厂方法实现 ====================

/**
 * @brief 创建节点实例
 * @return 新分配的 RenderNodeDefaultLights 实例
 */
RENDER_NS::IRenderNode* RenderNodeDefaultLights::Create()
{
    return new RenderNodeDefaultLights();
}

/**
 * @brief 销毁节点实例
 * @param instance 要销毁的实例指针
 */
void RenderNodeDefaultLights::Destroy(IRenderNode* instance)
{
    delete static_cast<RenderNodeDefaultLights*>(instance);
}
CORE3D_END_NAMESPACE()
