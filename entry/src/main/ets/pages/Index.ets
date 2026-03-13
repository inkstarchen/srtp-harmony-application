import { getScreenSize } from "../shared/ui/uiUtils";
import {
  getTouchDefault,
  HandleTouch,
  Touch,
  TouchDown,
  TouchMove,
  TouchUp,
  TOUCH_DEFAULT
} from "../shared/utils/TouchManager";
import { PageId, PhysicsScroller } from "../shared/utils/PosLimiter";
import { mainDisplay } from "../feature/mainDisplay/mainDisplay";
import { Constants } from "../shared/constants";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { NoteViewModel } from "../feature/note/NoteViewModel";
import { ToolBarComponent } from "../feature/note/component/toolBar/toolBar";
import { ColorUtil } from "../shared/utils/ColorUtil";
import { AnimatorResult, Prompt } from "@kit.ArkUI";
import { Test } from "../feature/TestComponent";
import { TestPage } from "./TestPage";
import { PlayGround } from "./PlayGround";
import { ThemeManager, ThemeState } from "../theme/core/ThemeManager";
import { DeviceAdapter } from "../theme/core/DeviceAdapter";
import { DeviceType } from "../theme/config/DeviceConfig";
import { SceneProxy } from "../core/scene3D/GlobalSceneProxy";

/**
 * 页面状态枚举
 */
enum NewPageState {
  HIDDEN = 0,
  SHOW = 1
}

@Entry
@ComponentV2
export struct MainPage {
  initFlag:boolean = false;
  // ==================== 基础变量 ====================
  @Local deviceManager: DeviceAdapter = DeviceAdapter.getInstance();
  @Local deviceType: DeviceType = this.deviceManager.currentDeviceInfo.type;
  @Local themeManager: ThemeManager = ThemeManager.getInstance();
  @Local themeState: ThemeState = this.themeManager.getThemeState();
  @Local screenSize: Size = getScreenSize();
  @Local screenHeight: number = this.getUIContext().px2vp(this.screenSize.height);
  @Local screenWidth: number = this.getUIContext().px2vp(this.screenSize.width);
  @Local touch: Touch = getTouchDefault();

  // ==================== 前屏遮挡变量 ====================
  @Local frontVisible: boolean = true;
  @Local fadeColor: string = "#fff";
  @Local fadeAnim: AnimatorResult = this.getUIContext().createAnimator({
    duration: 500,
    iterations: 1,
    direction: "normal",
    fill: "forwards",
    delay: 1000,
    begin: 0,
    easing: "ease-in",
    end: 1
  });

  // ==================== 导航变量 ====================
  @Local photoBlock: boolean = false;
  @Local rubberMovable: boolean = true;
  @Local rubber: PhysicsScroller = new PhysicsScroller(
    { x: -this.screenWidth * 0.12, y: -this.screenHeight * 0.12 },
    { x: this.screenWidth * 0.12, y: this.screenHeight * 0.12 },
    this.getUIContext(),
    { width: this.screenWidth, height: this.screenHeight }
  );

  // ==================== 灯光效果变量 ====================
  @Local backId: number = 0;
  @Local timeNow: number = 0.01;

  // ==================== 编辑变量 ====================
  @Local newPageState: NewPageState = NewPageState.HIDDEN;
  @Local editPageVisible: boolean = true;
  @Local selectedTextColor: Color = Color.Black;
  @Local isColorPickerOpen: boolean = false;
  @Local editing: boolean = false;
  @Local editInner: boolean = false;
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  @Local options: RichEditorOptions = { controller: this.noteViewModel.getController() };
  @Local translateY: number = 0;
  @Local additionHeight: number = 0;
  @Local editState: boolean = false;

