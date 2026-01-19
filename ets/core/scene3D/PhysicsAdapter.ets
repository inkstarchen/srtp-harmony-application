import { Geometry, Node } from '@kit.ArkGraphics3D';

export interface Vector3 {
  x: number;
  y: number;
  z: number;
}

export interface PhysicsData{
  name: string,
  position: Vector3;
  velocity: Vector3;
  aabb_length: Vector3;
  mass: number;
  radius: number;
  isStatic: boolean;
}

export class PhysicsAdapter {
  static nodeToPhysicsData(node: Node): PhysicsData {
    const position = node.position;
    const scale = node.scale;

    const radius = (scale[0] + scale[1] + scale[2]) / 6;
    let geom = node as Geometry;
    let aabb = geom.mesh.aabb;
    const aabb_length = {
      x: (aabb.aabbMax.x - aabb.aabbMin.x) / 2,
      y: (aabb.aabbMax.y - aabb.aabbMin.y) / 2,
      z: (aabb.aabbMax.z - aabb.aabbMin.z) / 2
    } as Vector3;

    return {
      name:node.name,
      position:{
        x: position.x,
        y: position.y,
        z: position.z
      } as Vector3,
      velocity: { x:1, y:0 ,z:0},
      aabb_length: aabb_length,
      radius: radius,
      mass: 1,
      isStatic: false
    } as PhysicsData;
  }

  static applyPhysicsToNode(node: Node, physicsData: PhysicsData): void{
    const pos = physicsData.position;
    node.position.x = pos.x;
    node.position.y = pos.y;
    node.position.z = pos.z;
  }
}