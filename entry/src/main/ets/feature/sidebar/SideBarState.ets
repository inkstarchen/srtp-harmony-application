export class ButtonData{
  id: string;
  imgSrc: ResourceStr;
  title: string;

  constructor(id: string, imgSrc: ResourceStr, title: string) {
    this.id = id;
    this.imgSrc = imgSrc;
    this.title = title;
  }
}

@ObservedV2
export class SideBarState {
  @Trace path: string = '';
  @Trace cyc1: string = '';
  @Trace hour: string = '';
  @Trace minutes: string = '';
  @Trace buttonData: ButtonData[] = [];

  buildButton(){
    this.buttonData.push(new ButtonData('Banner', $r('app.media.calendar'), "Banner"));
    this.buttonData.push(new ButtonData('3D', $r('app.media.calendar'), "3D"));
    this.buttonData.push(new ButtonData('calendar', $r('app.media.calendar'), "日历"));
  }

  getTimeString(){
    let date = new Date();
    let year = date.getFullYear();
    let month = date.getMonth() < 10 ? '0' + date.getMonth().toString() : date.getMonth().toString();
    let day1 = date.getDate() < 10 ? '0' + date.getDate().toString() : date.getDate().toString();
    this.hour = date.getHours() < 10 ? '0' + date.getHours().toString() : date.getHours().toString();
    this.minutes = date.getMinutes() < 10 ? '0' + date.getMinutes().toString() : date.getMinutes().toString();
  }

  make_path(ScreenSize: Size): void {
    let width   = ScreenSize.width * 0.35;
    let height  = ScreenSize.height;
    let radius_1 = height * 0.1;
    let radius_2 = height * 0.1;
    console.log("width = " + width + " height = " + height)
    this.path = 'M 0' + ' 0' +
      'L' + width.toFixed(0)  + ' 0' +
      'L' + width.toFixed(0) + ' ' + (height * 0.33).toFixed(0) +
      'A' + radius_1.toFixed(0) + ' ' + radius_1.toFixed(0) + ' 0 0 1 ' + (width - radius_1 * (1 - Math.cos(Math.PI / 3))).toFixed(0) + ' ' + (height * 0.33 + radius_1 * Math.sin(Math.PI / 3)).toFixed(0) +
      'A' + radius_2.toFixed(0) + ' ' + radius_2.toFixed(0) + ' 0 0 0 ' + (width - radius_1 * (1 - Math.cos(Math.PI / 3))).toFixed(0) + ' ' + (height * 0.33 + radius_1 * Math.sin(Math.PI / 3) + 2 * radius_2 * Math.sin(Math.PI / 3)).toFixed(0) +
      'A' + radius_1.toFixed(0) + ' ' + radius_1.toFixed(0) + ' 0 0 1 ' + width.toFixed(0) + ' ' + (height * 0.33 + radius_1 * Math.sin(Math.PI / 3) * 2 + 2 * radius_2 * Math.sin(Math.PI / 3)).toFixed(0) +
      'L' + width.toFixed(0) + ' ' + (height * 1.0).toFixed(0) +
      'L 0' + ' ' + height.toFixed(0);
    // 'L-100 2500'
    ;


  }
}




