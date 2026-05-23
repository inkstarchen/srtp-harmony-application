import { SceneProxy } from '../../core/scene3D/GlobalSceneProxy'
import { captureAndDisplay } from '../../core/scene3D/ImageTo3D';
import { Camera, Vec2 } from '@kit.ArkGraphics3D';
import { TraceVec2 } from '../../core/math/vec';
import { AnimatorResult, Prompt } from '@kit.ArkUI';
import { Constants } from '../../shared/constants';
import { UIInfo } from '../../shared/ui/uiUtils';


@Entry
@ComponentV2
struct Render1{
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  @Local uiEntities: UIInfo[] = [];
  @Local temp_x: number = 0;
  @Local anim: AnimatorResult = this.getUIContext().createAnimator(Constants.ANIMATION_OPTION_2);
  async aboutToAppear(): Promise<void> {
    // if(this.sceneProxy.scene) Prompt.showToast({message:"already have scene"});
    await this.sceneProxy.LoadPhotoWall();
    // await this.sceneProxy.addBall("ball");
    let config = this.sceneProxy.getCameraConfig()
    if(config){
      this.sceneProxy.physicalSystem.enableLayout(this.sceneProxy.camera as Camera);
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
        Column(){
          Component3D(this.sceneProxy.options)
            .renderWidth("100%")
            .renderHeight("100%")
            .hitTestBehavior(HitTestMode.None)
            .id("3D")
        }
        .width(this.getUIContext().px2vp(SceneProxy.sceneSize.height))
        .height(this.getUIContext().px2vp(SceneProxy.sceneSize.height))


      }
      Column({space:20}){
        Button("Scale")
          .onClick(() => {
            if(this.uiEntities.length != 0){
              this.temp_x = this.uiEntities[0].pos.x;
              this.anim.onFrame = (progress) => {
                this.uiEntities[0].size.x = 400 + 200 * progress;
                this.uiEntities[0].pos.x = this.temp_x + 200 * progress;
                SceneProxy.syncUI(this.uiEntities[0].id,this.uiEntities[0])
              }
              this.anim.play();
            }
          })
        Button("Capture")
          .onClick(() => {
            captureAndDisplay(this.getUIContext(), this.sceneProxy);
          })

        Button("CreateBox")
          .onClick(() => {
            if(this.uiEntities.length == 0){
              let info = this.getUIContext().getComponentUtils().getRectangleById("3D");
              let infoTemp: UIInfo = new UIInfo({x:info.screenOffset.x + 200,y:info.screenOffset.y + 100},{x:400,y:400},'uid');
              SceneProxy.addUIPlane("uid",infoTemp);
              this.uiEntities.push(infoTemp);
            }
          })

      }
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)
      .width("100%")
      .height("100%")
      .backgroundColor("#00ffffff")
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
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
      Stack({alignContent:Alignment.TopStart}){
        ForEach(this.uiEntities,(uiInfo:UIInfo,index:number) => {
          Column(){

          }
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          .translate({x:this.getUIContext().px2vp(uiInfo.pos.x),y:this.getUIContext().px2vp(uiInfo.pos.y)})
          .width(this.getUIContext().px2vp(uiInfo.size.x))
          .height(this.getUIContext().px2vp(uiInfo.size.y))
          .backgroundColor("#3422f5b9")
        })
      }
      .width("100%")
      .height("100%")
      .hitTestBehavior(HitTestMode.None)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])


    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }
}