import { NoteService } from "./NoteService";
import { NoteInfo, NoteState } from "./NoteState";
import { hilog } from '@kit.PerformanceAnalysisKit'
import { EditorController } from "./EditorController";
import fs from '@ohos.file.fs';
import { convertEditorContentToPersistentData } from "./utils/contentConvert";
import { NoteData } from "./model/NoteSpanData";
import { cleanupUnusedImageFiles, deleteFile, ensureDirectoryExists, writeStringToFile } from "../../shared/utils/file";
import { Prompt } from '@kit.ArkUI';
import { ImageUtils } from "../../shared/utils/ImageUtils";
import { Constants } from "../../shared/constants";
import { getDateByTimeStamp } from "../../shared/utils/Time/time";
import { InsertNote, UpdateNote, DeleteNote, NoteEntry, GetAllNotes, GetNotesByDate } from "../DataStorage/datastore";

export enum NoteType{
  UNINITIALIZED = 0,
  NOTE = 1,
  ARTICLE = 2,
}

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;
@ObservedV2
export class NoteViewModel {
  baseDir:string;
  @Trace noteState: NoteState;
  @Trace saveStatus: string = '';
  @Trace editorController = new EditorController();
  @Trace isBoldActive: boolean = false;
  @Trace isItalicActive: boolean = false;
  @Trace isUnderlineActive: boolean = false;
  @Trace currentTextColor: Color = Color.Black;


  constructor(context:Context | undefined) {
    let dir = context?.getApplicationContext()?.filesDir;
    this.baseDir = dir + '/data/'
    if(dir){
    // 需要后续修改存储路径
      this.noteState = new NoteState(this.baseDir,'',NoteType.UNINITIALIZED);
    }else{
      this.noteState = new NoteState('','',NoteType.UNINITIALIZED);
    }
  }

  async loadCurrentNote(){
    let filePath = this.noteState.getFilePath();
    let noteData = await NoteService.loadNote(filePath);
    this.noteState.fromNoteData(noteData);
    let data = this.noteState.getNoteData();
    if(!data) return;
    await this.editorController.rebuildEditorContent(data);
  }

  async loadCurrentNoteMain(){
    let filePath = this.noteState.getFilePath();
    let noteData = await NoteService.loadNote(filePath);
    this.noteState.fromNoteData(noteData);
    let data = this.noteState.getNoteData();
    if(!data) return;
    await this.editorController.rebuildEditorContentMain(data);
    this.editorController.controller.setCaretOffset(0);
  }

  async init(path: string): Promise<boolean>{
    try{
      this.noteState.setDir(path);
      let noteDir = this.noteState.getDir();
      hilog.info(DOMAIN_NUMBER, TAG, `笔记目录: ${noteDir}`);
      await NoteService.ensureNotesDirectoryExists(noteDir);
      await this.loadRecentNote(noteDir);
      return true;
    } catch(error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(DOMAIN_NUMBER, TAG, `初始化笔记失败: ${errorMessage}`);
      return false;
    }
  }

