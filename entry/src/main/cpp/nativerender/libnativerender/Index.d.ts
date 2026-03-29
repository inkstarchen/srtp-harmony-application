/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

import { NodeContent } from '@ohos.arkui.node';

/**
 * Render state enumeration
 */
export enum RenderState {
  UNINITIALIZED = 0,
  INITIALIZING,
  READY,
  RENDERING,
  ERROR,
  DESTROYED
}

/**
 * Create a native XComponent node for Lume rendering
 * @param content - NodeContent from XComponent controller
 * @param id - Unique identifier for this renderer instance
 */
export const createNativeNode: (content: NodeContent, id: string) => void;

/**
 * Bind a node to the renderer
 * @param id - Renderer instance identifier
 * @param node - Node object to bind
 */
export const bindNode: (id: string, node: object) => void;

/**
 * Unbind a node from the renderer
 * @param id - Renderer instance identifier
 */
export const unbindNode: (id: string) => void;

/**
 * Draw a single frame
 * @param id - Renderer instance identifier
 */
export const drawFrame: (id: string) => void;

/**
 * Draw a single frame (legacy alias for drawFrame)
 * @param id - Renderer instance identifier
 * @deprecated Use drawFrame instead
 */
export const drawPattern: (id: string) => void;

/**
 * Load a GLTF scene
 * @param id - Renderer instance identifier
 * @param gltfPath - Path to the GLTF file
 */
export const loadScene: (id: string, gltfPath: string) => void;

/**
 * Get the current renderer state
 * @param id - Renderer instance identifier
 * @returns Current render state
 */
export const getStatus: (id: string) => RenderState;

/**
 * Set the target frame rate
 * @param id - Renderer instance identifier
 * @param rate - Target frame rate in FPS
 */
export const setFrameRate: (id: string, rate: number) => void;

/**
 * Enable or disable soft keyboard
 * @param id - Renderer instance identifier
 * @param needSoftKeyboard - Whether soft keyboard is needed
 */
export const setNeedSoftKeyboard: (id: string, needSoftKeyboard: boolean) => void;

/**
 * Get the rendering context
 * @param id - Renderer instance identifier
 */
export const getContext: (id: string) => object;

/**
 * Initialize the renderer
 * @param id - Renderer instance identifier
 */
export const initialize: (id: string) => void;

/**
 * Finalize and cleanup the renderer
 * @param id - Renderer instance identifier
 */
export const finalize: (id: string) => void;