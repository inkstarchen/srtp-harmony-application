import * as scene3d from '@ohos.graphics.scene'
import { resourceManager } from "@kit.LocalizationKit";
import { Aabb, EnvironmentBackgroundType, Scene, SceneResourceFactory ,Node, Geometry,
  NodeType,
  Vec3,
  Image,
  ToneMappingType,
  Vec2,
  RaycastParameters} from "@kit.ArkGraphics3D";
import { NodeManager } from "./NodeManager";
import { LightManager } from "./LightManager";
import { CameraManager } from "./CameraManager";
import { LogUtil } from "../utils/LogUtil";
import { CalcUtils } from "../utils/calutils";
import { AnimationOp, AnimOption, nodeListInfo, NodeState, Ray, rayCastResult } from "../utils/BaseClass";
import { NodeInfo } from "../utils/InfoClass";
import { Helper } from "../utils/Helper";

@ObservedV2
export class SceneManager{

  screenWidth:number = 0;
  screenHeight:number = 0;
  scaleWH:number = 0;
  dot:Vec3 = {x:0,y:0,z:0}
  @Trace scene:Scene | undefined = undefined;
  sceneNode: Node | undefined | null = undefined;
  @Trace sceneOption: SceneOptions | undefined  = undefined;
  @Trace nodeManager: NodeManager = new NodeManager();
  @Trace lightManager: LightManager = new LightManager();
  @Trace cameraManager: CameraManager = new CameraManager();
  dragId:number = -1;

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
  TickArray:NodeState[] = new Array();
  TickId:number = 0;
  nodeInfo:NodeInfo | undefined = undefined;
  @Trace realTimeInfo: string = '';

  envImage:Image | null = null;
  radianceMap:Image | null = null;

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

  startTick(interval:number){
    if(this.TickId != 0) return;
    this.TickId = setInterval(() => {
      this.TickArray.forEach((nodeState,index) => {
        if(!nodeState.node) return;
        if(nodeState.velocity){
          nodeState.node.position.x = nodeState.node.position.x + nodeState.velocity.x * 0.001 * interval;
          nodeState.node.position.y = nodeState.node.position.y + nodeState.velocity.y * 0.001 * interval;
          nodeState.node.position.z = nodeState.node.position.z + nodeState.velocity.z * 0.001 * interval;
        }
      })
    },interval)
  }

  stopTick(){

  }

  async init(common: Context | undefined = undefined,file:string = 'undefined'){
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
      this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_IMAGE;
      if(this.scene.root){
        this.TraverseAll(this.scene.root, '');
      }

      // let viewPos: Vec2 = { x: 0, y: 1 };
      // let raycastParams: RaycastParameters = {};
      // if (this.scene.root) {
      //   raycastParams.rootNode = this.scene.root;
      // }
      // let results = await this.cameraManager.cam.raycast(viewPos, raycastParams);
      // results.forEach((raycastResult,index) =>{
      //   console.info('raycast Info | ' + raycastResult.node.name + '/' + raycastResult.hitPosition.x.toFixed(2) + '/' + raycastResult.hitPosition.y.toFixed(2))
      // })
      this.createAnimationMap();
      this.dragAbleMap.set('block',true);
      this.rotateAbleMap.set('柱体.001',true);
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
[]
        this.scene.environment.environmentMapFactor = {x:1,y:1,z:1,w:1}
        this.scene.environment.indirectDiffuseFactor = {x:1,y:1,z:1,w:1};
        this.scene.environment.indirectSpecularFactor = {x:1,y:1,z:1,w:1};
      }
    }

    this.nodeInfo = new NodeInfo('',{x:0,y:0,z:0},{x:0,y:1,z:0,w:0},1)
    if(this.sceneOption){
      console.info('option info | yes')
    }else{
      console.info('option info | no')
    }
    this.initFlag = true;
  }

  startInfoTrace(){
    if(this.InfoTrace[0] != 0) return;
    this.InfoTrace[0] = setInterval(() => {
      if(!this.nodeInfo || !this.nodeManager.node) return;
      this.nodeInfo.copyFromNode(this.nodeManager.node);
      this.realTimeInfo = this.nodeInfo.toString();
      if(this.cameraManager.cam){
        let v2 = CalcUtils.SpaceToPlane(this.nodeManager.node.position,this.cameraManager.cam.fov,this.scaleWH)
        this.realTimeInfo += '\n' + v2.x * this.screenWidth + '/' + v2.y * this.screenHeight ;
      }

    },25)
  }

  stopInfoTrace(){
    Helper.clearIntervalArray(this.InfoTrace,0);
  }

  getNode(pos:number):Node | null{
    if(!this.sceneNode) return null;
    let node = this.sceneNode.children.get(pos);
    return node;
  }

  rayCast(Px:number,Py:number):rayCastResult[] | undefined{
    if(!this.cameraManager.cam) return undefined;
    let ray = new Ray();
    ray.o = { x:this.cameraManager.cam.position.x,
              y:this.cameraManager.cam.position.y,
              z:this.cameraManager.cam.position.z};
    let tanA = Math.tan(this.cameraManager.cam.fov/2);
    console.info('camera Info | fov' + this.cameraManager.cam.fov + '/ tanA: ' + tanA);


    let FB:Vec3 = { x: Math.cos(Math.PI * this.cameraManager.angleY / 180) * Math.sin(Math.PI * this.cameraManager.angleX / 180),
              y: Math.sin(Math.PI * this.cameraManager.angleY / 180),
              z: -Math.cos(Math.PI * this.cameraManager.angleY / 180) * Math.cos(Math.PI * this.cameraManager.angleX / 180)}
    let RL:Vec3 = CalcUtils.NormVec3(CalcUtils.crossMul(FB,{x:0,y:1,z:0}));
    let UD:Vec3 = CalcUtils.NormVec3(CalcUtils.crossMul(RL,FB));
    console.info('Direction FB:' + FB.x + '/' + FB.y + '/' + FB.z + '\n');
    console.info('Direction UD:' + UD.x + '/' + UD.y + '/' + UD.z + '\n');
    console.info('Direction RL:' + RL.x + '/' + RL.y + '/' + RL.z + '\n');
    let t1 = 10;
    let h = t1 * tanA;
    let w = h * this.scaleWH;
    let t2 = h * Py;
    let t3 = w * Px;
    this.dot = {x: ray.o.x + t1 * FB.x + t2 * UD.x + t3 * RL.x,
                y: ray.o.y + t1 * FB.y + t2 * UD.y + t3 * RL.y,
                z: ray.o.z + t1 * FB.z + t2 * UD.z + t3 * RL.y,}
    // if(this.sceneNode){
    //   let node = this.sceneNode.getNodeByPath('Cube');
    //
    //   if(node){
    //     node.position = {x:this.dot.x,y:this.dot.y, z:this.dot.z};
    //     this.reCalAabb(node);
    //   }
    // }
    console.info('dot position: ' + this.dot.x + '/' + this.dot.y + '/' + this.dot.z);
    ray.d = CalcUtils.NormVec3({x:this.dot.x - ray.o.x,
                                y:this.dot.y - ray.o.y,
                                z:this.dot.z - ray.o.z})
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