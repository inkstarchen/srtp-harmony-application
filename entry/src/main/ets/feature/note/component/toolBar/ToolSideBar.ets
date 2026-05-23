import { Constants } from "../../../../shared/constants";
import { SHADOW_FLOAT } from "../../../../shared/ui/uiUtils";
import { ToolBarButtonStateParams } from "../../model/ToolBarTypes";
import { NoteViewModel } from "../../NoteViewModel";

@ComponentV2
export struct ToolSideBar{
  @Require @Param noteViewModel: NoteViewModel | undefined;

  build() {
    Column(){

      Grid(){
        this.ToolBarButton({
          icon: $r('sys.symbol.italic'),
          action: () => {
            this.noteViewModel?.toggleItalic();
          },
            isActive:this.noteViewModel?.isItalicActive
        })

        this.ToolBarButton({
          icon: $r('sys.symbol.bold'),
          action: () => {
            this.noteViewModel?.toggleBold();
          },
          isActive: this.noteViewModel?.isBoldActive
        })

        this.ToolBarButton({
          icon: $r('sys.symbol.underline'),
          action: () =>
          {
            this.noteViewModel?.toggleUnderline();
          },
          isActive: this.noteViewModel?.isUnderlineActive
        })

        this.ToolBarButton({ icon: $r('sys.symbol.ohos_photo'), action: () => {
          this.noteViewModel?.selectImage();
        } })
      }
      .columnsGap(20)
      .rowsGap(40)
      .padding(40)
      .columnsTemplate("1fr 1fr")
      .width("100%")
      .height("60%")
      .backgroundColor("#fff")
      .layoutWeight(0)
      Column(){

      }
      .width("100%")
      .layoutWeight(1)
    }
    .width("100%")
    .height("100%")
    .shadow(SHADOW_FLOAT)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }

  @Builder
  ToolBarButton(params: ToolBarButtonStateParams) {
    GridItem(){
      Button() {
        SymbolGlyph(params.icon)
          .fontSize(40)
          .fontColor([params.isActive ? Color.Blue : Color.Black])
      }
      .border(Constants.MD_BORDER)
      .width("100%")
      .height("100%")
      .backgroundColor('#00000000')
      .onClick(params.action)
    }
    .height("40%")
    .shadow(SHADOW_FLOAT)
    .border(Constants.MD_BORDER)
    .backgroundColor("#fff")
  }

}