import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';
import { BusinessError } from '@kit.BasicServicesKit';
import { Note } from '../models/Note';
import { NoteData, NoteSpanData, NoteSpanStyle } from '../models/NoteSpanData';
import { StyleConversionUtils } from '../utils/StyleConversionUtils';
import { ImagePersistenceManager } from '../models/ImageManager';
import { Prompt, ShowDialogSuccessResponse } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { FileUtils } from '../utils/FileUtils';

const TAG: string = '[NoteApp]';
const DOMAIN_NUMBER: number = 0xFF00;

@ObservedV2
export class NotesController{

  // 图片管理器
  notesDir: string = '';
  private imageManager: ImagePersistenceManager = new ImagePersistenceManager();
  controller: RichEditorController = new RichEditorController();
  private currentNoteId: string = '';
  private note: Note | undefined = undefined;
  @Trace saveStatus: string = '';
  uiContext:UIContext

  constructor(uiContext:UIContext) {
    this.uiContext = uiContext;
  }

  // 删除选中的图片
  deleteSelectedImage(): void {
    Prompt.showToast({ message: '删除功能待实现', duration: 1500 });
  }

  // 替换选中的图片
  replaceSelectedImage(): void {
    Prompt.showToast({ message: '替换功能待实现', duration: 1500 });
  }

  // 工具方法
  private generateSpanId(): string {
    return 'span_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  // 处理图片Span的持久化
  private async processImageSpanForPersistence(span: RichEditorImageSpanResult): Promise<NoteSpanData | null> {
    try {
      let imageContent: string;
      let imageType: 'image_resource' | 'image_local' = 'image_resource';
      let localPath: string | undefined;

      if (span.valueResourceStr) {
        // 应用资源图片
        imageContent = span.valueResourceStr.toString();
      } else if (span.valuePixelMap) {
        // 需要持久化的图片
        const fileName = `img_${Date.now()}_${Math.random().toString(36).substr(2, 9)}.png`;
        const imagesDir = `${this.notesDir}images/`;
        await FileUtils.ensureDirectoryExists(imagesDir);

        localPath = imagesDir + fileName;
        await this.imageManager.savePixelMapToFile(span.valuePixelMap, localPath);
        imageContent = localPath;
        imageType = 'image_local';
      } else {
        return null;
      }

      return {
        type: imageType,
        id: this.generateSpanId(),
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

  // 存储时：RichEditorTextStyleResult to NoteSpanStyle
  private simplifyTextStyle(textStyle: RichEditorTextStyleResult | undefined): NoteSpanStyle {
    if (!textStyle) {
      return {};
    }

    return {
      fontSize: textStyle.fontSize,
      // 使用工具类转换颜色
      fontColor: 'Color.Black' ,//StyleConversionUtils.colorToString(textStyle.fontColor),
      fontWeight: textStyle.fontWeight,
      // 使用工具类转换字体样式
      fontStyle: StyleConversionUtils.fontStyleToString(textStyle.fontStyle),
      fontFamily: textStyle.fontFamily,
    };
  }


  // 从RichEditor内容转换为持久化数据
  private async convertEditorContentToPersistentData(): Promise<NoteSpanData[]> {
    const allSpans = this.controller.getSpans();
    const persistentData: NoteSpanData[] = [];

    for (const span of allSpans) {
      // 使用官方推荐的方式判断span类型
      if (typeof (span as RichEditorImageSpanResult)['imageStyle'] !== 'undefined') {
        // 图片Span
        const imageSpan = span as RichEditorImageSpanResult;
        const imageData = await this.processImageSpanForPersistence(imageSpan);
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
            id: this.generateSpanId(),
            content: textSpan.value,
            // style: this.simplifySymbolStyle(textSpan.symbolSpanStyle), // 需要单独实现
            timestamp: Date.now()
          });
        } else {
          // 普通文本Span
          persistentData.push({
            type: 'text',
            id: this.generateSpanId(),
            content: textSpan.value,
            style: this.simplifyTextStyle(textSpan.textStyle),
            timestamp: Date.now()
          });
        }
      }
    }

    return persistentData;
  }

  // 保存笔记
  async saveNote(): Promise<boolean> {
    if(!this.note) return false;
    try {
      this.saveStatus = '保存中...';
      hilog.info(DOMAIN_NUMBER, TAG, '开始保存笔记');
      /////////////////////////////// 添加尝试！！！！
      await NotesController.ensureNotesDirectoryExists(this.notesDir);
      // 1. 从RichEditor提取数据
      hilog.info(DOMAIN_NUMBER, TAG, '开始提取数据');
      const noteContent = await this.convertEditorContentToPersistentData();
      hilog.info(DOMAIN_NUMBER, TAG, `提取数据完成，共${noteContent.length}个span`);

      const noteData: NoteData = {
        id: this.currentNoteId,
        title: this.note?.noteTitle ? this.note.noteTitle : '未命名的笔记',
        content: noteContent
      };


      // 2. 序列化为JSON
      hilog.info(DOMAIN_NUMBER, TAG, '开始序列化');
      const jsonString = JSON.stringify(noteData, null, 2);
      hilog.info(DOMAIN_NUMBER, TAG, '序列化完成');

      // 3. 写入文件
      const filePath = this.note.getNoteFilePath();
      hilog.info(DOMAIN_NUMBER, TAG, `开始写入文件: ${filePath}`);
      await FileUtils.writeStringToFile(filePath, jsonString);

      this.saveStatus = '保存成功!';
      hilog.info(DOMAIN_NUMBER, TAG, '保存笔记成功');
      setTimeout(() => { this.saveStatus = ''; }, 2000);

      Prompt.showToast({ message: '笔记已保存', duration: 1500 });
      return true;

    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `保存笔记失败: ${error.message}`);
      this.saveStatus = '保存失败!';
      setTimeout(() => { this.saveStatus = ''; }, 2000);
      return false;
    }
  }

