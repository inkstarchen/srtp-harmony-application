import { CalendarDayState } from "./day/CalendarDayState";

export class CalendarService{

  getDaysInMonth(currentDate: Date): CalendarDayState[] {
    let days:CalendarDayState[] = [];

    let year = currentDate.getFullYear()
    let month = currentDate.getMonth()

    let firstDay = new Date(year, month, 1)
    let lastDay = new Date(year, month + 1, 0)
    let firstDayOfWeek = firstDay.getDay()
    let daysInMonth = lastDay.getDate()


    let prevMonthLastDay = new Date(year, month, 0).getDate()
    for (let i = 0; i < firstDayOfWeek; i++) {
      let date = new Date(year, month - 1, prevMonthLastDay - firstDayOfWeek + i + 1)
      if(days.length != 42){
        days.push(new CalendarDayState(date, false, i))
      }else{
        days[i].date = date;
      }
    }

    for (let i = 1; i <= daysInMonth; i++) {
      let date = new Date(year, month, i)
      if(days.length != 42){
        days.push(new CalendarDayState(date, true, i + firstDayOfWeek - 1 ))
      }else{
        days[i + firstDayOfWeek - 1].date = date;
        days[i + firstDayOfWeek - 1].isCurrentMonth = true;
      }

    }

    let totalCells = 42
    let remaining = totalCells - firstDayOfWeek - daysInMonth;
    for (let i = 1; i <= remaining; i++) {
      let date = new Date(year, month + 1, i)
      if(days.length != 42){
        days.push(new CalendarDayState(date, false,firstDayOfWeek + daysInMonth + i - 1))
      }else{
        days[firstDayOfWeek + daysInMonth + i - 1].date = date;
        days[firstDayOfWeek + daysInMonth + i - 1].isCurrentMonth = false;
      }
    }
    return days;
  }

}