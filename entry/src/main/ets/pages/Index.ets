import { SceneProxy } from '../core/scene3D/GlobalSceneProxy';

@Entry
@ComponentV2
struct Index{

  @Local Debug: boolean = true;

  build(){
    Stack({alignContent:Alignment.Bottom}){
      Column(){
      }
      .width("100%")
      .height("100%")
      .id("size")
      Image($r("app.media.IndexBack"))
        .width("100%")
        .height("100%")
      if(this.Debug){
        Row({space:20}){
          Button("开始记录")
            .width(120)
            .backgroundColor("#ff9eb7af")
            .fontColor("#fff")
            .fontSize(17)
            .border({radius:15})
            .height(50)
            .onClick(() =>{
              this.getUIContext().getRouter().pushUrl({
                url:"pages/MainPage"
              })
            })

          Button("Demos")
            .width(120)
            .backgroundColor("#ff9eb7af")
            .fontColor("#fff")
            .fontSize(17)
            .border({radius:15})
            .height(50)
            .onClick(() =>{
              this.getUIContext().getRouter().pushUrl({
                url:"pages/DemoPage"
              })
            })
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .width("100%")
        .height(60)

      }else{
        Button("开始记录")
          .width(200)
          .backgroundColor("#ff9eb7af")
          .fontColor("#fff")
          .fontSize(17)
          .border({radius:15})
          .height(50)
          .onClick(() =>{
            this.getUIContext().getRouter().pushUrl({
              url:"pages/MainPage"
            })
          })
      }
    }
    .onTouch(() => {
      let info = this.getUIContext().getComponentUtils().getRectangleById("size");
      let componentSize: Size = info.size;
      SceneProxy.sceneSize.width = componentSize.width;
      SceneProxy.sceneSize.height = componentSize.height;
      SceneProxy.ratio =  componentSize.width / componentSize.height;
    })
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }
  pageTransition() {
    PageTransitionEnter({delay:500, duration:250,curve:Curve.Linear})
      .opacity(0)
    PageTransitionExit({delay:0, duration:250,curve:Curve.Linear})
      .opacity(0)
  }
}