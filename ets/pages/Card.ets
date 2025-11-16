import { AnimatorResult, display, window } from '@kit.ArkUI';
import { touchManager, TraceString} from '../models/BaseClass';
import { CalcUtils } from '../utils/calutils';
import { matrix4 } from '@kit.ArkUI';
import {image} from '@kit.ImageKit'

@ObservedV2
class vCamera{
  @Trace x: number = 0;
  @Trace y: number = 0;
  @Trace z: number = 0;
  @Trace PlaneZ: number = 10;

  forward(){
    this.z += 0.2;
  }

  backward(){
    this.z -= 0.2;
  }
}

@ObservedV2
class Object2D{
  @Trace scaleV:number = 1;
  @Trace positionX:number = 200;
  @Trace positionY:number = 300;
  @Trace positionZ:number = 10;
  step: number = 0.01;
  increase(){
    this.scaleV += this.step;
  }

  decrease(){
    this.scaleV -= this.step;
  }
}

@Entry
@ComponentV2
struct Test{
  initFlag: boolean = false;
  @Local dynamicWidth:number = 40;
  @Local dynamicHeight: number = 40;
  @Local virtualCamera:vCamera = new vCamera();
  @Local testObject:Object2D = new Object2D();
  @Local title: string = '我们的明天会更好';
  @Local date: string = '九月廿十';
  @Local TextArray: string[] = ['桃树、杏树、梨树，你不让我，我不让你，都开满了花赶趟儿。红的像火，粉的像霞，白的像雪。花里带着甜味儿；闭了眼，树上仿佛已经满是桃儿、杏儿、梨儿。花下成千成百的蜜蜂嗡嗡地闹着，大小的蝴...','不知情权是当今社会的宝贵权利','在行动前，先沉思','智慧产生于独处之中']
  @Local translateArray: TraceString[] = [new TraceString(-800),new TraceString(0),new TraceString(800)];

  translateLastArray: number[] = [0,0,0]
  screenSize: Size | undefined = undefined;
  uiContext:UIContext | undefined = undefined;
  fullscreen:boolean = false;
  longPress:boolean = false;
  touchTime: number = 0
  @Local left: number = 0;
  @Local right: number = 2;
  @Local count:number = 1;
  @Local touchM:touchManager = new touchManager(0)
  @Local speed:number = 0;
  @Local angle:number = 0;

  @Local theta:number = 50;
  index:number = 1;
  set:boolean = false;
  set2:boolean = false;
  @Local pixMap: image.PixelMap | undefined = undefined;

  @Local anim:AnimatorResult | undefined = undefined;
  @Local scaleAnim:AnimatorResult | undefined = undefined;
  @Local matrix: Matrix4Transit | undefined = undefined;
  @Local perspective: Matrix4Transit | undefined = undefined;

  onPageShow(): void {
    if(!this.initFlag){
      this.init();
    }
  }

  async init(){
    let fov = Math.PI * 90 / 180;
    let aspect = 0.5;
    let theta = 50;
    let farPlane = 200;
    let nearPlane = 20;
    this.perspective = matrix4.init([
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0.001,
      0, 0, 0, 1
    ])
    this.matrix = matrix4.init([
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1
    ])
    // this.matrix.scale({x:1,y:1,z:1})
    this.matrix.rotate({angle:theta,y:0,x:1})
    this.matrix.translate({x:0,y:400 * Math.sin(Math.PI * theta / 180),z:400 * (1-Math.cos(Math.PI * theta / 180))})
    this.matrix.combine(this.perspective);
    this.uiContext = this.getUIContext();
    // let DisplaySync = display.getDefaultDisplaySync()
    // this.screenSize = { width:DisplaySync.width,  height:DisplaySync.height }
    let Window =  window.getLastWindow(this.uiContext.getHostContext())
    this.anim = this.uiContext.createAnimator({
      duration:18000,
      delay:0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    })
    this.scaleAnim = this.uiContext.createAnimator({
      duration:1500,
      delay:0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-in-out',
      begin:0,
      end:1,
      iterations:1
    })
    this.anim.onFrame = (progress) => {
      // this.virtualCamera.z = -progress *
      this.theta = 360 * progress;
      let fov = Math.PI * 90 / 180;
      let aspect = 0.5;
      let farPlane = 200;
      let nearPlane = 20;
      this.perspective = matrix4.init([
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0.002,
        0, 0, 0, 1
      ])
      this.matrix = matrix4.identity();
      // this.matrix.scale({x:1,y:1,z:1})
      this.matrix.rotate({angle:-this.theta,y:1,x:0})
      this.matrix.translate({x:800 * Math.sin(Math.PI * this.theta / 180),y:0,z:800 - 800 * Math.cos(Math.PI * this.theta / 180)})
      this.matrix.combine(this.perspective);
    }
    this.scaleAnim.onFrame = (progress) =>{
      // this.virtualCamera.z = -20 + 30 * progress;
    }
    this.anim.play();
    this.anim.onFinish = () =>{
      this.anim?.finish();
      this.anim?.play();
    }
  }


