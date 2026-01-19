import { ButtonData } from "../SideBarState"
import Prompt from "@system.prompt";

@ComponentV2
export struct SideBarButton{

  @Require @Param state: ButtonData;
  @Require @Param Click: () => void;

  build() {
    Column(){
      Image(this.state.imgSrc)
        .width(30)
        .width(30)
      Text(this.state.title)
        .margin({ top:2 })
        .fontSize(10)
    }
    .justifyContent(FlexAlign.Center)
    .border({radius:10,color:'#00ffffff',width:1})
    .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
    .width(50)
    .height(50)
    .margin({ top: 20 })
    .backgroundColor('#ffffffff')
    .onClick(() => {
      Prompt.showToast({message:'click'})
      this.Click();
    })

  }
}