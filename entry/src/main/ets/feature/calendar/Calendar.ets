import { CalendarViewModel } from "./CalendarViewModel"
import { CalendarDayState } from "./day/CalendarDayState";
import { CalendarDayView } from "./day/CalendarDayView";
import { AnimatorResult, matrix4, Prompt } from "@kit.ArkUI";
import { Vec3 } from "@kit.ArkGraphics3D";
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { TraceVec3 } from "../../core/math/vec";
import { TimeState } from "../mainDisplay/TwoColumnLayoutMain";
import { Constants } from "../../shared/constants";

const THRESHOLD_MAX = 0.5;
const THRESHOLD_MIN = 0.1;

@Preview
@ComponentV2
export struct CalendarComponent {
  context:UIContext = this.getUIContext();
  @Local calendarViewModel: CalendarViewModel = new CalendarViewModel();
  @Param timeState:TimeState = TimeState.STATE_1;
  aboutToAppear(): void {
    this.calendarViewModel.updateDays();
  }

  build() {
    Column(){
      Column() {
        this.HeaderBuilder()

        this.WeekdaysBuilder()

        Stack(){
          Grid() {
            ForEach(this.calendarViewModel.getDays(), (day: CalendarDayState, index) => {
              GridItem() {
                CalendarDayView({
                  state: day
                })
              }
            }, (day: CalendarDayState) => day.date.toString() + day.isCurrentMonth.toString())
          }
          .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
          .margin({left:10,right:10})
          .width(LayoutPolicy.wrapContent)
        }
        .layoutWeight(1)
        .width(LayoutPolicy.wrapContent)
        .height(LayoutPolicy.wrapContent)
      }
      .padding({left:20,right:20})
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width("100%")
      .height(340)
    }
    .height(this.timeState == TimeState.STATE_2 ? 340 : 0)
    .clip(true)
    .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
    .backgroundColor('#ffffffff')
    .animation({
      duration:500,
      delay:0,
      iterations:1,
      curve:Curve.EaseInOut
    })
  }

  @Builder
  HeaderBuilder() {
    Row({space:10}) {
      // 上个月按钮
      Button(){
        SymbolGlyph($r("sys.symbol.chevron_left_2"))
          .fontSize(30)
          .fontColor([Color.Black])
      }
      .onClick(() => this.calendarViewModel.changeMonth(-12))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      .border(Constants.MD_BORDER)
      .shadow({radius:10,offsetX:5,color:"#ffd2d2d2"})
      .fontSize(Constants.buttonFontSize)
      .backgroundColor('#ffffffff' )
      .width(Constants.buttonHeight)
      .height(Constants.buttonHeight)
      .layoutWeight(0)
      Button(){
        SymbolGlyph($r("sys.symbol.chevron_left"))
          .fontSize(30)
          .fontColor([Color.Black])
      }
      .onClick(() => this.calendarViewModel.changeMonth(-1))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      .border(Constants.MD_BORDER)
      .shadow({radius:10,offsetX:5,color:"#ffd2d2d2"})
      .fontSize(Constants.buttonFontSize)
      .backgroundColor('#ffffffff' )
      .width(Constants.buttonHeight)
      .height(Constants.buttonHeight)
      .layoutWeight(0)

      // 年月显示
      Text(this.calendarViewModel.buildHeader())
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 下个月按钮
      Button(){
        SymbolGlyph($r("sys.symbol.chevron_right"))
          .fontSize(30)
          .fontColor([Color.Black])
      }
      .onClick(() => this.calendarViewModel.changeMonth(1))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      .border(Constants.MD_BORDER)
      .shadow({radius:10,offsetX:5,color:"#ffd2d2d2"})
      .fontSize(Constants.buttonFontSize)
      .backgroundColor('#ffffffff' )
      .width(Constants.buttonHeight)
      .height(Constants.buttonHeight)
      .layoutWeight(0)

      Button(){
        SymbolGlyph($r("sys.symbol.chevron_left_2"))
          .fontSize(30)
          .fontColor([Color.Black])
      }
      .onClick(() => this.calendarViewModel.changeMonth(12))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      .border(Constants.MD_BORDER)
      .shadow({radius:10,offsetX:-5,color:"#ffd2d2d2"})
      .transform(matrix4.identity().rotate({x:0,y:0,z:1,angle:180}))
      .fontSize(Constants.buttonFontSize)
      .backgroundColor('#ffffffff' )
      .width(Constants.buttonHeight)
      .height(Constants.buttonHeight)
      .layoutWeight(0)
    }
    .padding({left:20,right:20})
    .margin({ top: 5})
    .width('100%')
    .layoutWeight(0)
    .backgroundColor('#ffffffff')
  }

  @Builder
  WeekdaysBuilder() {
    Row() {
      ForEach(['日', '一', '二', '三', '四', '五', '六'], (weekday: string) => {
        Text(weekday)
          .fontSize(16)
          .fontWeight(FontWeight.Bolder)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
      }, (weekday: string) => weekday)
    }
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 10, right: 10 ,top:10})
    .width(LayoutPolicy.wrapContent)
    .backgroundColor('#ffffffff')
    .layoutWeight(0)
  }
}