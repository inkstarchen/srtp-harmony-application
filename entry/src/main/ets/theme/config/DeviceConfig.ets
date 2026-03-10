/**
 * 设备配置定义
 * 定义支持的设备类型和设备识别逻辑
 */

import { display } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * 设备类型枚举
 */
export enum DeviceType {
  PHONE = 'phone',           // 手机
  TABLET = 'tablet',         // 平板
  DESKTOP = 'desktop',       // 桌面设备 (2in1)
  UNKNOWN = 'unknown'        // 未知设备
}

/**
 * 屏幕尺寸分类
 */
export enum ScreenSizeCategory {
  COMPACT = 'compact',       // 紧凑型 (< 600vp)
  MEDIUM = 'medium',         // 中等型 (600vp - 840vp)
  EXPANDED = 'expanded'      // 扩展型 (> 840vp)
}

/**
 * 设备信息接口
 */
export interface DeviceInfo {
  type: DeviceType;                    // 设备类型
  screenSize: ScreenSizeCategory;      // 屏幕尺寸分类
  screenWidth: number;                 // 屏幕宽度 (vp)
  screenHeight: number;                // 屏幕高度 (vp)
  pixelRatio: number;                  // 像素密度比
  isCompact: boolean;                  // 是否为紧凑屏幕
  isMedium: boolean;                   // 是否为中等屏幕
  isExpanded: boolean;                 // 是否为扩展屏幕
}

/**
 * 屏幕尺寸断点 (单位：vp)
 */
export interface ScreenBreakPoints {
  COMPACT_MAX: number;
  MEDIUM_MIN: number;
  MEDIUM_MAX: number;
  EXPANDED_MIN: number;
}

export const SCREEN_BREAKPOINTS:ScreenBreakPoints = {
  COMPACT_MAX: 600,      // 紧凑屏幕最大值
  MEDIUM_MIN: 600,       // 中等屏幕最小值
  MEDIUM_MAX: 840,       // 中等屏幕最大值
  EXPANDED_MIN: 840      // 扩展屏幕最小值
};

/**
 * 设备适配器管理类
 * 提供设备识别和分类功能
 */
export class DeviceAdapterManager {
  /**
   * 获取屏幕尺寸分类
   */
  static getScreenSizeCategory(screenWidth: number): ScreenSizeCategory {
    if (screenWidth < SCREEN_BREAKPOINTS.COMPACT_MAX) {
      return ScreenSizeCategory.COMPACT;
    } else if (screenWidth < SCREEN_BREAKPOINTS.EXPANDED_MIN) {
      return ScreenSizeCategory.MEDIUM;
    } else {
      return ScreenSizeCategory.EXPANDED;
    }
  }

  /**
   * 识别设备类型
   * 注：实际项目中可能需要通过 systemCapability 或其他 API 判断
   */
  static identifyDeviceType(): DeviceType {
    let deviceString = deviceInfo.deviceType;
    switch (deviceString) {
      case deviceInfo.DeviceTypes.TYPE_PHONE:
        return DeviceType.PHONE;
      case deviceInfo.DeviceTypes.TYPE_TABLET:
        return DeviceType.TABLET;
      case deviceInfo.DeviceTypes.TYPE_2IN1:
        return DeviceType.DESKTOP
      case deviceInfo.DeviceTypes.TYPE_TV:
      case deviceInfo.DeviceTypes.TYPE_WEARABLE:
      case deviceInfo.DeviceTypes.TYPE_WEARABLE:
      case deviceInfo.DeviceTypes.TYPE_DEFAULT:
      default:
        return DeviceType.UNKNOWN
    }
  }

  /**
   * 获取完整的设备信息
   */
  static getDeviceInfo(
    screenWidth: number,
    screenHeight: number,
    pixelRatio: number = 1
  ): DeviceInfo {
    const screenSize = DeviceAdapterManager.getScreenSizeCategory(screenWidth);
    const deviceType =  DeviceAdapterManager.identifyDeviceType();

    return {
      type: deviceType,
      screenSize,
      screenWidth,
      screenHeight,
      pixelRatio,
      isCompact: screenSize === ScreenSizeCategory.COMPACT,
      isMedium: screenSize === ScreenSizeCategory.MEDIUM,
      isExpanded: screenSize === ScreenSizeCategory.EXPANDED
    };
  }

  /**
   * 从系统显示获取设备信息
   */
  static getDeviceInfoFromSystem(deviceTypeList: string[] = ['phone']): DeviceInfo {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      const width = displayInfo.width;
      const height = displayInfo.height;
      // 假设 px 到 vp 的转换，实际项目中可能需要根据密度调整
      const widthVp = width;
      const heightVp = height;

      return DeviceAdapterManager.getDeviceInfo(widthVp, heightVp, displayInfo.densityDPI );
    } catch (e) {
      console.error(`[DeviceAdapter] Failed to get display info: ${e}`);
      // 返回默认手机设备信息
      return DeviceAdapterManager.getDeviceInfo(393, 873, 3);
    }
  }
}