  // 加载最近编辑的笔记
  async loadRecentNote(notesDir:string): Promise<void> {
    try {
      // const files = await fileIo.listFile(this.notesDir);
      // const noteFiles = files.filter(file => file.endsWith('.json'));

      const files = await fs.listFile(notesDir);
      const noteFiles = files.filter(file => file.endsWith('.json'));

      if (noteFiles.length > 0) {
        // 加载最新的笔记
        const latestFile = noteFiles[noteFiles.length - 1];
        const noteId = latestFile.replace('.json', '');
        this.note = new Note(notesDir,noteId);
        await this.note.loadNote();
        // 清空编辑器并重建内容
        this.controller.deleteSpans({ start: 0, end: -1 });
        if(!this.note.noteData) return;
        await this.rebuildEditorContent(this.note.noteData.content);

        this.currentNoteId = this.note.noteId;
        hilog.info(DOMAIN_NUMBER, TAG, '加载了最新笔记！！！！！！！！');
      } else {
        // 创建新笔记
        await this.initializeNewNote();
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `加载最近笔记失败: ${error.message}`);
      await this.initializeNewNote();
    }
  }

  // 初始化新笔记
  async initializeNewNote(): Promise<void> {
    // 清空编辑器，让placeholder显示
    this.currentNoteId = 'note_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);  //?
    this.note = new Note(this.notesDir,this.currentNoteId);
    this.note.noteTitle = '未命名笔记';   //?
    this.controller.deleteSpans({ start: 0, end: -1 });
    hilog.info(DOMAIN_NUMBER, TAG, '初始化新笔记完成');
  }

