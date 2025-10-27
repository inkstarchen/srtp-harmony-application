import { SceneManager } from '../Manager3D/SceneManager'
import { BusinessError } from '@kit.BasicServicesKit';
import { AnimatorResult, display, window } from '@kit.ArkUI';
import { touchManager } from '../CanvasClass/ClassUtils';
import { Node, Vec2 } from '@kit.ArkGraphics3D';
import { CalcUtils } from '../utils/calutils';
import { settings } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { NodeManager } from '../Manager3D/NodeManager';

@Entry
@ComponentV2
struct Index{
  @Local imageWidth: number = 40;
  @Local imageHeight: number = 40;
  positionX: number = 100;
  positionY: number = 0;
  particleAnim: AnimatorResult | undefined = undefined;
  dragNode: Node | undefined = undefined;
  rotateNode: Node | undefined = undefined;
  rotateFlag: boolean = false;
  distanceZ: number = 0;
  startPos: Vec2 = {x:0,y:0};
  settingsBrightness:string = '';
  windowBrightness:number = 0;
  @Local emitterProperties: Array<EmitterProperty> = [
    {
      index: 0,
      emitRate: 0, // 每秒发射粒子数
      position: { x: this.positionX, y: this.positionY }, // 设置粒子发射器位置
      size: { width: 20, height: 20 }
    }
  ]

  @Local sceneManager: SceneManager = new SceneManager();
  @Local touchM: touchManager = new touchManager(0);
  hostContext: Context | undefined = undefined;
  uiContext: UIContext | undefined = undefined;
  CameraAnim: AnimatorResult | undefined = undefined;
  intensityId: number = 0;
  raindropId: number = 0;
  stopDrag(){
    console.info('dragId = ' + this.sceneManager.dragId);
    if(this.sceneManager.dragId != -1){
      console.info('clear dragId = ' + this.sceneManager.dragId);
      if(this.dragNode){
        this.sceneManager.reCalAabb(this.dragNode);
      }
      clearInterval(this.sceneManager.dragId);
      this.sceneManager.dragId = -1;
    }else{
      console.info('dragId end = ' + this.sceneManager.dragId)
    }
  }
  onPageShow(): void {
    console.info('Index page')
    if (!this.uiContext) {
      this.uiContext = this.getUIContext();
      this.hostContext = this.uiContext.getHostContext();
      this.particleAnim = this.uiContext.createAnimator({
        duration: 50,
        delay: 0,
        direction: 'normal',
        begin: 0,
        easing: 'ease',
        end: 1,
        iterations: 1,
        fill: 'forwards'
      })
      this.particleAnim.onFrame = (progress) => {
        if (progress < 0.5) {

          this.emitterProperties[0] = {
            index: 0,
            emitRate: 150,
            position: { x: this.positionX, y: this.positionY },
            size: { width: 1, height: 1 }
          }
        } else {
          this.emitterProperties[0] = {
            index: 0,
            emitRate: 0,
            position: { x: this.positionX, y: this.positionY },
            size: { width: 1, height: 1 }
          }
        }
      }
      if (!this.sceneManager.initFlag) {

        let displayClass: Array<display.Display> = [];
        display.getAllDisplays((err: BusinessError, data: Array<display.Display>) => {
          displayClass = data;
          this.sceneManager.screenWidth = displayClass[0].width;
          this.sceneManager.screenHeight = displayClass[0].height;
          this.sceneManager.scaleWH = this.sceneManager.screenWidth / this.sceneManager.screenHeight;
          console.info('width:' + this.sceneManager.screenWidth + '/height :' + this.sceneManager.screenHeight);
          const errCode: number = err.code;
          if (errCode) {
            console.error(`Failed to obtain all the display objects. Code: ${err.code}, message: ${err.message}`);
            return;
          }
          console.info(`Succeeded in obtaining all the display objects. Data: ${JSON.stringify(data)}`);
        });
        this.sceneManager.init(this.hostContext);
      }
    }
  }

