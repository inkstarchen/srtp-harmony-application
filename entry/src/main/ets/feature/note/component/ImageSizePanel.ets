import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

// 图片尺寸调整面板组件
@ComponentV2
export struct ImageSizePanel {
  @Param Width: number = 425;
  @Param Height: number = 325;
  @Param lockAspectRatio: boolean = true;
  private AspectRatio: number = 425 / 325;
  private onStart: number = 0;
  private onEnd: number = 0;
  @Event onWidthChange?: (value: number) => void;
  @Event onHeightChange?: (value: number) => void;
  @Event onLockChange?: (value: boolean) => void;
  @Event onConfirm?: () => void;
  @Event onCancel?: () => void;

  aboutToAppear() {
    this.AspectRatio = this.Width / this.Height;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('调整图片尺寸')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        
        Blank()
        
        // 关闭按钮
        Button() {
          Image($r('app.media.xmark'))
            .width(24)
            .height(24)
            .fillColor(Color.Gray)
        }
        .type(ButtonType.Circle)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.onCancel) {
            this.onCancel();
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Divider()

      // 尺寸调整区域
      Column({ space: 20 }) {
        // 宽度滑块
        Column({ space: 8 }) {
          Row() {
            Text('宽度')
              .fontSize(14)
              .fontColor(Color.Gray)
              .width(60)
            
            Text(`${this.Width}px`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          
          Slider({
            value: this.Width,
            min: 100,
            max: 800,
            step: 10
          })
            .blockColor('#007AFF')
            .onChange((value: number) => {
              if (this.onHeightChange && this.lockAspectRatio) {
                let height = Math.round(value / this.AspectRatio);
                this.onHeightChange(height);
              }
              if (this.onWidthChange) {
                this.onWidthChange(value);
              }
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Up) {
                // 拖动结束后确保尺寸同步
                if (this.onWidthChange) {
                  this.onWidthChange(this.Width);
                }
              }
            })
        }
        .width('100%')

        // 高度滑块
        Column({ space: 8 }) {
          Row() {
            Text('高度')
              .fontSize(14)
              .fontColor(Color.Gray)
              .width(60)
            
            Text(`${this.Height}px`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          
          Slider({
            value: this.Height,
            min: 50,
            max: 600,
            step: 10
          })
            .blockColor('#007AFF')
            .onChange((value: number) => {
              if (this.onWidthChange && this.lockAspectRatio) {
                let width = Math.round(value * this.AspectRatio);
                this.onWidthChange(width);
              }
              if (this.onHeightChange) {
                this.onHeightChange(value);
              }
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Up) {
                // 拖动结束后确保尺寸同步
                if (this.onHeightChange) {
                  this.onHeightChange(this.Height);
                }
              }
            })
        }
        .width('100%')

        // 锁定宽高比开关
        Row() {
          Checkbox({ name: 'lockAspect', group: 'aspect' })
            .select(this.lockAspectRatio)
            .onChange((value: boolean) => {
              if(this.onLockChange){
                this.onLockChange(value);
                hilog.info(DOMAIN_NUMBER, TAG, `锁定宽高比: ${value}`);
              }
            })
          
          Text('锁定宽高比')
            .fontSize(14)
            .margin({ left: 8 })
          
          Blank()
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })

        // 预设比例按钮
        Row({ space: 12 }) {
          Button('1:1')
            .fontSize(12)
            .layoutWeight(1)
            .onClick(() => {
              if(this.onWidthChange && this.onHeightChange){
                this.onWidthChange(400);
                this.onHeightChange(400);
              }
              this.AspectRatio = 1;
              this.updateSizes();
            })
          
          Button('4:3')
            .fontSize(12)
            .layoutWeight(1)
            .onClick(() => {
              if(this.onWidthChange && this.onHeightChange){
                this.onWidthChange(400);
                this.onHeightChange(300);
              }
              this.AspectRatio = 4 / 3;
              this.updateSizes();
            })
          
          Button('16:9')
            .fontSize(12)
            .layoutWeight(1)
            .onClick(() => {
              if(this.onWidthChange && this.onHeightChange){
                this.onWidthChange(400);
                this.onHeightChange(225);
              }
              this.AspectRatio = 16 / 9;
              this.updateSizes();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16 })

      Blank()

      // 底部按钮
      Row() {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#F1F3F5')
          .fontColor(Color.Black)
          .onClick(() => {
            if (this.onCancel) {
              this.onCancel();
            }
          })
        
        Button('确定')
          .layoutWeight(1)
          .margin({ left: 12 })
          .onClick(() => {
            if (this.onConfirm) {
              this.onConfirm();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    }
    .width('90%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  // 更新尺寸并通知外部
  private updateSizes() {
    if (this.onWidthChange) {
      this.onWidthChange(this.Width);
    }
    if (this.onHeightChange) {
      this.onHeightChange(this.Height);
    }
  }
}
