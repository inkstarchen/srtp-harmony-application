import image from '@ohos.multimedia.image'
import { ImageUtils } from '../shared/utils/ImageUtils';
import { Image, LightType, RaycastParameters, ShaderMaterial, SpotLight, Vec2, Vec3, Vec4 } from '@kit.ArkGraphics3D';
import { AnimatorOptions, AnimatorResult, matrix4 } from '@kit.ArkUI';
import { Touch } from '../shared/utils/TouchManager';
import { getScreenSize } from '../shared/ui/uiUtils';
import { getDateByTimeStamp, getDateStringWithTimeStamp } from '../shared/utils/Time/time';
import { TraceSize, TraceVec2 } from '../core/math/vec';
import { NoteViewModel } from '../feature/note/NoteViewModel';
import { SceneProxy } from '../core/scene3D/GlobalSceneProxy';
import { PerspectiveTransform, PerspectiveMatrixBuilder } from '../core/math/PerspectiveTransform';
import { Constants } from '../shared/constants';

@ObservedV2
export class UIInfo{
  @Trace position: TraceVec2 = new TraceVec2();
  @Trace size: TraceSize = new TraceSize();
}


@ComponentV2
export struct TestPage {
  @Local uiInfo: UIInfo = new UIInfo();
  @Local nodeInit: boolean = false;
  @Local TestMatrix: matrix4.Matrix4Transit = matrix4.identity();
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
  @Local animTest: AnimatorResult | undefined;
  aboutToAppear(): void {
    this.sceneProxy.loadSceneFrom();
    this.backAnimator = this.getUIContext().createAnimator(Constants.ANIMATION_OPTION);
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
    this.animTest = this.getUIContext().createAnimator(Constants.ANIMATION_OPTION_2);
    this.animTest.onFrame = (progress) => {
      this.uiInfo.size.width = 200 - (progress * 100);
      console.info("UI Width = " + this.uiInfo.size.width.toString());
      this.syncUIto3D('ui');
    }
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
    await ImageUtils.savePixelMapToFile(pixMap, fileDir + interPath + '/component.png');
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

  /**
   * 将 2D UI 的位置和尺寸同步到对应的 3D 替身
   * @param uiId 2D UI 组件的 id
   */
  syncUIto3D(uiId: string) {
    // 1. 获取 3D Node ID
    const nodeId = this.sceneProxy.get3DNodeId(uiId);
    if (nodeId === undefined) {
      console.warn(`[syncUIto3D] 未找到 UI '${uiId}' 对应的 3D 节点`);
      return;
    }

    // 2. 获取 3D 视口尺寸（用于归一化）
    const viewportInfo = this.uiContext.getComponentUtils().getRectangleById('3D');
    const vpWidth = viewportInfo.size.width;
    const vpHeight = viewportInfo.size.height;

    // 3. 获取 2D UI 的实时位置和尺寸
    const uiInfo = this.uiContext.getComponentUtils().getRectangleById(uiId);
    const uiWidth = this.uiContext.vp2px(this.uiInfo.size.width);
    const uiHeight = this.uiContext.vp2px(this.uiInfo.size.height);

    // 4. 计算 3D 归一化位置（屏幕坐标 → 3D 相机空间）
    // 相机在 z=-6 处，fov=90°，视口宽度对应约 10 个 3D 单位
    const worldScale = 10.0;
    const centerX = vpWidth / 2;
    const centerY = vpHeight / 2;
    const uiCenterX = uiInfo.windowOffset.x + uiWidth / 2;
    const uiCenterY = uiInfo.windowOffset.y + uiHeight / 2;

    const posX = ((uiCenterX - centerX) / vpHeight) * worldScale;
    const posY = -((uiCenterY - centerY) / vpHeight) * worldScale;
    const posZ = -1.0; // 固定深度层

    // 5. 计算 3D 缩放
    console.info('uiWidth is ' + uiWidth.toString());
    const scaleX = (uiWidth / vpHeight) * worldScale;
    const scaleY = (uiHeight / vpHeight) * worldScale;

    // 6. 通过 EventQueue 发送更新指令
    this.sceneProxy.eventQueue.updateTransform(
      nodeId,
      { x: posX, y: posY, z: posZ },
      { x: scaleX, y: scaleY }
    );

    console.info(`[syncUIto3D] '${uiId}' → pos(${posX.toFixed(2)}, ${posY.toFixed(2)}, ${posZ}) scale(${scaleX.toFixed(2)}, ${scaleY.toFixed(2)})`);
  }

  build() {
    Stack({alignContent:Alignment.Center}){

      Stack({alignContent:Alignment.Center}){

        Column(){
          if(this.sceneProxy.options){
            Component3D(this.sceneProxy.options)
              .renderWidth('100%')
              .renderHeight('100%')
              .hitTestBehavior(HitTestMode.None)
          }
        }
        .id('3D')
        .width("100%")
        .height("100%")
        Column(){

        }
        .width(this.uiInfo.size.width)
        .height(this.uiInfo.size.height)
        .id('ui')
        .onClick(() => {
            this.animTest?.play()
        })
        // .transform3D(this.TestMatrix)
        .backgroundColor("#72ea3d3d")
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor("#00ffffff")
      .hitTestBehavior(HitTestMode.None)
      .width("100%")
      .height("100%")

    }
    .backgroundColor("#00ffffff")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .hitTestBehavior(HitTestMode.Transparent)
    .onTouch((event) => {
      if(!this.init){
        let info = this.uiContext.getComponentUtils().getRectangleById('3D');
        console.info("3D ViewPort Size is " + info.size.width.toString() + "*" + info.size.height.toString());
        this.uiInfo.size.width = 200;
        this.uiInfo.size.height = 200;
        console.log('uiInfo Size: ' + this.uiInfo.size.width.toString() +"*" + this.uiInfo.size.height.toString());
        let uiposition = this.uiContext.getComponentUtils().getRectangleById('ui').windowOffset;
        let centeroffset = uiposition.x + this.uiContext.vp2px(this.uiInfo.size.width) / 2 - info.size.width / 2;
        // this.TestMatrix = this.getTiltMatrix(90,info.size.height/2,0,0,centeroffset,0);
        let relativeFactor:Vec2 = {
          x:this.uiContext.vp2px(this.uiInfo.size.height - 2) / info.size.height,
          y:this.uiContext.vp2px(this.uiInfo.size.width - 2) / info.size.height
        } as Vec2;
        let scale: Vec2 = {
          x: 10 * relativeFactor.x,
          y: 10 * relativeFactor.y
        } as Vec2;
        if(!this.nodeInit){
          this.sceneProxy.addUIPlane('ui',scale);
          this.sceneProxy.addBall('ball');
          this.nodeInit = true;
          // 初始化完成后立即同步一次
          setTimeout(() => {
            this.syncUIto3D('ui');
          }, 100);
        }
        this.init = true;
        console.info("3D Screen Position is " + info.screenOffset.x.toString() + "*" + info.screenOffset.y.toString());
        console.info("3D Window Position is " + info.windowOffset.x.toString() + "*" + info.screenOffset.y.toString());
        console.info("3D Local Position is " + info.localOffset.x.toString() + "*" + info.localOffset.y.toString());
      }



      if(event.type == TouchType.Down){
        this.sceneProxy.sendTouchDown({x:event.touches[0].x, y:event.touches[0].y});
        this.sceneProxy.rayCast({x:event.touches[0].x, y:event.touches[0].y},this.getUIContext());
      }else if(event.type == TouchType.Move){
        this.sceneProxy.sendTouchMove({x:event.touches[0].x, y:event.touches[0].y});
        // 示例：如果 UI 位置发生变化，调用同步
        // this.uiInfo.position.x = event.touches[0].x;
        // this.uiInfo.position.y = event.touches[0].y;
        // this.syncUIto3D('ui');
      }else if(event.type == TouchType.Up){
        this.sceneProxy.sendTouchUp();
      }
    })
    .width("100%")
    .height("100%")
  }

  /**
   * 使用新的透视变换工具计算矩阵
   *
   * 参数说明：
   * - fovy: 相机视场角 (度) - 值越大透视效果越明显
   * - distance: 相机距离平面中心的距离 (像素)
   * - rotateX/rotateY: 平面组件的旋转角度 (度)
   * - translateX/translateY: 平面组件离中心的偏移 (像素)
   */
  private getTiltMatrix(
    fovy: number = 90,
    distance: number = 400,
    rotateX: number = 0,
    rotateY: number = 45,
    translateX: number = 0,
    translateY: number = 0
  ): matrix4.Matrix4Transit {
    // 使用透视变换工具计算矩阵
    const matrixArray = PerspectiveTransform.calculateSimpleTransform(
      PerspectiveTransform.degToRad(fovy),    // 转换为弧度
      distance,
      PerspectiveTransform.degToRad(rotateX),
      PerspectiveTransform.degToRad(rotateY),
      translateX,
      translateY
    );

    return matrix4.init(matrixArray);
  }

  /**
   * 完整参数版本的透视变换矩阵计算
   * 支持平面尺寸和偏移视差效果
   */
  private getTiltMatrixWithParallax(
    fovy: number,
    distance: number,
    rotateX: number,
    rotateY: number,
    offsetX: number,
    offsetY: number,
    planeWidth: number,
    planeHeight: number
  ): matrix4.Matrix4Transit {
    const matrixArray = PerspectiveTransform.calculateTransformMatrix({
      fovy: PerspectiveTransform.degToRad(fovy),
      cameraDistance: distance,
      rotation: {
        x: PerspectiveTransform.degToRad(rotateX),
        y: PerspectiveTransform.degToRad(rotateY)
      } as Vec3,
      offset: { x: offsetX, y: offsetY },
      planeSize: { width: planeWidth, height: planeHeight }
    });

    return matrix4.init(matrixArray);
  }

  /**
   * 使用链式API构建变换矩阵 (推荐用于复杂场景)
   */
  private getTiltMatrixBuilder(): matrix4.Matrix4Transit {
    const matrixArray = new PerspectiveMatrixBuilder()
      .setCamera(60, 400, this.ScreenSize.width, this.ScreenSize.height)
      .setRotation(0, 45)
      .setTranslation(0, 0)
      .build();

    return matrix4.init(matrixArray);
  }

  // ==================== 2D UI → 3D 替身同步使用示例 ====================
  /**
   * 使用示例：在任何涉及 2D 组件移动和尺寸变化的函数中，调用 syncUIto3D()
   *
   * 示例 1：拖拽移动
   * onDragUpdate(newX: number, newY: number) {
   *   this.uiInfo.position.x = newX;
   *   this.uiInfo.position.y = newY;
   *   this.syncUIto3D('ui');  // ← 只需这一行
   * }
   *
   * 示例 2：缩放调整
   * onResize(newWidth: number, newHeight: number) {
   *   this.uiInfo.size.width = newWidth;
   *   this.uiInfo.size.height = newHeight;
   *   this.syncUIto3D('ui');  // ← 只需这一行
   * }
   *
   * 示例 3：动画结束后同步
   * onAnimationEnd() {
   *   this.syncUIto3D('ui');
   * }
   *
   * 核心流程：
   * 1. 2D UI 变化（位置/尺寸）
   * 2. 调用 syncUIto3D(uiId)
   * 3. 自动查找对应的 3D Node ID
   * 4. 计算归一化坐标和缩放
   * 5. 通过 EventQueue 发送到物理引擎
   * 6. 3D 替身自动跟随更新
   *
   * 注意事项：
   * - 默认使用 addUIPlane() 创建静态替身，位置完全由 syncUIto3D() 控制
   * - 如需物理交互（碰撞、重力），使用 addDynamicUIPlane() 创建动态替身
   * - 动态替身的位置会受物理引擎影响，syncUIto3D() 会设置初始位置
   */
}
