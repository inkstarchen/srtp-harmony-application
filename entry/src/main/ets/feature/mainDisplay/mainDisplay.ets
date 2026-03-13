import { PageId, PhysicsScroller, PosLimiter } from "../../shared/utils/PosLimiter";
import { DateInfo, getDateByTimeStamp, getDateInfo, getDateStringWithTimeStamp } from "../../shared/utils/Time/time";
import { entryCard } from "../note/component/entryCard/entryCard";
import { AnimatorResult, App, LengthMetrics, Prompt } from "@kit.ArkUI";
import { NoteService } from "../note/NoteService";
import { NoteInfo } from "../note/NoteState";
import { DateItem, SlidingDateModel } from "../../shared/utils/Time/SlideTimeModel";
import { SlideList } from "../SlideList/SlideList";
import { clipNum } from "../../core/math/mathUtil";
import { TraceVec2 } from "../../core/math/vec";
import { ThemeManager, ThemeState } from "../../theme/core/ThemeManager";
import { NoteViewModel } from "../note/NoteViewModel";

const CARD_DISAPPEAR_DUR = 100;
const CARD_APPEAR_DUR = 500;

@ComponentV2
export struct mainDisplay{

  @Local selectedTextColor: Color = Color.Black;
  @Local editing: boolean = false;
  @Local isColorPickerOpen: boolean = false;
  @Local noteViewModel: NoteViewModel= new NoteViewModel(this.getUIContext().getHostContext());
  @Local options: RichEditorOptions = { controller: this.noteViewModel.getController() };

  @Local themeManager:ThemeManager = ThemeManager.getInstance();
  @Local themeState:ThemeState = this.themeManager.getThemeState();
  @Require @Param mainOffset: TraceVec2;
  @Param curPage:PageId = PageId.NONE;
  @Local cardDisappearAnim:AnimatorResult = this.getUIContext().createAnimator({
    duration:CARD_DISAPPEAR_DUR,
    iterations:1,
    fill:"forwards",
    delay:0,
    direction:"normal",
    easing:"ease-in-out",
    begin:0,
    end:1
  })
  @Local cardAppearAnim:AnimatorResult = this.getUIContext().createAnimator({
    duration:CARD_APPEAR_DUR,
    iterations:1,
    fill:"forwards",
    delay:0,
    direction:"normal",
    easing:"ease-in-out",
    begin:0,
    end:1
  })
  @Local cardOpacity:number = 0;
  @Local cardOffset: number = 0;
  @Local TimeLineOpacity: number = 0;
  @Local slideTime:SlidingDateModel = new SlidingDateModel();
  selectedData: DateItem = this.slideTime.createItem(new Date(),0);
  @Local weekStr:string = this.selectedData.weekStr;
  @Local dayStr:string = this.selectedData.dayStr;
  @Local data: number[] = [30,20,10];
  @Require @Param limit:PhysicsScroller;
  @Require @Param timeNow:number;
  @Local dateInfo:DateInfo = getDateInfo(new Date());
  fileList: string[] = [];
  @Local notes: NoteInfo[] = [];
  @Event setRubber: () => void;
  @Local slideDisplay: boolean = false;

  refreshNotes() {
    let timeArray = getDateByTimeStamp(this.selectedData.timestamp);
    let appContext = this.getUIContext().getHostContext()?.getApplicationContext();

    if (!appContext) {
      return;
    }
    let fileDir = NoteService.getNoteDir(appContext, timeArray);

    NoteService.getNoteList(fileDir).then((data) => {
      // 已存在文件
      let exist = new Set(this.notes.map(n => n.fileName));

      data.forEach((value) => {
        if (!exist.has(value)) {

          let info: NoteInfo = {
            fileDir: fileDir,
            fileName: value,
            time: this.parseDateTimeFromPath(fileDir, value)
          }
          // ⭐ 新卡片直接 push
          this.notes.push(info);
        }
      })

    })
  }

  parseDateTimeFromPath(path: string, fileName: string): string | null {
  try {
    // 1️⃣ 提取日期部分 (YYYY/MM/DD)
    const dateMatch = path.match(/(\d{4})\/(\d{2})\/(\d{2})\/?$/);
    if (!dateMatch) {
      return null;
    }

    const year = dateMatch[1];
    const month = dateMatch[2];
    const day = dateMatch[3];

    // 2️⃣ 提取时间部分 (HH_MM_SS)
    const timeMatch = fileName.match(/_(\d{2})_(\d{2})_(\d{2})\.json$/);
    if (!timeMatch) {
      return null;
    }

    const hour = timeMatch[1];
    const minute = timeMatch[2];
    const second = timeMatch[3];

    return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
  } catch (e) {
    return null;
  }
}

  getNotes(timeStamp:number) {
    this.notes = [];
    let timeArray = getDateByTimeStamp(timeStamp);
    let appContext = this.getUIContext().getHostContext()?.getApplicationContext();
    if (appContext) {
      let fileDir = NoteService.getNoteDir(appContext,timeArray);
      NoteService.getNoteList(fileDir).then((data) => {
        this.fileList = data;
        this.fileList.forEach((value) => {
          console.info("check filelist | " + value);
          let info:NoteInfo = {
            fileDir: fileDir,
            fileName: value,
            time: this.parseDateTimeFromPath(fileDir,value)
          }
          this.notes.push(info);
        })
        this.cardAppearAnim.play();
      })
    }

  }

