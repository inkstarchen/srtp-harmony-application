
import { Constants } from '../constants/Constants'
import { Queue } from '@kit.ArkTS';



import { Vec2, Vec3, Quaternion, Node, Aabb } from '@kit.ArkGraphics3D';
import { Ray,rayCastResult, slabResult} from './BaseClass';

export class CalcUtils {

  static pxToNormal(v2:Vec2, screenWidth:number, screenHeight:number):Vec2{
    let result:Vec2 = {x:0,y:0};
    result.x = v2.x / screenWidth;
    result.y = v2.y / screenHeight;
    return result;
  }

  static calAngle(oPos:Vec2, tPos:Vec2):number{
    let x = tPos.x - oPos.x;
    let y = tPos.y - oPos.y;
    let r = Math.sqrt(x * x + y * y);
    let angle = Math.asin(y / r);
    if(x > 0){
      if(y < 0){
        angle = 2 * Math.PI + angle;
      }
    }else{
        angle = Math.PI - angle;
    }
    return angle;
  }

  static SpaceToPlane(v3:Vec3, fov:number,scaleWH:number):Vec2{
    let distance = 4 - v3.z;
    let tan = Math.tan(fov / 2);
    let h = tan * distance;
    let w = scaleWH * h;
    let factY = (1 - v3.y / h) / 2;
    let factX = (1 + v3.x / w) / 2;
    return {x:factX,y:factY};
  }

  static PlaneSizeToSpaceSize(distancePlane:Vec2,distanceZ:number,fov:number,screenWidth:number,screenHeight:number):Vec3{
    let tanA = Math.tan(fov / 2);
    let H = (4 - distanceZ) * tanA * 2;
    let W = H * screenWidth / screenHeight;
    let distanceSpace:Vec3 = {x:0,y:0,z:0}
    distanceSpace.x = W * (distancePlane.x / screenWidth);
    distanceSpace.y = H * (distancePlane.y / screenHeight);
    return distanceSpace;
  }

  static crossMul(v1:Vec3, v2:Vec3):Vec3{
    let result:Vec3 = {x: v1.y * v2.z - v1.z * v2.y,
                  y: v1.z * v2.x - v1.x * v2.z,
                  z: v1.x * v2.y - v1.y * v2.x}
    return result;
  }

  static NormVec3(v:Vec3):Vec3{
    let length = Math.sqrt(Math.pow(v.x,2) + Math.pow(v.y,2) + Math.pow(v.z,2));
    let result:Vec3 = {x : v.x / length,
    y: v.y /length,
    z: v.z / length}
    return result;
  }

  static calRayCast(ab:Aabb, ray:Ray) :slabResult{
    let result = new slabResult(0,undefined,false);
    let tmin = -Infinity;
    let tmax = Infinity;

    // X轴
    if (ray.d.x === 0) {
      // 射线方向x分量为0，则射线平行于X轴
      if (ray.o.x <= ab.aabbMin.x || ray.o.x >= ab.aabbMax.x) {
        return result;
      }
    } else {
      let invD = 1.0 / ray.d.x;
      let t1 = (ab.aabbMin.x - ray.o.x) * invD;
      let t2 = (ab.aabbMax.x - ray.o.x) * invD;

      if (t1 > t2) {
        // 交换t1和t2，保证t1是近交点，t2是远交点
        let temp = t1;
        t1 = t2;
        t2 = temp;
      }

      tmin = Math.max(tmin, t1);
      tmax = Math.min(tmax, t2);

      if (tmin > tmax) return result;
    }

    // Y轴
    if (ray.d.y === 0) {
      if (ray.o.y <= ab.aabbMin.y || ray.o.y >= ab.aabbMax.y) {
        return result;
      }
    } else {
      let invD = 1.0 / ray.d.y;
      let t1 = (ab.aabbMin.y - ray.o.y) * invD;
      let t2 = (ab.aabbMax.y - ray.o.y) * invD;

      if (t1 > t2) {
        let temp = t1;
        t1 = t2;
        t2 = temp;
      }

      tmin = Math.max(tmin, t1);
      tmax = Math.min(tmax, t2);

      if (tmin > tmax) return result;
    }

    // Z轴
    if (ray.d.z === 0) {
      // 注意：这里原始代码错误地使用了ab.aabbMin.y，应该使用ab.aabbMin.z
      if (ray.o.z <= ab.aabbMin.z || ray.o.z >= ab.aabbMax.z) {
        return result;
      }
    } else {
      let invD = 1.0 / ray.d.z;
      let t1 = (ab.aabbMin.z - ray.o.z) * invD;
      let t2 = (ab.aabbMax.z - ray.o.z) * invD;

      if (t1 > t2) {
        let temp = t1;
        t1 = t2;
        t2 = temp;
      }

      tmin = Math.max(tmin, t1);
      tmax = Math.min(tmax, t2);

      if (tmin > tmax) return result;
    }

    // 如果tmax大于等于0，则射线从AABB中穿过或起点在AABB内
    if(tmax >= 0 && tmin > 0){
      result.tMin = tmin;
      result.position = {
        x: ray.o.x + ray.d.x * tmin,
        y: ray.o.y + ray.d.y * tmin,
        z: ray.o.z + ray.d.z * tmin,
      }
      result.flag = true;
    }
    return result;
  }

