import { NoteService } from "./NoteService";
import { NoteState } from "./NoteState";
import { hilog } from '@kit.PerformanceAnalysisKit'
import { EditorController } from "./EditorController";
import fs from '@ohos.file.fs';
import { convertEditorContentToPersistentData } from "./utils/contentConvert";
import { NoteData } from "./model/NoteSpanData";
import { cleanupUnusedImageFiles, ensureDirectoryExists, writeStringToFile } from "../../shared/utils/file";
import { Prompt } from '@kit.ArkUI';
import { ImageUtils } from "../../shared/utils/ImageUtils";
import { Constants } from "../../shared/constants";
import { getDateByTimeStamp } from "../../shared/utils/Time/time";

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
      this.noteState = new NoteState(this.baseDir,'');
    }else{
      this.noteState = new NoteState('','');
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
      } else {
        // 创建新笔记
        this.newNote();
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `加载最近笔记失败: ${error.message}`);
      this.newNote();
    }
  }

  newNote(): void {
    // let id = 'note_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    let timestamp = Date.now();
    let timeArray = getDateByTimeStamp(timestamp);
    let id = `note_${timeArray[3]}_${timeArray[4]}_${timeArray[5]}`;
    this.noteState.setDir(`${this.baseDir}${timeArray[0]}/${timeArray[1]}/${timeArray[2]}/`);
    this.noteState.setId(id);
    this.editorController.cleanAll();
  }

  async selectImage() {
    let ImageUrl = await ImageUtils.selectImageFromGallery();
    // Prompt.showToast({message:'Image Url is:' + ImageUrl});
    await this.editorController.insertImageToEditor(ImageUrl);
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
      setTimeout(() => { this.saveStatus = ''; }, 2000);

      Prompt.showToast({ message: '笔记已保存', duration: 1500 });
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

}