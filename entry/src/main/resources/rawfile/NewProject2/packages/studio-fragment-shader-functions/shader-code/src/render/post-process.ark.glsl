
#ifndef SHADERS__COMMON__POST_PROCESS_BLOCKS_H
#define SHADERS__COMMON__POST_PROCESS_BLOCKS_H

#include "render/shaders/common/render_post_process_structs_common.h"
#include "render/shaders/common/render_tonemap_common.h"
#include "render/shaders/common/render_color_conversion_common.h"

#define CORE_CLAMP_MAX_VALUE 64512.0

/**
 * Applies a tone mapping effect on the color. todo write more about this
 *
 * @displayName Tone Mapping
 * @in flags - Post process flags (contains tone map enable flag)
 * @in factor - Tonemap factor (.x = exposure, .w type) todo shouldn't this be a float and a uint instead of a vec4?
 * @in color - Input color
 * @out mapped color - output color of the tone-mapping
 */
void PostProcessTonemapBlock(in uint postProcessFlags, in vec4 tonemapFactor, in vec3 inCol, out vec3 outCol)
{
    outCol = inCol;
    if ((postProcessFlags & POST_PROCESS_SPECIALIZATION_TONEMAP_BIT) == POST_PROCESS_SPECIALIZATION_TONEMAP_BIT) {
        const float exposure = tonemapFactor.x;
        const vec3 x = outCol * exposure;
        const uint tonemapType = uint(tonemapFactor.w);
        if (tonemapType == CORE_POST_PROCESS_TONEMAP_ACES) {
            outCol = TonemapAces(x);
        } else if (tonemapType == CORE_POST_PROCESS_TONEMAP_ACES_2020) {
            outCol = TonemapAcesFilmRec2020(x);
        } else if (tonemapType == CORE_POST_PROCESS_TONEMAP_FILMIC) {
            const float exposureEstimate = 6.0f;
            outCol = TonemapFilmic(x * exposureEstimate);
        }
    }
}

/**
 * Applies vignette to a color.
 *
 * @displayName Vignette
 * @in flags - Post process flags (contains vignette enable flag)
 * @in factor - Vignette factor (.x = coefficient, .y = pow) Values in the range [0, 1]
 *              todo maybe change to vec2 or separate variables?
 * @in UV coords - UV coordinates
 * @in color - Input color
 * @out color - The result color after applying the vignette effect
 */
void PostProcessVignetteBlock(
    in uint postProcessFlags, in vec4 vignetteFactor, in vec2 uv, in vec3 inCol, out vec3 outCol)
{
    outCol = inCol;
    if ((postProcessFlags & POST_PROCESS_SPECIALIZATION_VIGNETTE_BIT) == POST_PROCESS_SPECIALIZATION_VIGNETTE_BIT) {
        const vec2 uvVal = uv.xy * (vec2(1.0) - uv.yx);
        // TODO: coefficient 40 baked into factor .x ?
        CORE_RELAXEDP float vignette = uvVal.x * uvVal.y * vignetteFactor.x * 40.0;
        vignette = clamp(pow(vignette, vignetteFactor.y), 0.0, 1.0);
        outCol.rgb *= vignette;
    }
}

/**
 * A chromatic aberration post-process block that applies color fringing to the input image based on the provided chroma
 * factors. The function adds red and blue color fringes to the input color, creating a chromatic aberration effect. The
 * strength and distance scaling of the effect are controlled by the chromaFactor parameter.
 *
 * @displayName Chromatic Aberration
 * @in postProcessFlags - Flags containing post-process settings, including the chromatic aberration enable flag.
 * @in chromaFactor - A vec4 representing chromatic aberration factors (.x = chroma strength, .y = chroma distance
 * scaling factor).
 * @in uv - The texture coordinates for sampling the image.
 * @in uv size - The size of the texture in UV space (width, height) as a vec2.
 * @in sampler - The sampler2D containing the input image to be processed.
 * @in color  - The color at the given texture coordinates. Its green channel will be used. Todo do we need this? Maybe
 *                                                                                           we could sample inside?
 * @out color - The output vec3 color with chromatic aberration applied.
 */
void PostProcessColorFringeBlock(in uint postProcessFlags, in vec4 chromaFactor, in vec2 uv, in vec2 uvSize,
    in sampler2D imgSampler, in vec3 inCol, out vec3 outCol)
{
    outCol = inCol;
    if ((postProcessFlags & POST_PROCESS_SPECIALIZATION_COLOR_FRINGE_BIT) !=
        POST_PROCESS_SPECIALIZATION_COLOR_FRINGE_BIT) {
        return;
    }
    // this is cheap chroma
    const vec2 distUv = (uv - 0.5) * 2.0;
    const CORE_RELAXEDP float chroma = dot(distUv, distUv) * chromaFactor.y * chromaFactor.x;

    const vec2 uvDistToImageCenter = chroma * uvSize;
    const CORE_RELAXEDP float chromaRed =
        texture(imgSampler, uv - vec2(uvDistToImageCenter.x, uvDistToImageCenter.y)).x;
    const CORE_RELAXEDP float chromaBlue =
        texture(imgSampler, uv + vec2(uvDistToImageCenter.x, uvDistToImageCenter.y)).z;

    outCol.r = chromaRed;
    outCol.b = chromaBlue;
}

