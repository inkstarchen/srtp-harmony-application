import { Vec2 } from "@kit.ArkGraphics3D";

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

@ObservedV2
export class TraceVec2{
  constructor(x:number = 0,y:number = 0) {
    this.x = x;
    this.y = y;
  }

  @Trace x:number = 0;
  @Trace y:number = 0;
}
@ObservedV2
export class TraceVec3{
  @Trace x:number = 0;
  @Trace y:number = 0;
  @Trace z:number = 0;
}

@ObservedV2
export class touchManager {
  constructor(pos:number) {
    this.pos = pos;
  }
  pos:number =0;
  @Trace down:Vec2 = {x:0,y:0}
  @Trace distance:TraceVec2 = new TraceVec2()

  touchDown(event:TouchEvent){
    this.down = {x:event.touches[this.pos].x, y:event.touches[this.pos].y}
  }

  touchMove(event:TouchEvent){
    this.distance.x = event.touches[this.pos].x - this.down.x
    this.distance.y = event.touches[this.pos].y - this.down.y
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