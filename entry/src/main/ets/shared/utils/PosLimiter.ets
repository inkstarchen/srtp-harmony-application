import { TraceVec2 } from "../../core/math/vec";
import { Vec2 } from "@kit.ArkGraphics3D";
import { AnimatorResult, Prompt } from "@kit.ArkUI";
import { ClassFilter } from "@ohos/hypium/src/main/module/config/Filter";
import { TouchState } from "../../feature/SlideList/SlideList";
import { NavDirection } from "../../feature/TestComponent";

interface PageSetting{
  main:Vec2;
  photo:Vec2;
  play:Vec2;
}
const DEFAULT_PAGE_SETTING:PageSetting = {
  main:{x:0,y:0},
  photo:{x:0,y:0},
  play:{x:0,y:0}
};

export enum mainState{
  DISPLAY = 0,
  CARD = 1
}

const NAV_LIST: [number,number,number][] = [[1,-1,2],[-1,-1,0],[0,-1,-1]];

const PAGE_SETTING: [PageSetting,PageSetting,PageSetting][] = [
  [{main:{x:1,y:0}, photo: {x:0,y:0}, play:{x:1,y:0}},DEFAULT_PAGE_SETTING,{main:{x:-1,y:0}, photo: {x:-1,y:0}, play:{x:0,y:0}}],
  [DEFAULT_PAGE_SETTING,DEFAULT_PAGE_SETTING,{main:{x:0,y:0}, photo: {x:-1,y:0}, play:{x:1,y:0}}],
  [{main:{x:0,y:0}, photo: {x:-1,y:0}, play:{x:1,y:0}},DEFAULT_PAGE_SETTING,DEFAULT_PAGE_SETTING],
];

// 滑动状态切换工具
@ObservedV2
export class PosLimiter{
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

export enum PageId {
  MAIN = 0,
  PHOTO = 1,
  PLAYGROUND = 2,
  NONE = 3,
}
@ObservedV2
export class PhysicsScroller {

  touchState:TouchState = TouchState.IDLE;
  screenWidth: number;
  screenHeight: number;
  @Trace navDir: NavDirection = NavDirection.NONE;
  tempNavDir: NavDirection = NavDirection.NONE;
  @Trace mainOffset: TraceVec2 = new TraceVec2();
  @Trace photoOffset: TraceVec2 = new TraceVec2();
  @Trace playGroundOffset: TraceVec2 = new TraceVec2();

  @Trace pos: TraceVec2 = new TraceVec2();
  @Trace curPage: PageId = PageId.MAIN;
  @Trace nextPage: PageId = PageId.NONE;
  lastPos: Vec2 = {x:0,y:0};
  TargetPos: Vec2 = {x:0,y:0};

  minPos: Vec2;
  maxPos: Vec2;
  state: MotionState = MotionState.IDLE;

  private downPos: Vec2 = {x:0, y:0};
  rubberK = 60;
  friction = 0.0025;
  springK = 0.02;
  springDamping = 0.15;

  animPlay: boolean = false;
  moveAnim:AnimatorResult;

  lookUpNextPage(dir:NavDirection,cur:PageId): PageId {
    if(dir == NavDirection.NONE || dir == NavDirection.TOP) return PageId.NONE;
    return NAV_LIST[cur][dir] == -1 ? PageId.NONE : NAV_LIST[cur][dir];
  }

  updateOffset(){
    if(this.tempNavDir == NavDirection.TOP || this.tempNavDir == NavDirection.NONE) return;
    this.mainOffset.x = PAGE_SETTING[this.curPage][this.tempNavDir].main.x * this.screenWidth;
    this.photoOffset.x = PAGE_SETTING[this.curPage][this.tempNavDir].photo.x * this.screenWidth;
    this.playGroundOffset.x = PAGE_SETTING[this.curPage][this.tempNavDir].play.x * this.screenWidth;
    this.pos.x = 0;
    this.pos.y = 0;
  }
  constructor(min:Vec2,max:Vec2,uiContext:UIContext,screenSize:Size) {
    this.screenWidth = screenSize.width;
    this.screenHeight = screenSize.height;
    this.photoOffset.x = -this.screenWidth;
    this.minPos = min;
    this.maxPos = max;
    this.moveAnim = uiContext.createAnimator({
      duration:300,
      delay:0,
      iterations:1,
      direction:"normal",
      fill:"forwards",
      easing:"ease-out",
      begin:0,
      end:1
    })
    this.moveAnim.onFrame = (progress) => {
      this.pos.x = (1 - progress) * this.lastPos.x + this.TargetPos.x * progress;
      this.pos.y = (1 - progress) * this.lastPos.y + this.TargetPos.y * progress;
    }
    this.moveAnim.onFinish = () => {
      if(this.nextPage != PageId.NONE){
        this.updateOffset();
        this.curPage = this.nextPage;
        this.nextPage = PageId.NONE;
      }
      this.state = MotionState.IDLE;
      this.animPlay = false;
    }
  }

  down(pos:Vec2){
    if(!this.animPlay){
      Prompt.showToast({message:"down"})
      this.state = MotionState.DRAG
      this.downPos.x = pos.x;
      this.downPos.y = pos.y;
    }
  }

  move(pos:Vec2){
    if(this.state != MotionState.DRAG || this.animPlay) return;
    let raw:Vec2 = {x:pos.x - this.downPos.x,y:pos.y - this.downPos.y};
    raw = this.refract(raw);
    this.pos.x = this.applyRubberX(raw.x, this.minPos.x, this.maxPos.x);
    this.pos.y = this.applyRubberX(raw.y, this.minPos.y, this.maxPos.y);
    if (this.navDir === NavDirection.NONE) {
      if (this.pos.x >  0.1 * this.screenWidth) {
        this.navDir = NavDirection.LEFT;
      }
      if (this.pos.x < -0.1 * this.screenWidth) {
        this.navDir = NavDirection.RIGHT;
      }

    }
    if (this.navDir === NavDirection.LEFT) {
      if (this.pos.x < this.screenWidth * 0.05) {
        this.navDir = NavDirection.NONE;
      }
    }
    if (this.navDir === NavDirection.RIGHT) {
      if (this.pos.x > -this.screenWidth * 0.05) {
        this.navDir = NavDirection.NONE;
      }
    }
    this.nextPage = this.lookUpNextPage(this.navDir,this.curPage);
  }

  up(){
    if(this.state != MotionState.DRAG) return;
    if(!this.animPlay){
      if(this.nextPage != PageId.NONE){
        this.TargetPos = {x:this.screenWidth * ( 1- this.navDir), y:0};
      }else {
        this.TargetPos = {x:0, y:0};
      }
      this.animPlay = true;
      this.lastPos.x = this.pos.x;
      this.lastPos.y = this.pos.y;
      this.tempNavDir = this.navDir;
      this.navDir = NavDirection.NONE;
      this.moveAnim.play();

    }
  }

  // 辅助计算函数
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
  refract(raw:Vec2):Vec2{
    return {x:raw.x * 0.5, y: raw.y * 0.5};
  }
}