import { common } from "@kit.AbilityKit";
import { ToolBarComponent } from "../feature/note/component/toolBar/toolBar";
import { NoteViewModel } from "../feature/note/NoteVeiwModel";
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

@Entry
@ComponentV2
export struct NotePage {

  // RichEditor 控制器和选项
  @Local noteViewModel: NoteViewModel = new NoteViewModel();
  private options: RichEditorOptions = { controller: this.noteViewModel.getController() };
  @Local currentNoteTitle: string = '未命名笔记';
  @Local isTitleFocused: boolean = false;
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

  aboutToAppear(): void {
    this.init();
  }

  async init(){
    const appContext = this.context.getApplicationContext();
    let path = `${appContext.filesDir}/notes/`;
    // console.info('NotePage | path is ' + path);
    let initFlag = await this.noteViewModel.init(path);
    this.currentNoteTitle = this.noteViewModel.noteState.title;
    // await this.noteViewModel.loadCurrentNote();
  }

  build() {
    Column() {
      Column() {
        // 标题区域
        Row() {  //, verticalAlign: ItemAlign.Center
          TextInput({ text: this.currentNoteTitle })
            .layoutWeight(1)
            .fontSize(20)
            .fontWeight(this.isTitleFocused ? FontWeight.Normal : FontWeight.Bold)
            .backgroundColor(Color.Transparent)
            .maxLines(1)
            .textAlign(TextAlign.Start)
            .onFocus(() => {
              this.isTitleFocused = true;
            })
            .onBlur(() => {
              this.isTitleFocused = false;
            })
            .onChange((value: string) => {
              this.currentNoteTitle = value;
              this.noteViewModel.setTitle(value);
            })

          // 保存状态
          Text(this.noteViewModel.saveStatus)
            .fontSize(12)
            .fontColor(Color.Blue)
            .margin({ left: 8 })
            .height(20)
            .opacity(this.noteViewModel.saveStatus ? 1 : 0)
            .animation({ duration: 300 })

        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 4 })
        .alignItems(VerticalAlign.Center)

        ToolBarComponent({
          newNote: () => {
            this.noteViewModel.newNote();
            },
          selectImage: () => {
            this.noteViewModel.selectImage();
          },
          saveNote: () => {
            this.noteViewModel.saveNote();
          }
        })
      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius(8)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .padding({ top: 4, bottom: 4 })

      // 富文本编辑器区域
      Column() {
        RichEditor(this.options)
          .onReady(() => {
            hilog.info(DOMAIN_NUMBER, TAG, 'RichEditor准备就绪');
          })
          .onSelect((value: RichEditorSelection) => {
            hilog.debug(DOMAIN_NUMBER, TAG, `选中范围: [${value.selection[0]}, ${value.selection[1]}]`);
          })
          .aboutToIMEInput((value: RichEditorInsertValue) => {
            hilog.debug(DOMAIN_NUMBER, TAG, `即将输入: ${value.insertValue}`);
            return true;
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
          .border({
            width: 1,
            color: '#EEEEEE',
            radius: 8
          })
          .backgroundColor(Color.White)
          .width('100%')
          .height('100%')
      }
      .layoutWeight(1)
      .padding({ top: 0, left: 10, right: 10, bottom: 10 })
      .backgroundColor('#ffffffff')
    }
    .padding(10)
    .backgroundColor('#ffffffff')
    .height('100%')
  }

  pageTransition() {
    PageTransitionEnter({delay:1000, duration:1000,curve:Curve.Linear})
      .slide(SlideEffect.Left)
  }
}