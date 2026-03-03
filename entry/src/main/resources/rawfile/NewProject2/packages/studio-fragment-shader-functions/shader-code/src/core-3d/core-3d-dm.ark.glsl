#ifndef SHADERS__COMMON__CORE3D_DM_BLOCKS_H
#define SHADERS__COMMON__CORE3D_DM_BLOCKS_H

// #include "render/shaders/common/render_post_process_blocks.h"
#include "studio-fragment-shader-functions/render/post-process.h"

#include "3d/shaders/common/3d_dm_structures_common.h"
#include "3d/shaders/common/3d_dm_inplace_sampling_common.h"
#include "3d/shaders/common/3d_dm_lighting_common.h"
#include "3d/shaders/common/3d_dm_shadowing_common.h"
#include "3d/shaders/common/3d_dm_target_packing_common.h"
#include "3d/shaders/common/3d_dm_inplace_fog_common.h"

#define BLOCK_EPSILON 0.0001

// Needs to be included after the descriptor set descriptions
/// Default Material BRDF
struct DefaultMaterialBrdfDataStruct {
    /// Material f0
    CORE_RELAXEDP vec4 f0;

    /// Material diffuse color
    /// @displayName diffuse color
    CORE_RELAXEDP vec3 diffuseColor;

    /// Material roughness
    /// @displayName roughness
    CORE_RELAXEDP float roughness;

    /// @displayName alpha^2
    CORE_RELAXEDP float alpha2;

    /// Shading normal
    /// @displayName normal
    vec3 normal;
};

/*
 * (DEPRECATED) GetFragInstanceIndex free function
 */
uint GetFragInstanceIndex()
{
    uint instanceIdx = 0U;
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_GPU_INSTANCING_BIT) == CORE_MATERIAL_GPU_INSTANCING_BIT) {
        instanceIdx = GetUnpackFlatIndicesInstanceIdx(inIndices);
    }
    return instanceIdx;
}

/*
 * GetMaterialFragInstanceIndex free function
 */
uint GetMaterialFragInstanceIndex()
{
    return GetMaterialInstanceIndex(inIndices);
}

/**
 * Provides time information for the scene.
 *
 * @displayName Time Info
 * @out scence Δt - Scene delta time (ms). todo clarify/confirm
 * @out tick Δt - Tick delta time (ms). todo clarfiy/confirm
 * @out elapsed time - Tick total time (s).
 * @out frame count - Frame index. (todo clarify - starts at 0 or 1?)
 */
void SceneTimeBlock(out float sceneDeltaTime, out float tickDeltaTime, out float tickTotalTime, out uint frameIndex)
{
    sceneDeltaTime = uGeneralData.sceneTimingData.x;
    tickDeltaTime = uGeneralData.sceneTimingData.y;
    tickTotalTime = uGeneralData.sceneTimingData.z;
    frameIndex = floatBitsToUint(uGeneralData.sceneTimingData.w);
}

/**
 * @displayName Color Output
 * @in color - Final color output of this shader graph.
 */
void OutputColorBlock(in vec4 color = vec4(0, 0, 0, 1))
{
    outColor = color;
    // multiply with alpha
    outColor.rgb = clamp(outColor.rgb * outColor.a, 0.0, CORE_HDR_FLOAT_CLAMP_MAX_VALUE);
}

/**
 * @displayName Velocity and Normal Output
 * @in worldPos - Current world position.
 * @in prevWorldPos - Previous frame world position.
 * @in normal - Per pixel normal.
 */
void OutputVelocityAndNormalBlock(
    in vec3 worldPos = vec3(0, 0, 0), in vec3 prevWorldPos = vec3(0, 0, 0), in vec3 normal = vec3(0, 0, 0))
{
    outVelocityNormal = GetPackVelocityAndNormal(GetFinalCalculatedVelocity(worldPos.xyz, prevWorldPos.xyz), normal);
}

/**
 * The coordinates of the current fragment (gl_FragCoord)
 *
 * @displayName Fragment Coordinates
 * @out coordinates - gl_FragCoord.
 */
void FragCoordBlock(out vec4 outFragCoord)
{
    outFragCoord = gl_FragCoord;
}

/**
 * Todo write clarifying description
 *
 * @displayName Screen UV
 * @out UV coordinates - UV coordinates of current screen/viewport.
 */
void ScreenUvBlock(out vec2 outUv)
{
    CORE_GET_FRAGCOORD_UV(outUv, gl_FragCoord.xy, uGeneralData.viewportSizeInvViewportSize.zw);
}

/**
 * World position of the current fragment.
 *
 * @displayName World Position
 * @out position - World position of the current fragment.
 */
void WorldPositionBlock(out vec3 outPos)
{
    outPos = inPos;
}

/**
 * World position of the current fragment.
 *
 * @displayName Input World Position
 * @out position - World position of the current fragment.
 */
void InputWorldPositionBlock(out vec3 outPos)
{
    outPos = inPos;
}

/**
 * Previous frame world position of the current fragment.
 * Can be used e.g. to calculate velocity from the current frame world position.
 *
 * @displayName Input Previous World Position
 * @out previous position - Previous frame world position of the current fragment.
 */
void InputPrevWorldPositionBlock(out vec3 outPrevPos)
{
    outPrevPos = inPrevPosI.xyz;
}

/**
 * Get instance index of the current (sub)mesh.
 *
 * @displayName Input instance index
 * @out instance index - Instance index.
 */