  build() {

    Stack(){
      Stack(){
          Stack(){
            Column(){}
            .position({x:30,y:20})
            .width(90)
            .height(340)
            .border({width:1,color:'#8adedede',radius:'25px'})
            .backgroundColor('#0ae3dfdf')
            .shadow({radius:15,offsetX:10,offsetY:5,color:'#8adedede'})

            Text(this.title)
              .fontColor('#ff1a2747')
              .fontWeight(600)
              .fontSize(30)
              .position({x:50, y:40})
              // .backgroundColor('#60d9d9d9')
              // .height(200)
              .width(40)
            Text(this.date)
              .fontColor('#ff8e8f9f')
              .fontWeight(600)
              .fontSize(20)
              .position({x:90, y:200})
              // .backgroundColor('#60d9d9d9')
              // .height(200)
              .width(30)
            Text(this.TextArray[0])
              .textIndent(30)
              .fontSize(15)
              .width(120)
              .height(280)
              .maxLines(10)
              .textOverflow({overflow:TextOverflow.Ellipsis})
              .fontColor('#901a2747')
              .lineSpacing({value:8,unit:1})
              .position({x:140,y:260})
              .fontWeight(600)
            Column(){

            }
            .linearGradient({
              direction: GradientDirection.Bottom, // 渐变方向
              repeating: false, // 渐变颜色是否重复
              colors: [['#00ffffff', 0.0],['#00ffffff', 0.7], ['#fde8eef6', 1]] // 数组末尾元素占比小于1时满足重复着色效果
            })
            .width(120)
            .height(260)
            .position({x:140,y:260})
          }
          .width('80%')
          .height('80%')
          .scale({x:0.5,y:0.5})
          .clip(true)
          .linearGradient({
            direction: GradientDirection.Bottom, // 渐变方向
            repeating: false, // 渐变颜色是否重复
            colors: [['#ffffffff', 0.0], ['#ffe8eef6', 1]] // 数组末尾元素占比小于1时满足重复着色效果
          })
          .border({color:'#00ffffff',width:1,radius:18})
          .shadow({color:'#c4e3e3e3',radius:15,offsetY:10})
          .transform3D(this.matrix)
          .gesture(
            SwipeGesture({ direction: SwipeDirection.Horizontal })
              .onAction((event: GestureEvent) => {
                if (event) {
                  this.speed = event.speed
                  this.angle = event.angle
                  this.uiContext?.getPromptAction().showToast({message:'speed ' + this.speed + '/' + event.angle})
                }
              })
          )
      }
      .width('100%')
      .height('100%')
      .id('main')
      .onClick(() => {

        this.dynamicWidth = this.dynamicWidth == 300? 40 : 300;
        this.dynamicHeight = this.dynamicHeight == 600? 40 : 600;
      })
      // .onClick(() => {
      //   let snapShot = this.getUIContext().getComponentSnapshot();
      //   snapShot.get('main', { scale: 0.8, waitUntilRenderFinished: true })
      //     .then((pixMap: image.PixelMap) => {
      //       // 用pixMap方式，同时可以对比测试
      //       this.pixMap = pixMap;
      //
      //       this.getUIContext()?.getPromptAction().showToast({message:'截图成果'});
      //     })
      //     .catch((err: Error) => {
      //       console.error(`截图失败：${err}`);
      //     });
      // })
      .backgroundColor('#fff')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .linearGradient({
        direction: GradientDirection.Bottom, // 渐变方向
        repeating: false, // 渐变颜色是否重复
        colors: [['#fffff5fa', 0.0], ['#ffcbdbfd', 1]] // 数组末尾元素占比小于1时满足重复着色效果
      })

      .onTouch((event) => {
        this.theta += 1;
        if(this.theta >= 90) this.theta = 0;

        if(event.type == TouchType.Up){
          if(event.touches[0].y > 500){
            this.anim?.play();
            // this.virtualCamera.forward();
          }else{
            this.scaleAnim?.play();
            // this.virtualCamera.backward();
          }
        }
      })

    }

  }
}