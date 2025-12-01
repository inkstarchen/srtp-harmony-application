import picker from '@ohos.file.picker';

import { AnimatorResult, matrix4 } from '@kit.ArkUI';
import { BannerClass, BannerDisplay } from '../models/BannerClass';
import { SceneManager } from '../models/SceneManager';
import { Constants } from '../constants/Constants';


@CustomDialog
struct CreateDialog {
  controller?: CustomDialogController;
  @State input_text: string = '';
  @State imageSrc: string | ResourceStr = $r('app.media.background');

  onConfirm: (title: string, imgSrc: string | ResourceStr) => void = () => {};

  build() {
    Column() {
      TextInput({ placeholder: '新建笔记' })
        .onChange((value: string) => {
          this.input_text = value;
        })

      Text('选择想要的封面')
        .fontSize(18)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)

      Image(this.imageSrc)
        .width(100)
        .height(100)
        .margin(10)

      Button('从本地选择')
        .onClick(() => {
          this.selectImage();
        })
        .margin(10)

      Row() {
        Button("取消")
          .onClick(() => {
            this.controller?.close();
          })
          .margin(10)

        Button("确定")
          .onClick(() => {
            this.onConfirm(this.input_text, this.imageSrc);
            this.controller?.close();
          })
          .margin(10)
      }
    }
    .padding(20)
  }

  async selectImage() {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.fileSuffixFilters = ['.jpg', '.jpeg', '.png', '.gif'];
      documentSelectOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker();
      const uris = await documentPicker.select(documentSelectOptions);
      if (uris && uris.length > 0) {
        this.imageSrc = uris[0];
        console.log('选择的图片URI:', this.imageSrc);
      }
    } catch (err) {
      console.error('选择图片失败:', err.code, err.message);
    }
  }
}

@ComponentV2
struct Banner {
  @Local bannerList: BannerClass[] = [
    new BannerClass('1', $r('app.media.background'),'')
  ];
  @Local bannerDisplays: BannerDisplay[] = [];
  translateLastArray: number[] = [0,0,0,0,0]
  @Local currentIndex: number = 0;
  set:boolean = false;
  @Local sceneManager:SceneManager | undefined = undefined;
  @Local title: string = '我们的明天会更好';
  @Local date: string = '九月廿十';
  @Local TextArray: string[] = ['桃树、杏树、梨树，你不让我，我不让你，都开满了花赶趟儿。红的像火，粉的像霞，白的像雪。花里带着甜味儿；闭了眼，树上仿佛已经满是桃儿、杏儿、梨儿。花下成千成百的蜜蜂嗡嗡地闹着，大小的蝴...','不知情权是当今社会的宝贵权利','在行动前，先沉思','智慧产生于独处之中']
  @Local frontOffset: number = -100;
  @Local currentOffset: number = 0;
  @Local nextOffset: number = 100;
  @Local frontScale: number = 0.8;
  @Local currentScale: number = 1;
  @Local nextScale: number = 0.8;
  @Local frontOpacity: number = 0.7;
  @Local currentOpacity: number = 1;
  @Local nextOpacity: number = 0.7;
  @Local index:number = 2;
  @Local perspective: Matrix4Transit | undefined = undefined;
  anim: AnimatorResult | undefined = undefined;
  uiContext: UIContext | undefined = undefined;
  dialogController: CustomDialogController | null = null;
  private autoPlayInterval: number = 0;

  aboutToAppear() {
    if(!this.sceneManager){
      this.sceneManager = new SceneManager(this.getUIContext(),Constants.NewProject);
    }
    this.perspective = matrix4.init([
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0.002,
      0, 0, 0, 1
    ])
    this.uiContext = this.getUIContext();
    this.dialogController = new CustomDialogController({
      builder: CreateDialog({
        onConfirm: (imgSrc: string | ResourceStr) => {
          this.insert_note(imgSrc, '');
        }
      }),
      cancel: () => console.log("关闭弹窗")
    });

    this.init();
    // this.startAutoPlay();
  }

