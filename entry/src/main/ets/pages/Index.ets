import { getScreenSize } from "../shared/ui/uiUtils";
import { getTouchDefault,
  HandleTouch,
  Touch, TouchDown, TouchMove, TouchUp, TOUCH_DEFAULT } from "../shared/utils/TouchManager";
import { PageId, PhysicsScroller, PosLimiter } from "../shared/utils/PosLimiter";
import { mainDisplay } from "../feature/mainDisplay/mainDisplay";
import { Constants } from "../shared/constants";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { NoteViewModel } from "../feature/note/NoteVeiwModel";
import { ToolBarComponent } from "../feature/note/component/toolBar/toolBar";
import { ColorUtil, RGB } from "../shared/utils/ColorUtil";
import { AnimatorResult, Prompt } from "@kit.ArkUI";
import { NavDirection, Test } from "../feature/TestComponent";
import { TestPage } from "./TestPage";
import { PlayGround } from "./PlayGround";

@Entry
@ComponentV2
export struct mainPage {

  // 基础变量
  ScreenSize: Size = getScreenSize();
  ScreenHeight: number = this.getUIContext().px2vp(this.ScreenSize.height);
  ScreenWidth: number = this.getUIContext().px2vp(this.ScreenSize.width);
  @Local touch: Touch = getTouchDefault();

  // 前屏遮挡变量
  @Local frontVisible: boolean = true;
  @Local fadeColor:string = "#fff";
  fadeAnim:AnimatorResult = this.getUIContext().createAnimator({
    duration:500,
    iterations:1,
    direction:"normal",
    fill:"forwards",
    delay:1000,
    begin:0,
    easing:"ease-in",
    end:1
  })

  // Navi


  rubberMovable: boolean = true;
  @Local rubber: PhysicsScroller = new PhysicsScroller({x:-20,y:-20}, {x:20,y:20},this.getUIContext(),{width:this.ScreenWidth,height:this.ScreenHeight});

  // LightEffect
  backId:number = 0;
  @Local timeNow: number = 0.01;

  // 编辑
  @Local editPageVisible:boolean = true;
  @Local selectedTextColor: Color = Color.Black;
  @Local isColorPickerOpen: boolean = false;
  @Local editing: boolean = false;
  @Local editInner: boolean = false;
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  @Local options: RichEditorOptions = { controller: this.noteViewModel.getController() };
  @Local translateY:number = 0;
  @Local additionHeight: number = 0;
  @Local editState: boolean = false;


