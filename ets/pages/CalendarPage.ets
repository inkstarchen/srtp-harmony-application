import { CalendarDay } from './CalendarDay'
import { AnimatorResult } from '@kit.ArkUI';

@Entry
@ComponentV2
export struct CalendarPage {
  @Local currentDate: Date = new Date()
  @Local weather: string = '晴';
  @Local fontNumber: string = '132字';
  @Local description: string = '桃树、杏树、梨树，你不让我，我不让你，都开满了花赶趟儿。红的像火，粉的像霞，白的像雪。花里带着甜味儿；闭了眼，树上仿佛已经满是桃儿、杏儿、梨儿。花下成千成百的蜜蜂嗡嗡地闹着，大小的蝴...';
  @Local selectedDate: Date | undefined = undefined;
  @Local dynamicWidth: number = 40;
  @Local dynamicHeight: number = 40;
  @Local dynamicSize: number = 15;
  @Local dynamicX: number = 0;
  @Local dynamicY: number = 0;
  @Local days : CalendarDay[] = [];
  @Local span : boolean = true;
  @Local selectedDay: CalendarDay | undefined = undefined;
  @Local anim: AnimatorResult | undefined = undefined;
  @Local anim2: AnimatorResult | undefined = undefined;
  private onDateSelected: (date: Date) => void = (date: Date) => {
    this.selectedDate = date;
    if(this.span){
      this.anim?.play();
    }else{
      this.anim2?.play();
    }

  }

  aboutToAppear(): void {
    this.getDaysInMonth();
    if(!this.anim && !this.anim2){
      this.anim = this.getUIContext().createAnimator({
        duration:800,
        delay:0,
        iterations:1,
        direction:'normal',
        easing:"rhythm",
        begin:0,
        end:1,
        fill:'forwards'
      })
      this.anim2 = this.getUIContext().createAnimator({
        duration:400,
        delay:0,
        iterations:1,
        direction:'normal',
        easing:'rhythm',
        begin:0,
        end:1,
        fill:'forwards'
      })

      this.anim.onFrame = (progress) =>{
        if(this.span){
          this.dynamicWidth = 40 + 560 * progress;
          this.dynamicHeight = 40 + 760 * progress;
        }else{
          this.dynamicWidth = 600 - 560 * progress;
          this.dynamicHeight = 800 - 760 * progress;
        }

      }
      this.anim.onFinish = () => {
        if(!this.span){
          this.span = !this.span;
          if(this.selectedDay)
            this.selectedDay.selected = false;
        }else{
          this.anim2?.play();
        }
      }
      this.anim2.onFrame = (progress) => {
        let additionX = 20;
        let additionY = 40;
        if(this.selectedDay){
          if(this.span){
            this.dynamicX = ((this.selectedDay.id % 7 ) * -46 + additionX) * progress;
            this.dynamicY = (Math.floor((this.selectedDay.id) / 7) * -57 + additionY) * progress;
            this.dynamicSize = 15 + 35 * progress;
          }else{
            this.dynamicX = ((this.selectedDay.id % 7 ) * -46 + additionX) + ((this.selectedDay.id % 7) * 46 - additionX) * progress;
            this.dynamicY = (Math.floor(this.selectedDay.id / 7) * -57 + additionY) + (Math.floor((this.selectedDay.id) / 7) * 57 - additionY) * progress ;
            this.dynamicSize = 50 - 35 * progress;
          }
        }
      }
      this.anim2.onFinish = () => {
        if(this.span){
          this.span = !this.span;
        }else{
          this.anim?.play();
        }
      }
    }
  }

