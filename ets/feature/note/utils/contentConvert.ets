import { NoteData, NoteSpanData } from "../model/NoteSpanData";
import { StyleConversionUtils } from "./StyleConversionUtils";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { ImageUtils } from "../../../shared/utils/ImageUtils";
import { ensureDirectoryExists } from "../../../shared/utils/file";

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;
// 工具方法


export function generateSpanId(): string {
  return 'span_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
}

// 从RichEditor内容转换为持久化数据
export async function convertEditorContentToPersistentData(allSpans: (RichEditorImageSpanResult | RichEditorTextSpanResult)[], currentDir: string): Promise<NoteSpanData[]> {
  const persistentData: NoteSpanData[] = [];

  for (const span of allSpans) {
    // 使用官方推荐的方式判断span类型
    if (typeof (span as RichEditorImageSpanResult)['imageStyle'] !== 'undefined') {
    // 图片Span
    const imageSpan = span as RichEditorImageSpanResult;
    const imageData = await processImageSpanForPersistence(imageSpan, currentDir);
    if (imageData) {
      persistentData.push(imageData);
    }
  } else {
    // 文本Span
    const textSpan = span as RichEditorTextSpanResult;

    // 进一步判断是否为SymbolSpan
    if (typeof (textSpan as RichEditorTextSpanResult)['symbolSpanStyle'] !== 'undefined') {
      // SymbolSpan处理（如果需要的话）
      persistentData.push({
        type: 'text', // 或者可以定义新的类型'symbol'？
        id: generateSpanId(),
        content: textSpan.value,
        // style: this.simplifySymbolStyle(textSpan.symbolSpanStyle), // 需要单独实现
        timestamp: Date.now()
      });
    } else {
      // 普通文本Span
      persistentData.push({
        type: 'text',
        id: generateSpanId(),
        content: textSpan.value,
        style: StyleConversionUtils.simplifyTextStyle(textSpan.textStyle),
        timestamp: Date.now()
      });
    }
  }
  }

  return persistentData;
}

// 处理图片Span的持久化
export async function processImageSpanForPersistence(span: RichEditorImageSpanResult, currentDir: string): Promise<NoteSpanData | null> {
  try {
    let imageContent: string;
    let imageType: 'image_resource' | 'image_local' = 'image_resource';
    let localPath: string | undefined;
    let spanId: string = generateSpanId();

    if (span.valueResourceStr) {
    // 应用资源图片
    imageContent = span.valueResourceStr.toString();
  } else if (span.valuePixelMap) {
    // 需要持久化的图片

    const imagesDir = `${currentDir}/images/`
    localPath = `${imagesDir}${spanId}.png`;
    await ImageUtils.savePixelMapToFile(span.valuePixelMap, localPath);
    imageContent = localPath;
    imageType = 'image_local';
  } else {
    return null;
  }

  return {
    type: imageType,
    id: spanId,
    content: imageContent,
    style: {
      size: span.imageStyle?.size,
      // 使用工具类将枚举转换为字符串
      verticalAlign: StyleConversionUtils.imageSpanAlignmentToString(span.imageStyle?.verticalAlign),
      objectFit: StyleConversionUtils.imageFitToString(span.imageStyle?.objectFit)
    },
    imageInfo: {
      localPath: localPath,
      width: span.imageStyle?.size?.[0],
      height: span.imageStyle?.size?.[1]
    },
    timestamp: Date.now()
  };

  } catch (error) {
    hilog.error(DOMAIN_NUMBER, TAG, `处理图片Span失败: ${error.message}`);
    return null;
  }
}



