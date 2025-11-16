import fs from '@ohos.file.fs';
import { buffer, util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

export class FileUtils{

  static async writeStringToFile(filePath: string, content: string): Promise<void> {
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

  static async ensureDirectoryExists(dirPath: string): Promise<void> {
    try {
      const exists = await fs.access(dirPath);
      if (!exists) {
        await fs.mkdir(dirPath);
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `创建目录失败: ${(error as BusinessError).message}`);
    }
  }

  static async readStringFromFile(filePath: string): Promise<string> {
    try {
      // 使用新的 fs.access API 检查文件是否存在
      const fileExists = await fs.access(filePath);
      if (!fileExists) {
        throw new Error('文件不存在');
      }

      // 使用新的 fs.open API
      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);

      try {
        // 使用新的 fs.stat API
        const stat = await fs.stat(filePath);
        const buffer = new ArrayBuffer(stat.size);

        // 使用新的 fs.read API
        await fs.read(file.fd, buffer);

        const decoder = util.TextDecoder.create('utf-8');
        return decoder.decodeToString(new Uint8Array(buffer));
      } finally {
        // 确保文件被关闭
        await fs.close(file);
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `读取文件失败: ${(error as BusinessError).message}`);
      return '';
    }
  }
}