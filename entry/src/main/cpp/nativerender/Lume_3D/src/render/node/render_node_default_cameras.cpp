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
 * @file render_node_default_cameras.cpp
 * @brief 默认相机渲染节点实现
 *
 * ============================================================================
 * 【功能概述】
 * ============================================================================
 * 负责处理场景中所有相机和环境数据，计算各种变换矩阵并写入 GPU 缓冲区。
 *
 * 核心职责：
 * 1. 从 DataStore 读取相机列表和环境列表
 * 2. 计算视图、投影、阴影矩阵及其逆矩阵
 * 3. 处理 TAA 抖动偏移
 * 4. 处理 Cubemap 相机
 * 5. 写入 GPU Uniform Buffer
 *
 * ============================================================================
 * 【输入】
 * ============================================================================
 * 1. IRenderDataStoreDefaultCamera
 *    - RenderCamera 列表：包含视图矩阵、投影矩阵、标志位等
 *    - Environment 列表：包含球谐系数、环境贴图因子等
 *
 * 2. IRenderDataStoreDefaultLight
 *    - 用于计算阴影偏移矩阵
 *
 * ============================================================================
 * 【输出】
 * ============================================================================
 * 1. camHandle_ (CAMERA_DATA_BUFFER)
 *    - DefaultCameraMatrixStruct 数组
 *    - 内容：view/proj/viewProj 矩阵、逆矩阵、阴影矩阵、抖动数据
 *
 * 2. envHandle_ (SCENE_ENVIRONMENT_DATA_BUFFER)
 *    - DefaultMaterialEnvironmentStruct 数组
 *    - 内容：球谐系数、环境因子、混合参数
 *
 * ============================================================================
 * 【被谁使用】
 * ============================================================================
 * - RenderNodeDefaultShadowRenderSlot: 阴影相机设置
 * - RenderNodeDefaultMaterialRenderSlot: Shader 中的相机变换
 * - RenderNodeDefaultEnv: 环境反射计算
 * - RenderNodeCameraPostProcessController: 后处理参数
 *
 * ============================================================================
 * 【执行流程】
 * ============================================================================
 * InitNode() -> 创建 GPU 缓冲区
 *     ↓
 * PreExecuteFrame() -> 重新注册输出句柄，清空 cubemap 相机
 *     ↓
 * ExecuteFrame() -> 读取 DataStore
 *                 -> 计算矩阵（view/proj/shadow）
 *                 -> 应用抖动（TAA）
 *                 -> 写入 GPU Buffer
 */

#include "render_node_default_cameras.h"

#include <3d/render/default_material_constants.h>
#include <3d/render/intf_render_data_store_default_camera.h>
#include <3d/render/intf_render_data_store_default_light.h>
#include <base/containers/allocator.h>
#include <base/math/matrix_util.h>
#include <base/math/quaternion_util.h>
#include <core/log.h>
#include <core/namespace.h>
#include <core/util/intf_frustum_util.h>
#include <render/datastore/intf_render_data_store.h>
#include <render/datastore/intf_render_data_store_manager.h>
#include <render/device/intf_gpu_resource_manager.h>
#include <render/nodecontext/intf_render_node_context_manager.h>
#include <render/nodecontext/intf_render_node_graph_share_manager.h>

namespace {
#include "3d/shaders/common/3d_dm_structures_common.h"
} // namespace

CORE3D_BEGIN_NAMESPACE()
using namespace BASE_NS;
using namespace CORE_NS;
using namespace RENDER_NS;

