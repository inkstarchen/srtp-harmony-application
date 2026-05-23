import { AnimatorResult, Prompt, SymbolGlyphModifier } from "@kit.ArkUI";
import { NoteInfo } from "../../NoteState";
import { NoteViewModel } from "../../NoteViewModel";
import { ThemeManager, ThemeState } from "../../../../theme/core/ThemeManager";

const CARD_APPEAR_DUR = 500;

@Preview
@ComponentV2
export struct entryCard2D{
  @Local hover:boolean = false;
  @Param index:number = 0;
  @Event setCardState: () => void;
  @Event editNote:(noteInfo: NoteInfo) => void;
  @Event deleteNote:(noteInfo: NoteInfo) => void;
  @Local editIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.pencil_waveform')).fontSize('24vp');
  @Local trashIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.ohos_trash')).fontSize('24vp');
  @Local themeManager:ThemeManager = ThemeManager.getInstance();
  @Local themeState:ThemeState = this.themeManager.getThemeState();
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  @Local cardAppearAnim:AnimatorResult = this.getUIContext().createAnimator({
    duration:CARD_APPEAR_DUR,
    iterations:1,
    fill:"forwards",
    delay:this.index * 100,
    direction:"normal",
    easing:"ease-in-out",
    begin:0,
    end:1
  })
  @Local cardOffset: number = -600;

  private options: RichEditorOptions = { controller: this.noteViewModel.getController() };

  @Require @Param noteInfo: NoteInfo;
  @Builder
  MyMenu(onDelete: () => void, onEdit: () => void) {
    Menu() {
      MenuItem({ symbolStartIcon: this.editIconModifier, content: "编辑" })
        .onChange(() => {
          onEdit();
        })
      MenuItem({ symbolStartIcon: this.trashIconModifier, content: "删除"})
        .onChange(() => {
          Prompt.showToast({message:"delete"})
          onDelete();
        })
    }
  }

  removeJsonExtension(fileName: string): string {
    if (fileName.endsWith(".json")) {
      return fileName.slice(0, -5);
    }
    return fileName;
  }

  async aboutToAppear() {
    this.noteViewModel.noteState.setDir(this.noteInfo.fileDir);
    this.noteViewModel.noteState.setId(this.removeJsonExtension(this.noteInfo.fileName));
    await this.noteViewModel.loadCurrentNoteMain();
    this.cardAppearAnim.onFrame = (progress) => {
      this.cardOffset = (1 - progress) * -600;
    }
    this.cardAppearAnim.play();
  }

  build(){
    Column() {
      Text(this.noteInfo.title ? this.noteInfo.title : this.noteInfo.time)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      RichEditor(this.options)
        .hitTestBehavior(HitTestMode.None)
        .barState(BarState.Off)
        .maxLines(4)
        .width('100%')
      Line()
        .width("90%")
        .height(2)
        .margin({top:20})
        .strokeLineCap(LineCapStyle.Round)
        .backgroundColor('#2d000000')
    }
    .onTouch((event) => {
      this.handleTouch(event);
    })
    .bindContextMenu(this.MyMenu(() => {
      this.deleteNote(this.noteInfo);
    },
      () => {
        this.editNote(this.noteInfo);
      }),ResponseType.LongPress)
    .padding({left:30,right:30,top:20})
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.SpaceBetween)
    .width("100%")
    .backgroundColor(this.hover ? "#ffeaeaea" : "#00ffffff")
    .animation({
      duration:100,
      delay:0,
      iterations:1,
      curve:Curve.EaseInOut,
    })
    .translate({x:this.cardOffset})
  }

  handleTouch(event:TouchEvent){
    if(event.type == TouchType.Down){
      this.hover = true;
    }else if(event.type == TouchType.Move){

    }else{
      this.hover = false;
    }
  }
}