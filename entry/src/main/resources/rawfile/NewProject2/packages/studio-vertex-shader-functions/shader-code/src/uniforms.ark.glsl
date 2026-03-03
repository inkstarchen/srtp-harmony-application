#ifndef UNIFORM_BLOCKS_H
#define UNIFORM_BLOCKS_H

/**
 * Retrieves common camera properties from the camera data structure.
 *
 * @displayName Camera Properties
 * @out position - Vec3 camera world position
 * @out forward - Vec3 normalized camera forward direction
 * @out up - Vec3 normalized camera up direction
 * @out right - Vec3 normalized camera right direction
 * @out jitter - Vec2 camera jitter offset
 * @out uniqueId - UVec2 camera unique identifier
 * @out layerMask - UVec2 camera layer mask
 */
void CameraPropertiesVertBlock(
    out vec3 outPosition,
    out vec3 outForward,
    out vec3 outUp,
    out vec3 outRight,
    out vec2 outJitter,
    out uvec2 outUniqueId,
    out uvec2 outLayerMask)
{
    const uint cameraIdx = GetUnpackCameraIndex(uGeneralData);
    DefaultCameraMatrixStruct camera = uCameras[cameraIdx];
    
    // From 3d_dm_structures_common.h
    outPosition = camera.viewInv[3].xyz;
    
    // Extract camera basis vectors from view inverse matrix
    outRight = normalize(camera.viewInv[0].xyz);
    
    outUp = normalize(camera.viewInv[1].xyz);
    
    outForward = normalize(-camera.viewInv[2].xyz);
    
    // Extract jitter values
    outJitter = camera.jitter.xy;
    
    // Extract camera identifiers
    outUniqueId = camera.indices.xy;
    outLayerMask = camera.indices.zw;
}

/**
 * Extracts object properties from the world matrix.
 *
 * @displayName Object Properties
 * @out position - Vec3 object world position
 * @out scale - Vec3 object scale in world space
 * @out right - Vec3 object right direction (X axis)
 * @out up - Vec3 object up direction (Y axis)
 * @out forward - Vec3 object forward direction (Z axis)
 */
void ObjectPropertiesVertBlock(
    out vec3 outPosition, 
    out vec3 outScale, 
    out vec3 outRight, 
    out vec3 outUp, 
    out vec3 outForward)
{
    const uint instanceIdx = GetInstanceIndex();
    
    mat4 worldMatrix = uMeshMatrix.mesh[instanceIdx].world;
    
    outPosition = worldMatrix[3].xyz;
    
    outScale.x = length(worldMatrix[0].xyz);
    outScale.y = length(worldMatrix[1].xyz);
    outScale.z = length(worldMatrix[2].xyz);
    
    outRight = normalize(worldMatrix[0].xyz);
    outUp = normalize(worldMatrix[1].xyz);
    outForward = normalize(worldMatrix[2].xyz);
}

#endif


