import { Vec2, Vec3 } from "@kit.ArkGraphics3D";

export interface CalTransformParams {
  fovy: number;           // 相机垂直视场角 (弧度)
  cameraDistance: number;  // 相机到平面中心的距离 (像素)
  rotation: Vec3,             // 平面组件的旋转角度 (弧度)
  offset: Vec2,                // 平面组件离平面中心的偏移 (像素)
  planeSize?: Size            // 平面尺寸 (像素)，用于计算视差效果
}

export interface PerspectiveFactors{
  scale: number;
  perspectiveBoost: number;
}

/**
 * 透视变换矩阵计算工具
 *
 * 通过相机参数计算变换矩阵，使2D图像具有3D渲染效果
 *
 * 核心原理：
 * 在锥形视图中，屏幕不同位置的物体会有不同的透视变形效果。
 * - 离中心越远的物体，透视倾斜效果越明显
 * - 偏移量会产生"视差倾斜"，叠加到组件自身的旋转上
 *
 * 参数说明：
 * - fovy: 相机垂直视场角 (弧度)
 * - cameraDistance: 相机到平面的距离 (像素)
 * - rotation: 平面组件的旋转角度 {x, y, z} (弧度)
 * - offset: 平面组件离平面中心的偏移 {x, y} (像素)
 * - planeSize: 平面尺寸 {width, height} (像素)
 */
export class PerspectiveTransform {

  /**
   * 根据相机fovy和距离计算透视因子
   */
  static calculatePerspectiveFactor(fovy: number, distance: number): number {
    return Math.tan(fovy / 2) / distance;
  }

  /**
   * 计算相机到平面的最佳距离
   */
  static calculateCameraDistance(fovy: number, planeHeight: number): number {
    return (planeHeight / 2) / Math.tan(fovy / 2);
  }

  /**
   * 计算偏移位置产生的视差倾斜角度
   *
   * 在视锥体中，偏移位置会产生一个自然的倾斜效果：
   * - 相机看向偏移位置的物体时，视线方向会倾斜
   * - 这个倾斜角度取决于偏移量和视锥体的几何关系
   *
   * @param offset 偏移量 {x, y} (像素)
   * @param distance 相机距离 (像素)
   * @param planeSize 平面尺寸
   * @returns 视差倾斜角度 {x, y} (弧度)
   */
  static calculateParallaxTilt(
    offset: Vec2,
    distance: number,
    planeSize: Size
  ): Vec3 {
    // 计算视线方向向量（从相机指向组件）
    // 相机位置: (0, 0, -distance)
    // 组件位置: (offset.x, offset.y, 0)
    // 视线方向 = 组件位置 - 相机位置 = (offset.x, offset.y, distance)

    const dirX = offset.x;
    const dirY = offset.y;
    const dirZ = distance;

    // 计算视线方向的角度
    // 这是相机看向该位置时的自然倾斜
    // X轴倾斜 = atan2(dirY, dirZ) - 从相机看向Y偏移位置时的角度
    // Y轴倾斜 = atan2(dirX, dirZ) - 从相机看向X偏移位置时的角度

    const tiltX = Math.atan2(dirY, dirZ);
    const tiltY = -Math.atan2(dirX, dirZ); // Y轴倾斜方向相反

    return { x: tiltX, y: tiltY, z: 0 };
  }

  /**
   * 计算透视衰减因子
   *
   * 离中心越远，透视效果衰减（物体看起来更小）
   * 同时透视变形更明显
   *
   * @param offset 偏移量
   * @param distance 相机距离
   * @param planeSize 平面尺寸
   * @returns 衰减因子和透视增强因子
   */
  static calculatePerspectiveFactors(
    offset: Vec2,
    distance: number,
    planeSize: Size
  ): PerspectiveFactors {
    // 计算到中心的距离
    const distToCenter = Math.sqrt(offset.x * offset.x + offset.y * offset.y);

    // 计算最大偏移距离（平面边缘）
    const maxOffset = Math.sqrt(
      Math.pow(planeSize.width / 2, 2) +
      Math.pow(planeSize.height / 2, 2)
    );

    // 透视增强因子：边缘位置透视效果更强
    // 线性插值，中心为1，边缘为2
    const perspectiveBoost = 1 + (distToCenter / maxOffset);

    // 缩放因子：边缘位置物体看起来更小（深度差异）
    // 由于偏移位置的z深度相对相机更远
    const actualDepth = Math.sqrt(distToCenter * distToCenter + distance * distance);
    const scale = distance / actualDepth;

    return { scale, perspectiveBoost };
  }

