#ifndef VERTEX_BLOCKS_H
#define VERTEX_BLOCKS_H

#include "common.h"

/**
 * Sets the output data of the vertex shader.
 *
 * @displayName Output Vertex Data
 * @in Position - The local vertex position.
 * @in Normal - The local vertex normal.
 * @in Tangent - The local vertex tangent.
 * @in Color - The vertex color.
 */
void OutputVertexBlock(in vec3 position, in vec3 normal, in vec4 tangent, in vec4 color)
{
    const uint cameraIdx = GetUnpackCameraIndex(uGeneralData);
    mat4 worldMatrix;
    mat3 normalMatrix;
    mat4 prevWorldMatrix;
    GetWorldMatrix(worldMatrix, normalMatrix, prevWorldMatrix);
    const vec4 worldPos = worldMatrix * vec4(position.xyz, 1.0);
    const vec4 projPos = uCameras[cameraIdx].viewProj * worldPos;
    CORE_VERTEX_OUT(projPos);

    const uint instanceIdx = GetInstanceIndex();
    outIndices = GetPackFlatIndices(cameraIdx, instanceIdx);

    outPos.xyz = worldPos.xyz;
    outPrevPosI = vec4(0.0, 0.0, 0.0, 0.0);
    if ((CORE_SUBMESH_FLAGS & CORE_SUBMESH_VELOCITY_BIT) == CORE_SUBMESH_VELOCITY_BIT) {
        outPrevPosI.xyz = (prevWorldMatrix * vec4(position.xyz, 1.0)).xyz;
    }

    outNormal = normalize(normalMatrix * normal.xyz);
    if ((CORE_SUBMESH_FLAGS & CORE_SUBMESH_TANGENTS_BIT) == CORE_SUBMESH_TANGENTS_BIT) {
        outTangentW = vec4(normalize(normalMatrix * tangent.xyz), tangent.w);
    } else {
        outTangentW = vec4(0.0, 0.0, 0.0, 1.0);
    }

    outUv.xy = inUv0;
    if ((CORE_SUBMESH_FLAGS & CORE_SUBMESH_SECOND_TEXCOORD_BIT) == CORE_SUBMESH_SECOND_TEXCOORD_BIT) {
        outUv.zw = inUv1;
    }

    if ((CORE_SUBMESH_FLAGS & CORE_SUBMESH_VERTEX_COLORS_BIT) == CORE_SUBMESH_VERTEX_COLORS_BIT) {
        outColor = color;
    } else {
        outColor = vec4(1.0);
    }
}

/**
 * Retrieves various attributes of the vertex from the input data.
 *
 * @displayName Input Vertex Data
 * @out Position - The local vertex position.
 * @out Normal - The local vertex normal.
 * @out Tangent - The local vertex tangent.
 * @out Color - The vertex color.
 */
void InputVertexBlock(out vec3 position, out vec3 normal, out vec4 tangent, out vec4 color)
{
    position = inPosition.xyz;
    normal = inNormal.xyz;
    tangent = inTangent;
    color = inColor;
}

/**
 * Retrieves the local vertex position from the input data.
 *
 * @displayName Input Vertex Position
 * @out Position - The local vertex position.
 */
void InputVertexPositionBlock(out vec3 position)
{
    position = inPosition.xyz;
}

/**
 * Retrieves the local vertex normal from the input data.
 *
 * @displayName Input Vertex Normal
 * @out Normal - The local vertex normal.
 */
void InputVertexNormalBlock(out vec3 normal)
{
    normal = inNormal.xyz;
}

/**
 * Retrieves the local vertex tangent from the input data.
 *
 * @displayName Input Vertex Tangent
 * @out Tangent - The local vertex tangent.
 */
void InputVertexTangentBlock(out vec4 tangent)
{
    tangent = inTangent;
}

/**
 * Retrieves the vertex color from the input data.
 *
 * @displayName Input Vertex Color
 * @out Color - The vertex color.
 */
void InputVertexColorBlock(out vec4 color)
{
    color = inColor;
}

/**
 * Retrieves the UV coordinates from the input, including support for a second UV set if available.
 *
 * @displayName UV
 * @out Uv - UV coordinates (xy: first UV set, zw: second UV set, if available).
 */
void UvVertexBlock(out vec4 uv)
{
    uv = vec4(0.0, 0.0, 0.0, 0.0);
    uv.xy = inUv0;
    if ((CORE_SUBMESH_FLAGS & CORE_SUBMESH_SECOND_TEXCOORD_BIT) == CORE_SUBMESH_SECOND_TEXCOORD_BIT) {
        uv.zw = inUv1;
    }
}

/**
 * Retrieves the current scene time and delta time.
 *
 * @displayName Time
 * @out SceneTime - The current time in the scene.
 * @out DeltaTime - The time elapsed since the last frame.
 */
void TimeVertexBlock(out float sceneTime, out float deltaTime)
{
    sceneTime = uGeneralData.sceneTimingData.z;
    deltaTime = uGeneralData.sceneTimingData.x;
}

/**
 * Generates 3D Simplex noise based on the input position.
 *
 * @displayName Simplex Noise 3D
 * @in Position - The input position in 3D space.
 * @out Noise - The resulting 3D Simplex noise value.
 */
void SimplexNoise3DVertexBlock(in vec3 v, out float noise)
{  
    noise = SimplexNoise(v);
}