  aboutToDisappear() {
    if (this.autoPlayInterval) {
      clearInterval(this.autoPlayInterval);
    }
  }

  init_bannerDisplay(){
    let banner_temp = this.getDisplayBanners();
    if(this.bannerList.length > 0 && this.bannerDisplays.length == 0){
      this.bannerDisplays.push(new BannerDisplay( 0,banner_temp.Get_next().Get_next()));
      this.bannerDisplays.push(new BannerDisplay(1,banner_temp.Get_next()));
      this.bannerDisplays.push(new BannerDisplay(2, banner_temp));
      this.bannerDisplays.push(new BannerDisplay(1, banner_temp.Get_front()));
      this.bannerDisplays.push(new BannerDisplay(0, banner_temp.Get_front().Get_front()));
      this.bannerDisplays.push(new BannerDisplay(0, banner_temp.Get_front().Get_front().Get_front()));
    }else if(this.bannerDisplays.length > 0){
      const newDisplays = [new BannerDisplay(- 0,banner_temp.Get_next().Get_next())];
      for(let i = 0; i < this.bannerDisplays.length - 1; i++) {
        newDisplays.push(this.bannerDisplays[i]);
      }
      this.bannerDisplays = newDisplays;
    }
  }

  async init(){
    if(!this.uiContext) return;

    this.anim = this.uiContext.createAnimator({
      duration:1000,
      delay:0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    })
    this.anim.onFrame = (progress) => {
      if(!this.set){
        this.set = true;
        this.init_bannerDisplay();
      }
      this.bannerDisplays[this.index].zIndex = (2 - progress) < 1.5 ? 2 : 2;
      this.bannerDisplays[this.index].angle = -60 * progress;
      this.bannerDisplays[this.index + 1].zIndex = (1 - progress) < 0.5 ? 0 : 0;
      this.bannerDisplays[this.index + 1].angle = -60 - 60 * progress;
      this.bannerDisplays[this.index + 2].zIndex = (progress > 0.5) ? 0 : 0;
      this.bannerDisplays[this.index + 2].angle = 0 - 60 * progress;
      this.bannerDisplays[this.index + 3].zIndex = 0;
      this.bannerDisplays[this.index + 3].angle = 180 - 60 * progress;
      this.bannerDisplays[this.index - 1].zIndex = (1 + progress) > 1.5 ? 2 : 2;
      this.bannerDisplays[this.index - 1].angle = 60 - 60 * progress;
      this.bannerDisplays[this.index - 2].zIndex = (progress > 0.5) ? 0 : 0;
      this.bannerDisplays[this.index - 2].angle = 120 - 60 * progress;
      if(progress == 1){
        this.currentIndex = (this.currentIndex + 1) % this.bannerList.length;
        this.set = false;
      }
    }
    let intercalId = setInterval(() => {
      if(this.anim){
        this.anim.play();
      }
    },1500)

  }

  init_test() {
    this.insert_note($r('app.media.notebook'),'');
    this.insert_note($r('app.media.calendar'),'');
  }

  insert_note(imgSrc: string | ResourceStr, url: string): void {

    const newId = `pic${Date.now()}`;
    const newBanner = new BannerClass(newId, imgSrc, url);
    this.bannerList.unshift(newBanner);
    this.rebuildCircularLinks();
    console.log('添加了新Banner:', newBanner);
  }

  private rebuildCircularLinks(): void {
    for (let i = 0; i < this.bannerList.length; i++) {
      const prevIndex = (i - 1 + this.bannerList.length) % this.bannerList.length;
      const nextIndex = (i + 1) % this.bannerList.length;
      this.bannerList[i].Set_front(this.bannerList[prevIndex]);
      this.bannerList[i].Set_next(this.bannerList[nextIndex]);
    }
  }

  getDisplayBanners(): BannerClass {
    if(this.bannerList.length==1) {
      this.init_test();
    }
    return this.bannerList[this.currentIndex];
  }