  aboutToReuse(): void {
    let nowTime = Date.now();
    this.getNotes(nowTime);
  }

  aboutToAppear(): void {
    let nowTime = Date.now();
    this.getNotes(nowTime);
    this.cardDisappearAnim.onFrame = (progress) => {
      this.cardOpacity = (1 - progress);
    }
    this.cardDisappearAnim.onFinish = () => {
      this.getNotes(this.selectedData.timestamp);
    }
    this.cardAppearAnim.onFrame = (progress) => {
      this.cardOpacity = progress;
      this.cardOffset = (1 - progress) * 100;
    }
  }


  build() {
    Stack({alignContent:Alignment.Bottom}){
      Row({ space: 10 }) {
        // ==== 时间 START =====
        Stack({alignContent:Alignment.Top}){
          SlideList({
            display: this.slideDisplay,
            setItem:(item:DateItem) => {
              this.selectedData.timestamp = item.timestamp;
              this.weekStr = item.weekStr;
              this.dayStr = item.dayStr;
              this.cardDisappearAnim.play();
            },
            setOpacity: () => {
              this.slideDisplay = false;
              if(this.TimeLineOpacity){
                this.TimeLineOpacity = 0;
              }else{
                this.TimeLineOpacity = 0.5;
              }
              this.setRubber();
            }
          })
          Stack({alignContent:Alignment.Center}) {
            Column(){
              Text(this.weekStr)
                .fontSize(12)
              Text(this.dayStr)
                .fontSize(20)
                .fontWeight(500)
            }
            .animation({
              duration:500,
              iterations:0,
              curve:Curve.Linear,
              delay:0
            })
          }
          .width("100%")
          .height(40)
          .opacity(this.TimeLineOpacity ? 0 : 1)
          .backgroundColor("#00ffffff")
          .animation({
            duration:500,
            iterations:1,
            delay:0,
            curve:Curve.Linear
          })
          .onClick(() => {
            this.slideDisplay = true;
            if(this.TimeLineOpacity){
              this.TimeLineOpacity = 0;
            }else{
              this.TimeLineOpacity = 0.5;
            }
            this.setRubber();
          })
          .hitTestBehavior(this.slideDisplay ? HitTestMode.BLOCK_DESCENDANTS : HitTestMode.Default)
        }
        .hitTestBehavior(HitTestMode.None)
        .width("20%")
        .height(800)
        // ==== 时间 END ====
        // ==== entry卡片排列 START====
        List({ space: 20 }) {
          if(this.notes.length === 0){
            ListItem(){
              Text("本日没有任何记录.")
                .fontSize(15)
                .fontColor("#da333839")
            }
            .translate({x:40,y:0})
          }
          ForEach(this.notes, (info:NoteInfo, key) => {
            ListItem(){
              entryCard({
                editNote: (info:NoteInfo) => {
                  this.getUIContext().getRouter().pushUrl({
                    url:"pages/NotePage",
                    params: info
                  })
                },
                deleteNote:(info:NoteInfo) => {
                  this.notes = this.notes.filter(n => n.fileName !== info.fileName);
                  this.noteViewModel.deleteNote(info).then(() => {
                    this.refreshNotes()
                  })
                },

                noteInfo: info,
                depth: (3 - clipNum(key,0,3)) * 10 + 10,
                angle: this.timeNow
              })
            }
          })
        }
        .width("70%")
        .height("100%")
        .clip(false)
        .scrollBar(BarState.Off)
        .opacity(this.cardOpacity)
        .translate({y:this.cardOffset})
        // ==== entry卡片排列 END ====
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Top)
      .height("90%")
      .width("90%")
      .hitTestBehavior(HitTestMode.None)
      .backgroundColor("#00fff8eb")

      Row(){
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r("sys.symbol.plus"))
            .fontSize(20)
            .fontColor([Color.Black]) //?
        }
        .backgroundColor('#00000000')
        .width(40)
        .height(40)
        RichEditor(this.options)
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
          .border({
            width: 1,
            color: '#EEEEEE',
            radius: 8
          })
          .backgroundColor(Color.White)
          .width('70%')
          .onEditingChange(async (edit) => {
            this.editing = edit;
          })
          .height("80%")
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r("sys.symbol.paperplane_right_fill"))
            .fontSize(20)
            .fontColor([Color.Black]) //?
        }
        .onClick(() => {
          let spans = this.noteViewModel.editorController.controller.getSpans({start:0,end:1});
          if (spans.length != 0){
            this.noteViewModel.newNote();
            this.noteViewModel.saveNote().then(() =>{
              this.noteViewModel.editorController.cleanAll();
              this.refreshNotes();
            })
          }
        })
        .backgroundColor('#00000000')
        .width(40)
        .height(40)
      }
      .justifyContent(FlexAlign.SpaceAround)
      .alignItems(VerticalAlign.Center)
      .translate({x:0,y:this.editing ? -300 : 0 })
      .animation({
        duration:250,
        delay:0,
        iterations:1,
        curve:Curve.EaseInOut
      })
      .border({radius:15,width:1})
      .width("90%")
      .height(50)
      .backgroundColor("#ffffffff")
    }
    .hitTestBehavior(HitTestMode.None)
    .translate( { x: this.mainOffset.x + this.limit.pos.x, y: this.mainOffset.y + this.limit.pos.y })
    .height("100%")
    .width("100%")
    .backgroundColor("#00ffffff")

  }
}