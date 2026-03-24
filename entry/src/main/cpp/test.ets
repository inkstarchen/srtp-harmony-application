import { matrix4 } from '@kit.ArkUI';

@Entry
@Component
struct TiltCard {
  // 卡片尺寸
  private cardWidth: number = 300
  private cardHeight: number = 400

  // 当前旋转角度（弧度）
  @State rotateX: number = 0
  @State rotateY: number = 0

  // 最大倾斜角度（度数）
  private maxTilt: number = 15

  // 透视距离
  private perspective: number = 1000

  build() {
    Column() {
      Column() {
        Text('倾斜卡片')
          .fontSize(24)
          .fontColor(Color.White)
        Text('点击卡片任意位置')
          .fontSize(14)
          .fontColor(Color.White)
          .margin({ top: 10 })
      }
      .width(this.cardWidth)
      .height(this.cardHeight)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#4A90D9')
      .borderRadius(16)
      .shadow({ radius: 20, color: '#40000000', offsetX: 0, offsetY: 10 })
      // 应用3D变换矩阵
      .transform(this.getTiltMatrix())
      // 触摸事件处理
      .onTouch((event: TouchEvent) => {
        this.handleTouch(event)
      })
      // 添加过渡动画
      .animation({
        duration: 150,
        curve: Curve.EaseOut
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F0F0F0')
  }

  /**
   * 处理触摸事件
   */
  private handleTouch(event: TouchEvent) {
    const touchX = event.touches[0].x
    const touchY = event.touches[0].y

    // 计算相对于卡片中心的偏移（-1 到 1）
    const centerX = this.cardWidth / 2
    const centerY = this.cardHeight / 2

    const offsetX = (touchX - centerX) / centerX  // -1 到 1
    const offsetY = (touchY - centerY) / centerY  // -1 到 1

    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      // 触摸按下或移动时，计算倾斜角度
      // 注意：Y轴偏移影响X轴旋转，X轴偏移影响Y轴旋转
      this.rotateX = -offsetY * this.degToRad(this.maxTilt)  // 反转Y使上方向上倾斜
      this.rotateY = offsetX * this.degToRad(this.maxTilt)
    } else if (event.type === TouchType.Up) {
      // 触摸抬起时，恢复原位
      this.rotateX = 0
      this.rotateY = 0
    }
  }

  /**
   * 构建倾斜变换矩阵
   */
  private getTiltMatrix(): Matrix4 {
    const rx = this.rotateX
    const ry = this.rotateY

    // 旋转矩阵计算
    const cosX = Math.cos(rx)
    const sinX = Math.sin(rx)
    const cosY = Math.cos(ry)
    const sinY = Math.sin(ry)

    // 透视因子
    const p = 1 / this.perspective

    // 组合旋转矩阵：先Y轴旋转，再X轴旋转，加入透视
    // 矩阵乘法：RotateX * RotateY * Perspective
    // 简化后的矩阵参数
    const m00 = cosY
    const m01 = 0
    const m02 = sinY
    const m03 = p * sinY

    const m10 = sinX * sinY
    const m11 = cosX
    const m12 = -sinX * cosY
    const m13 = -p * sinX * cosY

    const m20 = -cosX * sinY
    const m21 = sinX
    const m22 = cosX * cosY
    const m23 = p * cosX * cosY

    const m30 = 0
    const m31 = 0
    const m32 = 0
    const m33 = 1

    return matrix4.init([
      m00, m01, m02, m03,
      m10, m11, m12, m13,
      m20, m21, m22, m23,
      m30, m31, m32, m33
    ])
  }

  /**
   * 角度转弧度
   */
  private degToRad(deg: number): number {
    return deg * Math.PI / 180
  }
}