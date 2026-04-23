import { image } from "@kit.ImageKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
import fs from '@ohos.file.fs';
import { ensureDirectoryExists } from "./file";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { Prompt } from "@kit.ArkUI";
import fileIo from "@ohos.file.fs";
import cameraPicker from "@ohos.multimedia.cameraPicker";
import { camera } from "@kit.CameraKit";
import { Context } from "@kit.AbilityKit";
import picker from "@ohos.file.picker";
import { JSON } from "@kit.ArkTS";

class Constants{
  static readonly NUMBER_500 = 500;
  static readonly NUMBER_800 = 800;
  static readonly NUMBER_ONE_HALF = 0.5;
  static readonly NUMBER_1000 = 1000;
  static readonly NUMBER_0 = 0;
  static readonly NUMBER_400 = 400;
  static readonly NUMBER_250 = 250;


}

const DOMAIN_NUMBER: number = 0xFF00;  // 与主笔记使用相同的领域号
const TAG: string = '[ImageManager]';   // 使用不同的TAG标识
export class ImageUtils {
  private static readonly MAX_SIZE: number = 2048;
  private static readonly DEFAULT_QUALITY: number = 85;

  static async TakePictureAndSave(context: Context | undefined,interPath:string):Promise<void>{
    try {
      // 使用后置摄像头
      let pickerProfile: cameraPicker.PickerProfile =
        { cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK };
      // 调用拍摄接口获取结果
      let pickerResult: cameraPicker.PickerResult =
        await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], pickerProfile);
      // 返回图片的uri到应用
      hilog.info(0x0000, "Camera", 'cameraPicker.pick succeed, uri: ' + JSON.stringify(pickerResult));
      let pixmap = await ImageUtils.uriToPixelMapByFd(pickerResult.resultUri);
      // 暂时使用临时目录需要后续决定如何存储
      let fileDir = context?.getApplicationContext().filesDir;
      if (fileDir && pixmap) {
        // 这里的文件名需要一个标识系统，这里仅仅用作示例
        await ImageUtils.savePixelMapToFile(pixmap, fileDir + interPath + "/capture.png");
      }
    } catch (error){
      let err = error as BusinessError;
      hilog.error(0x0000, "Camera", `cameraPicker.pick failed, error: ${err.code}, ${err.message}`);
    }
  }

  static TwoImageStencil(images: Array<string> | Array<image.PixelMap>,
    isH = true): image.PixelMap | null {
    let wideList: Array<number> = [];
    let heightList: Array<number> = [];
    let imageSourceList: Array<image.ImageSource> = [];
    try {
      if (images.length < 2) {
        return null;
      }
      let buffer: ArrayBuffer;
      for (let x = 0; x < images.length; x++) {
        if (typeof images[x] === 'string') {
          let file = fileIo.openSync(String(images[x]), fileIo.OpenMode.READ_ONLY);
          buffer = new ArrayBuffer(fileIo.statSync(file.fd).size);
          // 读取图片到buffer
          fileIo.readSync(file.fd, buffer);
          fileIo.closeSync(file);
        } else {
          let pixelMap1 = images[x] as image.PixelMap;
          buffer = new ArrayBuffer(pixelMap1.getPixelBytesNumber());
          pixelMap1.readPixelsToBufferSync(buffer);
        }
        // 创建imageSource
        let imageSource = image.createImageSource(buffer);
        let imageInfo = imageSource.getImageInfoSync();
        let singleWidth = imageInfo.size.width;
        let singleHeight = imageInfo.size.height;
        wideList[x] = singleWidth;
        heightList[x] = singleHeight;
        imageSourceList[x] = imageSource;
      }
      let totalHeight = 2 * heightList[0];
      let totalWidth = wideList[0];
      let combineOpts: image.InitializationOptions = {
        alphaType: 0,
        editable: true,
        // 注意上下格式统一
        pixelFormat: image.PixelMapFormat.BGRA_8888,
        size: { width: totalWidth, height: totalHeight }
      };
      let imageOption: Array<image.DecodingOptions> = [];
      for (let i = 0; i < images.length; i++) {
        let singleOpts: image.DecodingOptions = {
          editable: true,
          desiredPixelFormat: image.PixelMapFormat.BGRA_8888,
          desiredSize: {width: totalWidth, height: heightList[0]}
        };
        imageOption.push(singleOpts);
      }
      let combineColor = new ArrayBuffer(combineOpts.size.width * combineOpts.size.height * 4);
      let newPixelMap = image.createPixelMapSync(combineColor, combineOpts);
      if (true) {
        for (let x = 0; x < images.length; x++) {
          let singleOpts = imageOption[x];
          let singleColor = new ArrayBuffer(singleOpts.desiredSize!.width * singleOpts.desiredSize!.height * 4);
          let imageSource = imageSourceList[x];
          //读取小图
          let singlePixelMap = imageSource.createPixelMapSync(singleOpts);
          singlePixelMap.readPixelsToBufferSync(singleColor);
          //写入大图
          let area: image.PositionArea = {
            pixels: singleColor,
            offset: Constants.NUMBER_0,
            stride: totalWidth * 4,
            region: {
              size: {height: heightList[0], width: totalWidth},
              x: 0,
              y: x === 0 ? 0 : heightList[0]
            }
          };
          newPixelMap.writePixelsSync(area);
        }
        return newPixelMap;
      }
    } catch (err) {
      hilog.error(0x0000, 'JOIN_IMAGES', 'PictureJoinTogether join error: ' + JSON.stringify(err));
      return null;
    }
  }

  // 获取图片的信息，并在日志中打印出来.
  static async GetImageInfo(pixelMap: image.PixelMap) {
    if (pixelMap != undefined) {
      pixelMap.getImageInfo().then((imageInfo: image.ImageInfo) => {
        if (imageInfo != undefined) {
          console.info(`ImageInfo | ${imageInfo.mimeType} ${imageInfo.size.height} ${imageInfo.size.width} ${imageInfo.density} ${imageInfo.stride} ${imageInfo.pixelFormat.toString()} ${imageInfo.alphaType.toString()} ${imageInfo.isHdr}`);
        }
      }).catch((error:BusinessError) => {
        console.error(`Failed to obtain the image pixel map information, code is ${error}`);
      })
    }
  }

  static async  ReadPixelsToBuffer(pixelMap: image.PixelMap) {
    const readBuffer: ArrayBuffer = new ArrayBuffer(4096 * 3072 * 4);
    if(pixelMap != undefined){
      pixelMap.readPixelsToBuffer(readBuffer, (error: BusinessError, res: void) => {
        if(error) {
          console.error(`Failed to read image pixel data. code is ${error.code}, message is ${error.message}`);
          return;
        } else {
          console.info('Succeeded in reading image pixel data.');
        }
      })
    }
  }



  static captureComponent(uiContext:UIContext,id:string,name:string){
    uiContext.getComponentSnapshot().get("origin", (error: Error, pixmap: image.PixelMap) => {
      if(error) {
        console.error(`error: ${JSON.stringify(error)}`);
        return;
      }
      let fileDir = uiContext.getHostContext()?.tempDir;
      if(fileDir){
        console.info("Test: SaveDir is " + fileDir)
        ImageUtils.savePixelMapToFile(pixmap as image.PixelMap,fileDir + "/" + name)
          .then((result) => {
            if(result){
              Prompt.showToast({message: "saved"})
            }else{
              Prompt.showToast({message:"failed"})
            }
          })
      }
    }, { scale: 2, waitUntilRenderFinished: true });
  }

  // 通过uri获取PixelMap
  static async uriToPixelMapByFd(uri: string): Promise<image.PixelMap | null> {
    let file: fs.File | null = null;
    let imageSource: image.ImageSource | null = null;

    try {
      hilog.info(DOMAIN_NUMBER, TAG, '通过文件描述符创建ImageSource');

      file = await fs.open(uri, fs.OpenMode.READ_ONLY);
      hilog.info(DOMAIN_NUMBER, TAG, `文件打开成功，fd: ${file.fd}`);

      imageSource = image.createImageSource(file.fd);
      hilog.info(DOMAIN_NUMBER, TAG, 'ImageSource创建完成');

      // 使用固定的尺寸
      //const desiredSize_width = 800;
      //const desiredSize_height = 600;


      const imageInfo = await imageSource.getImageInfo();
      //const desiredSize = this.calculateDesiredSize(imageInfo.size);

      const decodingOptions: image.DecodingOptions = {
        //desiredSize: desiredSize,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true

      }

      const pixelMap = await imageSource.createPixelMap(decodingOptions);
      return pixelMap;
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `图片解码失败: ${error.message}`);
      return null;
    } finally {
      if (imageSource) {
        imageSource.release();
        hilog.info(DOMAIN_NUMBER, TAG, 'ImageSource已释放');
      }
      if (file) {
        await fs.close(file);
        hilog.info(DOMAIN_NUMBER, TAG, '文件已关闭');
      }
    }
  }

  // 保存PixelMap到某个路径
  static async savePixelMapToFile(pixelMap: image.PixelMap, filePath: string): Promise<boolean> {
    const imagePacker = image.createImagePacker();
    let file: fs.File | null = null;

    try {
      // 确保目录存在
      const dirPath = filePath.substring(0, filePath.lastIndexOf('/'));
      await ensureDirectoryExists(dirPath);

      // 使用新的 fs.open API
      file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

      const packOptions: image.PackingOption = {
        format: 'image/png',
        quality: ImageUtils.DEFAULT_QUALITY
      };

      // 使用正确的参数：pixelMap + 文件描述符
      await imagePacker.packToFile(pixelMap, file.fd, packOptions);

      hilog.info(DOMAIN_NUMBER, TAG, `图片保存成功: ${filePath}`);
      return true;
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `图片保存失败: ${error.message}`);
      return false;
    } finally {
      // 确保关闭文件 - 使用新的 fs.close API
      if (file) {
        await fs.close(file);
      }
      // 确保释放 ImagePacker
      await imagePacker.release();
    }
  }

  static async loadPixelMapFromFile(filePath: string): Promise<image.PixelMap> {

    const exists = await fs.access(filePath);
    if (!exists) {
      hilog.error(DOMAIN_NUMBER, TAG, `重构图片时发现不存在图片: ${filePath}`);
      throw new Error(`图片文件不存在: ${filePath}`);
    }

    const imageSource = image.createImageSource(filePath);
    try {
      const pixelMap = await imageSource.createPixelMap();
      return pixelMap;
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `加载图片失败: ${error.message}`);
      throw new Error(`图片加载失败: ${filePath}`);
      //return null;
    } finally {
      imageSource.release();
    }
  }

  static calculateDesiredSize(originalSize: image.Size): image.Size {
    const maxDimension = ImageUtils.MAX_SIZE;
    const width = originalSize.width;
    const height = originalSize.height;

    if (width <= maxDimension && height <= maxDimension) {
      return { width, height };
    }

    const ratio = Math.min(maxDimension / width, maxDimension / height);
    return {
      width: Math.floor(width * ratio),
      height: Math.floor(height * ratio)
    };
  }

  static async selectImageFromGallery(): Promise<string> {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;  //可以不要
      photoSelectOptions.maxSelectNumber = 1;   //可以不要  默认50

      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        const imageUri = photoSelectResult.photoUris[0];
        return imageUri;
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `选择图片失败: ${error.message}`);
      // Prompt.showToast({ message: '选择图片失败', duration: 2000 });
    }
    return '';
  }

  async makeTransparent(pixelMap: image.PixelMap) : Promise<image.PixelMap> {
    const info = await pixelMap.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;

    // 1. 准备缓冲区
    const byteLength = width * height * 4;
    const buffer = new ArrayBuffer(byteLength);

    const area: image.PositionArea = {
      offset: 0,
      pixels: buffer,
      stride: width * 4,
      region: { size: { width: width, height: height }, x: 0, y: 0 }
    };

    const initOptions: image.InitializationOptions = {
      editable: true, // 【关键】设置为可编辑
      pixelFormat: image.PixelMapFormat.RGBA_8888, // 建议指定格式，通常将 BGRA 转为 RGBA 使用
      size: {
        width: width,
        height: height
      }
    };
    await pixelMap.readPixels(area);


    console.log("pixelMap is editable" + pixelMap.isEditable);

    // 3. 使用 Uint32Array 视图
    // 在小端序系统中，RGBA (0,0,0,1) 对应的 32位整数是 0x01000000
    const pixelData = new Uint32Array(buffer);

    // 定义目标匹配值：Alpha=1 (0x01), R=0, G=0, B=0
    // 注意：这里假设 PixelMap 格式是 RGBA_8888
    const TARGET_COLOR = 0x01000000;

    for (let i = 0; i < pixelData.length; i++) {
      // 直接比较 32 位整数，比分别比较 R,G,B,A 快得多
      if (pixelData[i] === TARGET_COLOR) {
        // 将 Alpha 变为 0 (即整个像素变为 0x00000000)
        pixelData[i] = 0x01010101;
      }
    }
    let editablePixelMap = await image.createPixelMap(buffer, initOptions);
    console.log("editablePixelMap is editable" + editablePixelMap.isEditable);
    // 4. 写回
    await editablePixelMap.writePixels(area);
    return editablePixelMap;
  }

}