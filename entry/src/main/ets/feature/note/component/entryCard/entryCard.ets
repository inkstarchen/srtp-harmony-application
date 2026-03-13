import { NoteData } from "../../model/NoteSpanData"
import { LengthMetrics, LengthUnit, Prompt, SymbolGlyphModifier } from "@kit.ArkUI";
import { lerp } from "../../../../core/math/mathUtil";
import { ColorUtil } from "../../../../shared/utils/ColorUtil";
import { NoteInfo } from "../../NoteState";
import { NoteViewModel } from "../../NoteViewModel";
import { ThemeManager, ThemeState } from "../../../../theme/core/ThemeManager";

enum State{
  NONE = 0,
  SELECT = 1,
}

enum CardState{
  NONE = 0,
  DISPLAY = 1,
}

@Preview
@ComponentV2
export struct entryCard{
  @Event editNote:(noteInfo: NoteInfo) => void;
  @Event deleteNote:(noteInfo: NoteInfo) => void;

  @Local editIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.pencil_waveform')).fontSize('24vp');
  @Local trashIconModifier: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.ohos_trash')).fontSize('24vp');
  // @Require @Param data: NoteData;
  @Local opacityAnim: number = 0;
  @Local yAnim: number = 20;
  @Local themeManager:ThemeManager = ThemeManager.getInstance();
  @Local themeState:ThemeState = this.themeManager.getThemeState();
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  private options: RichEditorOptions = { controller: this.noteViewModel.getController() };

  @Require @Param noteInfo: NoteInfo;
  @Event Choose:() => void;
  @Local text:string = "测试文案";
  @Local date:string = "2026-2-3 20:35"
  @Require @Param angle:number;
  @Require @Param depth:number;
  @Local state: State = State.NONE;

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


  uiShadow(angle:number,baseDepth:number,baseRadius:number,baseAlpha:number) {
    const rad = angle * Math.PI / 180
    const vertical = Math.abs(Math.sin(rad))

    const depth =
      baseDepth *
        1.0 *
      lerp(1.6, 0.8, vertical)

    return {
      offsetX: depth * Math.cos(rad) * 0.6,
      offsetY: depth * Math.sin(rad),
      radius: baseRadius * lerp(1.4, 0.9, vertical),
      color: ColorUtil.fromRGBA(0,0,0,baseAlpha * (1.1 - 0.4 * vertical)),
    } as ShadowOptions;
  }

  removeJsonExtension(fileName: string): string {
    if (fileName.endsWith(".json")) {
      return fileName.slice(0, -5);
    }
    return fileName;
  }

  async aboutToAppear() {
    this.opacityAnim = 1;
    this.yAnim = 0;
    this.noteViewModel.noteState.setDir(this.noteInfo.fileDir);
    this.noteViewModel.noteState.setId(this.removeJsonExtension(this.noteInfo.fileName));
    await this.noteViewModel.loadCurrentNoteMain();
  }

  build(){
      Column() {
        Row(){
          RichEditor(this.options)
            .hitTestBehavior(HitTestMode.None)
            .barState(BarState.Off)
            .maxLength(39)
            .height(80)
            .width('80%')

          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r("sys.symbol.close_sidebar"))
              .fontSize(20)
              .fontColor([Color.Black]) //?
          }
          .bindMenu(this.MyMenu(() => {
              this.deleteNote(this.noteInfo);
            },
            () => {
              this.editNote(this.noteInfo);
            }))
          .backgroundColor('#00000000')
          .width(40)
          .height(40)
        }
        .height(80)
        .width('100%')
        .clip(true)

        Column() {
          Text(this.noteInfo.time)
            .fontSize(10)
            .fontColor(this.themeState.tokens.onPrimaryContainer)
            .margin({ right: 20 })
        }
        .alignItems(HorizontalAlign.End)
        .width("100%")
        .height(20)
      }
      .border({ radius: 15, width: 0, color: "#fff" })
      .padding({left:15,top:15,bottom:5})
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      // .shadow({radius:20,offsetX:-15,offsetY:-15,color:"#37292929"})
      .width("100%")
      .height(130)
      .opacity(this.opacityAnim)
      .translate({x:0,y:this.yAnim})
      // .height(this.state == State.NONE ? 120 : 800)
      .animation({
        duration:1000,
        delay:0,
        iterations:1,
        curve:Curve.Linear,
      })
      .shadow(this.uiShadow(30 + this.angle,this.depth,20,0.25))
      .backgroundColor(this.themeState.tokens.primaryContainer)
      .onClick(() => {
        this.Choose();
        if(this.state == State.NONE){
          this.state = State.SELECT;
        }else{
          this.state = State.NONE;
        }
      })
  }
}