import { CalendarComponent } from "../feature/calendar/Calendar";
import { SideBar } from "../feature/sidebar/SideBar";
import { getScreenSize } from "../shared/ui/uiUtils";
import { TouchManager } from "../shared/utils/TouchManager";
import Prompt from "@system.prompt";
import { PosLimiter } from "../shared/utils/PosLimiter";
import { AnimatorResult, router } from "@kit.ArkUI";



@Entry
@ComponentV2
export struct mainPage {
  @Local show_calendar: boolean = false;
  @Local ScreenSize: Size = getScreenSize();
  @Local centralRadius:number = this.ScreenSize.height * 0.055;
  @Local touchManager: TouchManager = new TouchManager();
  @Local sideBarAnim: AnimatorResult | undefined = undefined;
  @Local sideBarLimiter: PosLimiter = new PosLimiter(0,-150,0,0);
  @Local isShow: boolean = true;
  sideBarTarget: number = 0;
  aboutToAppear(): void {
    this.sideBarAnim = this.getUIContext().createAnimator({
      duration:500,
      delay:0,
      direction:"normal",
      fill:'forwards',
      easing:"ease-out",
      begin:0,
      end:1,
      iterations:1
    })
    this.sideBarAnim.onFrame = (progress) => {
      this.sideBarLimiter.pos.x = this.sideBarLimiter.pos.x * (1 - progress) + progress * this.sideBarLimiter.lastPos.x;
    }
  }

  navigateToNote(): void {
    this.getUIContext().getRouter().pushUrl({
      url:"pages/NotePage"
    }, router.RouterMode.Single)
  }


  build() {
    Stack({ alignContent: Alignment.TopStart}) {

      Stack({ alignContent: Alignment.Center }) {
        // Image($r('app.media.img1'))
        Column(){
          Text("今日书写")
            .fontColor("#fff")
            .fontSize(20)
            .width(80)
            .height(30)
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .width(this.centralRadius)
        .height(this.centralRadius)
        .clip(true)
        // .animation({
        //   duration:500,
        //   delay:0,
        //   curve:Curve.EaseInOut,
        //   iterations:1,
        // })
        .onClick((event) => {
          this.navigateToNote();
        })
        .backgroundColor("#ff333333")
        .borderRadius(this.ScreenSize.height * 0.0275)
        .borderWidth(1)

      }
      .width('100%')
      .height('100%')

      // CalendarComponent({
      //   showCalendar:this.show_calendar
      // })

      SideBar({
        touchManager: this.touchManager,
        CalendarDisplay:() => {
          console.info("change");
          this.show_calendar = !this.show_calendar
        }
      })
        .translate({x:this.sideBarLimiter.pos.x,})


    }
    // .gesture(
    //   // 绑定滑动手势且限制仅在竖直方向滑动时触发
    //   SwipeGesture({ direction: SwipeDirection.Horizontal })
    //   // 当滑动手势触发时，获取滑动的速度和角度，实现对组件的布局参数的修改
    //     .onAction((event: GestureEvent|undefined) => {
    //       if(event){
    //         Prompt.showToast({message: "speed: " + event.speed.toFixed(1) + '/angle:' +  event.angle.toFixed(1)});
    //
    //       }
    //     })
    // )
    .onTouch((event:TouchEvent) => {
      if(event.type == TouchType.Down) this.touchManager.TouchDown(event);
      if(event.type == TouchType.Move){
        this.touchManager.TouchMove(event);
        this.sideBarLimiter.update(this.touchManager.distance);
      }
      if(event.type == TouchType.Up){
        this.touchManager.TouchUp(event);
        if(this.sideBarLimiter.pos.x < -75){
          this.sideBarLimiter.lastPos.x = -150;
          this.sideBarAnim?.play();
        }else{
          this.sideBarLimiter.lastPos.x = 0;
          this.sideBarAnim?.play();
        }
      }
    })
    // .backgroundImage($r("app.media.test"))
    // .backgroundImageSize({width:"100%",height:"100%"})
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
    // .linearGradient({colors:[['#ffffffff',0.0],['#ffffffff',1.0]],direction:GradientDirection.LeftBottom})
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
        url:"pages/TestPage"
      });
    })
  }

  pageTransition() {
    PageTransitionExit({ duration: 500, curve: Curve.Linear }).onExit((type: RouteType, progress: number) => {
      this.sideBarLimiter.lastPos.x = -150;
      this.sideBarLimiter.pos.x = progress * this.sideBarLimiter.lastPos.x;
      this.centralRadius = this.ScreenSize.height * 0.055 * ( 1 - progress);
    })
    PageTransitionEnter({ duration: 500, curve: Curve.Linear }).onEnter((type: RouteType, progress: number) => {
      this.sideBarLimiter.lastPos.x = 0;
      this.sideBarLimiter.pos.x = 150 * ( progress - 1);
      this.centralRadius = this.ScreenSize.height * 0.055 * progress;
    })

  }
}