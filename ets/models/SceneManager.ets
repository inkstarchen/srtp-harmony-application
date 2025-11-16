import * as scene3d from '@ohos.graphics.scene'
import { resourceManager } from "@kit.LocalizationKit";
import { BusinessError } from '@kit.BasicServicesKit';
import { Aabb, EnvironmentBackgroundType, Scene, SceneResourceFactory ,Node, Geometry,
  NodeType,
  Vec3,
  Image,
  ToneMappingType,
  Vec2} from "@kit.ArkGraphics3D";
import { NodeManager } from "./NodeManager";
import { LightManager } from "./LightManager";
import { CameraManager } from "./CameraManager";
import { LogUtil } from "../utils/LogUtil";
import { CalcUtils } from "../utils/calutils";
import { AnimationOp, AnimOption, nodeListInfo, rayCastResult } from "./BaseClass";
import { NodeInfo } from "../models/BaseClass";
import { Helper } from "../utils/Helper";
import { display, window } from "@kit.ArkUI";
import { touchManager } from './BaseClass';


@ObservedV2
export class SceneManager{

  uiContext: UIContext | undefined = undefined;
  screenWidth:number = 0;
  screenHeight:number = 0;
  aspect:number = 0;

  dragNode: Node | undefined = undefined;
  rotateNode: Node | undefined = undefined;
  rotateFlag: boolean = false;
  distanceZ: number = 0;
  startPos: Vec2 = {x:0,y:0};

  dot:Vec3 = {x:0,y:0,z:0}
  @Trace touchM: touchManager | undefined = undefined;
  @Trace scene:Scene | undefined = undefined;
  sceneNode: Node | undefined | null = undefined;
  @Trace sceneOption: SceneOptions | undefined  = undefined;
  @Trace nodeManager: NodeManager = new NodeManager();
  @Trace lightManager: LightManager = new LightManager();
  @Trace cameraManager: CameraManager = new CameraManager();
  dragId:number = -1;

  envImg: Image | null = null;

  animationMap: Map<string, Array<number>> = new Map();
  nodeListMap: Map<string, nodeListInfo> = new Map();
  aabbListMap: Map<string,Aabb[]> = new Map();
  dragAbleMap: Map<string,boolean> = new Map();
  rotateAbleMap: Map<string,boolean> = new Map();
  @Trace initFlag:boolean = false;
  availableScenes: Map<string,Resource> = new Map();
  rM: resourceManager.ResourceManager | undefined = undefined;
  rf: SceneResourceFactory | undefined = undefined;
  InfoTrace:number[] = new Array(3).fill(0)
  nodeInfo:NodeInfo | undefined = undefined;
  @Trace realTimeInfo: string = '';

  envImage:Image | null = null;
  radianceMap:Image | null = null;

  constructor(uiContext:UIContext) {
    this.uiContext = uiContext;
    this.init();
  }

  scaleBlock(node:Node){
    if(!this.cameraManager.cam) return;
    node.scale.y = 0.38 * 8 * Math.tan(this.cameraManager.cam?.fov / 2);
    node.scale.x = 0.38 * 8 * Math.tan(this.cameraManager.cam?.fov / 2) * this.aspect;
  }

  GetNode(name:string):Node |undefined |null{
    let nodeInfo = this.nodeListMap.get(name);
    if(!nodeInfo) return undefined;
    let node = this.scene?.getNodeByPath(nodeInfo.path);
    console.info('root.child:' + this.scene?.root?.children.get(0)?.name);
    console.info('getNode Path:' + nodeInfo.path);
    return node;
  }

  Rotate(result: rayCastResult[] | undefined){
    result?.forEach((value,index) => {
      if(value.node && value.position){
        let geom = value.node as Geometry;
        if(geom.mesh.aabb){
          LogUtil.AabbLog(geom)
        }
        let rotateAble = this.rotateAbleMap.get(value.node.name);
        if(rotateAble){
          this.rotateNode = value.node;
          this.rotateFlag = true;
          let index = this.animationMap.get('rotate');
          index?.forEach((value,i) => {
            let anim = this.scene?.animations[value];
            anim?.start();
            anim?.pause();
          })
        }
      }
    })
  }

