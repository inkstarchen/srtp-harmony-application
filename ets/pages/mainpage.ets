import {CalendarPage} from './CalendarPage'
import { AnimatorResult, matrix4 } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PreferencesUtil } from '../utils/PreferencesUtil';

let dataPreferences: preferences.Preferences | null = null;
@Entry
@ComponentV2
export struct mainPage {
  @Event FinishInit:(screenWidth:number) => void;
  @Local ScreenSize?:Size;
  // @Local day: string = ''
  @Local hour: string = ''
  @Local minutes: string = ''

  @Local path: string = ''
  @Local cyc1: string = ''

  @Local show_calendar: boolean = false

  anim: AnimatorResult | undefined = undefined;
  uiContext: UIContext | undefined = undefined;
  anim1: AnimatorResult | undefined = undefined;
  @Local Width: number = 150;
  @Local Height: number = 150;
  @Local Width2: number = 0;
  @Local Height2: number = 0;
  @Local calendar_x: number = 0;
  @Local calendar_y: number = 0;
  @Local calendar_scaleX : number = 0;
  @Local calendar_scaleY : number = 0;
  @Local animResult?: AnimatorResult;
  @Local animResult2?: AnimatorResult;
  @Local translateY: number = 0;
  @Local scaleV: number = 0;

  aboutToAppear(): void {

    this.update_time();
    this.uiContext = this.getUIContext();
    this.ScreenSize = PreferencesUtil.getScreenData();
    this.FinishInit(this.ScreenSize.width);
    this.initAnim();
    // this.make_path();
  }

  initAnim(){
    if(!this.uiContext) return;
    this.animResult = this.uiContext.createAnimator({
      duration:500,
      direction:'normal',
      fill:'forwards',
      iterations:1,
      easing:'ease-in-out',
      begin:0,
      end:1,
      delay:0
    })
    this.animResult.onFrame = (progress) => {
      this.Width = 150 - 150 * progress;
      this.Height = 150 - 150 * progress;
      this.Width2 = 150 * progress;
      this.Height2 = 150 * progress;
    }
    this.animResult.onFinish = () => {
      this.animResult2?.play();
    }
    this.animResult2 = this.uiContext.createAnimator({
      duration:500,
      direction:'normal',
      fill:'forwards',
      iterations:1,
      easing:'ease-in-out',
      begin:0,
      end:1,
      delay:0
    })
    this.animResult2.onFrame = (progress) => {
      this.translateY = -100 * progress;
      this.Width2 = 150 - 150 * progress;
      this.Height2 = 150 - 150 * progress;
      this.scaleV = progress;
    }
  }

  update_time(): void {
    let date = new Date();
    let year = date.getFullYear();
    let month = date.getMonth() < 10 ? '0' + date.getMonth().toString() : date.getMonth().toString();
    let day1 = date.getDate() < 10 ? '0' + date.getDate().toString() : date.getDate().toString();
    this.hour = date.getHours() < 10 ? '0' + date.getHours().toString() : date.getHours().toString();
    this.minutes = date.getMinutes() < 10 ? '0' + date.getMinutes().toString() : date.getMinutes().toString();
    // this.day = `${year}-${month}-${day1}`;
  }

