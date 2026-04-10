@Preview
@ComponentV2
export struct imageCard{

  @Require @Param ImageUri: string;
  @Local text:string = "今天的天气真好，我想要去旅行";
  build() {
    Stack(){
      Column({space:20}){
        // Image(this.ImageUri)
        Column(){

        }
        .backgroundColor("#ffff0000")
        .width("100%")
        .height("80%")
        .border({radius:15,width:0})

        Text(this.text)
      }
      .backgroundColor("#fff")
      .border({radius:20,width:0})
      .shadow({radius:20,color:"#ffd9d9d9",offsetY:20})
      .padding(20)
      .width(300)
      .height(600)
    }
    .width("100%")
    .height("100%")
  }
}