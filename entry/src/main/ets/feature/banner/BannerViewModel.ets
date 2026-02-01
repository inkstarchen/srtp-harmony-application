import { AnimatorResult } from "@kit.ArkUI";
import { BannerState } from "./BannerState";

@ObservedV2
export class BannerViewModel {
  anim: AnimatorResult;
  @Trace bannerList: BannerState[] = [new BannerState(1,0)];
  index:number = 2;
  set:boolean = false;
  @Trace currentIndex: number = 0;
  constructor(uiContext: UIContext) {
    this.anim = uiContext.createAnimator({
      duration:1000,
      delay:0,
      direction:'normal',
      fill:'forwards',
      easing:'ease-out',
      begin:0,
      end:1,
      iterations:1
    });

    this.anim.onFrame = (progress:number) => {
      if(!this.set){
        this.set = true;
      }
      this.bannerList[this.index].zIndex = (2 - progress) < 1.5 ? 2 : 2;
      this.bannerList[this.index].angle = -60 * progress;
      this.bannerList[this.index + 1].zIndex = (1 - progress) < 0.5 ? 0 : 0;
      this.bannerList[this.index + 1].angle = -60 - 60 * progress;
      this.bannerList[this.index + 2].zIndex = (progress > 0.5) ? 0 : 0;
      this.bannerList[this.index + 2].angle = -120 - 60 * progress;
      this.bannerList[this.index + 3].zIndex = 0;
      this.bannerList[this.index + 3].angle = -180 - 60 * progress;
      this.bannerList[this.index - 1].zIndex = (1 + progress) > 1.5 ? 2 : 2;
      this.bannerList[this.index - 1].angle = 60 - 60 * progress;
      this.bannerList[this.index - 2].zIndex = (progress > 0.5) ? 0 : 0;
      this.bannerList[this.index - 2].angle = 120 - 60 * progress;
      if(progress == 1){
        this.currentIndex = (this.currentIndex + 1) % this.bannerList.length;
        let temp = this.bannerList[0];
        for(let i = 0 ; i < this.bannerList.length - 1; i++){
          this.bannerList[i] = this.bannerList[i+1];
        }
        this.bannerList[this.bannerList.length-1] = temp;
        this.set = false;
      }
    }
    let intercalId = setInterval(() => {
      if(this.anim){
        this.anim.play();
      }
    },1500)

  }

  init_test() {
    this.insert_note(1);
    this.insert_note(2);
    this.insert_note(3);
    this.insert_note(4);
    this.insert_note(5);
  }

  insert_note(id:number): void {
    const newBanner = new BannerState(1,id);
    this.bannerList.unshift(newBanner);
    this.rebuildCircularLinks();
    console.log('添加了新Banner:', newBanner);
  }

  private rebuildCircularLinks(): void {
    for (let i = 0; i < this.bannerList.length; i++) {
      const prevIndex = (i - 1 + this.bannerList.length) % this.bannerList.length;
      const nextIndex = (i + 1) % this.bannerList.length;
      this.bannerList[i].Set_front(this.bannerList[prevIndex]);
      this.bannerList[i].Set_next(this.bannerList[nextIndex]);
    }
  }

  getDisplayBanners(): BannerState {
    if(this.bannerList.length==1) {
      this.init_test();
    }
    return this.bannerList[this.currentIndex];
  }

}