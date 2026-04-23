import { SceneProxy } from "../core/scene3D/GlobalSceneProxy";
import { ArticleEntry } from "../feature/DataStorage/datastore"

@Preview
@ComponentV2
export struct ArticlePage{
  @Local selectId: number = 1;
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  @Local entries: ArticleEntry[] = [{title:"从零到一的笔记库开发",date:"2026-4-14",type:"手记"},
    {title:"从零到一的",date:"2026-4-15",type:"手记"},
    {title:"从零到一的笔记库开发",date:"2026-4-12",type:"手记"},
    {title:"从零到一的笔记",date:"2026-4-1",type:"手记"},
    {title:"从",date:"2026-4-11",type:"手记"}];


  aboutToAppear(): void {
    // this.sceneProxy.loadScene('emptyscene',this.getUIContext());
    this.sceneProxy.loadSceneFromDefault();
  }
  aboutToDisappear(): void {
    this.sceneProxy.releaseScene();
  }
  build() {
    Stack({alignContent:Alignment.Center}) {
      Column(){
        Row() {
        }
        .width("100%")
        .height(100)
        .zIndex(2)
        List(){
          ForEach(this.entries,(item:ArticleEntry,index:number)=>{
            ListItem(){
              Row({space:15}){
                Rect()
                  .width(3)
                  .stroke("#ffe0e0e0")
                  .fill(this.selectId == index ? "#ff00a6ff" :"#ffe0e0e0")
                  .height("100%")

                Text(this.parseDate(item.date))
                  .fontColor(this.selectId == index ? "#ff00a6ff" : "#ffbebcbc")
                  .fontSize(14)
                Text(item.title)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width(150)
                  .maxLines(1)
                  .fontSize(14)
                Blank()
                  .layoutWeight(1)
                Text(item.type)
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
            }
            .width("100%")
            .align(Alignment.Center)
          })
        }
        .width("100%")
        .backgroundColor("#00fffffc")
        .height("100%")
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .width("100%")
      .height("100%")
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .backgroundColor("#00ffffff")
      Column(){
        // Column(){
        //
        // }
        // .width("100%")
        // .height(100)
        // .layoutWeight(0)
        if(this.sceneProxy.options){
          Component3D(this.sceneProxy.options)
            .renderWidth('100%')
            .renderHeight('100%')
            .hitTestBehavior(HitTestMode.None)
            .backgroundColor("#00ffffff")
        }

      }
      .backgroundColor("#00ffffff")
      .id('3D')
      .width("100%")
      .height("100%")

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