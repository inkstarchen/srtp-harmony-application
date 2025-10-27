
export class Helper{
  static clearIntervalArray(array:number[],pos:number){
    if(array[pos] == 0) return;
    clearInterval(array[pos]);
    array[pos] = 0;
  }
}