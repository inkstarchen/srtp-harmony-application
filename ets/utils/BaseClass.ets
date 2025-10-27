import { Node, Vec3 } from "@kit.ArkGraphics3D";
import { Callback } from "@ohos.base";

export enum AnimationOp{
  START = 0,
  STOP = 1,
  PAUSE = 2,
  SEEK = 3,
  RESTART = 4,
  FINISH = 5,
  ON_FINISHED = 6,
  ON_STARTED = 7
}

@ObservedV2
export class TraceVec2{
  @Trace x:number = 0;
  @Trace y:number = 0;
}

@ObservedV2
export class TraceVec3{
  @Trace x:number = 0;
  @Trace y:number = 0;
  @Trace z:number = 0;
}

export class Ray{
  o:Vec3 = {x:0,y:0,z:0};
  d:Vec3 = {x:0,y:0,z:0};
}

export class nodeListInfo{
  path:string = '';
  children:string[] = [];
  constructor(path:string, children:string[]) {
    this.path = path;
    this.children = children;
  }
}

export class slabResult{
  tMin:number  = 0;
  position: Vec3 | undefined = undefined;
  flag: boolean = false;
  constructor(tMin:number, position: Vec3 | undefined , flag: boolean) {
    this.tMin = tMin;
    this.position = position;
    this.flag = flag;
  }
}

export class rayCastResult{
  node:Node | undefined = undefined;
  tMin:number  = 0;
  position: Vec3 | undefined = undefined;
  constructor(node:Node, slabResults:slabResult) {
    this.node = node;
    this.tMin = slabResults.tMin;
    this.position = slabResults.position;
  }
}

export class AnimOption{
  opt: AnimationOp | undefined = undefined;
  callBack: Callback<void> | undefined = undefined
  percent: number | undefined = undefined;
  constructor(opt: AnimationOp,callBack: Callback<void> | undefined = undefined,percent:number | undefined = undefined) {
    this.opt = opt;
    this.callBack = callBack;
    this.percent = percent;
  }
}

export class NodeState{
  node:Node | undefined = undefined;
  velocity:Vec3 | undefined = undefined;
  rotation:Vec3 | undefined = undefined;
  constructor(node:Node, velocity:Vec3 | undefined = undefined, rotation:Vec3 | undefined = undefined) {
    this.node = node;
    this.velocity = velocity;
    this.rotation = rotation;
  }

}