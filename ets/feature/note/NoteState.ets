import { NoteData, NoteSpanData } from "./model/NoteSpanData";

@ObservedV2
export class NoteState{
  dir: string;
  id: string;
  @Trace title: string = '未命名的笔记';
  content: NoteSpanData[] | undefined;

  constructor(dir: string, id: string) {
    this.id = id;
    this.dir = dir;
  }

  fromNoteData(data: NoteData | undefined){
    if(!data) return;
    this.id = data.id;
    this.title = data.title;
    this.content = data.content;
  }

  printNoteData

  (): string {
    return `{ "id": "${this.id}", "title": "${this.title}", "content": ${JSON.stringify(this.content)} }`;
  }
  getFilePath(): string { return `${this.dir}${this.id}.json`; }

  getDirPath(): string { return `${this.dir}${this.id}`; }

  getDir(): string { return this.dir; }

  getNoteData(): NoteSpanData[] | undefined { return this.content; }

  getTitle(): string{ return this.title; }

  setDir(dir: string){ this.dir = dir; }

  setId(id: string){ this.id = id; }

  setTitle(title: string){ this.title = title; }

  setNoteData(data: NoteSpanData[] | undefined){ this.content = data; }


}