namespace {
// ============================================================================
// 常量定义
// ============================================================================

// 零矩阵（用于填充）
constexpr BASE_NS::Math::Mat4X4 ZERO_MATRIX_4X4 = {};

// 标准阴影偏移矩阵
// 将 NDC 坐标从 [-1, 1] 变换到 [0, 1]，用于阴影贴图采样
// [x, y] = [x * 0.5 + 0.5, y * 0.5 + 0.5]
constexpr BASE_NS::Math::Mat4X4 SHADOW_BIAS_MATRIX = BASE_NS::Math::Mat4X4 {
    0.5f, 0.0f, 0.0f, 0.0f,  // x' = x * 0.5
    0.0f, 0.5f, 0.0f, 0.0f,  // y' = y * 0.5
    0.0f, 0.0f, 1.0f, 0.0f,  // z' = z
    0.5f, 0.5f, 0.0f, 1.0f   // 偏移 +0.5
};

/**
 * @brief 计算级联阴影的偏移矩阵
 * @param shadowIndex 当前阴影级联索引
 * @param shadowCount 阴影级联总数
 * @return 偏移矩阵，用于将当前级联映射到阴影图集的对应区域
 *
 * 阴影图集布局（以 shadowCount=4 为例）：
 * ┌─────┬─────┬─────┬─────┐
 * │ S0  │ S1  │ S2  │ S3  │
 * └─────┴─────┴─────┴─────┘
 * 每个级联占用 1/shadowCount 的宽度
 */
constexpr BASE_NS::Math::Mat4X4 GetShadowBias(const uint32_t shadowIndex, const uint32_t shadowCount)
{
    const float theShadowCount = static_cast<float>(Math::max(1u, shadowCount));
    const float invShadowCount = (1.0f / theShadowCount);
    const float sc = 0.5f * invShadowCount;        // 缩放因子
    const float so = invShadowCount * static_cast<float>(shadowIndex);  // 偏移因子
    return BASE_NS::Math::Mat4X4 { sc, 0.0f, 0.0f, 0.0f, 0.0f, 0.5f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, sc + so, 0.5f,
        0.0f, 1.0f };
}

// Cubemap LOD 计算系数
constexpr float CUBE_MAP_LOD_COEFF { 8.0f };

// 默认球谐系数（当没有环境贴图时使用）
// 用于计算间接漫反射光照
constexpr BASE_NS::Math::Vec4 DEFAULT_SH_INDIRECT_COEFFICIENTS[9u] {
    { 1.0f, 1.0f, 1.0f, 1.0f },  // L0
    { 0.0f, 0.0f, 0.0f, 0.0f },  // L1
    { 0.0f, 0.0f, 0.0f, 0.0f },  // L2
    // ... 其余为零
};

// Cubemap 额外相机数量（5 个方向：-X, +Y, -Y, +Z, -Z）
// +X 方向由主相机处理
constexpr uint32_t CUBEMAP_EXTRA_CAMERA_COUNT { 5U };

// Halton 序列采样点数量（用于 TAA 抖动）
constexpr uint32_t HALTON_SAMPLE_COUNT { 16u };

/**
 * @brief 获取 Halton 序列偏移（用于 TAA 抖动）
 * @param haltonIndex 采样索引（0-15）
 * @return 归一化的偏移值 [0, 1]
 *
 * Halton 序列是一种低差异序列，产生的采样点分布均匀，
 * 适合用于 TAA 的子像素抖动，减少锯齿和闪烁。
 */
Math::Vec2 GetHaltonOffset(const uint32_t haltonIndex)
{
    // Halton 序列（基于 base-2 和 base-3）
    constexpr const Math::Vec2 halton16[] = {
        { 0.500000f, 0.333333f }, // 00
        { 0.250000f, 0.666667f }, // 01
        { 0.750000f, 0.111111f }, // 02
        { 0.125000f, 0.444444f }, // 03
        { 0.625000f, 0.777778f }, // 04
        { 0.375000f, 0.222222f }, // 05
        { 0.875000f, 0.555556f }, // 06
        { 0.062500f, 0.888889f }, // 07
        { 0.562500f, 0.037037f }, // 08
        { 0.312500f, 0.370370f }, // 09
        { 0.812500f, 0.703704f }, // 10
        { 0.187500f, 0.148148f }, // 11
        { 0.687500f, 0.481481f }, // 12
        { 0.437500f, 0.814815f }, // 13
        { 0.937500f, 0.259259f }, // 14
        { 0.031250f, 0.592593f }, // 15
    };
    return halton16[haltonIndex];
}

/**
 * @brief 生成 Cubemap 六个面的旋转矩阵
 * @param matrices 输出矩阵数组（5个，+X 由主相机处理）
 *
 * Cubemap 面布局：
 *       +Y
 *        │
 *   -X ──┼── +X
 *        │
 *       -Y
 *   +Z (前) / -Z (后)
 */
void GenerateCubemapMatrices(vector<Math::Mat4X4>& matrices)
{
    if (matrices.empty()) {
        matrices.resize(CUBEMAP_EXTRA_CAMERA_COUNT);
        // -X: 绕 Y 轴旋转 -90 度
        matrices[0U] = Mat4Cast(Math::AngleAxis((Math::DEG2RAD * -90.0f), Math::Vec3(0.0f, 1.0f, 0.0f)));
        matrices[0U] = Math::Scale(matrices[0U], { 1.f, 1.f, -1.f });
        // +Y: 绕 X 轴旋转 -90 度
        matrices[1U] = Mat4Cast(Math::AngleAxis((Math::DEG2RAD * -90.0f), Math::Vec3(1.0f, 0.0f, 0.0f)));
        matrices[1U] = Math::Scale(matrices[1U], { 1.f, 1.f, -1.f });
        // -Y: 绕 X 轴旋转 +90 度
        matrices[2U] = Mat4Cast(Math::AngleAxis((Math::DEG2RAD * 90.0f), Math::Vec3(1.0f, 0.0f, 0.0f)));
        matrices[2U] = Math::Scale(matrices[2U], { 1.f, 1.f, -1.f });
        // +Z: 绕 Y 轴旋转 180 度
        matrices[3U] = Mat4Cast(Math::AngleAxis((Math::DEG2RAD * 180.0f), Math::Vec3(0.0f, 1.0f, 0.0f)));
        matrices[3U] = Math::Scale(matrices[3U], { -1.f, 1.f, 1.f });
        // -Z: 不旋转
        matrices[4U] = Mat4Cast(Math::AngleAxis((Math::DEG2RAD * 0.0f), Math::Vec3(0.0f, 1.0f, 0.0f)));
        matrices[4U] = Math::Scale(matrices[4U], { -1.f, 1.f, 1.f });
    }
}

/**
 * @brief 将 64 位整数打包为两个 32 位无符号整数
 */
inline constexpr Math::UVec2 GetPacked64(const uint64_t value)
{
    return { static_cast<uint32_t>(value >> 32) & 0xFFFFffff, static_cast<uint32_t>(value & 0xFFFFffff) };
}

/**
 * @brief 获取多视图相机的索引信息
 * @param rds 相机 DataStore
 * @param cam 当前相机
 * @return 打包的多视图索引信息
 *
 * 用于 VR/AR 等需要多视图渲染的场景。
 */
constexpr Math::UVec4 GetMultiViewCameraIndicesFunc(const IRenderDataStoreDefaultCamera* rds, const RenderCamera& cam)
{
    Math::UVec4 mvIndices { 0U, 0U, 0U, 0U };
    CORE_STATIC_ASSERT(RenderSceneDataConstants::MAX_MULTI_VIEW_LAYER_CAMERA_COUNT == 7U);
    const uint32_t inputCount =
        Math::min(cam.multiViewCameraCount, RenderSceneDataConstants::MAX_MULTI_VIEW_LAYER_CAMERA_COUNT);
    for (uint32_t idx = 0U; idx < inputCount; ++idx) {
        const uint64_t id = cam.multiViewCameraIds[idx];
        if (id != RenderSceneDataConstants::INVALID_ID) {
            mvIndices[0U]++; // 重新计算计数
            const uint32_t index = mvIndices[0U];
            const uint32_t viewIndexShift =
                (index >= CORE_MULTI_VIEW_VIEW_INDEX_MODULO) ? CORE_MULTI_VIEW_VIEW_INDEX_SHIFT : 0U;
            const uint32_t finalViewIndex = index % CORE_MULTI_VIEW_VIEW_INDEX_MODULO;
            mvIndices[finalViewIndex] =
                (Math::min(rds->GetCameraIndex(id), CORE_DEFAULT_MATERIAL_MAX_CAMERA_COUNT - 1U) &
                    CORE_MULTI_VIEW_VIEW_INDEX_MASK)
                << viewIndexShift;
        }
    }
    return mvIndices;
}

/**
 * @brief 获取 Cubemap 多视图相机的索引信息
 */
constexpr Math::UVec4 GetCubemapMultiViewCameraIndicesFunc(
    const IRenderDataStoreDefaultCamera* rds, const RenderCamera& cam, const array_view<const uint32_t> cameraIndices)
{
    Math::UVec4 mvIndices { 0U, 0U, 0U, 0U };
    CORE_STATIC_ASSERT(RenderSceneDataConstants::MAX_MULTI_VIEW_LAYER_CAMERA_COUNT == 7U);
    constexpr uint32_t inputCount = CUBEMAP_EXTRA_CAMERA_COUNT;
    mvIndices[0U] = inputCount; // 多视图相机数量
    for (uint32_t idx = 0U; idx < inputCount; ++idx) {
        const uint32_t writeIndex = idx + 1U;
        const uint32_t viewIndexShift =
            (writeIndex >= CORE_MULTI_VIEW_VIEW_INDEX_MODULO) ? CORE_MULTI_VIEW_VIEW_INDEX_SHIFT : 0U;
        const uint32_t finalViewIndex = writeIndex % CORE_MULTI_VIEW_VIEW_INDEX_MODULO;
        const uint32_t camId = cameraIndices[idx];
        mvIndices[finalViewIndex] |=
            (Math::min(camId, CORE_DEFAULT_MATERIAL_MAX_CAMERA_COUNT - 1U) & CORE_MULTI_VIEW_VIEW_INDEX_MASK)
            << viewIndexShift;
    }
    return mvIndices;
}
} // namespace

