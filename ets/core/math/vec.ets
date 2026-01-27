@ObservedV2
export class TraceVec3{
  @Trace x: number = 0;
  @Trace y: number = 0;
  @Trace z: number = 0;

  clip(threshold:number){
    if(this.x > threshold) this.x = threshold;
    if(this.x < -threshold) this.x = -threshold;
    if(this.y > threshold) this.y = threshold;
    if(this.y < -threshold) this.y = -threshold;
    if(this.z > threshold) this.z = threshold;
    if(this.z < -threshold) this.z = -threshold;
  }
}

@ObservedV2
export class TraceVec2{
  @Trace x:number = 0;
  @Trace y:number = 0;

  clip(xMinT:number, xMaxT:number, yMinT:number, yMaxT:number){
    if(this.x < xMinT) this.x = xMinT;
    if(this.x > xMaxT) this.x = xMaxT;
    if(this.y < yMinT) this.y = yMinT;
    if(this.y > yMaxT) this.y = yMaxT;
  }
}