import { CalendarDayState } from "./day/CalendarDayState";

@ObservedV2
export class CalendarState{
  @Trace days: CalendarDayState[] = [];
  @Trace currentDate: Date = new Date();
}