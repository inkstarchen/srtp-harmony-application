import { AnimatorOptions } from "@ohos.animator";

export class Constants{
  // 日志域
  static readonly DOMAIN_UI_NOTE = 0x1100;
  static readonly DOMAIN_SERVICE_NOTE = 0x2100;

  static readonly buttonHeight:number = 40;
  static readonly buttonWidth:number = 70;
  static readonly buttonFontSize: number = 17;

  static readonly SM_BORDER: BorderOptions = {radius:5,width:0,color:"#fffdfdfd"};

  static readonly MD_BORDER: BorderOptions = {radius:10,width:0,color:"#fffdfdfd"};

  static readonly SM_LINE_BORDER: BorderOptions = {radius:5,width:1,color:"#ffdddddd"};

  static readonly MD_LINE_BORDER: BorderOptions = {radius:10,width:1,color:"#ffdddddd"};

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

  static readonly ANIMATION_OPTION_2: AnimatorOptions = {
    duration: 2000,
    easing: 'ease-in-out',
    delay: 0,
    fill: 'forwards',
    direction: 'normal',
    iterations: 1,
    begin: 0,
    end: 1
  };

  static readonly ANIMATION_OPTION_QUICK: AnimatorOptions = {
    duration: 500,
    easing: 'ease-in-out',
    delay: 0,
    fill: 'forwards',
    direction: 'normal',
    iterations: 1,
    begin: 0,
    end: 1
  };

}

