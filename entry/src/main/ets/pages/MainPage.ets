import { getScreenSize, SHADOW_FLOAT } from "../shared/ui/uiUtils";
import {
  getTouchDefault,
  HandleTouch,
  Touch,
} from "../shared/utils/TouchManager";
import { PageId, PhysicsScroller } from "../shared/utils/PosLimiter";
import { mainDisplay } from "../feature/mainDisplay/mainDisplay";
import { NoteType, NoteViewModel } from "../feature/note/NoteViewModel";
import { ColorUtil } from "../shared/utils/ColorUtil";
import { AnimatorResult, Prompt, SymbolGlyphModifier } from "@kit.ArkUI";
import { Test } from "../feature/TestComponent";
import { TestPage } from "./TestPage";
import { PlayGround } from "./PlayGround";
import { ThemeManager, ThemeState } from "../theme/core/ThemeManager";
import { DeviceAdapter } from "../theme/core/DeviceAdapter";
import { DeviceType } from "../theme/config/DeviceConfig";
import { SceneProxy } from "../core/scene3D/GlobalSceneProxy";
import { SlideList } from "../feature/SlideList/SlideList";
import { DateItem, SlidingDateModel } from "../shared/utils/Time/SlideTimeModel";
import { NoteAction, NoteInfo, NotePageParams } from "../feature/note/NoteState";
import { rdbDataPersistence } from "../feature/DataStorage/datastore";
import { ArticlePage } from "./ArticlePage";

/**
 * 页面状态枚举
 */
enum NewPageState {
  HIDDEN = 0,
  SHOW = 1
}

enum PageState {
  READY = 0,
  SWITCHING = 1
}

@Entry
@ComponentV2
export struct MainPage {
  // Variable for head time
  @Local slideTime:SlidingDateModel = new SlidingDateModel();
  @Local selectedData: DateItem = this.slideTime.createItem(new Date(),0);
  @Local weekStr:string = this.selectedData.weekStr;
  @Local dayStr:string = this.selectedData.dayStr;
  @Local slideDisplay: boolean = false;
  @Local TimeLineOpacity: number = 0;
  @Local needFreshDate: boolean = false;

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
  @Local pageCurrent: PageId = PageId.MAIN;
  @Local pageBefore: PageId = PageId.NONE;
  @Local pageState: PageState = PageState.READY;
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
  @Local editing: boolean = false;
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  @Local options: RichEditorOptions = { controller: this.noteViewModel.getController() };
  // Variable for children component
  @Local needsFreshNotes: boolean = false;

  // =================== 新建栏 ===================
  @Local editIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.pencil_waveform')).fontSize('24vp');
  @Builder
  NewNote(onCreateArticle: () => void) {
    Menu() {
      MenuItem({ symbolStartIcon: this.editIconModifier, content: "编辑" })
        .onChange(() => {
          onCreateArticle();
        })
    }
  }

  aboutToAppear(): void {

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
      if(true){
        Stack(){}
        .width("100%")
        .height("100%")
        .id("ratio_test")
        .backgroundColor("#00ffffff")
        .onTouch((event) => {
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
      }
      if((this.pageCurrent == PageId.PHOTO && this.pageState == PageState.READY)
        || (this.pageBefore == PageId.PHOTO && this.pageState == PageState.SWITCHING)
      ){

        TestPage({
          setBlock:(flag:boolean) => {
            this.photoBlock = flag;
          },
          photoOffset:this.rubber.photoOffset,
          translatePos:this.rubber.pos
        })
      }
      if(false){
        PlayGround({
          playOffset:this.rubber.playGroundOffset,
          translatePos:this.rubber.pos
        })
      }

      if((this.pageCurrent == PageId.ARTICLE&& this.pageState == PageState.READY)
        || (this.pageBefore == PageId.ARTICLE && this.pageState == PageState.SWITCHING))
      {
        ArticlePage()
      }

      if((this.pageCurrent == PageId.MAIN&& this.pageState == PageState.READY)
        || (this.pageBefore == PageId.MAIN && this.pageState == PageState.SWITCHING))
      {
        mainDisplay({
          mainOffset:this.rubber.mainOffset,
          curPage:this.rubber.curPage,
          limit:this.rubber,
          timeNow:this.timeNow,
          needsFresh: this.needsFreshNotes,
          needFreshDate: this.needFreshDate,
          selectedData: this.selectedData,
          FreshDateFinished: () => {
            this.needFreshDate = false;
          },
          FreshFinished:() => {
            this.needsFreshNotes = false;
          },
        })
      }


      Stack({alignContent:Alignment.Top}){
        Row({space:10}){
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph(this.pageCurrent == PageId.MAIN ? $r("sys.symbol.rectangle_on_rectangle") : $r("sys.symbol.arrow_left"))
              .fontSize(20)
              .fontColor([Color.Black])
          }
          .onClick(() => {
            if(this.pageCurrent == PageId.MAIN){
              this.pageCurrent = PageId.PHOTO;
            }else{
              this.pageCurrent = PageId.MAIN
            }
          })
          .backgroundColor('#00000000')
          .width(40)
          .height(40)
          .layoutWeight(0)

          // ==== 时间 START =====
          if(this.pageCurrent == PageId.MAIN && (this.pageState == PageState.READY || this.pageState == PageState.SWITCHING))
          {
            Stack({ alignContent: Alignment.Center }) {
              SlideList({
                display: this.slideDisplay,
                setItem: (item: DateItem) => {
                  this.selectedData.timestamp = item.timestamp;
                  this.weekStr = item.weekStr;
                  this.dayStr = item.dayStr;
                  this.needFreshDate = true;
                },
                setOpacity: () => {
                  this.slideDisplay = false;
                  if (this.TimeLineOpacity) {
                    this.TimeLineOpacity = 0;
                  } else {
                    this.TimeLineOpacity = 0.5;
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
                .animation({
                  duration: 500,
                  iterations: 0,
                  curve: Curve.Linear,
                  delay: 0
                })
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
                this.slideDisplay = true;
                if (this.TimeLineOpacity) {
                  this.TimeLineOpacity = 0;
                } else {
                  this.TimeLineOpacity = 0.5;
                }
              })
              .hitTestBehavior(this.slideDisplay ? HitTestMode.BLOCK_DESCENDANTS : HitTestMode.Default)
            }
            .hitTestBehavior(HitTestMode.None)
            .margin({ bottom: 20, top: 20 })
            .width("100%")
            .height(50)
            .layoutWeight(1)
          }
          if(this.pageCurrent == PageId.PHOTO && (this.pageState == PageState.READY || this.pageState == PageState.SWITCHING)){
            Stack({ alignContent: Alignment.Center }){
              Text("图像库")
                .fontSize(20)
            }
            .hitTestBehavior(HitTestMode.None)
            .margin({ bottom: 20, top: 20 })
            .width("100%")
            .height(50)
            .layoutWeight(1)
          }
          // ==== 时间 END ====
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r("sys.symbol.rectangle_on_rectangle"))
              .fontSize(20)
              .fontColor([Color.Black])
          }
          .onClick(() => {
            if(this.pageCurrent == PageId.MAIN){
              this.pageCurrent = PageId.ARTICLE;
            }else{
              this.pageCurrent = PageId.MAIN
            }
          })
          .backgroundColor('#00000000')
          .width(40)
          .height(40)
          .layoutWeight(0)
        }
        .padding({bottom:40,left:20,right:20})
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
        .width("100%")
        .height(100)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .shadow(SHADOW_FLOAT)
        .backgroundColor("#fff")
        .zIndex(2)
      }
      .width("100%")
      .height("100%")
      .hitTestBehavior(HitTestMode.None)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])

