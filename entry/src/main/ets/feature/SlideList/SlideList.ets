import { Vec2 } from "@kit.ArkGraphics3D"
import { TraceVec2 } from "../../core/math/vec";
import { getTouchDefault, HandleTouch, Touch } from "../../shared/utils/TouchManager";
import Prompt from "@system.prompt";
import { AnimatorResult } from "@kit.ArkUI";
import { DateItem, SlidingDateModel } from "../../shared/utils/Time/SlideTimeModel";
import { circularDelta } from "../../core/math/mathUtil";
import { ThemeManager, ThemeState } from "../../theme/core/ThemeManager";
import { colorWithAlpha } from "../../shared/utils/ColorUtil";

export enum TouchState{
  IDLE = 0,
  MOVE = 1,
}

export interface DisplayItem{
  dataInfo: DateItem;
  index: number;
}

const ITEM_SPACE = 10;
const ITEM_WIDTH = 40;
const ITEM_HEIGHT = 40;

@ComponentV2
export struct SlideList{
  @Local weekStr: string = SlidingDateModel.createItem(new Date(),0).weekStr;
  @Local dayStr: string = SlidingDateModel.createItem(new Date(),0).dayStr;
  @Local display:boolean = false;
  @Local TimeLineOpacity: number = 0;

  init:boolean = false;
  @Local themeManager:ThemeManager = ThemeManager.getInstance();
  @Local themeState:ThemeState = this.themeManager.getThemeState();
  @Local touchM:Touch = getTouchDefault();
  @Local DisplayList: DisplayItem[] = [];

  @Local hitAble:boolean = false;
  @Event setItem:(item:DateItem) => void;
  @Event setOpacity:() => void;
  @Param timeOpacity:number = 0;
  touchState: TouchState = TouchState.IDLE;
  @Local distance: TraceVec2 = new TraceVec2();

  @Local fadeOpacity: number = 0;
  fadeTarget: number = 0;
  fadeLast:number = 0;

  playAnim:boolean = false;
  targetPos:number = 0;
  lastPos:number = 0;

  selectedIndex:number = 3;
  change: boolean = false;
  resetAnim:AnimatorResult = this.getUIContext().createAnimator({
    duration:100,
    iterations:1,
    fill:'forwards',
    delay:0,
    direction:"normal",
    begin:0,
    easing:"ease-in-out",
    end:1
  })
  FadeAnim: AnimatorResult = this.getUIContext().createAnimator({
    duration:500,
    iterations:1,
    fill:"forwards",
    delay:0,
    direction:"normal",
    easing:"ease-in-out",
    begin:0,
    end:1
  })

  @Monitor('display')
  onDisplayChange(monitor:IMonitor){
    let displayNow = monitor.value()?.now as boolean;
    if(displayNow){
      this.fadeTarget = 1;
      this.fadeLast = this.fadeOpacity;
      this.FadeAnim.play();
    }
  }

  aboutToAppear(): void {
    if(!this.init){
      this.init = true;
      this.createItem();
      this.resetAnim.onFrame = (progress) => {
        this.distance.x = progress * this.targetPos + (1 - progress) * this.lastPos;
      }
      this.resetAnim.onFinish = () => {
        if(this.distance.x > 0){
          let newData = SlidingDateModel.createItem(this.DisplayList[(this.selectedIndex + 3) % 7].dataInfo.date,-7);
          this.DisplayList[(this.selectedIndex + 3) % 7] = {dataInfo:newData,index:(this.selectedIndex + 3) % 7};
          this.selectedIndex  = (this.selectedIndex + 6) % 7;
          this.change = true;
        }else if(this.distance.x < 0){
          let newData = SlidingDateModel.createItem(this.DisplayList[(this.selectedIndex + 7 - 3) % 7].dataInfo.date,7);
          this.DisplayList[(this.selectedIndex + 7 - 3) % 7] = {dataInfo:newData,index:(this.selectedIndex + 7 - 3) % 7};
          this.selectedIndex  = (this.selectedIndex + 1) % 7;
          this.change = true;
        }
        this.playAnim = false;
        this.distance.x = 0;
        if(!this.change){
          this.display = false;
          if (this.TimeLineOpacity) {
            this.TimeLineOpacity = 0;
          } else {
            this.TimeLineOpacity = 0.5;
          }
          this.fadeTarget = 0;
          this.fadeLast = this.fadeOpacity;
          this.FadeAnim.play();
        }else{
          this.setItem(this.DisplayList[this.selectedIndex].dataInfo);
          this.weekStr = this.DisplayList[this.selectedIndex].dataInfo.weekStr;
          this.dayStr = this.DisplayList[this.selectedIndex].dataInfo.dayStr;
        }

        this.change = false;
      }
      this.FadeAnim.onFrame = (progress) => {
        this.fadeOpacity = (1 - progress) * this.fadeLast + progress * this.fadeTarget;
      }
      this.FadeAnim.onFinish = () => {
        this.hitAble = !this.hitAble;
      }
    }
  }

