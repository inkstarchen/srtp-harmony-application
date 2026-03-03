
#ifndef CLAMP_VEC2_BLOCKS_H
#define CLAMP_VEC2_BLOCKS_H

///******************************************************
// * Clamp functions on Vec2 Components
// ******************************************************/

/**
 * Returns the larger components from the input values (component-wise).
 *
 * @displayName Max
 * @in A - First value.
 * @in B - Second value.
 * @out max - The larger components from A and B.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void MaxBlock(in T a, in T b, out T max_)
{
    max_ = max(a, b);
}

/**
 * Returns the smaller components from the input values (component-wise).
 *
 * @displayName Min
 * @in A - First value.
 * @in B - Second value.
 * @out min - The smaller components from A and B.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void MinBlock(in T a, in T b, out T min_)
{
    min_ = min(a, b);
}

/**
 * Restricts the input value between the minimum and maximum values.
 *
 * @displayName Clamp
 * @in value - The value to be clamped.
 * @in min - The lower bound(s).
 * @in max - The higher bound(s)
 * @out output - Output of clamp(value, min, max) operation
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ClampBlock(in T x, in T minVal, in T maxVal, out T out_)
{
    out_ = clamp(x, minVal, maxVal);
}

/**
 * @displayName Step
 * @in A - The input value.
 * @in edge - The edge value to compare against.
 * @out result - Output of step(A, edge) operation
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void StepBlock(in T x, in T edge, out T res)
{
    res = step(edge, x);
}

/**
 * @displayName Smooth Step
 * @in A - The value to interpolate.
 * @in edge0 - The lower edge of the interpolation range.
 * @in edge1 - The upper edge of the interpolation range.
 * @out out - The interpolated value.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void SmoothStepBlock(in T x, in T edge0, in T edge1, out T out_)
{
    out_ = smoothstep(edge0, edge1, x);
}

/**
 * @displayName Saturate
 * @in A - The value to saturate.
 * @out out - The saturated value.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void SaturateBlock(in T x, out T out_)
{
    out_ = clamp(x, 0.0f, 1.0f);
}

#endif // CLAMP_VEC2_BLOCKS_H