/**
 * @brief 初始化节点 - 创建 GPU 缓冲区资源
 *
 * 步骤：
 * 1. 保存渲染节点上下文管理器引用
 * 2. 获取视锥体工具（用于计算裁剪平面）
 * 3. 获取场景数据存储名称（Scene、Camera、Light）
 * 4. 创建相机数据 Uniform Buffer
 * 5. 创建环境数据 Uniform Buffer
 * 6. 注册输出句柄供其他节点使用
 *
 * 缓冲区说明：
 * - camHandle_: 存储 DefaultCameraMatrixStruct 数组（最多 CORE_DEFAULT_MATERIAL_MAX_CAMERA_COUNT 个）
 * - envHandle_: 存储 DefaultMaterialEnvironmentStruct 数组（最多 CORE_DEFAULT_MATERIAL_MAX_ENVIRONMENT_COUNT 个）
 * - 使用 DYNAMIC_RING_BUFFER 确保帧间数据不冲突
 */
void RenderNodeDefaultCameras::InitNode(IRenderNodeContextManager& renderNodeContextMgr)
{
    // 保存上下文管理器引用（所有节点共享同一个 RenderContext）
    renderNodeContextMgr_ = &renderNodeContextMgr;

    // 获取视锥体工具（用于计算 6 个裁剪平面）
    // 从全局插件注册表获取单例
    frustumUtil_ = GetInstance<IFrustumUtil>(UID_FRUSTUM_UTIL);

    // 获取场景渲染数据存储名称
    // stores_ 包含：dataStoreNameScene, dataStoreNameCamera, dataStoreNameLight
    const auto& renderNodeGraphData = renderNodeContextMgr_->GetRenderNodeGraphData();
    stores_ = RenderNodeSceneUtil::GetSceneRenderDataStores(
        renderNodeContextMgr, renderNodeGraphData.renderNodeGraphDataStoreName);

    // 验证结构体大小满足 GPU 对齐要求（通常 256 字节）
    CORE_STATIC_ASSERT((sizeof(DefaultCameraMatrixStruct) % CORE_MIN_UNIFORM_BUFFER_OFFSET_ALIGNMENT) == 0);

    auto& gpuResourceMgr = renderNodeContextMgr.GetGpuResourceManager();

    // 创建相机数据 Uniform Buffer
    // 名称：<SceneDataStoreName>_CORE3D_DM_CAMERA_DATA_BUFFER
    // 用途：存储所有相机的矩阵数据（view/proj/shadow 等）
    {
        const string bufferName =
            stores_.dataStoreNameScene.c_str() + DefaultMaterialCameraConstants::CAMERA_DATA_BUFFER_NAME;
        camHandle_ = gpuResourceMgr.Create(
            bufferName, { CORE_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                            (CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT | CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT),
                            CORE_ENGINE_BUFFER_CREATION_DYNAMIC_RING_BUFFER,
                            sizeof(DefaultCameraMatrixStruct) * CORE_DEFAULT_MATERIAL_MAX_CAMERA_COUNT });
    }

    // 创建环境数据 Uniform Buffer
    // 名称：<SceneDataStoreName>_CORE3D_DM_SCENE_ENVIRONMENT_DATA_BUFFER
    // 用途：存储环境光照数据（球谐系数、环境贴图因子等）
    {
        const string bufferName =
            stores_.dataStoreNameScene.c_str() + DefaultMaterialSceneConstants::SCENE_ENVIRONMENT_DATA_BUFFER_NAME;
        envHandle_ = gpuResourceMgr.Create(
            bufferName, { CORE_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                            (CORE_MEMORY_PROPERTY_HOST_VISIBLE_BIT | CORE_MEMORY_PROPERTY_HOST_COHERENT_BIT),
                            CORE_ENGINE_BUFFER_CREATION_DYNAMIC_RING_BUFFER,
                            sizeof(DefaultMaterialEnvironmentStruct) * CORE_DEFAULT_MATERIAL_MAX_ENVIRONMENT_COUNT });
    }

    // 注册输出句柄到 RenderNodeGraph 共享管理器
    // 其他渲染节点可以通过这些句柄访问相机和环境缓冲区
    IRenderNodeGraphShareManager& rngShareMgr = renderNodeContextMgr_->GetRenderNodeGraphShareManager();
    const RenderHandle outputs[2U] { camHandle_.GetHandle(), envHandle_.GetHandle() };
    rngShareMgr.RegisterRenderNodeOutputs(outputs);
}

