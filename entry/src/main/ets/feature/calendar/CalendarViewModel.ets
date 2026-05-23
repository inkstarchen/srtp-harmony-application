import { CalendarService } from "./CalendarService";
import { CalendarState } from "./CalendarState";
import { CalendarDayState } from "./day/CalendarDayState";

@ObservedV2
export class CalendarViewModel{
  @Trace calendarState: CalendarState;
  calendarService: CalendarService = new CalendarService();

  constructor(currentDate:Date | undefined = undefined) {
    this.calendarState = new CalendarState(currentDate);
  }

  getDays(): CalendarDayState[] {
    return this.calendarState.days;
  }

  changeMonth(offset: number) {
    let newDate = new Date(this.calendarState.currentDate);
    newDate.setMonth(this.calendarState.currentDate.getMonth() + offset);
    this.calendarState.currentDate = newDate;
    this.updateDays();
  }

  updateDays() {
    this.calendarState.days = this.calendarService.getDaysInMonth(this.calendarState.currentDate);
  }

  buildHeader(): string{
    let currentDate = this.calendarState.currentDate;
    return `${currentDate.getFullYear()}年${currentDate.getMonth() + 1}月`
  }
}