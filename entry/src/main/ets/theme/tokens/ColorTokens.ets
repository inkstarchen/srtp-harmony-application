/**
 * 颜色设计令牌
 * 定义所有主题颜色变量，实现单一变量控制全部组件色彩
 */

import { ColorScheme, ThemeType } from '../config/ThemeConfig';

/**
 * 颜色令牌接口
 * 定义所有可用的颜色变量
 */
export interface ColorTokens {
  // 主色调
  primary: string;
  primaryLight: string;
  primaryDark: string;
  primaryContainer: string;
  onPrimary: string;
  onPrimaryContainer: string;

  // 次色调
  secondary: string;
  secondaryLight: string;
  secondaryDark: string;
  secondaryContainer: string;
  onSecondary: string;
  onSecondaryContainer: string;

  // 强调色
  tertiary: string;
  tertiaryLight: string;
  tertiaryDark: string;
  tertiaryContainer: string;
  onTertiary: string;
  onTertiaryContainer: string;

  // 功能色
  success: string;
  warning: string;
  error: string;
  info: string;

  // 背景色
  background: string;
  backgroundVariant: string;
  surface: string;
  surfaceVariant: string;
  surfaceRaised: string;
  onBackground: string;
  onSurface: string;
  onSurfaceVariant: string;

  // 边框色
  outline: string;
  outlineVariant: string;

  // 阴影/遮罩
  shadow: string;
  scrim: string;

  // 特殊状态
  inverse: string;
  inverseSurface: string;
  inverseOnSurface: string;
}

/**
 * 默认浅色主题色板
 */
const DEFAULT_LIGHT_PALETTE: ColorTokens = {
  // 主色调 - 蓝色系
  primary: '#1976d2',
  primaryLight: '#BBDEFB',
  primaryDark: '#0D47A1',
  primaryContainer: '#fff3f6f6',
  onPrimary: '#FFFFFF',
  onPrimaryContainer: '#0D47A1',

  // 次色调 - 青色系
  secondary: '#00897B',
  secondaryLight: '#B2DFDB',
  secondaryDark: '#004D40',
  secondaryContainer: '#E0F2F1',
  onSecondary: '#FFFFFF',
  onSecondaryContainer: '#004D40',

  // 强调色 - 紫色系
  tertiary: '#7B1FA2',
  tertiaryLight: '#E1BEE7',
  tertiaryDark: '#4A148C',
  tertiaryContainer: '#F3E5F5',
  onTertiary: '#FFFFFF',
  onTertiaryContainer: '#4A148C',

  // 功能色
  success: '#4CAF50',
  warning: '#FF9800',
  error: '#F44336',
  info: '#2196F3',

  // 背景色 - 浅色系
  background: '#f8f3f0',
  backgroundVariant: '#F5F5F5',
  surface: '#FFFFFF',
  surfaceVariant: '#F0F0F0',
  surfaceRaised: '#FFFFFF',
  onBackground: '#1C1B1F',
  onSurface: '#1C1B1F',
  onSurfaceVariant: '#49454F',

  // 边框色
  outline: '#BDBDBD',
  outlineVariant: '#E0E0E0',

  // 阴影/遮罩
  shadow: 'rgba(0, 0, 0, 0.15)',
  scrim: 'rgba(0, 0, 0, 0.32)',

  // 特殊状态
  inverse: '#FFFFFF',
  inverseSurface: '#303030',
  inverseOnSurface: '#FFFFFF'
};

/**
 * 默认深色主题色板
 */
