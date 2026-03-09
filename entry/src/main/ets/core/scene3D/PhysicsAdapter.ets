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

    let extent = {
      x: (aabb.aabbMax.x - aabb.aabbMin.x) / 2,
      y: (aabb.aabbMax.y - aabb.aabbMin.y) / 2,
      z: (aabb.aabbMax.z - aabb.aabbMin.z) / 2
    } as Vec3;
    let shapeType:number = 0;
    if(type == ShapeType.SPHERE){
      shapeType = 1;
      let max = Math.max(extent.x,extent.y,extent.z);
      extent.x = max;
      extent.y = max;
      extent.z = max;
    }

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