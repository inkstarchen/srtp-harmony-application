import { PageId, PhysicsScroller, PosLimiter } from "../../shared/utils/PosLimiter";
import { DateInfo, getDateByTimeStamp, getDateInfo, getDateStringWithTimeStamp } from "../../shared/utils/Time/time";
import { entryCard } from "../note/component/entryCard/entryCard";
import { AnimatorResult} from "@kit.ArkUI";
import { NoteService } from "../note/NoteService";
import { NoteInfo } from "../note/NoteState";
import { DateItem} from "../../shared/utils/Time/SlideTimeModel";
import { clipNum } from "../../core/math/mathUtil";
import { TraceVec2 } from "../../core/math/vec";
import { ThemeManager, ThemeState } from "../../theme/core/ThemeManager";
import { NoteViewModel } from "../note/NoteViewModel";

export enum CardState {
  SHOW = 0,
  SELECTION = 1
}

const CARD_DISAPPEAR_DUR = 100;
const CARD_APPEAR_DUR = 500;
const SHADOW_FLOAT = {radius:15,offsetY:10,color: "#ffc8c8c8" } as ShadowOptions;
@ComponentV2
export struct mainDisplay{
  @Local cardState: CardState = CardState.SHOW;
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

  @Require @Param selectedData: DateItem;

  @Require @Param limit:PhysicsScroller;
  @Require @Param timeNow:number;
  @Local dateInfo:DateInfo = getDateInfo(new Date());
  fileList: string[] = [];
  @Local notes: NoteInfo[] = [];
  @Event FreshDateFinished:() => void;
  @Param needFreshDate:boolean = false;
  @Monitor("needFreshDate")
  onFreshDateChange(monitor:IMonitor){
    if((monitor.value()?.now as boolean)){
      this.cardDisappearAnim.play();
    }
  }

  @Event FreshFinished:() => void;
  @Param needsFresh: boolean = false;
  @Monitor("needsFresh")
  onFreshChange(monitor:IMonitor){
    if((monitor.value()?.now as boolean)){
      this.refreshNotes();
    }
  }


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
    this.FreshFinished();
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
    this.cardAppearAnim.onFinish = () => {
      this.FreshDateFinished();
    }
  }

  build() {
    Column() {
      Row(){
      }
      .width("100%")
      .height(100)
      .zIndex(2)
      // ==== entry卡片排列 START====
      List({ space: 20 }) {
        if(this.notes.length === 0){
          ListItem(){
            Text("本日没有任何记录.")
              .fontSize(15)
              .fontColor("#da333839")
          }
          .width("100%")
        }
        ForEach(this.notes, (info:NoteInfo, key) => {
          ListItem(){
            entryCard({
              setCardState:() => {
                this.cardState = CardState.SELECTION;
              },
              cardState:this.cardState,
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
        ListItem(){
        }
        .height(200)
        .width("100%")
      }
      .width("70%")
      .height("100%")
      .clip(false)
      .scrollBar(BarState.Off)
      .opacity(this.cardOpacity)
      .translate({y:this.cardOffset})
      .zIndex(1)
      // ==== entry卡片排列 END ====
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
    .height("100%")
    .width("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor("#00ffffff")
  }
}