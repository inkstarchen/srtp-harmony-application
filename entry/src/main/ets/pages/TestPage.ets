import image from '@ohos.multimedia.image'
import { ImageUtils } from '../shared/utils/ImageUtils';
import { Image, RaycastParameters, ShaderMaterial, Vec2, Vec3, Vec4 } from '@kit.ArkGraphics3D';
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
    this.sceneProxy.loadScene('imagetest',this.getUIContext());
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

  async captureAndLoadImage() {
    let now = Date.now();
    let timeArray = getDateByTimeStamp(now);
    let array: Array<string> = [];
    let interPath:string = `/photoCards/${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`;
    let CardName = `${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`
    await ImageUtils.TakePictureAndSave(this.getUIContext().getHostContext(),interPath);
    let fileDir = this.uiContext.getHostContext()?.getApplicationContext().filesDir;
    let pixMap = await this.getUIContext().getComponentSnapshot().get("page");
    await this.ReadPixelsRGBA(pixMap);
    let editablePixel = await this.makeTransparent(pixMap);
    await this.ReadPixelsRGBA(editablePixel);
    await ImageUtils.savePixelMapToFile(editablePixel, fileDir + interPath + '/component.png');
    if(fileDir){
      array.push(fileDir + interPath + '/capture.png');
      array.push(fileDir + interPath + '/component.png');
      let loadPixmap = ImageUtils.TwoImageStencil(array, false);
      if(loadPixmap){
        await ImageUtils.savePixelMapToFile(loadPixmap, fileDir + interPath + '/fix.png');
        this.sceneProxy.addImage(fileDir + interPath + '/component.png',CardName);
      }
    }
  }

  async ReadPixelsRGBA(pixelMap : image.PixelMap) {
  const area: image.PositionArea = {
    pixels: new ArrayBuffer(8), // 8为需要创建的像素buffer大小，取值为：height * width *4。
    offset: 0,
    stride: 8,
    region: { size: { height: 1, width: 2 }, x: 0, y: 0 }
  };
  if (pixelMap != undefined) {
    pixelMap.readPixels(area, (error: BusinessError) => {
      if (error) {
        console.error("Failed to read pixelmap from the specified area. code is ", error);
        return;
      } else {
        console.info('Succeeded in reading pixelmap from the specified area.');
        console.info('RGBA data is ', new Uint8Array(area.pixels));
      }
    })
  }
}

  async makeTransparent(pixelMap: image.PixelMap) : Promise<image.PixelMap> {
    const info = await pixelMap.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;

    // 1. 准备缓冲区
    const byteLength = width * height * 4;
    const buffer = new ArrayBuffer(byteLength);

    const area: image.PositionArea = {
      offset: 0,
      pixels: buffer,
      stride: width * 4,
      region: { size: { width: width, height: height }, x: 0, y: 0 }
    };

    const initOptions: image.InitializationOptions = {
      editable: true, // 【关键】设置为可编辑
      pixelFormat: image.PixelMapFormat.RGBA_8888, // 建议指定格式，通常将 BGRA 转为 RGBA 使用
      size: {
        width: width,
        height: height
      }
    };
    await pixelMap.readPixels(area);


    console.log("pixelMap is editable" + pixelMap.isEditable);

    // 2. 读取像素


    // 3. 使用 Uint32Array 视图
    // 在小端序系统中，RGBA (0,0,0,1) 对应的 32位整数是 0x01000000
    const pixelData = new Uint32Array(buffer);

    // 定义目标匹配值：Alpha=1 (0x01), R=0, G=0, B=0
    // 注意：这里假设 PixelMap 格式是 RGBA_8888
    const TARGET_COLOR = 0x01000000;

    for (let i = 0; i < pixelData.length; i++) {
      // 直接比较 32 位整数，比分别比较 R,G,B,A 快得多
      if (pixelData[i] === TARGET_COLOR) {
        // 将 Alpha 变为 0 (即整个像素变为 0x00000000)
        pixelData[i] = 0x01010101;
      }
    }
    let editablePixelMap = await image.createPixelMap(buffer, initOptions);
    console.log("editablePixelMap is editable" + editablePixelMap.isEditable);
    // 4. 写回
    await editablePixelMap.writePixels(area);
    return editablePixelMap;
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
        Button("ImageTest")
          .onClick(async () => {
            await this.captureAndLoadImage();
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
                  .fontColor("#ff414141")
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
        }
        .clip(true)
        .id("page")
        .border({radius: 60,width:0})
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
    // .translate({x:this.photoOffset.x + this.translatePos.x,y:this.photoOffset.y + this.translatePos.y})
    .width("100%")
    .height("100%")

  }
}