  aboutToAppear(): void {
    // Prompt.showToast({ message: this.deviceManager.currentDeviceInfo.type.toString() });
    this.noteViewModel.newNote();

    // 灯光效果参数
    this.backId = setInterval(() => {
      this.timeNow += 0.05;
    }, 10);

    // 前屏淡出动画
    this.fadeAnim.onFrame = (progress) => {
      this.fadeColor = ColorUtil.rgbaToHex(255, 255, 255, 1 - progress);
    };
    this.fadeAnim.onFinish = () => {
      this.frontVisible = false;
    };
    this.fadeAnim?.play();
  }

  aboutToDisappear(): void {
    clearInterval(this.backId);
  }

  build() {
    Stack({ alignContent: Alignment.Center}) {
      // NavigatorBack
      Test({
        navDirection:this.rubber.navDir,
        nextPage: this.rubber.nextPage
      })
      Stack(){

      }
      .width("100%")
      .height("100%")
      .id("ratio_test")
      .backgroundColor("#00ffffff")
      .onTouch((event) => {
        if(!this.initFlag){
          let info = this.getUIContext().getComponentUtils().getRectangleById("ratio_test");
          let componentSize: Size = info.size;
          SceneProxy.sceneSize.width = componentSize.width;
          SceneProxy.sceneSize.height = componentSize.height;
          SceneProxy.ratio = componentSize.height / componentSize.width;
          this.initFlag = true;
        }
        HandleTouch(event, this.touch);
        if(this.rubberMovable && !this.photoBlock) {
          if (event.type == TouchType.Down) {
            this.rubber.down(this.touch.downPos);
          } else if (event.type == TouchType.Move) {
            this.rubber.move(this.touch.curPos);
          } else {
            this.rubber.up()
          }
        }
      })
      if(this.rubber.curPage == PageId.PHOTO){
        TestPage({
          setBlock:(flag:boolean) => {
            this.photoBlock = flag;
          },
          photoOffset:this.rubber.photoOffset,
          translatePos:this.rubber.pos
        })
      }
      if(this.rubber.curPage == PageId.PLAYGROUND){
        PlayGround({
          playOffset:this.rubber.playGroundOffset,
          translatePos:this.rubber.pos
        })
      }
      // ==== 主展示界面 START ====
      mainDisplay({
        mainOffset:this.rubber.mainOffset,
        curPage:this.rubber.curPage,
        limit:this.rubber,
        timeNow:this.timeNow,
        setRubber:() => {
          this.rubberMovable = !this.rubberMovable;
        }
      })

      // ==== 背景阴影图层 ====
      if(true){
        Stack() {}
        .width("100%")
        .height("100%")
        .linearGradient({
          direction: GradientDirection.LeftBottom, // 渐变方向
          angle: 50 + this.timeNow,
          repeating: false, // 渐变颜色是否重复
          colors: [["#6a070707", 0.0], ["#28000000", 0.15], ["#00ffffff", 0.3]] // 数组末尾元素占比小于1时满足重复着色效果
        })
        .hitTestBehavior(HitTestMode.None)
        .sharedTransition('shared2', { duration: 0, curve: Curve.Linear, delay: 0 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

        Stack() {}
        .width("100%")
        .height("100%")
        .linearGradient({
          direction: GradientDirection.LeftBottom, // 渐变方向
          angle: 200 + this.timeNow,
          repeating: false, // 渐变颜色是否重复
          colors: [["#6a070707", 0.0], ["#28000000", 0.15], ["#00ffffff", 0.3]] // 数组末尾元素占比小于1时满足重复着色效果
        })
        .hitTestBehavior(HitTestMode.None)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }

      // ==== 前屏启动遮挡 ====
      if(this.frontVisible){
        Rect()
          .width("100%")
          .height(this.screenHeight)
          .fill(this.fadeColor)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      }

    }
    .hitTestBehavior(HitTestMode.None)
    .backgroundColor(this.themeState.tokens.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')

  }
  pageTransition() {
    PageTransitionEnter({delay:500, duration:250,curve:Curve.Linear})
      .opacity(0)
    PageTransitionExit({delay:0, duration:250,curve:Curve.Linear})
      .opacity(0)
  }
}