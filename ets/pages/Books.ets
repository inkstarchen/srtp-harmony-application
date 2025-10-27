import { ClickEventType } from '../utils/EventTypes'
import { Constants } from '../constants/Constants'
import { BookItem } from '../Components/bookItem';
import { SlotItem } from '../Components/slotItem'
import { CalcUtils } from '../utils/calutils'
import { ComponentUtils} from '@kit.ArkUI';
import { Vec2 } from '@kit.ArkGraphics3D'

class Resource{
  id:number = 0;
  originId:number = 0;
}

@Entry
@ComponentV2
struct Books{
  @Local source:Resource[] = [{id:0,originId:0},{id:1,originId:1},{id:2,originId:2},{id:3,originId:3},{id:4,originId:4}]
  @Local event: ClickEventType = ClickEventType.NONE_CLICK;
  @Local distanceX:number = 0;
  @Local distanceY:number = 0;
  @Local selectId:number = 300;
  @Local targetSlot:number = 0;
  componentUtil: ComponentUtils = this.getUIContext().getComponentUtils();
  originSlot:number = 0;

  selectTimerId:number | null = null;

  aboutToAppear(): void {
    this.selectId = this.source.length;
  }

  resetEvent(){
    this.event = ClickEventType.NONE_CLICK;
  }

  reArrangeBook(originId:number){
    let count = this.source.length;
    if(this.targetSlot == count) return;
    console.info('origin:' + this.originSlot + 'target' + this.targetSlot)
    if(this.originSlot > this.targetSlot){
      for(let i = 0; i < count; i++){
        if(this.source[i].id < this.originSlot && this.source[i].id >= this.targetSlot){
          this.source[i].id++;
        }
      }
    }else if(this.originSlot < this.targetSlot){
      for(let i = 0; i < count; i++){
        if(this.source[i].id  > this.originSlot && this.source[i].id <= this.targetSlot){
          this.source[i].id--;
        }
      }
    }
    this.source[originId].id = this.targetSlot;
    this.event = ClickEventType.BACKGROUND_CLICK;
  }

  pressUp(originId:number){
    if(this.selectTimerId != null){
      clearInterval(this.selectTimerId)
      this.selectTimerId = null;
    }
    this.reArrangeBook(originId);
    this.event = ClickEventType.BACKGROUND_CLICK;
    this.selectId = 300
  }

  startFit(originId:number){

    this.originSlot = this.source[originId].id;
    if(this.selectTimerId != null) return;
    this.selectTimerId = setInterval(()=>{
      this.originSlot = this.selectId;
      let count = this.source.length;
      for(let i = 0; i <= count ; i++){
        if(i==count) this.targetSlot = count;
        let uiInfo = this.componentUtil.getRectangleById('book' + originId.toString());
        let uiPoint = {x:Constants.BOOK_ITEM_WIDTH / 2 + uiInfo.translate.x,y: Constants.BOOK_BOX_HEIGHT / 2 + uiInfo.translate.y} as Vec2
        this.getUIContext().getPromptAction().showToast({message:'uix:' + uiPoint.x.toString() + '/y:' + uiPoint.y.toString()})
        if(CalcUtils.CalSlot(uiPoint,i)){
          this.targetSlot = i;
          return;
        }
      }
    },250)
  }

  build() {
    Column(){
      Column(){

      }
      .width('100%')
      .height('100%')
      .backgroundColor('#ffff0000')
      .onClick(() => {
        this.event = ClickEventType.BACKGROUND_CLICK;
      })


      Column(){
        Row({space:Constants.BOOK_ITEM_SPACE}){
          ForEach(this.source,(item:Resource) => {
            SlotItem({
              targetSlot:this.targetSlot,
              originId:item.originId
            })
          })
        }.position({x:0,y:0})
        Stack(){
          ForEach(this.source,(item:Resource) => {
            BookItem({
              itemId:item.id,
              originId:item.originId,
              event:this.event,
              selectId:this.selectId,
              selectItem:(originId:number) => {
                this.selectId = originId;

                // this.getUIContext().getPromptAction().showToast({message:this.selectId.toString()})
                this.event = ClickEventType.BOOK_CLICK
              },
              setNoneEvent:() => {
                this.event = ClickEventType.NONE_CLICK
              },
              pressUp:(originId:number) => {
                this.pressUp(originId);
              },
              startFit:(originId:number) => {
                this.startFit(originId)
              }
            })
              // .backgroundColor('#fffc0000')
          })
        }
        .position({x:0,y:0})
        .width('100%')
        .height('100%')

      }
      .position({x:40,y:10})
      .width(Constants.BOOK_BOX_WIDTH)
      .height(Constants.BOOK_BOX_HEIGHT)
      Text('x:'+this.distanceX.toString() + 'y:' + this.distanceY.toString())
    }
    .backgroundImage($r('app.media.img'))
    .backgroundColor('#ffececec')
    .width('100%')
    .height('100%')
    .onTouch((event) => {
      this.getUIContext().getRouter().pushUrl({
        url:'pages/GraphicsController',

      })
      if(event.type == TouchType.Move){
        this.distanceX = event.touches[0].windowX;
        this.distanceY = event.touches[0].windowY;
      }
    })


  }
}