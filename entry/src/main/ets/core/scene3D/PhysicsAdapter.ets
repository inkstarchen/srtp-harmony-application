import { Geometry, Node, Vec3, Vec4 } from '@kit.ArkGraphics3D';

export enum ShapeType{
  AABB,
  SPHERE,
}

export interface PhysicsData{
  position: Vec3;
  rotation: Vec4;
  scale: Vec3;
  extent: Vec3;
  shapeType: number;
  isStatic: number;
}

export class PhysicsAdapter {
  static ToPhysicsData(node: Node,type: ShapeType, isStatic: boolean): PhysicsData {
    const position = node.position;
    const rotation = node.rotation as Vec4;
    const scale = node.scale;
    let geom = node as Geometry;
    let aabb = geom.mesh.aabb;

    // 应用 scale 到 extent
    let extent = {
      x: Math.abs((aabb.aabbMax.x - aabb.aabbMin.x) / 2 * scale.x),
      y: Math.abs((aabb.aabbMax.y - aabb.aabbMin.y) / 2 * scale.y),
      z: Math.abs((aabb.aabbMax.z - aabb.aabbMin.z) / 2 * scale.z)
    } as Vec3;
    
    // 防止 extent 为 0
    const MIN_EXTENT = 0.001;
    if (extent.x < MIN_EXTENT) extent.x = MIN_EXTENT;
    if (extent.y < MIN_EXTENT) extent.y = MIN_EXTENT;
    if (extent.z < MIN_EXTENT) extent.z = MIN_EXTENT;
    
    let shapeType:number = 0;
    if(type == ShapeType.SPHERE){
      shapeType = 1;
      let max = Math.max(extent.x,extent.y,extent.z);
      extent.x = max;
      extent.y = max;
      extent.z = max;
    }
    
    console.info(`RegisterNode | node=${node.name} aabbMin=(${aabb.aabbMin.x},${aabb.aabbMin.y},${aabb.aabbMin.z}) aabbMax=(${aabb.aabbMax.x},${aabb.aabbMax.y},${aabb.aabbMax.z}) scale=(${scale.x},${scale.y},${scale.z}) extent=(${extent.x},${extent.y},${extent.z})`);

    return {
      position: position,
      rotation: rotation,
      scale: scale,
      extent: extent,
      shapeType: shapeType,
      isStatic: isStatic ? 1 : 0,
    } as PhysicsData;
  }
}