/**
 * @brief 每帧预处理 - 重新注册输出句柄，清空 Cubemap 相机
 *
 * 为什么要重新注册：
 * 1. 环形缓冲区每帧使用不同的内存区域（currentByteOffset 变化）
 * 2. BeginFrame() 会清空 renderNodeResources_[nodeIdx].outputs
 * 3. 新的句柄需要包含当前帧的偏移信息
 *
 * 清空 cubemapCameras_ 的原因：
 * Cubemap 相机是动态生成的（从普通相机派生），每帧需要重新创建
 */
void RenderNodeDefaultCameras::PreExecuteFrame()
{
    // 重新注册输出句柄（环形缓冲区偏移每帧变化）
    IRenderNodeGraphShareManager& rngShareMgr = renderNodeContextMgr_->GetRenderNodeGraphShareManager();
    const RenderHandle outputs[2U] { camHandle_.GetHandle(), envHandle_.GetHandle() };
    rngShareMgr.RegisterRenderNodeOutputs(outputs);

    // 清空 Cubemap 相机列表（每帧动态生成）
    cubemapCameras_.clear();
}

/**
 * @brief 执行帧 - 收集相机和环境数据，计算矩阵并写入 GPU 缓冲区
 *
 * 核心流程：
 * 1. 从 DataStore 获取相机和环境列表
 * 2. 映射 Camera Buffer，计算矩阵并写入
 *    - 普通相机：直接从 cameras 列表处理
 *    - Cubemap 相机：从 cubemapCameras_ 处理（动态生成）
 * 3. 更新抖动索引（用于下一帧 TAA）
 * 4. 映射 Environment Buffer，写入环境数据
 *
 * GPU 缓冲区布局：
 * Camera Buffer:
 *   [普通相机区域] [Cubemap 相机区域]
 *   每个相机占用 sizeof(DefaultCameraMatrixStruct)
 *
 * Environment Buffer:
 *   每个环境占用 sizeof(DefaultMaterialEnvironmentStruct)
 */
void RenderNodeDefaultCameras::ExecuteFrame(IRenderCommandList& cmdList)
{
    // 获取渲染数据存储管理器（全局唯一，所有节点共享）
    const auto& renderDataStoreMgr = renderNodeContextMgr_->GetRenderDataStoreManager();

    // 获取三个关键数据存储
    // - dsCamera: 相机和环境列表
    // - dsLight: 灯光数据（用于阴影矩阵计算）
    const IRenderDataStoreDefaultCamera* dsCamera =
        static_cast<IRenderDataStoreDefaultCamera*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameCamera));
    const IRenderDataStoreDefaultLight* dsLight =
        static_cast<IRenderDataStoreDefaultLight*>(renderDataStoreMgr.GetRenderDataStore(stores_.dataStoreNameLight));

    // 验证相机数据存储有效性
    if (!dsCamera) {
        return;
    }

    // 获取相机和环境列表
    const auto& cameras = dsCamera->GetCameras();
    const auto& environments = dsCamera->GetEnvironments();

    // 如果没有相机和环境，直接返回
    if (cameras.empty() && environments.empty()) {
        return;
    }

    // 获取 GPU 资源管理器
    const auto& gpuResMgr = renderNodeContextMgr_->GetGpuResourceManager();

    // 映射并填充 Camera Buffer
    if (uint8_t* data = reinterpret_cast<uint8_t*>(gpuResMgr.MapBuffer(camHandle_.GetHandle())); data) {
        const uint32_t originalCameraCount = static_cast<uint32_t>(cameras.size());

        // 添加普通相机到 GPU 缓冲区（从索引 0 开始）
        AddCameras(dsCamera, dsLight, cameras, data, 0U);

        // 添加 Cubemap 相机到 GPU 缓冲区（从 originalCameraCount 索引开始）
        // Cubemap 相机是在 AddCameras 中动态生成的
        AddCameras(dsCamera, dsLight, cubemapCameras_, data, originalCameraCount);

        // 解除缓冲区映射
        gpuResMgr.UnmapBuffer(camHandle_.GetHandle());
    }

    // 更新抖动索引（循环使用 Halton 序列的 16 个采样点）
    jitterIndex_ = (jitterIndex_ + 1) % HALTON_SAMPLE_COUNT;

    // 映射并填充 Environment Buffer
    if (uint8_t* data = reinterpret_cast<uint8_t*>(gpuResMgr.MapBuffer(envHandle_.GetHandle())); data) {
        // 添加环境数据到 GPU 缓冲区
        AddEnvironments(dsCamera, environments, data);

        // 解除缓冲区映射
        gpuResMgr.UnmapBuffer(envHandle_.GetHandle());
    }
}

/**
 * @brief 添加相机数据到 GPU 缓冲区
 *
 * @param dsCamera 相机 DataStore（用于获取多视图相机索引）
 * @param dsLight 灯光 DataStore（用于获取阴影偏移矩阵）
 * @param cameras 相机列表（普通相机或 Cubemap 相机）
 * @param data GPU 缓冲区映射指针
 * @param cameraOffset 写入起始索引（普通相机从 0 开始，Cubemap 相机从 originalCameraCount 开始）
 *
 * 每个相机计算并写入的数据：
 * 1. 视图矩阵 (view) 和逆矩阵 (viewInv)
 * 2. 投影矩阵 (proj) 和逆矩阵 (projInv)
 * 3. 视图-投影组合矩阵 (viewProj) 和逆矩阵
 * 4. 上一帧的矩阵（用于 TAA/运动模糊）
 * 5. 阴影视图-投影矩阵（带级联偏移）
 * 6. 抖动偏移（TAA）
 * 7. 相机 ID 和层遮罩
 * 8. 多视图索引（VR/AR）
 * 9. 视锥体裁剪平面（用于物体裁剪）
 *
 * 矩阵计算顺序：
 * view = ResolveViewMatrix(camera)  // 处理 Cubemap 旋转
 * proj = GetProjectionMatrix(camera)  // 应用 TAA 抖动
 * viewProj = proj * view
 * shadowViewProj = shadowBias * viewProj  // 级联阴影偏移
 */
