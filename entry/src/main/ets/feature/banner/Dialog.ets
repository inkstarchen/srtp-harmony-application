import picker from '@ohos.file.picker';

@CustomDialog
export struct CreateDialog {
  controller?: CustomDialogController;
  @State input_text: string = '';
  @State imageSrc: string | ResourceStr = $r('app.media.background');

  onConfirm: (title: string, imgSrc: string | ResourceStr) => void = () => {};

  build() {
    Column() {
      TextInput({ placeholder: '新建笔记' })
        .onChange((value: string) => {
          this.input_text = value;
        })

      Text('选择想要的封面')
        .fontSize(18)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)

      Image(this.imageSrc)
        .width(100)
        .height(100)
        .margin(10)

      Button('从本地选择')
        .onClick(() => {
          this.selectImage();
        })
        .margin(10)

      Row() {
        Button("取消")
          .onClick(() => {
            this.controller?.close();
          })
          .margin(10)

        Button("确定")
          .onClick(() => {
            this.onConfirm(this.input_text, this.imageSrc);
            this.controller?.close();
          })
          .margin(10)
      }
    }
    .padding(20)
  }

  async selectImage() {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.fileSuffixFilters = ['.jpg', '.jpeg', '.png', '.gif'];
      documentSelectOptions.maxSelectNumber = 1;
      const documentPicker = new picker.DocumentViewPicker();
      const uris = await documentPicker.select(documentSelectOptions);
      if (uris && uris.length > 0) {
        this.imageSrc = uris[0];
        console.log('选择的图片URI:', this.imageSrc);
      }
    } catch (err) {
      console.error('选择图片失败:', err.code, err.message);
    }
  }
}