  make_path(): void {
    if(!this.ScreenSize) return;
    let width = (this.ScreenSize.width * 0.3);
    let height = this.ScreenSize.height;
    let radius_1 = height * 0.08;
    let radius_2 = height * 0.08;
    this.path = 'M0 0 ' +
      'L' + width.toFixed(0)  + ' 0' +
      // 'L250 -500' +
      'L' + width + ' ' + (height * 0.40).toFixed(0) +
      // 'L250 0' +
      // 'L250 750' +
      'A' + radius_1.toFixed(0) + ' ' + radius_1.toFixed(0) + ' 0 0 1 ' + (width - radius_1).toFixed(0) + ' ' + (height * 0.45).toFixed(0) +
      'A' + radius_2.toFixed(0) + ' ' + radius_2.toFixed(0) + ' 0 0 0 ' + (width - radius_1).toFixed(0) + ' ' + (height * 0.55).toFixed(0) +
      'A' + radius_1.toFixed(0) + ' ' + radius_1.toFixed(0) + ' 0 0 1 ' + width.toFixed(0) + ' ' + (height * 0.6).toFixed(0) +
      // 'A100 100 0 0 1 170 850' +
      // 'A200 200 0 0 0 170 1200' +
      // 'A100 100 0 0 1 250 1300' +
      // 'L250 2500' +
      'L' + width.toFixed(0) + ' ' + height.toFixed(0) +
      'L0 ' + height.toFixed(0);
      // 'L-100 2500'
    ;
    this.cyc1 = 'M' + radius_1.toFixed(0) + ' ' + (height / 2 - 525).toFixed(2) + 'A525 525 0 0 1 '+ radius_1.toFixed(0) +  ' ' + (height / 2 + 525).toFixed(0);
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

      // Column()
      //   .width('100%')
      //   .height('112%')
      //   .backgroundImage($r('app.media.bk'))
      //   .backgroundImageSize(ImageSize.Cover)
      //   .backgroundImagePosition(Alignment.Center)
      //   .offset({ y: -50 })
      Stack({ alignContent: Alignment.Center }) {
        Column(){

        }
        .width(150 - this.Width)
        .height(150 - this.Height)
        .borderRadius(150)
        .translate({x:0,y:this.translateY})
        .scale({x:this.scaleV,y:this.scaleV})
        .backgroundColor('#ff0f9be9')
        Column(){

        }
        .width(this.Width2)
        .height(this.Height2)
        .borderRadius(150)
        .backgroundColor('#ff0f9be9')
        .transform3D(matrix4.identity().rotate({x:1,angle:70}))
        Image($r('app.media.img1'))
          .width(this.Width)
          .height(this.Height)
          .borderRadius(50)
          // .offset({ x: -270, y: 115 })
          .onClick(() => {
            if(this.animResult){
              this.getUIContext().getPromptAction().showToast({message:'yes'})
            }else{
              this.getUIContext().getPromptAction().showToast({message:'no'})
            }
            this.animResult?.play();
          })

        if(this.show_calendar){
          CalendarPage()
            .scale({ x: this.calendar_scaleX, y: this.calendar_scaleY })
        }
      }
      .width('100%')
      .height('100%')

      Column() {
        Row() {
          Stack() {
          //   Path()
          //     .width(300)
          //     .height(450)
          //     .strokeWidth(2)
          //     .stroke('#ffffff')
          //     .strokeDashArray([3, 3])
          //     .commands(this.cyc1)
          //     .fill(Color.Transparent)
          //
          //   Path()
          //     .width(300)
          //     .height(450)
          //     .strokeWidth(0)
          //     .commands(this.path)
          //     .fill('#ffd7d193')
          //     // .stroke(Color.Black)
          //     .position({x:0,y:0})
          //     .opacity(0.8)
            Column() {
              Text(this.hour)
                .fontSize(48)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.Black)
                .margin({top:10})
                .translate({x:-20,y:0})

              Text(this.minutes)
                .fontSize(32)
                .fontWeight(FontWeight.Medium)
                .fontColor('#888888')
                .translate({x:-10,y:0})
                .margin({bottom:20})
            }
            .height(LayoutPolicy.wrapContent)
            .border({radius:10,color:'#00ffffff',width:1})
            .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
            .backgroundColor('#fff')
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
              .border({radius:10,color:'#00ffffff',width:1})
              .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
              .width(50)
              .height(50)
              .transform3D(matrix4.identity().translate({x:-40,y:1440}))
              .backgroundColor('#ffffffff')
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
              .border({radius:10,color:'#00ffffff',width:1})
              .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
              .width(50)
              .height(50)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url:'pages/Note'
                }).catch()
              })
              .transform3D(matrix4.identity().translate({x:-40,y:1480}))
              .backgroundColor('#ffffffff')

              Column() {

                Text("3D")
                  .margin({top:2})
                  .fontSize(10)
              }
              .justifyContent(FlexAlign.Center)
              .border({radius:10,color:'#00ffffff',width:1})
              .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
              .width(50)
              .height(50)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url:"pages/lightTest"
                })
              })
              .transform3D(matrix4.identity().translate({x:-40,y:1500}))
              .backgroundColor('#ffffffff')


              Column() {

                  Text("Banner")
                    .margin({top:2})
                    .fontSize(10)
              }
              .justifyContent(FlexAlign.Center)
              .border({radius:10,color:'#00ffffff',width:1})
              .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
              .width(50)
              .height(50)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url:"pages/BannerPage"
                })
              })
              .transform3D(matrix4.identity().translate({x:-40,y:1540}))
              .backgroundColor('#ffffffff')
            }
          }
        }
        .justifyContent(FlexAlign.Start)
        .width('100%')
        .padding(20)


      }
    }
    .linearGradient({colors:[['#ffe1f5fd',0.0],['#ffdcf2fd',1.0]],direction:GradientDirection.LeftBottom})
    .width('100%')
    .height('100%')
  }
}