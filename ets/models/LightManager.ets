import { Color, Light, LightType, Quaternion, SceneResourceFactory, Vec3 } from "@kit.ArkGraphics3D";
import { Helper } from "../utils/Helper";

import { Constants } from "../constants/Constants";
import { CalcUtils } from "../utils/calutils";
import { NodeInfo } from "./BaseClass";


export class LightInfo extends NodeInfo{

  constructor(name:string,position:Vec3,rotation:Quaternion,scaleV:number,
    lightType:LightType,color:Color,intensity:number,shadowEnabled:boolean,
    enabled:boolean) {
    super(name,position,rotation,scaleV)
    this.lightType = lightType;
    this.color = color;
    this.intensity = intensity;
    this.shadowEnabled = shadowEnabled;
    this.enabled = enabled
  }

  copyFromNode(node:Light){
    this.name = node.name;
    this.position = node.position;
    this.rotation = node.rotation;
    this.scale = node.scale.x;
    this.lightType = node.lightType;
    this.intensity = node.intensity;
    this.color = node.color;
    this.shadowEnabled = node.shadowEnabled;
    this.enabled = node.enabled;
  }

  color:Color = {r:1,g:1,b:1,a:1};
  lightType:LightType = LightType.DIRECTIONAL
  intensity:number = 1;
  shadowEnabled:boolean = false;
  enabled:boolean = false;

  toString():string {
    let nodeInfo = '';
    nodeInfo += 'Name: ' + this.name + '\n';
    nodeInfo += 'Position | x: ' + this.position.x + ' / y: ' + this.position.y + ' / z: ' + this.position.z + '\n';
    nodeInfo += 'Rotation | x: ' + this.rotation.x + ' / y: ' + this.rotation.y + ' / z: ' + this.rotation.z + ' / w: ' + this.rotation.w + '\n';
    nodeInfo += 'Type : ' + (this.lightType == LightType.DIRECTIONAL ? 'Directional' : 'Spot') + '\n';
    nodeInfo += 'Intensity : ' + this.intensity + ' | color | r: ' + this.color.r + ' / g: ' + this.color.g + ' / b: ' + this.color.b + ' / a: ' + this.color.a + '\n';
    nodeInfo += 'Enabled: ' + (this.enabled ? 'true' : 'false') + ' | Shadow : ' + (this.shadowEnabled ? 'true' : 'false') + '\n';
    return nodeInfo;
  }
}

@ObservedV2
export class LightManager{

  lightInfo:LightInfo | undefined = undefined;
  @Trace realTimeInfo: string = '';
  light:Light | undefined = undefined
  lights:Light[] = [];
  /* 0:Info, 1:move, 2:rotate, 3:Intensity */
  intervalArray:number[] = new Array(4).fill(0)
  @Trace shadowEnabled:boolean = false;
  @Trace Enabled:boolean = false;
  angleX:number = 0;
  angleY:number = 0;
  quaternion:Quaternion = {
    x:0,
    y:1,
    z:0,
    w:0
  }


  async init(rf:SceneResourceFactory){
    this.lightInfo = new LightInfo('light',{x:0,y:0,z:0},{x:0,y:1,z:0,w:0},
    1,LightType.SPOT,{r:1,g:1,b:1,a:1},1,false,false);
    let directionalLight = await rf.createLight({name:'Light1'},LightType.SPOT);
    this.light = directionalLight;
    this.lights.push(this.light);
    this.light.enabled = true;
    this.light.intensity = 0.5;
    this.light.shadowEnabled = true;
    this.light.color = {r:255,g:255,b:255,a:0.5} ;
    CalcUtils.lookAt(this.light,{x:0,y:2,z:2},{x:0,y:0,z:0},{x:0,y:1,z:0});
  }

  switchToLight(index:number){
    this.light = this.lights[index];
    this.shadowEnabled = this.light.shadowEnabled;
    this.Enabled = this.light.enabled;
    this.quaternion = this.light.rotation;
    this.angleX = 0;
    this.angleY = 0;
  }

  setIntensity(intensity:number){
    if(!this.light) return;
    this.light.intensity = intensity;
  }

  setRotation(rotation:Quaternion){
    if(!this.light) return;
    this.light.rotation = rotation;
  }

  setPosition(position:Vec3){
    if(!this.light) return;
    this.light.position = position;
  }

  startInfoTrace() {
    if (this.intervalArray[0] != 0) return;
    this.intervalArray[0] = setInterval(() => {
      if (!this.light || !this.lightInfo) return;
      this.lightInfo.copyFromNode(this.light)
      this.realTimeInfo = this.lightInfo.toString()
    }, 25)
  }



  startRotate(){
    if(this.intervalArray[2] != 0) return;
    this.intervalArray[2] = setInterval(() => {
      if(!this.light) return;
      let angleX_t = Math.PI * this.angleX / 360;
      let angleY_t = Math.PI * this.angleY / 360;
      let qx:Quaternion = {
        x: Math.sin(angleX_t),
        y: 0,
        z: 0,
        w: Math.cos(angleX_t)
      }
      let qy:Quaternion = {
        x: 0,
        y: Math.sin(angleY_t),
        z: 0,
        w: Math.cos(angleY_t)
      }
      let q1 = CalcUtils.qMul(qx,qy);
      this.light.rotation = CalcUtils.qMul(q1,this.quaternion)
    },25)

  }

  stopInfoTrace(){
      Helper.clearIntervalArray(this.intervalArray,0);
  }

  stopRotate(){
    if(!this.light) return;
    this.quaternion = this.light.rotation;
    Helper.clearIntervalArray(this.intervalArray,2)
  }

}