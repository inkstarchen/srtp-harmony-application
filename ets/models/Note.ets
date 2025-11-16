import { FileUtils } from "../utils/FileUtils";
import { NoteData } from "./NoteSpanData";
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

export class Note{
  noteId:string = ''
  notesDir:string = ''
  noteTitle:string = ''
  noteData: NoteData | undefined = undefined;

  constructor(Dir:string, Id:string) {
    this.noteId = Id;
    this.notesDir = Dir;
  }

  // 加载笔记
  async loadNote(): Promise<boolean> {
    try {
      const filePath = this.getNoteFilePath();
      const jsonString = await FileUtils.readStringFromFile(filePath);
      this.noteData = JSON.parse(jsonString);


      this.noteTitle = this.noteData?.title || '未命名笔记';

      hilog.info(DOMAIN_NUMBER, TAG, '笔记加载成功');
      return true;

    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `加载笔记失败: ${error.message}`);
      return false;
    }
  }

  // 获取笔记文件路径
  getNoteFilePath(): string {
    return `${this.notesDir}${this.noteId}.json`;
  }
}