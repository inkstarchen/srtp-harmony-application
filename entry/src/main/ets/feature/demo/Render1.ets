import { SceneProxy } from '../../core/scene3D/GlobalSceneProxy'
import { captureAndDisplay } from '../../core/scene3D/ImageTo3D';

@Entry
@ComponentV2
struct Render1{
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.sceneProxy.LoadPhotoWall();
    let config = this.sceneProxy.getCameraConfig()
    if(config){
      this.sceneProxy.physicalSystem.enableLayout(config);
      console.info("enableLayout System");
    }
    this.sceneProxy.enableRotateRequest = true;
  }

  aboutToDisappear(): void {
    this.sceneProxy.releaseScene();
  }
  build(){
    Stack({alignContent:Alignment.Center}){
      if(this.sceneProxy.options){
        Component3D(this.sceneProxy.options)
          .renderWidth("100%")
          .renderHeight("100%")
          .hitTestBehavior(HitTestMode.None)
      }
      Column(){
        Button("Capture")
          .onClick(() => {
            captureAndDisplay(this.getUIContext(), this.sceneProxy);
          })
      }
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)
      .width("100%")
      .height("100%")
      .backgroundColor("#00ffffff")
      .onTouch((event) => {
        if(event.type == TouchType.Down){
          this.sceneProxy.sendTouchDown({x:event.touches[0].x, y:event.touches[0].y});
          this.sceneProxy.rayCast({x:event.touches[0].x, y:event.touches[0].y},this.getUIContext());
        }else if(event.type == TouchType.Move){
          this.sceneProxy.sendTouchMove({x:event.touches[0].x, y:event.touches[0].y});
        }else if(event.type == TouchType.Up){
          this.sceneProxy.sendTouchUp();
        }
      })
    }

    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }
}