  RayCast(event:TouchEvent){
    if(!this.uiContext) return;
    let Px = this.uiContext.vp2px(event.touches[0].windowX) / this.sceneManager.screenWidth * 2 - 1;
    let Py = 1 - this.uiContext.vp2px(event.touches[0].windowY) / this.sceneManager.screenHeight * 2;
    console.info('dot position Px: ' + Px + '/Py :' + Py);
    let returnList = this.sceneManager.rayCast(Px,Py);
    returnList?.forEach((value,index) => {
      if(value.node && value.position){
        console.info('RayCast Info | node name: ' + value.node.name + '/ tMin: ' + value.tMin + '/ positionZ:' + value.position.z );
        let dragAble = this.sceneManager.dragAbleMap.get(value.node.name);
        if(dragAble){
          if(this.sceneManager.dragId != -1) return;
          this.dragNode = value.node;
          this.distanceZ = value.position.z;
          this.startPos.x = value.node.position.x;
          this.startPos.y = value.node.position.y;
          console.info('here')
          let dragId = setInterval(() => {
            console.info('drag Info | drag effect');
            if(!this.dragNode || !this.uiContext) return;
            let distanceSpace = CalcUtils.PlaneSizeToSpaceSize({x:this.uiContext.vp2px(this.touchM.distance.x),y:this.uiContext.vp2px((this.touchM.distance.y))},this.distanceZ,Math.PI / 4, this.sceneManager.screenWidth,this.sceneManager.screenHeight);
            this.dragNode.position = {
              x: this.startPos.x + distanceSpace.x,
              y: this.startPos.y - distanceSpace.y,
              z: this.dragNode.position.z
            }
          },5)
          this.sceneManager.dragId = dragId;
          console.info('dragId == '+ dragId + ' /' + this.sceneManager.dragId)
        }
        let rotateAble = this.sceneManager.rotateAbleMap.get(value.node.name);
        if(rotateAble){
          this.rotateNode = value.node;
          this.rotateFlag = true;
          let index = this.sceneManager.animationMap.get('rotate');
          index?.forEach((value,i) => {
            let anim = this.sceneManager.scene?.animations[value];
            anim?.start();
            anim?.pause();
          })
        }
      }
    })
  }

