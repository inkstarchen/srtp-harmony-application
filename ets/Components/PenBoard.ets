import { touchManager, TraceVec2 } from "../CanvasClass/ClassUtils";
import { Constants } from "../constants/Constants";
import { Vec2 } from "@kit.ArkGraphics3D";
import { AnimatorResult } from "@kit.ArkUI";
import { CanvasControlType} from "../CanvasClass/Types";
import { Board } from "./board";
import { it } from "@ohos/hypium";

enum PenBoardStateType{
  Fold = 0,
  Unfold = 1
}

@ComponentV2
export struct PenBoard{
  @Local state:PenBoardStateType = PenBoardStateType.Fold
  @Local MainWidth:number = 40;
  @Local MainHeight:number = 40;
  @Local touchM:touchManager = new touchManager(0);
  posLast: Vec2 = {x:0,y:0}
  @Local posNow: TraceVec2 = new TraceVec2()
  @Local testMode: boolean = false;
  LongPress: boolean = false;
  borderAnimation: AnimatorResult | undefined = undefined
  @Event sendControl:(event:CanvasControlType) => void;
  @Local boardImg:Resource[] = [$r('app.media.pencil_line_1'),$r('app.media.eraser_line'),$r('app.media.undo'),$r('app.media.redo')]
  @Local selectItem:number = 5;
  aboutToAppear(): void {
    this.init()
  }

  init(){
    this.borderAnimation = this.getUIContext().createAnimator({
      duration:500,
      delay:0,
      fill:'forwards',
      direction:'normal',
      begin:0,
      end:1,
      easing:'ease-in-out',
      iterations:1
    })
    this.borderAnimation.onFrame = (progress:number) => {
      if(this.state == PenBoardStateType.Fold){
        this.MainWidth = 40 + progress * 200;
      }else if(this.state == PenBoardStateType.Unfold){
        this.MainWidth = 240 - progress * 200
      }
    }

    this.borderAnimation.onFinish = () => {
      if(this.state == PenBoardStateType.Fold){
        this.state = PenBoardStateType.Unfold
      }else if(this.state == PenBoardStateType.Unfold){
        this.state = PenBoardStateType.Fold
      }
    }
  }

  build() {
      Row({space:15}){
            if(this.state == PenBoardStateType.Unfold){
              Column(){
                Image($r('app.media.arrow_up_left'))
                  .width(Constants.ROUND_R)
                  .height(Constants.ROUND_R)
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .width(Constants.ROUND_R_OUTER)
              .height(Constants.ROUND_R_OUTER)
              .borderRadius(Constants.ROUND_R_OUTER)
              .width(Constants.ROUND_R_OUTER)
              .margin({left:10})
              .onClick(() => {
                if(this.state == PenBoardStateType.Unfold){
                  this.borderAnimation?.play()
                }
              })
              ForEach(this.boardImg,(item:Resource,index:number) => {
                Column(){
                  Image(item)
                    .width(Constants.ROUND_R)
                    .height(Constants.ROUND_R)
                }
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .width(Constants.ROUND_R_OUTER)
                .height(Constants.ROUND_R_OUTER)
                .borderRadius(Constants.ROUND_R_OUTER)
                .backgroundColor(this.selectItem == index ? '#95c3c3c3' : '#fff')
                .onTouch((event) => {
                  if(event.type == TouchType.Down){
                    this.selectItem = index
                  }else if(event.type == TouchType.Up){
                    this.selectItem = 5
                  }
                })
                .animation({
                  duration:500,
                  delay:0,
                  iterations:1,
                  curve:Curve.EaseInOut
                })
                .onClick(() => {
                  this.sendControl(index)
                })
              })

            }
      }
      .clip(true)
      .backgroundColor('#ffffffff')
      .shadow({color:'#ffd9d9d9',radius:10})
      .position({x:0,y:0})
      .translate(this.posNow)
      .width(this.MainWidth)
      .height(this.MainHeight)
      .zIndex(5)
      .borderRadius(35)
      .alignItems(VerticalAlign.Center)
      .gesture(
        LongPressGesture({ repeat: true })
        // 由于repeat设置为true，长按动作存在时会连续触发，触发间隔为duration（默认值500ms）
          .onAction((event: GestureEvent) => {
            if (event && event.repeat) {
              this.LongPress = true;
            }
          })
          // 长按动作一结束触发
          .onActionEnd((event: GestureEvent) => {
            this.LongPress = false;
          })
      )
      .onClick(() => {
        if(this.state == PenBoardStateType.Fold){
          this.borderAnimation?.play()
        }
      })
      .onTouch((event:TouchEvent) => {
        switch (event.type){
          case TouchType.Down:{
            this.touchM.touchDown(event);
            break;
          }
          case TouchType.Move:{
            this.touchM.touchMove(event);
            this.posNow.x = this.posLast.x + this.touchM.distance.x
            this.posNow.y = this.posLast.y + this.touchM.distance.y
            break;
          }
          case TouchType.Up:{
            this.posLast = {x:this.posNow.x, y: this.posNow.y}
            break;
          }
          default :
            break;
        }
      })


  }
}