import { PhysicsData, PhysicsAdapter, ShapeType} from "./PhysicsAdapter"
import { Node, Quaternion, Vec3 } from "@ohos.graphics.scene";
import { PhysicsSystem } from "libphysics.so";
import { gamePerformance } from "@kit.GameServiceKit";
import { systemDateTime } from "@kit.BasicServicesKit";
import { sensor } from "@kit.SensorServiceKit";
import { EventCommand, EventType, ReturnData } from "./EventTypes";
import { CameraConfig, generateLayoutConfigForCameraView, LayoutConfig } from "./layout/CameraViewUtils";

export class PhysicsSystemManager {
  private idMap: Map<string, number> = new Map();
  private nodeMap: Map<string, Node> = new Map();
  selectId: number = 0;
  available: boolean = false;
  private capacity: number = 128;
  private lastTime: number = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false);
  private physicsSystem: PhysicsSystem = new PhysicsSystem(this.capacity);
  angle: Vec3 = {x:0,y:0,z:0};

  // 获取底层 PhysicsSystem 实例（用于事件队列初始化）
  getPhysicsSystem(): PhysicsSystem {
    return this.physicsSystem;
  }

  enableLayout(cameraConfig: CameraConfig){
    let config: LayoutConfig = generateLayoutConfigForCameraView(
      -1, 3, 4, 0.1,0.1, 0.1, cameraConfig
    );
    this.physicsSystem.enableLayout(config);
  }

  constructor() {
    sensor.on(sensor.SensorId.ORIENTATION, (data: sensor.OrientationResponse) => {
      this.angle = {x:data.beta, y:data.gamma, z:data.alpha};
    }, { interval: 20 });
  }

  releaseScene(){
    this.available = false;
    this.physicsSystem.release();
    this.idMap.clear();
    this.nodeMap.clear();
  }

  setAvailable(){
    this.available = true;
    this.lastTime = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE,false);
  }

  getId(path:string) :number |undefined{
    return this.idMap.get(path);
  }

  // 注册第三方Node
  registerNode(node: Node, isStatic: boolean = true): number {
    let id = this.physicsSystem.addNode(PhysicsAdapter.ToPhysicsData(node, ShapeType.AABB, isStatic));
    this.idMap.set(node.path + '/' + node.name, id);
    this.nodeMap.set(node.name, node);
    console.info("RegisterNode | " + node.name + '/' + id.toString());
    return id;
  }

  updateNodeData(eventCommands:EventCommand[][]){
    if(!this.available) return;
    // this.physicsSystem.getNormal(this.angle);
    let nowTime = systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false);
    let dt = (nowTime - this.lastTime) / 1000 ;
    let returnData:ReturnData = this.physicsSystem.update(eventCommands,dt);
    let buffer = returnData.bufferData;
    let eventResult = returnData.results;
    eventResult.forEach((result) => {
      if(result.type == EventType.RAYCAST_REQUEST){
        if(result.status == 1){
          this.selectId = result.nodeId;
          let data = result.data;
          // console.info("Raycast ArkTs | nodeId " + result.nodeId.toString() + "\ndistance " + data[1].toString() + "\npos " + data[2].toString() + '/' + data[3].toString() + '/' + data[4].toString());
        }
      }
    })
    this.lastTime = nowTime;
    // console.info("update info buffer length is" + buffer?.byteLength);
    this.nodeMap.forEach((node:Node, key:string) => {
      let id = this.idMap.get(node.path + '/' + node.name);
      if(id != undefined){
        if(buffer){
          let dataView = new Float32Array(buffer);
          // 同步位置
          node.position.x = dataView[id];
          node.position.y = dataView[id + this.capacity];
          node.position.z = dataView[id + this.capacity * 2];
          // 同步旋转
          node.rotation.x = dataView[id + this.capacity * 3];
          node.rotation.y = dataView[id + this.capacity * 4];
          node.rotation.z = dataView[id + this.capacity * 5];
          node.rotation.w = dataView[id + this.capacity * 6];
          node.scale.x = dataView[id + this.capacity * 7];
          // console.info("update id" + id.toString() +  "scalex is" + node.scale.x.toString());
          node.scale.y = dataView[id + this.capacity * 8];
          node.scale.z = dataView[id + this.capacity * 9];
        } else {
          console.info("update info buffer is undefined")
        }
      }
    })
    // return this.nodeMap.get(name);
  }

  getNode(name:string):Node|undefined{
    return this.nodeMap.get(name);
  }

  // 根据物理 ID 获取节点
  getNodeById(id: number): Node | undefined {
    let result: Node | undefined;

    this.idMap.forEach((nodeId, path) => {
      if (nodeId === id) {
        this.nodeMap.forEach((node, name) => {
          if (node.path + '/' + node.name === path) {
            result = node;
          }
        });
      }
    });
    return result;
  }

}