  aboutToAppear(): void {
    // 灯光效果参数
    this.backId = setInterval(() => {
      this.timeNow += 0.05;
    },10);

    // 前屏淡出动画
    {
      this.fadeAnim.onFrame = (progress) => {
        this.fadeColor = ColorUtil.rgbaToHex(255,255,255,1 - progress);
      }
      this.fadeAnim.onFinish = () => {
        this.frontVisible = false;
      }
      this.fadeAnim?.play();
    }
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

      if(this.rubber.curPage == PageId.PHOTO){
        TestPage()
      }
      if(this.rubber.curPage == PageId.PLAYGROUND){
        PlayGround()
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

      // ==== 新建笔记编辑 ====
      if(this.editPageVisible){
        Stack({alignContent:Alignment.Center}){
          Column(){
            // topBar
            Row(){
              Button({ type: ButtonType.Circle }){
                SymbolGlyph(this.editState ? $r("sys.symbol.arrow_down_right_and_arrow_up_left"): $r("sys.symbol.arrow_up_left_and_arrow_down_right"))
                  .fontSize(20)
                  .fontColor([Color.Black ])   //?
              }
              .onClick(() => {
                this.editState = !this.editState;
              })
              .margin({top:15,left:10})
              .backgroundColor('#00000000')
              .width(40)
              .height(40)
            }
            .justifyContent(FlexAlign.Start)
            .backgroundColor('#00000000')
            .height(40)
            .width("100%")

            // toolBar
            if(this.editing || this.editInner){
              ToolBarComponent({
                editing:this.editing,
                playAnim:true,
                clearSpan: () => {
                  this.noteViewModel.editorController.cleanAll();
                },
                newNote: () => {
                  this.noteViewModel.newNote();
                },
                selectImage: () => {
                  this.noteViewModel.selectImage();
                },
                saveNote: () => {
                  this.noteViewModel.saveNote();
                },
                toggleBold: () => {
                  this.noteViewModel.toggleBold();
                },
                toggleItalic: () => {
                  this.noteViewModel.toggleItalic();
                },
                toggleUnderline: () => {
                  this.noteViewModel.toggleUnderline();
                },
                isBoldActive: this.noteViewModel.isBoldActive,
                isItalicActive: this.noteViewModel.isItalicActive,
                isUnderlineActive: this.noteViewModel.isUnderlineActive,
                currentTextColor: this.selectedTextColor,
                setTextColor: (color: Color) => {
                  // hilog.info(DOMAIN_NUMBER, TAG, `color swatch tapped: ${color}`);
                  this.selectedTextColor = color;
                  this.noteViewModel.setTextColor(color);
                },
                applyTextColor: () => {
                  this.noteViewModel.applyTextColor();
                },
                isColorPickerOpen: this.isColorPickerOpen,
                setColorPickerOpen: (open: boolean) => {
                  this.isColorPickerOpen = open;
                },
                changeEditState:() => {
                  this.editInner = false;
                }
              })
            }

            // mainEditPlace
            RichEditor(this.options)
              .onReady(() => {
                hilog.info(Constants.DOMAIN_UI_NOTE, "UI-NOTE-EDITOR", 'RichEditor ready');
              })
              .onSelectionChange((range: RichEditorRange) => {
                if (range.start === undefined || range.end === undefined) {
                  return;
                }
                const start = range.start;
                const end = range.end;
                // hilog.debug(DOMAIN_NUMBER, TAG, `选中范围: [${start}, ${end}]`);
                this.noteViewModel.updateSelection(start, end);
              })
              // .aboutToIMEInput((value: RichEditorInsertValue) => {
              //   hilog.debug(DOMAIN_NUMBER, TAG, `即将输入: ${value.insertValue}`);
              //   return true;
              // })
              .placeholder('开始记录您的想法...', {
                fontColor: Color.Gray,
                font: {
                  size: 16,
                  weight: FontWeight.Normal,
                  family: "HarmonyOS Sans",
                  style: FontStyle.Normal
                }
              })
              .border({
                width: 1,
                color: '#EEEEEE',
                radius: 8
              })
              .backgroundColor(Color.White)
              .width('90%')
              .onEditingChange(async (edit) => {
                this.editing = edit;
                if(edit){
                  this.editInner = true;
                  this.noteViewModel.newNote();
                  this.translateY += 300;
                }else{
                  let spans = this.noteViewModel.editorController.controller.getSpans({start:0,end:1});
                  if (spans.length != 0){
                    await this.noteViewModel.saveNote();
                    this.noteViewModel.editorController.cleanAll();
                  }
                  this.translateY -= 300;
                  this.additionHeight = 0;
                }
              })
              .onSubmit(() => {this.additionHeight += 15;})
              .margin(20)
              .height("60%")

          }
          .alignItems(HorizontalAlign.Center)
          .translate({x:0,y:this.rubber.curPage == PageId.MAIN ? (this.editState ? 0: this.ScreenHeight / 2 -this.translateY - this.additionHeight - 50) : this.ScreenHeight })
          .height(this.editState ? "100%" : 300 + this.additionHeight)
          .width(this.editState ? "100%" : "80%")
          .animation({
            duration:500,
            iterations:1,
            delay:0,
            curve:Curve.EaseInOut
          })
          .backgroundColor("#fff")
          .border({radius:20,width:0,color:"#fff"})
          .shadow({radius:15,color:"#1d000000",offsetX:0,offsetY:-20})
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        }
        .hitTestBehavior(HitTestMode.None)
        .width("100%")
        .height("100%")
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      }

      // ==== 前屏启动遮挡 ====
      if(this.frontVisible){
        Rect()
          .width("100%")
          .height(this.ScreenHeight)
          .fill(this.fadeColor)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      }

    }
    .onTouch((event) => {
      HandleTouch(event, this.touch);
      if(this.rubberMovable) {
        if (event.type == TouchType.Down) {
          this.rubber.down(this.touch.downPos);
        } else if (event.type == TouchType.Move) {

          this.rubber.move(this.touch.curPos);
        } else {

          this.rubber.up()
        }
      }
    })
    .backgroundColor("#fffff8eb")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')

  }
}