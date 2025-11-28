import { preferences } from "@kit.ArkData";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { BusinessError } from "@kit.BasicServicesKit";

const DOMAIN = 0x0001;
const TAG = 'PreferencesTag';

export class PreferencesUtil {
  public static preference?: preferences.Preferences;

  public static getAppPreferences(context:Context){
    PreferencesUtil.preference = preferences.getPreferencesSync(context, { name: 'appPreferences'});
    hilog.info(DOMAIN, TAG, 'create success')
  }

  public static getScreenData(): Size{
    let ScreenWidth = PreferencesUtil.preference?.getSync('ScreenWidth', 0) as number;
    let ScreenHeight = PreferencesUtil.preference?.getSync('ScreenHeight', 0) as number;
    let ScreenData: Size = {width:ScreenWidth, height:ScreenHeight};
    return ScreenData;
  }

  public static saveScreenData(screenData:Size){
    PreferencesUtil.preference?.putSync('ScreenWidth', screenData.width);
    PreferencesUtil.preference?.putSync('ScreenHeight', screenData.height);
    PreferencesUtil.preference?.flush(
      (err: BusinessError) => {
        if(err){
          hilog.error(DOMAIN,TAG, 'Failed to flush, code=' + err.code + ', message = ' + err.message);
          return;
        }
        hilog.info(DOMAIN, TAG, 'Succeeded in flushing.');
      });
  }
}