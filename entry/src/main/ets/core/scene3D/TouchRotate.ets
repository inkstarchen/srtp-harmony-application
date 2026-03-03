import { Node, Quaternion, Vec2, Vec3 } from "@kit.ArkGraphics3D";
import { Touch } from "../../shared/utils/TouchManager";
import { normalizeVec3, TraceVec2 } from "../math/vec";

@ObservedV2
export class TouchRotate {
  target: Node | undefined;

  update(touch: Touch):Quaternion{
    if(!this.target) return {x:0,y:0,z:0,w:0} as Quaternion;
    if(touch.active){
      let distance: Vec2 = {x:touch.curPos.x - touch.lastPos.x, y: touch.curPos.y - touch.lastPos.y};
      console.info("Rotation Test | touch cur:" + touch.curPos.x.toString() + '/' + touch.curPos.y.toString() + ' last ' + touch.lastPos.x.toString() + '/' + touch.lastPos.y.toString())
      const deltaRot = rotationFromTouchDelta(distance.x, distance.y);
      console.info("Rotation Test | distance + " + distance.x.toString() + '/' + distance.y.toString() )
      // 新旋转 = Δq × 当前旋转
      return mulQuat(deltaRot, this.target.rotation);
      // console.info(this.target.name + "rotate " + this.target.rotation.x.toString() + '/' + this.target.rotation.y.toString() + '/' + this.target.rotation.z.toString())
    }else{
      return {x:0,y:0,z:0,w:0} as Quaternion;
    }
  }

}

export function fromAxisAngle(axis: Vec3, angleRad:number) : Quaternion {
    let n = normalizeVec3(axis);
    let half = angleRad * 0.5;
    let s = Math.sin(half);

    return {
      x: n.x * s,
      y: n.y * s,
      z: n.z * s,
      w: Math.cos(half)
    } as Quaternion;
}

const ROTATE_SPEED = 0.05 // 灵敏度（可调）

export function rotationFromTouchDelta(
  dx: number,
  dy: number
): Quaternion {
  // X 方向滑动 → 绕 Y 轴
  const qYaw = fromAxisAngle(
    { x: 0, y: 1, z: 0 },
    dx * ROTATE_SPEED
  )

  // Y 方向滑动 → 绕 X 轴
  const qPitch = fromAxisAngle(
    { x: 1, y: 0, z: 0 },
    dy * ROTATE_SPEED
  )

  // 先 pitch 再 yaw（顺序很重要）
  return mulQuat(qYaw, qPitch)
}

export function mulQuat(a: Quaternion, b: Quaternion): Quaternion {
  return {
    w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
    x: a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
    y: a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
    z: a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w
  }
}