  build() {
    Stack() {
      Column() {
        this.HeaderBuilder()

        this.WeekdaysBuilder()

        Grid() {
          ForEach(this.days, (day: CalendarDay, index) => {
            GridItem() {
              this.DayCellBuilder(day,this.onDateSelected)
            }
            .zIndex(this.isSameDay(day.date, this.selectedDate) ? 20 : 0)
          }, (day: CalendarDay) => day.date.toString() + day.isCurrentMonth.toString())
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
        .rowsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
        .margin({left:10,right:10,bottom:10})
        .height(400)
        .width(LayoutPolicy.wrapContent)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width(LayoutPolicy.wrapContent)
      .height(LayoutPolicy.wrapContent)
      .border({ radius: '20px', width: 1, color: '#fff' })
      .backgroundColor('#ffffffff')
      .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
    }
      .width('100%')
      .height('100%')
  }

  @Builder
  HeaderBuilder() {
    Row() {
      // 上个月按钮
      Image($r('app.media.chevron_left'))
        .onClick(() => this.changeMonth(-1))
        .width(30)
        .height(30)
        .border({radius:20,width:10,color:'#fff'})
        .shadow({offsetX:5,offsetY:5,color: '#8f919191',radius:10})
        .backgroundColor('#fff')

      // 年月显示
      Text(`${this.currentDate.getFullYear()}年${this.currentDate.getMonth() + 1}月`)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 下个月按钮
      Image($r('app.media.chevron_right'))
        .onClick(() => this.changeMonth(1))
        .width(30)
        .height(30)
        .border({radius:20,width:10,color:'#fff'})
        .shadow({offsetX:5,offsetY:5,color:'#8f919191',radius:10})
        .backgroundColor('#fff')
    }
    .padding(10)
    .margin({top:10})
    .width('100%')
    .backgroundColor('#ffffffff')
  }

  @Builder
  WeekdaysBuilder() {
    Row() {
      ForEach(['日', '一', '二', '三', '四', '五', '六'], (weekday: string) => {
        Text(weekday)
          .fontSize(16)
          .fontWeight(FontWeight.Bolder)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
      }, (weekday: string) => weekday)
    }
    .padding({ top: 10, bottom: 10 })
    .margin({left:10,right:10})
    .width(LayoutPolicy.wrapContent)
    .backgroundColor('#ffffffff')
  }

  @Builder
  DayCellBuilder(day: CalendarDay,onDateSelected: (date: Date) => void) {
    Stack(){

      Column(){
      }
      .width(day.selected ? this.dynamicWidth:40)
      .height(day.selected ? this.dynamicHeight:40)
      .zIndex(day.selected ? 20 : 0)
      .border({radius:20,width:1,color:'#00ffffff'})
      .backgroundColor((this.isToday(day.date) ? '#ff00b4fd' : (day.isCurrentMonth ? "#fff":"#ffe3e2e2")))

      if(day.selected && !this.span){
        Text(this.weather)
          .translate({x:this.dynamicX + 200,y:this.dynamicY})
          .fontSize(40)
          .zIndex(day.selected ? 20 : 0)
      }

      Text(day.date.getDate().toString())
        .translate({x:day.selected ? this.dynamicX: 0,y:day.selected ? this.dynamicY : 0})
        .width(day.selected ? 100 : 40)
        .height(day.selected ? 100 : 40)
        .fontSize(day.selected ? this.dynamicSize : 15)
        .textAlign(TextAlign.Center)
        .fontColor((day.isCurrentMonth ? (this.isToday(day.date) ? '#fff' : '#000') : '#ffffffff'))
        .onClick(() =>{
          if(day.isCurrentMonth){
            this.selectedDay = day;
            day.selected = true;
            onDateSelected(day.date);
          }
        })
        .zIndex(day.selected ? 22 : 1)
    }

  }

  changeMonth(offset: number) {
    let newDate = new Date(this.currentDate)
    newDate.setMonth(this.currentDate.getMonth() + offset)
    this.currentDate = newDate
    this.getDaysInMonth();
  }

  getDaysInMonth(): void {
    let year = this.currentDate.getFullYear()
    let month = this.currentDate.getMonth()

    let firstDay = new Date(year, month, 1)
    let lastDay = new Date(year, month + 1, 0)
    let firstDayOfWeek = firstDay.getDay()
    let daysInMonth = lastDay.getDate()


    let prevMonthLastDay = new Date(year, month, 0).getDate()
    for (let i = 0; i < firstDayOfWeek; i++) {
      let date = new Date(year, month - 1, prevMonthLastDay - firstDayOfWeek + i + 1)
      if(this.days.length != 42){
        this.days.push(new CalendarDay(date, false,false,i ))
      }else{
        this.days[i].date = date;
        this.days[i].isCurrentMonth = false;
        this.days[i].selected = false;
      }
    }

    for (let i = 1; i <= daysInMonth; i++) {
      let date = new Date(year, month, i)
      if(this.days.length != 42){
        this.days.push(new CalendarDay(date, true,false,i + firstDayOfWeek - 1 ))
      }else{
        this.days[i + firstDayOfWeek - 1].date = date;
        this.days[i + firstDayOfWeek - 1].isCurrentMonth = true;
        this.days[i + firstDayOfWeek - 1].selected = false;
      }

    }

    let totalCells = 42
    let remaining = totalCells - firstDayOfWeek - daysInMonth;
    for (let i = 1; i <= remaining; i++) {
      let date = new Date(year, month + 1, i)
      if(this.days.length != 42){
        this.days.push(new CalendarDay(date, false,false,firstDayOfWeek + daysInMonth + i - 1))
      }else{
        this.days[firstDayOfWeek + daysInMonth + i - 1].date = date;
        this.days[firstDayOfWeek + daysInMonth + i - 1].isCurrentMonth = false;
        this.days[firstDayOfWeek + daysInMonth + i - 1].selected = false;
      }

    }
  }

  isToday(date: Date): boolean {
    const today = new Date()
    return this.isSameDay(date, today)
  }

  isSameDay(date1: Date|undefined, date2: Date|undefined): boolean {
    if(date1 && date2){
      return date1.getFullYear() === date2.getFullYear() &&
        date1.getMonth() === date2.getMonth() &&
        date1.getDate() === date2.getDate()
    }else{
      return false;
    }

  }
}