void InputInstanceIndexBlock(out uint outInstanceIdx)
{
    outInstanceIdx = 0U;
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_GPU_INSTANCING_BIT) == CORE_MATERIAL_GPU_INSTANCING_BIT) {
        outInstanceIdx = GetUnpackFlatIndicesInstanceIdx(inIndices);
    }
}

/**
 * UV channels 0 and 1.
 *
 * @displayName Input UVs
 * @out UV - Vec4 of two UVs, .xy = UV0, .zw = UV1.
 */
void InputUvBlock(out vec4 outUv)
{
    outUv = inUv;
}

/**
 * Fragment shader color input.
 *
 * @displayName Input Color
 * @out color - Vec4 of color.
 */
void InputColorBlock(out vec4 outVec)
{
    outVec = inColor;
}

/**
 * A vector with length 1 pointing in a direction perpendicular to the surface.
 * Fragment shader normal input.
 *
 * @displayName Input Normal
 * @out normal - Vec3 of normal.
 */
void InputNormalBlock(out vec3 outVec)
{
    outVec = inNormal.xyz;
}

/**
 * Fragment shader tangent input.
 *
 * @displayName Input Tangent
 * @out tangent - Vec4 of tangent.
 */
void InputTangentBlock(out vec4 outVec)
{
    outVec = inTangentW;
}

/**
 * The direction of the ray from the camera to the current fragment.
 *
 * @displayName Camera View Direction
 * @out direction - Vec3 normalized camera view direction.
 */
void CameraViewDirBlock(out vec3 outCamDir)
{
    const uint cameraIdx = GetUnpackCameraIndex();
    const vec3 camPos = uCameras[cameraIdx].viewInv[3].xyz;
    outCamDir = normalize(inPos - camPos.xyz);
}

/**
 * Return vec4 of material texture info slot. todo improve description and add where the factor comes from
 *
 * @displayName Material Texture Slot
 * @in texture slot - Slot index of material texture info.
 * @out texture sample - The output vec4 containing the sampled texture color with applied factor.
 */
void MaterialTextureInfoSlotBlock(in uint materialIndexSlot, out vec4 outCol)
{
    const uint maxCount = min(materialIndexSlot, CORE_MATERIAL_SAMPTEX_COUNT);
    const uint texCoordInfoBit = (1 << maxCount);
    const uint texCoordIdx = maxCount + CORE_MATERIAL_PACK_TEX_BASE_COLOR_UV_IDX;
    const vec2 uv = GetFinalSamplingUV(inUv, texCoordInfoBit, texCoordIdx);
    const vec4 factor = GetUnpackMaterialTextureInfoSlotFactor(maxCount, GetMaterialFragInstanceIndex());
    // NOTE: baseColor is on its own for automatic hwbuffer/oes support
    if (maxCount == 0) {
        outCol = texture(uSampTextureBase, uv) * factor;
    } else {
        outCol = texture(uSampTextures[maxCount - 1], uv) * factor;
    }
}

/**
 * Sample material slot texture with given uv
 *
 * @displayName Sampled Material Texture Slot
 * @in texture sampler - Slot index of material texture info.
 * @in UV coords - UV coordinates for sampling.
 * @out sample - Sampled texture with given UVs.
 */
void MaterialTextureInfoSlotSampleBlock(in uint materialIndexSlot, in vec2 uv, out vec4 outCol)
{
    const uint maxCount = min(materialIndexSlot, CORE_MATERIAL_SAMPTEX_COUNT);
    // NOTE: baseColor is on its own for automatic hwbuffer/oes support
    if (maxCount == 0) {
        outCol = texture(uSampTextureBase, uv);
    } else {
        outCol = texture(uSampTextures[maxCount - 1], uv);
    }
}

/**
 * Sample material slot normal texture with given uv
 *
 * @displayName Sampled Material Normal Texture Slot
 * @in texture slot - Slot index of material texture info.
 * @in UV coords - UV coordinates for sampling.
 * @out Normal - Sampled normal from tangent space.
 */
void MaterialTextureInfoSlotSampleNormalBlock(in uint materialIndexSlot, in vec2 uv, out vec3 outNor)
{
    const uint maxCount = min(materialIndexSlot, CORE_MATERIAL_SAMPTEX_COUNT);
    // NOTE: baseColor is on its own for automatic hwbuffer/oes support
    const vec4 factor = GetUnpackMaterialTextureInfoSlotFactor(maxCount, GetMaterialFragInstanceIndex());
    if (maxCount == 0) {
        outNor = texture(uSampTextureBase, uv).rgb * factor.xyz;
    } else {
        outNor = texture(uSampTextures[maxCount - 1], uv).rgb * factor.xyz;
    }
    outNor = normalize(2.0 * outNor - 1.0);
    const vec3 normNormal = normalize(inNormal.xyz);
    const vec3 theTangent = normalize(inTangentW.xyz);
    const vec3 theBitangent = cross(normNormal.xyz, theTangent.xyz) * inTangentW.w;
    const mat3 tbn = mat3(theTangent.xyz, theBitangent.xyz, normNormal.xyz);
    outNor = normalize(tbn * outNor);

    outNor = gl_FrontFacing ? outNor : -outNor;
}

/**
 * Todo write description
 *
 * @displayName Material Texture Slot Factor
 * @in texture slot - [0] Slot index of material texture info.
 * @out factor - Vec4 factor of material texture info.
 */
void MaterialTextureInfoSlotFactorBlock(in uint materialIndexSlot, out vec4 outFactor)
{
    const uint maxCount = min(materialIndexSlot, CORE_MATERIAL_SAMPTEX_COUNT);
    outFactor = GetUnpackMaterialTextureInfoSlotFactor(maxCount, GetMaterialFragInstanceIndex());
}

