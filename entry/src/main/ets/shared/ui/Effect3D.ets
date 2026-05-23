import { matrix4 } from '@kit.ArkUI'

/**
 * 构建倾斜变换矩阵
 */
export function getTiltMatrix(rx:number,ry:number,perspective:number): matrix4.Matrix4Transit {

  // 旋转矩阵计算
  const cosX = Math.cos(rx)
  const sinX = Math.sin(rx)
  const cosY = Math.cos(ry)
  const sinY = Math.sin(ry)

  // 透视因子
  const p = 1 / perspective

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
  const m32 = -400
  const m33 = 1

  return matrix4.init([
    m00, m01, m02, m03,
    m10, m11, m12, m13,
    m20, m21, m22, m23,
    m30, m31, m32, m33
  ])
}
