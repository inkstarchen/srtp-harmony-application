// src/utils/StyleConversionUtils.ts
import { NoteSpanStyle } from "../model/NoteSpanData";
import { hilog } from "@kit.PerformanceAnalysisKit";
//import { staticMap } from "@kit.MapKit";

const TAG: string = '[NoteStyle]';
const DOMAIN_NUMBER: number = 0xFF01;

export class StyleConversionUtils {
  // 静态常量映射表 - 只在类加载时创建一次

  // FontStyle 映射
  private static readonly fontStyleMap: Map<FontStyle, string> = new Map([
    [FontStyle.Normal, 'normal'],
    [FontStyle.Italic, 'italic']
  ]);

  private static readonly fontStyleReverseMap: Map<string, FontStyle> = new Map([
    ['normal', FontStyle.Normal],
    ['italic', FontStyle.Italic]
  ]);

  // ImageSpanAlignment 映射
  private static readonly alignmentMap: Map<ImageSpanAlignment, string> = new Map([
    [ImageSpanAlignment.BASELINE, 'baseline'],
    [ImageSpanAlignment.BOTTOM, 'bottom'],
    [ImageSpanAlignment.CENTER, 'center'],
    [ImageSpanAlignment.TOP, 'top']
  ]);

  private static readonly alignmentReverseMap: Map<string, ImageSpanAlignment> = new Map([
    ['baseline', ImageSpanAlignment.BASELINE],
    ['bottom', ImageSpanAlignment.BOTTOM],
    ['center', ImageSpanAlignment.CENTER],
    ['top', ImageSpanAlignment.TOP]
  ]);

  // ImageFit 映射
  private static readonly imageFitMap: Map<ImageFit, string> = new Map([
    [ImageFit.Contain, 'contain'],
    [ImageFit.Cover, 'cover'],
    [ImageFit.Fill, 'fill'],
    [ImageFit.None, 'none'],
    [ImageFit.ScaleDown, 'scaleDown'],
    [ImageFit.Auto, 'auto']
  ]);

  private static readonly imageFitReverseMap: Map<string, ImageFit> = new Map([
    ['contain', ImageFit.Contain],
    ['cover', ImageFit.Cover],
    ['fill', ImageFit.Fill],
    ['none', ImageFit.None],
    ['scaleDown', ImageFit.ScaleDown],
    ['auto', ImageFit.Auto]
  ]);

  private static readonly colorMap: Map<number, string> = new Map([
    [Color.Black, 'black'],
    [Color.Blue, 'blue'],
    [Color.Brown, 'brown'],
    [Color.Grey, 'grey'],
    [Color.Green, 'green'],
    [Color.Orange, 'orange'],
    [Color.Pink, 'pink'],
    [Color.Red, 'red'],
    [Color.White, 'white'],
    [Color.Yellow, 'yellow']
  ]);

  private static readonly colorReverseMap: Map<string, Color> = new Map([
    ['black', Color.Black],
    ['blue', Color.Blue],
    ['brown', Color.Brown],
    ['grey', Color.Grey],
    ['green', Color.Green],
    ['orange', Color.Orange],
    ['pink', Color.Pink],
    ['red', Color.Red],
    ['white', Color.White],
    ['yellow', Color.Yellow]
  ]);

  // FontStyle 转换
  static fontStyleToString(fontStyle: FontStyle | undefined): string {
    if (!fontStyle) return 'normal';
    return StyleConversionUtils.fontStyleMap.get(fontStyle) || 'normal';  // 使用类名而不是this
  }

  static stringToFontStyle(fontStyleStr: string | undefined): FontStyle {
    if (!fontStyleStr) return FontStyle.Normal;
    return StyleConversionUtils.fontStyleReverseMap.get(fontStyleStr) || FontStyle.Normal;  // 使用类名而不是this
  }

  static fontWeightToString(fontWeight: number | undefined): string {
    if (fontWeight === undefined || fontWeight === null) return 'normal';
    return fontWeight === 9 ? 'bold' : 'normal';
  }

