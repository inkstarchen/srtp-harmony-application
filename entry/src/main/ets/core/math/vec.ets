import { Vec2, Vec3, Vec4 } from "@kit.ArkGraphics3D";

@ObservedV2
export class TraceVec3{
  @Trace x: number = 0;
  @Trace y: number = 0;
  @Trace z: number = 0;

  clip(threshold:number){
    if(this.x > threshold) this.x = threshold;
    if(this.x < -threshold) this.x = -threshold;
    if(this.y > threshold) this.y = threshold;
    if(this.y < -threshold) this.y = -threshold;
    if(this.z > threshold) this.z = threshold;
    if(this.z < -threshold) this.z = -threshold;
  }
}

@ObservedV2
export class TraceSize{
  @Trace width:number = 0;
  @Trace height:number = 0;
}

@ObservedV2
export class TraceVec2{
  @Trace x:number = 0;
  @Trace y:number = 0;

  clip(xMinT:number, xMaxT:number, yMinT:number, yMaxT:number){
    if(this.x < xMinT) this.x = xMinT;
    if(this.x > xMaxT) this.x = xMaxT;
    if(this.y < yMinT) this.y = yMinT;
    if(this.y > yMaxT) this.y = yMaxT;
  }
}

export function vec3(x = 0, y = 0, z = 0): Vec3 {
  return { x, y, z }
}
export function addVec3(a: Vec3, b: Vec3): Vec3 {
  return {
    x: a.x + b.x,
    y: a.y + b.y,
    z: a.z + b.z
  }
}

export function subVec3(a: Vec3, b: Vec3): Vec3 {
  return {
    x: a.x - b.x,
    y: a.y - b.y,
    z: a.z - b.z
  }
}

export function mulVec3Scalar(v: Vec3, s: number): Vec3 {
  return {
    x: v.x * s,
    y: v.y * s,
    z: v.z * s
  }
}

export function divVec3Scalar(v: Vec3, s: number): Vec3 {
  if (s === 0) {
    throw new Error('Vec3 division by zero')
  }
  return {
    x: v.x / s,
    y: v.y / s,
    z: v.z / s
  }
}


export function lengthSqVec3(v: Vec3): number {
  return v.x * v.x + v.y * v.y + v.z * v.z
}

export function lengthVec3(v: Vec3): number {
  return Math.sqrt(lengthSqVec3(v))
}


export function normalizeVec3(v: Vec3): Vec3 {
  const len = lengthVec3(v)
  if (len === 0) {
    return { x: 0, y: 0, z: 0 }
  }
  return {
    x: v.x / len,
    y: v.y / len,
    z: v.z / len
  }
}

export function dotVec3(a: Vec3, b: Vec3): number {
  return a.x * b.x + a.y * b.y + a.z * b.z
}

export function crossVec3(a: Vec3, b: Vec3): Vec3 {
  return {
    x: a.y * b.z - a.z * b.y,
    y: a.z * b.x - a.x * b.z,
    z: a.x * b.y - a.y * b.x
  }
}

export function vec2(x = 0, y = 0): Vec2 {
  return { x, y }
}

export function addVec2(a: Vec2, b: Vec2): Vec2 {
  return { x: a.x + b.x, y: a.y + b.y }
}

export function subVec2(a: Vec2, b: Vec2): Vec2 {
  return { x: a.x - b.x, y: a.y - b.y }
}

export function mulVec2Scalar(v: Vec2, s: number): Vec2 {
  return { x: v.x * s, y: v.y * s }
}

export function lengthVec2(v: Vec2): number {
  return Math.sqrt(v.x * v.x + v.y * v.y)
}

export function normalizeVec2(v: Vec2): Vec2 {
  const len = lengthVec2(v)
  return len === 0 ? { x: 0, y: 0 } : { x: v.x / len, y: v.y / len }
}

export function vec4(x = 0, y = 0, z = 0, w = 0): Vec4 {
  return { x, y, z, w }
}

export function addVec4(a: Vec4, b: Vec4): Vec4 {
  return {
    x: a.x + b.x,
    y: a.y + b.y,
    z: a.z + b.z,
    w: a.w + b.w
  }
}



export function mulVec4Scalar(v: Vec4, s: number): Vec4 {
  return {
    x: v.x * s,
    y: v.y * s,
    z: v.z * s,
    w: v.w * s
  }
}