const DEFAULT_DARK_PALETTE: ColorTokens = {
  // 主色调 - 蓝色系 (深色适配)
  primary: '#90CAF9',
  primaryLight: '#42A5F5',
  primaryDark: '#1565C0',
  primaryContainer: '#0D47A1',
  onPrimary: '#0D47A1',
  onPrimaryContainer: '#BBDEFB',

  // 次色调 - 青色系 (深色适配)
  secondary: '#80CBC4',
  secondaryLight: '#4DB6AC',
  secondaryDark: '#00796B',
  secondaryContainer: '#004D40',
  onSecondary: '#004D40',
  onSecondaryContainer: '#B2DFDB',

  // 强调色 - 紫色系 (深色适配)
  tertiary: '#CE93D8',
  tertiaryLight: '#BA68C8',
  tertiaryDark: '#7B1FA2',
  tertiaryContainer: '#4A148C',
  onTertiary: '#4A148C',
  onTertiaryContainer: '#E1BEE7',

  // 功能色 (深色适配)
  success: '#81C784',
  warning: '#FFB74D',
  error: '#E57373',
  info: '#64B5F6',

  // 背景色 - 深色系
  background: '#121212',
  backgroundVariant: '#1E1E1E',
  surface: '#1E1E1E',
  surfaceVariant: '#2D2D2D',
  surfaceRaised: '#2D2D2D',
  onBackground: '#E6E1E5',
  onSurface: '#E6E1E5',
  onSurfaceVariant: '#CAC4D0',

  // 边框色 (深色适配)
  outline: '#938F99',
  outlineVariant: '#444746',

  // 阴影/遮罩 (深色适配)
  shadow: 'rgba(0, 0, 0, 0.3)',
  scrim: 'rgba(0, 0, 0, 0.6)',

  // 特殊状态
  inverse: '#1C1B1F',
  inverseSurface: '#E6E1E5',
  inverseOnSurface: '#302F35'
};

/**
 * 色板生成器
 */
export class ColorPaletteGenerator {
  /**
   * 根据色板方案生成颜色令牌
   */
  static generatePalette(
    scheme: ColorScheme,
    isDark: boolean
  ): ColorTokens {
    const basePalette = isDark ? DEFAULT_DARK_PALETTE : DEFAULT_LIGHT_PALETTE;

    // 目前默认方案返回基础色板
    // 可以扩展其他色板方案 (海洋、森林、日落、浆果)
    switch (scheme) {
      case ColorScheme.OCEAN:
        return ColorPaletteGenerator.generateOceanPalette(isDark);
      case ColorScheme.FOREST:
        return ColorPaletteGenerator.generateForestPalette(isDark);
      case ColorScheme.SUNSET:
        return ColorPaletteGenerator.generateSunsetPalette(isDark);
      case ColorScheme.BERRY:
        return ColorPaletteGenerator.generateBerryPalette(isDark);
      default:
        return basePalette;
    }
  }

  /**
   * 海洋色板 (蓝色系)
   */
  private static mergePalette(base: ColorTokens, overrides: Partial<ColorTokens>): ColorTokens {
    // 手动合并 base 和 overrides
    return {
      primary: overrides.primary ?? base.primary,
      primaryLight: overrides.primaryLight ?? base.primaryLight,
      primaryDark: overrides.primaryDark ?? base.primaryDark,
      primaryContainer: overrides.primaryContainer ?? base.primaryContainer,
      onPrimary: overrides.onPrimary ?? base.onPrimary,
      onPrimaryContainer: overrides.onPrimaryContainer ?? base.onPrimaryContainer,

      secondary: overrides.secondary ?? base.secondary,
      secondaryLight: overrides.secondaryLight ?? base.secondaryLight,
      secondaryDark: overrides.secondaryDark ?? base.secondaryDark,
      secondaryContainer: overrides.secondaryContainer ?? base.secondaryContainer,
      onSecondary: overrides.onSecondary ?? base.onSecondary,
      onSecondaryContainer: overrides.onSecondaryContainer ?? base.onSecondaryContainer,

      tertiary: overrides.tertiary ?? base.tertiary,
      tertiaryLight: overrides.tertiaryLight ?? base.tertiaryLight,
      tertiaryDark: overrides.tertiaryDark ?? base.tertiaryDark,
      tertiaryContainer: overrides.tertiaryContainer ?? base.tertiaryContainer,
      onTertiary: overrides.onTertiary ?? base.onTertiary,
      onTertiaryContainer: overrides.onTertiaryContainer ?? base.onTertiaryContainer,

      success: overrides.success ?? base.success,
      warning: overrides.warning ?? base.warning,
      error: overrides.error ?? base.error,
      info: overrides.info ?? base.info,

      background: overrides.background ?? base.background,
      backgroundVariant: overrides.backgroundVariant ?? base.backgroundVariant,
      surface: overrides.surface ?? base.surface,
      surfaceVariant: overrides.surfaceVariant ?? base.surfaceVariant,
      surfaceRaised: overrides.surfaceRaised ?? base.surfaceRaised,
      onBackground: overrides.onBackground ?? base.onBackground,
      onSurface: overrides.onSurface ?? base.onSurface,
      onSurfaceVariant: overrides.onSurfaceVariant ?? base.onSurfaceVariant,

      outline: overrides.outline ?? base.outline,
      outlineVariant: overrides.outlineVariant ?? base.outlineVariant,
      shadow: overrides.shadow ?? base.shadow,
      scrim: overrides.scrim ?? base.scrim,
      inverse: overrides.inverse ?? base.inverse,
      inverseSurface: overrides.inverseSurface ?? base.inverseSurface,
      inverseOnSurface: overrides.inverseOnSurface ?? base.inverseOnSurface
    };
  }

