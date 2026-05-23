import mediaquery from '@ohos.mediaquery';
import { BreakpointConstants } from './BreakpointConstants';
import { display, UIContext } from '@kit.ArkUI';

export class BreakpointManager {
  private static instance: BreakpointManager;
  private listener: mediaquery.MediaQueryListener | null = null;
  private context:UIContext | null = null;
  private callbacks: Array<(breakpoint:string) => void> = [];

  constructor(context:UIContext | undefined) {
    if(context) this.context = context;
  }

  static getInstance(context:UIContext | undefined): BreakpointManager {
    if(!BreakpointManager.instance){
      BreakpointManager.instance = new BreakpointManager(context);
    }
    return BreakpointManager.instance;
  }


  startListening(callback: (breakpoint: string) => void){
    this.callbacks.push(callback);

    if(this.listener || !this.context) return;

    const condition = '(min-width: 0vp)';
    this.listener = this.context.getMediaQuery().matchMediaSync(condition);

    this.listener.on('change',(result:mediaquery.MediaQueryResult) => {
      if(!this.context) return;
      let displayClass: display.Display | null = null;
      try {
        displayClass = display.getDefaultDisplaySync();
        const width = this.context.px2vp(displayClass.width);
        const breakpoint = this.getBreakpoint(width);
        this.callbacks.forEach(cb => cb(breakpoint));
      } catch (exception) {
        console.error(`Failed to get default display. Code: ${exception.code}, message: ${exception.message}`);
      }
    });

    let displayClass: display.Display | null = null;
    try {
      displayClass = display.getDefaultDisplaySync();
      const initialWidth = this.context.px2vp(displayClass.width);
      const initialBreakpoint = this.getBreakpoint(initialWidth);
      callback(initialBreakpoint);
    } catch (exception) {
      console.error(`Failed to get default display. Code: ${exception.code}, message: ${exception.message}`);
    }

  }

  private getBreakpoint(width: number): string {
    if(width <= BreakpointConstants.XS_MAX){
      return BreakpointConstants.TYPE_XS;
    } else if (width <= BreakpointConstants.SM_MAX){
      return BreakpointConstants.TYPE_SM;
    } else if (width <= BreakpointConstants.MD_MAX){
      return BreakpointConstants.TYPE_MD;
    } else if (width <= BreakpointConstants.LG_MAX){
      return BreakpointConstants.TYPE_LG;
    } else {
      return BreakpointConstants.TYPE_XL;
    }
  }

  stopListening() {
    if (this.listener) {
      this.listener.off('change');
      this.listener = null;
    }
  }
}