  Drag(result: rayCastResult[] | undefined){
    result?.forEach((value,index) => {
      if(value.node && value.position){
        let geom = value.node as Geometry;
        if(geom.mesh.aabb){
          LogUtil.AabbLog(geom)
        }
        console.info('RayCast Info | node name: ' + value.node.name + '/ tMin: ' + value.tMin + '/ positionZ:' + value.position.z );
        let dragAble = this.dragAbleMap.get(value.node.name);
        if(dragAble){
          if(this.dragId != -1) return;
          this.dragNode = value.node;
          this.distanceZ = value.position.z;
          this.startPos.x = value.node.position.x;
          this.startPos.y = value.node.position.y;

          let dragId = setInterval(() => {
            console.info('drag Info | drag effect');
            if(!this.dragNode || !this.uiContext) return;
            let distanceSpace = CalcUtils.PlaneSizeToSpaceSize({x:this.uiContext.vp2px(this.touchM?.distance.x),y:this.uiContext.vp2px((this.touchM?.distance.y))},this.distanceZ,Math.PI / 4, this.screenWidth,this.screenHeight);
            this.dragNode.position = {
              x: this.startPos.x + distanceSpace.x,
              y: this.startPos.y - distanceSpace.y,
              z: this.dragNode.position.z
            }
          },5)
          this.dragId = dragId;
        }
      }
    })
  }

  stopDrag(){
    console.info('dragId = ' + this.dragId);
    if(this.dragId != -1){
      console.info('clear dragId = ' + this.dragId);
      if(this.dragNode){
        this.reCalAabb(this.dragNode);
      }
      clearInterval(this.dragId);
      this.dragId = -1;
    }else{
      console.info('dragId end = ' + this.dragId)
    }
  }

  HandleTouch(event: TouchEvent){
    if (event.type == TouchType.Down) {
      this.touchM?.touchDown(event);
      let returnList = this.rayCast(event);
      this.Drag(returnList);
      this.Rotate(returnList);
    }else if(event.type == TouchType.Move) {
      this.touchM?.touchMove(event);
      if(this.rotateFlag && this.rotateNode && this.cameraManager.cam?.fov){
        let oPos = CalcUtils.SpaceToPlane(this.rotateNode.position,this.cameraManager.cam.fov,this.aspect);
        if(this.uiContext){
          let downPos = CalcUtils.pxToNormal({x: this.uiContext.vp2px(this.touchM?.down.x),y: this.uiContext.vp2px(this.touchM?.down.y)},this.screenWidth,this.screenHeight);
          let tPos = CalcUtils.pxToNormal({x: this.uiContext.vp2px(event.touches[0].x),y: this.uiContext.vp2px(event.touches[0].y)},this.screenWidth,this.screenHeight);
          let oAngle = CalcUtils.calAngle(oPos,downPos);
          let tAngle = CalcUtils.calAngle(oPos,tPos);
          console.info('oPos: ' + oPos.x.toFixed(2) + '/' + oPos.y.toFixed(2) +' | tPos: ' + tPos.x.toFixed(2) + '/' + tPos.y.toFixed(2));
          console.info('oAngle: ' + oAngle + '/ tAngle:' + tAngle);
          // NodeManager.setNodeRotation(this.rotateNode,-tAngle / 2);
          let index = this.animationMap.get('rotate');
          index?.forEach((value,i) => {
            let anim = this.scene?.animations[value];
            anim?.seek(tAngle / (2 * Math.PI));
          })
          let brightNess = tAngle / (2 * Math.PI);
          let windowClass:window.Window = AppStorage.get('windowClass') as window.Window;
          windowClass.setWindowBrightness(brightNess, (err: BusinessError) => {
            const errCode: number = err.code;
            if (errCode) {
              console.error(`Failed to set the brightness. Cause code: ${err.code}, message: ${err.message}`);
              return;
            }
            console.info('Succeeded in setting the brightness.');
          });
        }
      }
    }else if(event.type == TouchType.Up){
      let index = this.animationMap.get('rotate');
      index?.forEach((value,i) => {
        let anim = this.scene?.animations[value];
        anim?.pause();
      })
      this.rotateFlag = false;
      this.stopDrag();
    }
  }

  TraverseAll(node:Node,path:string){
    let length = node.children.count();
    let children:string[] = []
    for(let i = 0; i < length ; i++){
      let child = node.children.get(i);
      if(child){
        children.push(child.name);
        if(child.nodeType == NodeType.GEOMETRY){
          let geom = child as Geometry;
          LogUtil.AabbLog(geom);
          if(geom.mesh.aabb){
            console.info('AABB Info | node ' + child.name + ' registered');
            this.aabbListMap.set(child.name, [geom.mesh.aabb,geom.mesh.aabb])
            this.reCalAabb(child)
          }
        }
        let nodePath = path + '/' + child.name;
        console.info('Traversal Info | ' + node.name + ' -> ' + child.name + '/ path: ' + nodePath);
        this.TraverseAll(child,nodePath);
      }
    }
    this.nodeListMap.set(node.name, new nodeListInfo(path,children));
  }

