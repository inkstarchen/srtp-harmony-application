@Entry
@ComponentV2
export struct BackButton{
  @Local R:number = 40

  build() {
    Column(){
      Column(){
       Image($r('app.media.chevron_left'))
         .width(this.R/2)
         .height(this.R/2)
      }
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width(this.R)
      .height(this.R)
      .border({radius:this.R,color:'#ffffffff',width:1})
      .shadow({color:'#ff8c8c8c',radius:5 })
      .backgroundColor('#ffffffff')
      .onClick(() => {
        this.getUIContext().getRouter().back()
      })

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#ffdddcdc')
  }
}