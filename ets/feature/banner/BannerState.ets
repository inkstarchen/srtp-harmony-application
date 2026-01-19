@ObservedV2
export class BannerState {
  @Trace id: number = 0;
  @Trace zIndex: number = 0;
  @Trace angle: number = 0;
  front: BannerState = this;
  next: BannerState = this;

  constructor(zIndex:number,id : number) {
    this.id = id;
    this.zIndex = zIndex;
  }

  Set_front(front_node: BannerState) {
    this.front = front_node;
  }

  Set_next(next_node: BannerState) {
    this.next = next_node;
  }

  Get_front() {
    return this.front;
  }

  Get_next() {
    return this.next;
  }
}