void RenderNodeDefaultCameras::AddCameras(const IRenderDataStoreDefaultCamera* dsCamera,
    const IRenderDataStoreDefaultLight* dsLight, const array_view<const RenderCamera> cameras, uint8_t* const data,
    const uint32_t cameraOffset)
{
    // 计算实际写入的相机数量（不超过最大值）
    const uint32_t cameraCount = static_cast<uint32_t>(
        Math::max(0, Math::min(static_cast<int32_t>(CORE_DEFAULT_MATERIAL_MAX_CAMERA_COUNT - cameraOffset),
                         static_cast<int32_t>(cameras.size()))));

    // 遍历每个相机，计算矩阵并写入 GPU 缓冲区
    for (uint32_t idx = 0; idx < cameraCount; ++idx) {
        const auto& currCamera = cameras[idx];

        // 计算当前相机的 GPU 缓冲区地址（考虑偏移）
        // 布局：data + sizeof(DefaultCameraMatrixStruct) * (idx + cameraOffset)
        auto dat = reinterpret_cast<DefaultCameraMatrixStruct* const>(
            data + sizeof(DefaultCameraMatrixStruct) * (idx + cameraOffset));

        // ========== 基本矩阵计算 ==========

        // 获取视图矩阵（处理 Cubemap 相机的额外旋转）
        const auto view = ResolveViewMatrix(currCamera);

        // 获取投影矩阵（带 TAA 抖动）
        const JitterProjection jp = GetProjectionMatrix(currCamera, false);

        // 计算视图-投影组合矩阵
        const Math::Mat4X4 viewProj = jp.proj * view;

        // 写入当前帧矩阵
        dat->view = view;
        dat->proj = jp.proj;
        dat->viewProj = viewProj;

        // ========== 逆矩阵计算 ==========

        // 计算逆矩阵（用于世界坐标重建、反射等）
        dat->viewInv = Math::Inverse(view);
        dat->projInv = Math::Inverse(jp.proj);
        dat->viewProjInv = Math::Inverse(viewProj);

        // ========== 上一帧矩阵（用于 TAA 和运动模糊） ==========

        // 获取上一帧投影矩阵（带抖动）
        const JitterProjection jpPrevFrame = GetProjectionMatrix(currCamera, true);

        // 计算上一帧的视图-投影组合矩阵
        const Math::Mat4X4 viewProjPrevFrame = jpPrevFrame.proj * currCamera.matrices.viewPrevFrame;

        // 写入上一帧矩阵
        dat->viewPrevFrame = currCamera.matrices.viewPrevFrame;
        dat->projPrevFrame = jpPrevFrame.proj;
        dat->viewProjPrevFrame = viewProjPrevFrame;

        // ========== 阴影矩阵 ==========

        // 计算阴影视图-投影矩阵（带级联偏移）
        // shadowViewProj = GetShadowBiasMatrix() * viewProj
        // 将 NDC [-1,1] 变换到阴影图集的对应区域 [0,1/shadowCount]
        const Math::Mat4X4 shadowViewProj = GetShadowBiasMatrix(dsLight, currCamera) * viewProj;
        dat->shadowViewProj = shadowViewProj;
        dat->shadowViewProjInv = Math::Inverse(shadowViewProj);

        // ========== 抖动数据（TAA） ==========

        // 写入抖动偏移（用于 Shader 中的 TAA 计算）
        dat->jitter = jp.jitter;
        dat->jitterPrevFrame = jpPrevFrame.jitter;

        // ========== 索引和标识 ==========

        // 将 64 位 ID 和层遮罩打包为两个 32 位整数
        const Math::UVec2 packedId = GetPacked64(currCamera.id);
        const Math::UVec2 packedLayer = GetPacked64(currCamera.layerMask);
        dat->indices = { packedId.x, packedId.y, packedLayer.x, packedLayer.y };

        // 获取多视图相机索引（用于 VR/AR 渲染）
        // 如果是 Cubemap 相机，会在此处动态生成额外的 Cubemap 相机
        dat->multiViewIndices = GetMultiViewCameraIndices(dsCamera, currCamera, cameraCount);

        // ========== 视锥体裁剪平面 ==========

        // 计算 6 个视锥体裁剪平面（用于物体可见性判断）
        // 注意：使用不带抖动的投影矩阵（baseProj）计算，避免抖动影响裁剪精度
        if (frustumUtil_) {
            const Frustum frustum = frustumUtil_->CreateFrustum(jp.baseProj * view);
            CloneData(dat->frustumPlanes, CORE_DEFAULT_CAMERA_FRUSTUM_PLANE_COUNT * sizeof(Math::Vec4), frustum.planes,
                Frustum::PLANE_COUNT * sizeof(Math::Vec4));
        }

        // ========== 填充数据 ==========

        // 多环境数量（用于环境光照混合）
        dat->counts = { currCamera.environment.multiEnvCount, 0U, 0U, 0U };
        dat->pad0 = { 0U, 0U, 0U, 0U };
        dat->matPad0 = ZERO_MATRIX_4X4;
        dat->matPad1 = ZERO_MATRIX_4X4;
    }
}

/**
 * @brief 获取多视图相机索引信息
 *
 * @param rds 相机 DataStore
 * @param cam 当前相机
 * @param cameraCount 当前已处理的相机数量（用于计算 Cubemap 相机的起始索引）
 * @return 打包的多视图索引信息
 *
 * 功能：
 * 1. 如果是 Cubemap 相机：
 *    - 动态生成 5 个额外方向的相机（-X, +Y, -Y, +Z, -Z）
 *    - 添加到 cubemapCameras_ 列表
 *    - 返回这些相机的索引信息
 *
 * 2. 如果是普通多视图相机：
 *    - 返回配置的多视图相机索引（用于 VR/AR）
 *
 * Cubemap 相机生成原理：
 * - 主相机处理 +X 方向
 * - 生成 5 个额外相机处理其他方向
 * - 每个方向有不同的旋转矩阵
 */