/**
 * Get material texture info slot uv (TODO: improve description)
 *
 * @displayName Material Texture Slot UV
 * @in texture slot - [0] Slot index of material texture info.
 * @out UV - Vec2 UV coordinates.
 */
void MaterialTextureInfoSlotUvBlock(in uint materialIndexSlot, out vec2 outUv)
{
    const uint maxCount = min(materialIndexSlot, CORE_MATERIAL_SAMPTEX_COUNT);
    const uint texCoordInfoBit = (1 << maxCount);
    const uint texCoordIdx = maxCount + CORE_MATERIAL_PACK_TEX_BASE_COLOR_UV_IDX;
    outUv = GetFinalSamplingUV(inUv, texCoordInfoBit, texCoordIdx);
}

/**
 * Provides total elapsed time from the start of the scene.
 *
 * @displayName Elapsed Time
 * @out t - Tick total time in seconds.
 */
void ElapsedTimeBlock(out float totalTimeInSeconds)
{
    totalTimeInSeconds = uGeneralData.sceneTimingData.z;
}

/**
 * Performs default base color sampling and handling for a material.
 * - Discards fragments based on alpha cutoff.
 * - Handles opaque materials with 1.0 alpha.
 *
 * @displayName Base Color Sampler
 * @out base color - The output vec4 containing the calculated base color.
 */
void BaseColorSampleBlock(out vec4 baseColor)
{
    // NOTE: blend mode opaque alpha should be 1.0 from this calculation
    const uint instanceIdx = GetFragInstanceIndex();
    baseColor = GetBaseColorSample(inUv) * GetUnpackBaseColor(instanceIdx) * inColor;
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_ADDITIONAL_SHADER_DISCARD_BIT) ==
        CORE_MATERIAL_ADDITIONAL_SHADER_DISCARD_BIT) {
        if (baseColor.a < GetUnpackAlphaCutoff(instanceIdx)) {
            discard;
        }
    }
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_OPAQUE_BIT) == CORE_MATERIAL_OPAQUE_BIT) {
        baseColor.a = 1.0;
    } else {
        baseColor = Unpremultiply(baseColor);
    }
}

/**
 * Todo write more helpful description
 * Default normals sampling and handling block.
 * Handles normal and clearcoat normal.
 * The values are returned vec3 values.
 *
 * @displayName Sampled Normals
 * @out normal - The output vec3 containing the calculated normal.
 * @out clearcoat normal - The output vec3 containing the calculated clearcoat normal.
 */
void NormalsSampleBlock(out vec3 normal, out vec3 clearcoatNormal)
{
    const vec3 normNormal = normalize(inNormal.xyz);
    normal = normNormal;
    clearcoatNormal = normNormal;
    // clear coat normal is calculated if normal_map_bit and if clearcoat_bit
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_NORMAL_MAP_BIT) == CORE_MATERIAL_NORMAL_MAP_BIT) {
        vec3 normalSample = GetNormalSample(inUv);
        const float normalScale = GetUnpackNormalScale(GetMaterialFragInstanceIndex());
        normalSample = normalize((2.0 * normalSample - 1.0) * vec3(normalScale, normalScale, 1.0f));
        const vec3 tangent = normalize(inTangentW.xyz);
        const vec3 bitangent = cross(normNormal, tangent.xyz) * inTangentW.w;
        const mat3 tbn = mat3(tangent.xyz, bitangent.xyz, normNormal);
        normal = normalize(tbn * normalSample);
        if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_CLEARCOAT_BIT) == CORE_MATERIAL_CLEARCOAT_BIT) {
            vec3 ccNormalSample = GetClearcoatNormalSample(inUv);
            // cc normal scale not yet supported
            ccNormalSample = normalize((2.0 * ccNormalSample - 1.0));
            clearcoatNormal = normalize(tbn * ccNormalSample);
        }
    }

    // NOTE: clearcoat normal should be front-facing as well?
    // if no backface culling we flip automatically
    normal = gl_FrontFacing ? normal : -normal;
}

/**
 * Performs material sampling and handling for a given base color and polygon normal, and outputs the computed BRDF
 * (Bidirectional Reflectance Distribution Function) values in a struct.
 *
 * @displayName Material BRDF Sampling and Handling
 * @in base color - Base color.
 * @in normal - Polygon normal of the object
 * @out brdf - the computed BRDF (Bidirectional Reflectance Distribution Function) values
 */
void MaterialSampleBlock(
    in vec4 baseColor = vec4(1, 1, 1, 1), in vec3 polygonNormal = vec3(0, 1, 0), out DefaultMaterialBrdfDataStruct bd)
{
    vec4 uv = inUv;
    const uint instanceIdx = GetMaterialFragInstanceIndex();
    const CORE_RELAXEDP vec4 material = GetMaterialSample(uv) * GetUnpackMaterial(instanceIdx);
    bd.normal = polygonNormal;
    InputBrdfData brdfData;
    if (CORE_MATERIAL_TYPE == CORE_MATERIAL_SPECULAR_GLOSSINESS) {
        brdfData = CalcBRDFSpecularGlossiness(baseColor, polygonNormal, material);
    } else if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_SPECULAR_BIT) == CORE_MATERIAL_SPECULAR_BIT) {
        const CORE_RELAXEDP vec4 specular = GetSpecularSample(inUv, instanceIdx) * GetUnpackSpecular(instanceIdx);
        brdfData = CalcBRDFSpecular(baseColor, polygonNormal, material, specular);
    } else {
        brdfData = CalcBRDFMetallicRoughness(baseColor, polygonNormal, material);
    }
    bd.f0 = brdfData.f0;
    bd.diffuseColor = brdfData.diffuseColor;
    bd.roughness = brdfData.roughness;
    bd.alpha2 = brdfData.alpha2;
    bd.normal = polygonNormal;
}

