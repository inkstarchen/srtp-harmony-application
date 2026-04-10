import { display, Size } from "@kit.ArkUI";
export const SHADOW_FLOAT = {radius:15,offsetY:10,color: "#ffc8c8c8" } as ShadowOptions;
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