/**
 * Applies a dither effect to the input color.
 *
 * Dithering is a technique that can be used to simulate a higher color bit depth by introducing random noise to smooth
 * out color transitions between neighboring pixels.
 *
 * @displayName Dither
 * @in flags - Post process flags (contains dither enable flag)
 * @in dither factors - Dither factors (.x = amount, .y = uvx coeff, .xz = uvy coeff)
 * @in uv - The XY coordinates where we are applying the effect
 * @in input color - Input color
 * @out output color - Vec3 output color of operation
 */
void PostProcessDitherBlock(in uint postProcessFlags, in vec4 ditherFactor, in vec2 uv, in vec3 inCol, out vec3 outCol)
{
    outCol = inCol;
    if (!((postProcessFlags & POST_PROCESS_SPECIALIZATION_DITHER_BIT) == POST_PROCESS_SPECIALIZATION_DITHER_BIT)) {
        return;
    }
    const vec2 random01Range = vec2(uv.x * ditherFactor.y, uv.y * ditherFactor.z);
    outCol += fract(sin(dot(random01Range.xy, vec2(12.9898, 78.233))) * 43758.5453) * ditherFactor.x;
}

/**
 * A post-process block that performs color space conversion based on the provided color conversion options.
 * The function will support different types of color space conversions, determined by the conversionType parameter.
 * Currently, it only supports linear-to-sRGB conversion.
 *
 * @displayName Color Space Conversion
 * @in flags - Post process flags, including the color space conversion enable flag
 * (POST_PROCESS_SPECIALIZATION_COLOR_CONVERSION_BIT).
 * @in options - A vec4 representing color conversion options (.w = conversion type). Todo maybe refactor this to single
 * attribute
 * @in color - The input vec3 color in the original color space.
 * @out color - The output vec3 color after the color space conversion has been applied.
 */
void PostProcessColorConversionBlock(
    in uint postProcessFlags, in vec4 colorConversionFactor, in vec3 inCol, out vec3 outCol)
{
    outCol = inCol;
    if ((postProcessFlags & POST_PROCESS_SPECIALIZATION_COLOR_CONVERSION_BIT) ==
        POST_PROCESS_SPECIALIZATION_COLOR_CONVERSION_BIT) {
        const uint conversionType = uint(colorConversionFactor.w);
        if (conversionType == CORE_POST_PROCESS_COLOR_CONVERSION_SRGB) {
            outCol.rgb = LinearToSrgb(outCol.rgb);
        }
    }
}

/**
 * Applies a bloom effect on the given color. todo write more about this, what are the types, how does it look, how do
 *                                            the parameters affect it, etc.
 *
 * @displayName Bloom Combine
 * @in flags - Post process flags, including the bloom combine enable flag (POST_PROCESS_SPECIALIZATION_BLOOM_BIT).
 * @in bloom factors - A vec4 representing bloom factors (.z = bloom color strength, .w = dirt strength).
 * @in uv - The coordinates where we are applying the effect
 * @in bloom combined sampler - A sampler2D for the bloom combined image. todo rename / rephrase / add details
 * @in dirt map combined sampler - A sampler2D for the dirt map combined image.
 * @in color - The input color.
 * @out color - The output color after the bloom combine has been applied.
 */
void PostProcessBloomCombineBlock(in uint postProcessFlags, in vec4 bloomFactor, in vec2 uv, in sampler2D imgSampler,
    in sampler2D dirtImgSampler, in vec3 inCol, out vec3 outCol)
{
    outCol = inCol;
    if ((postProcessFlags & POST_PROCESS_SPECIALIZATION_BLOOM_BIT) == POST_PROCESS_SPECIALIZATION_BLOOM_BIT) {
        // NOTE: lower resolution, more samples might be needed
        const vec3 bloomColor = texture(imgSampler, uv).rgb * bloomFactor.z;
        const vec3 dirtColor = texture(dirtImgSampler, uv).rgb * bloomFactor.w;
        const vec3 bloomCombine = outCol + bloomColor + dirtColor * max(bloomColor.x, max(bloomColor.y, bloomColor.z));
        outCol.rgb = min(bloomCombine, CORE_CLAMP_MAX_VALUE);
    }
}

#endif // SHADERS__COMMON__POST_PROCESS_BLOCKS_H
