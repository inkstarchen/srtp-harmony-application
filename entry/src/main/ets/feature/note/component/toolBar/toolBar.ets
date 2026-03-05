import { ColorButtonParams,  ColorSwatchParams, DropdownButtonParams, ToolBarButtonStateParams
} from "../../model/ToolBarTypes";
import { AnimatorResult } from "@kit.ArkUI";

@ComponentV2
export struct ToolBarComponent{

  @Require @Param clearSpan:() => void;
  @Require @Param newNote:() => void;
  @Require @Param selectImage:() => void;
  @Require @Param saveNote:() => void;
  @Require @Param toggleBold:() => void;
  @Require @Param toggleItalic:() => void;
  @Require @Param toggleUnderline:() => void;
  @Require @Param isBoldActive: boolean;
  @Require @Param isItalicActive: boolean;
  @Require @Param isUnderlineActive: boolean;
  @Require @Param currentTextColor: Color;
  @Require @Param setTextColor:(color: Color) => void;
  @Require @Param applyTextColor:() => void;
  @Require @Param isColorPickerOpen: boolean;
  @Require @Param setColorPickerOpen:(open: boolean) => void;
  @Require @Param changeEditState: () => void;

  @Require @Param editing:boolean;
  @Param playAnim: boolean = false;
  @Local heightAnim: number = 0;
  appearAnim:AnimatorResult | undefined;
  disappearAnim:AnimatorResult | undefined;

  @Monitor("editing")
  onEditChange(monitor:IMonitor) {
    let editState = monitor.value()?.now as boolean;
    if(!editState) {
      this.disappearAnim?.play();
    }
  }

  aboutToAppear(): void {
    if(this.playAnim){
      this.appearAnim = this.getUIContext().createAnimator({
        duration:1000,
        fill:"forwards",
        easing:'ease-in-out',
        delay:0,
        direction:"normal",
        iterations:1,
        begin:0,
        end:1
      })
      this.appearAnim.onFrame = (progress) => {
        this.heightAnim = 36 * progress;
      }
      this.disappearAnim = this.getUIContext().createAnimator({
        duration:1000,
        fill:"forwards",
        easing:'ease-in-out',
        delay:0,
        direction:"normal",
        iterations:1,
        begin:0,
        end:1
      })
      this.disappearAnim.onFrame = (progress) => {
        this.heightAnim = 36 * (1 - progress);
      }
      this.disappearAnim.onFinish = () => {
        this.changeEditState();
      }
      this.appearAnim.play();
    }else{
      this.heightAnim = 36;
    }
  }



  aboutToDisappear(): void {

  }

  private readonly colorRow1: Color[] = [
    Color.Black,
    Color.Blue,
    Color.Brown,
    Color.Grey,
    Color.Green
  ];

  private readonly colorRow2: Color[] = [
    Color.Orange,
    Color.Pink,
    Color.Red,
    Color.White,
    Color.Yellow
  ];

  build(){
    // 格式工具栏
    Column() {
      Scroll( ) {
        Row() {
          this.ToolBarButton({ icon: $r('sys.symbol.archivebox_badge_clock'), action: () => this.saveNote() })
          this.ToolBarButton({
            icon: $r('sys.symbol.folder_badge_plus'),
            action: async () => {
              this.newNote();
              this.clearSpan();
              // await this.notesController.initializeNewNote();
              // this.currentNoteTitle = this.notesController.note?.noteTitle ?? '未命名笔记';
            }
          })
          this.ToolBarButton({ icon: $r('sys.symbol.ohos_photo'), action: () => this.selectImage() })

          Divider().vertical(true).height(20).margin({ left: 4, right: 4 })

          this.ToolBarButton({
            icon: $r('sys.symbol.bold'),
            action: () => this.toggleBold(),
            isActive: this.isBoldActive
          })
          this.ToolBarButton({
            icon: $r('sys.symbol.italic'),
            action: () => this.toggleItalic(),
            isActive: this.isItalicActive
          })
          this.ToolBarButton({
            icon: $r('sys.symbol.underline'),
            action: () => this.toggleUnderline(),
            isActive: this.isUnderlineActive
          })

          Row({ space: 4 }) {
            this.ColorButton({
              color: this.currentTextColor,
              action: () => this.applyTextColor()
            })
            this.DropdownButton({
              isOpen: this.isColorPickerOpen,
              action: () => {
                this.setColorPickerOpen(!this.isColorPickerOpen);
              }
            })
          }
        }
        .padding({ left: 12, right: 12 })
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)


      if (this.isColorPickerOpen) {
        Column() {
          Row({ space: 10 }) {
            ForEach(this.colorRow1, (item: Color) => {
              this.ColorSwatch({
                color: item,
                action: () => {
                  this.setTextColor(item);
                }
              })
            }, (_item: Color, index: number) => `${index}`)
          }
          .margin({ bottom: 8 })
          .offset({ left: 160 })     //  可手动调节
          Row({ space: 10 }) {
            ForEach(this.colorRow2, (item: Color) => {
              this.ColorSwatch({
                color: item,
                action: () => {
                  this.setTextColor(item);
                }
              })
            }, (_item: Color, index: number) => `${index + 5}`)
          }
          .offset({ left: 160 })    //   可手动调节
        }
        .padding({ left: 12, right: 12, bottom: 8 })
        .alignItems(HorizontalAlign.End)
      }
    }
    .width("100%")
    .clip(true)
    .height(this.heightAnim)
  }

  @Builder
  ToolBarButton(params: ToolBarButtonStateParams) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(params.icon)
        .fontSize(18)
        .fontColor([params.isActive ? Color.Blue : Color.Black])
    }
    .width(36)
    .height(36)
    .backgroundColor('#00000000')
    .onClick(params.action)
  }

  @Builder
  ColorButton(params: ColorButtonParams) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.paintpalette'))
        .fontSize(18)
        .fontColor([params.color === Color.White ? Color.Black : params.color])
    }
    .width(36)
    .height(36)
    .backgroundColor('#00000000')
    .border({ width: params.color === Color.White ? 1 : 0, color: '#DDDDDD' })
    .onClick(params.action)
  }

  @Builder
  DropdownButton(params: DropdownButtonParams) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(params.isOpen ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
        .fontSize(16)
        .fontColor([params.isOpen ? Color.Blue : Color.Black])
    }
    .width(28)
    .height(28)
    .backgroundColor('#00000000')
    .onClick(params.action)
  }

  @Builder
  ColorSwatch(params: ColorSwatchParams) {
    Button({ type: ButtonType.Circle }) {
    }
    .width(24)
    .height(24)
    .backgroundColor(params.color)
    .border({ width: params.color === Color.White ? 1 : 0, color: '#DDDDDD' })
    .onClick(params.action)
  }
}