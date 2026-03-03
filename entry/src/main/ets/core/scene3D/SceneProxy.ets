import { Scene, Node, PostProcessSettings, ToneMappingType, Vec3, Quaternion,
  EnvironmentBackgroundType,
  NodeType,
  Camera,
  LightType} from "@kit.ArkGraphics3D";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { lookAt, NodeUtil } from "./Utils";
import { Prompt } from "@kit.ArkUI";
import { PhysicsSystemManager } from "./PhysicsSystemManager";
import { Touch } from "../../shared/utils/TouchManager";
import { TouchRotate } from "./TouchRotate";


const DOMAIN = 0x1;
const TAG = "SceneProxy"

@ObservedV2
export class SceneProxy{
  @Trace renderId: number = 0;
  camera: Camera | undefined;
  @Trace touchRotate: TouchRotate = new TouchRotate();
  resMap: Map<string, Resource> = new Map();
  @Trace scene: Scene | undefined;
  @Trace options: SceneOptions | undefined;
  @Trace physicalSystem: PhysicsSystemManager = new PhysicsSystemManager();

  release(){
    clearInterval(this.renderId);
  }



  update(){
    // this.physicalSystem.updateData("Cube");
    this.physicalSystem.updateNodeData();
    this.scene?.renderFrame({alwaysRender: false});
  }

  constructor(ui: UIContext) {
    let waitingQueue: string[] = ["dir"];
    let rM= ui.getHostContext()?.resourceManager;
    if(!rM) return;
    while(waitingQueue.length != 0){
      let path = waitingQueue.pop();
      if (!path) {
        return;
      }
      let rL = rM.getRawFileListSync(path);
      rL.forEach((value: string, index:number) => {
        let str = value.split('.');
        hilog.debug(DOMAIN,TAG,"Find File: " + value);
        if (str.length == 1) {
          waitingQueue.push(path + '/' + str[0]);
        } else {
          if(str[1] == 'glb' || str[1] == 'gltf'){
            this.resMap.set(str[0], {
              id: 0,
              bundleName: 'com.example.daynote',
              moduleName: 'entry',
              type: 30000,
              params:[path + '/' + value]
            } as Resource)
          }
        }
      })
    }
  }

  // 从加载预设场景
  async loadSceneFrom(){
    const resource = $rawfile("NewProject/assets/default.scene");
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();

    // let camera = await rf.createCamera({name:'perspectiveCamera'});
    let camera = this.scene.root?.getNodeByPath("Perspective Camera") as Camera;
    camera.enabled = true;
    // camera.fov = Math.PI / 4;
    // camera.position = {x:0, y:0, z:-4} as Vec3;
    // lookAt(camera,{x:0,y:0,z:-10}, {x:0,y:0,z:0}, {x:0,y:1,z:0});
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    // camera.clearColor = {r:1,g:1,b:1,a:1};
    camera.postProcess = {
      toneMapping: {
        type: ToneMappingType.ACES,
        exposure: 1
      }
    } as PostProcessSettings;
    if(this.scene.root)
      this.traversal(this.scene.root);
    if(camera.enabled){
      Prompt.showToast({message:'test'});
    }

    this.renderId = setInterval(() => {
      this.update();
    }, 20);
  }

  // 记载指定场景
  async loadScene(sceneName: string){
    let resource = this.resMap.get(sceneName);
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();
    let camera = await rf.createCamera({name:'perspectiveCamera'});
    camera.enabled = true;
    camera.fov = Math.PI / 4;
    camera.position = {x:0, y:0, z:-4} as Vec3;
    camera.clearColor = {r:0.0,g:0.0,b:0.0,a:0.001};
    lookAt(camera,{x:0,y:0,z:-10}, {x:0,y:0,z:0}, {x:0,y:1,z:0});
    this.camera = camera;
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.postProcess = {
      toneMapping: {
        type: ToneMappingType.ACES,
        exposure: 1
      }
    } as PostProcessSettings;
    if(this.scene.root)
      this.traversal(this.scene.root);
    this.renderId = setInterval(() => {
      this.update();
    }, 20);

  }


  // 预设场景初始化函数2
  scene2_init(){
    this.physicalSystem.setStatic(2,false);
    // this.physicalSystem.setStatic(0,false);
    // this.physicalSystem.setStatic(1,false);
    this.physicalSystem.setMass(2,1.0);
  }

  // 预设场景初始化函数1
  scene1_init(){
    this.scene?.getResourceFactory().createLight({name:"light"},LightType.DIRECTIONAL)
      .then((light) => {
        light.intensity = 2;
        light.shadowEnabled = true;
        light.enabled = true;
        lookAt(light,{x:0,y:-2,z:-10}, {x:0,y:0,z:0}, {x:0,y:1,z:0});
      })

    this.physicalSystem.setStatic(0,true);
    this.physicalSystem.setStatic(1,false);
    this.physicalSystem.setStatic(2,true);
    this.physicalSystem.setStatic(3,true);
    this.physicalSystem.setStatic(4,true);
    this.physicalSystem.setStatic(5,true);
    this.physicalSystem.setPosition(1, {x:0.0,y:1.0,z:-4.0});
    this.physicalSystem.setFriction(1, 0.0);
    this.physicalSystem.setRestitution(0, 0.8);
    this.physicalSystem.setRestitution(1, 0.2);
    this.physicalSystem.setRestitution(2, 0.8);
    this.physicalSystem.setRestitution(3, 0.8);
    this.physicalSystem.setRestitution(4, 0.8);
    this.physicalSystem.setRestitution(5, 0.8);

    this.physicalSystem.setMass(0,1.0);
    this.physicalSystem.setMass(1,1.0);
    this.physicalSystem.setMass(2,1.0);
    this.physicalSystem.setMass(3,1.0);
    this.physicalSystem.setMass(4,1.0);
    this.physicalSystem.setMass(5,1.0);
  }

  async addCard(ImageUri:string){
    let node = await this.addNode('card','Cube');
    let factory = this.scene?.getResourceFactory();
    if(factory && node){
      NodeUtil.attachShader(
        node,'Myshader',$rawfile('shaders/Myshader/myshader.shader'),
        factory,"MyMATERIAL",'Image',ImageUri);
    }
  }

  async addNode(res: string, name:string):Promise<Node | undefined>{
    let resource = this.resMap.get(res);
    if(!resource) return;
    let resScene = await Scene.load(resource);
    let nodeQueue:Node[] = [];
    if (resScene.root) { nodeQueue.push(resScene.root); }
    while(nodeQueue.length != 0) {
      let parent = nodeQueue.pop();
      if(parent && parent?.name == name){
        let node = this.scene?.importNode(name,parent,this.scene.root);
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

  getNode(name:string): Node | undefined{
    return this.physicalSystem.getNode(name);
  }

  traversal(node:Node){
    console.info('Node name:' + node.name);
    let count = node.children.count();
    if(count){
      for(let i = 0; i < count ; i++){
        let temp = node.children.get(i);
        if(temp){
          if(temp.nodeType == NodeType.GEOMETRY){
            this.physicalSystem.registerNode(temp);
          }
          this.traversal(temp);
        }
      }
    }
  }
}