  private static generateOceanPalette(isDark: boolean): ColorTokens {
    const base = isDark ? DEFAULT_DARK_PALETTE : DEFAULT_LIGHT_PALETTE;

    return ColorPaletteGenerator.mergePalette(base, {
      primary: isDark ? '#64B5F6' : '#1E88E5',
      primaryContainer: isDark ? '#01579B' : '#E3F2FD',
      secondary: isDark ? '#4DD0E1' : '#00ACC1',
      tertiary: isDark ? '#4FC3F7' : '#039BE5'
    });
  }

  private static generateForestPalette(isDark: boolean): ColorTokens {
    const base = isDark ? DEFAULT_DARK_PALETTE : DEFAULT_LIGHT_PALETTE;

    return ColorPaletteGenerator.mergePalette(base, {
      primary: isDark ? '#81C784' : '#43A047',
      primaryContainer: isDark ? '#1B5E20' : '#E8F5E9',
      secondary: isDark ? '#AED581' : '#7CB342',
      tertiary: isDark ? '#4DB6AC' : '#00897B'
    });
  }

  private static generateSunsetPalette(isDark: boolean): ColorTokens {
    const base = isDark ? DEFAULT_DARK_PALETTE : DEFAULT_LIGHT_PALETTE;

    return ColorPaletteGenerator.mergePalette(base, {
      primary: isDark ? '#FF8A65' : '#F57C00',
      primaryContainer: isDark ? '#BF360C' : '#FFF3E0',
      secondary: isDark ? '#FFD54F' : '#FFA000',
      tertiary: isDark ? '#FF6E40' : '#D84315'
    });
  }

  private static generateBerryPalette(isDark: boolean): ColorTokens {
    const base = isDark ? DEFAULT_DARK_PALETTE : DEFAULT_LIGHT_PALETTE;

    return ColorPaletteGenerator.mergePalette(base, {
      primary: isDark ? '#BA68C8' : '#AB47BC',
      primaryContainer: isDark ? '#4A148C' : '#F3E5F5',
      secondary: isDark ? '#F06292' : '#EC407A',
      tertiary: isDark ? '#E57373' : '#D32F2F'
    });
  }
}

/**
 * 颜色令牌管理器
 * 主题色彩的核心管理类
 */
export class ColorTokenManager {
  private static currentTokens: ColorTokens = DEFAULT_LIGHT_PALETTE;

  /**
   * 获取当前颜色令牌
   */
  static getTokens(): ColorTokens {
    return ColorTokenManager.currentTokens;
  }

  /**
   * 设置颜色令牌
   * @param scheme 色板方案
   * @param isDark 是否为深色模式
   */
  static setTokens(scheme: ColorScheme, isDark: boolean): void {
    ColorTokenManager.currentTokens = ColorPaletteGenerator.generatePalette(scheme, isDark);
  }

  /**
   * 获取主色调
   */
  static getPrimary(): string {
    return ColorTokenManager.currentTokens.primary;
  }

  /**
   * 获取背景色
   */
  static getBackground(): string {
    return ColorTokenManager.currentTokens.background;
  }

  /**
   * 获取表面色
   */
  static getSurface(): string {
    return ColorTokenManager.currentTokens.surface;
  }
}
