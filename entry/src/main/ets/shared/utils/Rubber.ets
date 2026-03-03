import { TraceVec2 } from "../../core/math/vec";
import { Vec2 } from "@kit.ArkGraphics3D";
import { AnimatorResult, Prompt } from "@kit.ArkUI";
import { ClassFilter } from "@ohos/hypium/src/main/module/config/Filter";


export enum mainState{
  DISPLAY = 0,
  CARD = 1
}

// 滑动状态切换工具
@ObservedV2
export class Rubber{
  @Trace pos:TraceVec2 = new TraceVec2();
  @Trace state: mainState = mainState.DISPLAY;
  nextState: mainState = mainState.CARD;
  isShow: boolean = true;
  downPos: Vec2 = {x:0,y:0};
  lastPos: Vec2 = {x:0, y:0};
  targetPos:Vec2 = {x:0,y:0};
  xMax:number;
  xMin:number;
  yMax:number;
  yMin:number;
  animPlay: boolean = false;
  anim:AnimatorResult;
  constructor(xMax: number, xMin: number, yMax:number ,yMin:number,uiContext:UIContext) {
    this.xMax = xMax;
    this.xMin = xMin;
    this.yMax = yMax;
    this.yMin = yMin;
    this.anim = uiContext.createAnimator({
      duration:500,
      delay:0,
      iterations:1,
      direction:"normal",
      fill:"forwards",
      easing:"ease-out",
      begin:0,
      end:1
    })
    this.anim.onFrame = (progress) => {
      this.pos.x = this.targetPos.x * progress + (1 - progress) * this.lastPos.x;
      Prompt.showToast({message:'play'})
    }
    this.anim.onFinish = () => {
      this.animPlay = false;
      this.lastPos.x = this.targetPos.x;
      this.lastPos.y = this.targetPos.y;
      this.state = this.nextState;
    }
  }

  Down(downPos:Vec2){
    if(!this.animPlay){
      this.downPos = downPos;
    }
  }

  update(target:Vec2){
    if(!this.animPlay){
      this.pos.x = target.x - this.downPos.x + this.lastPos.x;
      this.pos.y = target.y - this.downPos.y + this.lastPos.y;
      if(this.pos.x > (this.xMax + this.xMin) / 2){
        this.targetPos.x = this.xMax;
        this.targetPos.y = this.pos.y;
        this.nextState = mainState.CARD;
      } else{
        this.targetPos.x = this.xMin;
        this.targetPos.y = this.pos.y;
        this.nextState = mainState.DISPLAY;
      }
      this.pos.clip(this.xMin, this.xMax, this.yMin, this.yMax);
    }
  }

  Up(){
    if(!this.animPlay){
      this.animPlay = true;
      this.anim.play();
      this.lastPos.x = this.pos.x;
      this.lastPos.y = this.pos.y;
    }
  }
}

enum MotionState {
  IDLE,
  DRAG,
  INERTIA,
  SPRING
}

@ObservedV2
export class PhysicsScroller {
  @Trace pos: TraceVec2 = new TraceVec2();
  lastPos: Vec2 = {x:0,y:0};
  velocity:Vec2 = {x:0,y:0};
  minPos: Vec2;
  maxPos: Vec2;
  state: MotionState = MotionState.IDLE;

  private downPos: Vec2 = {x:0, y:0};
  rubberK = 60;
  friction = 0.0025;
  springK = 0.02;
  springDamping = 0.15;

  animPlay: boolean = false;
  anim:AnimatorResult;
  constructor(min:Vec2,max:Vec2,uiContext:UIContext) {
    this.minPos = min;
    this.maxPos = max;
    this.anim = uiContext.createAnimator({
      duration:500,
      delay:0,
      iterations:1,
      direction:"normal",
      fill:"forwards",
      easing:"ease-out",
      begin:0,
      end:1
    })
    this.anim.onFrame = (progress) => {
      this.pos.x = (1 - progress) * this.lastPos.x;
      this.pos.y = (1 - progress) * this.lastPos.y;
    }
    this.anim.onFinish = () => {
      this.animPlay = false;
    }
  }

  down(pos:Vec2){
    this.state = MotionState.DRAG
    this.downPos.x = pos.x;
    this.downPos.y = pos.y;
    this.velocity = {x:0,y:0};
  }

  move(pos:Vec2){
    if(this.state !== MotionState.DRAG) return;

    let raw:Vec2 = {x:pos.x - this.downPos.x,y:pos.y - this.downPos.y};
    raw = this.refract(raw);
    this.pos.x = this.applyRubberX(raw.x, this.minPos.x, this.maxPos.x);
    this.pos.y = this.applyRubberX(raw.y, this.minPos.y, this.maxPos.y);
  }

  refract(raw:Vec2):Vec2{
    return {x:raw.x * 0.5, y: raw.y * 0.5};
  }

  up(){
    if(!this.animPlay){
      this.animPlay = true;
      this.anim.play();
      this.lastPos.x = this.pos.x;
      this.lastPos.y = this.pos.y;
    }
  }
  private applyRubberX(value: number,min:number,max:number): number {
    if(value < min) {
      const diff = value - this.minPos.x;
      return min + diff / (1 + Math.abs(diff) / this.rubberK);
    }
    if(value > max) {
      const diff = value - this.maxPos.x;
      return max + diff / (1 + Math.abs(diff) / this.rubberK);
    }
    return value;
  }


}