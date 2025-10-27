import { AnimatorResult } from '@kit.ArkUI';

@Entry
@ComponentV2
struct GraphicsController{

  uiContext:UIContext | undefined = undefined
  @Local command:string = '';
  @Local command2:string = '';
  anim:AnimatorResult | undefined = undefined;
  @Local angle:number = 0;
  touchDownX:number = 0;
  touchDownY:number = 0;
  @Local touchInfo:string = '';
  downFlag:boolean = false;
  onPageShow(): void {
    if(!this.uiContext){
      this.uiContext = this.getUIContext()
    }
    if(!this.anim){
      this.anim = this.uiContext.createAnimator({
        duration:500,
        delay:0,
        fill:'forwards',
        direction:'normal',
        easing:'ease-in-out',
        iterations:1,
        begin:0,
        end:1
      })
      this.anim?.reverse()
      this.anim.onFrame = (progress:number) => {
        if(!this.uiContext) return
        this.angle = progress * 359;
        this.command = ''
        this.command += 'M' + this.touchDownX.toFixed(0)  + ' ' + (this.touchDownY + 130).toFixed(0) ;
        if(this.angle > 180){
          this.command += ' A130 130 0 1 1 ' ;
        }else{
          this.command += ' A130 130 0 0 1 ' ;
        }

        this.command += (this.touchDownX - Math.sin(Math.PI * this.angle / 180) * 130 ).toFixed(0) + ' ' + (this.touchDownY + Math.cos(Math.PI * this.angle / 180) * 130).toFixed(0);
        if(progress == 0 ){
          this.command = ''
        }

      }
    }
  }

  build() {

    Stack(){
      Text(this.touchInfo);
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
      this.touchInfo = ''
      for(let i = 0 ; i < event.touches.length; i++){
        this.touchInfo += event.touches[i].type == TouchType.Down ? 'Down' : (event.touches[i].type == TouchType.Move ? 'Move' : 'UP');
        this.touchInfo += ' ' + event.touches[i].x + '/' + event.touches[i].y + '\n';
      }
      if(!this.uiContext) return;
      if(event.touches[0].type == TouchType.Down){
        if(this.downFlag == false){
          this.getUIContext().getPromptAction().showToast({message:'Down'})
          this.downFlag = true;
          this.touchDownX = this.uiContext.vp2px(event.touches[0].x)
          this.touchDownY = this.uiContext.vp2px(event.touches[0].y)
          this.anim?.reverse()
          this.anim?.play()
        }
      }else if(event.touches[0].type == TouchType.Move) {
        this.command2 = '';
        this.command2 += 'M' + this.touchDownX.toFixed(0) + ' ' + (this.touchDownY - 70).toFixed(0);
        this.command2 += ' A70 70 0 1 1 ' ;
        this.command2 += (this.touchDownX + Math.sin(Math.PI * 359 / 180) * 70).toFixed(0) + ' ' + (this.touchDownY - Math.cos(Math.PI * 359 / 180) * 70).toFixed(0) + 'Z';
        this.command2 += 'M' + this.touchDownX.toFixed(0) + ' '  + this.touchDownY.toFixed(0)
        this.command2 += ' L' + (this.uiContext.vp2px(event.touches[0].x)).toFixed(0) + ' ' + (this.uiContext.vp2px(event.touches[0].y)).toFixed(0);
      }else if(event.touches.length == 1 && event.type == TouchType.Up){
        this.getUIContext().getPromptAction().showToast({message:'UP'})
        this.downFlag = false;
        this.anim?.reverse()
        this.command2 = ''
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#fff')
  }
}