/**
 * Samples a gradient based on the number of colors and interpolates between them over time.
 *
 * @displayName Sample Gradient
 * @in NumColors - The number of colors to interpolate between [2, 4].
 * @in Color 1 - The first color.
 * @in Color 2 - The second color.
 * @in Color 3 - The third color (used if numColors >= 3).
 * @in Color 4 - The fourth color (used if numColors == 4).
 * @in Time - A value between 0 and 1 representing the interpolation factor.
 * @out Color - The interpolated color output.
 */
void SampleGradientVertexBlock(
    in float numColors, in vec3 color1, in vec3 color2, in vec3 color3, in vec3 color4, in float time, out vec3 color)
{
    vec3 result;
    if (numColors == 2) {
        result = mix(color1, color2, time);
    } else if (numColors == 3) {
        if (time <= 0.5) {
            float t = time / 0.5;
            result = mix(color1, color2, t);
        } else {
            float t = (time - 0.5) / 0.5;
            result = mix(color2, color3, t);
        }
    } else if (numColors == 4) {
        if (time <= 0.33) {
            float t = time / 0.33;
            result = mix(color1, color2, t);
        } else if (time <= 0.66) {
            float t = (time - 0.33) / 0.33;
            result = mix(color2, color3, t);
        } else {
            float t = (time - 0.66) / 0.34;
            result = mix(color3, color4, t);
        }
    } else {
        // Default case if an unsupported number of colors is passed
        result = color1;
    }

    color = result;
}

/**
 * Applies a 3D rotation to the input position around a specified axis and center.
 *
 * @displayName Rotate 3D
 * @in Position - The input vector to rotate.
 * @in RotationCenter - The center of the rotation.
 * @in Axis - The axis around which to rotate.
 * @in Angle - The angle of rotation, in radians.
 * @out NewPosition - The rotated output vector.
 */
void Rotate3DVertexBlock(in vec3 position, in vec3 rotationCenter, in vec3 axis, in float angle, out vec3 newPosition)
{
    vec3 normalizedAxis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;

    mat3 rotationMatrix = mat3(oc * normalizedAxis.x * normalizedAxis.x + c,
        oc * normalizedAxis.x * normalizedAxis.y - normalizedAxis.z * s,
        oc * normalizedAxis.x * normalizedAxis.z + normalizedAxis.y * s,
        oc * normalizedAxis.x * normalizedAxis.y + normalizedAxis.z * s, oc * normalizedAxis.y * normalizedAxis.y + c,
        oc * normalizedAxis.y * normalizedAxis.z - normalizedAxis.x * s,
        oc * normalizedAxis.x * normalizedAxis.z - normalizedAxis.y * s,
        oc * normalizedAxis.y * normalizedAxis.z + normalizedAxis.x * s, oc * normalizedAxis.z * normalizedAxis.z + c);

    vec3 translatedPosition = position - rotationCenter;
    newPosition = rotationMatrix * translatedPosition;
    newPosition += rotationCenter;
}

/**
 * Transforms a position from object space to world space using the world matrix.
 *
 * @displayName World Matrix Transform
 * @in ObjectPosition - The position in object space.
 * @out WorldPosition - The transformed position in world space.
 */
void WorldMatrixTransformVertexBlock(in vec3 objectPosition, out vec3 worldPosition)
{
    mat4 worldMatrix;
    mat3 normalMatrix;
    mat4 prevWorldMatrix;
    GetWorldMatrix(worldMatrix, normalMatrix, prevWorldMatrix);

    worldPosition = (worldMatrix * vec4(objectPosition, 1.0)).xyz;
}

/**
 * Transforms a position from world space to object space using the inverse of the world matrix.
 *
 * @displayName Object Matrix Transform
 * @in WorldPosition - The position in world space.
 * @out ObjectPosition - The transformed position in object space.
 */
void ObjectMatrixTransformVertexBlock(in vec3 worldPosition, out vec3 objectPosition)
{
    mat4 worldMatrix;
    mat3 normalMatrix;
    mat4 prevWorldMatrix;
    GetWorldMatrix(worldMatrix, normalMatrix, prevWorldMatrix);

    mat4 objectMatrix = inverse(worldMatrix);

    objectPosition = (objectMatrix * vec4(worldPosition, 1.0)).xyz;
}

/**
 * Transforms a direction from world space to object space
 *
 * @displayName Object Direction Transform
 * @in WorldDirection - The direction in world space.
 * @out ObjectDirection - The transformed direction in object space.
 */
void ObjectDirectionTransformVertexBlock(in vec3 worldDirection, out vec3 objectDirection)
{
    mat4 worldMatrix;
    mat3 normalMatrix;
    mat4 prevWorldMatrix;
    GetWorldMatrix(worldMatrix, normalMatrix, prevWorldMatrix);
    mat4 objectMatrix = inverse(worldMatrix);
    
    objectDirection = (objectMatrix * vec4(worldDirection, 0.0)).xyz;
}

/**
* Transforms a direction from object space to world space
*
* @displayName World Direction Transform
* @in ObjectDirection - The direction in object space.
* @out WorldDirection - The transformed direction in world space.
*/
void WorldDirectionTransformVertexBlock(in vec3 objectDirection, out vec3 worldDirection)
{
   mat4 worldMatrix;
   mat3 normalMatrix;
   mat4 prevWorldMatrix;
   GetWorldMatrix(worldMatrix, normalMatrix, prevWorldMatrix);
   
   worldDirection = (worldMatrix * vec4(objectDirection, 0.0)).xyz;
}

#endif


