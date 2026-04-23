// 自定义持久化数据模型
export interface NoteSpanStyle {
  fontSize?: number;
  fontColor?: string;
  fontWeight?: string | number;
  fontStyle?: string;
  fontFamily?: string;
  decorationType?: number;
  size?: [number, number];
  verticalAlign?: string;
  objectFit?: string;
}

// 定义图片信息接口
export interface ImageInfo {
  localPath?: string;
  width?: number;
  height?: number;
}

// 定义主数据接口
export interface NoteSpanData {
  type: 'text' | 'image_resource' | 'image_local';
  id: string;
  content: string;
  style?: NoteSpanStyle;
  imageInfo?: ImageInfo;
  timestamp: number;
}


export interface NoteData {
  id : string;
  title: string;
  type: number;
  content: NoteSpanData[];
}