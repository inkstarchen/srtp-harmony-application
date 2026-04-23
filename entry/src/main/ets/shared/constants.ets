import { AnimatorOptions } from "@ohos.animator";

export class Constants{
  // 日志域
  static readonly DOMAIN_UI_NOTE = 0x1100;
  static readonly DOMAIN_SERVICE_NOTE = 0x2100;

  static readonly ANIMATION_OPTION: AnimatorOptions = {
    duration: 2000,
    easing: 'ease',
    delay: 0,
    fill: 'none',
    direction: 'normal',
    iterations: -1,
    begin: 100,
    end: 200
  };

}

