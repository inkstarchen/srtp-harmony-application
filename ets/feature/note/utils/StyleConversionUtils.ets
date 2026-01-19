// src/utils/StyleConversionUtils.ts
import { NoteSpanStyle } from "../model/NoteSpanData";
import { staticMap } from "@kit.MapKit";

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

  // FontStyle 转换
  static fontStyleToString(fontStyle: FontStyle | undefined): string {
    if (!fontStyle) return 'normal';
    return StyleConversionUtils.fontStyleMap.get(fontStyle) || 'normal';  // 使用类名而不是this
  }

  static stringToFontStyle(fontStyleStr: string | undefined): FontStyle {
    if (!fontStyleStr) return FontStyle.Normal;
    return StyleConversionUtils.fontStyleReverseMap.get(fontStyleStr) || FontStyle.Normal;  // 使用类名而不是this
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

  // 存储时：RichEditorTextStyleResult to NoteSpanStyle
  static simplifyTextStyle(textStyle: RichEditorTextStyleResult | undefined): NoteSpanStyle {
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

  // 颜色转换  暂时不用
  static colorToString(color: ResourceColor): string {
    if (typeof color === 'string') return color;
    if (color && color.toString) return color.toString();
    return '#000000';
  }

  // 暂时不用
  static stringToColor(colorStr: string | undefined): ResourceColor {
    if (!colorStr) {
      return Color.Black;
    }
    if (colorStr.startsWith('#')) {
      return colorStr;
    }
    return Color.Black;
  }
}