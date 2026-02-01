import { it } from "@ohos/hypium";
import { getScreenSize } from "../../shared/ui/uiUtils";
import { SideBarButton } from "./component/button";
import { ButtonData, SideBarState } from "./SideBarState"
import { router } from "@kit.ArkUI";
import { TouchManager } from "../../shared/utils/TouchManager";

@ComponentV2
export struct SideBar {
  @Local sideBarState: SideBarState = new SideBarState();
  @Require @Param touchManager:TouchManager;
  @Event CalendarDisplay: () => void;
  // 回调映射表
  private buttonHandlers: Record<string, () => void> = {
    'calendar': () => this.Calendar(),
    '3D': () => this.navigateTo3D(),
    'Banner': () => this.navigateToBanner(),
  };

  private getButtonHandler(buttonId: string): () => void {
    return this.buttonHandlers[buttonId] || (() => {
      console.warn(`未定义按钮 ${buttonId} 的回调`);
    });
  }

  Calendar(): void{
    this.getUIContext().getPromptAction().showToast({message:'test'});
    this.CalendarDisplay();
  }


  navigateTo3D() : void{
    this.getUIContext().getRouter().pushUrl({
      url:"pages/tes"
    }, router.RouterMode.Single)
  }

  navigateToBanner(): void{
    this.getUIContext().getRouter().pushUrl({
      url:"pages/DiaryHomePage"
    }, router.RouterMode.Single)
  }

  aboutToAppear(): void {
    let ScreenSize = getScreenSize();
    this.sideBarState.make_path(ScreenSize);
    this.sideBarState.getTimeString();
    this.sideBarState.buildButton();
  }

  build(){
    Stack({alignContent: Alignment.TopStart}){
      Path()
        .width('100%')
        .height('100%')
        .id('test')
        .strokeWidth(1)
        .commands(this.sideBarState.path)
        .fill('#ff000000')
        .opacity(0.8)


      Column({space:Alignment.Center}){
        Column() {
          Text(this.sideBarState.hour)
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor('#00888888')
            .margin({top:10})
            .translate({x:-20,y:0})


          Text(this.sideBarState.minutes)
            .fontSize(32)
            .fontWeight(FontWeight.Medium)
            .fontColor('#00888888')
            .translate({x:-10,y:0})
            .margin({bottom:20})
        }
        .height(LayoutPolicy.wrapContent)
        .border({radius:10,color:'#00ffffff',width:1})
        .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
        .backgroundColor('#fff')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 30 })
        .translate({x:20,y:20})

        Column(){

        }
        .width(40)
        .height(400)
        .backgroundColor('#00bababa')

        ForEach(this.sideBarState.buttonData, (item: ButtonData, index: number) => {
          SideBarButton({
            state: item,
            Click: this.getButtonHandler(item.id)
          })
        })
      }
    }
    .width("30%")
    .height("100%")
    .ignoreLayoutSafeArea()
  }
}