  // 修改后的图片选择方法 - 支持多图片
  async selectImageFromGallery(): Promise<void> {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 5; // 设置为最多选择5张图片

      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoPicker.select(photoSelectOptions);

      if (photoSelectResult && photoSelectResult.photoUris.length > 0) {
        hilog.info(DOMAIN_NUMBER, TAG, `选择了 ${photoSelectResult.photoUris.length} 张图片`);

        // 遍历所有选中的图片URI
        for (const tempUri of photoSelectResult.photoUris) {
          try {
            await this.processAndInsertImage(tempUri);
          } catch (error) {
            hilog.error(DOMAIN_NUMBER, TAG, `处理单张图片失败: ${error.message}`);
            // 继续处理其他图片，不中断整个流程
          }
        }

        Prompt.showToast({
          message: `成功插入了 ${photoSelectResult.photoUris.length} 张图片`,
          duration: 2000
        });
      }
    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `选择图片失败: ${error.message}`);
      Prompt.showToast({ message: '选择图片失败', duration: 2000 });
    }
  }

  // 新增方法：处理临时URI并插入图片
  private async processAndInsertImage(tempUri: string): Promise<void> {
    try {
      // 1. 获取PhotoAccessHelper实例
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.uiContext.getHostContext());

      // 2. 构建查询条件
      let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo('uri', tempUri);

      let fetchOptions: photoAccessHelper.FetchOptions = {
        fetchColumns: [], // 只需要基础信息
        predicates: predicates
      };

      // 3. 获取PhotoAsset
      const fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
        await phAccessHelper.getAssets(fetchOptions);

      if (!fetchResult) {
        throw new Error('获取图片资源失败');
      }

      // 4. 从结果集中获取PhotoAsset
      const photoAsset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject();

      if (!photoAsset) {
        throw new Error('未找到对应的图片资源');
      }

      hilog.info(DOMAIN_NUMBER, TAG, `获取到图片: ${photoAsset.displayName}`);

      // 5. 使用正确的URI插入图片
      await this.insertImageToEditor(photoAsset.uri);

      // 6. 关闭fetchResult释放资源
      fetchResult.close();

    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `处理图片URI失败: ${error.message}`);
      throw new Error(`处理图片失败: ${error.message}`);
    }
  }

  // 插入图片到编辑器
  private async insertImageToEditor(imageUri: string): Promise<void> {
    try {
      const pixelMap = await this.imageManager.uriToPixelMap(imageUri);


      if (!pixelMap) {
        throw new Error('insertImageToEditor中图片解码失败，无法获取PixelMap');
      }


      this.controller.addImageSpan(pixelMap, {
        imageStyle: {
          size: [200, 150],
          verticalAlign: ImageSpanAlignment.CENTER,
          objectFit: ImageFit.Contain,
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

  // 重建编辑器内容
  private async rebuildEditorContent(noteContent: NoteSpanData[]): Promise<void> {
    for (const item of noteContent) {
      try {
        if (item.type === 'text') {
          this.controller.addTextSpan(item.content, {
            style: this.restoreTextStyle(item.style)
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

  // 重建本地图片Span
  private async rebuildLocalImageSpan(item: NoteSpanData): Promise<void> {
    if (!item.imageInfo?.localPath) {
      throw new Error('本地图片路径不存在');
    }

    // 检查图片文件是否存在
    const exists = await fs.access(item.imageInfo.localPath);
    if (!exists) {
      throw new Error('图片文件不存在: ' + item.imageInfo.localPath);
    }

    // 从本地文件加载图片
    const pixelMap = await this.imageManager.loadPixelMapFromFile(item.imageInfo.localPath);
    this.controller.addImageSpan(pixelMap, {
      imageStyle: {
        size: item.style?.size,
        // 使用工具类将字符串转换回枚举
        verticalAlign: StyleConversionUtils.stringToImageSpanAlignment(item.style?.verticalAlign),
        objectFit: StyleConversionUtils.stringToImageFit(item.style?.objectFit)
      }
    });
  }

  // 恢复时：NoteSpanStyle to RichEditorTextStyle
  private restoreTextStyle(style: NoteSpanStyle | undefined): RichEditorTextStyle {
    if (!style) {
      return {};
    }

    return {
      fontSize: style.fontSize,
      // 使用工具类转换颜色
      fontColor: Color.Black, //StyleConversionUtils.stringToColor(style.fontColor),
      fontWeight: style.fontWeight,
      // 使用工具类转换字体样式
      fontStyle: StyleConversionUtils.stringToFontStyle(style.fontStyle),
      fontFamily: style.fontFamily,
    };
  }


  // 检查笔记路径是否存在
  static async ensureNotesDirectoryExists(notesDir:string): Promise<void> {
    try {
      hilog.info(DOMAIN_NUMBER, TAG, `检查目录是否存在: ${notesDir}`);

      const dirExists = await fs.access(notesDir);

      if (dirExists) {
        hilog.info(DOMAIN_NUMBER, TAG, '笔记目录已存在');
        return;
      }

      hilog.info(DOMAIN_NUMBER, TAG, '目录不存在，开始创建笔记目录');

      // 使用新的 fs.mkdir API
      await fs.mkdir(notesDir);

      // 验证目录是否创建成功
      const created = await fs.access(notesDir);
      if (created) {
        hilog.info(DOMAIN_NUMBER, TAG, '笔记目录创建成功');
      } else {
        throw new Error('目录创建后验证失败');
      }

    } catch (error) {
      hilog.error(DOMAIN_NUMBER, TAG, `创建笔记目录失败: ${(error as BusinessError).message}`);
      throw new Error(`无法创建存储目录: ${(error as BusinessError).message}`);
    }
  }
}