import { matrix4 } from "@kit.ArkUI";
import { RotationState } from "../../../shared/utils/TouchManager";

const radius = 300;

@ObservedV2
export class SphereLayoutInfo{
  @Trace zIndex: number;
  @Trace translateMatrix: Matrix4Transit;
  @Trace angle: number;
  @Trace expand: boolean;
  constructor(globalAngle:number,angle:number) {
    this.angle = angle;
    let totalAngle = -180 + (540 + angle + globalAngle) % 360;
    let range = 36;
    this.zIndex = Math.abs(angle) >= 90 ? 0 : 100;
    this.translateMatrix = matrix4.identity().rotate({y:1,angle:totalAngle}).translate({x:Math.sin(totalAngle * Math.PI / 180) * radius})
    this.expand = (totalAngle < range && totalAngle > -range);
  }

  update(angle:number){
    let totalAngle = -180 + (540 + angle + this.angle) % 360;
    let lastZIndex = this.zIndex;
    let range = 36;
    this.zIndex = Math.abs(totalAngle) >= 90 ? 0 : 100;
    // if(lastZIndex != this.zIndex) console.info("angle " + this.angle.toString() + "change global" + angle.toString() )
    this.translateMatrix = matrix4.identity().rotate({y:1,angle:totalAngle}).translate({x:Math.sin(totalAngle * Math.PI / 180) * radius})
    this.expand = (totalAngle < range/2 && totalAngle > -range/2);
  }
}

export interface SpherePoint {
  id: number;
  angle: number;
}

export class SpherePointGenerator {
  static generateUniformPoints(count: number): SpherePoint[] {
    const points: SpherePoint[] = [];
    let anglePer = 360 / count;
    for (let i = 0; i < count; i++) {
      // 核心公式：使用 arccos 实现纬度均匀分布
      points.push({
        id: i,
        angle: -180 + (180 + i * anglePer) % 360  // 待计算
      } as SpherePoint);
    }
    return points;
  }

}

export class RotationMapper {
  private points: SpherePoint[];
  private occupied: boolean[] = [];
  count:number;

  constructor(count:number) {
    this.count = count;
    this.points = SpherePointGenerator.generateUniformPoints(count);
    for(let i = 0; i < count ; i++){
      this.occupied.push(false);
    }
  }

  /**
   * 通过ID获取点信息
   */
  getPointById(id: number): SpherePoint | undefined {
    if(id >= this.count) return undefined;
    return this.points[id];
  }

}
