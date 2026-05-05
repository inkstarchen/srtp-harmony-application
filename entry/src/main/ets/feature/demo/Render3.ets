import { SceneProxy } from '../../core/scene3D/GlobalSceneProxy'

@Entry
@ComponentV2
struct Render3{
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  async aboutToAppear(): Promise<void> {
    await this.sceneProxy.LoadCollision();
    this.sceneProxy.eventQueue.setStatic(3,false);
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
          .backgroundColor("#00ffffff")
      }
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }
}