  static calAabb(node:Node, ab:Aabb, scale:number = 1):Aabb{

    let ret:Aabb = {aabbMin:{x:0,y:0,z:0},aabbMax:{x:0,y:0,z:0}};
    let length:Vec3 = { x:(ab.aabbMax.x - ab.aabbMin.x) * scale,
                        y:(ab.aabbMax.y - ab.aabbMin.y) * scale,
                        z:(ab.aabbMax.z - ab.aabbMin.z) * scale}
    console.info('cal 1 length:' + length.x + '/' + length.y + '/' + length.z + '/' + scale);
    let center:Vec3 = { x:(ab.aabbMax.x + ab.aabbMin.x) / 2,
                        y:(ab.aabbMax.y + ab.aabbMin.y) / 2,
                        z:(ab.aabbMax.z + ab.aabbMin.z) / 2};
    console.info('cal 1 center:' + center.x + '/' + center.y + '/' + center.z)
    center.x = center.x + node.position.x * scale;
    center.y = center.y + node.position.y * scale;
    center.z = center.z + node.position.z * scale;
    ret = {
      aabbMin:{
        x: center.x - length.x / 2,
        y: center.y - length.y / 2,
        z: center.z - length.z / 2,
      },
      aabbMax:{
        x: center.x + length.x / 2,
        y: center.y + length.y / 2,
        z: center.z + length.z / 2,
      }
    }
    return ret;
  }

  static calDistance(v1:Vec2,v2:Vec2){
    return Math.sqrt(Math.pow(v1.x - v2.x,2) + Math.pow(v1.y-v2.y,2))
  }

  static qMul(q1:Quaternion,q2:Quaternion):Quaternion{
    let result = {
      w: q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
      x: q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
      y: q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
      z: q1.w * q2.z + q1.x * q2.y - q1.y * q1.x + q1.z * q2.w
    } as Quaternion;
    return result;
  }

  static CalSlot(point:Vec2,idx:number){
    let leftX = idx * (Constants.BOOK_ITEM_WIDTH + Constants.BOOK_ITEM_SPACE);
    let rightX = idx * (Constants.BOOK_ITEM_WIDTH + Constants.BOOK_ITEM_SPACE) + Constants.BOOK_ITEM_WIDTH;
    let ceil = 0;
    let bottom = Constants.BOOK_BOX_HEIGHT;
    return point.x < rightX && point.x > leftX && point.y < bottom && point.y > ceil;
  }

  static sub(l: Vec3, r: Vec3): Vec3 {
    return { x: l.x - r.x, y: l.y - r.y, z: l.z - r.z };
  }

  static dot(l: Vec3, r: Vec3): number {
    return l.x * r.x + l.y * r.y + r.z * l.z;
  }

  static normalize(l: Vec3): Vec3 {
    let d = Math.sqrt(CalcUtils.dot(l, l));
    return { x: l.x / d, y: l.y / d, z: l.z / d };
  }

  static cross(l: Vec3, r: Vec3): Vec3 {
    return { x: (l.y * r.z - l.z * r.y), y: (l.z * r.x - l.x * r.z), z: (l.x * r.y - l.y * r.x) };
  }

  static mul(l: Quaternion, d: number): Quaternion {
    return {
      x: l.x * d,
      y: l.y * d,
      z: l.z * d,
      w: l.w * d
    };
  }

  static lookAt(cam: Node, eye: Vec3, center: Vec3, up: Vec3) {
    let t: number;
    let q: Quaternion = {
      x: 0.0,
      y: 0.0,
      z: 0.0,
      w: 0.0
    };
    let f = CalcUtils.normalize(CalcUtils.sub(center, eye));
    let m0 = CalcUtils.normalize(CalcUtils.cross(f, up));
    let m1 = CalcUtils.cross(m0, f);
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
        };
      }
    }
    cam.position = eye;
    cam.rotation = CalcUtils.mul(q, 0.5 / Math.sqrt(t));
  }

  static genRandom(): number {
    return Math.random() * 2 - 1;
  }


}