BASE_NS::Math::UVec4 RenderNodeDefaultCameras::GetMultiViewCameraIndices(
    const IRenderDataStoreDefaultCamera* rds, const RenderCamera& cam, const uint32_t cameraCount)
{
    // 检查是否是 Cubemap 相机
    if (cam.flags & RenderCamera::CameraFlagBits::CAMERA_FLAG_CUBEMAP_BIT) {
        // ========== 生成 Cubemap 额外方向的相机 ==========

        // 记录当前 Cubemap 相机数量（用于计算新增相机的索引）
        const size_t currSize = cubemapCameras_.size();

        // 扩展列表，添加 5 个额外方向
        cubemapCameras_.resize(currSize + CUBEMAP_EXTRA_CAMERA_COUNT);

        // 生成 Cubemap 旋转矩阵（如果尚未生成）
        GenerateCubemapMatrices(cubemapMatrices_);

        // 计算新增相机在 GPU 缓冲区中的索引
        // 紧跟在普通相机和已生成的 Cubemap 相机之后
        const uint32_t startCameraIndex = cameraCount + static_cast<uint32_t>(currSize);
        const uint32_t camIndices[CUBEMAP_EXTRA_CAMERA_COUNT] = {
            startCameraIndex + 0U,  // -X 方向
            startCameraIndex + 1U,  // +Y 方向
            startCameraIndex + 2U,  // -Y 方向
            startCameraIndex + 3U,  // +Z 方向
            startCameraIndex + 4U,  // -Z 方向
        };

        // 创建每个方向的相机数据
        for (size_t idx = 0; idx < CUBEMAP_EXTRA_CAMERA_COUNT; ++idx) {
            CORE_ASSERT(currSize + idx < cubemapCameras_.size());
            CORE_ASSERT(idx < cubemapMatrices_.size());

            // 复制主相机的基础数据
            auto& currCamera = cubemapCameras_[currSize + idx];
            currCamera = cam;

            // 清除 Cubemap 标志（避免再次生成）
            currCamera.flags = 0U;

            // 应用方向旋转矩阵到视图矩阵
            // view = cubemapMatrix * originalView
            currCamera.matrices.view = cubemapMatrices_[idx] * currCamera.matrices.view;
            currCamera.matrices.viewPrevFrame = currCamera.matrices.view;
        }

        // 返回 Cubemap 多视图索引信息
        return GetCubemapMultiViewCameraIndicesFunc(rds, cam, { camIndices, CUBEMAP_EXTRA_CAMERA_COUNT });
    } else {
        // 普通多视图相机（VR/AR 配置）
        return GetMultiViewCameraIndicesFunc(rds, cam);
    }
}

/**
 * @brief 解析视图矩阵，处理 Cubemap 相机的额外旋转
 *
 * @param camera 相机数据
 * @return 解析后的视图矩阵
 *
 * Cubemap 相机需要额外处理：
 * - +X 方向（主相机）：绕 Y 轴旋转 90 度
 * - 这是 RenderNode 中对 Cubemap +X 面的处理
 *
 * 其他方向（-X, +Y, -Y, +Z, -Z）的旋转已在 cubemapMatrices_ 中预计算
 */
BASE_NS::Math::Mat4X4 RenderNodeDefaultCameras::ResolveViewMatrix(const RenderCamera& camera) const
{
    // 获取基础视图矩阵
    auto view = camera.matrices.view;

    // 如果是 Cubemap 相机（主相机处理 +X 方向）
    if (camera.flags & RenderCamera::CAMERA_FLAG_CUBEMAP_BIT) {
        // 应用 +X 方向的旋转：绕 Y 轴旋转 90 度
        Math::Mat4X4 temporary = Mat4Cast(Math::AngleAxis((Math::DEG2RAD * 90.0f), Math::Vec3(0.0f, 1.0f, 0.0f)));
        temporary = Math::Scale(temporary, { 1.f, 1.f, -1.f });
        view = temporary * view;
    }

    return view;
}

/**
 * @brief 获取投影矩阵，处理 TAA 抖动
 *
 * @param camera 相机数据
 * @param prevFrame 是否获取上一帧的投影矩阵
 * @return 包含基础投影、抖动投影和抖动偏移的结构体
 *
 * TAA (Temporal Anti-Aliasing) 抖动原理：
 * 1. 每帧在投影矩阵中添加微小的偏移
 * 2. 偏移值来自 Halton 序列（低差异采样）
 * 3. Shader 中使用当前帧和上一帧的抖动值计算运动向量
 * 4. 多帧累积实现抗锯齿效果
 *
 * 投影矩阵抖动应用方式：
 * proj[2][0] += jitterOffset.x / renderResolution.x
 * proj[2][1] += jitterOffset.y / renderResolution.y
 *
 * 这会在 NDC 空间产生子像素偏移，从而改变采样位置
 */
RenderNodeDefaultCameras::JitterProjection RenderNodeDefaultCameras::GetProjectionMatrix(
    const RenderCamera& camera, const bool prevFrame) const
{
    JitterProjection jp;

    // 获取基础投影矩阵（当前帧或上一帧）
    jp.baseProj = prevFrame ? camera.matrices.projPrevFrame : camera.matrices.proj;
    jp.proj = jp.baseProj;

    // 如果相机启用了抖动标志（TAA）
    if (camera.flags & RenderCamera::CameraFlagBits::CAMERA_FLAG_JITTER_BIT) {
        // 注意：当前实现使用相同的抖动值处理两帧，以产生零速度
        // 这是为了在静态场景中避免运动模糊伪影
        const uint32_t jitterIndex = jitterIndex_;

        // 计算渲染分辨率（确保至少为 1）
        const Math::Vec2 renderRes = Math::Vec2(static_cast<float>(Math::max(1u, camera.renderResolution.x)),
            static_cast<float>(Math::max(1u, camera.renderResolution.y)));

        // 从 Halton 序列获取偏移值（归一化坐标 [0, 1]）
        const Math::Vec2 haltonOffset = GetHaltonOffset(jitterIndex);

        // 转换为像素偏移并归一化到 NDC 空间
        // haltonOffset * 2 - 1 将 [0, 1] 变换到 [-1, 1]
        // 再除以分辨率得到像素级别的偏移
        const Math::Vec2 haltonOffsetRes =
            Math::Vec2((haltonOffset.x * 2.0f - 1.0f) / renderRes.x, (haltonOffset.y * 2.0f - 1.0f) / renderRes.y);

        // 存储抖动数据供 Shader 使用
        // .xy = Halton 偏移（归一化）, .zw = 像素偏移（NDC）
        jp.jitter = Math::Vec4(haltonOffset.x, haltonOffset.y, haltonOffsetRes.x, haltonOffsetRes.y);

        // 将偏移应用到投影矩阵
        // proj[2][0] 和 proj[2][1] 控制投影的偏移
        jp.proj[2U][0U] += haltonOffsetRes.x;
        jp.proj[2U][1U] += haltonOffsetRes.y;
    }

    return jp;
}

