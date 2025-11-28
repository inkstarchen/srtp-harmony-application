import { Node, Quaternion, Vec2, Vec3 } from "@kit.ArkGraphics3D";
import { Constants } from "../constants/Constants";
import { CalcUtils } from "../utils/calutils";

import { Helper } from "../utils/Helper";
import { CameraManager } from "./CameraManager";

@ObservedV2
export class NodeManager{

  rootNode:Node | undefined = undefined;
  @Trace node:Node | undefined = undefined

  angleX:number = 0;
  angleY:number = 0;
  angleX_last:number = 0;
  angleY_last:number = 0;
  @Trace angleInfo:string = '';
  quaternion:Quaternion = {
    x:0,
    y:1,
    z:0,
    w:0
  }
  scaleV:number = 1;

  /* 0:Info , 1:move 2:rotate*/
  intervalArray:number[] = new Array(3).fill(0)

  async init(root:Node){
    this.rootNode = root;
  }

  moveToScreen_vp(v:Vec2,camM:CameraManager) {
    if(!this.node){
      console.error('Node Manager | There is no node selected');
      return;
    }
    let depth = camM.CalDepth(this.node.position) as number;
    this.node.position.y = camM.Distance2to3_vp(v.y, depth);
    this.node.position.x = camM.Distance2to3_vp(v.x, depth);
  }

  moveToScreen_px(v:Vec2, camM:CameraManager){
    if(!this.node){
      console.error('Node Manager | There is no node selected');
      return;
    }
    let depth = camM.CalDepth(this.node.position) as number;
    this.node.position.y = camM.Distance2to3_px(v.y, depth);
    this.node.position.x = camM.Distance2to3_px(v.x, depth);
  }

  scaleUp(scale:number){
    if(!this.node){
      console.error('Node Manager | There is no node selected');
      return;
    }
    this.node.scale.x *= scale;
    this.node.scale.y *= scale;
    this.node.scale.z *= scale;
    return;
  }

  scaleTo(scale:number){
    if(!this.node){
      console.error('Node Manager | There is no node selected');
      return;
    }
    this.node.scale = {x: scale, y: scale, z: scale};
    return;
  }

  switchToNode(node:Node){
    this.node = node;
    this.scaleV = node.scale.x
    this.quaternion = {x:node.rotation.x,y:node.rotation.y,z:node.rotation.z,w:node.rotation.w};
    this.angleX = 0;
    this.angleY = 0;
  }

  static setNodeRotation(node:Node,angle:number){
    let qz:Quaternion = {
      x: 0,
      y: 0,
      z: Math.sin(angle),
      w: Math.cos(angle)
    }
    node.rotation = qz;
  }

  setRotate(X:number,Y:number){
    this.angleX = X + this.angleX_last;
    this.angleY = Y + this.angleY_last;
  }

  startRotate(){
    if(this.intervalArray[2] != 0) return;
    this.intervalArray[2] = setInterval(() => {
      if(!this.node) return;
      let angleX_t = Math.PI * this.angleX / 360;
      let angleY_t = Math.PI * this.angleY / 360;
      let qx:Quaternion = {
        x: Math.sin(angleX_t),
        y: 0,
        z: 0,
        w: Math.cos(angleX_t)
      }
      let qy:Quaternion = {
        x: 0,
        y: Math.sin(angleY_t),
        z: 0,
        w: Math.cos(angleY_t)
      }
      let q1 = CalcUtils.qMul(qx,qy);
      this.node.rotation = CalcUtils.qMul(q1,this.quaternion)
    },25)

  }

  stopRotate(){
    if(!this.node) return;
    this.quaternion = this.node.rotation;
    Helper.clearIntervalArray(this.intervalArray,2)
    this.angleX_last = this.angleX;
    this.angleY_last = this.angleY;
  }

  scale(scaleV:number){
    if(!this.node) return;
    this.scaleV = scaleV;
    this.node.scale ={x:scaleV, y:scaleV, z:scaleV}
  }

}