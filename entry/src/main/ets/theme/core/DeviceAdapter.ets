import { DeviceType, ScreenSizeCategory, DeviceInfo, DeviceAdapterManager } from '../config/DeviceConfig';
import { BreakpointConfig, BREAKPOINT_CONFIGS, BreakpointUtils } from '../config/BreakpointsConfig';


/**
 * 设备适配器类（响应式）
 * 不再需要手动订阅，界面绑定 @local 即可自动更新
 */
@ObservedV2
export class DeviceAdapter {
  private static instance: DeviceAdapter;

  /** 当前设备信息，@local 响应式 */
  @Trace currentDeviceInfo: DeviceInfo;

  private isInitialized: boolean = false;

  private constructor() {
    // 默认设备信息
    this.currentDeviceInfo = DeviceAdapterManager.getDeviceInfo(393, 873, 3);
  }

  /** 获取单例 */
  static getInstance(): DeviceAdapter {
    if (!DeviceAdapter.instance) {
      DeviceAdapter.instance = new DeviceAdapter();
    }
    return DeviceAdapter.instance;
  }

  /** 初始化设备信息 */
  initialize(deviceTypeList: string[] = ['phone']): void {
    if (this.isInitialized) return;

    this.refresh(deviceTypeList);

    this.isInitialized = true;
    console.log('[DeviceAdapter] Initialized', this.currentDeviceInfo);
  }

  /** 刷新设备信息 */
  refresh(deviceTypeList: string[] = []): void {
    if (deviceTypeList.length === 0) {
      deviceTypeList = [this.currentDeviceInfo.type];
    }
    const newInfo = DeviceAdapterManager.getDeviceInfoFromSystem(deviceTypeList);

    // 仅在信息变化时更新
    if (this.hasChanged(newInfo)) {
      // 整体替换对象，@local 会触发绑定更新
      this.currentDeviceInfo = newInfo ;
    }
  }

  /** 判断设备信息是否变化 */
  private hasChanged(newInfo: DeviceInfo): boolean {
    const old = this.currentDeviceInfo;
    return (
      old.type !== newInfo.type ||
        old.screenSize !== newInfo.screenSize ||
        Math.abs(old.screenWidth - newInfo.screenWidth) > 1 ||
        Math.abs(old.screenHeight - newInfo.screenHeight) > 1
    );
  }

  /** -------- 响应式 getter -------- */

  get deviceInfo(): DeviceInfo { return this.currentDeviceInfo; }
  get deviceType(): DeviceType { return this.currentDeviceInfo.type; }
  get screenSizeCategory(): ScreenSizeCategory { return this.currentDeviceInfo.screenSize; }
  get screenWidth(): number { return this.currentDeviceInfo.screenWidth; }
  get screenHeight(): number { return this.currentDeviceInfo.screenHeight; }

  get isPhone(): boolean { return this.currentDeviceInfo.type === DeviceType.PHONE; }
  get isTablet(): boolean { return this.currentDeviceInfo.type === DeviceType.TABLET; }
  get isDesktop(): boolean { return this.currentDeviceInfo.type === DeviceType.DESKTOP; }

  get isCompact(): boolean { return this.currentDeviceInfo.isCompact; }
  get isMedium(): boolean { return this.currentDeviceInfo.isMedium; }
  get isExpanded(): boolean { return this.currentDeviceInfo.isExpanded; }

  get breakpointConfig(): BreakpointConfig {
    return BREAKPOINT_CONFIGS[this.currentDeviceInfo.screenSize];
  }


  getResponsiveFontSize(baseSize: number): number {
    const scale = this.isCompact ? 0.9 : this.isExpanded ? 1.1 : 1;
    return Math.round(baseSize * scale);
  }

  getColumnWidth(span: number = 1): number {
    return BreakpointUtils.calculateColumnWidth(this.currentDeviceInfo.screenWidth, span);
  }

  getPageMargin(): number {
    return BreakpointUtils.getBreakpointConfig(this.currentDeviceInfo.screenWidth).margin;
  }

  getGutter(): number {
    return BreakpointUtils.getBreakpointConfig(this.currentDeviceInfo.screenWidth).gutter;
  }

  getColumns(): number {
    return BreakpointUtils.getBreakpointConfig(this.currentDeviceInfo.screenWidth).columns;
  }
}

// 导出单例实例
export const deviceAdapter = DeviceAdapter.getInstance();