  build() {
    Stack({alignContent:Alignment.TopStart}) {

      Stack({ alignContent: Alignment.Center }) {
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
            .zIndex(1)
            .position({x:0,y:0})
            .width(this.uiContext?.px2vp(this.sceneManager.screenWidth))
            .height(this.uiContext?.px2vp(this.sceneManager.screenHeight))

          }
          .position({x:0,y:0})
          .zIndex(1)
          .width(this.uiContext?.px2vp(this.sceneManager.screenWidth))
          .height(this.uiContext?.px2vp(this.sceneManager.screenHeight))
        }
        else {
          Text('loading...');
        }
        ForEach(this.bannerDisplays,(Item:BannerDisplay) => {
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
          .height(600)
          .scale({x:0.4,y:0.4})
          // .clip(true)
          .linearGradient({
            direction: GradientDirection.Bottom, // 渐变方向
            repeating: false, // 渐变颜色是否重复
            colors: [['#ffffffff', 0.0], ['#ffe8eef6', 1]] // 数组末尾元素占比小于1时满足重复着色效果
          })
          .border({color:'#00ffffff',width:1,radius:18})
          .shadow({color:'#c4e3e3e3',radius:15,offsetY:10})
          .zIndex(Item.zIndex)
          .transform3D(matrix4.identity()
            .rotate({angle:-Item.angle,y:1,x:0})
            .translate({x:700 * Math.sin(Math.PI * Item.angle / 180),y:200,z:700 - 700 * Math.cos(Math.PI * Item.angle / 180)})
            .combine(this.perspective)
          )
          // Column() {
          //   Image(Item.banner?.imgSrc)
          // }
          // .justifyContent(FlexAlign.Center)
          // .alignItems(HorizontalAlign.Center)
          // .width('50%')
          // .height('80%')
          // .zIndex(Item.zIndex)
          // .transform3D(matrix4.identity()
          //   .rotate({angle:-Item.angle,y:1,x:0})
          //   .translate({x:800 * Math.sin(Math.PI * Item.angle / 180),y:0,z:800 - 800 * Math.cos(Math.PI * Item.angle / 180)})
          //   .combine(this.perspective)
          // )
          // .linearGradient({direction:GradientDirection.RightBottom,
          //   colors:[['#fff',0],['#ffccefff',0.5],['#ff6cceff',1]]})
          // .border({ color: '#00ffffff', width: 1, radius: 18 })
          // .onTouch((event) => {
          //   this.anim?.play();
          // })
        },(translateItem: BannerDisplay) => {
          return translateItem.id.toString();
        })

      }
      .width('100%')
      .height(200)
      .margin({ bottom: 20 })
    }
    .width('100%')
    .height('100%')
  }
}

@Entry
@ComponentV2
export struct DiaryHomePage {
  @Local cardElevation: number = 8;
  @Local quote: string = "生活中只有唯一的英雄主义，\n那就是在认清生活的本质之后依然热爱它";
  @Local currentDate: string = "";

  aboutToAppear() {
    this.updateDate();
  }

  private updateDate() {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const day = now.getDate();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const weekday = weekdays[now.getDay()];

    this.currentDate = `${year}年${month}月${day}日 ${weekday}`;
  }

  build() {
    Column() {
      Text(this.currentDate)
        .fontSize(16)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .padding({ top: 8, bottom: 12 })
        .margin({ top: 8 })
        .width('100%')

      Banner()
        .translate({x:0,y:40})


      Text(this.quote)
        .fontSize(18)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .padding({
          top: 16,
          bottom: 16,
          left: 20,
          right: 20
        })
        .margin({ top: 128 })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .linearGradient({
      direction: GradientDirection.Bottom, // 渐变方向
      repeating: false, // 渐变颜色是否重复
      colors: [['#fffff5fa', 0.0], ['#ffcbdbfd', 1]] // 数组末尾元素占比小于1时满足重复着色效果
    })
  }
}