/**
 * 设备 Hook
 * 在组件中便捷地使用设备信息
 *
 * 使用方式:
 * @ComponentV2
 * export struct MyComponent {
 *   device = useDevice();
 *
 *   aboutToAppear() {
 *     this.device.init(this);
 *   }
 *
 *   build() {
 *     if (this.device.isTablet) {
 *       // 平板布局
 *     }
 *   }
 * }
 */

import { DeviceAdapter } from '../core/DeviceAdapter';
import { DeviceInfo, DeviceType, ScreenSizeCategory } from '../config/DeviceConfig';
import { BreakpointConfig } from '../config/BreakpointsConfig';

/**
 * 设备 Hook 类
 * 封装设备信息相关的常用方法
 */
export class UseDeviceHook {
  private subscriberId: number | null = null;
  private currentDeviceInfo: DeviceInfo;
  private onChange: ((deviceInfo: DeviceInfo) => void) | undefined = undefined;

  constructor() {
    this.currentDeviceInfo = DeviceAdapter.getInstance().deviceInfo;
  }

  /**
   * 初始化 Hook
   * 应在组件的 aboutToAppear 中调用
   */
  init(callback?: (deviceInfo: DeviceInfo) => void): void {
  }

  /**
   * 销毁 Hook
   * 应在组件的 aboutToDisappear 中调用
   */
  destroy(): void {
  }

  /**
   * 获取当前设备信息
   */
  get device(): DeviceInfo {
    return this.currentDeviceInfo;
  }

  /**
   * 获取设备类型
   */
  get deviceType(): DeviceType {
    return this.currentDeviceInfo.type;
  }

  /**
   * 获取屏幕尺寸分类
   */
  get screenSize(): ScreenSizeCategory {
    return this.currentDeviceInfo.screenSize;
  }

  /**
   * 获取屏幕宽度
   */
  get screenWidth(): number {
    return this.currentDeviceInfo.screenWidth;
  }

  /**
   * 获取屏幕高度
   */
  get screenHeight(): number {
    return this.currentDeviceInfo.screenHeight;
  }

  /**
   * 判断是否为手机
   */
  get isPhone(): boolean {
    return this.currentDeviceInfo.type === DeviceType.PHONE;
  }

  /**
   * 判断是否为平板
   */
  get isTablet(): boolean {
    return this.currentDeviceInfo.type === DeviceType.TABLET;
  }

  /**
   * 判断是否为桌面设备
   */
  get isDesktop(): boolean {
    return this.currentDeviceInfo.type === DeviceType.DESKTOP;
  }

  /**
   * 判断是否为紧凑屏幕
   */
  get isCompact(): boolean {
    return this.currentDeviceInfo.isCompact;
  }

  /**
   * 判断是否为中等屏幕
   */
  get isMedium(): boolean {
    return this.currentDeviceInfo.isMedium;
  }

  /**
   * 判断是否为扩展屏幕
   */
  get isExpanded(): boolean {
    return this.currentDeviceInfo.isExpanded;
  }

  /**
   * 获取断点配置
   */
  get breakpoint(): BreakpointConfig {
    return {
      columns: this.currentDeviceInfo.isCompact ? 4 :
               this.currentDeviceInfo.isMedium ? 8 : 12,
      gutter: this.currentDeviceInfo.isCompact ? 16 : 24,
      margin: this.currentDeviceInfo.isCompact ? 16 :
              this.currentDeviceInfo.isMedium ? 24 : 32
    };
  }


  /**
   * 获取响应式字体大小
   */
  fontSize(baseSize: number): number {
    return DeviceAdapter.getInstance().getResponsiveFontSize(baseSize);
  }

  /**
   * 计算网格列宽度
   */
  columnWidth(span: number = 1): number {
    return DeviceAdapter.getInstance().getColumnWidth(span);
  }
}

/**
 * useDevice 工厂函数
 */
export function useDevice(): UseDeviceHook {
  return new UseDeviceHook();
}

/**
 * 便捷设备信息获取函数
 */
export function deviceInfo(): DeviceInfo {
  return DeviceAdapter.getInstance().deviceInfo;
}

/**
 * 判断是否为指定设备类型
 */
export function isDeviceType(type: DeviceType): boolean {
  return DeviceAdapter.getInstance().deviceType === type;
}

/**
 * 判断是否为指定屏幕尺寸
 */
export function isScreenSize(size: ScreenSizeCategory): boolean {
  return DeviceAdapter.getInstance().screenSizeCategory === size;
}
