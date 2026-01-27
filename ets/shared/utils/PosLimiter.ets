import { TraceVec2 } from "../../core/math/vec";
import { Vec2 } from "@kit.ArkGraphics3D";

@ObservedV2
export class PosLimiter{
  @Trace pos:TraceVec2 = new TraceVec2();
  isShow: boolean = true;
  lastPos: Vec2 = {x:0, y:0};
  xMax:number;
  xMin:number;
  yMax:number;
  yMin:number;
  constructor(xMax: number, xMin: number, yMax:number ,yMin:number) {
    this.xMax = xMax;
    this.xMin = xMin;
    this.yMax = yMax;
    this.yMin = yMin;
  }

  update(target:TraceVec2){
    this.pos.x = this.lastPos.x + target.x;
    this.pos.y = this.lastPos.y + target.y;
    this.pos.clip(this.xMin, this.xMax, this.yMin, this.yMax);
  }
}