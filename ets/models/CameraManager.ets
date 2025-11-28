
import {
  BloomSettings,
  Camera, Color, Quaternion, SceneResourceFactory,
  ToneMappingSettings,
  ToneMappingType,
  Vec3} from "@kit.ArkGraphics3D";
import { CalcUtils } from "../utils/calutils";
import { Helper } from "../utils/Helper";
import { NodeInfo } from "./BaseClass";

export class CameraInfo extends NodeInfo{

  constructor(name:string,position:Vec3,rotation:Quaternion,scaleV:number,fov:number,nearPlane:number,
    farPlane:number,enabled:boolean,clearColor:Color,toneMapping:ToneMappingSettings | undefined = undefined,
    bloom:BloomSettings | undefined = undefined) {
    super(name,position,rotation,scaleV)
    this.fov = fov;
    this.nearPlane = nearPlane;
    this.farPlane = farPlane;
    this.enabled = enabled;
    this.clearColor = clearColor;
    if(toneMapping) {
      this.toneMapping = toneMapping
    }
    if(bloom){
      this.bloom = bloom;
    }
  }

  copyFromNode(node:Camera){
    this.name = node.name;
    this.position = node.position;
    this.rotation = node.rotation;
    this.scale = node.scale.x;
    this.fov = node.fov;
    this.nearPlane = node.nearPlane;
    this.farPlane = node.farPlane
    this.enabled = node.enabled;
  }

  name:string = '';
  position:Vec3 = {x:0,y:0,z:0}
  rotation:Quaternion = {x:0,y:1,z:0,w:0}
  scale:number = 1;
  fov:number = 90;
  nearPlane:number = 0;
  farPlane:number = 0;
  enabled:boolean = false;
  clearColor:Color = {r:0,g:0,b:0,a:0}
  toneMapping:ToneMappingSettings = {type:undefined,exposure:undefined}
  bloom:BloomSettings = {thresholdHard:0,thresholdSoft:0,scaleFactor:0,scatter:0}

  toString():string {
    let nodeInfo = '';
    nodeInfo += 'Name: ' + this.name + '\n';
    nodeInfo += 'Position | x: ' + this.position.x + ' / y: ' + this.position.y + ' / z: ' + this.position.z + '\n';
    nodeInfo += 'Rotation | x: ' + this.rotation.x + ' / y: ' + this.rotation.y + ' / z: ' + this.rotation.z + ' / w: ' + this.rotation.w + '\n';
    nodeInfo += 'fov: ' + this.fov + ' | nearPlane: ' + this.nearPlane + ' | farPlane: ' + this.farPlane + '\n';
    nodeInfo += 'enabled: ' + (this.enabled ? 'true' : 'false') + '\n';
    return nodeInfo;
  }

}

const Y:Vec3 = {x:0,y:1,z:0};
const Z:Vec3 = {x:0,y:0,z:1};
const X:Vec3 = {x:1,y:0,z:0};
const NEG_Y:Vec3 = {x:0,y:-1,z:0};
const NEG_Z:Vec3 = {x:0,y:0,z:-1};
const NEG_X:Vec3 = {x:-1,y:0,z:0};

@ObservedV2
export class CameraManager{

  cameraInfo:CameraInfo | undefined = undefined;
  @Trace realTimeInfo: string = '';
  screenSize: Size = {width: 1000, height: 2000};
  cam:Camera | undefined = undefined;
  cams: Camera[] = [];
  cameraIndex: Map<string,number> = new Map();
  uiContext?: UIContext;
  rf:SceneResourceFactory | undefined = undefined;

  async init(rf:SceneResourceFactory){
    this.rf = rf;
    this.cameraInfo = new CameraInfo('name',{x:0,y:0,z:0},{x:0,y:0,z:0,w:0},1,90,0,0,false,{r:0,g:0,b:0,a:0});
    this.cam = await this.rf.createCamera({name:'Camera'});
    this.cam.fov = Math.PI / 4;
    this.cam.clearColor = {r:255,g:255,b:255,a:1} ;

    this.cam.enabled = true;
    this.cam.postProcess = {toneMapping:{
      exposure:1,
      type:ToneMappingType.ACES
    }};
    this.startInfoTrace();
  }

  enableCamera_name(name:string){
    let index = this.cameraIndex.get(name);
    if(!index) return;
    this.cams[index].enabled = !this.cams[index].enabled;
  }

  addCamera(cam:Camera){
    this.cameraIndex.set(cam.name, this.cams.length);
    this.cams.push(cam);
  }

  Distance2to3_vp(d:number,depth:number): number{
    if(!this.uiContext) return 0;
    let px = this.uiContext.vp2px(d);
    return this.Distance2to3_px(px,depth);
  }

  Distance2to3_px(d:number,depth:number):number{
    let f = d / this.screenSize.height;
    let fov = this.getFov() as number;
    let tanY = Math.tan(fov / 2);
    let h = tanY * depth * 2;
    return h * f;
  }

  CalDepth(target:Vec3): number | undefined{
    if(!this.cam) return undefined;
    let t = CalcUtils.sub(target, this.cam.position);
    let forward = this.getForward() as Vec3;
    return CalcUtils.dot(t, forward);
  }

  /* 0:Info, 1:move, 2:rotation */
  intervalArray:number[] = new Array(2).fill(0)

  getRotation():Quaternion | undefined{
    if(!this.cam) return undefined;
    return {x: this.cam.rotation.x, y: this.cam.rotation.y, z: this.cam.rotation.z, w: this.cam.rotation.w};
  }

  getFov(): number | undefined {
    if(!this.cam) return undefined;
    return this.cam.fov;
  }

  getPosition():Vec3 | undefined {
    if(!this.cam) return undefined;
    return {x:this.cam.position.x, y: this.cam.position.y, z: this.cam.position.z };
  }

  getForward():Vec3 | undefined {
    if(!this.cam) return undefined;
    return CalcUtils.rotate_Vec3_Quaternion(NEG_Z,this.cam.rotation);
  }

  getDefaultForward(): Vec3 {
    return NEG_Z;
  }

  getRight():Vec3 | undefined {
    if(!this.cam) return undefined;
    return CalcUtils.rotate_Vec3_Quaternion(X,this.cam.rotation);
  }

  getDefaultRight():Vec3 {
    return X;
  }

  getUp(): Vec3 | undefined {
    if(!this.cam) return undefined;
    return CalcUtils.rotate_Vec3_Quaternion(Y, this.cam.rotation);
  }

  getDefaultUp(): Vec3 {
    return Y;
  }

  startInfoTrace(){
    if(this.intervalArray[0] != 0) return;
    this.intervalArray[0] = setInterval(() => {
      if(!this.cameraInfo || !this.cam) return;
      this.cameraInfo.copyFromNode(this.cam)
      this.realTimeInfo = this.cameraInfo.toString()
      console.info(this.realTimeInfo)
    },1000)
  }

  stopInfoTrace(){
    Helper.clearIntervalArray(this.intervalArray,0)
  }

}