  /**
   * 计算完整的透视变换矩阵
   *
   * 组合以下变换：
   * 1. 视差倾斜（由偏移位置产生）
   * 2. 组件自身旋转
   * 3. 透视投影
   * 4. 平移（偏移位置）
   *
   * @param params 变换参数
   * @returns 4x4变换矩阵数组 (列主序)
   */
  static calculateTransformMatrix(params: CalTransformParams):
    [number, number, number, number,
    number, number, number, number,
    number, number, number, number,
    number, number, number, number] {
    const fovy = params.fovy;
    const cameraDistance = params.cameraDistance;
    const rotation = params.rotation;
    const offset = params.offset;
    const planeSize = params.planeSize;

    // 1. 计算基础透视因子
    const basePerspectiveFactor = PerspectiveTransform.calculatePerspectiveFactor(fovy, cameraDistance);

    // 2. 计算视差倾斜（偏移产生的自然倾斜）
    let parallaxTilt: Vec3 = { x: 0, y: 0, z: 0 };
    let perspectiveBoost = 1;

    if (planeSize) {
      // 视差倾斜：偏移位置产生的视线倾斜
      parallaxTilt = PerspectiveTransform.calculateParallaxTilt(offset, cameraDistance, planeSize);

      // 透视增强：边缘位置透视效果更强
      const factors = PerspectiveTransform.calculatePerspectiveFactors(offset, cameraDistance, planeSize);
      perspectiveBoost = factors.perspectiveBoost;
    }

    // 3. 组合旋转角度：视差倾斜 + 组件自身旋转
    const combinedRotX = rotation.x + parallaxTilt.x;
    const combinedRotY = rotation.y + parallaxTilt.y;
    const combinedRotZ = rotation.z || 0;

    const cosX = Math.cos(combinedRotX);
    const sinX = Math.sin(combinedRotX);
    const cosY = Math.cos(combinedRotY);
    const sinY = Math.sin(combinedRotY);
    const cosZ = Math.cos(combinedRotZ);
    const sinZ = Math.sin(combinedRotZ);

    // 4. 应用透视增强
    const p = basePerspectiveFactor * perspectiveBoost;

    // 5. 计算4x4矩阵（列主序）
    // 组合顺序：P * Rz * Rx * Ry * T

    const m00 = cosY * cosZ + sinX * sinY * sinZ;
    const m01 = -cosX * sinZ;
    const m02 = sinY * cosZ - sinX * cosY * sinZ;
    const m03 = p * m02; // 透视分量

    const m10 = cosY * sinZ - sinX * sinY * cosZ;
    const m11 = cosX * cosZ;
    const m12 = sinY * sinZ + sinX * cosY * cosZ;
    const m13 = p * m12; // 透视分量

    const m20 = -cosX * sinY;
    const m21 = sinX;
    const m22 = cosX * cosY;
    const m23 = p * m22; // 透视分量

    // 平移分量：直接使用偏移量
    const m30 = offset.x;
    const m31 = offset.y;
    const m32 = -cameraDistance;
    const m33 = 1;

    return [
      m00, m01, m02, m03,
      m10, m11, m12, m13,
      m20, m21, m22, m23,
      m30, m31, m32, m33
    ];
  }

