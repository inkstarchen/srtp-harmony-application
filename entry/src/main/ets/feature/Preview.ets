import { NoteViewModel } from './note/NoteViewModel';

@Preview
@ComponentV2
struct PreviewPage {


  build() {
      Stack({alignContent:Alignment.Center}){
        Column() {
          Column() {
            // 标题区域
            Row() {  //, verticalAlign: ItemAlign.Center
              TextInput({ text: "无标题" })
                .layoutWeight(1)
                .fontSize(20)
                .backgroundColor(Color.Transparent)
                .maxLines(1)
                .textAlign(TextAlign.Start)




            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 4 })
            .alignItems(VerticalAlign.Center)


          }
          .width('100%')
          .height("9%")
          .backgroundColor(Color.White)
          .borderRadius(8)
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .padding({ top: 4, bottom: 4 })

          Divider().strokeWidth(4).color('#F1F3F5').width("80%")
          // 富文本编辑器区域
          Column() {
            Column()
              .backgroundColor("#ffffffff")
              .width('100%')
              .height('100%')
          }
          .layoutWeight(1)
          .width("100%")
          .padding({top:5,left:10,right:10,bottom:20})
          .margin({top:10})
          .backgroundColor('#ffff0000')
        }
        .backgroundColor('#ffffffff')
        .border({radius:15,width:0})
        .padding(10)
        .width("90%")
        .height('90%')
      }
      .hitTestBehavior(HitTestMode.None)
      .backgroundColor("#cdb0b0b0")
      .width("100%")
      .height("100%")
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }
}