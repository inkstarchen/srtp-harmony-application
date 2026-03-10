/**
 * 主题 Hook
 * 在组件中便捷地使用主题
 *
 * 使用方式:
 * 在 ComponentV2 中:
 * @Local theme = useTheme(this);
 * build() {
 *   Text('Hello').fontColor(this.theme.getColor('primary'))
 * }
 */

import { ThemeManager, ThemeState} from '../core/ThemeManager';
import { ColorTokens } from '../tokens/ColorTokens';
import { SpacingTokens } from '../tokens/SpacingTokens';
import { ComponentSizeTokens } from '../tokens/SizeTokens';
import { TypographyTokens } from '../tokens/SizeTokens';

/**
 * 主题 Hook 类
 * 封装主题相关的常用方法
 */
export class UseThemeHook {
  private subscriberId: number | null = null;
  private currentThemeState: ThemeState;
  private onChange: ((theme: ThemeState) => void) | null = null;

  constructor() {
    this.currentThemeState = ThemeManager.getInstance().getThemeState();
  }

  /**
   * 初始化 Hook
   * 应在组件的 aboutToAppear 中调用
   * @param component 组件实例 (this)
   * @param callback 可选的回调函数，在主题变化时执行自定义逻辑
   */
  init(callback?: (theme: ThemeState) => void): void {


  }

  /**
   * 销毁 Hook
   * 应在组件的 aboutToDisappear 中调用
   */
  destroy(): void {
  }

  /**
   * 获取当前主题状态
   */
  get theme(): ThemeState {
    return this.currentThemeState;
  }

  /**
   * 获取颜色令牌
   */
  get colors(): ColorTokens {
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
  get sizes(): ComponentSizeTokens {
    return this.currentThemeState.componentSizes;
  }

  /**
   * 获取字体令牌
   */
  get typography(): TypographyTokens {
    return this.currentThemeState.typography;
  }


  /**
   * 判断是否为深色模式
   */
  get isDark(): boolean {
    return this.currentThemeState.isDark;
  }

  /**
   * 获取主色
   */
  get primaryColor(): string {
    return this.currentThemeState.tokens.primary;
  }

  /**
   * 获取背景色
   */
  get backgroundColor(): string {
    return this.currentThemeState.tokens.background;
  }

  /**
   * 获取表面色
   */
  get surfaceColor(): string {
    return this.currentThemeState.tokens.surface;
  }
}

/**
 * useTheme 工厂函数
 * 创建并返回一个主题 Hook 实例
 *
 * 使用示例:
 * @ComponentV2
 * export struct MyComponent {
 *   theme = useTheme();
 *
 *   aboutToAppear() {
 *     this.theme.init(this);
 *   }
 *
 *   aboutToDisappear() {
 *     this.theme.destroy();
 *   }
 *
 *   build() {
 *     Text('Hello').fontColor(this.theme.getColor('primary'))
 *   }
 * }
 */
export function useTheme(): UseThemeHook {
  return new UseThemeHook();
}


