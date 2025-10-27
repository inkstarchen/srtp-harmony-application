import { Constants } from '../constants/Constants'
import { BookStateType } from '../utils/StateTypes'
import { ClickEventType } from '../utils/EventTypes'
import { Vec2 } from '@kit.ArkGraphics3D';

@ComponentV2
export struct BookItem{
  count:number = 0;
  moveFlag:boolean = false;
  @Local pos:Vec2 = {x:0,y:0}
  @Param itemId:number = 0;
  @Param originId:number = 0;
  @Param selectId:number = 0;
  @Param event:ClickEventType = ClickEventType.NONE_CLICK;
  @Local scaleV: number = 1;
  @Local zItemIndex: number = 0;
  @Local bookState:BookStateType = BookStateType.IDLE;

  @Local uiContext:UIContext = this.getUIContext()
  downX:number = 0;
  downY:number = 0;

  @Local distanceX:number = 0;
  @Local distanceY:number = 0;
  @Local itemTranslateX:number = 0;


  @Local angle:number = 0;

  @Local backZIndex:number = 0;
  @Local frontZIndex:number = 0;
  @Local wrapZIndex:number = 0;

  @Event setNoneEvent:() => void;
  @Event selectItem:(idx:number) => void;
  @Event startFit:(originId:number) => void;
  @Event pressUp:(originId:number) => void;

  @Monitor('event')
  eventTrigger(monitor:IMonitor){
    if(this.event == ClickEventType.NONE_CLICK) return;
    if(this.originId != this.selectId){
      this.itemTranslateX = this.itemId * (Constants.BOOK_ITEM_WIDTH + Constants.BOOK_ITEM_SPACE) + this.distanceX;
      this.bookState = BookStateType.IDLE
      this.distanceX = 0;
      this.distanceY = 0;
    }
    else{
      this.itemTranslateX = this.itemId * (Constants.BOOK_ITEM_WIDTH + Constants.BOOK_ITEM_SPACE) + this.distanceX;
      if(this.event == ClickEventType.BACKGROUND_CLICK){
        if(this.bookState ==  BookStateType.FOCUS){
          this.bookState = BookStateType.IDLE;
          this.selectItem(300);
        }else if(this.bookState == BookStateType.SHOW){
          this.bookState = BookStateType.FOCUS;
        }
      }else if(this.event == ClickEventType.BOOK_CLICK){
        if(this.bookState == BookStateType.IDLE){
          this.bookState = BookStateType.FOCUS
        }else if(this.bookState == BookStateType.FOCUS){
          this.bookState = BookStateType.SHOW
        }
      }
    }
    this.updateItem();
  }

  updateItem(){
    if(this.bookState == BookStateType.IDLE){
      this.itemTranslateX = this.itemId * (Constants.BOOK_ITEM_WIDTH + Constants.BOOK_ITEM_SPACE) + this.distanceX;
      this.distanceY = 0;
      this.zItemIndex = this.itemId;
      this.angle = (this.itemTranslateX - 200) / 10;
      this.scaleV = 1;
    }else if(this.bookState == BookStateType.FOCUS){
      this.scaleV = 1.5;
      this.itemTranslateX = this.itemId * (Constants.BOOK_ITEM_WIDTH + Constants.BOOK_ITEM_SPACE) + this.distanceX - 10;
      this.angle = (this.itemTranslateX - 200) / 10;
      this.distanceY = -10;
      this.zItemIndex = 300;
    }else if(this.bookState == BookStateType.SHOW){
      this.itemTranslateX = (Constants.BOOK_BOX_WIDTH - Constants.BOOK_ITEM_WIDTH) / 2;
      this.distanceY = 200;
      this.scaleV = 4;
      this.angle = -90;
      this.zItemIndex = 300;
    }
    if(this.angle > 0){
      this.backZIndex = 3;
      this.wrapZIndex = 2;
      this.frontZIndex = 1;
    }else{
      this.backZIndex = 1;
      this.wrapZIndex = 2;
      this.frontZIndex = 3;
    }
    this.setNoneEvent();
  }

  aboutToAppear(): void {
    this.updateItem()
    this.zItemIndex = this.itemId;
  }


