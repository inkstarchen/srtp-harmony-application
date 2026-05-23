import { AnimatorResult } from "@kit.ArkUI";
import { DateItem } from "../../../../shared/utils/Time/SlideTimeModel";
import { DateInfo, getDateByTimeStamp, getDateInfo } from "../../../../shared/utils/Time/time";
import { NoteService } from "../../NoteService";
import { NoteAction, NoteInfo, NotePageParams } from "../../NoteState";
import { NoteType, NoteViewModel } from "../../NoteViewModel";
import { entryCard2D } from "../entryCard/entryCard2D";

const CARD_DISAPPEAR_DUR = 100;
const CARD_APPEAR_DUR = 500;
const SHADOW_FLOAT = {radius:15,offsetY:10,color: "#ffc8c8c8" } as ShadowOptions;
@ComponentV2
export struct CardDisplay2D{
  @Local selectedTextColor: Color = Color.Black;
  @Local editing: boolean = false;
  @Local isColorPickerOpen: boolean = false;
  @Local noteViewModel: NoteViewModel= new NoteViewModel(this.getUIContext().getHostContext());
  @Local options: RichEditorOptions = { controller: this.noteViewModel.getController() };

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
  @Local cardOffset: number = 0;

  @Require @Param selectedData: DateItem;
  @Param needFreshDate:boolean = false;

  @Local dateInfo:DateInfo = getDateInfo(new Date());
  fileList: string[] = [];
  @Local notes: NoteInfo[] = [];

  @Event noteClicked:(info:NoteInfo) => void;

  @Event FreshDateFinished:() => void;
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

  @Event FreshAllFinished:() => void;
  @Param needsFreshAll:boolean = false;
  @Monitor("needsFreshAll")
  onFreshAll(monitor:IMonitor){
    if((monitor.value()?.now as boolean)){
      this.refreshAll();
    }
  }

  refreshAll(){
    this.notes = [];
    this.refreshNotes();
    this.FreshAllFinished();
  }

  refreshNotes() {
    let timeArray = getDateByTimeStamp(this.selectedData.timestamp);
    let appContext = this.getUIContext().getHostContext()?.getApplicationContext();

    if (!appContext) {
      return;
    }
    let fileDir = NoteService.getNoteDir(appContext, timeArray);

    NoteService.getNoteList(fileDir).then(async (data) => {
      // 已存在文件
      let exist = new Set(this.notes.map(n => n.fileName));

      for (const fileName of data) {
        if (!exist.has(fileName)) {
          try {
            // 读取文件判断类型，过滤 ARTICLE
            const noteData = await NoteService.loadNote(`${fileDir}/${fileName}`);
            if (noteData && noteData.type === NoteType.ARTICLE) {
              continue; // 跳过 ARTICLE 类型
            }
          } catch (e) {
            // 忽略读取失败的文件
            continue;
          }

          let info: NoteInfo = {
            type: NoteType.NOTE,
            fileDir: fileDir,
            fileName: fileName,
            time: this.parseDateTimeFromPath(fileDir, fileName)
          }
          // ⭐ 新卡片直接 push
          this.notes.push(info);
        }
      }
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
      NoteService.getNoteList(fileDir).then(async (data) => {
        this.fileList = data;
        for (const value of data) {
          console.info("check filelist | " + value);
          try {
            // 读取文件判断类型，过滤 ARTICLE
            const noteData = await NoteService.loadNote(`${fileDir}/${value}`);
            if (noteData && noteData.type === NoteType.ARTICLE) {
              continue; // 跳过 ARTICLE 类型
            }
          } catch (e) {
            continue;
          }

          let info:NoteInfo = {
            type:NoteType.NOTE,
            fileDir: fileDir,
            fileName: value,
            time: this.parseDateTimeFromPath(fileDir,value)
          }
          this.notes.push(info);
        }
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
    }
    this.cardDisappearAnim.onFinish = () => {
      this.getNotes(this.selectedData.timestamp);
    }
    this.cardAppearAnim.onFrame = (progress) => {

    }
    this.cardAppearAnim.onFinish = () => {
      this.FreshDateFinished();
    }
  }

  build() {
    Column() {
      // ==== entry卡片排列 START====
      List({ space: 0 }) {
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
              entryCard2D({
                index:key,
                editNote: (info:NoteInfo) => {
                  this.getUIContext().getRouter().pushUrl({
                    url:"pages/NotePage",
                    params: {action:NoteAction.SHOW,info:info} as NotePageParams,
                  })
                },
                deleteNote:(info:NoteInfo) => {
                  this.notes = this.notes.filter(n => n.fileName !== info.fileName);
                  this.noteViewModel.deleteNote(info).then(() => {
                    this.refreshNotes()
                  })
                },
                noteInfo: info,
              })
          }
          .onClick(() => {
            this.noteClicked(info);
          })
        })
        ListItem(){
        }
        .height(200)
        .width("100%")
      }
      .width("100%")
      .height("100%")
      .clip(false)
      .scrollBar(BarState.Off)
      .padding({top:20})
      .zIndex(1)
      // ==== entry卡片排列 END ====
    }
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
    .hitTestBehavior(HitTestMode.None)
    .height("100%")
    .width("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor("#00ffffff")
  }
}