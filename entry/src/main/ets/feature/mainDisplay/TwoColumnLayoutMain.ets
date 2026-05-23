import { SceneProxy } from "../../core/scene3D/GlobalSceneProxy"
import { Constants } from "../../shared/constants";
import { SHADOW_FLOAT, UIInfo } from "../../shared/ui/uiUtils"
import { DateItem, SlidingDateModel } from "../../shared/utils/Time/SlideTimeModel";
import { CardDisplay2D } from "../note/component/CardDisplay/CardDisplay2D";
import { SendBox } from "../note/component/SendBox/SendBox";
import { WorkSpace } from "../note/component/WorkSpace/WorkSpace";
import { NoteInfo } from "../note/NoteState";
import { SlideList } from "../SlideList/SlideList";
import { Node, Vec2 } from "@kit.ArkGraphics3D";
import { ToolSideBar } from "../note/component/toolBar/ToolSideBar";
import { AnimatorResult, matrix4 } from "@kit.ArkUI";
import { NoteViewModel } from "../note/NoteViewModel";
import { CalendarComponent } from "../calendar/Calendar";
import { RotationMapper, SphereLayoutInfo } from "../../core/scene3D/layout/SphereLayout";
import { RotationState } from "../../shared/utils/TouchManager";

export enum TimeState {
  STATE_1 = 0,
  STATE_2 = 1
}

export enum WorkSpaceState{
  SPHERE_LAYOUT = 0,
  PLANE_LAYOUT = 1
}

@ComponentV2
export struct TwoColumnLayout{
  @Local workSpaceState: WorkSpaceState = WorkSpaceState.SPHERE_LAYOUT;

  replaceId:number = 0;
  rotationMapper: RotationMapper = new RotationMapper(10);
  rotationState:RotationState = {latitude:0,longitude:0};
  @Local sphereEntities: SphereLayoutInfo[] = [];
  @Local timeToId: Map<string, number> = new Map();

  @Local editingNow: boolean = false;
  @Local editingNext: boolean = false;
  targetIndex: number = -1;
  nextIndex: number = -1;
  @Local currentNoteViewModel: NoteViewModel | undefined = undefined;

  @Local uiEntities: UIInfo[] = [];
  @Local NoteInfos: NoteInfo[] = [];
  @Local selectedData: DateItem = SlidingDateModel.createItem(new Date(), 0);
  @Local needFreshDate: boolean = false;
  @Local needFreshNote: boolean = false;
  @Local needFreshAll: boolean = false;
  @Local timeState:TimeState = TimeState.STATE_1;

  @Local toolBarAnim: AnimatorResult = this.getUIContext().createAnimator(Constants.ANIMATION_OPTION_QUICK);
  @Local toolBarOffset: number = SceneProxy.sceneSize.height - SceneProxy.sceneSize.width;
  aboutToAppear(): void {

  }

