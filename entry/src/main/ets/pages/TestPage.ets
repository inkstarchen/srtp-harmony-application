import image from '@ohos.multimedia.image'
import { JSON } from '@kit.ArkTS';
import { ImageUtils } from '../shared/utils/ImageUtils';
import Prompt from '@system.prompt';

@Entry
@ComponentV2
struct TestPage{
  @Local pixmap: image.PixelMap | undefined = undefined;
  @Local loadPixmap: image.PixelMap | undefined = undefined;
  uiContext: UIContext = this.getUIContext();

  build(){
    Column(){

      Row({space: 20}){
        Column(){

        }
        .width(80)
        .height(80)
        .backgroundColor("#ff00c4ff")
        .id("origin")

        Image(this.pixmap)
          .width(80)
          .height(80)

        Image(this.loadPixmap)
          .width(80)
          .height(80)
      }
      .width("100%")
      .height("50%")
      .background("#fffce2e2")

      Button("click")
        .onClick(() => {
          this.uiContext.getComponentSnapshot().get("origin", (error: Error, pixmap: image.PixelMap) => {
            if(error) {
              console.error(`error: ${JSON.stringify(error)}`);
              return;
            }
            this.pixmap = pixmap;
          }, { scale: 2, waitUntilRenderFinished: true });
        }).margin(10)

      Button("save")
        .onClick(() => {
          if(this.pixmap){
            let fileDir = this.uiContext.getHostContext()?.tempDir;
            if(fileDir){
              console.info("Test: SaveDir is " + fileDir)
              ImageUtils.savePixelMapToFile(this.pixmap as image.PixelMap,fileDir + "/temp.png")
                .then((result) => {
                  if(result){
                    Prompt.showToast({message: "saved"})
                  }else{
                    Prompt.showToast({message:"failed"})
                  }
                })
            }
          }
        })

      Button("load")
        .onClick(() => {
          let fileDir = this.uiContext.getHostContext()?.tempDir;
          if(fileDir){
            ImageUtils.loadPixelMapFromFile(fileDir + '/temp.png')
              .then((pixmap) => {
                this.loadPixmap = this.pixmap;
                Prompt.showToast({message:'load pixmap'});
              })
          }


        })
    }
    .width("100%")
    .height("100%")
    .backgroundColor("#fff")
  }
}