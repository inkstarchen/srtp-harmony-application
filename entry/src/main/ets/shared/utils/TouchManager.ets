import { TraceVec2 } from "../../core/math/vec";
import Prompt from "@system.prompt";
import { Vec2 } from "@kit.ArkGraphics3D";

export interface Touch{
  phase: number;
  active: boolean;
  downPos: Vec2;
  curPos: Vec2;
  lastPos: Vec2;
}

export function getTouchDefault() : Touch{
  return {
    phase: 0,
    active: false,
    downPos : {x:0,y:0},
    curPos : {x:0, y:0},
    lastPos : {x:0,y:0},
  };
}

export const TOUCH_DEFAULT = {
  phase :0,
  active : false,
  downPos : {x:0,y:0},
  curPos : {x:0, y:0},
  lastPos : {x:0,y:0},
} as Touch;

export function HandleTouch(event:TouchEvent, touch: Touch) {
  if (event.type === TouchType.Down) {
    TouchDown(event,touch);
  } else if (event.type === TouchType.Move) {
    TouchMove(event,touch)
  } else if (event.type === TouchType.Up) {
    TouchUp(event,touch)
  }
}

export function TouchDown(event:TouchEvent, touch: Touch){
  touch.downPos.x = event.touches[0].x;
  touch.downPos.y = event.touches[0].y;
  touch.active = true;
  touch.curPos.x = event.touches[0].x;
  touch.curPos.y = event.touches[0].y;
  touch.phase = 1;
  touch.lastPos.x = event.touches[0].x;
  touch.lastPos.y = event.touches[0].y;
}

export function TouchUp(event:TouchEvent, touch: Touch){
  touch.active = false;
  touch.curPos.x = event.touches[0].x;
  touch.curPos.y = event.touches[0].y;
  touch.phase = 3;
  // Prompt.showToast({message:'up'});
}

export function TouchMove(event:TouchEvent, touch: Touch){
  touch.lastPos.x = touch.curPos.x;
  touch.lastPos.y = touch.curPos.y;
  console.info("Rotation Test | cur" + touch.curPos.x.toString() + '/' + touch.curPos.y.toString() + ' | last' + touch.lastPos.x + '/' + touch.lastPos.y.toString())
  touch.curPos.x = event.touches[0].x;
  touch.curPos.y = event.touches[0].y;
  touch.phase = 2;
  // Prompt.showToast({message:'move'});
}

export interface RotationState {
  latitude: number;
  longitude: number;
}

@ObservedV2
export class RotationTouchManager{
  startPos:Vec2 = {x:0,y:0};
  start(startPos:Vec2){
    this.startPos.x = startPos.x;
    this.startPos.y = startPos.y;
  }

  move(curPos:Vec2):Vec2{
    return {x:curPos.x - this.startPos.x, y:curPos.y - this.startPos.y};
  }

}