  initScreenData(){
    let displayClass: Array<display.Display> = [];
    display.getAllDisplays((err: BusinessError, data: Array<display.Display>) => {
      displayClass = data;
      this.screenWidth = displayClass[0].width;
      this.screenHeight = displayClass[0].height;
      this.aspect = displayClass[0].width / displayClass[0].height;
      console.info('SceneManager Init Info : ScreenWidth:' + this.screenWidth + ' | ScreenHeight :' + this.screenHeight + ' | aspect: ' + this.aspect);
      const errCode: number = err.code;
      if (errCode) {
        console.error(`Failed to obtain all the display objects. Code: ${err.code}, message: ${err.message}`);
        return;
      }
      console.info(`Succeeded in obtaining all the display objects. Data: ${JSON.stringify(data)}`);
    });
  }

  LightRotate(angle:number){
    if(!this.lightManager.light) return;
    let position: Vec3 = {
      x: 2 * Math.cos(-angle),
      y: 2 * Math.sin(-angle),
      z:3
    }
    CalcUtils.lookAt(this.lightManager.light,position,{x:0,y:0,z:0},{x:0,y:1,z:0});
  }

  async init(file:string = 'undefined'){
    this.initScreenData();
    this.touchM = new touchManager(0);
    let common = this.uiContext?.getHostContext();
    if(common){
      this.rM = common.resourceManager
    }
    const resource = $rawfile('1/assets/default.scene');

    scene3d.Scene.load(resource).then(async (scene: Scene) => {
      this.scene = scene;
      this.cameraManager.cam = this.scene.root?.getNodeByPath("Perspective Camera") as scene3d.Camera;
      this.cameraManager.cam.enabled = true;
      this.cameraManager.cam.postProcess = {toneMapping:{
        exposure:1,
        type:ToneMappingType.ACES
      }};
      this.cameraManager.cameraInfo?.copyFromNode(this.cameraManager.cam);
      this.lightManager.light = this.scene.root?.getNodeByPath("Spot Light") as scene3d.SpotLight;
      this.lightManager.light.enabled = true;
      this.lightManager.lightInfo?.copyFromNode(this.lightManager.light);
      console.info('camera Info | ' + this.cameraManager.cameraInfo?.toString());
      console.info('light Info | ' + this.lightManager.lightInfo?.toString());

      this.sceneOption = { scene: this.scene, modelType: ModelType.SURFACE };
      this.rf = this.scene.getResourceFactory();
      this.envImg = await this.rf.createImage({
        name: 'envImg',
        uri: $rawfile('quarry_02_2k_skybox.ktx')
      });
      this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_CUBEMAP;
      this.scene.environment.environmentImage = this.envImg;
      if(this.scene.root){
        this.TraverseAll(this.scene.root, '');
      }

      this.createAnimationMap();
      this.dragAbleMap.set('block',true);
      this.rotateAbleMap.set('旋钮',true);
      if(this.cameraManager.cam?.rotation){
        this.cameraManager.cam.rotation= {x:0,y:0,z:0,w:1};
      }
    })
    console.info('yes loading success!')

    if(this.rf){
      console.info('try to create image')
      this.envImage = await this.rf.createImage({
        name: 'envImage',
        uri: $rawfile('3D/env/quarry_02_2k_skybox.ktx')
      });

      console.info('check here')
      if(this.scene) {
        this.scene.environment.environmentMapFactor = {x:1,y:1,z:1,w:1}
        this.scene.environment.indirectDiffuseFactor = {x:1,y:1,z:1,w:1};
        this.scene.environment.indirectSpecularFactor = {x:1,y:1,z:1,w:1};
      }
    }

    this.nodeInfo = new NodeInfo('',{x:0,y:0,z:0},{x:0,y:1,z:0,w:0},1)
  }

  startInfoTrace(){
    if(this.InfoTrace[0] != 0) return;
    this.InfoTrace[0] = setInterval(() => {
      if(!this.nodeInfo || !this.nodeManager.node) return;
      this.nodeInfo.copyFromNode(this.nodeManager.node);
      this.realTimeInfo = this.nodeInfo.toString();
      if(this.cameraManager.cam){
        let v2 = CalcUtils.SpaceToPlane(this.nodeManager.node.position,this.cameraManager.cam.fov,this.aspect)
        this.realTimeInfo += '\n' + v2.x * this.screenWidth + '/' + v2.y * this.screenHeight ;
      }
    },25)
  }

  stopInfoTrace(){
    Helper.clearIntervalArray(this.InfoTrace,0);
  }

