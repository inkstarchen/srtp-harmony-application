@Preview
@ComponentV2
export struct Board{
  @Event changeLineWidth:(value:number) => void;
  @Event changeColor:(value:string) => void;
  @Local color:string[] = ['#ffff0000','#ff06ff00','#ff2d1bcd','#fffcce18','#fff']
  build() {
    Column({space:20}){
      Slider({
        style:SliderStyle.OutSet,
        step:1,
        min:1,
        max:10,
      })
        .blockStyle({ type: SliderBlockType.DEFAULT })
        .onChange((value:number) =>{
          this.changeLineWidth(value);
        })
        .margin(5)
      Grid(){
        ForEach(this.color,(item:string,index:number) => {
          GridItem(){

          }
          .backgroundColor(item)
          .width(20)
          .height(20)
          .margin(5)
          .border({radius:2,color:'#fffcc8c8',width:2})
          .onClick(() => {
            this.changeColor(item)
          })
        })
      }

    }
    .backgroundColor('#fff')
    .borderRadius(25)
    .width(200)
    .shadow({radius:10,color:'#ffb7b7b7'})
    .height(100)
  }
}