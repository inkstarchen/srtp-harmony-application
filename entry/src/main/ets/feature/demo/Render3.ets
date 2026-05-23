import { SceneProxy } from '../../core/scene3D/GlobalSceneProxy'
import { Scene } from '@kit.ArkGraphics3D';

@Entry
@ComponentV2
struct Render3{
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  async aboutToAppear(): Promise<void> {
    await this.sceneProxy.LoadCollision();
    await this.sceneProxy.addBall();
    await this.sceneProxy.addCube();
  }

  aboutToDisappear(): void {
    this.sceneProxy.releaseScene();
  }
  build(){
    Stack({alignContent:Alignment.Center}){
      if(this.sceneProxy.options){
        Column(){
          Component3D(this.sceneProxy.options)
            .renderWidth("100%")
            .renderHeight("100%")
            .hitTestBehavior(HitTestMode.None)
            .backgroundColor("#00ffffff")
        }
        .width(this.getUIContext().px2vp(SceneProxy.sceneSize.height))
        .height(this.getUIContext().px2vp(SceneProxy.sceneSize.height))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      }
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }
}