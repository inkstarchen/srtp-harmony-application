import {matrix4 } from "@kit.ArkUI";
import { BannerState } from "./BannerState";
import { BannerViewModel } from "./BannerViewModel";
import { CreateDialog } from "./Dialog";

@ComponentV2
export struct Banner {
  uiContext: UIContext | undefined = undefined;
  @Local viewModel: BannerViewModel = new BannerViewModel(this.getUIContext());
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

  @Local perspective: Matrix4Transit | undefined = undefined;


  dialogController: CustomDialogController | null = null;

  aboutToAppear() {
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
          this.viewModel.insert_note(50);
        }
      }),
      cancel: () => console.log("关闭弹窗")
    });
    this.viewModel.init_test();
  }

  aboutToDisappear() {
  }
  build() {
    Stack({alignContent:Alignment.TopStart}) {

      Stack({ alignContent: Alignment.Center }) {
        ForEach(this.viewModel.bannerList,(Item:BannerState) => {
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
              .width(40)
            Text(this.date)
              .fontColor('#ff8e8f9f')
              .fontWeight(600)
              .fontSize(20)
              .position({x:90, y:200})
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
        },(item: BannerState) => {
          return item.id.toString();
        })

      }
      .width('100%')
      .height(200)
      .margin({ bottom: 20 })
    }
    .onClick(() => {
      this.getUIContext().getPromptAction().showToast({message:"length is " + this.viewModel.bannerList.length.toString()});
    })
    .width('100%')
    .height('100%')
  }
}

