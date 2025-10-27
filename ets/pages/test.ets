import { AnimatorResult, display, window } from '@kit.ArkUI';
import { touchManager, TraceString, TraceVec2 } from '../CanvasClass/ClassUtils';
import { CalcUtils } from '../utils/calutils';

@Entry
@ComponentV2
struct Test{
  initFlag: boolean = false;
  @Local translateArray: TraceString[] = [new TraceString(-800),new TraceString(0),new TraceString(800)];
  @Local TextArray: string[] = ['休息是宝贵的时间，不要让娱乐占据它','不知情权是当今社会的宝贵权利','在行动前，先沉思','智慧产生于独处之中']
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
  index:number = 1;
  set:boolean = false;
  set2:boolean = false;

  @Local anim:AnimatorResult | undefined = undefined;
  @Local scaleAnim:AnimatorResult | undefined = undefined;
  onPageShow(): void {
    if(!this.initFlag){
      this.init();
    }
  }

  async init(){
    this.uiContext = this.getUIContext();
    let DisplaySync = display.getDefaultDisplaySync()
    this.screenSize = { width:DisplaySync.width,  height:DisplaySync.height }
    let Window =  window.getLastWindow(this.uiContext.getHostContext())
    this.anim = this.uiContext.createAnimator({
      duration:500,
      delay:0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    })
    this.scaleAnim = this.uiContext.createAnimator({
      duration:500,
      delay:0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-in-out',
      begin:0,
      end:1,
      iterations:1
    })
    this.scaleAnim?.reverse()
    for(let i = 0 ; i < 3; i++){
      this.translateArray[i].text = this.TextArray[i]
    }
    this.scaleAnim.onFrame = (progress) => {
      if(!this.set2){
        this.set2 = !this.set2
      }
      if(progress <= 0.5){
        this.translateArray[this.index].scaleV = 1 - progress * 1.5
      }else{
        this.translateArray[this.index].scaleV = 0.25 + (progress - 0.5) * 2.5;
      }
    }
    this.scaleAnim.onFinish = () => {
      this.set2 = false;
      if(this.fullscreen){
        this.fullscreen = !this.fullscreen
      }
    }
    this.anim.onFrame = (progress) => {
      if(!this.set){
        this.set = true;
        this.translateLastArray[0] = this.translateArray[0].x
        this.translateLastArray[1] = this.translateArray[1].x
        this.translateLastArray[2] = this.translateArray[2].x
        if(this.touchM.distance.x < -400 || (this.speed > 1000 && Math.abs(this.angle) > 130)){
          this.right = (this.right + 1) % this.TextArray.length;
          this.left = (this.left + 1) % this.TextArray.length;

        }
        else if(this.touchM.distance.x > 400 || (this.speed > 1000 && Math.abs(this.angle) <= 50)){
          this.left = (this.left - 1 < 0) ? this.TextArray.length - 1 : this.left - 1;
          this.right = (this.right - 1 < 0) ? this.TextArray.length - 1: this.right - 1;
        }
      }
      if(this.touchM.distance.x < -400 || (this.speed > 1000 && Math.abs(this.angle) > 130)){

        this.translateArray[this.index].x = this.translateLastArray[this.index] + progress * (-800 - this.translateLastArray[this.index]);
        let index_1 = this.index - 1 < 0 ? this.index + 2:this.index - 1;
        this.translateArray[index_1].x = 800
        this.translateArray[index_1].text = this.TextArray[this.right]
        this.translateArray[(this.index + 1) % 3].x = (1 - progress) * this.translateLastArray[(this.index + 1) % 3]
      }else if(this.touchM.distance.x > 400 || (this.speed > 1000 && Math.abs(this.angle) <= 50)){

        this.translateArray[this.index].x = this.translateLastArray[this.index] + progress * (800 - this.translateLastArray[this.index]);
        let index_1 = this.index - 1 < 0 ? this.index + 2:this.index - 1;
        this.translateArray[index_1].x = (1- progress) * this.translateLastArray[index_1]
        this.translateArray[(this.index + 1) % 3].x = -800
        this.translateArray[(this.index + 1) % 3].text = this.TextArray[this.left];
      }else{
        this.translateArray[this.index].x = (1-progress) * this.translateLastArray[this.index];
        let index_1 = this.index - 1 < 0 ? this.index + 2:this.index - 1;
        this.translateArray[index_1].x = this.translateLastArray[index_1] + progress *(-800 - this.translateLastArray[index_1])
        this.translateArray[(this.index + 1) % 3].x = this.translateLastArray[(this.index + 1) % 3] + progress * (800 - this.translateLastArray[(this.index + 1) % 3])
      }
      if(progress == 1){
        this.speed = 0;
        this.set = false;
      }
    }
    this.initFlag = !this.initFlag

  }


  build() {
    Stack(){
      ForEach(this.translateArray,(translateItem:TraceString,index:number) => {
        Column(){
          Text(translateItem.text)
            .fontColor('#ff1a2747')
            .fontWeight(600)
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width('80%')
        .height('80%')
        .translate(translateItem)
        .scale({x:translateItem.scaleV,y:translateItem.scaleV})
        .backgroundColor('#fff')
        // .linearGradient({direction:GradientDirection.RightBottom,
        //   colors:[['#fff',0],['#ffccefff',0.5],['#ff6cceff',1]]})
        .border({color:'#00ffffff',width:1,radius:18})
        .shadow({color:'#c4e3e3e3',radius:15,offsetY:10})
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
        .onTouch((event) => {
          if(this.set || this.set2) return;
          if(event.type == TouchType.Down){
            this.index = index;
            this.touchM.touchDown(event)
            this.touchTime = event.timestamp;
          }else if(event.type == TouchType.Move){
            if(event.timestamp - this.touchTime > 250000000){
              this.longPress = true;
            }
            if(!this.fullscreen){
              this.touchM.touchMove(event);
              this.translateArray[index].x = this.touchM.distance.x
              let index_1 = index - 1 < 0 ? index + 2:index - 1;
              this.translateArray[index_1].x = -800 + this.touchM.distance.x;
              this.translateArray[(index + 1) % 3].x = 800 + this.touchM.distance.x;
            }
          }else if(event.type == TouchType.Up){
            if(CalcUtils.calDistance({x:event.touches[0].x,y:event.touches[0].y},this.touchM.down) < 10 && !this.longPress){
              this.scaleAnim?.reverse()
              this.scaleAnim?.play()
              if(!this.fullscreen){
                this.fullscreen = !this.fullscreen

              }
            }
            this.longPress = false;
            if(!this.fullscreen){
              this.anim?.play()
            }
          }
        })
      })



    }
    .width('100%')
    .height('100%')
    .backgroundColor('#fff')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .linearGradient({
      direction: GradientDirection.Bottom, // 渐变方向
      repeating: false, // 渐变颜色是否重复
      colors: [['#fffff5fa', 0.0], ['#ffcbdbfd', 1]] // 数组末尾元素占比小于1时满足重复着色效果
    })
  }
}