  createItem(){
    let now = new Date();
    for(let i = -3; i <4; i++){
      let item = SlidingDateModel.createItem(now,i);
      this.DisplayList.push({dataInfo:item, index: i + 3});
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Stack({alignContent:Alignment.Center}){
        ForEach(this.DisplayList, (item:DisplayItem, index) => {

          Column(){
            Text(item.dataInfo.weekStr)
              .fontSize(12)
              .fontColor(this.themeState.tokens.onBackground)
            Text(item.dataInfo.dayStr)
              .fontSize(20)
              .fontWeight(500)
              .fontColor(this.themeState.tokens.onBackground)
          }
          .translate({x:circularDelta(item.index,this.selectedIndex,7) * (ITEM_HEIGHT + ITEM_SPACE) + this.distance.x})
          .width(ITEM_WIDTH)
          .opacity(this.fadeOpacity)
          .height(ITEM_HEIGHT)
        },(item: DisplayItem,index) => {
          console.log("keyGen" + index.toString() + item.index.toString() +  item.dataInfo.dayStr )
          return item.dataInfo.timestamp.toString();
        })
        Rect()
          .fill("#00ffffff")
          .width("100%")
          .height("100%")
          .linearGradient({direction:GradientDirection.Left,colors:[
            [this.themeState.tokens.surface,0.0],
            [this.themeState.tokens.surface,0.05],
            [colorWithAlpha(this.themeState.tokens.surface,0),0.5],
            [this.themeState.tokens.surface,0.95],
            [this.themeState.tokens.surface,1.0]]})
      }
      .height("100%")
      .clip(true)
      .translate({y:1})
      .backgroundColor("#00ffffff")
      .hitTestBehavior(this.display ? HitTestMode.Default : HitTestMode.None)
      .onTouch((event) => {
        if(!this.playAnim){
          HandleTouch(event,this.touchM);
          if(this.touchState == TouchState.IDLE && event.type == TouchType.Down){
            this.touchState = TouchState.MOVE;
          }
          else if(this.touchState == TouchState.MOVE && event.type === TouchType.Move){
            this.distance.x = this.touchM.curPos.x - this.touchM.downPos.x;
            let itemNum = 0;
            if(this.distance.x > 0){
              itemNum = Math.floor(this.distance.x / (ITEM_WIDTH + ITEM_SPACE));
            } else {
              itemNum = Math.ceil(this.distance.x / (ITEM_WIDTH + ITEM_SPACE));
            }

            if(itemNum !== 0){
              this.distance.x -= (ITEM_WIDTH + ITEM_SPACE) * itemNum;
              if(itemNum > 0){
                let newData = SlidingDateModel.createItem(this.DisplayList[(this.selectedIndex + 3) % 7].dataInfo.date,-7);
                this.DisplayList[(this.selectedIndex + 3) % 7] = {dataInfo:newData,index:(this.selectedIndex + 3) % 7};
                this.selectedIndex  = (this.selectedIndex + 6) % 7;
                this.change = true;
              }else if(itemNum < 0){
                let newData = SlidingDateModel.createItem(this.DisplayList[(this.selectedIndex + 7 - 3) % 7].dataInfo.date,7);
                this.DisplayList[(this.selectedIndex + 7 - 3) % 7] = {dataInfo:newData,index:(this.selectedIndex + 7 - 3) % 7};
                this.selectedIndex  = (this.selectedIndex + 1) % 7;
                this.change = true;
              }
              this.touchM.downPos.x = this.touchM.curPos.x;
            }

          }
          else if(this.touchState == TouchState.MOVE && event.type === TouchType.Up){
            this.touchState = TouchState.IDLE;
            this.lastPos = this.distance.x;
            if(Math.abs(this.distance.x) < ITEM_WIDTH / 2){
              this.targetPos = 0;
            }
            else if(this.distance.x < 0){
              this.targetPos = -(ITEM_WIDTH + ITEM_SPACE);
            }
            else if(this.distance.x > 0){
              this.targetPos = (ITEM_WIDTH + ITEM_SPACE);
            }
            if(this.resetAnim){
              this.playAnim = true;
              this.resetAnim?.play();
            }
          }
        }
      })
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          Text(this.weekStr)
            .fontSize(12)
          Text(this.dayStr)
            .fontSize(20)
            .fontWeight(500)
        }
      }
      .width("100%")
      .height(50)
      .opacity(this.TimeLineOpacity ? 0 : 1)
      .backgroundColor("#00ffffff")
      .animation({
        duration: 500,
        iterations: 1,
        delay: 0,
        curve: Curve.Linear
      })
      .onClick(() => {
        this.display = true;
        this.fadeTarget = 1;
        this.fadeLast = this.fadeOpacity;
        this.FadeAnim.play();
        if (this.TimeLineOpacity) {
          this.TimeLineOpacity = 0;
        } else {
          this.TimeLineOpacity = 0.5;
        }
      })
      .hitTestBehavior(this.display ? HitTestMode.BLOCK_DESCENDANTS : HitTestMode.Default)
    }
    .hitTestBehavior(HitTestMode.None)
    .width("100%")
    .height("100%")
  }
}