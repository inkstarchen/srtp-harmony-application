import { Prompt} from '@kit.ArkUI';

interface ToolBarButtonParams {
  icon: Resource;
  action: () => void;
}

interface ToolBarButtonStateParams extends ToolBarButtonParams {
  isActive?: boolean;
}

@ComponentV2
export struct ToolBarComponent{

  @Require @Param newNote:() => void;
  @Require @Param selectImage:() => void;
  @Require @Param saveNote:() => void;
  @Require @Param toggleBold:() => void;
  @Require @Param isBoldActive: boolean;
  build(){
    // 格式工具栏
    Scroll( ) {
      Row({ space: 8} ) {  //, verticalAlign: ItemAlign.Center }
        this.ToolBarButton({ icon: $r('sys.symbol.archivebox_badge_clock'), action: () => this.saveNote() })
        this.ToolBarButton({
          icon: $r('sys.symbol.folder_badge_plus'),
          action: async () => {
            this.newNote();
            // this.notesController.controller.deleteSpans({ start: 0, end: -1 });
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
        this.ToolBarButton({ icon: $r('sys.symbol.italic'), action: () => {
          Prompt.showToast({ message: '斜体功能待实现', duration: 1500 });
        } })
        this.ToolBarButton({ icon: $r('sys.symbol.underline'), action: () => {
          Prompt.showToast({ message: '下划线功能待实现', duration: 1500 });
        } })
        this.ToolBarButton({ icon: $r('sys.symbol.paintpalette'), action: () => {
          Prompt.showToast({ message: '颜色功能待实现', duration: 1500 });
        } })
      }
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .height(48)
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
}