vec3 GetIrradianceSample(const vec3 worldNormal)
{
    const vec3 worldNormalEnv = mat3(uEnvironmentData.envRotation) * worldNormal;
    return unpackIblIrradianceSH(worldNormalEnv, uEnvironmentData.shIndirectCoefficients) *
        uEnvironmentData.indirectDiffuseColorFactor.rgb;
}

float GetLodForRadianceSample(const float roughness)
{
    return uEnvironmentData.values.x * roughness;
}

vec3 GetRadianceSample(const vec3 worldReflect, const float roughness)
{
    const CORE_RELAXEDP float cubeLod = GetLodForRadianceSample(roughness);
    const vec3 worldReflectEnv = mat3(uEnvironmentData.envRotation) * worldReflect;
    return unpackIblRadiance(textureLod(uSampRadiance, worldReflectEnv, cubeLod)) *
        uEnvironmentData.indirectSpecularColorFactor.rgb;
}

/*
 * Obtains a transmission radiance sample based on the given fragment UVs, world reflection direction, and roughness.
 *
 * This function first tries to fetch a color from a pre-pass texture based on the given fragment UVs and
 * level-of-detail (LOD) derived from the roughness. If the alpha component of this color is below a threshold (0.5), it
 * falls back to sampling the environment using the provided world reflection direction and roughness.
 *
 * Note: The default texture used for the pre-pass is assumed to be black with zero alpha. If the alpha is below the
 * threshold (0.5), it's assumed that the pre-pass color is essentially "transparent" or "unavailable", and therefore
 * the environment should be sampled directly.
 *
 * @param fragUv The UV coordinates for the fragment.
 * @param worldReflect The world reflection direction vector.
 * @param roughness Surface roughness, determines the level of detail for sampling the radiance.
 * @return The RGB transmission radiance sample.
 */
vec3 GetTransmissionRadianceSample(const vec2 fragUv, const vec3 worldReflect, const float roughness)
{
    // NOTE: this makes a pre color selection based on alpha
    // we would generally need an extra flag, the default texture is black with alpha zero
    const CORE_RELAXEDP float lod = GetLodForRadianceSample(roughness);
    vec4 color = textureLod(uSampColorPrePass, fragUv, lod).rgba;
    if (color.a < 0.5f) {
        // sample environment if the default pre pass color was 0.0 alpha
        color.rgb = GetRadianceSample(worldReflect, roughness);
    }
    return color.rgb;
}

/**
 * Indirect lighting block with brdf and base color input.
 *
 * @displayName Indirect Lighting
 * @in brdf - BRDF data (Bidirectional Reflectance Distribution Function)
 * @in color - Base color to be lit
 * @out color - Lit color
 */
void IndirectLightingBlock(in DefaultMaterialBrdfDataStruct bd, in vec3 color, out vec3 outCol)
{
    outCol = color;
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_INDIRECT_LIGHT_RECEIVER_BIT) ==
        CORE_MATERIAL_INDIRECT_LIGHT_RECEIVER_BIT) {
        const uint cameraIdx = GetUnpackCameraIndex();
        const vec3 camPos = uCameras[cameraIdx].viewInv[3].xyz;

        const vec3 V = normalize(camPos.xyz - inPos);
        const vec3 N = bd.normal;
        const float NoV = clamp(dot(N, V), CORE3D_PBR_LIGHTING_EPSILON, 1.0);

        const CORE_RELAXEDP float ao = clamp(1.0 + GetUnpackAO(GetMaterialFragInstanceIndex()) * (GetAOSample(inUv) - 1.0), 0.0, 1.0);

        // lambert baked into irradianceSample (SH)
        CORE_RELAXEDP
        vec3 irradiance = GetIrradianceSample(N) * bd.diffuseColor * ao;

        const vec3 worldReflect = reflect(-V, N);
        const CORE_RELAXEDP vec3 fIndirect = EnvBRDFApprox(bd.f0.xyz, bd.roughness, NoV);
        // ao applied after clear coat
        CORE_RELAXEDP
        vec3 radianceSample = GetRadianceSample(worldReflect, bd.roughness);
        CORE_RELAXEDP
        vec3 radiance = radianceSample * fIndirect;

// apply ao for indirect specular as well (cheap version)
#if 1
        radiance *= ao * SpecularHorizonOcclusion(worldReflect, inNormal);
#else
        radiance *= EnvSpecularAo(ao, NoV, roughness) * SpecularHorizonOcclusion(worldReflect, inNormal);
#endif

        outCol += (irradiance + radiance);
    }
}

/**
 * Direct lighting block with brdf and base color input.
 *
 * @displayName Direct Lighting
 * @in brdf - BRDF data (Bidirectional Reflectance Distribution Function)
 * @in color - Base color to be lit
 * @out color - Lit color
 */
