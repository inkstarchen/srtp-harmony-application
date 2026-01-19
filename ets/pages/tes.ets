import { SceneProxy } from '../core/scene3D/SceneProxy'

@Entry
@ComponentV2
struct Graphics{
  @Local sceneProxy: SceneProxy = new SceneProxy(this.getUIContext());

  aboutToAppear(): void {
    this.sceneProxy.loadScene('test')
  }
  build(){
    Stack({alignContent:Alignment.Center}){
      if(this.sceneProxy.options){
        Component3D(this.sceneProxy.options)
          .renderWidth('100%')
          .renderHeight('100%')

      }
    }
    .onClick(() => {
      this.sceneProxy.update();
    })
    .width('100%')
    .height('100%')

  }
}