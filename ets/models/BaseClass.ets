import { Node, Quaternion, Vec2, Vec3 } from "@kit.ArkGraphics3D";
import { Callback } from "@ohos.base";
import { CalcUtils } from "../utils/calutils";


export class NodeInfo{

  constructor(name:string,position:Vec3,rotation:Quaternion,scaleV:number) {
    this.name = name;
    this.position = position;
    this.rotation = rotation;
    this.scale = scaleV;
  }

  copyFromNode(node:Node){
    this.name = node.name;
    this.position = node.position;
    this.rotation = node.rotation;
    this.scale = node.scale.x;
  }

  name:string = '';
  position:Vec3 = {x:0,y:0,z:0}
  rotation:Quaternion = {x:0,y:1,z:0,w:0}
  scale:number = 1;

  toString():string {
    let nodeInfo = '';
    nodeInfo += 'Name: ' + this.name + '\n';
    nodeInfo += 'Position | x: ' + this.position.x + ' / y: ' + this.position.y + ' / z: ' + this.position.z + '\n';
    nodeInfo += 'Rotation | x: ' + this.rotation.x + ' / y: ' + this.rotation.y + ' / z: ' + this.rotation.z + ' / w: ' + this.rotation.w + '\n';
    nodeInfo += 'Scale | ' + this.scale + '\n';
    return nodeInfo;
  }
}

@ObservedV2
export class TraceString{
  constructor(x:number = 0, text:string = '') {
    this.x = x;
    this.text = text;
  }
  @Trace x:number = 0;
  @Trace text:string = '';
  @Trace scaleV:number = 1;
}

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
  @Trace x:number
  @Trace y:number

  constructor(x:number, y:number) {
    this.x = x;
    this.y = y;
  }
}


@ObservedV2
export class TraceVec3{
  @Trace x:number
  @Trace y:number
  @Trace z:number

  constructor(x:number,y:number,z:number) {
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

@ObservedV2
export class touchManager {
  constructor(pos:number) {
    this.pos = pos;
  }
  pos:number =0;
  @Trace down:Vec2 = {x:0,y:0}
  @Trace distance:TraceVec2 = new TraceVec2(0,0)
  @Trace angle:number = 0;

  touchDown(event:TouchEvent){
    this.down = {x:event.touches[this.pos].x, y:event.touches[this.pos].y}
  }

  touchMove(event:TouchEvent){
    this.distance.x = event.touches[this.pos].x - this.down.x
    this.distance.y = event.touches[this.pos].y - this.down.y
    this.angle = CalcUtils.calAngle(this.down,{x:event.touches[this.pos].x, y:event.touches[this.pos].y})
    if(this.distance.x == 0 && this.distance.y == 0){
      this.angle = 0;
    }

  }
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


@ObservedV2
export class History<T>{
  history: T[] = [];
  @Trace index: number = -1;
  @Trace length: number = 0;

  isBegin():boolean{
    return this.index == 0;
  }

  isEnd():boolean{
    return this.index == this.length - 1 ;
  }

  newHistory(item:T){
    if(!this.isEnd()){
      for(;this.length > this.index + 1; this.length--){
        this.history.pop()
      }
    }
    this.history.push(item);
    this.index++;
    this.length++;
  }

  back(target:number = -1):T{
    if(target == -1){
      if(this.isBegin()){
        console.info('History info | index is at beginning')
      }else{
        this.index--;
      }
    }else if(target < 0 || target >= this.index){
      console.error('History info | back error')
    }else{
      this.index = target;
    }
    return this.history[this.index];
  }

  forward(target:number = -1):T{
    if(target == -1){
      if(this.isEnd()){
        console.info('History info | index in at end')
      }else{
        this.index++;
      }
    }else if(target < this.index || target >= this.length){
      console.error('History info | forward error')
    }else{
      this.index = target;
    }

    return this.history[this.index];
  }


}