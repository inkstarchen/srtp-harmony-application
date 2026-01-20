import { CalendarViewModel } from "./CalendarViewModel"
import { CalendarDayState } from "./day/CalendarDayState";
import { CalendarDayView } from "./day/CalendarDayView";
import { AnimatorResult, matrix4, Prompt } from "@kit.ArkUI";

@ComponentV2
export struct CalendarComponent {
  @Local calendarViewModel: CalendarViewModel = new CalendarViewModel();
  @Local scaleX: number = 0;
  @Local scaleY: number = 0;
  anim1: AnimatorResult | undefined = undefined;
  @Param showCalendar:boolean = false;
  @Local perspective: Matrix4Transit | undefined;

  @Monitor('showCalendar')
  onChange(monitor: IMonitor) {
    if(this.showCalendar){
      Prompt.showToast({message:'show'});
      this.show();
    }else{
      this.hide();
      Prompt.showToast({message:'hide'});
    }
  }

  init(){
    this.perspective = matrix4.init([
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0.002,
      0, 0, 0, 1
    ]);
    let uiContext = this.getUIContext();
    this.anim1 = uiContext.createAnimator({
      duration: 500,
      delay: 0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    });
  }

  async hide(){
    if(!this.anim1) return;
    this.anim1.onFrame = (progress) => {
      this.scaleX = 0.7 - 0.7 * progress;
      this.scaleY = 0.7 - 0.7 * progress;
    }
    this.anim1.play();
  }

  async show(){
    if(!this.anim1) return;
    this.anim1.onFrame = (progress) => {
      this.scaleX = 0.7 * progress;
      this.scaleY = 0.7 * progress;
    }
    this.anim1.play();
  }

  aboutToAppear(): void {
    this.calendarViewModel.updateDays();
    this.init();
  }

  build() {
    Column() {
      this.HeaderBuilder()

      this.WeekdaysBuilder()

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
      .margin({left:10,right:10,bottom:10})
      .height(400)
      .width(LayoutPolicy.wrapContent)
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width(400)
    .height(600)
    .border({ radius: '20px', width: 1, color: '#fff' })
    .backgroundColor('#ffffffff')
    // .translate({x:50, y:200})
    .transform3D(matrix4.identity()
      .rotate({angle:10,y:1,x:0})
      .translate({x:50,y:200,z:100})
      .combine(this.perspective)
    )
    .scale({ x: this.scaleX, y: this.scaleY })
    .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
  }

  @Builder
  HeaderBuilder() {
    Row() {
      // 上个月按钮
      Image($r('app.media.chevron_left'))
        .onClick(() => this.calendarViewModel.changeMonth(-1))
        .width(30)
        .height(30)
        .border({ radius: 20, width: 10, color: '#fff' })
        .shadow({
          offsetX: 5,
          offsetY: 5,
          color: '#8f919191',
          radius: 10
        })
        .backgroundColor('#fff')

      // 年月显示
      Text(this.calendarViewModel.buildHeader())
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 下个月按钮
      Image($r('app.media.chevron_right'))
        .onClick(() => this.calendarViewModel.changeMonth(1))
        .width(30)
        .height(30)
        .border({ radius: 20, width: 10, color: '#fff' })
        .shadow({
          offsetX: 5,
          offsetY: 5,
          color: '#8f919191',
          radius: 10
        })
        .backgroundColor('#fff')
    }
    .padding(10)
    .margin({ top: 10 })
    .width('100%')
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
    .margin({ left: 10, right: 10 })
    .width(LayoutPolicy.wrapContent)
    .backgroundColor('#ffffffff')
  }
}