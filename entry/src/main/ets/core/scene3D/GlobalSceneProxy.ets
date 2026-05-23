// GlobalSceneProxy.ts
import { Scene, Node, PostProcessSettings, ToneMappingType, Vec3, EnvironmentBackgroundType, NodeType, Camera, LightType,
  Vec2,
  Geometry,
  MaterialType,
  MetallicRoughnessMaterial,
  SceneResourceParameters,
  Light,
  Blend,
  Quaternion} from "@kit.ArkGraphics3D";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { getAdaptiveFovy, lookAt, NodeUtil } from "./Utils";
import { Prompt } from "@kit.ArkUI";
import { EventQueueManager } from "./EventQueue";
import { PhysicsSystemManager } from "./PhysicsSystemManager";
import { getScreenSize, UIInfo } from "../../shared/ui/uiUtils";
import { Property } from "./EventTypes";
import { CameraConfig } from "./layout/CameraViewUtils";


interface NodeInfo{
  position: Vec3 | undefined;
  scale: Vec3 | undefined;
  rotation: Quaternion | undefined;
  layout:boolean;
}

interface NodeReturnInfo{
  node:Node;
  id:number;
}


const DOMAIN = 0x1;
const TAG = "SceneProxy"

@ObservedV2
export class SceneProxy {
  private static instance: SceneProxy | null = null;
  static safeOffset: number = 0;
  static ratio: number = 1.0;
  static screenSizeInit: boolean = false;
  static screenRatio: number = 1.5;
  static uiPos: Vec2 = {x:0,y:0};
  static center: Vec2 = {x:0,y:0};
  static sceneSize: Size = {width:1600, height:2500};
  static getInstance(context?:Context): SceneProxy {
    if (!SceneProxy.instance) {
      if (!context) throw new Error("SceneProxy not initialized yet! Please provide UIContext.");
      SceneProxy.instance = new SceneProxy(context);
    }
    return SceneProxy.instance;
  }

  static release() {
    if (SceneProxy.instance) {
      SceneProxy.instance.release();
      SceneProxy.instance = null;
    }
  }

  // ================= 你的原 SceneProxy 成员 =================
  camera: Camera | undefined;
  eventQueue: EventQueueManager = new EventQueueManager();
  resMap: Map<string, Resource> = new Map();
  lightNodes: Node[] = [];
  enableRotateRequest: boolean = false;
  @Trace scene: Scene | undefined;
  @Trace options: SceneOptions | undefined;
  @Trace physicalSystem: PhysicsSystemManager = new PhysicsSystemManager();
  private screenSize: Size = getScreenSize();
  private renderId: number | undefined;
  private context: Context;
  // 2D UI ID → 3D Node ID 映射
  static uiToNodeIdMap: Map<string, Node> = new Map();

  // ================= 构造函数私有化 =================
  private constructor(context: Context) {
    this.context = context;
    this.initResources();
  }

  private initResources() {
    const rM = this.context?.resourceManager;
    if (!rM) return;
    let waitingQueue: string[] = ["dir"];

    while(waitingQueue.length != 0){
      let path = waitingQueue.pop();
      if(!path) break;

      let rL = rM.getRawFileListSync(path);
      rL.forEach((value: string) => {
        let str = value.split('.');
        hilog.debug(DOMAIN, TAG, "Find File: " + value);
        if (str.length === 1) {
          waitingQueue.push(path + '/' + str[0]);
        } else {
          if(str[1] === 'glb' || str[1] === 'gltf'){
            this.resMap.set(str[0], {
              id: 0,
              bundleName: 'com.example.daynote',
              moduleName: 'entry',
              type: 30000,
              params: [path + '/' + value]
            } as Resource)
          }
        }
      })
    }
  }

  // ================= 公共方法 =================
  releaseScene(){
    if (this.renderId !== undefined) {
      clearInterval(this.renderId);
      this.renderId = undefined;
    }
    this.scene = undefined;
    this.options = undefined;
    this.camera = undefined;
    this.physicalSystem.releaseScene();
  }

  release() {
    if (this.renderId !== undefined) {
      clearInterval(this.renderId);
      this.renderId = undefined;
    }
    SceneProxy.uiToNodeIdMap.clear();
    this.scene = undefined;
    this.camera = undefined;
    this.options = undefined;
    this.resMap.clear();
  }

