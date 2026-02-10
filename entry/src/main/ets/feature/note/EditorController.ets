import { NoteSpanData } from "./model/NoteSpanData";
import { StyleConversionUtils } from "./utils/StyleConversionUtils";
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Prompt, ShowDialogSuccessResponse } from '@kit.ArkUI';
import fs from '@ohos.file.fs';
import { ImageUtils } from "../../shared/utils/ImageUtils";

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;
const FONT_WEIGHT_BOLD_LEVEL: number = 9;

interface SpanRange {
  start: number;
  end: number;
}

interface BoldStats {
  hasText: boolean;
  anyBold: boolean;
  allBold: boolean;
}
@ObservedV2
export class EditorController{
  @Trace controller: RichEditorController = new RichEditorController();
  private selectionStart: number = 0;
  private selectionEnd: number = 0;

  getAllSpans(): (RichEditorImageSpanResult | RichEditorTextSpanResult)[] {
    return this.controller.getSpans();
  }

  cleanAll(){
    this.controller.deleteSpans({start: 0, end: -1});
  }

  setSelection(start: number, end: number): void {
    this.selectionStart = Math.max(0, start);
    this.selectionEnd = Math.max(0, end);
  }

  private getSpanRange(span: RichEditorImageSpanResult | RichEditorTextSpanResult): SpanRange {
    const range = span.spanPosition.spanRange;
    return { start: range[0], end: range[1] };
  }

  private isTextSpan(span: RichEditorImageSpanResult | RichEditorTextSpanResult): boolean {
    return typeof (span as RichEditorTextSpanResult)['textStyle'] !== 'undefined';
  }

  private isImageSpan(span: RichEditorImageSpanResult | RichEditorTextSpanResult): boolean {
    return typeof (span as RichEditorImageSpanResult)['imageStyle'] !== 'undefined';
  }

  private isBoldWeight(weight: number | undefined): boolean {
    if (weight === undefined || weight === null) return false;
    return weight === FONT_WEIGHT_BOLD_LEVEL;
  }

  getBoldStateForSelection(): boolean {
    const start = Math.min(this.selectionStart, this.selectionEnd);
    const end = Math.max(this.selectionStart, this.selectionEnd);
    const stats = this.getBoldStatsForRange(start, end);
    return stats.anyBold;
  }

  private getBoldStatsForRange(start: number, end: number): BoldStats {  // 分析指定范围内文本的加粗统计信息
    const spans = this.getAllSpans();
    if (spans.length === 0) {
      return { hasText: false, anyBold: false, allBold: false };
    }
    let foundText = false;
    let anyBold = false;
    let allBold = true;
    for (const span of spans) {
      if (this.isImageSpan(span)) {
        continue;
      }

      if (!this.isTextSpan(span)) {
        continue;
      }

      const range = this.getSpanRange(span);
      const overlaps = end > start && range.end > start && range.start < end;
      if (!overlaps) {
        continue;
      }

      foundText = true;
      const textSpan = span as RichEditorTextSpanResult;
      const isBold = this.isBoldWeight(textSpan.textStyle.fontWeight);    //传入的是单一number类型
      if (isBold) {
        anyBold = true;
      } else {
        allBold = false;
      }
    }

    if (!foundText) {
      return { hasText: false, anyBold: false, allBold: false };
    }
    return { hasText: true, anyBold: anyBold, allBold: allBold };
  }

  toggleBold(): boolean {
    const selection = this.controller.getSelection();
    if (!selection || selection.selection[0]=== undefined || selection.selection[1]=== undefined) {
      return false;
    }

    const start:number = selection.selection[0];
    const end:number = selection.selection[1];
    this.setSelection(start, end);
    if (start === end) {
      return false;
    }

    const stats = this.getBoldStatsForRange(start, end);
    if (!stats.hasText) {
      return false;
    }
    const shouldBold = !stats.anyBold;
    if (stats.anyBold && !stats.allBold) {
      // 混合样式 -> 统一变细体
      this.controller.updateSpanStyle({
        start,
        end,
        textStyle: {
          fontWeight: FontWeight.Normal
        }
      });
      return false;
    }
    this.controller.updateSpanStyle({
      start,
      end,
      textStyle: {
        fontWeight: shouldBold ? FontWeight.Bold : FontWeight.Normal
      }
    });
    return shouldBold;
  }


