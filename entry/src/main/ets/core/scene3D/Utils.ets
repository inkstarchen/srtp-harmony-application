import { Geometry, Material, Node, Quaternion, Vec3 } from '@kit.ArkGraphics3D';

export class NodeUtil{

  static getMaterial(node: Node): Material{
    let geom = node as Geometry;
    return geom.mesh.subMeshes[0].material;
  }

}

function Sub(l: Vec3, r: Vec3): Vec3 {
  return { x: l.x - r.x, y: l.y - r.y, z: l.z - r.z };
}
function Dot(l: Vec3, r: Vec3): number {
  return l.x * r.x + l.y * r.y + r.z * l.z;
}
function Normalize(l: Vec3): Vec3 {
  let d = Math.sqrt(Dot(l, l));
  return { x: l.x / d, y: l.y / d, z: l.z / d };
}
function Cross(l: Vec3, r: Vec3): Vec3 {
  return { x: (l.y * r.z - l.z * r.y), y: (l.z * r.x - l.x * r.z), z: (l.x * r.y - l.y * r.x) };
}
function Mul(l: Quaternion, d: number): Quaternion {
  return {
    x: l.x * d,
    y: l.y * d,
    z: l.z * d,
    w: l.w * d
  };
}
export function lookAt(node: Node, eye: Vec3, center: Vec3, up: Vec3) {

  let t: number;

  let q: Quaternion = {
    x: 0.0,
    y: 0.0,
    z: 0.0,
    w: 0.0
  };
  let f = Normalize(Sub(center, eye));
  let m0 = Normalize(Cross(f, up));
  let m1 = Cross(m0, f);
  let m2: Vec3 = { x: -f.x, y: -f.y, z: -f.z };
  if (m2.z < 0) {
    if (m0.x > m1.y) {
      t = 1.0 + m0.x - m1.y - m2.z;
      q = {
        x: t,
        y: m0.y + m1.x,
        z: m2.x + m0.z,
        w: m1.z - m2.y
      };
    } else {
      t = 1.0 - m0.x + m1.y - m2.z;
      q = {
        x: m0.y + m1.x,
        y: t,
        z: m1.z + m2.y,
        w: m2.x - m0.z
      };
    }
  } else {
    if (m0.x < -m1.y) {
      t = 1.0 - m0.x - m1.y + m2.z;
      q = {
        x: m2.x + m0.z,
        y: m1.z + m2.y,
        z: t,
        w: m0.y - m1.x
      };
    } else {
      t = 1.0 + m0.x + m1.y + m2.z;
      q = {
        x: m1.z - m2.y,
        y: m2.x - m0.z,
        z: m0.y - m1.x,
        w: t
      }
    }
  }
  node.position = eye;
  node.rotation = Mul(q, 0.5 / Math.sqrt(t));
}