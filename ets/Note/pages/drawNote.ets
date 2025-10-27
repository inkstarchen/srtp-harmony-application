import { LengthMetricsUnit } from '@kit.ArkUI'
import { CanvasController } from '../CanvasClass/CanvasClass'
import { CanvasControlType, CanvasStateTypes } from '../CanvasClass/Types';
import { Board } from '../Components/board';
import { PenBoard } from '../Components/PenBoard';
import { util } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit'
import { touchManager } from '../CanvasClass/ClassUtils';


@Entry
@ComponentV2
struct drawNote{
  settings: RenderingContextSettings = new RenderingContextSettings(true)
  canvasController: CanvasController = new CanvasController();
  @Local touchM:touchManager = new touchManager();
  @Local boardEnable: boolean = false;
  onPageShow(): void {
    this.init()
  }

  init(){
    this.canvasController.init(new CanvasRenderingContext2D(this.settings),this.getUIContext())
  }

  handleControlEvent(event:CanvasControlType){
    switch (event){
      case CanvasControlType.ENABLE:{
        this.canvasController.setPen();
        this.boardEnable = !this.boardEnable;
        break;
      }
      case CanvasControlType.ERASE:{
        this.canvasController.setErase();
        break;
      }
      case CanvasControlType.UNDO:{
        this.canvasController.handleEvent(event);
        break;
      }
      case CanvasControlType.REDO:{
        this.canvasController.handleEvent(event);
        break;
      }
      default :
        break;
    }

  }

  build() {
    Column(){
      if(this.canvasController.state == CanvasStateTypes.ERASE && this.canvasController.touch){
        Column(){

        }
        .width(this.canvasController.eraseLineWidth)
        .height(this.canvasController.eraseLineWidth)
        .position(this.touchM.down)
        .translate({x:-this.canvasController.eraseLineWidth/2,y:-this.canvasController.eraseLineWidth/2})
        .border({color:'#ff000000',width:1,radius:this.canvasController.eraseLineWidth})
        .zIndex(10)
      }


      Column({space:10}){

        PenBoard({
          sendControl:(event:CanvasControlType) =>{
            this.handleControlEvent(event)
          },
        })
          .zIndex(10)
        if(this.boardEnable){
          Board({
            changeLineWidth:(value:number) => {
              this.canvasController.setLineWidth(value);
            },
            changeColor:(value:string) => {
              this.canvasController.setColor(value);
            }
          })
        }
      }
      .position({x:0,y:0})
      .zIndex(10)


      Canvas(this.canvasController.context)
        .height('80%')
        .width('100%')
        .backgroundColor('#ffffffff')
        .onTouch((event:TouchEvent) => {
          this.touchM.touchDown(event)
          this.canvasController.handleTouch(event)
        })
      Text(this.canvasController.pixelHistory.index +  '/' + (this.canvasController.pixelHistory.length - 1))
    }
    .width('100%')
    .height('100%')
  }

}