  build() {
    Row(){
      Column(){

      }
      .backgroundColor('#ffffffff')
      .width(Constants.BOOK_LENGTH)
      .height(Constants.BOOK_BOX_HEIGHT)
      .translate({x:( Constants.BOOK_WIDTH - Constants.BOOK_LENGTH) / 2,y:0,z:(Constants.BOOK_LENGTH - Constants.BOOK_WIDTH) / 2})
      .rotate({y:1,centerX:'50%',centerZ: this.uiContext.vp2px(Constants.BOOK_WIDTH / 2) ,angle: -90 + this.angle})
      .zIndex(this.backZIndex)
      .animation({
        duration:500,
        curve:Curve.EaseOut,
        iterations:1,
      })
      Column(){

      }
      .backgroundColor('#ffffffff')
      .grayscale((this.bookState == BookStateType.IDLE && this.selectId != 300)? 0.5 :0)
      .width(Constants.BOOK_WIDTH)
      .height(Constants.BOOK_BOX_HEIGHT)
      .translate({x: -Constants.BOOK_LENGTH,y:0})
      .rotate({y:1,centerX:'50%',centerZ: this.uiContext.vp2px(Constants.BOOK_LENGTH / 2),angle: this.angle})
      .zIndex(this.wrapZIndex)
      .animation({
        duration:500,
        curve:Curve.EaseOut,
        iterations:1,
      })
      Column(){

      }
      .width(Constants.BOOK_LENGTH)
      .height(Constants.BOOK_BOX_HEIGHT)
      .translate({x:-(Constants.BOOK_LENGTH * 3 + Constants.BOOK_WIDTH )/ 2,y:0,z:(Constants.BOOK_LENGTH - Constants.BOOK_WIDTH) / 2})
      .rotate({y:1,centerX:'50%',centerZ: this.uiContext.vp2px(Constants.BOOK_WIDTH / 2) ,angle: 90 + this.angle})
      .backgroundColor('#ffefefef')
      .shadow({offsetX:-5,color: '#9fa0a0a0',radius:5 })
      .grayscale((this.bookState == BookStateType.IDLE && this.selectId != 300) ? 0.5 :0)
      .zIndex(this.frontZIndex)
      .animation({
        duration:500,
        curve:Curve.EaseOut,
        iterations:1,
      })
    }
    .translate({x:this.itemTranslateX,y:this.distanceY})
    .scale({x:this.scaleV,y:this.scaleV,z:this.scaleV})
    .animation({
      duration:500,
      curve:Curve.EaseOut,
      iterations:1,
    })
    .gesture(
      LongPressGesture({ repeat: true })
      // 由于repeat设置为true，长按动作存在时会连续触发，触发间隔为duration（默认值500ms）
        .onAction((event: GestureEvent) => {
          if (event && event.repeat) {
            this.count++
          }
        })
        // 长按动作一结束触发
        .onActionEnd((event: GestureEvent) => {
          this.count = 0
        })
    )
    .onTouch((event) => {
      if(event.type == TouchType.Down){
        // if(this.bookState == BookStateType.FOCUS){
        //   this.getUIContext().getPromptAction().showToast({message:'focus'})
        // }else if(this.bookState == BookStateType.IDLE){
        //   this.getUIContext().getPromptAction().showToast({message:'idle'})
        // }else{
        //   this.getUIContext().getPromptAction().showToast({message:'show'})
        // }
        this.downX = event.touches[0].windowX;
        this.downY = event.touches[0].windowY;
      }else if(event.type == TouchType.Move && this.count >= 1) {
        this.bookState = BookStateType.FOCUS;
        this.moveFlag = true;
        this.distanceX = event.touches[0].windowX - this.downX;
        this.distanceY = event.touches[0].windowY - this.downY;
        this.itemTranslateX = this.itemId * (Constants.BOOK_ITEM_WIDTH + Constants.BOOK_ITEM_SPACE) + this.distanceX;
        // this.getUIContext().getPromptAction().showToast({message:this.itemTranslateX.toString()})
        this.angle = (this.itemTranslateX - 200 ) / 10 + this.distanceX;
        if(this.angle > 0){
          this.backZIndex = 3;
          this.wrapZIndex = 2;
          this.frontZIndex = 1;
        }else{
          this.backZIndex = 1;
          this.wrapZIndex = 2;
          this.frontZIndex = 3;
        }
        this.zItemIndex = 300;
        this.startFit(this.originId);
      }else if(event.type == TouchType.Up){
        this.zItemIndex = this.itemId;
        this.distanceX = 0
        this.distanceY = 0
        if(this.moveFlag){
          this.pressUp(this.originId);
          this.moveFlag = false;
        }else{
          // this.getUIContext().getPromptAction().showToast({message:this.originId.toString()})
          this.selectItem(this.originId);
        }
      }
    })
    .position({x:0,y:0})
    .id('book'+ this.originId.toString())
    .width(Constants.BOOK_ITEM_WIDTH)
    .height('100%')
    .zIndex(this.zItemIndex)

  }
}