#ifndef SHADERS__COMMON__BASE_BLOCKS_H
#define SHADERS__COMMON__BASE_BLOCKS_H

/**
 * Constructs a vec4 color of floats. You can alternatively use attached literal on an input port.
 *
 * @displayName Construct Color (Vec4)
 * @in r - red component of the color (vec4.x)
 * @in g - green component of the color (vec4.y)
 * @in b - blue component of the color (vec4.z)
 * @in a - alpha component of the color (vec4.w)
 * @out color - Vec4 color output
 */
void ColorVec4Block(in float r, in float g, in float b, in float a, out vec4 outVec)
{
    outVec = vec4(r, g, b, a);
}

/**
 * Constructs a vec3 color of floats. You can alternatively use an attached literal on an input port.
 *
 * @displayName Construct Color (Vec3)
 * @in r - red component of the color (vec3.x)
 * @in g - green component of the color (vec3.y)
 * @in b - blue component of the color (vec3.z)
 * @out color - Vec3 color output
 */
void ColorVec3Block(in float x, in float y, in float z, out vec3 outVec)
{
    outVec = vec3(x, y, z);
}

/**
 * Samples a texture with the provided sampler2D at the given UV coordinates.
 *
 * @displayName Sample Texture with Sampler
 * @in UV coords - UV coordinates to sample from.
 * @in sampler - Combined image sampler for fetching a value.
 * @out color - Vec4 sampled value at the given UV coordinates.
 */
void ImageSampleVec4Block(in vec2 inUv, in sampler2D inSampler, out vec4 outColor)
{
    outColor = texture(inSampler, inUv);
}

/**
 * The binormal vector of the current fragment that is perpendicular to the tangent vector and the normal vector.
 * Also referred as the bitangent.
 *
 * @displayName Binormal
 * @out B - The binormal vector perpendicular to the normal and the tangent.
 */
void BinormalBlock(out vec3 outBinormal)
{
    const vec3 normNormal = normalize(inNormal.xyz);
    const vec3 tangent = normalize(inTangentW.xyz);
    outBinormal = normalize(cross(normNormal, tangent.xyz) * inTangentW.w);
}

/**
 * Provides the size of the viewport in pixels.
 *
 * @displayName Viewport Size
 * @out size - The size of the viewport in pixels.
 */
void ViewportSizeBlock(out vec2 outViewportSize)
{
    outViewportSize = GetUnpackViewport(uGeneralData).xy;
}

/**
 * Provides whether the current fragment is facing the camera.
 *
 * @displayName Is Front Facing
 * @out front facing - Whether the current fragment is facing the camera.
 */
void FrontFacingBlock(out bool outFrontFacing)
{
    outFrontFacing = gl_FrontFacing;
}

/**
 * Computes the Fresnel term for a material using Schlick's approximation based on the given
 * F0 reflectance and VoH value.
 *
 * @displayName Fresnel Calculation
 * @in f0 - The base reflectance (F0) of the material as a vec3.
 * @in VoH - The dot product between the view direction and the half vector as a float.
 * @out outFresnel - The output vec3 containing the calculated Fresnel term.
 */
void FresnelBlock(in vec3 f0, in float VoH, out vec3 outFresnel)
{
    outFresnel = f0 + (1.0 - f0) * pow(1.0 - VoH, 5.0);
}

/**
 * Converts an RGB color to HSV. All components are in the range [0, 1].
 *
 * @displayName RGB to HSV
 * @in rgb - The RGB color to convert.
 * @out hsv - The HSV color.
 */
void Rgb2HsvBlock(in vec3 rgbColor, out vec3 hsvColor)
{
    const vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    const vec4 p = mix(vec4(rgbColor.bg, K.wz), vec4(rgbColor.gb, K.xy), step(rgbColor.b, rgbColor.g));
    const vec4 q = mix(vec4(p.xyw, rgbColor.r), vec4(rgbColor.r, p.yzx), step(p.x, rgbColor.r));

    const float d = q.x - min(q.w, q.y);
    const float e = 1.0e-10;
    hsvColor = vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

/**
 * Converts an HSV color to RGB. All components are in the range [0, 1].
 *
 * @displayName HSV to RGB
 * @in hsv - The HSV color to convert.
 * @out rgb - The RGB color.
 */
void Hsv2RgbBlock(in vec3 hsvColor, out vec3 rgbColor)
{
    const vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    const vec3 p = abs(fract(hsvColor.xxx + K.xyz) * 6.0 - K.www);
    rgbColor = hsvColor.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsvColor.y);
}

#endif // SHADERS__COMMON__BASE_BLOCKS_H
