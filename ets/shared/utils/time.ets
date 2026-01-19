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
