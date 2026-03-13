import image from '@ohos.multimedia.image'
import { ImageUtils } from '../shared/utils/ImageUtils';
import { RaycastParameters, ShaderMaterial, Vec2, Vec3, Vec4 } from '@kit.ArkGraphics3D';
import { AnimatorOptions, AnimatorResult } from '@kit.ArkUI';
import { Touch, TouchDown, TouchMove, TouchUp, TOUCH_DEFAULT } from '../shared/utils/TouchManager';
import { getScreenSize } from '../shared/ui/uiUtils';
import { getDateByTimeStamp, getDateStringWithTimeStamp } from '../shared/utils/Time/time';
import { TraceVec2 } from '../core/math/vec';
import { ComponentSnapshot } from '@ohos.arkui.UIContext';
import { NoteViewModel } from '../feature/note/NoteViewModel';
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
    this.sceneProxy.loadScene('emptyscene',this.getUIContext());
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

      Stack({alignContent:Alignment.BottomStart}){
        Stack(){
          Column() {
            Column() {
              // 标题区域
              Row() {  //, verticalAlign: ItemAlign.Center
                TextInput({ text: "无标题" })
                  .layoutWeight(1)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .backgroundColor(Color.Transparent)
                  .maxLines(1)
                  .textAlign(TextAlign.Start)
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 8, bottom: 4 })
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .height("15%")
            .backgroundColor(Color.White)
            .borderRadius(8)
            .padding({ top: 4, bottom: 4 })

            Divider().strokeWidth(4).color('#F1F3F5').width("80%")

            // 富文本编辑器区域
            Column() {
              RichEditor(this.options)
                .placeholder('开始记录您的想法...', {
                  fontColor: Color.Gray,
                  font: {
                    size: 16,
                    weight: FontWeight.Normal,
                    family: "HarmonyOS Sans",
                    style: FontStyle.Normal
                  }
                })
                .onSelectionChange((range: RichEditorRange) => {
                  if (range.start === undefined || range.end === undefined) {
                    return;
                  }
                  const start = range.start;
                  const end = range.end;
                  // hilog.debug(DOMAIN_NUMBER, TAG, `选中范围: [${start}, ${end}]`);
                  this.noteViewModel.updateSelection(start, end);
                })
                .backgroundColor("#ffffffff")
                .width('100%')
                .height('100%')
            }
            .layoutWeight(1)
            .width("100%")
            .padding({top:5,left:10,right:10,bottom:20})
            .margin({top:10})
            .backgroundColor('#00ffffff')
          }
          .backgroundColor('#ffffffff')
          .padding(10)
          .width("100%")
          .height('100%')
          .id("page")
        }
        .clip(true)
        .border({radius: 15,width:0})
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .width("60%")
        .height('60%')

      }
      .hitTestBehavior(HitTestMode.None)
      .backgroundColor("#00ffffff")
      .width("100%")
      .height("100%")

      Stack({alignContent:Alignment.Center}){
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
    .translate({x:this.photoOffset.x + this.translatePos.x,y:this.photoOffset.y + this.translatePos.y})
    .width("100%")
    .height("100%")

  }
}
