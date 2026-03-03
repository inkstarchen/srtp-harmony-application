import { PageId } from "../shared/utils/PosLimiter";


export enum NavDirection{
  LEFT = 0,
  BOTTOM = 1,
  RIGHT = 2,
  TOP = 3,
  NONE = 4
}



@Preview
@ComponentV2
export struct Test{
  @Param navDirection: NavDirection = NavDirection.NONE;
  @Param nextPage: PageId = PageId.NONE;

  build() {
    Stack({alignContent:Alignment.Center}){
      if(this.navDirection === NavDirection.TOP && this.nextPage != PageId.NONE){
        Stack({alignContent:Alignment.Top}){
          Column(){

          }
          .backgroundColor("#0000ffcc")
          .height("10%")
          .width("100%")
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .width("100%")
        .height("100%")
      }
      if(this.navDirection === NavDirection.BOTTOM && this.nextPage!= PageId.NONE){
        Stack({alignContent:Alignment.Bottom}){
          Column(){

          }
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
          .backgroundColor("#00ffffff")
          .height("10%")
          .width("100%")
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .width("100%")
        .height("100%")
      }
      if(this.navDirection === NavDirection.LEFT && this.nextPage != PageId.NONE){
        Stack({alignContent:Alignment.Start}){
          Column(){
            SymbolGlyph($r("sys.symbol.arrow_right_circle"))
              .fontSize(40)
              .fontColor(["#ff9d9d9d"])
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor("#00ffffff")
          .height("100%")
          .width("20%")
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .width("100%")
        .height("100%")
      }
      if(this.navDirection === NavDirection.RIGHT && this.nextPage != PageId.NONE){
        Stack({alignContent:Alignment.End}){
          Column(){
            SymbolGlyph($r("sys.symbol.arrow_left_circle"))
              .fontSize(40)
              .fontColor(["#ff9d9d9d"])
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor("#00ffffff")
          .height("100%")
          .width("20%")
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
        .width("100%")
        .height("100%")
      }
    }
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP,SafeAreaEdge.BOTTOM])
    .width("100%")
    .height("100%")
    .backgroundColor("#00ffffff")
  }
}