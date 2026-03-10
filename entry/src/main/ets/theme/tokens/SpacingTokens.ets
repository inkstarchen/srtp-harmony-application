/**
 * 间距设计令牌
 * 定义统一的间距系统，确保界面一致性
 */

import { ScreenSizeCategory } from '../config/DeviceConfig';
import { BreakpointUtils } from '../config/BreakpointsConfig';

/**
 * 间距令牌接口
 */
export interface SpacingTokens {
  xs: number;   // 4vp - 超小间距
  sm: number;   // 8vp - 小间距
  md: number;   // 16vp - 中间距
  lg: number;   // 24vp - 大间距
  xl: number;   // 32vp - 超大间距
  xxl: number;  // 48vp - 特大间距
  xxxl: number; // 64vp - 巨大间距
}

/**
 * 默认间距令牌 (基于 4px 网格系统)
 */
export const DEFAULT_SPACING: SpacingTokens = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
  xxxl: 64
};

/**
 * 响应式间距配置
 * 不同屏幕尺寸下的间距缩放
 */
export interface ResponsiveSpacing {
  compact: SpacingTokens;
  medium: SpacingTokens;
  expanded: SpacingTokens;
}

/**
 * 响应式间距令牌
 * 在小屏幕上适当缩小间距
 */
export const RESPONSIVE_SPACING: ResponsiveSpacing = {
  compact: {
    xs: 4,
    sm: 6,
    md: 12,
    lg: 16,
    xl: 20,
    xxl: 24,
    xxxl: 32
  },
  medium: DEFAULT_SPACING,
  expanded: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 56,
    xxxl: 80
  }
};

/**
 * 间距工具类
 */
export class SpacingUtils {

}
