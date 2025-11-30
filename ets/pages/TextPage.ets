import {CalendarPage} from './CalendarPage'
import { AnimatorResult, componentUtils, LengthMetrics, LengthMetricsUnit, matrix4, router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { PreferencesUtil } from '../utils/PreferencesUtil';
import { display,  window } from '@kit.ArkUI';
import { touchManager, TraceString} from '../models/BaseClass';
import { SceneManager } from '../models/SceneManager';
import { CalcUtils } from '../utils/calutils';
import { Vec2, Vec3 } from '@kit.ArkGraphics3D';
import { Constants } from '../constants/Constants';

// ListDataSource.ets
class ListDataSource implements IDataSource {
  private list: number[] = [];
  private listeners: DataChangeListener[] = [];

  constructor(list: number[]) {
    this.list = list;
  }

  totalCount(): number {
    return this.list.length;
  }

  getData(index: number): number {
    return this.list[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  // 通知控制器数据删除
  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }

  // 通知控制器添加数据
  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  // 在指定索引位置删除一个元素
  public deleteItem(index: number): void {
    this.list.splice(index, 1);
    this.notifyDataDelete(index);
  }

  // 在指定索引位置插入一个元素
  public insertItem(index: number, data: number): void {
    this.list.splice(index, 0, data);
    this.notifyDataAdd(index);
  }
}

@Entry
@ComponentV2
export struct TextPage{
  initFlag: boolean = false;
  screenSize: Size | undefined = undefined;
  uiContext:UIContext | undefined = undefined;
  @Local touchM:touchManager = new touchManager(0)
  @Local lightAngle: number = 0;
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
  @Local ScreenSize?:Size;
  @Local Text: string[] = ['1','2','3','4'];
  private arr: ListDataSource = new ListDataSource([0, 1, 2]);

  onPageShow(): void {

    if(!this.sceneManager){
      this.sceneManager = new SceneManager(this.getUIContext(),Constants.default);
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

  onPageHide(): void {

  }

  CalLight(){
    const info = this.getUIContext().getComponentUtils().getRectangleById('1')
    console.info('屏幕坐标' + info.screenOffset.x + '/' + info.screenOffset.y);
    let pos = this.sceneManager?.cameraManager.Position2to3_px({x:info.screenOffset.x, y:info.screenOffset.y}) as Vec3;
    console.info('屏幕3D坐标' + pos.x + '/' + pos.y + '/' + pos.z);
    let angle = CalcUtils.calAngle({x:info.screenOffset.x, y:info.screenOffset.y},this.sceneManager?.cameraManager.Position3to2(this.sceneManager.lightManager.light?.position as Vec3) as Vec2);
    console.info('屏幕angle:' + angle);
    this.lightAngle = angle;

    let vColor: Vec3 = {x:255,y:255,z:255} as Vec3;
    this.linearColor = []

    this.linearColor.push([CalcUtils.Vec3ToColor(vColor),0.0])

    this.linearColor.push([CalcUtils.Vec3ToColor(CalcUtils.Vec3Mul(vColor,0.95)),1.0]);
  }

  async init(){
    this.uiContext = this.getUIContext();
    let DisplaySync = display.getDefaultDisplaySync()
    this.screenSize = { width:DisplaySync.width,  height:DisplaySync.height }
    let Window =  window.getLastWindow(this.uiContext.getHostContext())
    this.initFlag = !this.initFlag
  }

  aboutToAppear(): void {

    this.uiContext = this.getUIContext();
    this.ScreenSize = PreferencesUtil.getScreenData();
  }

  build() {
    Stack({alignContent:Alignment.TopStart}) {

      Column(){

        List({space: 20, initialIndex: 0}) {
          ListItem(){
            Column(){

            }

            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
            .height('10%')
            .width('100%')
            .backgroundColor('#00ffffff')
          }
          LazyForEach(this.arr, (item:number) => {
            ListItem(){
              Column() {
                Text('今天天气真好，最适合运动了,让我多打一点字看看')
                  .lineSpacing(LengthMetrics.vp(8))
                  .alignSelf(ItemAlign.Start)
              }
              .justifyContent(FlexAlign.Start)
              .padding(10)
              // .backgroundColor(Color.White)
              .linearGradient({angle: this.lightAngle * 180 / Math.PI - 90,
                colors:this.linearColor})
              .shadow({color:'#2d8c8c8c',radius:10,
                offsetX:20 * Math.sin(this.lightAngle - Math.PI / 2),
                offsetY:20 * Math.cos(this.lightAngle + Math.PI / 2)
              })
              .id(item.toString())
              .width('100%')
              .constraintSize({ maxWidth: '100%' }) // 关键约束
              .height(LayoutPolicy.wrapContent)
              .margin({left:30,right:30})
              .padding({left:20,right:20,top:20,bottom:20})
              // .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
              .border({
                width: 1,
                color: '#EEEEEE',
                radius: 8
              })
            }
          })
          ListItem(){
            Column() {
              Image($r("app.media.plus"))
                .width(40)
                .height(40)
            }
            .justifyContent(FlexAlign.Start)
            .padding(10)
            // .backgroundColor(Color.White)
            .linearGradient({angle: this.lightAngle * 180 / Math.PI - 90,
              colors:this.linearColor})
            .shadow({color:'#2d8c8c8c',radius:10,
              offsetX:8 * Math.sin(this.lightAngle - Math.PI / 2),
              offsetY:8 * Math.cos(this.lightAngle + Math.PI / 2)
            })
            .width('100%')
            .constraintSize({ maxWidth: '100%' }) // 关键约束
            .height(LayoutPolicy.wrapContent)
            .margin({left:30,right:30})
            .padding({left:20,right:20,top:10,bottom:10})
            // .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
            .border({
              width: 1,
              color: '#EEEEEE',
              radius: 8
            })
            .onClick(() => {
              this.arr.insertItem(1,10);
            })
          }
          ListItem(){
            Column() {
            }
            .justifyContent(FlexAlign.Start)
            .padding(10)
            .backgroundColor("#00ffffff")
            .width('100%')
            .constraintSize({ maxWidth: '100%' }) // 关键约束
            .height(60)
            .margin({left:30,right:30})
            .padding({left:20,right:20,top:10,bottom:10})
          }
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .listDirection(Axis.Vertical)
        .scrollBar(BarState.Off)
        .friction(0.6)
        .width('90%')
        .height("100%")
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      Column(){

      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .width('100%')
      .height('8%')
      .shadow({color:'#2d8c8c8c',radius:10,offsetX:8,offsetY:8})
      .backgroundColor('#fff')
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
      if (this.sceneManager?.sceneOption) {
        Stack() {
          Column(){
            Component3D(this.sceneManager?.sceneOption)
              .renderWidth('100%')
              .renderHeight('100%')

          }
          .position({x:0,y:0})
          .width(this.uiContext?.px2vp(this.sceneManager.screenWidth))
          .height(this.uiContext?.px2vp(this.sceneManager.screenHeight))

        }
        .position({x:0,y:0})
        .hitTestBehavior(HitTestMode.BLOCK_DESCENDANTS)
        .width(this.uiContext?.px2vp(this.sceneManager.screenWidth))
        .height(this.uiContext?.px2vp(this.sceneManager.screenHeight))
      }
      else {
        Text('loading...');
      }
    }
    .onTouch((event) => {
      this.sceneManager?.HandleTouch(event);
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
        this.CalLight();
        this.touchM.touchMove(event)
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
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .linearGradient({colors:[['#ff97dffd',0.0],['#ff9adafc',1.0]],direction:GradientDirection.LeftBottom})
    .width('100%')
    .height('100%')
  }
}