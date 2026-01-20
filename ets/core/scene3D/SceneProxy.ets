import { Scene, Node, PostProcessSettings, ToneMappingType, Vec3, Quaternion,
  EnvironmentBackgroundType,
  NodeType} from "@kit.ArkGraphics3D";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { lookAt } from "./Utils";
import { Prompt } from "@kit.ArkUI";
import { PhysicsSystemManager } from "./PhysicsSystemManager";


const DOMAIN = 0x1;
const TAG = "SceneProxy"

@ObservedV2
export class SceneProxy{
  @Trace renderId: number = 0;
  resMap: Map<string, Resource> = new Map();
  @Trace scene: Scene | undefined;
  @Trace options: SceneOptions | undefined;
  @Trace physicalSystem: PhysicsSystemManager = new PhysicsSystemManager();

  update(){
    this.physicalSystem.update(0.01);
    // this.scene?.renderFrame({alwaysRender: false});
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

  async loadScene(sceneName: string){
    let resource = this.resMap.get(sceneName);
    this.scene = await Scene.load(resource);
    this.options = { scene: this.scene, modelType: ModelType.SURFACE };
    let rf = this.scene.getResourceFactory();
    let camera = await rf.createCamera({name:'perspectiveCamera'});
    camera.enabled = true;
    camera.fov = Math.PI / 4;
    camera.position = {x:0, y:0, z:-4} as Vec3;
    lookAt(camera,{x:0,y:0,z:-10}, {x:0,y:0,z:0}, {x:0,y:1,z:0});
    this.scene.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;
    camera.clearColor = {r:1,g:1,b:1,a:0};
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
      this.scene?.renderFrame({alwaysRender:false});
    }, 20);
  }

  async addNode(res: string, name:string) {
    let resource = this.resMap.get(res);
    if(!resource) return;
    let resScene = await Scene.load(resource);
    let nodeQueue:Node[] = [];
    if (resScene.root) { nodeQueue.push(resScene.root); }
    while(nodeQueue.length != 0) {
      let parent = nodeQueue.pop();
      if(parent && parent?.name == name){
        this.scene?.importNode(name,parent,this.scene.root);
        return;
      }
      let count = parent?.children.count();
      if (count) {
        for(let i = 0; i < count; i++) { nodeQueue.push(parent?.children.get(i) as Node)}
      }
    }
    return;
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