//#ifndef SHADERS__COMMON__CORE3D_ENV_BLOCKS_H
//#define SHADERS__COMMON__CORE3D_ENV_BLOCKS_H
//
//// Needs to be included after the descriptor set descriptions
//
//#define CORE3D_DEFAULT_ENV_PI 3.1415926535897932384626433832795

///**
// * Outputs the default environment type (CORE_DEFAULT_ENV_TYPE) with default material env
// *
// * @displayName Environment Type
// * @out environment type - default environment type (CORE_DEFAULT_ENV_TYPE)
// */
//void EnvironmentTypeBlock(out uint environmentType)
//{
//    environmentType = CORE_DEFAULT_ENV_TYPE;
//}

///**
// * Performs environment map sampling based on the given environment type and input parameters.
// * This function uses data from common sets (which need to be defined with descriptor sets):
// * - uGeneralData (camera index)
// * - uCameras (cameras for near/far plane)
// * - uEnvironmentData (orientation, LOD level, and factors)
// *
// * @displayName Environment Map Sampler
// * @in environmentType - The type of environment map to use, based on the flags (CORE_DEFAULT_ENV_TYPE).
// * @in uv - The 2D texture coordinates for sampling the environment map.
// * @in cubeMap - The environment cube map.
// * @in texMap - The environment texture map.
// * @out color - The sampled environment color.
// */
//void EnvironmentMapSampleBlock(
//    in uint environmentType, in vec2 uv, in samplerCube cubeMap, in sampler2D texMap, out vec3 color)
//{
//    color = vec3(0.0);
//    CORE_RELAXEDP const float lodLevel = uEnvironmentData.values.y;
//    if ((environmentType == CORE_BACKGROUND_TYPE_CUBEMAP) ||
//        (environmentType == CORE_BACKGROUND_TYPE_EQUIRECTANGULAR)) {
//        // NOTE: would be nicer to calculate in the vertex shader
//
//        // remove translation from view
//        const uint cameraIdx = GetUnpackCameraIndex(uGeneralData);
//        mat4 viewProjInv = uCameras[cameraIdx].viewInv;
//        viewProjInv[3] = vec4(0.0, 0.0, 0.0, 1.0);
//        viewProjInv = viewProjInv * uCameras[cameraIdx].projInv;
//
//        vec4 farPlane = viewProjInv * vec4(inUv.x, inUv.y, 1.0, 1.0);
//        farPlane.xyz = farPlane.xyz / farPlane.w;
//
//        vec4 nearPlane = viewProjInv * vec4(inUv.x, inUv.y, 0.0, 1.0);
//        nearPlane.xyz = nearPlane.xyz / nearPlane.w;
//
//        const vec3 worldView = mat3(uEnvironmentData.envRotation) * normalize(farPlane.xyz - nearPlane.xyz);
//
//        if (environmentType == CORE_BACKGROUND_TYPE_CUBEMAP) {
//            color = unpackEnvMap(textureLod(cubeMap, worldView, lodLevel));
//        } else {
//            const vec2 texCoord = vec2(atan(worldView.z, worldView.x) + CORE3D_DEFAULT_ENV_PI, acos(worldView.y)) /
//                vec2(2.0 * CORE3D_DEFAULT_ENV_PI, CORE3D_DEFAULT_ENV_PI);
//            color = textureLod(texMap, texCoord, lodLevel).xyz;
//        }
//    } else if (environmentType == CORE_BACKGROUND_TYPE_IMAGE) {
//        const vec2 texCoord = (inUv + vec2(1.0)) * 0.5;
//        color = unpackEnvMap(textureLod(texMap, texCoord, lodLevel));
//    }
//
//    color *= uEnvironmentData.envMapColorFactor.xyz;
//}
//#endif // SHADERS__COMMON__CORE3D_ENV_BLOCKS_H
