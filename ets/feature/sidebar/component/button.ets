import { ButtonData } from "../SideBarState"
import Prompt from "@system.prompt";

@ComponentV2
export struct SideBarButton{

  @Require @Param state: ButtonData;
  @Require @Param Click: () => void;

  build() {
    Column(){
      Text(this.state.title)
        .margin({ top:2,left:5 })
        .fontColor("#fff")
        .fontSize(20)
    }
    .justifyContent(FlexAlign.Center)
    .border({radius:10,color:'#00ffffff',width:1})
    .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
    .width(100)
    .height(50)
    .margin({ top: 20 })
    .backgroundColor('#00ffffff')
    .onClick(() => {
      Prompt.showToast({message:'click'})
      this.Click();
    })

  }
}