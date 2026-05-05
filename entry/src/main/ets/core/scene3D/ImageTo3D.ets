import { ImageUtils } from "../../shared/utils/ImageUtils";
import { getDateByTimeStamp } from "../../shared/utils/Time/time";
import { SceneProxy } from "./GlobalSceneProxy";

export async function captureAndDisplay(ui:UIContext, sceneProxy:SceneProxy) {
  let now = Date.now();
  let timeArray = getDateByTimeStamp(now);
  let array: Array<string> = [];
  let interPath:string = `/photoCards/${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`;
  let CardName = `${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`
  await ImageUtils.TakePictureAndSave(ui.getHostContext(),interPath);
  let fileDir = ui.getHostContext()?.getApplicationContext().filesDir;
  // let pixMap = await ui.getComponentSnapshot().get("page");
  // await ImageUtils.savePixelMapToFile(pixMap, fileDir + interPath + '/component.png');
  if(fileDir){
    // array.push(fileDir + interPath + '/capture.png');
    // array.push(fileDir + interPath + '/component.png');
    // let loadPixmap = ImageUtils.TwoImageStencil(array, false);
    // if(loadPixmap){
    //   await ImageUtils.savePixelMapToFile(loadPixmap, fileDir + interPath + '/fix.png');
      sceneProxy.addCard(fileDir + interPath + '/capture.png',CardName);
    // }
  }
}