void DirectLightingBlock(in DefaultMaterialBrdfDataStruct bd, in vec3 color, out vec3 outCol)
{
    outCol = color;
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_PUNCTUAL_LIGHT_RECEIVER_BIT) ==
        CORE_MATERIAL_PUNCTUAL_LIGHT_RECEIVER_BIT) {
        const uint cameraIdx = GetUnpackCameraIndex();
        const vec3 camPos = uCameras[cameraIdx].viewInv[3].xyz;

        const vec3 V = normalize(camPos.xyz - inPos);
        const float NoV = clamp(dot(bd.normal, V), CORE3D_PBR_LIGHTING_EPSILON, 1.0);
        ShadingData shadingData;
        shadingData.pos = inPos.xyz;
        shadingData.N = bd.normal;
        shadingData.NoV = NoV;
        shadingData.V = V;
        shadingData.f0 = bd.f0;
        shadingData.alpha2 = bd.alpha2;
        shadingData.diffuseColor = bd.diffuseColor;

        outCol = CalculateLighting(shadingData, CORE_MATERIAL_FLAGS);
    }
}

bool ValidNormalValue(vec3 normal)
{
    const float maxVal = max(max(abs(normal.x), abs(normal.y)), abs(normal.z));
    return (maxVal > BLOCK_EPSILON) ? true : false;
}

bool ValidClearcoatValue(float val)
{
    return (val > BLOCK_EPSILON) ? true : false;
}

bool ValidSheenValue(float val)
{
    return (val > BLOCK_EPSILON) ? true : false;
}

bool ValidTransmissionValue(float val)
{
    return (val > BLOCK_EPSILON) ? true : false;
}

/**
 * Calculates a lit color using the BRDF lighting model.
 *
 * @displayName BRDF Lighting
 * @in base color - [1, 1, 1] Albedo/Base color. Base color expected to be unpremultiplied with alpha (Base Color Block)
 * @in alpha - [1] Alpha value (0-1).
 * @in alpha cutoff - [1] Float alpha cutoff value (0-1, ignored if 1).
 * @in normal - [0, 0, 0] Vec3 Surface normal (ignored if zero).
 * @in roughness - [1] Roughness value (0-1).
 * @in metallic - [1] Metallic value (0.0f = dielectric, 1.0f = metallic).
 * @in reflectance - [0.04] F0 reflectance (0-1) - the amount of light that bounces back
 *                          when coming from perpendicular to the surface.
 * @in emissive - [0, 0, 0] Emissive (ignored if zero).
 * @in ambient occlusion - [1] Ambient Occlusion (0-1, ignored if 1) - AO value
 * @in clearcoat - [0] Clearcoat value (0-1, ignored if zero).
 * @in clearcoat roughness - [0] Clearcoat roughness value (0-1, ignored if 0)
 * @in clearcoat normal - [0, 0, 0] Clearcoat normal vector (ignored if this or clearcoat is zero).
 * @in transmission - [0] Transmission value (0-1, ignored if zero).
 * @in sheen color - [0, 0, 0] Sheen color (ignored if sheen is zero).
 * @in sheen - [0] Sheen value (0-1, ignored if zero).
 * @in sheen roughness - [0] Sheen roughness value (0-1, ignored if sheen is zero).
 * @in specular - [0, 0, 0, 0] Specular vec4 with strength in alpha (ignored if alpha is zero).
 *
 * @out BRDF - Calculated lit color.
 */
