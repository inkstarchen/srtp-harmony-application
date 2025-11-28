import { AnimatorResult, display, matrix4, window } from '@kit.ArkUI';
import { touchManager, TraceString} from '../models/BaseClass';
import { SceneManager } from '../models/SceneManager';
import { CalcUtils } from '../utils/calutils';
import { Vec3 } from '@kit.ArkGraphics3D';


@Entry
@ComponentV2
struct LightTest{
  initFlag: boolean = false;
  screenSize: Size | undefined = undefined;
  uiContext:UIContext | undefined = undefined;
  @Local touchM:touchManager = new touchManager(0)

  @Local command:string = '';
  @Local command2:string = '';
  animPoint:AnimatorResult | undefined = undefined;
  @Local anglePoint:number = 0;

  touchDownX:number = 0;
  touchDownY:number = 0;
  downFlag:boolean = false;
  @Local linearColor: Array<[string,number]> = []

  @Local sceneManager:SceneManager | undefined = undefined;

  @Local anim:AnimatorResult | undefined = undefined;
  @Local scaleAnim:AnimatorResult | undefined = undefined;

  onPageShow(): void {

    if(!this.sceneManager){
      this.sceneManager = new SceneManager(this.getUIContext());
    }
    if(!this.initFlag){
      this.init();
    }
    if(!this.uiContext){
      this.uiContext = this.getUIContext()
    }
    if(!this.animPoint){
      this.animPoint = this.uiContext.createAnimator({
        duration:500,
        delay:0,
        fill:'forwards',
        direction:'normal',
        easing:'ease-in-out',
        iterations:1,
        begin:0,
        end:1
      })
      this.animPoint?.reverse()
      this.animPoint.onFrame = (progress:number) => {
        if(!this.uiContext) return
        this.anglePoint = progress * 359;
        this.command = ''
        this.command += 'M' + this.touchDownX.toFixed(0)  + ' ' + (this.touchDownY + 130).toFixed(0) ;
        if(this.anglePoint > 180){
          this.command += ' A130 130 0 1 1 ' ;
        }else{
          this.command += ' A130 130 0 0 1 ' ;
        }

        this.command += (this.touchDownX - Math.sin(Math.PI * this.anglePoint / 180) * 130 ).toFixed(0) + ' ' + (this.touchDownY + Math.cos(Math.PI * this.anglePoint / 180) * 130).toFixed(0);
        if(progress == 0 ){
          this.command = ''
        }

      }
    }
  }

  async init(){
    this.uiContext = this.getUIContext();
    let DisplaySync = display.getDefaultDisplaySync()
    this.screenSize = { width:DisplaySync.width,  height:DisplaySync.height }
    let Window =  window.getLastWindow(this.uiContext.getHostContext())
    this.initFlag = !this.initFlag
  }


