/**
 * 主题管理器 (核心)
 * 统一管理应用主题状态，实现单一变量控制全部组件色彩
 *
 * 使用方式:
 * 1. 初始化：ThemeManager.initialize(context)
 * 2. 订阅变化：ThemeManager.subscribe(callback)
 * 3. 切换主题：ThemeManager.setTheme(ThemeType.DARK, ColorScheme.OCEAN)
 * 4. 获取颜色：ThemeManager.getColor('primary') 或 ThemeManager.tokens.primary
 */

import { ColorTokens, ColorTokenManager } from '../tokens/ColorTokens';
import { ThemeType, ColorScheme, ThemeConfig, ThemeConfigManager, DEFAULT_THEME } from '../config/ThemeConfig';
import { SpacingTokens, SpacingUtils, DEFAULT_SPACING } from '../tokens/SpacingTokens';
import { ComponentSizeTokens, DEFAULT_COMPONENT_SIZE } from '../tokens/SizeTokens';
import { TypographyTokens, DEFAULT_TYPOGRAPHY } from '../tokens/SizeTokens';
import { deviceInfo } from '@kit.BasicServicesKit';

export interface ConfigType{
  type: string;
  colorScheme: string;
}

/**
 * 主题状态接口
 * 包含所有主题相关的状态信息
 */

export interface  ThemeState {
  config: ThemeConfig;           // 主题配置
  tokens: ColorTokens;           // 颜色令牌
  spacing: SpacingTokens;        // 间距令牌
  componentSizes: ComponentSizeTokens;  // 组件尺寸令牌
  typography: TypographyTokens;  // 字体令牌
  isDark: boolean;               // 是否深色模式
}

/**
 * 主题管理器类
 * 单例模式，全局唯一实例
 */
@ObservedV2
export class ThemeManager {
  private static instance: ThemeManager | null;
  @Trace private currentThemeState: ThemeState;
  private isInitialized: boolean = false;

  private constructor() {
    // 初始化默认主题状态
    this.currentThemeState = this.createThemeState(
      ThemeConfigManager.createTheme(ThemeType.LIGHT, ColorScheme.DEFAULT)
    );
  }

  /**
   * 获取单例实例
   */
  static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  /**
   * 初始化主题管理器
   * 应在应用启动时调用
   */
  initialize(systemIsDark: boolean = false): void {
    if (this.isInitialized) {
      return;
    }

    // 检测系统深色模式
    const isSystemDark = this.detectSystemDarkMode(systemIsDark);

    // 设置初始主题
    this.applyTheme(ThemeType.SYSTEM, ColorScheme.DEFAULT, isSystemDark);

    this.isInitialized = true;
    console.log('[ThemeManager] Initialized successfully');
  }

  static release() {
    if (ThemeManager.instance){
      ThemeManager.instance.releaseManager();
      ThemeManager.instance = null;
    }
  }

  releaseManager():void {
    this.isInitialized = false;
  }

  /**
   * 检测系统深色模式
   */
  private detectSystemDarkMode(fallback: boolean = false): boolean {
    try {
      // 尝试从系统获取深色模式状态
      // 注：实际项目中可能需要通过 preference 或其他 API 获取
      return fallback;
    } catch (e) {
      console.warn(`[ThemeManager] Failed to detect system dark mode: ${e}`);
      return fallback;
    }
  }

  /**
   * 创建主题状态
   */
  private createThemeState(config: ThemeConfig): ThemeState {
    const isDark = ThemeConfigManager.resolveDarkMode(
      config,
      this.detectSystemDarkMode()
    );

    // 更新颜色令牌管理器
    ColorTokenManager.setTokens(config.colorScheme, isDark);

    return {
      config,
      tokens: ColorTokenManager.getTokens(),
      spacing: DEFAULT_SPACING,
      componentSizes: DEFAULT_COMPONENT_SIZE,
      typography: DEFAULT_TYPOGRAPHY,
      isDark
    };
  }

  /**
   * 应用主题
   */
  private applyTheme(
    type: ThemeType,
    colorScheme: ColorScheme,
    systemIsDark: boolean = false
  ): void {
    const config = ThemeConfigManager.createTheme(type, colorScheme);
    const newThemeState = this.createThemeState(config);

    this.currentThemeState = newThemeState;
  }

  /**
   * 设置主题
   * @param type 主题类型 (LIGHT/DARK/SYSTEM)
   * @param colorScheme 色板方案
   *
   * 示例:
   * ThemeManager.setTheme(ThemeType.DARK)  // 切换到深色主题
   * ThemeManager.setTheme(ThemeType.LIGHT, ColorScheme.OCEAN)  // 浅色海洋主题
   */
  setTheme(type: ThemeType, colorScheme: ColorScheme = ColorScheme.DEFAULT): void {
    const systemIsDark = this.detectSystemDarkMode();
    this.applyTheme(type, colorScheme, systemIsDark);
    console.log(`[ThemeManager] Theme changed to ${type}, scheme: ${colorScheme}`);
  }

  /**
   * 切换深色/浅色模式
   */
  toggleDarkMode(): void {
    const newType = this.currentThemeState.isDark ? ThemeType.LIGHT : ThemeType.DARK;
    this.setTheme(newType, this.currentThemeState.config.colorScheme);
  }

  /**
   * 设置色板方案
   */
  setColorScheme(scheme: ColorScheme): void {
    this.setTheme(this.currentThemeState.config.type, scheme);
  }


  /**
   * 获取当前主题状态
   */
  getThemeState(): ThemeState {
    return this.currentThemeState;
  }

  /**
   * 获取颜色令牌
   */
  get tokens(): ColorTokens {
    return this.currentThemeState.tokens;
  }

  /**
   * 获取间距令牌
   */
  get spacing(): SpacingTokens {
    return this.currentThemeState.spacing;
  }

  /**
   * 获取组件尺寸令牌
   */
  get componentSizes(): ComponentSizeTokens {
    return this.currentThemeState.componentSizes;
  }

  /**
   * 获取字体令牌
   */
  get typography(): TypographyTokens {
    return this.currentThemeState.typography;
  }

  /**
   * 获取当前是否深色模式
   */
  get isDark(): boolean {
    return this.currentThemeState.isDark;
  }

  /**
   * 导出主题配置 (用于持久化)
   */
  exportConfig(): ConfigType {
    return {
      type: this.currentThemeState.config.type,
      colorScheme: this.currentThemeState.config.colorScheme
    };
  }

  /**
   * 导入主题配置 (从持久化恢复)
   */
  importConfig(config:ConfigType): void {
    const type = Object.values(ThemeType).find(t => t === config.type) || ThemeType.LIGHT;
    const scheme = Object.values(ColorScheme).find(s => s === config.colorScheme) || ColorScheme.DEFAULT;
    this.setTheme(type, scheme);
  }
}

// 导出单例实例，方便直接导入使用
export const themeManager = ThemeManager.getInstance();