  update() {
    if(this.physicalSystem.available){
      this.eventQueue.swapQueues();
      this.physicalSystem.updateNodeData(this.eventQueue.getReadQueues());
      this.scene?.renderFrame({ alwaysRender: false });
    }else{
      console.log('not available');
    }
  }

  initCamera(camera:Camera){
    this.eventQueue.pushSetRequest(0,Property.CAMERA,[camera.position.x,camera.position.y, camera.position.z,camera.fov,SceneProxy.ratio]);
  }

  getCameraConfig():CameraConfig | undefined{
    if(!this.camera){
      console.info("get no camera")
      return undefined;
    }
    let config:CameraConfig ={
      aspectRatio:SceneProxy.ratio,
      position:this.camera.position,
      fov:this.camera.fov,
      nearClip:this.camera.nearPlane,
      farClip:this.camera.farPlane
    }
    return config;
  }

  setRotation(name:string,rotation:Quaternion){
    let id = this.physicalSystem.getIdWithName(name);
    if(id != undefined){
      this.eventQueue.pushSetRequest(id,Property.ROTATION,
        [rotation.x,rotation.y,rotation.z,rotation.w]);
    }else{
      console.info("can't find " + name);
    }
  }

  static removeNode(node:Node){
    let instance = SceneProxy.getInstance();
    let id = instance.physicalSystem.idMap.get(node.path + '/' + node.name);
    if(id){
      instance.physicalSystem.idMap.delete(node.path + '/' + node.name);
      instance.physicalSystem.nodeMap.delete(node.name);
      instance.physicalSystem.unregisterNode(id);
      let parent = node.parent;
      if(parent){
        parent.children.remove(node);
      }
    }

  }

  setPosition(name:string,pos:Vec3){
    let id = this.physicalSystem.getIdWithName(name);
    if(id != undefined){
      this.eventQueue.pushSetRequest(id,Property.POS,[pos.x,pos.y,pos.z]);
    }else{
      console.info("can't find " + name);
    }
  }

