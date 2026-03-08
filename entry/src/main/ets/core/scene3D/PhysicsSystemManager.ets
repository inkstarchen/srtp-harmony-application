import { PhysicsData, PhysicsAdapter, ShapeType} from "./PhysicsAdapter"
import { Node, Quaternion, Vec3 } from "@ohos.graphics.scene";
import { PhysicsSystem } from "libphysics.so";
import { gamePerformance } from "@kit.GameServiceKit";
import { systemDateTime } from "@kit.BasicServicesKit";
import { sensor } from "@kit.SensorServiceKit";

export class PhysicsSystemManager {
  private idMap: Map<string, number> = new Map();
  private nodeMap: Map<string, Node> = new Map();
  private physicsDataMap: Map<string, PhysicsData> = new Map();
  private capacity: number = 128;
  private lastTime: number = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false);
  private physicsSystem: PhysicsSystem = new PhysicsSystem(this.capacity);
  private angle: Vec3 = {x:0,y:0,z:0};


  constructor() {
    sensor.on(sensor.SensorId.ORIENTATION, (data: sensor.OrientationResponse) => {
      this.angle = {x:data.beta, y:data.gamma, z:data.alpha};
    }, { interval: 20 });
  }

  getId(path:string) :number |undefined{
    return this.idMap.get(path);
  }

  // 注册第三方Node
  registerNode(node: Node, isStatic: boolean = false): void {
    let id = this.physicsSystem.addNode(PhysicsAdapter.ToPhysicsData(node, ShapeType.AABB,false));
    this.idMap.set(node.path + '/' + node.name, id);
    this.nodeMap.set(node.name, node);
    console.info("register info " + node.name + '/' + id.toString());
  }

  getNormal(angle:Vec3){
    this.physicsSystem.getNormal(angle);
  }

  setMass(id:number, m:number) {
    this.physicsSystem.setMass(id, m);
  }

  setFriction(id:number, f:number) {
    this.physicsSystem.setFriction(id, f);
  }

  setRotation(id:number, r:Quaternion){
    this.physicsSystem.setRotation(id, r);
  }

  getMass(id:number):number{
    let mass = this.physicsSystem.getMass(id);
    return mass;
  }

  getVel(id:number):Vec3{
    return this.physicsSystem.getVel(id);
  }

  getFric(id:number):number{
    return this.physicsSystem.getFric(id);
  }

  updateNodeData(){
    // this.nodeMap.forEach((node:Node,key:string) => {
      // let id = this.idMap.get(node.path + '/' + node.name);
      // this.physicsSystem.setForce(id, {x:0,y:1,z:0});
      // console.info("update info id:" + id?.toString());
    // })
    this.physicsSystem.getNormal(this.angle);
    let nowTime = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false);
    let dt = (nowTime - this.lastTime) / 1000 ;
    let buffer = this.physicsSystem.update(dt);
    this.lastTime = nowTime;
    // console.info("update info buffer length is" + buffer?.byteLength);
    this.nodeMap.forEach((node:Node, key:string) => {
      let id = this.idMap.get(node.path + '/' + node.name);
      if(id != undefined){
        if(buffer){
          let dataView = new Float32Array(buffer);
          node.position.x = dataView[id];
          node.position.y = dataView[id + this.capacity];
          node.position.z = dataView[id + this.capacity * 2];
          node.rotation.x = dataView[id + this.capacity * 3];
          node.rotation.y = dataView[id + this.capacity * 4];
          node.rotation.z = dataView[id + this.capacity * 5];
          node.rotation.w = dataView[id + this.capacity * 6];
          // console.info("check data id" + id.toString() + "pos :" + node.position.z);
        } else {
          console.info("update info buffer is undefined")
        }
      }
    })
    // return this.nodeMap.get(name);
  }

  setVelocity(id:number,v: Vec3){
    this.physicsSystem.setVelocity(id, v);
  }

  setStatic(id:number,isStatic:boolean){
    this.physicsSystem.setIsStatic(id,isStatic ? 1 :0 );
  }

  setRestitution(id:number, r:number){
    this.physicsSystem.setRestitution(id, r);
  }

  setPosition(id:number, position:Vec3){
    this.physicsSystem.setPosition(id, position);
  }

  getNode(name:string):Node|undefined{
    return this.nodeMap.get(name);
  }



  // 获取Node的物理状态
  getPhysicsData(nodeId: string): PhysicsData | undefined {
    return this.physicsDataMap.get(nodeId);
  }
}