import { common } from "@kit.AbilityKit";
import { ToolBarComponent } from "../feature/note/component/toolBar/toolBar";
import { NoteType, NoteViewModel } from "../feature/note/NoteViewModel";
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getDateByTimeStamp } from "../shared/utils/Time/time";
import { NoteAction, NoteInfo, NotePageParams } from "../feature/note/NoteState";
import { ThemeManager, ThemeState } from "../theme/core/ThemeManager";

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

@Entry
@ComponentV2
export struct NotePage {

  // RichEditor 控制器和选项
  @Local editing:boolean = false;
  @Local themeManager: ThemeManager = ThemeManager.getInstance();
  @Local themeState: ThemeState = this.themeManager.getThemeState();
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  private options: RichEditorOptions = { controller: this.noteViewModel.getController() };
  @Local currentNoteTitle: string = '无标题';
  @Local isTitleFocused: boolean = false;
  @Local selectedTextColor: Color = Color.Black;
  @Local isColorPickerOpen: boolean = false;
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;


  onPageShow(): void {
    let info:NotePageParams = this.getUIContext().getRouter().getParams() as NotePageParams;
    if(info.action == NoteAction.SHOW){
      this.noteViewModel.loadFromNoteInfo(info.info);
    }else if(info.action == NoteAction.NEW){
      this.noteViewModel.newNote(NoteType.ARTICLE);
    }
  }

  build() {
    Stack({alignContent:Alignment.Center}){
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
            clearSpan: () => {
              this.noteViewModel.editorController.cleanAll();
            },
            // newNote: () => {
            //   this.noteViewModel.newNote();
            // },
            selectImage: () => {
              this.noteViewModel.selectImage();
            },
            saveNote: () => {
              this.noteViewModel.saveNote();
            },
            toggleBold: () => {
              this.noteViewModel.toggleBold();
            },
            toggleItalic: () => {
              this.noteViewModel.toggleItalic();
            },
            toggleUnderline: () => {
              this.noteViewModel.toggleUnderline();
            },
            isBoldActive: this.noteViewModel.isBoldActive,
            isItalicActive: this.noteViewModel.isItalicActive,
            isUnderlineActive: this.noteViewModel.isUnderlineActive,
            currentTextColor: this.selectedTextColor,
            setTextColor: (color: Color) => {
              hilog.info(DOMAIN_NUMBER, TAG, `color swatch tapped: ${color}`);
              this.selectedTextColor = color;
              this.noteViewModel.setTextColor(color);
            },
            applyTextColor: () => {
              this.noteViewModel.applyTextColor();
            },
            isColorPickerOpen: this.isColorPickerOpen,
            setColorPickerOpen: (open: boolean) => {
              this.isColorPickerOpen = open;
            },
            changeEditState: () => {
            }
          })
        }
        .width('100%')
        .height("15%")
        .backgroundColor(Color.White)
        .borderRadius(8)
        // .shadow(ShadowStyle.OUTER_DEFAULT_XS)
        .padding({ top: 4, bottom: 4 })

        Divider().strokeWidth(4).color('#F1F3F5').width("80%")

        // 富文本编辑器区域
        Column() {
          RichEditor(this.options)
            .onReady(() => {
              hilog.info(DOMAIN_NUMBER, TAG, 'RichEditor准备就绪');
            })
            .onSelectionChange((range: RichEditorRange) => {
              if (range.start === undefined || range.end === undefined) {
                return;
              }
              const start = range.start;
              const end = range.end;
              hilog.debug(DOMAIN_NUMBER, TAG, `选中范围: [${start}, ${end}]`);
              this.noteViewModel.updateSelection(start, end);
            })
            .aboutToIMEInput((value: RichEditorInsertValue) => {
              hilog.debug(DOMAIN_NUMBER, TAG, `即将输入: ${value.insertValue}`);
              return true;
            })
            .onEditingChange((edit) => {
              this.editing = edit;
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
            .backgroundColor("#ffffffff")
            .width('100%')
            .height('100%')
        }
        .layoutWeight(1)
        .width("100%")
        .padding({top:5,left:10,right:10,bottom:20})
        .margin({top:10})
        .backgroundColor('#00ffffff')
      }
      .backgroundColor('#ffffffff')
      .border({radius:15,width:0})
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .padding(10)
      .width("90%")
      .height('90%')


    }
    .backgroundColor(this.themeState.tokens.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
    .width("100%")
    .height("100%")
  }

  pageTransition() {
    PageTransitionEnter({delay:500, duration:250,curve:Curve.Linear})
      .opacity(0)
    PageTransitionExit({delay:0, duration:250,curve:Curve.Linear})
      .opacity(0)
  }
}