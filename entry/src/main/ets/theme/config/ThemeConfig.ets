/**
 * 主题配置定义
 * 定义应用支持的所有主题类型和主题切换逻辑
 */

/**
 * 主题类型枚举
 */
export enum ThemeType {
  LIGHT = 'light',           // 浅色主题
  DARK = 'dark',             // 深色主题
  SYSTEM = 'system'          // 跟随系统
}

/**
 * 主题色板类型
 */
export enum ColorScheme {
  DEFAULT = 'default',       // 默认色板
  OCEAN = 'ocean',           // 海洋蓝
  FOREST = 'forest',         // 森林绿
  SUNSET = 'sunset',         // 日落橙
  BERRY = 'berry'            // 浆果紫
}

/**
 * 主题配置接口
 */
export interface ThemeConfig {
  name: string;              // 主题名称
  type: ThemeType;           // 主题类型
  colorScheme: ColorScheme;  // 色板方案
  isDark: boolean;           // 是否为深色模式
}

/**
 * 默认主题配置
 */
export const DEFAULT_THEME: ThemeConfig = {
  name: '默认主题',
  type: ThemeType.LIGHT,
  colorScheme: ColorScheme.DEFAULT,
  isDark: false
};

/**
 * 主题配置管理类
 * 提供主题的创建、验证和转换功能
 */
export class ThemeConfigManager {
  /**
   * 根据类型创建主题配置
   */
  static createTheme(type: ThemeType, colorScheme: ColorScheme = ColorScheme.DEFAULT): ThemeConfig {
    return {
      name: ThemeConfigManager.getThemeName(type, colorScheme),
      type,
      colorScheme,
      isDark: type === ThemeType.DARK
    };
  }

  /**
   * 获取主题显示名称
   */
  private static getThemeName(type: ThemeType, colorScheme: ColorScheme): string {
    const typeNames: Record<ThemeType, string> = {
      [ThemeType.LIGHT]: '浅色',
      [ThemeType.DARK]: '深色',
      [ThemeType.SYSTEM]: '系统'
    };
    const schemeNames: Record<ColorScheme, string> = {
      [ColorScheme.DEFAULT]: '默认',
      [ColorScheme.OCEAN]: '海洋',
      [ColorScheme.FOREST]: '森林',
      [ColorScheme.SUNSET]: '日落',
      [ColorScheme.BERRY]: '浆果'
    };
    return `${schemeNames[colorScheme]}${typeNames[type]}`;
  }

  /**
   * 判断是否需要深色模式
   */
  static resolveDarkMode(theme: ThemeConfig, systemIsDark: boolean = false): boolean {
    switch (theme.type) {
      case ThemeType.DARK:
        return true;
      case ThemeType.LIGHT:
        return false;
      case ThemeType.SYSTEM:
        return systemIsDark;
      default:
        return false;
    }
  }
}
