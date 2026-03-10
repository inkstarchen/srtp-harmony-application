import { PhysicsSystem } from "libphysics.so";
import { EventType, EventCommand, EventPriority, getDefaultPriority, Property } from "./EventTypes";
import { systemDateTime } from "@kit.BasicServicesKit";
import { Vec3 } from "@kit.ArkGraphics3D";

@ObservedV2
export class EventQueueManager {

  private physicsSystem: PhysicsSystem | null = null;

  // 双缓冲队列
  private writeQueues: EventCommand[][] = [
    [], // HIGH
    [], // NORMAL
    []  // LOW
  ]

  private readQueues: EventCommand[][] = [
    [],
    [],
    []
  ]

  private lastTouchMove: EventCommand | null = null;
  private pendingRayCast: EventCommand | null = null;
  private RotateRequest: EventCommand | null = null;

  init(physicsSystem: PhysicsSystem): void {
    this.physicsSystem = physicsSystem;
  }

  push(event:EventCommand) {
    this.writeQueues[event.priority].push(event)
  }

  getReadQueues():EventCommand[][]{
    return this.readQueues;
  }

  swapQueues() {
    let temp = this.readQueues;
    this.readQueues = this.writeQueues;
    this.writeQueues = temp;
    this.writeQueues.forEach(q => q.length = 0)
    this.lastTouchMove = null;
    this.RotateRequest = null;
    this.pendingRayCast = null;
  }

  pushTouchDown(x: number, y: number): void {
    let e: EventCommand = {
      type: EventType.TOUCH_DOWN,
      priority: getDefaultPriority(EventType.TOUCH_DOWN),
      nodeId: 0,
      timestamp: systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE, false),
      data:[x,y]
    }
    this.push(e);
  }

  pushTouchMove(x: number, y: number): void {
    if(this.lastTouchMove){
      this.lastTouchMove.data = [x,y];
    }else{
      let e:EventCommand = {
        type:EventType.TOUCH_MOVE,
        priority:getDefaultPriority(EventType.TOUCH_MOVE),
        nodeId: 0,
        timestamp: systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE,false),
        data:[x,y]
      };
      this.push(e);
      this.lastTouchMove = e;
    }
  }

  pushTouchUp(): void {
    let e:EventCommand = {
      type:EventType.TOUCH_UP,
      priority:getDefaultPriority(EventType.TOUCH_UP),
      nodeId: 0,
      timestamp: systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE,false),
      data:[]
    };
    this.push(e);
  }

  pushRayCastRequest(fx: number, fy: number): void {
    if(this.pendingRayCast){
      this.pendingRayCast.data = [fx,fy];
    }else{
      let e: EventCommand = {
        type:EventType.RAYCAST_REQUEST,
        priority:getDefaultPriority(EventType.RAYCAST_REQUEST),
        nodeId:0,
        timestamp:systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE,false),
        data:[0,fx,fy]
      };
      this.pendingRayCast = e;
      this.push(e);
    }
  }

  pushRotateRequest(nodeId: number): void {
    if(!this.RotateRequest){
      let e:EventCommand = {
        type:EventType.ROTATE_REQUEST,
        priority:getDefaultPriority(EventType.ROTATE_REQUEST),
        nodeId:nodeId,
        timestamp:systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE,false),
        data:[]
      };
      this.RotateRequest = e;
      this.push(e);
    }
  }

  pushSetRequest(nodeId: number, propertyId: Property, data:number[]){
    let e:EventCommand = {
      type:EventType.SET_PROPERTY_REQUEST,
      priority:getDefaultPriority(EventType.SET_PROPERTY_REQUEST),
      nodeId:nodeId,
      timestamp:systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE,false),
      data: [propertyId].concat(data)
    }
    this.push(e);
  }

  ResetGravity(angle:Vec3){
    let e:EventCommand = {
      type:EventType.RESET_GRAVITY,
      priority:getDefaultPriority(EventType.RESET_GRAVITY),
      nodeId:0,
      timestamp:systemDateTime.getUptime(systemDateTime.TimeType.ACTIVE,false),
      data:[0, angle.x,angle.y,angle.z]
    }
    console.info("ANGLE ARK IS " + angle.x.toString() + '/' + angle.y.toString() + '/' + angle.z.toString());
    this.push(e);
  }

  setStatic(nodeId: number, isStatic: boolean){
    this.pushSetRequest(nodeId, Property.STATIC, [isStatic ? 1 : 0]);
  }

  setPosition(nodeId: number, pos:Vec3){
    this.pushSetRequest(nodeId, Property.POS, [pos.x,pos.y,pos.z]);
  }

  setMass(nodeId: number, mass: number){
    this.pushSetRequest(nodeId, Property.MASS, [mass]);
  }

}