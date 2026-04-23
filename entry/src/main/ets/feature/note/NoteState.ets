import { NoteData, NoteSpanData } from "./model/NoteSpanData";
import { NoteType } from "./NoteViewModel";

export enum NoteAction{
  NONE = 0,
  SHOW = 1,
  NEW = 2,
}

export interface NotePageParams{
  action:NoteAction,
  info:NoteInfo,
}

export interface NoteInfo{
  type: NoteType;
  fileDir: string;
  fileName: string;
  time: string | null;
}

@ObservedV2
export class NoteState{
  dir: string;
  id: string;
  type: NoteType;
  @Trace title: string = '无标题';
  content: NoteSpanData[] | undefined;

  constructor(dir: string, id: string, type:NoteType) {
    this.id = id;
    this.dir = dir;
    this.type = type;
  }

  fromNoteData(data: NoteData | undefined){
    if(!data) return;
    this.id = data.id;
    this.title = data.title;
    this.content = data.content;
  }

  printNoteData(): string {
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

  setType(type: NoteType){ this.type = type; }

  setNoteData(data: NoteSpanData[] | undefined){ this.content = data; }


}