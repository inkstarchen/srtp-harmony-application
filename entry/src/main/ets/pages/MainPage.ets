import { SingleColumnLayoutMain } from "../feature/mainDisplay/SingleColumnLayoutMain"
import { TwoColumnLayout } from "../feature/mainDisplay/TwoColumnLayoutMain";
import { BreakpointConstants } from "../shared/BreakPoint/BreakpointConstants"
import { BreakpointManager } from "../shared/BreakPoint/BreakpointManager";


@Entry
@ComponentV2
export struct MainPage {
  @Local currentBreakpoint: string = BreakpointConstants.TYPE_SM;
  @Local context: UIContext = this.getUIContext();

  aboutToAppear(): void {
    BreakpointManager.getInstance(this.getUIContext()).startListening((breakpoint:string) => {
      this.currentBreakpoint = breakpoint;
      console.info(`当前断点: ${breakpoint}`);
    })
  }

  build() {
    Column(){
      if(this.currentBreakpoint === BreakpointConstants.TYPE_SM){
        SingleColumnLayoutMain()
      }else{
        TwoColumnLayout()
      }
    }
    .width("100%")
    .height("100%")
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
  }

  pageTransition() {
    PageTransitionEnter({delay:500, duration:250,curve:Curve.Linear})
      .opacity(0)
    PageTransitionExit({delay:0, duration:250,curve:Curve.Linear})
      .opacity(0)
  }
}