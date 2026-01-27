import { TraceVec2 } from "../../core/math/vec";
import Prompt from "@system.prompt";

@ObservedV2
export class TouchManager{
  down: TraceVec2 = new TraceVec2();
  @Trace distance: TraceVec2 = new TraceVec2();
  up:TraceVec2 = new TraceVec2();

  TouchDown(event:TouchEvent){
    this.down.x = event.touches[0].x;
    this.down.y = event.touches[0].y;
    // Prompt.showToast({message:'down'});
  }

  TouchUp(event:TouchEvent){
    this.up.x = event.touches[0].x;
    this.up.y = event.touches[0].y;
    // Prompt.showToast({message:'up'});
  }

  TouchMove(event:TouchEvent){
    this.distance.x = event.touches[0].x - this.down.x;
    this.distance.y = event.touches[0].y - this.down.y;
    // Prompt.showToast({message:'move'});
  }
}