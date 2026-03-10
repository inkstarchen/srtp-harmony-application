import image from '@ohos.multimedia.image'
import { ImageUtils } from '../shared/utils/ImageUtils';
import { RaycastParameters, ShaderMaterial, Vec2, Vec3, Vec4 } from '@kit.ArkGraphics3D';
import { AnimatorOptions, AnimatorResult } from '@kit.ArkUI';
import { getTouchDefault, Touch, TouchDown, TouchMove, TouchUp, TOUCH_DEFAULT } from '../shared/utils/TouchManager';
import { getScreenSize } from '../shared/ui/uiUtils';
import { getDateStringWithTimeStamp } from '../shared/utils/Time/time';
import { TraceVec2 } from '../core/math/vec';
import { SceneProxy } from '../core/scene3D/GlobalSceneProxy';


const  ANIMATION_OPTION: AnimatorOptions = {
  duration: 2000,
  easing: 'ease',
  delay: 0,
  fill: 'none',
  direction: 'normal',
  iterations: -1,
  begin: 100,
  end: 200
};

@ComponentV2
export struct PlayGround {
  @Require @Param playOffset:TraceVec2;
  @Require @Param translatePos: TraceVec2;
  @Local ScreenSize: Size = getScreenSize();
  touch:Touch = getTouchDefault();
  @Local imageUri: string = '';
  @Local backId: number = 0;
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  @Local backAnimator: AnimatorResult | undefined = undefined;
  step: number = 0;
  material: ShaderMaterial | null = null;
  @Local init:boolean = false;

  aboutToAppear(): void {
    this.sceneProxy.loadScene('demo1').then(() => {
      this.sceneProxy.scene1_init();
    })
    this.backAnimator = this.getUIContext().createAnimator(ANIMATION_OPTION);
    this.backAnimator.onFrame = () => {
      this.step++;
      if (this.material && this.material.colorShader) {
        // Just give a random effect.
        (this.material.colorShader.inputs['vec_1'] as Vec4) = {
          x: Math.abs(Math.sin(this.step) + 0.5),
          y: Math.abs(Math.sin(this.step * 0.86) + 0.5),
          z: Math.abs(Math.sin(this.step * 0.91) + 0.5),
          w: 1.0
        };
        (this.material.colorShader.inputs['time'] as number) = this.step;
      }
    };
  }

  aboutToDisappear(): void {
    this.sceneProxy.releaseScene();
  }

  build() {
    Stack({alignContent:Alignment.Center}){
      if(this.sceneProxy.options){
        Component3D(this.sceneProxy.options)
          .renderWidth('100%')
          .renderHeight('100%')
          .id('3D')
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .hitTestBehavior(HitTestMode.Transparent)
    .onTouch((event) => {
      if(event.type == TouchType.Down){

        this.sceneProxy.rayCast({x:event.touches[0].x, y:event.touches[0].y},this.getUIContext());
      }
    })
    // .onTouch((event) => {
    //   if(event.type == TouchType.Down){
    //     TouchDown(event, this.touch);
    //     const info = this.uiContext.getComponentUtils().getRectangleById('3D');
    //
    //     let x = this.uiContext.vp2px(event.touches[0].x);
    //     let y = this.uiContext.vp2px(event.touches[0].y);
    //
    //     // 转换为归一化坐标
    //     let fx = x / this.ScreenSize.width;
    //     let fy = y / this.ScreenSize.height;
    //
    //     // 通过事件队列发送 Raycast 请求
    //     // this.sceneProxy.eventQueue.pushRaycastRequest(fx, fy);
    //     // 刷新队列，触发 C++ 处理
    //     // this.sceneProxy.eventQueue.flush();
    //   }
    //   if(event.type == TouchType.Move){
    //     TouchMove(event, this.touch);
    //     if(this.sceneProxy.touchRotate.target){
    //       // 计算触摸增量
    //       let dx = this.touch.curPos.x - this.touch.lastPos.x;
    //       let dy = this.touch.curPos.y - this.touch.lastPos.y;
    //
    //       // 通过事件队列发送 Rotate 请求
    //       let id = this.sceneProxy.physicalSystem.getId(
    //         this.sceneProxy.touchRotate.target.path + "/" + this.sceneProxy.touchRotate.target.name
    //       );
    //       if(id != undefined){
    //         // this.sceneProxy.eventQueue.pushRotateRequest(id, dx, dy);
    //         // 刷新队列，触发 C++ 处理
    //         // this.sceneProxy.eventQueue.flush();
    //       }
    //     }
    //   }
    //   if(event.type == TouchType.Up){
    //     TouchUp(event, this.touch);
    //   }
    // })
    .translate({x:this.playOffset.x + this.translatePos.x,y:this.playOffset.y + this.translatePos.y})
    .width("100%")
    .height("100%")

  }
}