  build() {
    Stack(){
      if (this.sceneManager?.sceneOption) {
        Stack() {
          Column(){
            Component3D(this.sceneManager?.sceneOption)
              .renderWidth('100%')
              .renderHeight('100%')
              .onTouch((event) => {
                this.sceneManager?.HandleTouch(event);
              })

          }
          .position({x:0,y:0})
          .width(this.uiContext?.px2vp(this.sceneManager.screenWidth))
          .height(this.uiContext?.px2vp(this.sceneManager.screenHeight))

        }
        .position({x:0,y:0})
        .width(this.uiContext?.px2vp(this.sceneManager.screenWidth))
        .height(this.uiContext?.px2vp(this.sceneManager.screenHeight))
      }
      else {
        Text('loading...');
      }
      Column(){
        Text('Test Text')
          .fontColor('#ff1a2747')
          .fontWeight(600)
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width('80%')
      .height('20%')
      .transform3D(matrix4.identity().translate({y:400}))
      .linearGradient({angle: this.touchM.angle * 180 / Math.PI - 90,
        colors:this.linearColor})
      .shadow({color: '#51676767',radius:20,
        offsetX:20 * Math.sin(this.touchM.angle - Math.PI / 2),
        offsetY:20 * Math.cos(this.touchM.angle + Math.PI / 2)
      })

      Path()
        .width('210px')
        .height('310px')
        .commands(this.command)
        .fillOpacity(0)
        .strokeLineCap(LineCapStyle.Round)
        .stroke('#f30caef3')
        .strokeWidth(5)
        .position({x:0,y:0})
      Path()
        .width('210px')
        .height('310px')
        .commands(this.command2)
        .fillOpacity(0.5)
        .fill('#ffababab')
        .strokeLineCap(LineCapStyle.Round)
        .stroke('#f3cdcdcd')
        .strokeWidth(1)
        .position({x:0,y:0})

    }
    .onTouch((event) => {
      let len = event.touches.length;
      // this.touchInfo = ''
      // for(let i = 0 ; i < event.touches.length; i++){
      //   this.touchInfo += event.touches[i].type == TouchType.Down ? 'Down' : (event.touches[i].type == TouchType.Move ? 'Move' : 'UP');
      //   this.touchInfo += ' ' + event.touches[i].x + '/' + event.touches[i].y + '\n';
      // }
      if(!this.uiContext) return;
      if(event.touches[0].type == TouchType.Down){
        this.touchM.touchDown(event)
        if(this.downFlag == false){
          this.getUIContext().getPromptAction().showToast({message:'Down'})
          this.downFlag = true;
          this.touchDownX = this.uiContext.vp2px(event.touches[0].x)
          this.touchDownY = this.uiContext.vp2px(event.touches[0].y)
          this.animPoint?.reverse()
          this.animPoint?.play()
        }
      }else if(event.touches[0].type == TouchType.Move) {
        this.touchM.touchMove(event)
        if(this.sceneManager?.lightManager.light?.color){
          this.sceneManager.lightManager.light.color = {
            r:Math.abs(Math.cos(this.touchM.angle)),
            g:Math.abs(Math.sin(this.touchM.angle) * Math.sin(this.touchM.angle)),
            b:Math.abs(Math.sin(this.touchM.angle) * Math.cos(this.touchM.angle)),
            a:1.0};
        }
        let lightColor = this.sceneManager?.lightManager.light?.color;

        // if(lightColor){
        //   console.info('testLightColor: ' + lightColor.r + '/' + lightColor.a);
        //   vColor.x = vColor.x * lightColor.r;
        //   vColor.y = vColor.y * lightColor.g;
        //   vColor.z = vColor.z * lightColor.b;
        // }
        // console.info('linearColor: ' + vColor.x + '/' + vColor.y + '/' + vColor.z);
        let vColor: Vec3 = {x:220,y:242,z:253} as Vec3;
        this.linearColor = []

        this.linearColor.push([CalcUtils.Vec3ToColor(vColor),0.0])

        this.linearColor.push([CalcUtils.Vec3ToColor(CalcUtils.Vec3Mul(vColor,0.80)),1.0]);
        this.sceneManager?.LightRotate(this.touchM.angle);
        this.uiContext.getPromptAction().showToast({message:'angle' + this.touchM.angle})
        this.command2 = '';
        this.command2 += 'M' + this.touchDownX.toFixed(0) + ' ' + (this.touchDownY - 70).toFixed(0);
        this.command2 += ' A70 70 0 1 1 ' ;
        this.command2 += (this.touchDownX + Math.sin(Math.PI * 359 / 180) * 70).toFixed(0) + ' ' + (this.touchDownY - Math.cos(Math.PI * 359 / 180) * 70).toFixed(0) + 'Z';
        this.command2 += 'M' + this.touchDownX.toFixed(0) + ' '  + this.touchDownY.toFixed(0)
        this.command2 += ' L' + (this.uiContext.vp2px(event.touches[0].x)).toFixed(0) + ' ' + (this.uiContext.vp2px(event.touches[0].y)).toFixed(0);

      }else if(event.touches.length == 1 && event.type == TouchType.Up){
        this.downFlag = false;
        this.animPoint?.reverse()
        this.command2 = ''
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#fff')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}