      Stack({alignContent:Alignment.Bottom}){
        // 使用 Column 包裹可自适应高度的内容
        Column(){
          // 空白占位区域，用于将输入框推到下方
          Blank()

          // 输入区域容器
          Row(){
            // 左侧按钮
            Column(){
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r("sys.symbol.plus"))
                  .fontSize(20)
                  .fontColor([Color.Black])
              }
              .backgroundColor('#00000000')
              .height(LayoutPolicy.matchParent)
              .width(40)
              .height(40)
              .layoutWeight(0)
              .bindMenu(this.NewNote(() => {
                this.getUIContext().getRouter().pushUrl({
                  url:'pages/NotePage',
                  params:{action:NoteAction.NEW,info:{fileDir:'',fileName:'',time:null} as NoteInfo} as NotePageParams,
                })
              }))
            }
            .justifyContent(FlexAlign.End)
            .width(40)
            // .height(LayoutPolicy.matchParent)
            .layoutWeight(0)


            // RichEditor 文本输入框 - 可自适应高度
            RichEditor(this.options)
              .onSelectionChange((range: RichEditorRange) => {
                if (range.start === undefined || range.end === undefined) {
                  return;
                }
                const start = range.start;
                const end = range.end;
                this.noteViewModel.updateSelection(start, end);
              })
              .placeholder('开始记录您的想法...', {
                fontColor: Color.Gray,
                font: {
                  size: 16,
                  weight: FontWeight.Normal,
                  family: "HarmonyOS Sans",
                  style: FontStyle.Normal
                }
              })
              .border({radius:5,width:0})
              .backgroundColor(Color.White)
              .width('100%')
              .maxLines(5)
              .onEditingChange(async (edit) => {
                this.editing = edit;
              })
              .layoutWeight(1)  // 占据剩余空间
              .margin({left: 8, right: 8})  // 与按钮的间距

            // 右侧按钮
            Column(){
              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r("sys.symbol.paperplane_right_fill"))
                  .fontSize(20)
                  .fontColor([Color.Black])
              }
              .onClick(() => {
                let spans = this.noteViewModel.editorController.controller.getSpans({start:0,end:1});
                if (spans.length != 0){
                  this.noteViewModel.newNote(NoteType.NOTE);
                  this.noteViewModel.saveNote().then(() =>{
                    this.noteViewModel.editorController.cleanAll();
                    this.needsFreshNotes = true;
                  })
                }
              })
              .backgroundColor('#00000000')
              .width(40)
              .height(40)
            }
            .justifyContent(FlexAlign.End)
            .width(40)
            // .height(LayoutPolicy.matchParent)
            .layoutWeight(0)

          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .width("100%")
          .padding({left: 6, right: 6, top: 8, bottom: 8})
        }
        .width("100%")
        .translate({x:0,y:this.editing ? -280 : 0 })
        .animation({
          duration:250,
          delay:0,
          iterations:1,
          curve:Curve.EaseInOut
        })
        .border({radius:20,width:0})
        .shadow(SHADOW_FLOAT)
        .margin({bottom: 20})
        .width("90%")
        .backgroundColor("#fff8f8f8")
      }
      .width("100%")
      .height("100%")
      .hitTestBehavior(HitTestMode.None)
      .backgroundColor("#00ffffff")

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