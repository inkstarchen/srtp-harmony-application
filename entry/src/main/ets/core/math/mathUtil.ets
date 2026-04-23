import { Quaternion } from "@kit.ArkGraphics3D";

export function lerp(a:number , b:number, t:number):number{
  return a + (b - a) * t;
}

export function clipNum(v:number, min:number, max:number):number{
  return v > max ? max : (v < min ? min : v);
}

export function circularDelta(
  index: number,
  selectedIndex: number,
  length: number
): number {
  const half = Math.floor(length / 2)
  const raw = index - selectedIndex
  return ((raw + length + half) % length) - half
}

export function eulerToQuaternion(xAngle: number, yAngle: number, zAngle: number): Quaternion {
  // 将角度转换为弧度并取半角
  const degToRad = (angle: number) => angle * Math.PI / 360;
  const roll = degToRad(xAngle);
  const pitch = degToRad(yAngle);
  const yaw = degToRad(zAngle);

  // 计算各轴旋转的三角函数值
  const cr = Math.cos(roll);
  const sr = Math.sin(roll);
  const cp = Math.cos(pitch);
  const sp = Math.sin(pitch);
  const cy = Math.cos(yaw);
  const sy = Math.sin(yaw);

  // 计算四元数分量
  const w = cr * cp * cy + sr * sp * sy;
  const x = sr * cp * cy - cr * sp * sy;
  const y = cr * sp * cy + sr * cp * sy;
  const z = cr * cp * sy - sr * sp * cy;

  // 创建并返回四元数对象
  return {
    x: x,
    y: y,
    z: z,
    w: w
  } as Quaternion;
}