  async LoadPhotoWall(){
    const resource = $rawfile("PhotoWall/assets/default.scene");
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();
    let camera = this.scene.root?.getNodeByPath("Perspective Camera") as Camera;
    if (!camera) {
      return;
    }
    this.camera = camera;
    camera.enabled = true;

    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.clearColor = null;
    camera.fov = getAdaptiveFovy(SceneProxy.screenRatio);
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);
    // Prompt.showToast({ message: 'Scene Loaded' });
    this.physicalSystem.setAvailable();
    this.physicalSystem
    this.startRenderLoop();
  }

  async LoadRotationBall(){
    const resource = $rawfile("RotationBall/assets/default.scene");
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();
    let camera = this.scene.root?.getNodeByPath("Perspective Camera") as Camera;
    if (!camera) {
      return;
    }
    this.camera = camera;
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.enabled = true;

    camera.fov = getAdaptiveFovy(SceneProxy.screenRatio);
    camera.clearColor = null;
    // camera.clearColor = {r:0,g:0,b:0,a:0};
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);
    // Prompt.showToast({ message: 'Scene Loaded' });
    this.physicalSystem.setAvailable();
    this.physicalSystem
    this.startRenderLoop();
  }

  async LoadCollision(){
    const resource = $rawfile("Collision/assets/default.scene");
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();
    let camera = this.scene.root?.getNodeByPath("Perspective Camera") as Camera;
    if (!camera) {
      return;
    }
    this.camera = camera;
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.enabled = true;
    camera.fov = getAdaptiveFovy(SceneProxy.screenRatio);
    camera.clearColor = null;
    // camera.clearColor = {r:0,g:0,b:0,a:0};
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);
    // Prompt.showToast({ message: 'Scene Loaded' });
    this.physicalSystem.setAvailable();
    this.physicalSystem
    this.startRenderLoop();
  }

  async loadSceneFromDefault() {
    const resource = $rawfile("Wall2/assets/default.scene");
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();

    let camera = this.scene.root?.getNodeByPath("Perspective Camera") as Camera;
    if (!camera) return;

    camera.enabled = true;
    camera.fov = getAdaptiveFovy(SceneProxy.screenRatio);
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);

    // Prompt.showToast({ message: 'Scene Loaded' });
    this.physicalSystem.setAvailable();
    this.startRenderLoop();
  }

  async loadSceneFrom() {
    const resource = $rawfile("Wall/assets/default.scene");
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();
    let camera = this.scene.root?.getNodeByPath("Perspective Camera") as Camera;
    if (!camera) {
      return;
    }
    camera.enabled = true;
    camera.fov = getAdaptiveFovy(SceneProxy.screenRatio);
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);

    this.physicalSystem.setAvailable();
    this.startRenderLoop();
  }

  private startRenderLoop() {
    if (this.renderId !== undefined) return;
    this.renderId = setInterval(() => {
      this.update();
      // this.eventQueue.ResetGravity(this.physicalSystem.angle);
    }, 20);
  }

  async loadScene(sceneName: string,ui:UIContext) {
    const resource = this.resMap.get(sceneName);
    if (!resource) return;

    this.scene = await Scene.load(resource);
    Prompt.showToast({message:"load " + sceneName})
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    const rf = this.scene.getResourceFactory();

    const camera = await rf.createCamera({ name: 'perspectiveCamera' });
    camera.enabled = true;
    camera.fov = getAdaptiveFovy(SceneProxy.screenRatio);
    camera.clearColor = { r: 0, g: 0, b: 0, a: 0.001 };
    lookAt(camera, { x: 0, y: 0, z: -6 }, { x: 0, y: 0, z: 0 }, { x: 0, y: 1, z: 0 });
    this.initCamera(camera);
    this.camera = camera;
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.postProcess = { toneMapping: { type: ToneMappingType.ACES, exposure: 1 } } as PostProcessSettings;

    if (this.scene.root) await this.traversal(this.scene.root);
    this.physicalSystem.setAvailable();
    this.startRenderLoop();
  }

  async addCard(ImageUri:string,shaderName:string){
    let nodeInfo: NodeInfo = {
      position:undefined,
      scale:undefined,
      rotation:undefined,
      layout:true
    }
    let info = await this.addNodeWithInfo('card','Plane',shaderName,nodeInfo);
    if(!info) return;
    this.eventQueue.pushSetRequest(info.id,Property.CAN_ROTATE,[1]);
    let factory = this.scene?.getResourceFactory();
    if(factory && info.node){
      NodeUtil.attachShader(
        info.node,shaderName,$rawfile('shaders/Myshader/myshader.shader'),
        factory,"MyMATERIAL" + shaderName,'Image' + shaderName,ImageUri);
    }else{
      console.error("未找到节点")
    }
  }




  static async syncUI(uiId:string, uiInfo:UIInfo){
    let nodeInfo = SceneProxy.transUI(uiInfo);
    let instance = SceneProxy.getInstance();
    let nodeId = instance.physicalSystem.getIdWithName(uiId);
    if(nodeId){
      if(nodeInfo.position)
        instance.eventQueue.pushSetRequest(nodeId,Property.POS,[nodeInfo.position.x,nodeInfo.position.y,nodeInfo.position.z]);
      if(nodeInfo.scale)
        instance.eventQueue.pushSetRequest(nodeId,Property.SCALE,[nodeInfo.scale.x,nodeInfo.scale.y,nodeInfo.scale.z]);
      if(nodeInfo.rotation)
        instance.eventQueue.pushSetRequest(nodeId,Property.ROTATION,[nodeInfo.rotation.x,nodeInfo.rotation.y,nodeInfo.rotation.z,nodeInfo.rotation.w]);
    }
  }

  static async addUIPlane(uiId:string,uiInfo:UIInfo){
    let nodeInfo = SceneProxy.transUI(uiInfo);
    let info = await SceneProxy.getInstance().addNodeWithInfo('card','Plane',uiId,nodeInfo);
    if(!info) return;
    SceneProxy.uiToNodeIdMap.set(uiId,info.node);
  }

  async addBall(){
    let info = await this.addNodeWithOutInfo('ball','ball','VELBALL');
    let id = info?.id;
    let initialVel:Vec3 = {x:2,y:0,z:0};
    let initialPos:Vec3 = {x:-20,y:2,z:-1};
    if(id){
      this.eventQueue.pushSetRequest(id,Property.STATIC,[0]);
      this.eventQueue.pushSetRequest(id,Property.VELOCITY,[initialVel.x,initialVel.y,initialVel.z])
      this.eventQueue.pushSetRequest(id,Property.POS,[initialPos.x,initialPos.y,initialPos.z]);
    }
  }

  async addCube(){
    let info = await this.addNodeWithOutInfo('cube','Cube','Cube');
    let id = info?.id;
    let initialVel:Vec3 = {x:0,y:0,z:0};
    let initialPos:Vec3 = {x:0,y:-10,z:-0.6};
    if(id){
      this.eventQueue.pushSetRequest(id,Property.STATIC,[0]);
      this.eventQueue.pushSetRequest(id,Property.VELOCITY,[initialVel.x,initialVel.y,initialVel.z])
      this.eventQueue.pushSetRequest(id,Property.POS,[initialPos.x,initialPos.y,initialPos.z]);
    }
  }

  async addImage(imageUri:string,  imageName:string){
    let node = await this.addNode('imagetest','plane','imageTest');
    let gemo = node as Geometry;
    if(gemo.mesh.subMeshes.length > 0){
      console.log("has mesh number" + gemo.mesh.subMeshes.length.toString());
      let count = gemo.mesh.subMeshes.length;
      for(let i = 0; i < count ; i++){
        let mesh = gemo.mesh.subMeshes[i];
        if(mesh.material){
          console.log("material type is " + mesh.material.materialType.toString());
          if(mesh.material.materialType == MaterialType.METALLIC_ROUGHNESS){
            let material = mesh.material as MetallicRoughnessMaterial;
            if(material.baseColor.image){
              console.log("material has image");
            }else{
              let factory = this.scene?.getResourceFactory();
              if(factory){
                if(imageUri && imageName) {
                  let sceneImageParameter: SceneResourceParameters = {
                    name: imageName,
                    uri: imageUri
                  };
                  let image = await factory.createImage(sceneImageParameter);
                  material.baseColor.image = image;
                  // if(material.blend){
                  //   material.blend.enabled = true;
                  // }else {
                  //   material.blend = { enabled: true } as Blend;
                  // }

                  material.alphaCutoff = 0.5;
                }
              }
              console.log("material doesn't has image");
            }
          }
        }else{
          console.log("material doesn't exists");
        }
      }
    }else{
      console.log("gemo mesh empty");
    }
    if(gemo.mesh.materialOverride){
      console.log("material type is " + gemo.mesh.materialOverride.materialType.toString());
    }else{
      console.log("material doesn't exists");
    }
  }

  async addNodeWithInfo(res: string, name:string, reName:string,info:NodeInfo):Promise<NodeReturnInfo | undefined>{
    let node = await this.addNode(res,name,reName);
    if(!node) return;
    if(info.position){
      node.position.x = info.position.x;
      node.position.y = info.position.y;
      node.position.z = info.position.z;
    }
    if(info.scale){
      node.scale.x = info.scale.x;
      node.scale.y = info.scale.y;
      node.scale.z = info.scale.z;
    }
    if(info.rotation){
      node.rotation.x = info.rotation.x;
      node.rotation.y = info.rotation.y;
      node.rotation.z = info.rotation.z;
      node.rotation.w = info.rotation.w;
    }
    let id:number = 0;
    if(info.layout){
      id = this.physicalSystem.registerNodeWithLayout(node, true);
    }else {
      id = this.physicalSystem.registerNode(node, true);
    }
    return {node,id};
  }

  async addNodeWithOutInfo(res: string, name:string, reName:string):Promise<NodeReturnInfo | undefined>{
    let node = await this.addNode(res,name,reName);
    if(!node) return;
    let id = this.physicalSystem.registerNode(node,true);
    return {node,id};
  }

  async addNode(res: string, name:string, reName:string):Promise<Node | undefined>{
    let resource = this.resMap.get(res);
    if(!resource) return;
    let resScene = await Scene.load(resource);
    let nodeQueue:Node[] = [];
    if (resScene.root) { nodeQueue.push(resScene.root); }
    while(nodeQueue.length != 0) {
      let parent = nodeQueue.pop();
      if(parent && parent?.name == name){
        let node = this.scene?.importNode(reName,parent,this.scene.root);
        return node;
      }
      let count = parent?.children.count();
      if (count) {
        for(let i = 0; i < count; i++) { nodeQueue.push(parent?.children.get(i) as Node)}
      }
    }
    return;
  }

  static SceneProxyInit(ui:UIContext){
    if(!SceneProxy.screenSizeInit){
      let info = ui.getComponentUtils().getRectangleById("3D");
      console.info("ScreenTest | component position x " + info.windowOffset.x.toFixed(2) + " y " + info.windowOffset.y.toFixed(2));
      console.info("ScreenTest | component size | width " + info.size.width.toFixed(2) + " height " + info.size.height.toFixed(2));
      SceneProxy.center = {
        x: info.windowOffset.x + info.size.width / 2,
        y: info.windowOffset.y + SceneProxy.sceneSize.height / 2
      };
      SceneProxy.uiPos = {
        x: info.windowOffset.x,
        y: info.windowOffset.y
      };

      SceneProxy.screenSizeInit = true;
      let instance = SceneProxy.getInstance();
      if(instance && instance.camera) {
        instance.camera.fov = getAdaptiveFovy(SceneProxy.ratio);
        let pos = instance.camera.position;
        instance.eventQueue.pushSetRequest(0, Property.CAMERA, [pos.x , pos.y,pos.z, instance.camera.fov ,SceneProxy.ratio])
      }
    }
  }

  rayCast(pos:Vec2,ui:UIContext){
    let fx = SceneProxy.disToFrac(ui.vp2px(pos.x) - SceneProxy.center.x);
    let fy = SceneProxy.disToFrac(SceneProxy.center.y - ui.vp2px(pos.y));
    Prompt.showToast({message:"touchFrac" + fx.toFixed(2) + '/' + fy.toFixed(2)});
    this.eventQueue.pushRayCastRequest(fx,fy);
  }

  sendTouchDown(pos:Vec2){
    this.eventQueue.pushTouchDown(pos.x, pos.y);
  }

  sendTouchMove(pos:Vec2){
    this.eventQueue.pushTouchMove(pos.x,pos.y);
    if(this.physicalSystem.selectId != 128 && this.enableRotateRequest){
      this.eventQueue.pushRotateRequest(this.physicalSystem.selectId);
    }
  }

  sendTouchUp(){
    this.eventQueue.pushTouchUp();
  }

  getNode(name:string): Node | undefined{
    return this.physicalSystem.getNode(name);
  }

  /**
   * 注册 2D UI ID 到 3D Node ID 的映射
   */
  registerUI2DTo3D(uiId: string, node: Node) {
    SceneProxy.uiToNodeIdMap.set(uiId, node);
    // console.info(`[UI2D→3D] 注册映射: '${uiId}' → nodeId ${nodeId}`);
  }

  /**
   * 获取 2D UI 对应的 3D Node ID
   */
  get3DNodeId(uiId: string): number | undefined {
    let instance = SceneProxy.getInstance();
    return instance.physicalSystem.getIdWithName(uiId);;
  }

  async traversal(node: Node) {
    console.info('Node name: ' + node.name);
    // 遍历获取灯光节点
    if (node.nodeType === NodeType.LIGHT) {
      const light = node as Light;
      this.lightNodes.push(node);
      light.shadowEnabled = true;
      console.info(`Found Light: ${node.name}, Type: ${light.lightType}, Enabled: ${light.enabled}`);
    }
    
    const count = node.children.count();
    for (let i = 0; i < count; i++) {
      const temp = node.children.get(i);
      if (temp){
        if(temp.nodeType == NodeType.GEOMETRY){
          await this.physicalSystem.registerNode(temp);
        }
        this.traversal(temp);
      }
    }
  }

  // 由于当前的默认平面位置在z=-1，所以我们先固定
  static pxTo3D(v:number):number{
    return 5 * SceneProxy.disToFrac(v);
  }

  static disToFrac(v:number):number {
    return 2 * v / SceneProxy.sceneSize.height;
  }

  static transUI(uiInfo:UIInfo):NodeInfo{
    let x = SceneProxy.pxTo3D(SceneProxy.center.x - uiInfo.pos.x - uiInfo.size.x / 2);
    let y = SceneProxy.pxTo3D(SceneProxy.center.y - uiInfo.pos.y - uiInfo.size.y / 2);
    let scale:Vec3 = {x:SceneProxy.pxTo3D(uiInfo.size.x), y:SceneProxy.pxTo3D(uiInfo.size.y),z:1.0};
    let nodeInfo: NodeInfo = {
      position:{x,y,z:-1},
      scale,
      rotation:undefined,
      layout:false,
    }
    return nodeInfo;
  }

  // 其他方法如 addNode, addCard 可以照搬原来写法
}