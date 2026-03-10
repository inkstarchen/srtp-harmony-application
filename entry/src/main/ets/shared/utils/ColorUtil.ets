export interface RGB {
  r: number
  g: number
  b: number
}

/**
 * 给颜色字符串添加透明度
 * @param color 颜色字符串，例如 #1976d2 或 1976d2
 * @param alpha 透明度 0~1
 * @returns #AARRGGBB 格式颜色
 */
export function colorWithAlpha(color: string, alpha: number): string {
  // 去掉 #
  let hex = color.replace('#', '');

  if (hex.length !== 6) {
    throw new Error('color must be #RRGGBB format');
  }

  // 限制 alpha 范围
  const a = Math.max(0, Math.min(1, alpha));

  // 转换为 0~255
  const alphaInt = Math.round(a * 255);

  // 转为两位十六进制
  const alphaHex = alphaInt.toString(16).padStart(2, '0');

  return `#${alphaHex}${hex}`;
}

export class ColorUtil {
  /* ---------- 基础工具 ---------- */

  static clamp(v: number, min = 0, max = 1): number {
    return Math.min(max, Math.max(min, v))
  }

  static to255(v: number): number {
    return Math.round(ColorUtil.clamp(v) * 255)
  }

  static alphaTo255(a: number): number {
    return Math.round(ColorUtil.clamp(a, 0, 1) * 255)
  }

  static toHex(v: number): string {
    return v.toString(16).padStart(2, '0')
  }

  /* ---------- 输出 ---------- */

  static rgbToHex(r: number, g: number, b: number): string {
    return (
      '#' +
      ColorUtil.toHex(r) +
      ColorUtil.toHex(g) +
      ColorUtil.toHex(b)
    )
  }

  static rgbaToHex(
    r: number,
    g: number,
    b: number,
    a: number
  ): string {
    return (
      '#' +
      ColorUtil.toHex(ColorUtil.alphaTo255(a)) +
      ColorUtil.toHex(ColorUtil.clamp(r, 0, 255)) +
      ColorUtil.toHex(ColorUtil.clamp(g, 0, 255)) +
      ColorUtil.toHex(ColorUtil.clamp(b, 0, 255))
    )
  }


  /* ---------- RGB ---------- */

  static fromRGB(
    r: number,
    g: number,
    b: number
  ): string {
    return ColorUtil.rgbToHex(
      ColorUtil.clamp(r, 0, 255),
      ColorUtil.clamp(g, 0, 255),
      ColorUtil.clamp(b, 0, 255)
    )
  }

  /* ---------- RGBA ---------- */
  static fromRGBA(
    r: number,
    g: number,
    b: number,
    a: number
  ): string {
    return ColorUtil.rgbaToHex(r, g, b, a)
  }

  /* ---------- Gray ---------- */

  static fromGray(v: number): string {
    const c = ColorUtil.to255(v)
    return ColorUtil.rgbToHex(c, c, c)
  }

  static fromGrayA(v: number, a: number): string {
    const c = ColorUtil.to255(v)
    return ColorUtil.rgbaToHex(c, c, c, a)
  }
  /* ---------- HSL ---------- */

  static fromHSL(
    h: number, // 0–360
    s: number, // 0–1
    l: number  // 0–1
  ): string {
    h = ((h % 360) + 360) % 360
    s = ColorUtil.clamp(s)
    l = ColorUtil.clamp(l)

    const c = (1 - Math.abs(2 * l - 1)) * s
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1))
    const m = l - c / 2

    let r = 0, g = 0, b = 0;

    if (h < 60) {
      r = c
      g = x
      b = 0
    } else if (h < 120) {
      r = x
      g = c
      b = 0
    } else if (h < 180) {
      r = 0
      g = c
      b = x
    } else if (h < 240) {
      r = 0
      g = x
      b = c
    } else if (h < 300) {
      r = x
      g = 0
      b = c
    } else {
      r = c
      g = 0
      b = x
    }


    return ColorUtil.rgbToHex(
      ColorUtil.to255(r + m),
      ColorUtil.to255(g + m),
      ColorUtil.to255(b + m)
    )
  }

  /* ---------- HSV / HSB ---------- */

  static fromHSV(
    h: number, // 0–360
    s: number, // 0–1
    v: number  // 0–1
  ): string {
    h = ((h % 360) + 360) % 360
    s = ColorUtil.clamp(s)
    v = ColorUtil.clamp(v)

    const c = v * s
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1))
    const m = v - c

    let r = 0, g = 0, b = 0

    if (h < 60) {
      r = c
      g = x
      b = 0
    } else if (h < 120) {
      r = x
      g = c
      b = 0
    } else if (h < 180) {
      r = 0
      g = c
      b = x
    } else if (h < 240) {
      r = 0
      g = x
      b = c
    } else if (h < 300) {
      r = x
      g = 0
      b = c
    } else {
      r = c
      g = 0
      b = x
    }

    return ColorUtil.rgbToHex(
      ColorUtil.to255(r + m),
      ColorUtil.to255(g + m),
      ColorUtil.to255(b + m)
    )
  }

  static hslToRGB(h: number, s: number, l: number): RGB {
    h = ((h % 360) + 360) % 360
    s = ColorUtil.clamp(s)
    l = ColorUtil.clamp(l)

    const c = (1 - Math.abs(2 * l - 1)) * s
    const x = c * (1 - Math.abs(((h / 60) % 2) - 1))
    const m = l - c / 2

    let r = 0, g = 0, b = 0

    if (h < 60) {
      r = c; g = x; b = 0
    } else if (h < 120) {
      r = x; g = c; b = 0
    } else if (h < 180) {
      r = 0; g = c; b = x
    } else if (h < 240) {
      r = 0; g = x; b = c
    } else if (h < 300) {
      r = x; g = 0; b = c
    } else {
      r = c; g = 0; b = x
    }

    return {
      r: ColorUtil.to255(r + m),
      g: ColorUtil.to255(g + m),
      b: ColorUtil.to255(b + m),
    }
  }


  static fromHSLA(
    h: number,
    s: number,
    l: number,
    a: number
  ): string {
    // HSL → RGB 和你现在的一样
    // 最后一步用 rgbaToHex

    const rgb = ColorUtil.hslToRGB(h, s, l)
    return ColorUtil.rgbaToHex(rgb.r, rgb.g, rgb.b, a)
  }
}
