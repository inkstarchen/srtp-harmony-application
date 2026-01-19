import { isToday } from '../../../shared/utils/time';
import { CalendarDayState } from './CalendarDayState'

@ComponentV2
export struct CalendarDayView{

  @Require
  @Param state: CalendarDayState;
  @Local backColor: string = "#ffe3e2e2";
  @Local fontColor: string = "#ffffffff";

  aboutToAppear(): void {
    let today = isToday(this.state.date);
    this.backColor = today ? '#ff00b4fd' : (this.state.isCurrentMonth ? "#fff":"#ffe3e2e2");
    this.fontColor = this.state.isCurrentMonth? (today ? '#fff' : '#000') : '#ffffffff';
  }

  build() {
    Stack(){
      Text(this.state.date.getDate().toString())
        .width(40)
        .height(40)
        .fontSize(15)
        .textAlign(TextAlign.Center)
        .fontColor(this.fontColor)
        .onClick(() => {

        })
    }
    .width(40)
    .height(40)
    .border({radius: 20, width: 1, color: '#00ffffff'})
    .backgroundColor(this.backColor)
  }
}