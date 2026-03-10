/**
 * 响应式断点配置
 * 定义不同屏幕尺寸下的布局规则
 */

import { ScreenSizeCategory, SCREEN_BREAKPOINTS } from './DeviceConfig';

/**
 * 断点配置接口
 */
export interface BreakpointConfig {
  minVp?: number;          // 最小 vp 值
  maxVp?: number;          // 最大 vp 值
  columns: number;         // 网格列数
  gutter: number;          // 网格间距
  margin: number;          // 页面边距
}

/**
 * 各断点的默认配置
 */
export const BREAKPOINT_CONFIGS: Record<ScreenSizeCategory, BreakpointConfig> = {
  [ScreenSizeCategory.COMPACT]: {
    minVp: 0,
    maxVp: SCREEN_BREAKPOINTS.COMPACT_MAX,
    columns: 4,
    gutter: 16,
    margin: 16
  },
  [ScreenSizeCategory.MEDIUM]: {
    minVp: SCREEN_BREAKPOINTS.MEDIUM_MIN,
    maxVp: SCREEN_BREAKPOINTS.MEDIUM_MAX,
    columns: 8,
    gutter: 24,
    margin: 24
  },
  [ScreenSizeCategory.EXPANDED]: {
    minVp: SCREEN_BREAKPOINTS.EXPANDED_MIN,
    columns: 12,
    gutter: 24,
    margin: 32
  }
};

/**
 * 组件尺寸断点配置
 * 定义不同屏幕尺寸下组件的推荐尺寸
 */
export interface SizeConfig{
  compact: number;
  medium: number;
  expanded: number ;
}

export interface FontSizeConfig {
  title: SizeConfig;
  body: SizeConfig;
  caption: SizeConfig;
}

export interface ComponentSizeConfig {
  buttonHeight: SizeConfig;
  cardPadding: SizeConfig;
  fontSize: FontSizeConfig;
  iconSize: SizeConfig;
}

/**
 * 默认组件尺寸配置
 */
export const DEFAULT_COMPONENT_SIZES: ComponentSizeConfig = {
  buttonHeight: {
    compact: 40,
    medium: 44,
    expanded: 48
  },
  cardPadding: {
    compact: 12,
    medium: 16,
    expanded: 24
  },
  fontSize: {
    title: {
      compact: 20,
      medium: 24,
      expanded: 32
    },
    body: {
      compact: 14,
      medium: 16,
      expanded: 18
    },
    caption: {
      compact: 12,
      medium: 14,
      expanded: 16
    }
  },
  iconSize: {
    compact: 20,
    medium: 24,
    expanded: 28
  }
};

/**
 * 断点工具类
 */
export class BreakpointUtils {
  /**
   * 根据屏幕宽度获取断点配置
   */
  static getBreakpointConfig(screenWidth: number): BreakpointConfig {
    const category = BreakpointUtils.getScreenCategory(screenWidth);
    return BREAKPOINT_CONFIGS[category];
  }

  /**
   * 根据屏幕宽度获取尺寸分类
   */
  static getScreenCategory(screenWidth: number): ScreenSizeCategory {
    if (screenWidth < SCREEN_BREAKPOINTS.COMPACT_MAX) {
      return ScreenSizeCategory.COMPACT;
    } else if (screenWidth < SCREEN_BREAKPOINTS.EXPANDED_MIN) {
      return ScreenSizeCategory.MEDIUM;
    } else {
      return ScreenSizeCategory.EXPANDED;
    }
  }

  /**
   * 获取响应式值
   * 根据屏幕宽度返回对应的值
   */
  static getResponsiveValue<T>(
    screenWidth: number,
    values: SizeConfig
  ): number {
    const category = BreakpointUtils.getScreenCategory(screenWidth);
    switch (category){
      case ScreenSizeCategory.COMPACT:
        return values.compact;
      case ScreenSizeCategory.MEDIUM:
        return values.medium;
      case ScreenSizeCategory.EXPANDED:
        return values.expanded;
    }
  }

  /**
   * 计算网格宽度
   */
  static calculateColumnWidth(
    screenWidth: number,
    span: number = 1
  ): number {
    const config = BreakpointUtils.getBreakpointConfig(screenWidth);
    const availableWidth = screenWidth - (config.margin * 2);
    const columnWidth = availableWidth / config.columns;
    const gutterWidth = (config.gutter * (span - 1)) / span;
    return (columnWidth * span) - gutterWidth;
  }
}
