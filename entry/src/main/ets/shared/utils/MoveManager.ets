import { Vec2 } from '@kit.ArkGraphics3D';
import { TraceVec2 } from '../../core/math/vec';

@ObservedV2
export class MoveManager{
  targetIndex:number = -1;
  startPos: Vec2 = {x:0,y:0};
  lastPos: Vec2 = {x:0,y:0};
  start(startPos:TraceVec2,lastPos:Vec2){
    this.startPos.x = startPos.x;
    this.startPos.y = startPos.y;
    this.lastPos.x = lastPos.x;
    this.lastPos.y = lastPos.y;
  }

  move(curPos:Vec2):Vec2{
    return {
      x: this.startPos.x + curPos.x - this.lastPos.x,
      y: this.startPos.y + curPos.y - this.lastPos.y,
    };
  }
}