  async loadFromNoteInfo(info: NoteInfo): Promise<void> {
    try {
        const latestFile = info.fileName;
        const noteId = latestFile.replace('.json', '');
        this.noteState.setDir(info.fileDir);
        this.noteState.setId(noteId);
        this.noteState.setType(info.type);
        
        // 如果是 ARTICLE 类型且有 dbId，加载 dbId
        if (info.type === NoteType.ARTICLE && info.dbId) {
          this.noteState.setDbId(info.dbId);
        }
        
        let path = `${info.fileDir}/${noteId}.json`;
        hilog.info(DOMAIN_NUMBER, TAG, '笔记目录是 is ' + path);
        let noteData = await NoteService.loadNote(path);
        this.noteState.fromNoteData(noteData);
        hilog.info(DOMAIN_NUMBER, TAG,'笔记内容是' + this.noteState.printNoteData());
        let data = this.noteState.getNoteData();
        if(!data) return;
        await this.editorController.rebuildEditorContent(data);

        hilog.info(DOMAIN_NUMBER, TAG, '加载了笔记' + info.fileName);
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `加载最近笔记失败: ${error.message}`);
    }
  }

  async loadRecentNote(notesDir: string): Promise<void> {
    try {
      const files = await fs.listFile(notesDir);
      const noteFiles = files.filter(file => file.endsWith('.json'));
      if (noteFiles.length > 0) {
        // 加载最新的笔记
        const latestFile = noteFiles[noteFiles.length - 1];
        const noteId = latestFile.replace('.json', '');
        this.noteState.setDir(notesDir);
        this.noteState.setId(noteId);
        let path = `${notesDir}/${noteId}.json`;
        hilog.info(DOMAIN_NUMBER, TAG, '笔记目录是 is ' + path);
        let noteData = await NoteService.loadNote(path);
        this.noteState.fromNoteData(noteData);
        hilog.info(DOMAIN_NUMBER, TAG,'笔记内容是' + this.noteState.printNoteData());
        let data = this.noteState.getNoteData();
        if(!data) return;
        await this.editorController.rebuildEditorContent(data);

        hilog.info(DOMAIN_NUMBER, TAG, '加载了最新笔记！！！！！！！！');
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `加载最近笔记失败: ${error.message}`);
    }
  }

  newNote(type:NoteType): void {
    // let id = 'note_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    let timestamp = Date.now();
    let timeArray = getDateByTimeStamp(timestamp);
    let id = `note_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`;
    this.noteState.setDir(`${this.baseDir}${timeArray[0]}/${timeArray[1]}/${timeArray[2]}/`);
    this.noteState.setId(id);
    this.noteState.setType(type);
    this.noteState.setDbId(undefined);  // 新笔记清空 dbId
    console.info(`[NoteViewModel] newNote 创建新笔记: id=${id}, type=${type}, type_name=${NoteType[type]}, dir=${this.noteState.dir}`);
    // this.editorController.cleanAll();
  }

  async selectImage() {
    let ImageUrl = await ImageUtils.selectImageFromGallery();
    // Prompt.showToast({message:'Image Url is:' + ImageUrl});
    await this.editorController.insertImageToEditor(ImageUrl);
  }


  async deleteNote(info:NoteInfo): Promise<void> {
    if (!info.fileName) return;

    try {
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-DELETE", '开始删除笔记');

      const filePath = info.fileDir + '/' + info.fileName;
      const dirPath = info.fileDir;

      // 1. 删除笔记文件
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-DELETE", `删除文件: ${filePath}`);
      await deleteFile(filePath);

      // 2. 如果是 ARTICLE 类型且有 dbId，删除数据库记录
      if (info.type === NoteType.ARTICLE && info.dbId) {
        await DeleteNote(info.dbId);
        hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-DELETE", `删除数据库记录 ID: ${info.dbId}`);
      }

      // // 3. 删除笔记目录（包含图片）
      // hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-DELETE", `删除目录: ${dirPath}`);
      // await deleteDirectory(dirPath);

      // this.saveStatus = '删除成功!';
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-DELETE", '删除笔记成功');

      // setTimeout(() => {
      //   this.saveStatus = '';
      // }, 2000);

      Prompt.showToast({
        message: '笔记已删除',
        duration: 1500
      });

    } catch (error) {
      hilog.error(
        Constants.DOMAIN_SERVICE_NOTE,
        "SERVICE-NOTE-DELETE",
        `删除笔记失败: ${error.message}`
      );

      // this.saveStatus = '删除失败!';
      // setTimeout(() => {
      //   this.saveStatus = '';
      // }, 2000);
    }
  }

  async saveNote(): Promise<void> {
    if(!this.noteState.id) return;
    try {
      this.saveStatus = '保存中...';
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", '开始保存笔记');
      /////////////////////////////// 添加尝试！！！！
      await NoteService.ensureNotesDirectoryExists(this.noteState.getDir());
      // 1. 从RichEditor提取数据
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", '开始提取数据');
      let path = this.noteState.getDirPath();
      await ensureDirectoryExists(path);
      await ensureDirectoryExists(`${path}/images/`);
      const noteContent = await convertEditorContentToPersistentData(this.editorController.getAllSpans(),path);
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", `提取数据完成，共${noteContent.length}个span`);

      const usedImagePaths = new Set<string>();
      noteContent.forEach(item => {
        if (item.type === 'image_local' && item.imageInfo?.localPath) {
          usedImagePaths.add(item.imageInfo.localPath);
        }
      });

      const noteData: NoteData = {
        id: this.noteState.id,
        title: this.noteState.title,
        type: this.noteState.type,
        content: noteContent
      };


      // 2. 序列化为JSON
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", '开始序列化');
      const jsonString = JSON.stringify(noteData, null, 2);
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", '序列化完成');

      // 3. 写入文件
      const filePath = this.noteState.getFilePath();
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", `开始写入文件: ${filePath}`);
      await writeStringToFile(filePath, jsonString);

      await cleanupUnusedImageFiles(usedImagePaths,path);

      this.saveStatus = '保存成功!';
      hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", '保存笔记成功');

      // 4. 如果是 ARTICLE 类型，同步到数据库
      console.info(`[NoteViewModel] saveNote 完成, noteState.type=${this.noteState.type}, NoteType.ARTICLE=${NoteType.ARTICLE}`);
      if (this.noteState.type === NoteType.ARTICLE) {
        console.info(`[NoteViewModel] saveNote 开始同步到数据库, filePath=${filePath}`);
        await this.syncNoteToDatabase(filePath);
      } else {
        console.info(`[NoteViewModel] saveNote 跳过数据库同步, 类型不是 ARTICLE`);
      }

      setTimeout(() => { this.saveStatus = ''; }, 2000);

      // Prompt.showToast({ message: '笔记已保存', duration: 1500 });
    } catch (error) {
      hilog.error(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", `保存笔记失败: ${error.message}`);
      this.saveStatus = '保存失败!';
      setTimeout(() => { this.saveStatus = ''; }, 2000);
    }

  }

  getController(): RichEditorController {
    return this.editorController.controller;
  }

  updateSelection(start: number, end: number): void {
    this.editorController.setSelection(start, end);
    this.isBoldActive = this.editorController.getBoldStateForSelection();
    this.isItalicActive = this.editorController.getItalicStateForSelection();
    this.isUnderlineActive = this.editorController.getUnderlineStateForSelection();
  }

  toggleBold(): void {
    this.isBoldActive = this.editorController.toggleBold();
  }

  toggleItalic(): void {
    this.isItalicActive = this.editorController.toggleItalic();
  }

  toggleUnderline(): void {
    this.isUnderlineActive = this.editorController.toggleUnderline();
  }

  setTextColor(color: Color): void {
    hilog.info(DOMAIN_NUMBER, TAG, `setTextColor: ${color}`);
    this.currentTextColor = color;
  }

  applyTextColor(): void {
    this.editorController.applyTextColor(this.currentTextColor);
  }

  getTitle(){
    this.noteState.getTitle();
  }

  setTitle(title: string){
    this.noteState.setTitle(title);
  }

  /**
   * 同步笔记到数据库（仅 ARTICLE 类型）
   * @param filePath 文件完整路径
   */
  private async syncNoteToDatabase(filePath: string): Promise<void> {
    try {
      console.info(`[NoteViewModel] syncNoteToDatabase 开始: type=${this.noteState.type}, id=${this.noteState.id}, dbId=${this.noteState.dbId}`);
      
      const noteEntry: NoteEntry = {
        title: this.noteState.title || '无标题',
        date: new Date().toISOString().split('T')[0], // 只保留日期部分 YYYY-MM-DD
        type: NoteType[this.noteState.type],
        filePath: filePath,
        noteId: this.noteState.id,
      };

      console.info(`[NoteViewModel] syncNoteToDatabase noteEntry: ${JSON.stringify(noteEntry)}`);

      // 如果已有 dbId，则更新；否则插入新记录
      if (this.noteState.dbId) {
        console.info(`[NoteViewModel] syncNoteToDatabase 执行 UPDATE, dbId=${this.noteState.dbId}`);
        await UpdateNote(this.noteState.dbId, noteEntry);
        hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", `更新数据库记录 ID: ${this.noteState.dbId}`);
      } else {
        console.info(`[NoteViewModel] syncNoteToDatabase 执行 INSERT`);
        const rowId = await InsertNote(noteEntry);
        if (rowId) {
          this.noteState.setDbId(rowId);
          console.info(`[NoteViewModel] syncNoteToDatabase INSERT 成功, rowId=${rowId}`);
          hilog.info(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", `插入数据库记录 ID: ${rowId}`);
        } else {
          console.error(`[NoteViewModel] syncNoteToDatabase INSERT 失败, rowId 为 undefined`);
        }
      }
    } catch (error) {
      console.error(`[NoteViewModel] syncNoteToDatabase 异常: ${error.message}`);
      hilog.error(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE-SAVE", `同步数据库失败: ${error.message}`);
    }
  }

  /**
   * 从数据库加载所有 ARTICLE 笔记列表
   * @returns 笔记信息列表
   */
  async loadArticlesFromDatabase(): Promise<NoteInfo[]> {
    try {
      console.info(`[NoteViewModel] loadArticlesFromDatabase 开始`);
      const entries = await GetAllNotes();
      console.info(`[NoteViewModel] loadArticlesFromDatabase 获取到 ${entries.length} 条记录`);
      
      const noteInfos = entries.map(entry => {
        const noteInfo = this.convertNoteEntryToNoteInfo(entry);
        console.info(`[NoteViewModel] loadArticlesFromDatabase 转换: ${entry.noteId} -> ${noteInfo.fileName}`);
        return noteInfo;
      });
      
      console.info(`[NoteViewModel] loadArticlesFromDatabase 完成, 返回 ${noteInfos.length} 条`);
      return noteInfos;
    } catch (error) {
      console.error(`[NoteViewModel] loadArticlesFromDatabase 异常: ${error.message}`);
      hilog.error(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE", `加载文章列表失败: ${error.message}`);
      return [];
    }
  }

  /**
   * 从数据库按日期加载 ARTICLE 笔记列表
   * @param date 日期字符串 YYYY-MM-DD
   * @returns 笔记信息列表
   */
  async loadArticlesByDate(date: string): Promise<NoteInfo[]> {
    try {
      const entries = await GetNotesByDate(date);
      return entries.map(entry => this.convertNoteEntryToNoteInfo(entry));
    } catch (error) {
      hilog.error(Constants.DOMAIN_SERVICE_NOTE, "SERVICE-NOTE", `按日期加载文章失败: ${error.message}`);
      return [];
    }
  }

  /**
   * 将 NoteEntry 转换为 NoteInfo
   */
  private convertNoteEntryToNoteInfo(entry: NoteEntry): NoteInfo {
    // 从 filePath 中提取 fileDir 和 fileName
    const lastSlashIndex = entry.filePath.lastIndexOf('/');
    const fileDir = lastSlashIndex >= 0 ? entry.filePath.substring(0, lastSlashIndex) : '';
    const fileName = lastSlashIndex >= 0 ? entry.filePath.substring(lastSlashIndex + 1) : entry.noteId + '.json';

    return {
      type: NoteType.ARTICLE,
      fileDir: fileDir,
      fileName: fileName.endsWith('.json') ? fileName : fileName + '.json',
      time: entry.date,
      dbId: entry.id,
      title: entry.title, // 映射标题
    };
  }

}