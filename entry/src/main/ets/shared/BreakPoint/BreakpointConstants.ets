
export class BreakpointConstants {
  // 标准断点值 (单位: vp)
  static readonly XS_MAX = 320;
  static readonly SM_MAX = 600;    // 手机
  static readonly MD_MAX = 840;    // 折叠屏/小屏平板
  static readonly LG_MAX = 1440;
  // lg: > 840 (大屏平板/PC)

  // 断点类型枚举
  static readonly TYPE_XS = 'xs';
  static readonly TYPE_SM = 'sm';
  static readonly TYPE_MD = 'md';
  static readonly TYPE_LG = 'lg';
  static readonly TYPE_XL = 'xl';
}