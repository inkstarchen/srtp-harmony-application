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

#ifndef RENDER_NODECONTEXT_RENDER_NODE_GRAPH_NODE_STORE_H
#define RENDER_NODECONTEXT_RENDER_NODE_GRAPH_NODE_STORE_H

#include <base/containers/string.h>
#include <base/containers/string_view.h>
#include <base/containers/unique_ptr.h>
#include <base/containers/vector.h>
#include <render/namespace.h>
#include <render/nodecontext/intf_render_node.h>
#include <render/render_data_structures.h>

#include "nodecontext/node_context_descriptor_set_manager.h"
#include "nodecontext/node_context_pool_manager.h"
#include "nodecontext/node_context_pso_manager.h"
#include "nodecontext/render_barrier_list.h"
#include "nodecontext/render_command_list.h"
#include "nodecontext/render_node_context_manager.h"
#include "nodecontext/render_node_graph_share_manager.h"
#include "nodecontext/render_node_manager.h"

RENDER_BEGIN_NAMESPACE()
class IRenderBackendNode;
class RenderFrameSync;
class RenderFrameUtil;
class RenderNodeGpuResourceManager;

//提交的依赖
struct SubmitDependencies {
    // should this command buffer signal when submitting
    bool signalSemaphore { false };
    // valid command buffer indices for wait semaphores
    uint32_t waitSemaphoreCount { 0u };
    // render node indices or actual render command context indices (depending on the use context)
    uint32_t waitSemaphoreNodeIndices[PipelineStateConstants::MAX_RENDER_NODE_GPU_WAIT_SIGNALS] {};
    // wait for acquired swapchain image
    bool waitForSwapchainAcquireSignal { false };
};

// 一个渲染指令的上下文，它所需要知道的信息
struct RenderCommandContext {
    // if backend specific node code
    IRenderBackendNode* renderBackendNode { nullptr };
    RenderCommandList* renderCommandList { nullptr };
    RenderBarrierList* renderBarrierList { nullptr };
    NodeContextPsoManager* nodeContextPsoMgr { nullptr };
    NodeContextDescriptorSetManager* nodeContextDescriptorSetMgr { nullptr };
    NodeContextPoolManager* nodeContextPoolMgr { nullptr };

    uint32_t renderGraphRenderNodeIndex { ~0u };
    SubmitDependencies submitDepencies;

    BASE_NS::string_view debugName; // full node name with RNG name + node name
};


// 一个渲染帧的数据，依赖于多个指令
struct RenderCommandFrameData {
    BASE_NS::vector<RenderCommandContext> renderCommandContexts;
    RenderFrameSync* renderFrameSync { nullptr };
    RenderFrameUtil* renderFrameUtil { nullptr };
    // the index of the first render node in backend which needs swapchain acquired image
    // 第一个需要直接画在画布上的
    uint32_t firstSwapchainNodeIdx { ~0u };
};

struct RenderNodeContextData {
    struct CpuDependency {
        BASE_NS::vector<RenderDataConstants::RenderDataFixedString> cpuDependencyWaitRenderNodes;
    };

    // 所依赖的CPU计算的节点名称
    CpuDependency cpuDependency;
    SubmitDependencies submitInfo;

    // 这个渲染节点的命令
    BASE_NS::unique_ptr<RenderCommandList> renderCommandList;
    // 这个渲染节点的屏障
    BASE_NS::unique_ptr<RenderBarrierList> renderBarrierList;

    // 相关的管理器
    BASE_NS::unique_ptr<RenderNodeContextManager> renderNodeContextManager;
    BASE_NS::unique_ptr<NodeContextPsoManager> nodeContextPsoMgr;
    BASE_NS::unique_ptr<NodeContextDescriptorSetManager> nodeContextDescriptorSetMgr;
    BASE_NS::unique_ptr<NodeContextPoolManager> nodeContextPoolMgr;

    // with dynamic render node graphs we need initilization data per render node
    // 如果是动态渲染的节点图，我们就需要每个节点都初始化数据，只有在动态图中使用
    bool initialized { false };

    // optional render backend node pointer
    // （可选）渲染后端的指针
    IRenderBackendNode* renderBackendNode { nullptr };
};

struct RenderNodeGraphShareData {
    // render node graph inputs/outputs which can be set through render node graph manager
    static constexpr uint32_t MAX_RENDER_NODE_GRAPH_RES_COUNT { 4u };
    IRenderNodeGraphShareManager::NamedResource inputs[MAX_RENDER_NODE_GRAPH_RES_COUNT] { {}, {}, {}, {} };
    IRenderNodeGraphShareManager::NamedResource outputs[MAX_RENDER_NODE_GRAPH_RES_COUNT] { {}, {}, {}, {} };
    uint32_t inputCount { 0 };
    uint32_t outputCount { 0 };
};

/**
 * RenderNodeGraphNodeStore.
 * Store render nodes and related data per render node graph.
 * NOTE: When running the render node graphs, the real global name used is render node graph name + render node name
 */
struct RenderNodeGraphNodeStore {
    
    struct RenderNodeData {
        BASE_NS::unique_ptr<IRenderNode, RenderNodeTypeInfo::DestroyRenderNodeFn> node;
        RenderDataConstants::RenderDataFixedString typeName;
        RenderDataConstants::RenderDataFixedString fullName; // rng name + node name
        RenderDataConstants::RenderDataFixedString nodeName; // node name
        // NOTE: should be cleared after first init if not dev-mode
        BASE_NS::unique_ptr<RenderNodeGraphInputs> inputData;
        BASE_NS::string nodeJson;
    };
    BASE_NS::vector<RenderNodeData> renderNodeData;
    BASE_NS::vector<RenderNodeContextData> renderNodeContextData;
    // NOTE: used in backend and accessed in update
    RenderNodeGraphShareData renderNodeGraphShareData;

    BASE_NS::unique_ptr<RenderNodeGraphShareDataManager> renderNodeGraphShareDataMgr;

    bool initialized { false };
    bool dynamic { false };

    RenderDataConstants::RenderDataFixedString renderNodeGraphName;
    RenderDataConstants::RenderDataFixedString renderNodeGraphDataStoreName;
    RenderDataConstants::RenderDataFixedString renderNodeGraphUri;
};
RENDER_END_NAMESPACE()

#endif // CORE__RENDER__RENDER_NODE_GRAPH_NODE_STORE_H
