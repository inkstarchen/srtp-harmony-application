import {mainPage} from './mainpage'

@Entry
@ComponentV2
struct MainApplication {
  build() {
    Column() {
      mainPage()
    }
  }
}

// @Local currentIndex: number = 0
// @Builder
// BottomNavigation() {
//   Row() {
//     Column() {
//       Image($r('app.media.notebook'))
//         .width(24)
//         .height(24)
//       Text('记事本')
//         .fontSize(12)
//     }
//     .onClick(() => {
//       this.currentIndex = 0
//     })
//     .opacity(this.currentIndex === 0 ? 1 : 0.5)
//     .layoutWeight(1)
//     .justifyContent(FlexAlign.Center)
//
//     // 另一个页面按钮
//     Column() {
//       Image($r('app.media.calendar'))
//         .width(24)
//         .height(24)
//       Text('日历')
//         .fontSize(12)
//     }
//     .onClick(() => {
//       this.currentIndex = 1
//     })
//     .opacity(this.currentIndex === 1 ? 1 : 0.5)
//     .layoutWeight(1)
//     .justifyContent(FlexAlign.Center)
//   }
//   .height(60)
//   .width('100%')
//   .backgroundColor('#f5f5f5')
//   .justifyContent(FlexAlign.SpaceAround)
// }