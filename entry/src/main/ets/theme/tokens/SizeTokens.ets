/**
 * 组件尺寸设计令牌
 * 定义不同设备类型下组件的尺寸规范
 */

import { ScreenSizeCategory } from '../config/DeviceConfig';
import { BreakpointUtils, DEFAULT_COMPONENT_SIZES } from '../config/BreakpointsConfig';

/**
 * 字体令牌接口
 */
export interface TypographyTokens {
  // 字体大小
  fontSizeXS: number;   // 10vp - 超小字体
  fontSizeSM: number;   // 12vp - 小字体
  fontSizeMD: number;   // 14vp - 标准字体
  fontSizeLG: number;   // 16vp - 大字体
  fontSizeXL: number;   // 20vp - 超大字体
  fontSizeXXL: number;  // 24vp - 特大字体
  fontSizeXXXL: number; // 32vp - 巨大字体

  // 字重
  fontWeightLight: number;
  fontWeightRegular: number;
  fontWeightMedium: number;
  fontWeightBold: number;

  // 行高
  lineHeightTight: number;
  lineHeightNormal: number;
  lineHeightRelaxed: number;
}

/**
 * 默认字体令牌
 */
export const DEFAULT_TYPOGRAPHY: TypographyTokens = {
  // 字体大小
  fontSizeXS: 10,
  fontSizeSM: 12,
  fontSizeMD: 14,
  fontSizeLG: 16,
  fontSizeXL: 20,
  fontSizeXXL: 24,
  fontSizeXXXL: 32,

  // 字重 (数值映射：100-900)
  fontWeightLight: 300,
  fontWeightRegular: 400,
  fontWeightMedium: 500,
  fontWeightBold: 700,

  // 行高 (倍数)
  lineHeightTight: 1.2,
  lineHeightNormal: 1.5,
  lineHeightRelaxed: 1.75
};

/**
 * 组件尺寸令牌接口
 */
export interface ComponentSizeTokens {
  // 按钮尺寸
  buttonHeightSmall: number;
  buttonHeightMedium: number;
  buttonHeightLarge: number;
  buttonPaddingHorizontal: number;
  buttonBorderRadius: number;

  // 卡片尺寸
  cardBorderRadius: number;
  cardPaddingSmall: number;
  cardPaddingMedium: number;
  cardPaddingLarge: number;
  cardShadowRadius: number;

  // 输入框尺寸
  inputHeight: number;
  inputBorderRadius: number;
  inputPaddingHorizontal: number;

  // 列表项尺寸
  listItemHeightSmall: number;
  listItemHeightMedium: number;
  listItemHeightLarge: number;

  // 图标尺寸
  iconSizeXS: number;
  iconSizeSM: number;
  iconSizeMD: number;
  iconSizeLG: number;
  iconSizeXL: number;

  // 头像尺寸
  avatarSizeXS: number;
  avatarSizeSM: number;
  avatarSizeMD: number;
  avatarSizeLG: number;
  avatarSizeXL: number;
}

/**
 * 默认组件尺寸令牌
 */
export const DEFAULT_COMPONENT_SIZE: ComponentSizeTokens = {
  // 按钮尺寸
  buttonHeightSmall: 32,
  buttonHeightMedium: 40,
  buttonHeightLarge: 48,
  buttonPaddingHorizontal: 16,
  buttonBorderRadius: 8,

  // 卡片尺寸
  cardBorderRadius: 12,
  cardPaddingSmall: 12,
  cardPaddingMedium: 16,
  cardPaddingLarge: 24,
  cardShadowRadius: 8,

  // 输入框尺寸
  inputHeight: 44,
  inputBorderRadius: 8,
  inputPaddingHorizontal: 12,

  // 列表项尺寸
  listItemHeightSmall: 48,
  listItemHeightMedium: 56,
  listItemHeightLarge: 72,

  // 图标尺寸
  iconSizeXS: 12,
  iconSizeSM: 16,
  iconSizeMD: 20,
  iconSizeLG: 24,
  iconSizeXL: 32,

  // 头像尺寸
  avatarSizeXS: 24,
  avatarSizeSM: 32,
  avatarSizeMD: 40,
  avatarSizeLG: 56,
  avatarSizeXL: 80
};

/**
 * 响应式组件尺寸配置
 */
export interface ResponsiveComponentSizes {
  compact: ComponentSizeTokens;
  medium: ComponentSizeTokens;
  expanded: ComponentSizeTokens;
}

/**
 * 响应式组件尺寸
 * 在不同屏幕尺寸下调整组件大小
 */
export const RESPONSIVE_COMPONENT_SIZES: ResponsiveComponentSizes = {
  // 手机/紧凑屏幕 - 稍小的组件
  compact: {
    buttonHeightSmall: 28,
    buttonHeightMedium: 36,
    buttonHeightLarge: 44,
    buttonPaddingHorizontal: 12,
    buttonBorderRadius: 6,
    cardBorderRadius: 8,
    cardPaddingSmall: 10,
    cardPaddingMedium: 12,
    cardPaddingLarge: 16,
    cardShadowRadius: 6,
    inputHeight: 40,
    inputBorderRadius: 6,
    inputPaddingHorizontal: 10,
    listItemHeightSmall: 44,
    listItemHeightMedium: 52,
    listItemHeightLarge: 64,
    iconSizeXS: 10,
    iconSizeSM: 14,
    iconSizeMD: 18,
    iconSizeLG: 22,
    iconSizeXL: 28,
    avatarSizeXS: 20,
    avatarSizeSM: 28,
    avatarSizeMD: 36,
    avatarSizeLG: 48,
    avatarSizeXL: 64
  },
  // 平板/中等屏幕 - 标准尺寸
  medium: DEFAULT_COMPONENT_SIZE,
  // 桌面/扩展屏幕 - 稍大的组件
  expanded: {
    buttonHeightSmall: 36,
    buttonHeightMedium: 44,
    buttonHeightLarge: 52,
    buttonPaddingHorizontal: 20,
    buttonBorderRadius: 10,
    cardBorderRadius: 16,
    cardPaddingSmall: 16,
    cardPaddingMedium: 20,
    cardPaddingLarge: 28,
    cardShadowRadius: 12,
    inputHeight: 48,
    inputBorderRadius: 10,
    inputPaddingHorizontal: 16,
    listItemHeightSmall: 52,
    listItemHeightMedium: 60,
    listItemHeightLarge: 80,
    iconSizeXS: 14,
    iconSizeSM: 18,
    iconSizeMD: 24,
    iconSizeLG: 28,
    iconSizeXL: 40,
    avatarSizeXS: 28,
    avatarSizeSM: 36,
    avatarSizeMD: 48,
    avatarSizeLG: 64,
    avatarSizeXL: 96
  }
};

