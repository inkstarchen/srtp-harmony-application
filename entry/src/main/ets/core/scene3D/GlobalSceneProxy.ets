// GlobalSceneProxy.ts
import { Scene, Node, PostProcessSettings, ToneMappingType, Vec3, EnvironmentBackgroundType, NodeType, Camera, LightType,
  Vec2,
  Geometry,
  MaterialType,
  MetallicRoughnessMaterial,
  SceneResourceParameters,
  Light,
  Blend} from "@kit.ArkGraphics3D";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { lookAt, NodeUtil } from "./Utils";
import { Prompt } from "@kit.ArkUI";
import { EventQueueManager } from "./EventQueue";
import { PhysicsSystemManager } from "./PhysicsSystemManager";
import { getScreenSize } from "../../shared/ui/uiUtils";
import { Property } from "./EventTypes";
import { LayoutHelper } from "./layout/CameraViewUtils";


const DOMAIN = 0x1;
const TAG = "SceneProxy"

@ObservedV2
export class SceneProxy {
  private static instance: SceneProxy | null = null;
  static ratio: number = 1.5;
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
  @Trace scene: Scene | undefined;
  @Trace options: SceneOptions | undefined;
  @Trace physicalSystem: PhysicsSystemManager = new PhysicsSystemManager();
  private screenSize: Size = getScreenSize();
  private renderId: number | undefined;
  private context: Context;
  // 2D UI ID → 3D Node ID 映射
  private uiToNodeIdMap: Map<string, number> = new Map();

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
    camera.fov = Math.PI / 2;
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);

    Prompt.showToast({ message: 'Scene Loaded' });
    this.physicalSystem.setAvailable();
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
    camera.fov = Math.PI / 2;
    // lookAt(camera, { x: 0, y: 0, z: -10 }, { x: 0, y: 0, z: 0 }, { x: 0, y: 1, z: 0 });
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);

    Prompt.showToast({ message: 'Scene Loaded' });
    this.physicalSystem.setAvailable();
    this.startRenderLoop();
  }

  private startRenderLoop() {
    if (this.renderId !== undefined) return;
    this.renderId = setInterval(() => {
      this.update();
      this.eventQueue.ResetGravity(this.physicalSystem.angle);
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
    camera.fov = Math.PI / 2;
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
    let node = await this.addNode('card','Cube',shaderName);
    let factory = this.scene?.getResourceFactory();
    if(factory && node){
      NodeUtil.attachShader(
        node,shaderName,$rawfile('shaders/Myshader/myshader.shader'),
        factory,"MyMATERIAL" + shaderName,'Image' + shaderName,ImageUri);
    }
  }

  /**
   * 添加 2D UI 替身（静态平面，用于阴影/碰撞）
   * 注意：默认为静态节点，位置由 syncUIto3D() 显式控制
   * 如需物理交互（如碰撞推动），请使用 addDynamicUIPlane()
   */
  async addUIPlane(name:string,scale:Vec2):Promise<number | undefined>{
    let nodeId = await this.addNodeWithScaleReturnId('card','Plane', name,scale);
    if(nodeId !== undefined){
      this.registerUI2DTo3D(name, nodeId); // 注册 2D→3D 映射
    }
    return nodeId;
  }

  /**
   * 添加动态 2D UI 替身（受物理引擎控制）
   * 可用于需要碰撞、重力等物理交互的 UI 元素
   */
  async addDynamicUIPlane(name:string,scale:Vec2):Promise<number | undefined>{
    let nodeId = await this.addNodeWithScaleReturnId('card','Plane', name,scale);
    if(nodeId !== undefined){
      this.registerUI2DTo3D(name, nodeId);
      this.eventQueue.setStatic(nodeId, false); // 设置为动态
      this.eventQueue.setMass(nodeId, 1.0);     // 设置质量
    }
    return nodeId;
  }

  async addBall(name:string){
    let scale = {x:1,y:1} as Vec2;
    let nodeId = await this.addNodeWithScaleReturnId('ball','ball','ball',scale);
    if(nodeId){
      console.log('setball');
      this.eventQueue.setPosition(nodeId, {x:0,y:0,z:-3});
      this.eventQueue.setStatic(nodeId,false);
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

  async addNodeWithScaleReturnId(res: string, name:string, reName:string,scale:Vec2):Promise<number | undefined>{
    let resource = this.resMap.get(res);
    if(!resource) return;
    let resScene = await Scene.load(resource);
    let nodeQueue:Node[] = [];
    if (resScene.root) { nodeQueue.push(resScene.root); }
    while(nodeQueue.length != 0) {
      let parent = nodeQueue.pop();
      if(parent && parent?.name == name){
        let node = this.scene?.importNode(reName,parent,this.scene.root);
        if(node && node.nodeType == NodeType.GEOMETRY){
          node.scale.x = scale.x ;
          node.scale.y = scale.y ;
          node.position.z = -1;
          let id = this.physicalSystem.registerNode(node,true);
          return id;
        }
      }
      let count = parent?.children.count();
      if (count) {
        for(let i = 0; i < count; i++) { nodeQueue.push(parent?.children.get(i) as Node)}
      }
    }
    return;
  }

  async addNodeWithScale(res: string, name:string, reName:string,scale:Vec2):Promise<Node | undefined>{
    let resource = this.resMap.get(res);
    if(!resource) return;
    let resScene = await Scene.load(resource);
    let nodeQueue:Node[] = [];
    if (resScene.root) { nodeQueue.push(resScene.root); }
    while(nodeQueue.length != 0) {
      let parent = nodeQueue.pop();
      if(parent && parent?.name == name){
        let node = this.scene?.importNode(reName,parent,this.scene.root);
        if(node && node.nodeType == NodeType.GEOMETRY){
          node.scale.x = scale.x ;
          node.scale.y = scale.y ;
          node.position.z = -1;
          this.physicalSystem.registerNode(node,true);
        }
        return node;
      }
      let count = parent?.children.count();
      if (count) {
        for(let i = 0; i < count; i++) { nodeQueue.push(parent?.children.get(i) as Node)}
      }
    }
    return;
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
        let pos = LayoutHelper.randomPosInCameraView();

        if(node && node.nodeType == NodeType.GEOMETRY){
          node.position.x = pos.x;
          node.position.y = pos.y;
          node.position.z = pos.z;
          this.physicalSystem.registerNode(node,true);
        }
        return node;
      }
      let count = parent?.children.count();
      if (count) {
        for(let i = 0; i < count; i++) { nodeQueue.push(parent?.children.get(i) as Node)}
      }
    }
    return;
  }

  scene1_init(){
    this.scene?.getResourceFactory().createLight({name:"light"},LightType.DIRECTIONAL)
      .then((light) => {
        light.intensity = 2;
        light.shadowEnabled = true;
        light.enabled = true;
        lookAt(light,{x:0,y:-2,z:-10}, {x:0,y:0,z:0}, {x:0,y:1,z:0});
      })

    // this.eventQueue.setStatic(0,false);
    this.eventQueue.setStatic(1,false);
    // this.physicalSystem.setStatic(2,true);
    // this.physicalSystem.setStatic(3,true);
    // this.physicalSystem.setStatic(4,true);
    // this.physicalSystem.setStatic(5,true);
    this.eventQueue.setPosition(1, {x:0.0,y:1.0,z:-4.0});
    // this.physicalSystem.setFriction(1, 0.0);
    // this.physicalSystem.setRestitution(0, 0.8);
    // this.physicalSystem.setRestitution(1, 0.2);
    // this.physicalSystem.setRestitution(2, 0.8);
    // this.physicalSystem.setRestitution(3, 0.8);
    // this.physicalSystem.setRestitution(4, 0.8);
    // this.physicalSystem.setRestitution(5, 0.8);

    this.eventQueue.setMass(0,1.0);
    this.eventQueue.setMass(1,1.0);
    this.eventQueue.setMass(2,1.0);
    this.eventQueue.setMass(3,1.0);
    this.eventQueue.setMass(4,1.0);
    this.eventQueue.setMass(5,1.0);
  }

  rayCast(pos:Vec2,ui:UIContext){
    let fx =  (2 * ui.vp2px(pos.x) / SceneProxy.sceneSize.width) - 1;
    let fy = 1 - (2 * ui.vp2px(pos.y) / SceneProxy.sceneSize.height);
    this.eventQueue.pushRayCastRequest(fx,fy);
  }

  sendTouchDown(pos:Vec2){
    this.eventQueue.pushTouchDown(pos.x, pos.y);
  }

  sendTouchMove(pos:Vec2){
    this.eventQueue.pushTouchMove(pos.x,pos.y);
    // if(this.physicalSystem.selectId != 128){
    //   this.eventQueue.pushRotateRequest(this.physicalSystem.selectId);
    // }
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
  registerUI2DTo3D(uiId: string, nodeId: number) {
    this.uiToNodeIdMap.set(uiId, nodeId);
    console.info(`[UI2D→3D] 注册映射: '${uiId}' → nodeId ${nodeId}`);
  }

  /**
   * 获取 2D UI 对应的 3D Node ID
   */
  get3DNodeId(uiId: string): number | undefined {
    return this.uiToNodeIdMap.get(uiId);
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

  // 其他方法如 addNode, addCard 可以照搬原来写法
}