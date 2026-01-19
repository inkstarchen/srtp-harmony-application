import { CalendarComponent } from "../feature/calendar/Calendar";
import { SideBar } from "../feature/sidebar/SideBar";
import { getScreenSize } from "../shared/ui/uiUtils";

@Entry
@ComponentV2
export struct mainPage {
  @Local show_calendar: boolean = false;
  @Local ScreenSize: Size = getScreenSize();
  aboutToAppear(): void {
  }

  build() {
    Stack({ alignContent: Alignment.TopStart}) {
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.img1'))
          .width(this.ScreenSize.height * 0.055)
          .height(this.ScreenSize.height * 0.055)
          .borderRadius(this.ScreenSize.height * 0.0275)
          .offset({ x: - this.ScreenSize.width * 0.03, y: this.ScreenSize.height * 0.005 })
      }
      .width('100%')
      .height('100%')
      SideBar({
        CalendarDisplay:() => {
          console.info("change");
          this.show_calendar = !this.show_calendar
        }
      })
        CalendarComponent({
          showCalendar:this.show_calendar
        });
    }
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
    .linearGradient({colors:[['#ffe1f5fd',0.0],['#ffdcf2fd',1.0]],direction:GradientDirection.LeftBottom})
    .width('100%')
    .height('100%')
  }
}