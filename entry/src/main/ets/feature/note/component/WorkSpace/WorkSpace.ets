import { TraceVec2 } from "../../../../core/math/vec";
import { Camera, Quaternion, Vec2 } from "@kit.ArkGraphics3D";
import { SceneProxy } from "../../../../core/scene3D/GlobalSceneProxy";
import { AnimatorResult, matrix4, Prompt } from "@kit.ArkUI";
import { Constants } from "../../../../shared/constants";
import { captureAndDisplay } from "../../../../core/scene3D/ImageTo3D";
import { UIInfo } from "../../../../shared/ui/uiUtils";
import { NoteEditCard } from "../NoteEditCard/NoteEditCard";
import { NoteInfo } from "../../NoteState";
import { MoveManager } from "../../../../shared/utils/MoveManager";
import { NoteViewModel } from "../../NoteViewModel";
import { RotationState, RotationTouchManager } from "../../../../shared/utils/TouchManager";
import { applyDeltaRotation, eulerToQuaternion, getCurrentRotation,
  normalizeQuaternion } from "../../../../core/math/mathUtil";
import { RotationMapper,
  SphereLayoutInfo,
  SpherePoint, SpherePointGenerator} from "../../../../core/scene3D/layout/SphereLayout";
import { WorkSpaceState } from "../../../mainDisplay/TwoColumnLayoutMain";

const XVP:number = 600;
const YVP:number = 400;

@ComponentV2
export struct WorkSpace{
  @Require @Param workSpaceState: WorkSpaceState;
  @Require @Param rotationMapper: RotationMapper;
  @Require @Param sphereEntities: SphereLayoutInfo[];
  rotationManager: RotationTouchManager = new RotationTouchManager();
  @Require @Param rotation: RotationState;
  @Event setRotationState:(state:RotationState) => void;

  quaternion: Quaternion = {x:0,y:0,z:0,w:1};
  @Local testMatrix: Matrix4Transit = matrix4.identity();
  @Local testZIndex: number = 100;

  moveManager:MoveManager = new MoveManager();
  context:UIContext = this.getUIContext();
  @Local sceneProxy: SceneProxy = SceneProxy.getInstance();
  @Require @Param uiEntities: UIInfo[];
  @Require @Param NoteInfos: NoteInfo[];
  @Local temp_x: number = 0;
  @Local anim: AnimatorResult = this.getUIContext().createAnimator(Constants.ANIMATION_OPTION_2);

  @Event setUIInfo:(pos:Vec2 | undefined,size:Vec2 | undefined,index:number) => void;
  @Event setEditing:(editing:boolean,noteViewModel:NoteViewModel,index:number) => void;
  
  @Monitor("workSpaceState")
  onChange(monitor:IMonitor){
    if ((monitor.value()?.now as WorkSpaceState) == WorkSpaceState.SPHERE_LAYOUT) {
      this.sceneProxy.setPosition("ball",{x:0,y:0,z:-2});
      this.sceneProxy.setPosition("Plane",{x:0,y:20,z:0})
      this.sceneProxy.setPosition("Cube",{x:0,y:-10,z:-0.6})
    }else{
      this.sceneProxy.setPosition("Plane",{x:0,y:0,z:0})
      this.sceneProxy.setPosition("ball", {x:0,y:20,z:0});
      this.sceneProxy.setPosition("Cube",{x:0,y:-2,z:-0.6});
    }
  }
  
  async aboutToAppear(): Promise<void> {
    // if(this.sceneProxy.scene) Prompt.showToast({message:"already have scene"});
    await this.sceneProxy.LoadPhotoWall();
    await this.sceneProxy.addCube();
    // await this.sceneProxy.addBall();
    let config = this.sceneProxy.getCameraConfig()
    if(config){
      this.sceneProxy.physicalSystem.enableLayout(this.sceneProxy.camera as Camera);
      console.info("enableLayout System");
    }
    this.sceneProxy.enableRotateRequest = true;
  }

