
@ObservedV2
export class BannerDisplay {
  @Trace id: number = 0;
  @Trace banner: BannerClass | undefined = undefined;
  @Trace zIndex: number = 0;
  @Trace angle: number = 0;

  constructor(zIndex:number, banner:BannerClass) {
    this.id = Date.now();
    this.banner = banner;
    this.zIndex = zIndex;
  }
}

@ObservedV2
export class BannerClass {
  @Trace id: string = '';
  @Trace imgSrc: string | ResourceStr = '';
  url: string = '';
  front: BannerClass = this;
  next: BannerClass = this;

  constructor(id: string, imgSrc: string | ResourceStr, url: string) {
    this.id = id;
    this.imgSrc = imgSrc;
    this.url = url;
  }

  Set_front(front_node: BannerClass) {
    this.front = front_node;
  }

  Set_next(next_node: BannerClass) {
    this.next = next_node;
  }

  Get_front() {
    return this.front;
  }

  Get_next() {
    return this.next;
  }
}