  /**
   * 简化版：仅考虑偏移视差效果
   *
   * 当组件自身旋转为0时，使用这个方法更简单
   *
   * @param fovy 视场角 (弧度)
   * @param distance 相机距离 (像素)
   * @param offsetX X偏移 (像素)
   * @param offsetY Y偏移 (像素)
   * @param planeWidth 平面宽度 (像素)
   * @param planeHeight 平面高度 (像素)
   * @returns 4x4矩阵
   */
  static calculateOffsetParallaxTransform(
    fovy: number,
    distance: number,
    offsetX: number,
    offsetY: number,
    planeWidth: number,
    planeHeight: number
  ): [number, number, number, number,
    number, number, number, number,
    number, number, number, number,
    number, number, number, number] {
    const planeSize: Size = { width: planeWidth, height: planeHeight };

    // 计算视差倾斜
    const parallaxTilt = PerspectiveTransform.calculateParallaxTilt(
      { x: offsetX, y: offsetY },
      distance,
      planeSize
    );

    // 使用视差倾斜作为旋转角度
    return PerspectiveTransform.calculateTransformMatrix({
      fovy,
      cameraDistance: distance,
      rotation: parallaxTilt,
      offset: { x: offsetX, y: offsetY },
      planeSize
    });
  }

  /**
   * 简化版：仅考虑X轴和Y轴旋转的透视变换
   *
   * 适用于大多数卡片翻转、倾斜效果（忽略偏移视差）
   *
   * @param fovy 视场角 (弧度)
   * @param distance 相机距离 (像素)
   * @param rotateX X轴旋转 (弧度)
   * @param rotateY Y轴旋转 (弧度)
   * @param translateX X偏移 (像素)
   * @param translateY Y偏移 (像素)
   * @returns 4x4矩阵
   */
  static calculateSimpleTransform(
    fovy: number,
    distance: number,
    rotateX: number,
    rotateY: number,
    translateX: number = 0,
    translateY: number = 0
  ): [number, number, number, number,
    number, number, number, number,
    number, number, number, number,
    number, number, number, number] {
    const cosX = Math.cos(rotateX);
    const sinX = Math.sin(rotateX);
    const cosY = Math.cos(rotateY);
    const sinY = Math.sin(rotateY);

    const p = PerspectiveTransform.calculatePerspectiveFactor(fovy, distance);

    const m00 = cosY;
    const m01 = 0;
    const m02 = sinY;
    const m03 = p * sinY;

    const m10 = sinX * sinY;
    const m11 = cosX;
    const m12 = -sinX * cosY;
    const m13 = -p * sinX * cosY;

    const m20 = -cosX * sinY;
    const m21 = sinX;
    const m22 = cosX * cosY;
    const m23 = p * cosX * cosY;

    const m30 = translateX;
    const m31 = translateY;
    const m32 = -distance;
    const m33 = 1;

    return [
      m00, m01, m02, m03,
      m10, m11, m12, m13,
      m20, m21, m22, m23,
      m30, m31, m32, m33
    ];
  }

  /**
   * 度数转弧度
   */
  static degToRad(degrees: number): number {
    return degrees * Math.PI / 180;
  }

  /**
   * 弧度转度数
   */
  static radToDeg(radians: number): number {
    return radians * 180 / Math.PI;
  }

  /**
   * 预设效果
   */
  static cardFlip(angle: number, fovy: number = 60, distance: number = 1000): number[] {
    return PerspectiveTransform.calculateSimpleTransform(
      PerspectiveTransform.degToRad(fovy),
      distance,
      0,
      PerspectiveTransform.degToRad(angle)
    );
  }

  static cardTilt(tiltX: number, tiltY: number, fovy: number = 60, distance: number = 1000): number[] {
    return PerspectiveTransform.calculateSimpleTransform(
      PerspectiveTransform.degToRad(fovy),
      distance,
      PerspectiveTransform.degToRad(tiltX),
      PerspectiveTransform.degToRad(tiltY)
    );
  }

  /**
   * 网格布局卡片（带视差倾斜）
   *
   * @param gridX X方向网格位置 (-1 到 1)
   * @param gridY Y方向网格位置 (-1 到 1)
   * @param planeWidth 平面宽度
   * @param planeHeight 平面高度
   * @param fovy 视场角 (度)
   * @param distance 相机距离
   */
  static gridCardWithParallax(
    gridX: number,
    gridY: number,
    planeWidth: number,
    planeHeight: number,
    fovy: number = 60,
    distance: number = 1000
  ): [number, number, number, number,
    number, number, number, number,
    number, number, number, number,
    number, number, number, number] {
    // 将网格位置转换为像素偏移
    const offsetX = gridX * (planeWidth / 2);
    const offsetY = gridY * (planeHeight / 2);

    return PerspectiveTransform.calculateOffsetParallaxTransform(
      PerspectiveTransform.degToRad(fovy),
      distance,
      offsetX,
      offsetY,
      planeWidth,
      planeHeight
    );
  }

