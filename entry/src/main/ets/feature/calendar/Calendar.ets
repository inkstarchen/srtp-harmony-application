import { CalendarViewModel } from "./CalendarViewModel"
import { CalendarDayState } from "./day/CalendarDayState";
import { CalendarDayView } from "./day/CalendarDayView";
import { AnimatorResult, matrix4, Prompt } from "@kit.ArkUI";
import { Vec3 } from "@kit.ArkGraphics3D";
import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { TraceVec3 } from "../../core/math/vec";

const THRESHOLD_MAX = 0.5;
const THRESHOLD_MIN = 0.1;

@ComponentV2
export struct CalendarComponent {
  @Local calendarViewModel: CalendarViewModel = new CalendarViewModel();
  @Local scaleX: number = 0;
  @Local scaleY: number = 0;
  anim1: AnimatorResult | undefined = undefined;
  animTo: AnimatorResult | undefined = undefined;
  @Local matrixCalendar: matrix4.Matrix4Transit = matrix4.identity();
  @Param showCalendar:boolean = false;
  lastAngle: Vec3 = {x:0,y:0,z:0};
  @Local rotation:TraceVec3 = new TraceVec3();
  delta: Vec3 = {x:0,y:0,z:0};
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
    this.animTo = uiContext.createAnimator({
      duration:10,
      delay:0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    })
    this.animTo.onFrame = (progress) => {
    }
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
    try {
      sensor.on(sensor.SensorId.ORIENTATION, (data: sensor.OrientationResponse) => {
        this.delta = {
          x: data.beta - this.lastAngle.x,
          y: data.gamma - this.lastAngle.y,
          z: data.alpha - this.lastAngle.z
        };
        if( Math.abs(this.delta.x) > THRESHOLD_MAX || Math.abs(this.delta.x) < THRESHOLD_MIN) this.delta.x = 0;
        else this.rotation.x += this.delta.x;
        if( Math.abs(this.delta.y) > THRESHOLD_MAX || Math.abs(this.delta.y) < THRESHOLD_MIN) this.delta.y = 0;
        else this.rotation.y += this.delta.y;
        if( Math.abs(this.delta.z) > THRESHOLD_MAX || Math.abs(this.delta.z) < THRESHOLD_MIN) this.delta.z = 0;
        else this.rotation.z += this.delta.z;
        this.rotation.clip(5.0);
        this.lastAngle.x = data.beta;
        this.lastAngle.y = data.gamma;
        this.lastAngle.z = data.alpha;
        // Prompt.showToast({message: "x: " + this.delta.x.toFixed(1) + '/y: ' + this.delta.y.toFixed(1) + "/z: " + this.delta.z.toFixed(1)});
      }, { interval: 20 });
      setTimeout(() => {
        sensor.off(sensor.SensorId.ORIENTATION);
      }, 1000000);
    } catch (error) {
      let e: BusinessError = error as BusinessError;
      console.error(`Failed to invoke on. Code: ${e.code}, message: ${e.message}`);
    }
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
    .transform3D(matrix4.identity()
      .rotate({angle:10,y:1,x:0})
      .rotate({angle:this.rotation.x, x:1})
      .rotate({angle:this.rotation.z, y:1})
      .translate({x:50,y:200,z:100})
      .combine(this.perspective))
    .border({ radius: '20px', width: 1, color: '#fff' })
    .backgroundColor('#ffffffff')
    .scale({ x: this.scaleX, y: this.scaleY })
    .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
  }

  @Builder
  HeaderBuilder() {
    Row() {
      // 上个月按钮
      Image($r('app.media.chevron_left'))
        .onClick(() => this.calendarViewModel.changeMonth(-1))
        .width(50)
        .height(50)
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
        .width(50)
        .height(50)
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