void BRDFBlock(in vec3 baseColor = vec3(1, 1, 1), in float alpha = 1, in float alphaCutoff = 1, in vec3 norm,
    in float roughness = 1, in float metallic = 1, in float reflectance = 0.04, in vec3 emissive, in float ao = 1,
    in float clearcoat, in float clearcoatRoughness, in vec3 clearcoatNormal, in float transmission, in vec3 sheenColor,
    in float sheen, in float sheenRoughness, in vec4 specular, out vec4 outCol)
{
    outCol = vec4(0.0, 0.0, 0.0, alpha);
    // alpha cutoff
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_ADDITIONAL_SHADER_DISCARD_BIT) ==
        CORE_MATERIAL_ADDITIONAL_SHADER_DISCARD_BIT) {
        if (alpha < alphaCutoff) {
            discard;
        }
    }

    // normal
    vec3 N = normalize(inNormal.xyz);
    vec3 normal = normalize(ValidNormalValue(norm) ? norm : N);
    normal = gl_FrontFacing ? normal : -normal;

    // material
    const vec4 material = vec4(0.0, roughness, metallic, reflectance);
    InputBrdfData brdfData;
    // NOTE: does not implement CORE_MATERIAL_SPECULAR_GLOSSINESS
    if (specular.w > BLOCK_EPSILON) {
        brdfData = CalcBRDFSpecular(vec4(baseColor.rgb, alpha), N, material, specular);
    } else {
        brdfData = CalcBRDFMetallicRoughness(vec4(baseColor.rgb, alpha), N, material);
    }

    const uint cameraIdx = GetUnpackCameraIndex();
    const vec3 camPos = uCameras[cameraIdx].viewInv[3].xyz;
    const vec3 V = normalize(camPos.xyz - inPos);
    const float NoV = clamp(dot(normal, V), CORE3D_PBR_LIGHTING_EPSILON, 1.0);

    const bool hasClearcoat = ValidClearcoatValue(clearcoat);
    const bool hasSheen = ValidSheenValue(sheen);
    const bool hasTransmission = ValidTransmissionValue(transmission);

    ClearcoatShadingVariables clearcoatSV;
    if (hasClearcoat) {
        clearcoatSV.cc = clearcoat;
        clearcoatSV.ccRoughness = clearcoatRoughness;
        // geometric correction doesn't behave that well with clearcoat due to it being basically 0 roughness
        clearcoatSV.ccRoughness = clamp(clearcoatSV.ccRoughness, CORE_BRDF_MIN_ROUGHNESS, 1.0);
        CORE_RELAXEDP const float ccAlpha = clearcoatSV.ccRoughness * clearcoatSV.ccRoughness;
        clearcoatSV.ccAlpha2 = ccAlpha * ccAlpha;
        clearcoatSV.ccNormal = normalize(ValidNormalValue(clearcoatNormal) ? clearcoatNormal : N);
    }

    SheenShadingVariables sheenSV;
    if (hasSheen) {
        sheenSV.sheenColor = sheenColor;
        sheenSV.sheenColorMax = max(sheenSV.sheenColor.r, max(sheenSV.sheenColor.g, sheenSV.sheenColor.b));
        sheenSV.sheenRoughness = sheenRoughness;
        sheenSV.sheenBRDFApprox = EnvBRDFApproxSheen(NoV, sheenSV.sheenRoughness * sheenSV.sheenRoughness);
    }

    if (hasTransmission) {
        brdfData.diffuseColor *= (1.0 - transmission);
    }

    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_PUNCTUAL_LIGHT_RECEIVER_BIT) ==
        CORE_MATERIAL_PUNCTUAL_LIGHT_RECEIVER_BIT) {
        ShadingData shadingData;
        shadingData.pos = inPos.xyz;
        shadingData.N = normal;
        shadingData.NoV = NoV;
        shadingData.V = V;
        shadingData.f0 = brdfData.f0;
        shadingData.alpha2 = brdfData.alpha2;
        shadingData.diffuseColor = brdfData.diffuseColor;
        uint materialFlags = CORE_MATERIAL_FLAGS;
        materialFlags |= (hasClearcoat) ? CORE_MATERIAL_CLEARCOAT_BIT : 0;
        materialFlags |= (hasSheen) ? CORE_MATERIAL_SHEEN_BIT : 0;
        materialFlags |= (hasTransmission) ? CORE_MATERIAL_TRANSMISSION_BIT : 0;

        outCol.rgb += CalculateLighting(shadingData, clearcoatSV, sheenSV, materialFlags);
    }
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_INDIRECT_LIGHT_RECEIVER_BIT) ==
        CORE_MATERIAL_INDIRECT_LIGHT_RECEIVER_BIT) {
        // lambert baked into irradianceSample (SH)
        CORE_RELAXEDP vec3 irradiance = GetIrradianceSample(normal) * brdfData.diffuseColor * ao;

        const vec3 worldReflect = reflect(-V, normal);
        const CORE_RELAXEDP vec3 fIndirect = EnvBRDFApprox(brdfData.f0.xyz, brdfData.roughness, NoV);
        // ao applied after clear coat
        CORE_RELAXEDP vec3 radianceSample = GetRadianceSample(worldReflect, brdfData.roughness);
        CORE_RELAXEDP vec3 radiance = radianceSample * fIndirect;

        if (hasSheen) {
            AppendIndirectSheen(sheenSV, radianceSample, alpha, irradiance, radiance);
        }
        if (hasClearcoat) {
            const vec3 ccWorldReflect = reflect(-V, clearcoatSV.ccNormal);
            const vec3 ccRadianceSample = GetRadianceSample(ccWorldReflect, clearcoatSV.ccRoughness);
            AppendIndirectClearcoat(clearcoatSV, ccRadianceSample, alpha, V, irradiance, radiance);
        }
        if (hasTransmission) {
            vec2 fragUv;
            CORE_GET_FRAGCOORD_UV(fragUv, gl_FragCoord.xy, uGeneralData.viewportSizeInvViewportSize.zw);
            // NOTE: ATM use direct refract (no sphere mapping)
            const vec3 rr = -V; // refract(-V, N, 1.0 / ior);
            const CORE_RELAXEDP vec3 transmissionRadianceSample =
                GetTransmissionRadianceSample(fragUv, rr, brdfData.roughness);

            AppendIndirectTransmission(transmissionRadianceSample, baseColor.rgb, transmission, irradiance);
        }
        // apply ao for indirect specular as well (cheap version)
#if 1
        radiance *= ao * SpecularHorizonOcclusion(worldReflect, N);
#else
        radiance *= EnvSpecularAo(ao, NoV, brdfData.roughness) * SpecularHorizonOcclusion(worldReflect, N);
#endif

        outCol.rgb += (irradiance + radiance);
    }
    outCol.rgb += emissive;

    InplaceFogBlock(CORE_CAMERA_FLAGS, inPos.xyz, camPos.xyz, vec4(outCol.rgb, alpha), outCol.rgb);
}

/**
 * todo write description
 *
 * @displayName Anisotropic BRDF Lighting
 * @in base color - [1, 1, 1] Albedo/Base color.
 * @in alpha - [1] Alpha value (0-1).
 * @in alpha cutoff - [1] Alpha cutoff value (0-1, ignored if 1).
 * @in normal - [0, 0, 0] Normal (ignored if zero).
 * @in roughness - [1] Roughness value (0-1).
 * @in metallic - [1] Metallic value (0-1).
 * @in reflectance - [0.04] Reflectance (F0)
 * @in emissive - [0, 0, 0] Emissive (ignored if zero).
 * @in ambient occlusion - [1] Ambient occlusion value (0-1, ignored if 1).
 * @in clearcoat - [0] Clearcoat value (0-1, ignored if zero).
 * @in clearcoat roughness - [0] Clearcoat roughness value (0-1, ignored if clearcoat is zero).
 * @in clearcoat normal - [0, 0, 0] Clearcoat normal (ignored if zero or clearcoat is zero).
 * @in transmission - [0] Transmission value (0-1, ignored if zero).
 * @in sheen color - [0, 0, 0] Sheen color (ignored if sheen is zero).
 * @in sheen - [0] Sheen value (0-1, ignored if zero).
 * @in sheen roughness - [0] Sheen roughness value (0-1, ignored if sheen is zero).
 * @in specular - [0, 0, 0, 0] Specular vec4 with strength in alpha (ignored if alpha is zero).
 * @in anisotropy - [0] Anisotropy value (-1…1).
 * @in anisotropic direction - [0, 0, 0] Anisotropic direction vec3 (-1…1).
 *
 * @out color - Calculated lit color.
 */