  aboutToDisappear(): void {
    this.sceneProxy.releaseScene();
  }
  build(){
    Stack({alignContent:Alignment.Center}){
      if(this.sceneProxy.options){
        Column(){
          Component3D(this.sceneProxy.options)
            .renderWidth("100%")
            .renderHeight("100%")
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
            .hitTestBehavior(HitTestMode.None)
            .id("3D")
        }
        .backgroundColor("#00ffffff")
        .justifyContent(FlexAlign.Center)
        .zIndex(50)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .width(this.getUIContext().px2vp(SceneProxy.sceneSize.height))
        .height(this.getUIContext().px2vp(SceneProxy.sceneSize.height))
      }

      if(this.workSpaceState == WorkSpaceState.SPHERE_LAYOUT){
        ForEach(this.NoteInfos, (info:NoteInfo, index:number) => {
          Column(){
            Column(){
              NoteEditCard({
                safeTrans:false,
                info,
                handleMove:(event) =>{
                  this.handleMoveCard(event,index);
                },
                setEditing:(editing,noteViewModel) => {
                  this.setEditing(editing,noteViewModel,index);
                }
              })
            }
            .backgroundColor("#fff")
            .opacity(this.sphereEntities[index].expand ? 1 : 0)
            .justifyContent(FlexAlign.Center)
            .height(400)
            .width(240)
          }
          .justifyContent(FlexAlign.Center)
          .width(this.sphereEntities[index].expand ? 240 : 40)
          .height(this.sphereEntities[index].expand ? 400 : 40)
          .translate({y:this.sphereEntities[index].expand ? -300 : 0})
          .animation({duration:500})
          .clip(true)
          .backgroundColor("#ffffffff")
          .zIndex(this.sphereEntities[index].zIndex)
          .transform3D(this.sphereEntities[index].translateMatrix)
        })
      }

      if(this.workSpaceState == WorkSpaceState.PLANE_LAYOUT){
        Stack({alignContent:Alignment.TopStart}){
          ForEach(this.uiEntities,(uiInfo:UIInfo,index:number) => {
            Column({space:0}){
              NoteEditCard({
                info:this.NoteInfos[index],
                handleMove:(event) =>{
                  this.handleMoveCard(event,index);
                },
                setEditing:(editing,noteViewModel) => {
                  this.setEditing(editing,noteViewModel,index);
                }
              })
            }
            .backgroundColor("#fff")
            .justifyContent(FlexAlign.Start)
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
            .translate({x:this.getUIContext().px2vp(uiInfo.pos.x - SceneProxy.uiPos.x),y:this.getUIContext().px2vp(uiInfo.pos.y - SceneProxy.uiPos.y)})
            .width(this.getUIContext().px2vp(uiInfo.size.x))
            .height(this.getUIContext().px2vp(uiInfo.size.y))
          })
        }
        .width("100%")
        .height("100%")
        .zIndex(500)
        .hitTestBehavior(HitTestMode.None)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
      }



    }
    .width("100%")
    .height("100%")
    .backgroundImageSize({width:SceneProxy.sceneSize.height.toString() + "px",height:SceneProxy.sceneSize.height.toString() + "px"})
    .backgroundImage($r("app.media.space"))
    .onTouch((event) => {
      if(this.workSpaceState == WorkSpaceState.SPHERE_LAYOUT){
        this.handleRotation(event);
      }
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }

  handleRotation(event:TouchEvent){
    if(event.type == TouchType.Down){
      this.rotationManager.start({x:event.touches[0].x,y:event.touches[0].y});
    } else if(event.type == TouchType.Move){
      let dis = this.rotationManager.move({x:event.touches[0].x, y:event.touches[0].y});
      let xAngle = dis.x / XVP * 180;
      let yAngle = 0;
      let quaterionTemp = applyDeltaRotation(this.quaternion,-yAngle,xAngle);
      this.sceneProxy.setRotation("ball",quaterionTemp);
      this.setRotationState(getCurrentRotation(quaterionTemp));
      // this.testMatrix = this.transformMatrixUtil.getCardTransformMatrix(this.rotationMapper.getPointById(0) as SpherePoint,this.rotation);
      let expandTemp:boolean[] = [];
      this.sphereEntities.forEach((item) => {
        item.update(this.rotation.longitude);
      })
    } else {
      let dis = this.rotationManager.move({x:event.touches[0].x, y:event.touches[0].y});
      let xAngle = dis.x / XVP * 180;
      let yAngle = 0;
      this.quaternion = normalizeQuaternion(applyDeltaRotation(this.quaternion,-yAngle,xAngle));
      this.setRotationState(getCurrentRotation(this.quaternion));
    }
  }

  handleMoveCard(event:TouchEvent,index:number){
    if(event.type == TouchType.Down){
      this.moveManager.targetIndex = index;
      this.moveManager.start(this.uiEntities[index].pos,
        {x:this.context.vp2px(event.touches[0].x),y:this.context.vp2px(event.touches[0].y)});
    } else if(event.type == TouchType.Move){
      this.setUIInfo(this.moveManager.move({x:this.context.vp2px(event.touches[0].x),y:this.context.vp2px(event.touches[0].y)}),undefined,index);
    }else{

    }
  }
}