  rayCast(event:TouchEvent):rayCastResult[] | undefined{
    console.info('rayCast 1');
    if(!this.uiContext || !this.cameraManager.cam) return;
    console.info('rayCast 2');
    let Px = this.uiContext.vp2px(event.touches[0].windowX) / this.screenWidth * 2 - 1;
    let Py = 1 - this.uiContext.vp2px(event.touches[0].windowY) / this.screenHeight * 2;

    // console.info('RayCast Info : Dot position Px: ' + Px + '/Py :' + Py);
    console.info('camera Info : ' +this.cameraManager.cam.rotation.x + '/' + this.cameraManager.cam.rotation.y + '/' +
    this.cameraManager.cam.rotation.z + '/' + this.cameraManager.cam.rotation.w);
    let ray = CalcUtils.CalRayFromCam(this.cameraManager.cam, this.aspect, Px, Py);
    let results: rayCastResult[] = new Array();
    this.aabbListMap.forEach((value:Aabb[],key:string) => {
      // console.info('raycast Info | check node : ' + key);
      LogUtil.AabbLog(undefined,value[1])
      let result = CalcUtils.calRayCast(value[1],ray);
      if(result.flag == true){
        // console.info('raycast Info | check node : ' + key +'/true')
        let nodeInfo = this.nodeListMap.get(key);
        if(nodeInfo){
          let node = this.scene?.getNodeByPath(nodeInfo.path);
          if(node){
            results.push(new rayCastResult(node, result));
          }
        }
      }
    })
    results.sort((a:rayCastResult,b:rayCastResult) => a.tMin - b.tMin);
    return results;
  }

  reCalAabb(node:Node){
    let nodeInfo = this.nodeListMap.get(node.name);
    let children = nodeInfo?.children;
    let parentContainer = this.aabbListMap.get(node.name);
    if(parentContainer && node.parent){
      parentContainer[1] = CalcUtils.calAabb(node,CalcUtils.calAabb(node.parent,parentContainer[0],1),node.scale.x);
    }
    if(!children) return;
    children.forEach((value:string) => {
      if(!this.sceneNode) return;
      let container = this.aabbListMap.get(value);
      if(container){
        let child = this.sceneNode.getNodeByPath(value);
        if(child){
          container[1] = CalcUtils.calAabb(child,CalcUtils.calAabb(node,container[0],1),node.scale.x)
        }
        let geom = child as Geometry;
        LogUtil.AabbLog(undefined,container[1]);
      }
    })
  }

  async searchScene(topPath:string) {
    if (!this.rM) return;
    let waitingQueue:string[] = [topPath];
    while(waitingQueue.length != 0){
      let path = waitingQueue.pop();
      await this.rM.getRawFileList(path).then((values) => {
        values.forEach((value:string,index:number) =>{
          let str = value.split('.');
          console.info('glb search info : \n' + value);
          if(str.length == 1){
            waitingQueue.push(path + '/' + str[0]);
          }else{
            if(str[1] == 'glb' || str[1] == 'gltf'){
              this.availableScenes.set(str[0],{
                id:0,
                bundleName:'com.example.note',
                moduleName:'entry',
                type:30000,
                params:[path + '/' + value]
              } as Resource)
            }
          }
        })
      })
    }
  }

  createAnimationMap(){
    if(this.scene && this.scene.animations.length != 0){
      for(let i = 0 ; i < this.scene.animations.length ; i++){
        const animationName = this.scene.animations[i].name;
        let indexArray = this.animationMap.get(animationName);
        if(indexArray == undefined){
          indexArray = [i];
        }else{
          indexArray.push(i);
        }
        this.animationMap.set(animationName,indexArray);
        console.info('Animation Info | register animation name: ' + this.scene.animations[i].name + '/ index: ' + i);
      }
    }
  }

  operateAnimation(name:string, options:AnimOption){
    if(options.opt == AnimationOp.SEEK && options.percent == undefined){
      console.info('Animation Info | seek operation need percent!');
      return;
    }
    if((options.opt == AnimationOp.ON_FINISHED || options.opt == AnimationOp.ON_STARTED) && options.callBack == undefined){
      console.info('Animation Info | set callback need function!');
      return;
    }
    const indexArray = this.animationMap.get(name);
    if(indexArray == undefined){
      console.info('Animation Info | can not find animation named ' + name);
      return;
    }
    indexArray.forEach((index,i) => {
      let anim = this.scene?.animations[index];
      switch (options.opt){
        case AnimationOp.START:{
          anim?.start();
          break;
        }
        case AnimationOp.STOP:{
          anim?.stop();
          break;
        }
        case AnimationOp.PAUSE:{
          anim?.pause();
          break;
        }
        case AnimationOp.SEEK:{
          anim?.seek(options.percent);
          break;
        }
        case AnimationOp.RESTART:{
          anim?.restart();
          break;
        }
        case AnimationOp.FINISH:{
          anim?.finish();
          break;
        }
        case AnimationOp.ON_FINISHED:{
          anim?.onFinished(options.callBack);
          break;
        }
        case AnimationOp.ON_STARTED:{
          anim?.onStarted(options.callBack);
          break;
        }
        default :break;
      }
    })

  }
}