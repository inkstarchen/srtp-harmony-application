import { CameraInfo } from "../utils/InfoClass";
import { Camera, Quaternion, SceneResourceFactory, ToneMappingType } from "@kit.ArkGraphics3D";
import { Helper } from "../utils/Helper";
import { NodeControlEventType } from "../utils/EventTypes";
import { CalcUtils } from "../utils/calutils";
import { Constants } from "../constants/Constants";
import { AnimatorResult } from "@kit.ArkUI";

@ObservedV2
export class CameraManager{

  cameraInfo:CameraInfo | undefined = undefined;
  @Trace realTimeInfo: string = '';
  cam:Camera | undefined = undefined;
  rf:SceneResourceFactory | undefined = undefined;

  quaternion:Quaternion = {
    x:0,
    y:1,
    z:0,
    w:0
  }

  async init(rf:SceneResourceFactory){
    this.rf = rf;
    this.cameraInfo = new CameraInfo('name',{x:0,y:0,z:0},{x:0,y:0,z:0,w:0},1,90,0,0,false,{r:0,g:0,b:0,a:0});
    this.cam = await this.rf.createCamera({name:'Camera'});
    CalcUtils.lookAt(this.cam,{x:0,y:0,z:4},{x:0,y:0,z:0},{x:0,y:1,z:0})
    this.cam.fov = Math.PI / 4;
    this.cam.clearColor = {r:255,g:255,b:255,a:1} ;
    this.cam.enabled = true;
    this.cam.postProcess = {toneMapping:{
      exposure:1,
      type:ToneMappingType.ACES
    }};
    this.startInfoTrace();
  }

  /* 0:Info, 1:move, 2:rotation */
  intervalArray:number[] = new Array(2).fill(0)
  angleX:number = 0;
  angleY:number = 0;
  angleXLast:number = 0;
  angleYLast:number = 0;

  startInfoTrace(){
    if(this.intervalArray[0] != 0) return;
    this.intervalArray[0] = setInterval(() => {
      if(!this.cameraInfo || !this.cam) return;
      this.cameraInfo.copyFromNode(this.cam)
      this.realTimeInfo = this.cameraInfo.toString()
      console.info(this.realTimeInfo)
    },1000)
  }

  startRotate(){
    if(this.intervalArray[1] != 0) return;
    this.intervalArray[1] = setInterval(() => {
      if(!this.cam) return;
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
      this.cam.rotation = CalcUtils.qMul(q1,this.quaternion)
    },25)
  }

  stopInfoTrace(){
    Helper.clearIntervalArray(this.intervalArray,0)
  }

  stopRotate(){
    if(!this.cam) return;
    this.quaternion = this.cam.rotation;
    Helper.clearIntervalArray(this.intervalArray,1)
  }
}