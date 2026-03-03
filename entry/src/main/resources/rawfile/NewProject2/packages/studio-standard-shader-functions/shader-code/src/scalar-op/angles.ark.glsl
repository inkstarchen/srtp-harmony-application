

#ifndef ANGLE_VEC2_BLOCKS_H
#define ANGLE_VEC2_BLOCKS_H

// /******************************************************
// * Angle functions on Vec2 Components
// ******************************************************/

/**
 * Converts a number or vector's components from radians to degrees.
 *
 * @displayName Radians To Degrees
 * @in x - The angle(s) in radians to convert.
 * @out result - The converted angle(s) in degrees.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void DegreesBlock(in T x, out T outVec2)
{
    outVec2 = degrees(x);
}

/**
 * Converts a number or a vector's components from degrees to radians.
 *
 * @displayName Degrees To Radians
 * @in x - The angle(s) in degrees to convert.
 * @out result - The converted angle(s) in radians.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void RadiansBlock(in T x, out T outVec2)
{
    outVec2 = radians(x);
}

#endif // ANGLE_VEC2_BLOCKS_H