void BRDFAnisotropicBlock(in vec3 baseColor = vec3(1, 1, 1), in float alpha = 1.0, in float alphaCutoff = 1.0,
    in vec3 norm, in float roughness = 1, in float metallic = 1, in float reflectance = 0.04, in vec3 emissive,
    in float ao = 1, in float clearcoat, in float clearcoatRoughness, in vec3 clearcoatNormal, in float transmission,
    in vec3 sheenColor, in float sheen, in float sheenRoughness, in vec4 specular, in float anisotropy,
    in vec3 anisotropyDir, out vec4 outCol)
{
    outCol = vec4(0.0, 0.0, 0.0, alpha);
    // alpha cutoff
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_ADDITIONAL_SHADER_DISCARD_BIT) ==
        CORE_MATERIAL_ADDITIONAL_SHADER_DISCARD_BIT) {
        if (alpha < alphaCutoff) {
            discard;
        }
    }

    // normal
    vec3 normal = normalize(ValidNormalValue(norm) ? norm : inNormal);
    normal = gl_FrontFacing ? normal : -normal;

    // material
    const vec4 material = vec4(0.0, roughness, metallic, reflectance);
    InputBrdfData brdfData;
    // NOTE: does not implement CORE_MATERIAL_SPECULAR_GLOSSINESS
    if (specular.w > BLOCK_EPSILON) {
        brdfData = CalcBRDFSpecular(vec4(baseColor.rgb, alpha), inNormal, material, specular);
    } else {
        brdfData = CalcBRDFMetallicRoughness(vec4(baseColor.rgb, alpha), inNormal, material);
    }

    const uint cameraIdx = GetUnpackCameraIndex();
    const vec3 camPos = uCameras[cameraIdx].viewInv[3].xyz;
    const vec3 V = normalize(camPos.xyz - inPos);
    const float NoV = clamp(dot(normal, V), CORE3D_PBR_LIGHTING_EPSILON, 1.0);

    const bool hasClearcoat = ValidClearcoatValue(clearcoat);
    const bool hasSheen = ValidSheenValue(sheen);
    const bool hasTransmission = ValidTransmissionValue(transmission);

    ClearcoatShadingVariables clearcoatSV;
    if (hasClearcoat) {
        clearcoatSV.cc = clearcoat;
        clearcoatSV.ccRoughness = clearcoatRoughness;
        // geometric correction doesn't behave that well with clearcoat due to it being basically 0 roughness
        clearcoatSV.ccRoughness = clamp(clearcoatSV.ccRoughness, CORE_BRDF_MIN_ROUGHNESS, 1.0);
        CORE_RELAXEDP const float ccAlpha = clearcoatSV.ccRoughness * clearcoatSV.ccRoughness;
        clearcoatSV.ccAlpha2 = ccAlpha * ccAlpha;
        clearcoatSV.ccNormal = normalize(ValidNormalValue(clearcoatNormal) ? clearcoatNormal : inNormal);
    }

    SheenShadingVariables sheenSV;
    if (hasSheen) {
        sheenSV.sheenColor = sheenColor;
        sheenSV.sheenColorMax = max(sheenSV.sheenColor.r, max(sheenSV.sheenColor.g, sheenSV.sheenColor.b));
        sheenSV.sheenRoughness = sheenRoughness;
        sheenSV.sheenBRDFApprox = EnvBRDFApproxSheen(NoV, sheenSV.sheenRoughness * sheenSV.sheenRoughness);
    }

    if (hasTransmission) {
        brdfData.diffuseColor *= (1.0 - transmission);
    }

    AnisotropicShadingVariables asv;
    {
        const vec3 normNormal = normalize(inNormal.xyz);
        const vec3 tangent = normalize(inTangentW.xyz);
        const vec3 bitangent = cross(normNormal, tangent.xyz) * inTangentW.w;
        const mat3 tbn = mat3(tangent.xyz, bitangent.xyz, normNormal);

        asv.roughness = brdfData.roughness;
        asv.alpha = asv.roughness * asv.roughness;
        asv.anisotropy = anisotropy;
        asv.anisotropicT = normalize(tbn * anisotropyDir);
        asv.anisotropicB = normalize(cross(normNormal, asv.anisotropicT));
        asv.ToV = dot(asv.anisotropicT, V);
        asv.BoV = dot(asv.anisotropicB, V);
    }

    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_PUNCTUAL_LIGHT_RECEIVER_BIT) ==
        CORE_MATERIAL_PUNCTUAL_LIGHT_RECEIVER_BIT) {
        ShadingData shadingData;
        shadingData.pos = inPos.xyz;
        shadingData.N = normal;
        shadingData.NoV = NoV;
        shadingData.V = V;
        shadingData.f0 = brdfData.f0;
        shadingData.alpha2 = brdfData.alpha2;
        shadingData.diffuseColor = brdfData.diffuseColor;
        uint materialFlags = CORE_MATERIAL_FLAGS;
        materialFlags |= (hasClearcoat) ? CORE_MATERIAL_CLEARCOAT_BIT : 0;
        materialFlags |= (hasSheen) ? CORE_MATERIAL_SHEEN_BIT : 0;
        materialFlags |= (hasTransmission) ? CORE_MATERIAL_TRANSMISSION_BIT : 0;

        outCol.rgb += CalculateLighting(shadingData, asv, clearcoatSV, sheenSV, materialFlags);
    }
    if ((CORE_MATERIAL_FLAGS & CORE_MATERIAL_INDIRECT_LIGHT_RECEIVER_BIT) ==
        CORE_MATERIAL_INDIRECT_LIGHT_RECEIVER_BIT) {
        // lambert baked into irradianceSample (SH)
        CORE_RELAXEDP vec3 irradiance = GetIrradianceSample(normal) * brdfData.diffuseColor * ao;

        const vec3 worldReflect = GetAnistropicReflectionVector(V, normal, asv);
        const CORE_RELAXEDP vec3 fIndirect = EnvBRDFApprox(brdfData.f0.xyz, brdfData.roughness, NoV);
        // ao applied after clear coat
        CORE_RELAXEDP vec3 radianceSample = GetRadianceSample(worldReflect, brdfData.roughness);
        CORE_RELAXEDP vec3 radiance = radianceSample * fIndirect;

        if (hasSheen) {
            AppendIndirectSheen(sheenSV, radianceSample, alpha, irradiance, radiance);
        }
        if (hasClearcoat) {
            const vec3 ccWorldReflect = reflect(-V, clearcoatSV.ccNormal);
            const vec3 ccRadianceSample = GetRadianceSample(ccWorldReflect, clearcoatSV.ccRoughness);
            AppendIndirectClearcoat(clearcoatSV, ccRadianceSample, alpha, V, irradiance, radiance);
        }
        if (hasTransmission) {
            vec2 fragUv;
            CORE_GET_FRAGCOORD_UV(fragUv, gl_FragCoord.xy, uGeneralData.viewportSizeInvViewportSize.zw);
            // NOTE: ATM use direct refract (no sphere mapping)
            const vec3 rr = -V; // refract(-V, N, 1.0 / ior);
            const CORE_RELAXEDP vec3 transmissionRadianceSample =
                GetTransmissionRadianceSample(fragUv, rr, brdfData.roughness);

            AppendIndirectTransmission(transmissionRadianceSample, baseColor.rgb, transmission, irradiance);
        }
        // apply ao for indirect specular as well (cheap version)
#if 1
        radiance *= ao * SpecularHorizonOcclusion(worldReflect, inNormal);
#else
        radiance *= EnvSpecularAo(ao, NoV, brdfData.roughness) * SpecularHorizonOcclusion(worldReflect, inNormal);
#endif

        outCol.rgb += (irradiance + radiance);
    }
    outCol.rgb += emissive;
}

