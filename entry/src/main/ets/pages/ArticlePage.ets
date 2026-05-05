import { SceneProxy } from "../core/scene3D/GlobalSceneProxy";
import { ArticleEntry, getArticlesByTimeDesc } from "../feature/DataStorage/datastore"
import { NoteType, NoteViewModel } from "../feature/note/NoteViewModel";
import { NoteAction, NoteInfo, NotePageParams } from "../feature/note/NoteState";

@Preview
@ComponentV2
export struct ArticlePage{
  @Local selectId: number = 0;
  @Local entries: ArticleEntry[] = [];
  @Local isLoading: boolean = true;
  @Local noteViewModel: NoteViewModel = new NoteViewModel(this.getUIContext().getHostContext());
  @Local noteList: NoteInfo[] = [];  // 笔记列表（从数据库加载）


  aboutToAppear(): void {
    this.loadArticles();
  }

  /**
   * 从数据库加载文章列表
   */
  private async loadArticles(): Promise<void> {
    try {
      this.isLoading = true;
      console.info("[ArticlePage] 开始从数据库加载文章列表");
      
      // 从数据库加载 ARTICLE 笔记（内部自动处理数据库初始化等待）
      const notes = await this.noteViewModel.loadArticlesFromDatabase();
      this.noteList = notes;
      console.info(`[ArticlePage] 从数据库加载到 ${notes.length} 条笔记`);
      
      if (notes.length > 0) {
        notes.forEach((note, index) => {
          console.info(`[ArticlePage] 笔记 ${index}: title=${note.fileName}, time=${note.time}, dbId=${note.dbId}`);
        });
      }

      // 同时加载旧版 ARTICLE 表数据（兼容）
      const articles = await getArticlesByTimeDesc();
      this.entries = articles;
      console.info(`[ArticlePage] 旧版 ARTICLE 表数据: ${articles.length} 条`);

      // 如果有数据，默认选中第一篇
      if (notes.length > 0) {
        this.selectId = 0;
      }
    } catch (error) {
      console.error(`[ArticlePage] 加载文章失败: ${JSON.stringify(error)}`);
    } finally {
      this.isLoading = false;
      console.info(`[ArticlePage] 加载完成, noteList.length=${this.noteList.length}, entries.length=${this.entries.length}`);
    }
  }
  aboutToDisappear(): void {
  }
  build() {
    Stack({alignContent:Alignment.Center}) {
      Column(){
        Row() {
        }
        .width("100%")
        .height(100)
        .zIndex(2)
        
        // 加载状态
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(50)
              .height(50)
              .color('#ff00a6ff')
            Text('加载中...')
              .fontSize(14)
              .fontColor('#ff999999')
              .margin({ top: 10 })
          }
          .width("100%")
          .height("100%")
          .justifyContent(FlexAlign.Center)
        } else if (this.noteList.length === 0) {
          // 空数据状态 - 判断 noteList 而不是 entries
          Column() {
            Text('暂无文章')
              .fontSize(16)
              .fontColor('#ff999999')
          }
          .width("100%")
          .height("100%")
          .justifyContent(FlexAlign.Center)
        } else {
          // 文章列表
          List(){
            ForEach(this.noteList,(item:NoteInfo,index:number)=>{
              ListItem(){
                Row({space:15}){
                  Rect()
                    .width(3)
                    .stroke("#ffe0e0e0")
                    .fill(this.selectId == index ? "#ff00a6ff" :"#ffe0e0e0")
                    .height("100%")

                  Text(this.parseDate(item.time || ''))
                    .fontColor(this.selectId == index ? "#ff00a6ff" : "#ffbebcbc")
                    .fontSize(14)
                  Text(item.title || '无标题')
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width(150)
                    .maxLines(1)
                    .fontSize(14)
                  Blank()
                    .layoutWeight(1)
                  Text('ARTICLE')
                    .fontColor("#ffbebcbc")
                    .fontSize(12)
                    .layoutWeight(0)
                }
                .width("90%")
                .height(45)
                .linearGradient(this.selectId == index ? {direction:GradientDirection.Right,colors:[["#3700a6ff",0],["#0000a6ff",0.8],["#0000a6ff",1]]}:undefined)
                .onTouch(() =>{
                  this.selectId = index;
                })
                .onClick(() => {
                  // 点击打开 NotePage
                  this.getUIContext().getRouter().pushUrl({
                    url: 'pages/NotePage',
                    params: {
                      action: NoteAction.SHOW,
                      info: item
                    } as NotePageParams,
                  });
                })
              }
              .width("100%")
              .align(Alignment.Center)
            })
          }
          .width("100%")
          .backgroundColor("#00fffffc")
          .height("100%")
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width("100%")
      .height("100%")
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor("#00ffffff")
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor("#00ffffff")
  }

  private parseDate(date:string):string{
    let timeArray = date.split('-');
    if (timeArray[1].length == 1) {
      timeArray[1] = '0' + timeArray[1];
    }
    if(timeArray[2].length == 1) {
      timeArray[2] = '0' + timeArray[2];
    }
    return timeArray[1] + '/' + timeArray[2];
  }
}