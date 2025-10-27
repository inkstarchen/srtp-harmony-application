import {Constants} from '../constants/Constants'
@ComponentV2
export struct SlotItem{
  @Param targetSlot:number = 0;
  @Param originId:number = 0;
  @Local borderOpts:BorderOptions | undefined = undefined;

  @Monitor('targetSlot')
  targetChange(monitor:IMonitor){
    this.getUIContext().getPromptAction().showToast({message:'yes' + this.targetSlot.toString()})
    if(this.originId == this.targetSlot){
      this.borderOpts = {width:2,radius:2,color:'#fff6f6f6'}
    }else{
      this.borderOpts = undefined;
    }
  }

  build() {
    Column(){

    }
    .width(Constants.BOOK_ITEM_WIDTH)
    .height('100%')
    .border(this.borderOpts)
    .animation({
      duration:200,
      curve:Curve.Rhythm,
      iterations:1
    })
  }
}