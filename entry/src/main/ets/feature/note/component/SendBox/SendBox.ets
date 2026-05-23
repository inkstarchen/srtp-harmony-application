import { Constants } from "../../../../shared/constants";
import { SHADOW_FLOAT } from "../../../../shared/ui/uiUtils";
import { NoteType, NoteViewModel } from "../../NoteViewModel";


@Preview
@ComponentV2
export struct SendBox{
  // UI参数
  buttonHeight:number = 40;
  buttonWidth:number = 70;
  buttonFontSize: number = 17;
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  @Local options: RichEditorOptions = { controller: this.noteViewModel.getController() };
  @Local sendable: boolean = false;

  @Event needsFreshNote:() => void;

  build() {
    Column(){
      // RichEditor 文本输入框 - 可自适应高度
      RichEditor(this.options)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .onSelectionChange((range: RichEditorRange) => {
          if (range.start === undefined || range.end === undefined) {
            return;
          }
          const start = range.start;
          const end = range.end;
          this.noteViewModel.updateSelection(start, end);
        })
        .placeholder('开始记录您的想法...', {
          fontColor: Color.Gray,
          font: {
            size: 16,
            weight: FontWeight.Normal,
            family: "HarmonyOS Sans",
            style: FontStyle.Normal
          }
        })
        .border({radius:5,width:0})
        .width('100%')
        .maxLines(5)
        .onDeleteComplete(() => {
          let spans = this.noteViewModel.editorController.controller.getSpans({start:0,end:1});
          if(spans.length == 0) this.sendable = false;
          this.noteViewModel.editorController
        })
        .onIMEInputComplete((result) => {
          if (result.value.length != 0) this.sendable = true;
        })
        // .onEditingChange(async (edit) => {
        //   this.editing = edit;
        // })
        .layoutWeight(1)  // 占据剩余空间
      Row(){
        Button("收起")
          .onClick(() => {
          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          .border(Constants.MD_BORDER)
          .fontSize(this.buttonFontSize)
          .fontColor("#fff")
          .backgroundColor('#ff000000' )
          .width(this.buttonWidth)
          .height(this.buttonHeight)
          .layoutWeight(0)
        Blank()
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          .height(this.buttonHeight)
          .layoutWeight(1)
        Button("记录")
        .onClick(() => {
          let spans = this.noteViewModel.editorController.controller.getSpans({start:0,end:1});
          if (spans.length != 0){
            this.noteViewModel.newNote(NoteType.NOTE);
            this.noteViewModel.saveNote().then(() =>{
              this.sendable = false;
              this.noteViewModel.editorController.cleanAll();
              this.needsFreshNote();
            })
          }
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .border(Constants.MD_BORDER)
        .fontSize(this.buttonFontSize)
        .fontColor(this.sendable ? "#fff" : "#ff8f8f8f")
        .backgroundColor(this.sendable ? '#ff000000' : "#ffe3e3e3")
        .enabled(this.sendable)
        .width(this.buttonWidth)
        .height(this.buttonHeight)
        .layoutWeight(0)
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      .width("100%")
      .padding(10)
      .height(this.buttonHeight + 20)
      .layoutWeight(0)
      // 右侧按钮
    }
    .shadow(SHADOW_FLOAT)
    .border(Constants.MD_LINE_BORDER)
    .padding({top:10})
    .backgroundColor("#fff")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
    .alignItems(HorizontalAlign.Start)
    .width("100%")
  }
}