  build(){
    Column(){
      if (this.sceneManager.sceneOption) {
        Stack() {
          Component3D(this.sceneManager.sceneOption)
            .renderWidth('100%')
            .renderHeight('100%')
          Column(){
            Button('获取屏幕亮度')
              .width(160)
              .margin({
                top: 16,
                bottom:16
              })
              .onClick(() => {
                // Get screen brightness through the getValueSync() method.
                const context: Context = this.getUIContext().getHostContext() as common.UIAbilityContext;
                settings.getValue(context, settings.display.SCREEN_BRIGHTNESS_STATUS).then((value) => {
                  console.log(`promise:value -> ${value}`)
                  if(this.uiContext){
                    this.uiContext.getPromptAction().showToast({message:'brightness:' + value});
                  }
                });
              })
            Button('设置屏幕亮度')
              .width(160)
              .onClick(() => {
                try {
                  this.windowBrightness = Math.random() * (1.0 - 0.0) + 0.0;
                  if (this.windowBrightness < 0 || this.windowBrightness > 1) {
                    console.error(`WindowBrightness is not within the valid range`);
                    return;
                  }
                  let windowClass:window.Window = AppStorage.get('windowClass') as window.Window;
                  windowClass.setWindowBrightness(this.windowBrightness, (err: BusinessError) => {
                    const errCode: number = err.code;
                    if (errCode) {
                      console.error(`Failed to set the brightness. Cause code: ${err.code}, message: ${err.message}`);
                      return;
                    }
                    console.info('Succeeded in setting the brightness.');
                  });
                } catch (exception) {
                  console.error(`Failed to set the brightness. Cause code: ${exception.code}, message: ${exception.message}`);
                }
              })
          }


        }
      }
      else {
        Text('loading...');
      }
      Particle({
        particles: [
          {
            emitter: {
              particle: {
                type: ParticleType.POINT, // 粒子类型
                config: {
                  radius: 1,
                },
                lifetime: 500, // 单个粒子的生命周期
                lifetimeRange: 0, // 粒子生命周期取值范围
                count: -1, // 粒子总数
              },
              emitRate: 0,
              shape: ParticleEmitterShape.RECTANGLE, // 发射器形状
              size: ['100%', '100%'],
              position: [100, 100]
            },
            color: {
              range: ['#ff00ffff', '#ff00ffff']
            },
            opacity: {
              range: [1.0, 1.0],
              updater: {
                type: ParticleUpdater.CURVE,
                config: [
                  {
                    from: 1.0,
                    to: .0,
                    startMillis: 0,
                    endMillis: 1600,
                    curve: Curve.Linear
                  }
                ]
              }
            },
            scale: {
              range: [1.0, 1.0],
              updater: {
                type: ParticleUpdater.CURVE,
                config: []
              }
            },
            velocity:{
              speed:[200,200],
              angle:[210,330]
            },
            acceleration: {
              speed: {
                range: [1500, 1500],
                updater: {
                  type: ParticleUpdater.RANDOM,
                  config: [0, 0]
                }
              },
              angle: {
                range: [90, 90],
                updater: {
                  type: ParticleUpdater.RANDOM,
                  config: [0, 0]
                }
              }
            },
            spin: {
              range: [0, 360],
              updater: {
                type: ParticleUpdater.CURVE,
                config: [
                  {
                    from: 0,
                    to: 360,
                    startMillis: 0,
                    endMillis: 1500,
                    curve: Curve.EaseIn
                  }
                ]
              }
            },
          },
        ]
      })
        .width('100%').height('100%')
        .emitter(this.emitterProperties)

    }
    .onTouch((event) => {
      if (event.type == TouchType.Down) {
        this.RayCast(event)
        this.touchM.touchDown(event);
        let node = this.sceneManager.sceneNode?.children.get(0);
        if(node){
          this.sceneManager.nodeManager.node = node;
          this.sceneManager.startInfoTrace()
        }
        // this.sceneManager.operateAnimation('球体动作',new AnimOption(AnimationOp.START,undefined,undefined));
        // this.sceneManager.operateAnimation('球体.001动作',new AnimOption(AnimationOp.START,undefined,undefined));

      }else if(event.type == TouchType.Move) {
        this.touchM.touchMove(event);
        if(this.rotateFlag && this.rotateNode && this.sceneManager.cameraManager.cam?.fov){
          let oPos = CalcUtils.SpaceToPlane(this.rotateNode.position,this.sceneManager.cameraManager.cam.fov,this.sceneManager.scaleWH);
          if(this.uiContext){
            let downPos = CalcUtils.pxToNormal({x: this.uiContext.vp2px(this.touchM.down.x),y: this.uiContext.vp2px(this.touchM.down.y)},this.sceneManager.screenWidth,this.sceneManager.screenHeight);
            let tPos = CalcUtils.pxToNormal({x: this.uiContext.vp2px(event.touches[0].x),y: this.uiContext.vp2px(event.touches[0].y)},this.sceneManager.screenWidth,this.sceneManager.screenHeight);
            let oAngle = CalcUtils.calAngle(oPos,downPos);
            let tAngle = CalcUtils.calAngle(oPos,tPos);
            console.info('oPos: ' + oPos.x.toFixed(2) + '/' + oPos.y.toFixed(2) +' | tPos: ' + tPos.x.toFixed(2) + '/' + tPos.y.toFixed(2));
            console.info('oAngle: ' + oAngle + '/ tAngle:' + tAngle);
            // NodeManager.setNodeRotation(this.rotateNode,-tAngle / 2);
            let index = this.sceneManager.animationMap.get('rotate');
            index?.forEach((value,i) => {
              let anim = this.sceneManager.scene?.animations[value];
              anim?.seek(tAngle / (2 * Math.PI));
            })
            let brightNess = tAngle / (2 * Math.PI);
            let windowClass:window.Window = AppStorage.get('windowClass') as window.Window;
            windowClass.setWindowBrightness(brightNess, (err: BusinessError) => {
              const errCode: number = err.code;
              if (errCode) {
                console.error(`Failed to set the brightness. Cause code: ${err.code}, message: ${err.message}`);
                return;
              }
              console.info('Succeeded in setting the brightness.');
            });
          }


        }
        // this.sceneManager.operateAnimation('球体动作', new AnimOption(AnimationOp.SEEK, undefined, this.touchM.distance.y / 200));
        // this.sceneManager.operateAnimation('球体.001动作', new AnimOption(AnimationOp.SEEK, undefined, this.touchM.distance.y / 200));
        console.info('animationSeek Info | percent' + this.touchM.distance.y / 200);
      }else if(event.type == TouchType.Up){
        let index = this.sceneManager.animationMap.get('rotate');
        index?.forEach((value,i) => {
          let anim = this.sceneManager.scene?.animations[value];
          anim?.pause();
        })
        this.rotateFlag = false;
        this.stopDrag();
        this.sceneManager.stopInfoTrace()
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#00ffffff')

  }
}