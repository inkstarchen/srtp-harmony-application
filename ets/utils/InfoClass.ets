import {
  BloomSettings,
  Camera,
  Color, Light, LightType, Node, PostProcessSettings, Quaternion,
  ToneMappingSettings,
  Vec3 } from "@kit.ArkGraphics3D";

export class NodeInfo{

  constructor(name:string,position:Vec3,rotation:Quaternion,scaleV:number) {
    this.name = name;
    this.position = position;
    this.rotation = rotation;
    this.scale = scaleV;
  }

  copyFromNode(node:Node){
    this.name = node.name;
    this.position = node.position;
    this.rotation = node.rotation;
    this.scale = node.scale.x;
  }

  name:string = '';
  position:Vec3 = {x:0,y:0,z:0}
  rotation:Quaternion = {x:0,y:1,z:0,w:0}
  scale:number = 1;

  toString():string {
    let nodeInfo = '';
    nodeInfo += 'Name: ' + this.name + '\n';
    nodeInfo += 'Position | x: ' + this.position.x + ' / y: ' + this.position.y + ' / z: ' + this.position.z + '\n';
    nodeInfo += 'Rotation | x: ' + this.rotation.x + ' / y: ' + this.rotation.y + ' / z: ' + this.rotation.z + ' / w: ' + this.rotation.w + '\n';
    nodeInfo += 'Scale | ' + this.scale + '\n';
    return nodeInfo;
  }
}

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