/**
 * @brief 获取阴影偏移矩阵
 *
 * @param dataStore 灯光 DataStore（用于获取阴影级联信息）
 * @param camera 相机数据（包含关联的阴影灯光 ID）
 * @return 阴影偏移矩阵
 *
 * 级联阴影映射 (Cascade Shadow Maps) 原理：
 * 1. 将阴影贴图划分为多个级联区域
 * 2. 每个级联覆盖不同的深度范围
 * 3. 近处级联精度高，远处级联精度低
 * 4. 所有级联存储在同一张阴影图集中
 *
 * 偏移矩阵的作用：
 * - 将当前相机关联的阴影级联映射到图集的对应区域
 * - 例如，如果 shadowIndex = 1，shadowCount = 4
 *   则阴影坐标会被变换到图集的第二个区域 [0.25, 0.5]
 *
 * 查找逻辑：
 * 遍历灯光列表，找到与当前相机 shadowId 匹配的灯光
 * 使用该灯光的 shadowIndex 计算偏移矩阵
 */
BASE_NS::Math::Mat4X4 RenderNodeDefaultCameras::GetShadowBiasMatrix(
    const IRenderDataStoreDefaultLight* dataStore, const RenderCamera& camera) const
{
    // 如果有灯光数据存储
    if (dataStore) {
        // 获取灯光统计信息（包含阴影数量）
        const auto lightCounts = dataStore->GetLightCounts();
        const uint32_t shadowCount = lightCounts.shadowCount;

        // 获取所有灯光列表
        const auto lights = dataStore->GetLights();

        // 遍历灯光，找到与当前相机关联的阴影灯光
        for (const auto& lightRef : lights) {
            if (lightRef.id == camera.shadowId) {
                // 找到匹配的灯光，使用其 shadowIndex 计算偏移矩阵
                // shadowIndex 表示该灯光在级联序列中的位置
                return GetShadowBias(lightRef.shadowIndex, shadowCount);
            }
        }
    }

    // 如果没有找到匹配的灯光，使用标准偏移矩阵
    // 将 NDC [-1, 1] 变换到 [0, 1]
    return SHADOW_BIAS_MATRIX;
}

namespace {
/**
 * @brief 获取多环境混合的索引信息
 *
 * @param env 当前环境数据
 * @param envs 所有环境列表
 * @return 打包的多环境索引信息
 *
 * 多环境混合用于：
 * - 室内外环境过渡（从一个环境渐变到另一个）
 * - 层叠环境效果（叠加多个环境光照）
 *
 * 返回值格式：
 * - [0] = 混合环境数量（最多 3 个）
 * - [1] = 第一个混合环境的索引
 * - [2] = 第二个混合环境的索引
 * - [3] = 第三个混合环境的索引
 *
 * 主环境索引不在此处存储，由 Shader 通过相机数据获取
 */
Math::UVec4 GetMultiEnvironmentIndices(
    const RenderCamera::Environment& env, const array_view<const RenderCamera::Environment> envs)
{
    if (env.multiEnvCount > 0U) {
        Math::UVec4 multiEnvIndices = { 0U, 0U, 0U, 0U };

        // 第一个值存储混合环境数量
        // 第一个索引是主环境，后续索引是混合环境
        const uint32_t maxEnvCount = Math::min(env.multiEnvCount, 3U);

        for (uint32_t idx = 0U; idx < maxEnvCount; ++idx) {
            multiEnvIndices[0U]++;  // 增加计数

            // 在环境列表中查找匹配的环境 ID
            uint32_t multiEnvIdx = 0U;
            for (uint32_t envIdx = 0U; envIdx < static_cast<uint32_t>(envs.size()); ++envIdx) {
                const auto& envRef = envs[envIdx];
                if (envRef.id == env.multiEnvIds[idx]) {
                    multiEnvIdx = envIdx;  // 找到匹配的环境索引
                }
            }

            // 存储环境索引（索引 + 1，因为 [0] 存储计数）
            CORE_ASSERT(idx + 1U <= 3U);
            multiEnvIndices[idx + 1U] = multiEnvIdx;
        }

        return multiEnvIndices;
    } else {
        // 没有多环境混合，返回零
        return { 0U, 0U, 0U, 0U };
    }
}
} // namespace

/**
 * @brief 添加环境数据到 GPU 缓冲区
 *
 * @param dsCamera 相机 DataStore
 * @param environments 环境列表
 * @param data GPU 缓冲区映射指针
 *
 * 每个环境写入的数据：
 * 1. 间接高光因子 (indirectSpecularFactor) - 用于环境反射
 * 2. 间接漫反射因子 (indirectDiffuseFactor) - 用于基于图像的光照
 * 3. 环境贴图因子 (envMapFactor) - 用于天空盒和环境反射强度
 * 4. LOD 参数 - 用于辐射度 Cubemap 的 LOD 级别选择
 * 5. 混合因子 (blendFactor) - 用于多环境过渡
 * 6. 旋转矩阵 (rotation) - 用于环境贴图旋转
 * 7. 球谐系数 (shIndirectCoefficients) - 用于间接漫反射光照计算
 * 8. 多环境索引 - 用于环境混合
 *
 * 球谐系数说明：
 * - L0-L2 级球谐系数，共 9 个向量
 * - 用于快速计算间接漫反射光照
 * - 如果没有环境贴图，使用默认系数（只有 L0 为 1）
 */
