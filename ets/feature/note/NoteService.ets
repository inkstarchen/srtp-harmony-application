import { createDir, isExists, readStringFromFile } from "../../shared/utils/file";
import { NoteData } from "./model/NoteSpanData";
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from "@kit.BasicServicesKit";
import fs from '@ohos.file.fs';

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

export class NoteService {

  async loadNote(filePath: string): Promise<NoteData | undefined> {
    try {
      const jsonString = await readStringFromFile(filePath);
      let noteData:NoteData = JSON.parse(jsonString);

      hilog.info(DOMAIN_NUMBER, TAG, '笔记加载成功');
      return noteData;
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `加载笔记失败: ${error.message}`);
      return undefined
    }
  }

  async ensureNotesDirectoryExists(notesDir:string): Promise<void> {
    try {
      const dirExists = await isExists(notesDir);

      if (dirExists) {
        hilog.info(DOMAIN_NUMBER, TAG, '笔记目录已存在');
        return;
      }

      hilog.info(DOMAIN_NUMBER, TAG, '目录不存在，开始创建笔记目录');

      // 验证目录是否创建成功
      const created = await createDir(notesDir);
      hilog.info(DOMAIN_NUMBER, TAG, '笔记目录创建成功');

    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `创建笔记目录失败: ${(error as BusinessError).message}`);
      throw new Error(`无法创建存储目录: ${(error as BusinessError).message}`);
    }
  }
}