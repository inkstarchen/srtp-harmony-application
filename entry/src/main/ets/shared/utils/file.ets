import fs from '@ohos.file.fs';
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
const TAG: string = '[FileService]';
const DOMAIN_NUMBER: number = 0xF000;

export async function cleanupUnusedImageFiles(usedImagePaths: Set<string>,currentPath: string): Promise<void> {
  try {
    // 使用笔记专属的图片目录
    const imagesDir = `${currentPath}/images/`;
    const dirExists = await fs.access(imagesDir);
    if (!dirExists) {
    return; // 目录不存在，无需清理
  }

  const files = await fs.listFile(imagesDir);
  for (const file of files) {
    const filePath = imagesDir + file;
    if (!usedImagePaths.has(filePath)) {
      // 删除未被引用的文件
      await fs.unlink(filePath);
      hilog.info(DOMAIN_NUMBER, TAG, `清理未使用的图片文件: ${filePath}`);
    }
  }
  } catch (error) {
    hilog.error(DOMAIN_NUMBER, TAG, `清理图片文件失败: ${error.message}`);
  }
}

export async function writeStringToFile(filePath: string, content: string): Promise<void> {
  let file: fs.File | null = null;
  try {
    hilog.info(DOMAIN_NUMBER, TAG, `准备写入文件: ${filePath}`);

  // 确保文件所在目录存在
  const dirPath = filePath.substring(0, filePath.lastIndexOf('/'));
  const dirExists = await fs.access(dirPath);

  if (!dirExists) {
    hilog.info(DOMAIN_NUMBER, TAG, `文件目录不存在，创建: ${dirPath}`);
    await fs.mkdir(dirPath);
  }

  // 使用新的 fs.open API 写入文件
  file = await fs.open(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);

  const encoder = new util.TextEncoder();
  const uint8Array = encoder.encodeInto(content);

  // 使用新的 fs.write API
  const written = await fs.write(file.fd, uint8Array.buffer);
  hilog.info(DOMAIN_NUMBER, TAG, `文件写入完成，字节数: ${written}`);

  } catch (error) {
    hilog.error(DOMAIN_NUMBER, TAG, `文件写入错误: ${(error as BusinessError).message}, 文件路径: ${filePath}`);
  } finally {
    if (file) {
      await fs.close(file);
    }
  }
}

export async function ensureDirectoryExists(dirPath: string): Promise<void> {
  try {
    const exists = await fs.access(dirPath);
    if (!exists) {
      await fs.mkdir(dirPath,true);
    }
  } catch (error) {
    hilog.error(DOMAIN_NUMBER, TAG, `创建目录失败: ${(error as BusinessError).message}`);
  }
}

export async function createDir(path: string): Promise<void> {
  try {

    await fs.mkdir(path,true);

    const created = await fs.access(path);
    if (created) {
      hilog.info(DOMAIN_NUMBER, TAG, '目录创建成功');
    } else {
      throw new Error('目录验证失败');
    }
  } catch (error) {
    throw new Error('目录创建失败')
  }
}

export async function isExists(path: string): Promise<boolean> {
  try {
    hilog.info(DOMAIN_NUMBER, TAG, `检查路径是否存在: ${path}`);

    const exists = await fs.access(path);

    if(exists) {
      hilog.info(DOMAIN_NUMBER, TAG, `路径 ${path} 存在`);
    }else{
      hilog.info(DOMAIN_NUMBER, TAG, `路径 ${path} 不存在`);
    }
    return exists;
  } catch (error) {
    hilog.error(DOMAIN_NUMBER, TAG, `检查路径是否存在失败: ${(error as BusinessError).message}`, path);
    throw new Error('检查路径是否存在失败'+ path);
  }
}

export async function readStringFromFile(filePath: string): Promise<string>{
    try {
      const fileExists = await isExists(filePath);
      if (!fileExists) {
        throw new Error('文件不存在');
      }

      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);

      try {
        const stat = await fs.stat(filePath);
        const buffer = new ArrayBuffer(stat.size);

        await fs.read(file.fd, buffer);

        const decoder = util.TextDecoder.create('utf-8');
        return decoder.decodeToString(new Uint8Array(buffer));
      } finally {
        await fs.close(file);
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `读取文件失败: ${(error as BusinessError).message}`);
      return '';
    }

}