  static stringToFontWeight(fontWeight: number | string | undefined): number | FontWeight | string {
    if (fontWeight === undefined || fontWeight === null) return FontWeight.Normal;
    if (typeof fontWeight === 'number') return fontWeight === 9 ? FontWeight.Bold : FontWeight.Normal;

    const trimmed = fontWeight.trim().toLowerCase();
    if (trimmed === 'bold') return FontWeight.Bold;
    if (trimmed === 'normal') return FontWeight.Normal;
    return FontWeight.Normal;
  }

  // ImageSpanAlignment 转换
  static imageSpanAlignmentToString(alignment: ImageSpanAlignment | undefined): string {
    if (!alignment) return 'baseline';
    return StyleConversionUtils.alignmentMap.get(alignment) || 'baseline';  // 使用类名而不是this
  }

  static stringToImageSpanAlignment(alignmentStr: string | undefined): ImageSpanAlignment {
    if (!alignmentStr) return ImageSpanAlignment.BASELINE;
    return StyleConversionUtils.alignmentReverseMap.get(alignmentStr) || ImageSpanAlignment.BASELINE;  // 使用类名而不是this
  }

  // ImageFit 转换
  static imageFitToString(fit: ImageFit | undefined): string {
    if (!fit) return 'auto';
    return StyleConversionUtils.imageFitMap.get(fit) || 'auto';  // 使用类名而不是this
  }

  static stringToImageFit(fitStr: string | undefined): ImageFit {
    if (!fitStr) return ImageFit.Auto;
    return StyleConversionUtils.imageFitReverseMap.get(fitStr) || ImageFit.Auto;  // 使用类名而不是this
  }

  // 恢复时：NoteSpanStyle to RichEditorTextStyle
  static restoreTextStyle(style: NoteSpanStyle | undefined): RichEditorTextStyle {
    if (!style) {
      return {};
    }
    hilog.info(DOMAIN_NUMBER, TAG, `restore color=${style.fontColor}`);
    return {
      fontSize: style.fontSize,
      fontColor: StyleConversionUtils.stringToColor(style.fontColor),
      fontWeight: StyleConversionUtils.stringToFontWeight(style.fontWeight),
      // 使用工具类转换字体样式
      fontStyle: StyleConversionUtils.stringToFontStyle(style.fontStyle),
      fontFamily: style.fontFamily,
      decoration: {
        type: style.decorationType !== undefined ? style.decorationType : TextDecorationType.None
      }
    };
  }

  // 存储时：RichEditorTextStyleResult to NoteSpanStyle
  static simplifyTextStyle(textStyle: RichEditorTextStyleResult | undefined): NoteSpanStyle {
    if (!textStyle) {
      return {};
    }
    return {
      fontSize: textStyle.fontSize,
      fontColor: StyleConversionUtils.colorToString(textStyle.fontColor),
      fontWeight: StyleConversionUtils.fontWeightToString(textStyle.fontWeight),
      // 使用工具类转换字体样式
      fontStyle: StyleConversionUtils.fontStyleToString(textStyle.fontStyle),
      fontFamily: textStyle.fontFamily,
      decorationType: textStyle.decoration ? textStyle.decoration.type : TextDecorationType.None
    };
  }

  // 颜色转换  暂时不用
  static colorToString(color: ResourceColor): string {
    if (typeof color === 'number') {
      return StyleConversionUtils.colorMap.get(color) || 'black';
    }
    if (typeof color === 'string') {
      return color;
    }
    return 'black';
  }

  // 暂时不用
  static stringToColor(colorStr: string | undefined): ResourceColor {
    if (!colorStr) {
      return Color.Black;
    }
    const trimmed = colorStr.trim();
    const lowered = trimmed.toLowerCase();
    if (trimmed.startsWith('#') || lowered.startsWith('0x')) {
      return trimmed;
    }
    return StyleConversionUtils.colorReverseMap.get(lowered) || Color.Black;
  }
}