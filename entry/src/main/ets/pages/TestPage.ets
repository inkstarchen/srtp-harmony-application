import image from '@ohos.multimedia.image'
import { ImageUtils } from '../shared/utils/ImageUtils';
import { RaycastParameters, ShaderMaterial, Vec2, Vec3, Vec4 } from '@kit.ArkGraphics3D';
import { AnimatorOptions, AnimatorResult } from '@kit.ArkUI';
import { Touch, TouchDown, TouchMove, TouchUp, TOUCH_DEFAULT } from '../shared/utils/TouchManager';
import { getScreenSize } from '../shared/ui/uiUtils';
import { getDateByTimeStamp, getDateStringWithTimeStamp } from '../shared/utils/Time/time';
import { TraceVec2 } from '../core/math/vec';
import { ComponentSnapshot } from '@ohos.arkui.UIContext';
import { NoteViewModel } from '../feature/note/NoteVeiwModel';
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
export struct TestPage {
  @Require @Param photoOffset: TraceVec2;
  @Require @Param translatePos: TraceVec2;
  @Event setBlock:(flag:boolean) => void;
  @Local ScreenSize: Size = getScreenSize();
  touch:Touch = {
    phase :0,
    active : false,
    downPos : {x:0,y:0},
    curPos : {x:0, y:0},
    lastPos : {x:0,y:0},
  } as Touch;
  @Local pixmap: image.PixelMap | undefined = undefined;
  @Local loadPixmap: image.PixelMap | undefined = undefined;
  uiContext: UIContext = this.getUIContext();
  @Local imageUri: string = '';
  @Local backId: number = 0;
  @Event showCard: (imageUri:string) => void;
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  @Local delta: Vec3 = {x:0,y:0,z:0};
  @Local backAnimator: AnimatorResult | undefined = undefined;
  step: number = 0;
  material: ShaderMaterial | null = null;
  @Local init:boolean = false;
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  @Local options: RichEditorOptions = { controller: this.noteViewModel.getController() };

  aboutToAppear(): void {
    this.sceneProxy.loadScene('emptyscene');
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

  async captureAndDisplay() {

    let now = Date.now();
    let timeArray = getDateByTimeStamp(now);
    let array: Array<string> = [];
    let interPath:string = `/photoCards/${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`;
    let CardName = `${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`
    await ImageUtils.TakePictureAndSave(this.getUIContext().getHostContext(),interPath);
    let fileDir = this.uiContext.getHostContext()?.getApplicationContext().filesDir;
    let pixMap = await this.getUIContext().getComponentSnapshot().get("page");
    await ImageUtils.savePixelMapToFile(pixMap, fileDir + interPath + '/component.png');
    if(fileDir){
      array.push(fileDir + interPath + '/capture.png');
      array.push(fileDir + interPath + '/component.png');
      let loadPixmap = ImageUtils.TwoImageStencil(array, false);
      if(loadPixmap){
        await ImageUtils.savePixelMapToFile(loadPixmap, fileDir + interPath + '/fix.png');
        this.sceneProxy.addCard(fileDir + interPath + '/fix.png',CardName);
      }
    }
  }

  aboutToDisappear(): void {
    this.sceneProxy.releaseScene();
  }

  build() {
    Stack({alignContent:Alignment.Center}){
      Column() {
        Button("capture")
          .onClick(async () => {
            await this.captureAndDisplay();
          })
      }
      .width("100%")
      .height("100%")
      .backgroundColor("#00fff8eb")

      Stack({alignContent:Alignment.Center}){

        RichEditor(this.options)
          .onSelectionChange((range: RichEditorRange) => {
            if (range.start === undefined || range.end === undefined) {
              return;
            }
            const start = range.start;
            const end = range.end;
            // hilog.debug(DOMAIN_NUMBER, TAG, `选中范围: [${start}, ${end}]`);
            this.noteViewModel.updateSelection(start, end);
          })
          // .aboutToIMEInput((value: RichEditorInsertValue) => {
          //   hilog.debug(DOMAIN_NUMBER, TAG, `即将输入: ${value.insertValue}`);
          //   return true;
          // })
          .placeholder('开始记录您的想法...', {
            fontColor: Color.Gray,
            font: {
              size: 16,
              weight: FontWeight.Normal,
              family: "HarmonyOS Sans",
              style: FontStyle.Normal
            }
          })
          .backgroundColor(Color.White)
          .id("page")
          .width('60%')
          .height("60%")
        if(this.sceneProxy.options){
          Component3D(this.sceneProxy.options)
            .renderWidth('100%')
            .renderHeight('100%')
            .id('3D')
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .backgroundColor("#00ffffff")
      .hitTestBehavior(HitTestMode.None)
      .width("100%")
      .height("100%")

    }
    .backgroundColor("#00ffffff")
    .hitTestBehavior(HitTestMode.Transparent)
    .onTouch(async (event) => {
      if(event.type == TouchType.Down){
        TouchDown(event, this.touch);
        const info = this.uiContext.getComponentUtils().getRectangleById('3D');

        let x = this.uiContext.vp2px(event.touches[0].x);
        let y = this.uiContext.vp2px(event.touches[0].y);
        {
        // console.info('RayCastTest | size' + info.size.width.toString() + '/' + info.size.height.toString());
        // console.info('RayCastTest | TouchPos ' + x.toString() + '/' + y.toString());
        // console.info('RayCastTest | offset ' + info.windowOffset.x.toString() + '/' + info.windowOffset.y.toString() );
        // console.info('RayCastTest | touchOffset ' + (x - info.windowOffset.x).toString() + '/' + (y - info.windowOffset.y).toString());
        }
        let fx = (2 * x) / this.ScreenSize.width  - 1;
        let fy = 1 - (2 * y) / this.ScreenSize.height ;
        // this.sceneProxy.rayCast({x:fx,y:fy});
        let node = this.sceneProxy.scene?.root;
        if(node){
          // raycastParams.rootNode = node;
          // let result = await this.sceneProxy.camera?.raycast({x:fx,y:fy} as Vec2,raycastParams);
          // if(result){
          //   if(event.type == TouchType.Down && result.length != 0){
          //     this.setBlock(true);
          //   }
          //   for(let i = 0; i < result.length; i++){
          //     console.info('RayCastTest | Results ' + result[i].node.name);
          //   }
          //   this.sceneProxy.touchRotate.target = result[0].node;
          // }
        }

      }
      if(event.type == TouchType.Move){
          TouchMove(event,this.touch);
      }
      if(event.type == TouchType.Up){
        TouchUp(event,this.touch);
        this.setBlock(false);
      }

    })
    .translate({x:this.photoOffset.x + this.translatePos.x,y:this.photoOffset.y + this.translatePos.y})
    .width("100%")
    .height("100%")

  }
}
