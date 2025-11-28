import { image } from "@kit.ImageKit";
import { hilog } from "@kit.PerformanceAnalysisKit";
//import { fileIo } from "@kit.CoreFileKit";
import fs from '@ohos.file.fs';
import { FileUtils } from "../utils/FileUtils";

const DOMAIN_NUMBER: number = 0xFF00;  // 与主笔记使用相同的领域号
const TAG: string = '[ImageManager]';   // 使用不同的TAG标识

// interface Size {
//   width: number;
//   height: number;
// }

export class ImagePersistenceManager {

  private imageQuality: number = 85;
  private maxImageSize: number = 2048;


  async uriToPixelMapByFd(uri: string): Promise<image.PixelMap | null> {
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


  // 用不了
  async uriToPixelMap(uri: string): Promise<image.PixelMap| null> {
    const imageSource = image.createImageSource(uri);

    try {
      const imageInfo = await imageSource.getImageInfo();
      const desiredSize = this.calculateDesiredSize(imageInfo.size);

      const decodingOptions: image.DecodingOptions = {
        desiredSize: desiredSize,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        editable: true
        //desiredSize: { width: 800, height: 800 },
      };

      const pixelMap = await imageSource.createPixelMap(decodingOptions);
      return pixelMap;
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `图片解码失败: ${error.message}`);
      return null;
    } finally {
      imageSource.release();
    }
  }

  async savePixelMapToFile(pixelMap: image.PixelMap, filePath: string): Promise<boolean> {
    const imagePacker = image.createImagePacker();
    let file: fs.File | null = null;

    try {
      // 确保目录存在
      const dirPath = filePath.substring(0, filePath.lastIndexOf('/'));
      await FileUtils.ensureDirectoryExists(dirPath);

      // 使用新的 fs.open API
      file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);

      const packOptions: image.PackingOption = {
        format: 'image/png',
        quality: this.imageQuality
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
      imagePacker.release();
    }
  }

  async loadPixelMapFromFile(filePath: string): Promise<image.PixelMap> {
    // 检查文件是否存在
    // try {
    //   await fileIo.access(filePath);
    // } catch {
    //   throw new Error(`图片文件不存在: ${filePath}`);
    // }

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

  private calculateDesiredSize(originalSize: image.Size): image.Size {
    const maxDimension = this.maxImageSize;
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



}

