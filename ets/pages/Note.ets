import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Prompt} from '@kit.ArkUI';

import { NotesController } from '../controller/NoteController';

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

@Entry
@ComponentV2
struct NotePage {

  @Local message: string = '我的富文本笔记';
  @Local noteTitle: string = '未命名笔记';
  @Local isEditingTitle: boolean = false;

  @Local notesController: NotesController = new NotesController(this.getUIContext());

  // RichEditor 控制器和选项
  private options: RichEditorOptions = { controller: this.notesController.controller };
  // 应用上下文和文件路径
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  //private appContext = this.context.getApplicationContext();

  private currentNoteId: string = 'note_' + Date.now();



  aboutToAppear(): void {
    // 初始化文件路径
    const appContext = this.context.getApplicationContext();
    //this.notesDir = `${this.context.filesDir}/notes/`;
    this.notesController.notesDir = `${appContext.filesDir}/notes/`;
    //this.notesDir = `${this.appContext.filesDir}/notes/`;
    hilog.info(DOMAIN_NUMBER, TAG, `笔记目录: ${this.notesController.notesDir}`); // 添加这行日志
    NotesController.ensureNotesDirectoryExists(this.notesController.notesDir);
    // 加载最近编辑的笔记（如果有）
    this.notesController.loadRecentNote(this.notesController.notesDir);
  }

  build() {
    Column({ space: 10 }) {
      // 标题和工具栏区域
      Column() {
        // 标题编辑
        Row() {
          if (this.isEditingTitle) {
            TextInput({ text: this.noteTitle })
              .onChange((value: string) => {
                this.noteTitle = value;
              })
              .onSubmit(() => {
                this.isEditingTitle = false;
              })
              .width('70%')
          } else {
            Text(this.noteTitle)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .width('70%')
              .onClick(() => {
                this.isEditingTitle = true;
              })
          }
          // 保存按钮和状态
          Column() {
            Button('保存')
              .onClick(() => {
                this.notesController.saveNote();
              })
              .width(60)
              .height(32)
            Text(this.notesController.saveStatus)
              .fontSize(12)
              .fontColor(Color.Blue)
              .height(20)
          }
          .width('30%')
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding(10)

        // 操作工具栏
        Row({ space: 10 }) {
          Button('插入图片')
            .onClick(() => {
              this.notesController.selectImageFromGallery();
            })
            .height(32)
            .layoutWeight(1)

          Button('文字加粗')
            .onClick(() => {
              Prompt.showToast({ message: '加粗功能待实现', duration: 1500 });
            })
            .height(32)
            .layoutWeight(1)

          Button('新建笔记')
            .onClick(async () => {
              this.currentNoteId = 'note_' + Date.now();
              this.notesController.controller.deleteSpans({ start: 0, end: -1 });
              await this.notesController.initializeNewNote();
            })
            .height(32)
            .layoutWeight(1)
        }
        .width('100%')
        .padding(10)
      }
      .backgroundColor(Color.White)
      .borderRadius(8)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)

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
      .padding(10)
      .backgroundColor('#F5F5F5')

    }
    .padding(10)
    .backgroundColor('#F8F8F8')
    .height('100%')
  }
}
