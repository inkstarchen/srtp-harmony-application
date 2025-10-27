import { Vec2 } from "@kit.ArkGraphics3D";
import { Constants } from "../constants/Constants";
import { History } from "./ClassUtils";
import { CanvasControlType, CanvasStateTypes } from "./Types";

@ObservedV2
export class CanvasController{
  @Trace state:CanvasStateTypes = CanvasStateTypes.PENCIL;
  @Trace touch:boolean = false;
  @Trace eraseLineWidth:number = 40;
  @Trace context:CanvasRenderingContext2D | undefined = undefined;
  eraseColor:string = '#fff'
  @Trace lineWidth:number = 2;
  @Trace color:string = '#fff'
  @Trace pixelHistory: History<PixelMap> = new History<PixelMap>()
  penTrace:Vec2[] = []
  uiContext:UIContext | undefined = undefined;

  init(context:CanvasRenderingContext2D, uiContext:UIContext){
    this.context = context;
    this.context.lineCap = 'round'
    this.uiContext = uiContext;
    let pixelMap = this.context.getPixelMap(0,0,this.uiContext.px2vp(Constants.MATE_60_PRO_WIDTH),this.uiContext.px2vp(Constants.MATE_60_PRO_HEIGHT) * 0.8)
    this.pixelHistory.newHistory(pixelMap)
  }

  setPen(){
    if(this.context == undefined) return;
    this.state = CanvasStateTypes.PENCIL;
    this.context.strokeStyle = this.color;
    this.context.lineWidth = this.lineWidth;
  }

  setErase(){
    if(this.context == undefined) return;
    this.state = CanvasStateTypes.ERASE
    this.context.strokeStyle = this.eraseColor
    this.context.lineWidth = this.eraseLineWidth
  }

  setLineWidth(wid:number){
    if(this.context == undefined) return;
    this.lineWidth = wid;
    this.context.lineWidth = wid;
  }

  setColor(color:string){
    if(this.context == undefined) return;
    this.color = color;
    this.context.strokeStyle = color;
  }

  handleEvent(event:CanvasControlType){
    if(this.context == undefined || this.uiContext == undefined) return;
    this.context.save()
    this.context.fillStyle = '#fff'
    this.context.fillRect(0,0,this.uiContext.px2vp(Constants.MATE_60_PRO_WIDTH),this.uiContext.px2vp(Constants.MATE_60_PRO_HEIGHT) * 0.8)
    this.context.restore()
    let pixelMap:PixelMap |undefined = undefined;
    switch (event){
      case CanvasControlType.UNDO:{
        pixelMap = this.pixelHistory.back();
        console.info('canvas back info ')
        break;
      }
      case CanvasControlType.REDO:{
        pixelMap = this.pixelHistory.forward();
        console.info('canvas forward info ')
        break;
      }
      default :
        break;
    }
    if(pixelMap == undefined) return;
    this.context?.setPixelMap(pixelMap);
  }

  handleTouch(touch:TouchEvent){
    if(this.uiContext == undefined) return;
    if(this.context == undefined) return;
    if(touch.type == TouchType.Down){
      this.touch = true;
      for(let i = 0 ; i < 3 ; i++){
        this.penTrace.push({x:touch.touches[0].x,y:touch.touches[0].y})
      }
    }else if(touch.type == TouchType.Move){
      for(let i = 0 ; i < 2; i++){
        this.penTrace[i] = this.penTrace[i+1]
      }
      this.penTrace[2] = {x:touch.touches[0].x,y:touch.touches[0].y}
      let x1 = (this.penTrace[0].x + this.penTrace[1].x) / 2;
      let y1 = (this.penTrace[0].y + this.penTrace[1].y) / 2;
      let x2 = (this.penTrace[1].x + this.penTrace[2].x) / 2;
      let y2 = (this.penTrace[1].y + this.penTrace[2].y) / 2;
      this.context.beginPath()
      this.context.lineCap = 'round'
      this.context.moveTo(x1,y1)
      this.context.quadraticCurveTo(this.penTrace[1].x,this.penTrace[1].y,x2,y2)
      this.context.stroke()

    }else if(touch.type == TouchType.Up){
      this.touch = false;
      for(let i = 0 ; i < 3; i++){
        this.penTrace.pop()
      }
      let pixelMap = this.context.getPixelMap(0,0,this.uiContext.px2vp(Constants.MATE_60_PRO_WIDTH),this.uiContext.px2vp(Constants.MATE_60_PRO_HEIGHT) * 0.8)
      this.pixelHistory.newHistory(pixelMap)
    }
  }
}