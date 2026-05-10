import { SceneProxy } from '../core/scene3D/GlobalSceneProxy';
import { display, mediaquery, Prompt } from '@kit.ArkUI';
import { Vec2 } from '@kit.ArkGraphics3D';


function onPortrait(mediaQueryResult: mediaquery.MediaQueryResult) {
  console.info('mediaQueryResult.matches:' + mediaQueryResult.matches)
  if (mediaQueryResult.matches) {
    console.info("横屏")
    let displayClass: display.Display | null = null;
    try {
      displayClass = display.getDefaultDisplaySync();
      console.info("get display size " + displayClass.width.toFixed(2) + " | " + displayClass.height.toFixed(2));
      SceneProxy.screenRatio = displayClass.width / displayClass.height;
      SceneProxy.screenSizeInit = false;
      SceneProxy.sceneSize.width = displayClass.height;
      SceneProxy.sceneSize.height = displayClass.height;
      console.info("get display ratio " + SceneProxy.screenRatio.toFixed(2));
    } catch (exception) {
      console.error(`Failed to get default display. Code: ${exception.code}, message: ${exception.message}`);
    }
    // do something here
  } else {
    console.info("竖屏")
    let displayClass: display.Display | null = null;
    try {
      displayClass = display.getDefaultDisplaySync();
      console.info("get display size " + displayClass.width.toFixed(2) + " | " + displayClass.height.toFixed(2));
      SceneProxy.screenRatio = displayClass.width / displayClass.height;
      SceneProxy.screenSizeInit = false;
      SceneProxy.sceneSize.width = displayClass.width;
      SceneProxy.sceneSize.height = displayClass.height;
      console.info("get display ratio " + SceneProxy.screenRatio.toFixed(2));
    } catch (exception) {
      console.error(`Failed to get default display. Code: ${exception.code}, message: ${exception.message}`);
    }
    // do something here
  }
}

@Entry
@ComponentV2
struct Index{
  @Local uiContext: UIContext = this.getUIContext();
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  @Local Debug: boolean = true;
  async onPageShow(): Promise<void> {
    let listener = this.getUIContext().getMediaQuery().matchMediaSync('(orientation: landscape)'); // Listen to landscape events
    listener.on('change', onPortrait) // Register callback
    // await this.sceneProxy.LoadCollision();
    // this.sceneProxy.eventQueue.setStatic(3,false);
  }

  onPageHide(): void {
    // this.sceneProxy.releaseScene();
  }
  build(){
    // Stack({alignContent:Alignment.Center}){
    //   Column(){
    //
    //   }
    //   .width("100%")
    //   .height("100%")
    //   .onTouch((event) => {
    //     if(!SceneProxy.screenSizeInit){
    //       let info = this.getUIContext().getComponentUtils().getRectangleById("3D");
    //       console.info("ScreenTest | component position x " + info.windowOffset.x.toFixed(2) + " y " + info.windowOffset.y.toFixed(2));
    //       console.info("ScreenTest | component size | width " + info.size.width.toFixed(2) + " height " + info.size.height.toFixed(2));
    //       SceneProxy.sceneSize = info.size;
    //       SceneProxy.screenSizeInit = true;
    //     }
    //     let uiContext = this.uiContext;
    //     // Prompt.showToast({message:"TouchTest |  x " +  event.touches[0].x.toFixed(2) + " y " + event.touches[0].y.toFixed(2)})
    //     let TouchPos:Vec2 = {x: event.touches[0].x, y:event.touches[0].y};
    //     this.sceneProxy.rayCast(TouchPos,this.uiContext);
    //   })
    //   if(this.sceneProxy.options){
    //     Component3D(this.sceneProxy.options)
    //       .renderWidth("100%")
    //       .renderHeight("100%")
    //       .hitTestBehavior(HitTestMode.None)
    //       .backgroundColor("#00ffffff")
    //       .id("3D")
    //   }
    // }
    // .width("100%")
    // .height("100%")
    // .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
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