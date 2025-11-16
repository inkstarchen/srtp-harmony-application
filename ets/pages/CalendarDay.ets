@ObservedV2
export class CalendarDay {
  @Trace date: Date
  @Trace isCurrentMonth: boolean
  @Trace selected: boolean
  id: number

  constructor(date: Date, isCurrentMonth: boolean, selected:boolean, id:number) {
    this.selected = selected
    this.date = date
    this.isCurrentMonth = isCurrentMonth
    this.id = id;
  }
}