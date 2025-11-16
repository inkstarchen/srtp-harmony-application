import {CalendarPage} from './CalendarPage'
import { AnimatorResult } from '@kit.ArkUI';
@Entry
@ComponentV2
export struct mainPage {
  @Local day: string = ''
  @Local hour: string = ''
  @Local minutes: string = ''

  @Local path: string = ''
  @Local cyc1: string = ''

  @Local show_calendar: boolean = false

  anim: AnimatorResult | undefined = undefined;
  uiContext: UIContext | undefined = undefined;
  anim1: AnimatorResult | undefined = undefined;

  @Local calendar_x: number = 0;
  @Local calendar_y: number = 0;
  @Local calendar_scaleX : number = 0;
  @Local calendar_scaleY : number = 0;


  aboutToAppear(): void {
    this.make_path();
    this.update_time();
    this.uiContext = this.getUIContext();
  }

  update_time(): void {
    let date = new Date();
    let year = date.getFullYear();
    let month = date.getMonth() < 10 ? '0' + date.getMonth().toString() : date.getMonth().toString();
    let day1 = date.getDate() < 10 ? '0' + date.getDate().toString() : date.getDate().toString();
    this.hour = date.getHours() < 10 ? '0' + date.getHours().toString() : date.getHours().toString();
    this.minutes = date.getMinutes() < 10 ? '0' + date.getMinutes().toString() : date.getMinutes().toString();
    this.day = `${year}-${month}-${day1}`;
  }

  make_path(): void {
    this.path = 'M-100 -500 ' +
      'L250 -500' +
      'L250 0' +
      'L250 750' +
      'A100 100 0 0 1 170 850' +
      'A200 200 0 0 0 170 1200' +
      'A100 100 0 0 1 250 1300' +
      'L250 2500' +
      'L-100 2500'
    ;
    this.cyc1 = 'M250 500' + 'A525 525 0 0 1 250 1550'
  }

  async hide_calendar() {
    if(!this.uiContext) return;
    this.anim1 = this.uiContext.createAnimator({
      duration: 500,
      delay: 0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    })

    this.anim1.onFrame = (progress) => {
      this.calendar_x = 50 - 50 * progress;
      this.calendar_y = -275 - (-275) * progress;
      this.calendar_scaleX = 0.7 - 0.7 * progress;
      this.calendar_scaleY = 0.7 - 0.7 * progress;
      if(progress == 1) {
        this.show_calendar = false;
      }
    }

    if(this.anim1) {
      this.anim1.play();
    }
  }

  async display_calendar() {
    if(!this.uiContext) return;
    this.show_calendar = true;
    this.anim = this.uiContext.createAnimator({
      duration: 500,
      delay: 0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    })

    this.anim.onFrame = (progress) => {
      this.calendar_x = 50 * progress;
      this.calendar_y = -275 * progress;
      this.calendar_scaleX = 0.7 * progress;
      this.calendar_scaleY = 0.7 * progress;
    }

    if(this.anim) {
      this.anim.play();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('112%')
        .backgroundImage($r('app.media.bk'))
        .backgroundImageSize(ImageSize.Cover)
        .backgroundImagePosition(Alignment.Center)
        .offset({ y: -50 })

      Column() {
        Row() {
          Stack() {
            Path()
              .width(300)
              .height(450)
              .strokeWidth(2)
              .stroke('#ffffff')
              .strokeDashArray([3, 3])
              .commands(this.cyc1)
              .fill(Color.Transparent)

            Path()
              .width(300)
              .height(450)
              .strokeWidth(0)
              .commands(this.path)
              .fill('#ffd7d193')
              .opacity(0.8)

            Column() {
              Text(this.hour)
                .fontSize(48)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.Black)
                .offset({ x: -110, y: -150})
              Text(this.minutes)
                .fontSize(32)
                .fontWeight(FontWeight.Medium)
                .fontColor('#888888')
                .offset({ x: -100, y: -150})
              Text(this.day)
                .fontSize(20)
                .fontColor('#666666')
                .margin({ top: 20 })
                .rotate({angle: 90})
                .offset({ x: -135, y: -100})
            }
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 30 })

            Column() {
              Column() {
                Image($r('app.media.calendar'))
                  .width(30)
                  .height(30)
                Text("日历")
                  .margin({top:2})
                  .fontSize(10)
              }
              .justifyContent(FlexAlign.Center)
              .border({radius:15,color:'#00ffffff',width:1})
              .width(50)
              .height(50)
              .offset({ x: -120, y: 370 })
              .backgroundColor('#ffd7d193')
              .onClick(() => {
                if(this.show_calendar) {
                  this.hide_calendar();
                }else {
                  this.display_calendar();
                }
              })

              Column() {
                  Image($r('app.media.notebook'))
                    .width(30)
                    .height(30)
                  Text("记事本")
                    .margin({top:2})
                    .fontSize(10)
              }
              .justifyContent(FlexAlign.Center)
              .border({radius:15,color:'#00ffffff',width:1})
              .width(50)
              .height(50)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url:'pages/Note'
                }).catch()
              })
              .offset({ x: -120, y: 400 })
              .backgroundColor('#ffd7d193')
            }
          }

          Image($r('app.media.img1'))
            .width(100)
            .height(100)
            .borderRadius(50)
            .offset({ x: -270, y: 115 })
        }
        .justifyContent(FlexAlign.Start)
        .width('100%')
        .padding(20)

        if(this.show_calendar){
          CalendarPage()
            .opacity(0.8)
            .scale({ x: this.calendar_scaleX, y: this.calendar_scaleY })
            .offset({ x: 50, y: -275})
        }
      }

    }
    .width('100%')
    .height('100%')
  }
}