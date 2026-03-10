import { display, Size } from "@kit.ArkUI";

/**
 * 获取屏幕尺寸
 */
export function getScreenSize(): Size{
  try{
    let data = display.getDefaultDisplaySync();
    return { width: data.width, height: data.height};
  }
  catch (e){
    console.error(`Failed to obtain the default display object. Code:${e.code}, message:${e.message}`);
    return {width: 1280, height: 1960};
  }
}

