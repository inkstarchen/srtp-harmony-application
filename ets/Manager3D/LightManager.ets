import { LightInfo } from "../utils/InfoClass";
import { Light, LightType, Quaternion, SceneResourceFactory, Vec3 } from "@kit.ArkGraphics3D";
import { Helper } from "../utils/Helper";
import { NodeControlEventType } from "../utils/EventTypes";
import { Constants } from "../constants/Constants";
import { CalcUtils } from "../utils/calutils";

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
  moveState:NodeControlEventType = NodeControlEventType.NONE;

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

  startMove(){
    if(this.intervalArray[1] != 0) return;
    this.intervalArray[1] = setInterval(() => {
      if(!this.light) return
      switch (this.moveState){
        case NodeControlEventType.NONE:{
          break;
        }
        case NodeControlEventType.MOVE_LEFT:{
          this.light.position.x -= Constants.CONTROL_STEP * 0.025;
          break;
        }
        case NodeControlEventType.MOVE_RIGHT:{
          this.light.position.x += Constants.CONTROL_STEP * 0.025;
          break;
        }
        case NodeControlEventType.MOVE_UP:{
          this.light.position.y += Constants.CONTROL_STEP * 0.025;
          break;
        }
        case NodeControlEventType.MOVE_DOWN:{
          this.light.position.y -= Constants.CONTROL_STEP * 0.025;
          break;
        }
        case NodeControlEventType.MOVE_FORWARD:{
          this.light.position.z -= Constants.CONTROL_STEP * 0.025;
          break;
        }
        case NodeControlEventType.MOVE_BACKWARD:{
          this.light.position.z += Constants.CONTROL_STEP * 0.025;
          break;
        }
        default :
          break;
      }
    },25)
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

  stopMove(){
    Helper.clearIntervalArray(this.intervalArray,1)
  }

  stopRotate(){
    if(!this.light) return;
    this.quaternion = this.light.rotation;
    Helper.clearIntervalArray(this.intervalArray,2)
  }

}