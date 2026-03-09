// GlobalSceneProxy.ts
import { Scene, Node, PostProcessSettings, ToneMappingType, Vec3, EnvironmentBackgroundType, NodeType, Camera, LightType } from "@kit.ArkGraphics3D";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { lookAt, NodeUtil } from "./Utils";
import { Prompt } from "@kit.ArkUI";
import { EventQueueManager } from "./EventQueue";
import { PhysicsSystemManager } from "./PhysicsSystemManager";


const DOMAIN = 0x1;
const TAG = "SceneProxy"

@ObservedV2
export class SceneProxy {
  private static instance: SceneProxy | null = null;

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
  @Trace scene: Scene | undefined;
  @Trace options: SceneOptions | undefined;
  @Trace physicalSystem: PhysicsSystemManager = new PhysicsSystemManager();
  private renderId: number | undefined;
  private context: Context;

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
    }
  }

  async loadSceneFrom() {
    const resource = $rawfile("NewProject/assets/default.scene");
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();

    let camera = this.scene.root?.getNodeByPath("Perspective Camera") as Camera;
    if (!camera) return;

    camera.enabled = true;
    camera.fov = Math.PI / 2;
    lookAt(camera, { x: 0, y: 0, z: -10 }, { x: 0, y: 0, z: 0 }, { x: 0, y: 1, z: 0 });
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.postProcess = {
      toneMapping: { type: ToneMappingType.ACES, exposure: 1 }
    } as PostProcessSettings;

    if (this.scene.root) this.traversal(this.scene.root);

    Prompt.showToast({ message: 'Scene Loaded' });

    this.startRenderLoop();
  }

  private startRenderLoop() {
    if (this.renderId !== undefined) return;
    this.renderId = setInterval(() => {
      this.update();
      this.eventQueue.ResetGravity(this.physicalSystem.angle);
    }, 20);
  }

  async loadScene(sceneName: string) {
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
        if(node && node.nodeType == NodeType.GEOMETRY){
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

  getNode(name:string): Node | undefined{
    return this.physicalSystem.getNode(name);
  }

  async traversal(node: Node) {
    console.info('Node name: ' + node.name);
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