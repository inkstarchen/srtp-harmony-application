import { display, mediaquery, Prompt } from '@kit.ArkUI';
import { SceneProxy } from '../core/scene3D/GlobalSceneProxy';
import { BreakpointConstants } from '../shared/BreakPoint/BreakpointConstants';
import { BreakpointManager } from '../shared/BreakPoint/BreakpointManager';


function onPortrait(mediaQueryResult: mediaquery.MediaQueryResult) {
  console.info('mediaQueryResult.matches:' + mediaQueryResult.matches)
  if (mediaQueryResult.matches) {
    console.info("横屏")
    let displayClass: display.Display | null = null;
    try {
      displayClass = display.getDefaultDisplaySync();
      console.info("get display size " + displayClass.width.toFixed(2) + " | " + displayClass.height.toFixed(2));
      SceneProxy.screenRatio = displayClass.width / displayClass.height;
      SceneProxy.ratio = 1.0;
      SceneProxy.screenSizeInit = false;
      SceneProxy.sceneSize.width = displayClass.width;
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
      SceneProxy.ratio = 1.0;
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
  @Local currentBreakpoint: string = BreakpointConstants.TYPE_MD;
  @Local uiContext: UIContext = this.getUIContext();

  @Local Debug: boolean = true;

  aboutToAppear(): void {
    BreakpointManager.getInstance(this.getUIContext()).startListening((breakpoint:string) => {
      this.currentBreakpoint = breakpoint;
      console.info(`当前断点: ${breakpoint}`);
    })
  }

  async onPageShow(): Promise<void> {
    let listener = this.getUIContext().getMediaQuery().matchMediaSync('(orientation: landscape)'); // Listen to landscape events
    listener.on('change', onPortrait) // Register callback
  }

  onPageHide(): void {
  }
  build(){
    Row(){
      if(this.currentBreakpoint === BreakpointConstants.TYPE_SM){
        this.SingleColumLayout()
      }else{
        this.TwoColumnLayout()
      }
    }
    .width("100%")
    .height("100%")
    .onTouch(() => {
      SceneProxy.safeOffset = this.getUIContext().getComponentUtils().getRectangleById('Safe').windowOffset.y;
    })
    .id('Safe')
  }

  @Builder
  SingleColumLayout() {
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

      }
      else{
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
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }

  @Builder
  TwoColumnLayout(){
    Column(){
      Image($r("app.media.IndexBack"))
        .width("100%")
        .height("100%")
    }
    .width("60%")
    .height("100%")
    Column(){
      if(this.Debug){
        Column({space:40}){
          Button("开始记录")
            .width("50%")
            .backgroundColor("#ff9eb7af")
            .fontColor("#fff")
            .fontSize(40)
            .border({radius:15})
            .height("20%")
            .onClick(() =>{
              this.getUIContext().getRouter().pushUrl({
                url:"pages/MainPage"
              })
            })

          Button("Demos")
            .width("50%")
            .backgroundColor("#ff9eb7af")
            .fontColor("#fff")
            .fontSize(40)
            .border({radius:15})
            .height("20%")
            .onClick(() =>{
              this.getUIContext().getRouter().pushUrl({
                url:"pages/DemoPage"
              })
            })
        }
        .justifyContent(FlexAlign.Center)
        .width("100%")
        .height("100%")

      }
      else{
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
    .justifyContent(FlexAlign.Center)
    .width("40%")
    .height("100%")
  }

  pageTransition() {
    PageTransitionEnter({delay:500, duration:250,curve:Curve.Linear})
      .opacity(0)
    PageTransitionExit({delay:0, duration:250,curve:Curve.Linear})
      .opacity(0)
  }
}