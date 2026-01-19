import { NoteSpanData } from "./model/NoteSpanData";
import { StyleConversionUtils } from "./utils/StyleConversionUtils";
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Prompt, ShowDialogSuccessResponse } from '@kit.ArkUI';
import fs from '@ohos.file.fs';
import { ImageUtils } from "../../shared/utils/ImageUtils";

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;
@ObservedV2
export class EditorController{
  @Trace controller: RichEditorController = new RichEditorController();

  getAllSpans(): (RichEditorImageSpanResult | RichEditorTextSpanResult)[] {
    return this.controller.getSpans();
  }

  cleanAll(){
    this.controller.deleteSpans({start: 0, end: -1});
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