/**
 * Simplified post process tonemap block with input color (todo describe difference between this and
 * PostProcessTonemapBlock, maybe refactor)
 *
 * @displayName Simple Tone Mapping
 * @in input color - [1, 1, 1]
 * @out output color - Output color of operation
 */
void PostProcessFwTonemapBlock(in vec3 inCol = vec3(1, 1, 1), out vec3 outCol)
{
    outCol = inCol;
    if (CORE_POST_PROCESS_FLAGS > 0) {
        PostProcessTonemapBlock(
            uPostProcessData.flags.x, uPostProcessData.factors[POST_PROCESS_INDEX_TONEMAP], outCol.rgb, outCol.rgb);
    }
}

/**
 * Simplified post process dither block with input color (todo)
 *
 * @displayName Dither
 * @in input color - [1, 1, 1]
 * @out output color - Output color of operation
 */
void PostProcessFwDitherBlock(in vec3 inCol, out vec3 outCol)
{
    outCol = inCol;
    if (CORE_POST_PROCESS_FLAGS > 0) {
        vec2 fragUv;
        CORE_GET_FRAGCOORD_UV(fragUv, gl_FragCoord.xy, uGeneralData.viewportSizeInvViewportSize.zw);
        PostProcessDitherBlock(uPostProcessData.flags.x, uPostProcessData.factors[POST_PROCESS_INDEX_VIGNETTE], fragUv,
            outCol.rgb, outCol.rgb);
    }
}

/**
 * Applies a simple vignette to the provided color. todo describe how this relates to PostProcessVignetteBlock.
 *
 * @displayName Simple Vignette
 * @in input color - [1, 1, 1]
 * @out output color - Output color of operation
 */
void PostProcessFwVignetteBlock(in vec3 inCol = vec3(1, 1, 1), out vec3 outCol)
{
    outCol = inCol;
    if (CORE_POST_PROCESS_FLAGS > 0) {
        vec2 fragUv;
        CORE_GET_FRAGCOORD_UV(fragUv, gl_FragCoord.xy, uGeneralData.viewportSizeInvViewportSize.zw);
        PostProcessVignetteBlock(uPostProcessData.flags.x, uPostProcessData.factors[POST_PROCESS_INDEX_VIGNETTE],
            fragUv, outCol.rgb, outCol.rgb);
    }
}

#endif // SHADERS__COMMON__CORE3D_DM_BLOCKS_H
