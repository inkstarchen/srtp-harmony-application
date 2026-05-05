import { SceneProxy } from '../../core/scene3D/GlobalSceneProxy'
import { Animation } from '@kit.ArkGraphics3D';
import { AnimatorResult, Prompt } from '@kit.ArkUI';

@Entry
@ComponentV2
struct Render2{
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  @Local z3D:number = 2;
  @Local anim0:Animation | undefined;
  @Local anim1:Animation | undefined;
  async aboutToAppear(): Promise<void> {
    await this.sceneProxy.LoadRotationBall();
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
          .zIndex(this.z3D)
      }
      Column(){

      }
      .width(300)
      .height(100)
      .backgroundColor("#ff47db5e")
      .shadow({radius:20,offsetX:10,offsetY:10,color: "#ffacacac"
      })
      .border({radius:15,width:0})
      .zIndex(1)

    }
    .onClick(() => {
      let anim0 = this.sceneProxy.scene?.animations[0];
      let anim1 = this.sceneProxy.scene?.animations[1];
      Prompt.showToast({message:"size is " + this.sceneProxy.scene?.animations.length.toString()});
      if(anim0){
        this.anim0 = anim0;
        this.anim0.onFinished(() => {
          this.anim0?.stop();
          this.anim1?.restart();
          this.z3D = 2;
        })
      }
      if(anim1){
        this.anim1 = anim1;
        this.anim1.onFinished(() => {
          this.anim1?.stop();
          this.anim0?.restart();
          this.z3D = 0;
        })
      }
      this.anim1?.restart();

    })
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }
}