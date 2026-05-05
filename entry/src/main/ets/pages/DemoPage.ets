
@Entry
@ComponentV2
struct DemoPage{
  build() {
    Stack({alignContent:Alignment.Center}){
      Column({space:20}){
        Button("2DUI贴图渲染").onClick((event: ClickEvent) => {
            this.getUIContext().getRouter().pushUrl({
              url:"feature/demo/Render1",
            })
        })
          .width(200)
          .height(80)
          .backgroundColor("#ff50b78a")
          .shadow({radius:20,offsetX:10,offsetY:10,color: "#ffacacac"
          })
          .border({radius:15,width:0})

        Button("图层切换效果").onClick((event: ClickEvent) => {
          this.getUIContext().getRouter().pushUrl({
            url:"feature/demo/Render2",
          })
        })
          .width(200)
          .height(80)
          .backgroundColor("#ff50b78a")
          .shadow({radius:20,offsetX:10,offsetY:10,color:"#ffacacac"})
          .border({radius:15,width:0})

        Button("碰撞效果").onClick((event: ClickEvent) => {
          this.getUIContext().getRouter().pushUrl({
            url:"feature/demo/Render3",
          })
        })
          .width(200)
          .height(80)
          .backgroundColor("#ff50b78a")
          .shadow({radius:20,offsetX:10,offsetY:10,color:"#ffacacac"})
          .border({radius:15,width:0})
      }
      .justifyContent(FlexAlign.Center)
      .width("100%")
      .height("100%")
    }
    .width("100%")
    .height("100%")
  }
  pageTransition() {
    PageTransitionEnter({delay:500, duration:250,curve:Curve.Linear})
      .opacity(0)
    PageTransitionExit({delay:0, duration:250,curve:Curve.Linear})
      .opacity(0)
  }
}