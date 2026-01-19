import { PhysicsData, PhysicsAdapter, Vector3} from "./PhysicsAdapter"
import { Node } from "@ohos.graphics.scene";
import { calculateCollisions } from "libentry.so";

export class PhysicsSystemManager {
  private nodeMap: Map<string, Node> = new Map();
  private physicsDataMap: Map<string, PhysicsData> = new Map();

  // 注册第三方Node
  registerNode(node: Node, isStatic: boolean = false): void {
    const physicsData = PhysicsAdapter.nodeToPhysicsData(node);
    physicsData.isStatic = isStatic;

    this.nodeMap.set(node.name, node);

    console.info('Physical Data before: ' + node.name);
    this.physicsDataMap.set(node.name, physicsData);
  }

  // 批量更新物理状态
  update(deltaTime: number): void {
    // 1. 收集所有物理数据
    const physicsDataArray: PhysicsData[] = [];
    this.physicsDataMap.forEach((data:PhysicsData, key: string) => {
      console.info('Physical Data send: ' + data.name);
      physicsDataArray.push(data);  // 浅拷贝
    })
    // 2. 调用C++进行物理计算
    const updatedDataArray = calculateCollisions(physicsDataArray, deltaTime);

    if(Array.isArray(updatedDataArray)){
      updatedDataArray.forEach((physicsData: PhysicsData, index: number) => {
        this.physicsDataMap.set(physicsData.name, physicsData);
        console.info('Physical Data :' + physicsData.name + '/' + physicsData.position.x.toString() +
        '/' + physicsData.velocity.x.toString())
        const node = this.nodeMap.get(physicsData.name);
        if (node) {
          PhysicsAdapter.applyPhysicsToNode(node, physicsData);
        }
      })
    }
  }

  // 为特定Node施加力
  applyForce(nodeId: string, force: Vector3): void {
    const data = this.physicsDataMap.get(nodeId);
    if (data && !data.isStatic) {
      // F = ma, a = F/m
      const acceleration = {
        x: force.x / data.mass,
        y: force.y / data.mass,
        z: force.z / data.mass
      } as Vector3;

      // 简单积分（实际应该考虑deltaTime）
      data.velocity.x += acceleration.x;
      data.velocity.y += acceleration.y;
      data.velocity.z += acceleration.z;
    }
  }

  // 设置Node的速度
  setVelocity(nodeId: string, velocity: Vector3): void {
    const data = this.physicsDataMap.get(nodeId);
    if (data && !data.isStatic) {
      data.velocity = velocity;
    }
  }

  // 获取Node的物理状态
  getPhysicsData(nodeId: string): PhysicsData | undefined {
    return this.physicsDataMap.get(nodeId);
  }
}