  build(){
    Row(){
      Stack({alignContent:Alignment.TopStart}){
        Column(){
          Column(){
            CalendarComponent({
              timeState: this.timeState
            })
            Row(){
              Button("工具")
                .onClick(() => {
                  this.toolBarAnim.onFrame = (progress) => {
                    this.toolBarOffset = (1-progress) * (SceneProxy.sceneSize.height - SceneProxy.sceneSize.width);
                  }
                  this.toolBarAnim.play();
                })
                .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
                .border(Constants.MD_BORDER)
                .fontSize(Constants.buttonFontSize)
                .fontColor("#fff")
                .backgroundColor('#ff000000' )
                .width(Constants.buttonWidth)
                .height(Constants.buttonHeight)
                .opacity(this.timeState == TimeState.STATE_1 ? (this.editingNow ? 1 : 0) : 0)
                .animation({
                  duration:500,
                  curve:Curve.EaseInOut,
                  delay:0,
                  iterations:1
                })
                .layoutWeight(0)
              Column(){
                SlideList({
                  setItem: (item: DateItem) => {
                    this.selectedData.timestamp = item.timestamp;
                    this.needFreshDate = true;
                  }
                })
              }
              .opacity(this.timeState == TimeState.STATE_1 ? 1 : 0)
              .animation({
                duration:500,
                curve:Curve.EaseInOut,
                delay:0,
                iterations:1
              })
              .height("100%")
              .layoutWeight(1)

              Button(){
                SymbolGlyph($r("sys.symbol.chevron_right"))
                  .fontSize(30)
                  .fontColor([Color.Black])
              }
              .onClick(() => {
                if(this.timeState == TimeState.STATE_1){
                  this.timeState = TimeState.STATE_2;
                }else{
                  this.timeState = TimeState.STATE_1
                }
              })
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
              .border(Constants.MD_BORDER)
              .shadow(SHADOW_FLOAT)
              .fontSize(Constants.buttonFontSize)
              .backgroundColor('#ffffffff' )
              .width(Constants.buttonHeight)
              .height(Constants.buttonHeight)
              .transform( this.timeState == TimeState.STATE_1 ? matrix4.identity().rotate({
                x: 0,
                y: 0,
                z: 1,   // z轴为1，代表在屏幕平面内旋转
                angle: 90
              }) :  matrix4.identity().rotate({
                x: 0,
                y: 0,
                z: 1,   // z轴为1，代表在屏幕平面内旋转
                angle: 270
              }))
              .animation({
                duration:300,
                curve:Curve.EaseInOut,
                delay:0,
                iterations:1
              })
              .layoutWeight(0)
            }
            .backgroundColor("#fff")
            .zIndex(200)
            .width("100%")
            .padding({left:20,right:20})
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
            .height(80)
          }
          .backgroundColor("#fff")
          .zIndex(200)
          .shadow({radius:15,color:"#ffa4a4a4",offsetY:10,offsetX:0})
          .layoutWeight(0)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          Column(){
            CardDisplay2D({
              noteClicked:(info:NoteInfo) => {
                this.LoadNoteEntity(info);
              },
              selectedData:this.selectedData,
              needsFresh: this.needFreshNote,
              needFreshDate: this.needFreshDate,
              needsFreshAll: this.needFreshAll,
              FreshDateFinished: () => {
                this.needFreshDate = false;
              },
              FreshFinished: ()=> {
                this.needFreshNote = false;
              },
              FreshAllFinished: () => {
                this.needFreshAll = false;
              }
            })
          }
          .zIndex(100)
          .width("100%")
          .layoutWeight(1)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])

          Column(){
            SendBox({
              needsFreshNote:() => {
                this.needFreshNote = true;
              }
            })
          }
          .zIndex(200)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          .height("25%")
          .width("100%")
          .padding(15)
          .backgroundColor("#00ffffff")
          .layoutWeight(0)
        }
        .width("100%")
        .height("100%")
        .backgroundColor("#fff")
        .shadow({color:"#ffaeaeae",radius:20,offsetX:10,offsetY:0})
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])

        Column(){
          Row(){
            Button("返回")
              .onClick(() => {
                this.toolBarAnim.onFrame = (progress) => {
                  this.toolBarOffset = progress * (SceneProxy.sceneSize.height - SceneProxy.sceneSize.width);
                }
                this.toolBarAnim.play();
              })
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
              .border(Constants.MD_BORDER)
              .fontSize(Constants.buttonFontSize)
              .fontColor("#fff")
              .backgroundColor('#ff000000' )
              .width(Constants.buttonWidth)
              .height(Constants.buttonHeight)
              .layoutWeight(0)
            Blank()
              .layoutWeight(1)
              .height("100%")
            Text(this.currentNoteViewModel?.saveStatus)
              .fontSize(12)
              .fontColor(Color.Black)
              .margin({ right: 8 })
              .height("100%")
              .layoutWeight(0)
              .opacity(this.currentNoteViewModel?.saveStatus ? 1 : 0)
              .animation({ duration: 300 })
            Button("保存")
              .onClick(() => {
                this.currentNoteViewModel?.saveNote();
                this.needFreshAll = true;
              })
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
              .border(Constants.MD_BORDER)
              .fontSize(Constants.buttonFontSize)
              .fontColor("#fff")
              .backgroundColor('#ff000000' )
              .width(Constants.buttonWidth)
              .height(Constants.buttonHeight)
              .layoutWeight(0)

          }
          .backgroundColor("#fff")
          .zIndex(200)
          .width("100%")
          .padding({left:20,right:20})
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          .height(this.timeState == TimeState.STATE_1 ? "10%" : "30%")
          .layoutWeight(0)
          Column(){
            ToolSideBar({
              noteViewModel:this.currentNoteViewModel
            })
          }
          .width("100%")
          .layoutWeight(1)
        }
        .width("100%")
        .height("100%")
        .backgroundColor("#fff")
        .zIndex(200)
        .shadow({color:"#ffaeaeae",radius:20,offsetX:10,offsetY:0})
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .translate({x:this.getUIContext().px2vp(this.toolBarOffset)})
      }
      .layoutWeight(1)
      .height("100%")
      .zIndex(200)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      .backgroundColor("#fff")
      Stack({alignContent:Alignment.TopStart}){

        WorkSpace({
          workSpaceState:this.workSpaceState,
          rotationMapper:this.rotationMapper,
          sphereEntities:this.sphereEntities,
          rotation:this.rotationState,
          setRotationState:(state) => {
            this.rotationState.longitude = state.longitude;
            console.info("longitude" + this.rotationState.longitude);
          },
          setEditing:(editing,noteViewModel,index) => {
            if(this.targetIndex == -1 && editing){
              this.editingNow = true;
              this.currentNoteViewModel = noteViewModel;
              this.targetIndex = index;
            }else{
              if(this.targetIndex != index){
                if(editing){
                  this.currentNoteViewModel = noteViewModel;
                  this.nextIndex = index;
                }
              }else{
                if(!editing){
                  setTimeout(()=>{
                    console.info("check editing" + this.targetIndex.toString() + this.nextIndex.toString() + (this.editingNow ? "true" : "false") + (this.editingNext ? "true" : "false"))
                    if(this.targetIndex != this.nextIndex && this.nextIndex != -1){
                      this.targetIndex = this.nextIndex;
                    }else if(this.targetIndex == index && this.editingNext){
                      this.editingNow = true;
                      this.editingNext = false;
                    }else{
                      this.editingNow = false;
                      if(this.toolBarOffset !== SceneProxy.sceneSize.height - SceneProxy.sceneSize.width){
                        this.toolBarAnim.onFrame = (progress) => {
                          this.toolBarOffset = progress * (SceneProxy.sceneSize.height - SceneProxy.sceneSize.width);
                        }
                        this.toolBarAnim.play();
                      }
                      this.targetIndex = -1;
                    }
                  },100)
                }else{
                  this.editingNext = true;
                }
              }
            }
          },
          setUIInfo:(pos:Vec2 | undefined = undefined,size:Vec2 | undefined = undefined,index:number) => {
            if(pos){
              this.uiEntities[index].pos.x = pos.x;
              this.uiEntities[index].pos.y = pos.y;
            }
            if(size){
              this.uiEntities[index].size.x = size.x;
              this.uiEntities[index].size.y = size.y;
            }
            SceneProxy.syncUI(this.uiEntities[index].id,this.uiEntities[index])
          },
          uiEntities:this.uiEntities,
          NoteInfos:this.NoteInfos
        })

        Button(this.workSpaceState == WorkSpaceState.SPHERE_LAYOUT ? "环球展示" : "平铺展示")
          .onClick(() => {
            if(this.workSpaceState == WorkSpaceState.SPHERE_LAYOUT){
              this.workSpaceState = WorkSpaceState.PLANE_LAYOUT;
              this.replaceId = 0;
              this.timeToId.clear();
              this.sphereEntities = [];
            }else{
              this.workSpaceState = WorkSpaceState.SPHERE_LAYOUT;
              this.uiEntities.forEach((info,index) => {
                SceneProxy.removeNode(SceneProxy.uiToNodeIdMap.get(info.id) as Node);
              })
              this.uiEntities = [];
              SceneProxy.uiToNodeIdMap.clear();
            }
            this.NoteInfos = [];

          })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          .border(Constants.MD_BORDER)
          .fontSize(Constants.buttonFontSize)
          .fontColor(this.workSpaceState == WorkSpaceState.SPHERE_LAYOUT ? "#ff000000":"#fff")
          .backgroundColor(this.workSpaceState == WorkSpaceState.SPHERE_LAYOUT ? '#fff':'#ff000000' )
          .width(LayoutPolicy.wrapContent)
          .height(Constants.buttonHeight)
          .margin(20)
      }
      .backgroundColor("#ffffffff")
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      .width(this.getUIContext().px2vp(SceneProxy.sceneSize.height))
      .height(this.getUIContext().px2vp(SceneProxy.sceneSize.height))
      .zIndex(50)
    }
    .onTouch(() => {
      SceneProxy.SceneProxyInit(this.getUIContext());
    })
    .alignItems(VerticalAlign.Top)
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }

  LoadNoteEntity(info:NoteInfo){
    switch (this.workSpaceState){
      case WorkSpaceState.SPHERE_LAYOUT:{
        if(this.timeToId.get(info.time as string) == undefined || this.timeToId.get(info.time as string) == -1){
          if(this.NoteInfos.length < this.rotationMapper.count){
            this.sphereEntities.push(new SphereLayoutInfo(this.rotationState.longitude,this.rotationMapper.getPointById(this.replaceId)?.angle as number));
            this.timeToId.set(info.time as string, this.replaceId);
            this.replaceId = (this.replaceId + 1) % this.rotationMapper.count;
            this.NoteInfos.push(info)
          }else{
            this.timeToId.set(this.NoteInfos[this.replaceId].time as string, -1);
            this.NoteInfos[this.replaceId] = info;
            this.replaceId = (this.replaceId + 1) % this.rotationMapper.count;
          }
        }
        break;
      }
      case WorkSpaceState.PLANE_LAYOUT:{
        let infoTemp: UIInfo = new UIInfo({x:SceneProxy.center.x -200,y:SceneProxy.center.y - 400},{x:600,y:800},info.time as string);
        console.info("info time" + info.time);
        if(SceneProxy.uiToNodeIdMap.get(info.time as string) == undefined){
          SceneProxy.addUIPlane(info.time as string,infoTemp);
          this.uiEntities.push(infoTemp);
          this.NoteInfos.push(info);
        }
        break;
      }
      default : break;
    }
  }
}