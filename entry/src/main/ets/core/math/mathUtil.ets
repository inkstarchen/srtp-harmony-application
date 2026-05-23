import { Quaternion } from "@kit.ArkGraphics3D";
import { RotationState } from "../../shared/utils/TouchManager";

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

export function normalizeQuaternion(q: Quaternion): Quaternion {
  const len = Math.sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z);
  if (len < 0.000001) return { x: 0, y: 0, z: 0, w: 1 };

  return {
    w: q.w / len,
    x: q.x / len,
    y: q.y / len,
    z: q.z / len
  };
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

export function multiplyQuaternions(q1: Quaternion, q2: Quaternion): Quaternion {
  return {
    w: q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
    x: q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
    y: q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
    z: q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w
  };
}

export function applyDeltaRotation(currentQuaternion:Quaternion,deltaX: number, deltaY: number): Quaternion {
  // 创建增量四元数（ZYX顺序，先绕X，再绕Y）
  const deltaQuat = eulerToQuaternion(deltaX, deltaY, 0);

  // 四元数乘法：current * delta（注意顺序，通常先应用当前旋转，再应用新旋转）
  return multiplyQuaternions(
    deltaQuat, // 新旋转在前（相当于在世界坐标系中旋转）
    currentQuaternion
  );
}

export function normalizeAngle(angle: number, min: number, max: number): number {
  const range = max - min;
  let normalized = angle;
  while (normalized > max) normalized -= range;
  while (normalized < min) normalized += range;
  return normalized;
}

export function getCurrentRotation(currentQuaternion:Quaternion): RotationState {
  const q = currentQuaternion;

  // 从四元数提取欧拉角（ZYX顺序，即先绕Z再绕Y再绕X）
  // 这里使用YX顺序来得到经纬度
  // 公式参考：https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles

  // 计算绕Y轴的角度（经度）
  // sinYaw = 2 * (w*y - z*x)
  // cosYaw = 1 - 2*(y^2 + z^2)
  const sinYaw = 2 * (q.w * q.y - q.z * q.x);
  const cosYaw = 1 - 2 * (q.y * q.y + q.z * q.z);
  let longitude = Math.atan2(sinYaw, cosYaw) * 180 / Math.PI;

  // 计算绕X轴的角度（纬度）
  // sinPitch = 2 * (w*x + y*z)
  const sinPitch = 2 * (q.w * q.x + q.y * q.z);
  let latitude = Math.asin(Math.min(1, Math.max(-1, sinPitch))) * 180 / Math.PI;

  // 限制经纬度范围
  longitude = longitude;
  latitude = normalizeAngle(latitude, -180, 180);; // 避免万向锁

  return { latitude, longitude };
}