void RenderNodeDefaultCameras::AddEnvironments(const IRenderDataStoreDefaultCamera* dsCamera,
    const array_view<const RenderCamera::Environment> environments, uint8_t* const data)
{
    CORE_ASSERT(data);

    // 计算缓冲区结束地址（用于边界检查）
    const auto* dataEnd = data + sizeof(DefaultMaterialEnvironmentStruct) * CORE_DEFAULT_MATERIAL_MAX_ENVIRONMENT_COUNT;

    // 计算实际写入的环境数量（不超过最大值）
    const uint32_t envCount = static_cast<uint32_t>(
        Math::min(CORE_DEFAULT_MATERIAL_MAX_ENVIRONMENT_COUNT, static_cast<uint32_t>(environments.size())));

    // 遍历每个环境，写入 GPU 缓冲区
    for (uint32_t idx = 0; idx < envCount; ++idx) {
        // 计算当前环境的 GPU 缓冲区地址
        auto* dat = data + (sizeof(DefaultMaterialEnvironmentStruct) * idx);

        const auto& currEnv = environments[idx];

        // 获取多环境混合索引
        const Math::UVec4 multiEnvIndices = GetMultiEnvironmentIndices(currEnv, environments);

        // 打包 64 位 ID 和层遮罩为两个 32 位整数
        const Math::UVec2 id = GetPacked64(currEnv.id);
        const Math::UVec2 layer = GetPacked64(currEnv.layerMask);

        // 计算辐射度 Cubemap LOD 系数
        // 用于在 Shader 中选择合适的 LOD 级别
        // CUBE_MAP_LOD_COEFF = 8.0，限制最大 LOD 级别
        const float radianceCubemapLodCoeff =
            (currEnv.radianceCubemapMipCount != 0)
                ? Math::min(CUBE_MAP_LOD_COEFF, static_cast<float>(currEnv.radianceCubemapMipCount))
                : CUBE_MAP_LOD_COEFF;

        // 构建环境结构体
        // 注意：因子存储时已经包含了 w 分量（强度）
        DefaultMaterialEnvironmentStruct envStruct {
            // 间接高光因子（用于环境反射）
            // RGB * A，其中 A 是强度系数
            Math::Vec4((Math::Vec3(currEnv.indirectSpecularFactor) * currEnv.indirectSpecularFactor.w),
                currEnv.indirectSpecularFactor.w),

            // 间接漫反射因子（用于 IBL）
            Math::Vec4(Math::Vec3(currEnv.indirectDiffuseFactor) * currEnv.indirectDiffuseFactor.w,
                currEnv.indirectDiffuseFactor.w),

            // 环境贴图因子
            Math::Vec4(Math::Vec3(currEnv.envMapFactor) * currEnv.envMapFactor.w, currEnv.envMapFactor.w),

            // LOD 参数：LOD 系数、LOD 级别
            Math::Vec4(radianceCubemapLodCoeff, currEnv.envMapLodLevel, 0.0f, 0.0f),

            // 环境混合因子（用于多环境过渡）
            currEnv.blendFactor,

            // 环境旋转矩阵（用于旋转环境贴图）
            Math::Mat4Cast(currEnv.rotation),

            // ID 和层遮罩
            Math::UVec4(id.x, id.y, layer.x, layer.y),

            // 球谐系数（稍后填充）
            {},  // shIndirectCoefficients 占位

            // 多环境索引
            multiEnvIndices,

            // 填充字段
            {},
            {},
        };

        // ========== 球谐系数填充 ==========

        constexpr size_t countOfSh = countof(envStruct.shIndirectCoefficients);

        // 如果有辐射度 Cubemap 或多环境混合，使用环境提供的球谐系数
        // 否则使用默认系数（只有 L0 = 1，其余为 0）
        if (currEnv.radianceCubemap || (currEnv.multiEnvCount > 0U)) {
            // 复制环境提供的球谐系数（用于精确的间接光照）
            for (size_t jdx = 0; jdx < countOfSh; ++jdx) {
                envStruct.shIndirectCoefficients[jdx] = currEnv.shIndirectCoefficients[jdx];
            }
        } else {
            // 使用默认球谐系数（简单的白色环境光）
            for (size_t jdx = 0; jdx < countOfSh; ++jdx) {
                envStruct.shIndirectCoefficients[jdx] = DEFAULT_SH_INDIRECT_COEFFICIENTS[jdx];
            }
        }

        // ========== 写入 GPU 缓冲区 ==========

        // 将结构体数据复制到 GPU 缓冲区
        // 检查缓冲区边界，防止溢出
        if (!CloneData(dat, size_t(dataEnd - dat), &envStruct, sizeof(DefaultMaterialEnvironmentStruct))) {
            CORE_LOG_E("environment ubo copying failed.");
        }
    }
}

// ============================================================================
// 工厂方法实现
// ============================================================================

/**
 * @brief 创建节点实例
 * @return 新分配的 RenderNodeDefaultCameras 实例
 *
 * 工厂方法由 RenderNodeManager 调用：
 * 1. 从 .rng 配置文件读取 typeName = "RenderNodeDefaultCameras"
 * 2. 通过插件注册表找到对应的 createNode 函数
 * 3. 调用此 Create() 方法创建实例
 *
 * 注册流程：
 * - static_plugin.cpp 中调用 FillRenderNodeTypeInfo()
 * - 将 typeName 映射到 Create() 和 Destroy() 函数指针
 */
RENDER_NS::IRenderNode* RenderNodeDefaultCameras::Create()
{
    return new RenderNodeDefaultCameras();
}

/**
 * @brief 销毁节点实例
 * @param instance 要销毁的实例指针
 *
 * 在渲染器关闭或节点图重新加载时调用
 */
void RenderNodeDefaultCameras::Destroy(IRenderNode* instance)
{
    delete static_cast<RenderNodeDefaultCameras*>(instance);
}

CORE3D_END_NAMESPACE()
