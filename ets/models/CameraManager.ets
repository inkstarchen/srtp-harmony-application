
import {
  BloomSettings,
  Camera, Color, Quaternion, SceneResourceFactory,
  ToneMappingSettings,
  ToneMappingType,
  Vec2,
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
  ScreenZ: number = 4;
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

  Position3to2(pos:Vec3): Vec2 | undefined{
    let depth = this.CalDepth(pos) as number;
    let camToPos = CalcUtils.sub(pos, this.getPosition() as Vec3);
    let Right = CalcUtils.dot(camToPos,this.getRight() as Vec3);
    let Up = CalcUtils.dot(camToPos, this.getUp() as Vec3);
    return {
      x: this.Distance3to2_px(Right,depth) + this.screenSize.width / 2,
      y: this.screenSize.height / 2 - this.Distance3to2_px(Up,depth)
    };
  }

  Position2to3_vp(v:Vec2): Vec3 | undefined{
    if(!this.uiContext) return undefined;
    let v_px = { x:this.uiContext.vp2px(v.x), y: this.uiContext.vp2px(v.y)} as Vec2;
    return this.Position2to3_px(v_px);
  }

  Position2to3_px(v:Vec2): Vec3 | undefined{
    let Px = v.x / this.screenSize.width * 2 - 1;
    let Py = 1 - v.y / this.screenSize.height * 2;


    let camPosition = this.getPosition() as Vec3;
    let fov = this.getFov() as number;
    let tanA = Math.tan( fov / 2);

    let FB = this.getForward() as Vec3;
    let rotation = this.getRotation() as Quaternion;
    if(rotation.x == 0 && rotation.y == 0 && rotation.z == 0){
      FB = this.getDefaultForward();
    }

    let RL:Vec3 = CalcUtils.NormVec3(CalcUtils.cross(FB,this.getDefaultUp()));
    let UD:Vec3 = CalcUtils.NormVec3(CalcUtils.cross(RL,FB));
    // console.info('Direction FB:' + FB.x + '/' + FB.y + '/' + FB.z + '\n');
    // console.info('Direction UD:' + UD.x + '/' + UD.y + '/' + UD.z + '\n');
    // console.info('Direction RL:' + RL.x + '/' + RL.y + '/' + RL.z + '\n');
    let h = this.ScreenZ * tanA;
    let w = h * this.screenSize.width / this.screenSize.height;
    let t2 = h * Py;
    let t3 = w * Px;
    let dot = {x: camPosition.x + this.ScreenZ * FB.x + t2 * UD.x + t3 * RL.x,
      y: camPosition.y + this.ScreenZ * FB.y + t2 * UD.y + t3 * RL.y,
      z: camPosition.z + this.ScreenZ * FB.z + t2 * UD.z + t3 * RL.z,} as Vec3;
    console.info('dot position: ' + dot.x + '/' + dot.y + '/' + dot.z);
    return dot;
  }

  Distance3to2_vp(d:number, depth:number):number {
    if(!this.uiContext) return 0;
    let px = this.Distance3to2_px(d,depth);
    return this.uiContext.px2vp(px);
  }

  Distance3to2_px(d:number, depth:number):number {
    let fov = this.getFov() as number;
    let tanY = Math.tan(fov / 2);
    let h = tanY * depth * 2;
    return (d / h) * this.screenSize.height;
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