  static gridCard(
    gridX: number,
    gridY: number,
    maxTilt: number = 15,
    fovy: number = 60,
    distance: number = 1000
  ): number[] {
    const tiltX = -gridY * maxTilt;
    const tiltY = gridX * maxTilt;

    return PerspectiveTransform.calculateSimpleTransform(
      PerspectiveTransform.degToRad(fovy),
      distance,
      PerspectiveTransform.degToRad(tiltX),
      PerspectiveTransform.degToRad(tiltY)
    );
  }
}

/**
 * 3D相机配置接口
 */
export interface Camera3DConfig {
  fovy: number;
  distance: number;
  planeSize: Size;
}

/**
 * 3D变换参数接口
 */
export interface Transform3DParams {
  rotateX: number;
  rotateY: number;
  rotateZ?: number;
  translateX: number;
  translateY: number;
}

/**
 * 透视变换矩阵构建器
 */
export class PerspectiveMatrixBuilder {
  private config: Camera3DConfig = {
    fovy: 60,
    distance: 1000,
    planeSize: { width: 800, height: 600 }
  };

  private transform: Transform3DParams = {
    rotateX: 0,
    rotateY: 0,
    rotateZ: 0,
    translateX: 0,
    translateY: 0
  };

  private enableParallax: boolean = true;

  setCamera(fovy: number, distance: number, planeWidth: number, planeHeight: number): PerspectiveMatrixBuilder {
    this.config.fovy = fovy;
    this.config.distance = distance;
    this.config.planeSize = { width: planeWidth, height: planeHeight };
    return this;
  }

  setRotation(x: number, y: number, z?: number): PerspectiveMatrixBuilder {
    this.transform.rotateX = x;
    this.transform.rotateY = y;
    this.transform.rotateZ = z ?? 0;
    return this;
  }

  setTranslation(x: number, y: number): PerspectiveMatrixBuilder {
    this.transform.translateX = x;
    this.transform.translateY = y;
    return this;
  }

  /**
   * 启用/禁用视差效果
   * 启用后，偏移位置会产生自然的透视倾斜
   */
  setParallax(enabled: boolean): PerspectiveMatrixBuilder {
    this.enableParallax = enabled;
    return this;
  }

  build(): [number, number, number, number,
    number, number, number, number,
    number, number, number, number,
    number, number, number, number] {
    if (this.enableParallax) {
      // 使用完整变换（带视差）
      return PerspectiveTransform.calculateTransformMatrix({
        fovy: PerspectiveTransform.degToRad(this.config.fovy),
        cameraDistance: this.config.distance,
        rotation: {
          x: PerspectiveTransform.degToRad(this.transform.rotateX),
          y: PerspectiveTransform.degToRad(this.transform.rotateY),
          z: PerspectiveTransform.degToRad(this.transform.rotateZ ?? 0)
        },
        offset: {
          x: this.transform.translateX,
          y: this.transform.translateY
        },
        planeSize: this.config.planeSize
      });
    } else {
      // 使用简化变换（无视差）
      return PerspectiveTransform.calculateSimpleTransform(
        PerspectiveTransform.degToRad(this.config.fovy),
        this.config.distance,
        PerspectiveTransform.degToRad(this.transform.rotateX),
        PerspectiveTransform.degToRad(this.transform.rotateY),
        this.transform.translateX,
        this.transform.translateY
      );
    }
  }

  reset(): PerspectiveMatrixBuilder {
    this.transform = {
      rotateX: 0,
      rotateY: 0,
      rotateZ: 0,
      translateX: 0,
      translateY: 0
    };
    this.enableParallax = true;
    return this;
  }
}