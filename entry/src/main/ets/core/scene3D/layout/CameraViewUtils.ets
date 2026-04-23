import { Vec3 } from "@kit.ArkGraphics3D";

/**
 * 相机参数配置
 */
export interface CameraConfig {
  position: Vec3;      // 相机位置
  fov: number;         // 视野角度（弧度）
  aspectRatio: number; // 宽高比 (width/height)
  nearClip: number;    // 近裁剪面
  farClip: number;     // 远裁剪面
}

/**
 * 默认相机配置
 * 相机位置：(0, 0, -6)
 * 朝向：+Z
 * FOV: 90 度 = π/2
 * 宽高比：1:2 = 0.5
 */
export const DEFAULT_CAMERA: CameraConfig = {
  position: { x: 0, y: 0, z: -6 },
  fov: Math.PI / 2,  // 90 度
  aspectRatio: 0.5,   // 1:2
  nearClip: 0.1,
  farClip: 100
};

/**
 * 计算相机在指定 Z 距离处的视野范围
 * @param zDistance Z 轴距离（相对于相机位置）
 * @param camera 相机配置
 * @returns 视野范围 { halfWidth, halfHeight }
 */
export function getCameraFrustumAtZ(zDistance: number, camera: CameraConfig = DEFAULT_CAMERA): [number, number] {
  // 计算半高（垂直视野的一半）
  const halfHeight = zDistance * Math.tan(camera.fov / 2);
  
  // 计算半宽（根据宽高比）
  const halfWidth = halfHeight * camera.aspectRatio;
  
  return [halfWidth, halfHeight];
}

/**
 * 在相机视野范围内生成随机位置
 * @param minZ 最小 Z 距离（相对于相机位置）
 * @param maxZ 最大 Z 距离（相对于相机位置）
 * @param camera 相机配置
 * @returns 随机世界坐标位置
 * 
 * 使用示例：
 * ```typescript
 * // 在 Z 轴 6-10 范围内随机生成位置
 * const randomPos = getRandomPositionInCameraView(6, 10);
 * console.log(`随机位置：${randomPos.x}, ${randomPos.y}, ${randomPos.z}`);
 * ```
 */
export function getRandomPositionInCameraView(
  minZ: number = 6, 
  maxZ: number = 10, 
  camera: CameraConfig = DEFAULT_CAMERA
): Vec3 {
  // 随机 Z 距离
  const zDistance = Math.random() * (maxZ - minZ) + minZ;
  
  // 获取该距离处的视野范围
  const view = getCameraFrustumAtZ(zDistance, camera);
  let halfWidth = view[0];
  let halfHeight = view[1];
  // 随机 X 和 Y（在视野范围内）
  const randomX = (Math.random() * 2 - 1) * halfWidth;  // [-halfWidth, halfWidth]
  const randomY = (Math.random() * 2 - 1) * halfHeight; // [-halfHeight, halfHeight]
  
  // 计算世界坐标
  return {
    x: camera.position.x + randomX,
    y: camera.position.y + randomY,
    z: camera.position.z + zDistance
  };
}

/**
 * 在相机视野范围内生成多个不重叠的随机位置
 * @param count 需要生成的位置数量
 * @param minZ 最小 Z 距离
 * @param maxZ 最大 Z 距离
 * @param minDistance 位置之间的最小距离
 * @param camera 相机配置
 * @returns 随机位置数组
 */
export function getMultipleRandomPositionsInCameraView(
  count: number,
  minZ: number = 6,
  maxZ: number = 10,
  minDistance: number = 1.0,
  camera: CameraConfig = DEFAULT_CAMERA
): Vec3[] {
  const positions: Vec3[] = [];
  const maxAttempts = count * 10; // 最大尝试次数
  let attempts = 0;
  
  while (positions.length < count && attempts < maxAttempts) {
    const newPos = getRandomPositionInCameraView(minZ, maxZ, camera);
    
    // 检查与已有位置的距离
    let tooClose = false;
    for (const existingPos of positions) {
      const distance = Math.sqrt(
        Math.pow(newPos.x - existingPos.x, 2) +
        Math.pow(newPos.y - existingPos.y, 2) +
        Math.pow(newPos.z - existingPos.z, 2)
      );
      
      if (distance < minDistance) {
        tooClose = true;
        break;
      }
    }
    
    if (!tooClose) {
      positions.push(newPos);
    }
    
    attempts++;
  }
  
  if (positions.length < count) {
    console.warn(`只生成了 ${positions.length}/${count} 个位置，可能空间不足或最小距离过大`);
  }
  
  return positions;
}

/**
 * 检查点是否在相机视野内
 * @param point 要检查的点
 * @param camera 相机配置
 * @returns 是否在视野内
 */
export function isPointInCameraView(point: Vec3, camera: CameraConfig = DEFAULT_CAMERA): boolean {
  // 计算相对于相机的位置
  const relativeX = point.x - camera.position.x;
  const relativeY = point.y - camera.position.y;
  const relativeZ = point.z - camera.position.z;
  
  // 检查是否在相机前方
  if (relativeZ <= 0) {
    return false;
  }
  
  // 计算该距离处的视野范围
  const view = getCameraFrustumAtZ(relativeZ, camera);
  let halfWidth = view[0];
  let halfHeight = view[1];
  
  // 检查点是否在视野范围内
  return Math.abs(relativeX) <= halfWidth && Math.abs(relativeY) <= halfHeight;
}

// ==================== 使用示例 ====================

/**
 * 在 GlobalSceneProxy 中使用示例
 */
export class LayoutHelper {
  /**
   * 添加物体到相机视野内的随机位置
   * @param sceneProxy SceneProxy 实例
   * @param resourceName 资源名称
   * @param nodeName 节点名称
   * @param rename 重命名
   */
  static randomPosInCameraView(
    minZ: number = 6,
    maxZ: number = 10
  ): Vec3 {
    // 生成随机位置
    const randomPos = getRandomPositionInCameraView(minZ, maxZ, DEFAULT_CAMERA);
    
    // 假设 sceneProxy 有 addNode 方法
    // const node = await sceneProxy.addNode(resourceName, nodeName, rename);
    // if (node) {
    //   node.position = randomPos;
    // }
    // return node;
    return randomPos;
  }
  
  /**
   * 批量添加物体到相机视野内
   */
  static async addMultipleNodesInCameraView(
    count: number,
    minDistance: number = 1.5
  ): Promise<Vec3[]> {
    return getMultipleRandomPositionsInCameraView(count, 6, 10, minDistance, DEFAULT_CAMERA);
  }
}

// ==================== 测试代码 ====================
if (false) {
  // 测试单个随机位置
  console.log("=== 测试单个随机位置 ===");
  for (let i = 0; i < 5; i++) {
    const pos = getRandomPositionInCameraView(6, 10);
    console.log(`位置 ${i}: (${pos.x.toFixed(2)}, ${pos.y.toFixed(2)}, ${pos.z.toFixed(2)})`);
    console.log(`  是否在视野内：${isPointInCameraView(pos)}`);
  }
  
  // 测试多个位置
  console.log("\n=== 测试 5 个不重叠位置 ===");
  const positions = getMultipleRandomPositionsInCameraView(5, 6, 10, 1.5);
  positions.forEach((pos, i) => {
    console.log(`位置 ${i}: (${pos.x.toFixed(2)}, ${pos.y.toFixed(2)}, ${pos.z.toFixed(2)})`);
  });
}
