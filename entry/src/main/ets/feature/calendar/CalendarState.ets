import { CalendarDayState } from "./day/CalendarDayState";

@ObservedV2
export class CalendarState{
  @Trace days: CalendarDayState[] = [];
  @Trace currentDate: Date;

  constructor(currentDate:Date | undefined = undefined) {
    if(currentDate)
      this.currentDate = currentDate;
    else
      this.currentDate = new Date();
  }
}