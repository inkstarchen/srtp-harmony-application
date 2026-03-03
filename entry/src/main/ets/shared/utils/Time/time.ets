
export function getDateStringWithTimeStamp(timestamp: number): string {
  let date = new Date(timestamp);
  const year = date.getFullYear();
  const month = ('0' + (date.getMonth() + 1)).slice(-2);
  const day = ('0' + date.getDate()).slice(-2);
  const hour = date.getHours();
  const min = date.getMinutes();
  const sec = date.getSeconds();
  return `${year}年${month}月${day}日${hour}时${min}分${sec}秒`;
}


export function getDateByTimeStamp(timestamp: number):Array<string>{
  let date = new Date(timestamp);
  const year = date.getFullYear().toString();
  const month = ('0' + (date.getMonth() + 1)).slice(-2);
  const day = ('0' + date.getDate()).slice(-2);
  const hour = date.getHours().toString().padStart(2, '0');;
  const min = date.getMinutes().toString().padStart(2, '0');;
  const sec = date.getSeconds().toString().padStart(2, '0');;
  return [year,month,day,hour,min,sec];
}
export function isToday(date: Date): boolean {
  const today = new Date()
  return isSameDay(date, today);
}

export function isSameMonth(date1: Date, date2:Date): boolean {
  return date1.getFullYear() === date2.getFullYear() && date1.getMonth() === date2.getMonth();
}

export function isSameDay(date1: Date|undefined, date2: Date|undefined): boolean {
  if(date1 && date2){
    return date1.getFullYear() === date2.getFullYear() &&
      date1.getMonth() === date2.getMonth() &&
      date1.getDate() === date2.getDate()
  }else{
    return false;
  }
}

export interface DateInfo {
  weekStr: string;
  dayStr: string;
}

export function getDateInfo(date?: Date): DateInfo {
  const target = date ?? new Date();

  // 获取周几
  const weekMap = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
  const weekStr = weekMap[target.getDay()];

  // 获取日期（补零）
  const day = target.getDate();
  const dayStr = day < 10 ? `0${day}` : `${day}`;

  return {
    weekStr,
    dayStr
  };
}