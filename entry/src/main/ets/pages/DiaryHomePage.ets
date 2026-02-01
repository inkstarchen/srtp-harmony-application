import { Banner } from '../feature/banner/Banner';

@Entry
@ComponentV2
struct DiaryHomePage {
  @Local cardElevation: number = 8;
  @Local quote: string = "生活中只有唯一的英雄主义，\n那就是在认清生活的本质之后依然热爱它";
  @Local currentDate: string = "";

  aboutToAppear() {
    this.updateDate();
  }

  private updateDate() {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const day = now.getDate();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const weekday = weekdays[now.getDay()];

    this.currentDate = `${year}年${month}月${day}日 ${weekday}`;
  }

  build() {
    Column() {
      Text(this.currentDate)
        .fontSize(16)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .padding({ top: 8, bottom: 12 })
        .margin({ top: 8 })
        .width('100%')

      Banner()
        .translate({x:0,y:40})


      Text(this.quote)
        .fontSize(18)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .padding({
          top: 16,
          bottom: 16,
          left: 20,
          right: 20
        })
        .margin({ top: 128 })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .linearGradient({
      direction: GradientDirection.Bottom, // 渐变方向
      repeating: false, // 渐变颜色是否重复
      colors: [['#fffff5fa', 0.0], ['#ffcbdbfd', 1]] // 数组末尾元素占比小于1时满足重复着色效果
    })
  }
}