  // 插入图片到编辑器
  async insertImageToEditor(imageUri: string): Promise<void> {
    try {
      hilog.info(DOMAIN_NUMBER, TAG, `开始插入图片，URI: ${imageUri}`);
      const pixelMap = await ImageUtils.uriToPixelMapByFd(imageUri);


      if (!pixelMap) {
        hilog.error(DOMAIN_NUMBER, TAG, 'PixelMap创建失败，返回null');
        throw new Error('PixelMap创建失败，返回null');
      }

      hilog.info(DOMAIN_NUMBER, TAG, 'PixelMap创建成功，准备插入编辑器');
      this.controller.addImageSpan(pixelMap, {
        imageStyle: {
          size: [425, 325],
          verticalAlign: ImageSpanAlignment.CENTER,
          objectFit: ImageFit.Auto,   // Auto 会不会好点 Contain
          layoutStyle: {
            borderRadius: '8px',
            margin: '10px'
          }
        },
        gesture: {
          onClick: () => {
            Prompt.showToast({ message: '点击了图片', duration: 1000 });
          },
          onLongPress: () => {
            this.showImageOptions();
          }
        }
      });

    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `插入图片失败: ${error.message}`);
      Prompt.showToast({ message: '插入图片失败', duration: 2000 });
    }
  }

  // 重建编辑器内容
  async rebuildEditorContent(noteContent: NoteSpanData[]): Promise<void> {
    for (const item of noteContent) {
      try {
        if (item.type === 'text') {
          this.controller.addTextSpan(item.content, {
            style: StyleConversionUtils.restoreTextStyle(item.style)
          });
        } else if (item.type === 'image_resource') {
          this.controller.addImageSpan(item.content, {
            imageStyle: {
              size: item.style?.size,
              // 使用工具类将字符串转换回枚举
              verticalAlign: StyleConversionUtils.stringToImageSpanAlignment(item.style?.verticalAlign),
              objectFit: StyleConversionUtils.stringToImageFit(item.style?.objectFit)
            }
          });
        } else if (item.type === 'image_local') {
          await this.rebuildLocalImageSpan(item);
        }
      } catch (error) {
        hilog.error(DOMAIN_NUMBER, TAG, `重建Span失败: ${error.message}`);
        // 插入错误提示
        this.controller.addTextSpan(`[加载失败: ${item.type}]`, {
          style: { fontColor: Color.Red, fontSize: 14 }
        });
      }
    }
  }

  // 显示图片操作选项
  private showImageOptions(): void {
    Prompt.showDialog({
      title: '图片操作',
      message: '请选择要执行的操作',
      buttons: [
        { text: '删除', color: '#FF3B30' },
        { text: '替换', color: '#007AFF' },
        { text: '取消', color: '#8E8E93' }
      ],
      success: (data: ShowDialogSuccessResponse) => {
        if (data.index === 0) {
          this.deleteSelectedImage();
        } else if (data.index === 1) {
          this.replaceSelectedImage();
        }
      },
      cancel: () => {
        console.log('对话框已取消');
      }
    });
  }

  // 删除选中的图片
  deleteSelectedImage(): void {
    Prompt.showToast({ message: '删除功能待实现', duration: 1500 });
  }

  // 替换选中的图片
  replaceSelectedImage(): void {
    Prompt.showToast({ message: '替换功能待实现', duration: 1500 });
  }

  // 重建本地图片Span
  async rebuildLocalImageSpan(item: NoteSpanData): Promise<void> {
    if (!item.imageInfo?.localPath) {
      throw new Error('本地图片路径不存在');
    }
    // 打印信息
    hilog.info(DOMAIN_NUMBER, TAG, `rebuildLocalImageSpan:重建图片Span，显示尺寸: ${item.style?.size}`);
    // 检查图片文件是否存在

    const exists = await fs.access(item.imageInfo.localPath);
    if (!exists) {
      throw new Error('图片文件不存在: ' + item.imageInfo.localPath);
    }

    // 从本地文件加载图片
    const pixelMap = await ImageUtils.loadPixelMapFromFile(item.imageInfo.localPath);
    this.controller.addImageSpan(pixelMap, {
      imageStyle: {
        size: [425, 325],     // 先给常数   以后要图片改尺寸再说
        //size: item.style?.size,
        // 使用工具类将字符串转换回枚举
        verticalAlign: StyleConversionUtils.stringToImageSpanAlignment(item.style?.verticalAlign),
        objectFit: StyleConversionUtils.stringToImageFit(item.style?.objectFit),
        layoutStyle: {
          borderRadius: '8px',
          margin: '10px'
        }
      },
      gesture: {
        onClick: () => {
          Prompt.showToast({ message: '点击了图片', duration: 1000 });
        },
        onLongPress: () => {
          this.showImageOptions();
        }
      }

    });
  }

}