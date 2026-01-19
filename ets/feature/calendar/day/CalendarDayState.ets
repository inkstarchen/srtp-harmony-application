@ObservedV2
export class CalendarDayState{
  @Trace date: Date;
  @Trace isCurrentMonth: boolean;
  id: number;

  constructor(date: Date, isCurrentMonth:boolean, id:number) {
    this.date = date;
    this.isCurrentMonth = isCurrentMonth;
    this.id = id;
  }
}