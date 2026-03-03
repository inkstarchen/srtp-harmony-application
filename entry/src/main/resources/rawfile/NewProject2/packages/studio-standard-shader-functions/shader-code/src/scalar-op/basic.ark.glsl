

#ifndef BASIC_VEC2_BLOCKS_H
#define BASIC_VEC2_BLOCKS_H

///******************************************************
// * Basic functions on Vec2 Components
// ******************************************************/

/**
 * @displayName Add
 * @in A - value to be added
 * @in B - value to be added
 * @out result - Sum of A and B.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void AddBlock(in T x, in T m, out T result)
{
    result = x + m;
}

/**
 * @displayName Subtract
 * @in A - value to be subtracted from
 * @in B - value to be subtracted
 * @out result - Difference of A and B. The result is a vector pointing from B to A (if T is a vector).
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void SubtractBlock(in T x, in T m, out T result)
{
    result = x - m;
}

/**
 * @displayName Multiply
 * @in A - value to be multiplied
 * @in B - value to be multiplied
 * @out result - Product of A and B.
 * @templateArg T = float | vec2 | vec3 | vec4 | mat2 | mat3 | mat4
 */
void MultiplyBlock(in T x, in T m, out T result)
{
    result = x * m;
}

/**
 * If the divisor is zero, the result is zero - todo migrate to float infinity
 *
 * @displayName Divide
 * @in A - Dividend - the value to be divided
 * @in B - Divisor - the value to divide by
 * @out result - Output of div operation.
 * @templateArg T
 */
void DivideBlock(in T x, in T d, out T result);

/**
 * @specialization
 * @templateArg T = float
 */
void DivideBlock(in float x, in float d, out float result)
{
    result = x / d;
    if (d == 0) {
        result = 0.0;
    }
}

/**
 * @specialization
 * @templateArg T = vec2
 */
void DivideBlock(in vec2 x, in vec2 d, out vec2 result)
{
    result = x / d;
    if (d.x == 0) {
        result.x = 0.0;
    }
    if (d.y == 0) {
        result.y = 0.0;
    }
}

/**
 * @specialization
 * @templateArg T = vec3
 */
void DivideBlock(in vec3 x, in vec3 d, out vec3 result)
{
    result = x / d;
    if (d.x == 0) {
        result.x = 0.0;
    }
    if (d.y == 0) {
        result.y = 0.0;
    }
    if (d.z == 0) {
        result.z = 0.0;
    }
}

/**
 * @specialization
 * @templateArg T = vec4
 */
void DivideBlock(in vec4 x, in vec4 d, out vec4 result)
{
    result = x / d;
    if (d.x == 0) {
        result.x = 0.0;
    }
    if (d.y == 0) {
        result.y = 0.0;
    }
    if (d.z == 0) {
        result.z = 0.0;
    }
    if (d.w == 0) {
        result.w = 0.0;
    }
}

/**
 * Returns the reciprocal of the input value component-wise. Equivalent of `1 / A`.
 *
 * @displayName Reciprocal
 * @in value - value to take the reciprocal of
 * @out result - the reciprocal of the input value
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ReciprocalBlock(in T x, out T result)
{
    result = 1.0f / x;
}

/**
 * Negates the input value component-wise. Equivalent of `-A`.
 *
 * @displayName Negate
 * @in value - value to negate
 * @out result - the negated value
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void NegateBlock(in T x, out T result)
{
    result = -x;
}

/**
 * Returns `1 - A` component-wise.
 *
 * @displayName One Minus
 * @in value - value to subtract from 1
 * @out result - the result of `1 - A`
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void OneMinusBlock(in T x, out T result)
{
    result = 1.0f - x;
}

/**
 * Linearly interpolates between two values.
 *
 * @displayName Lerp
 * @in A - value to interpolate from
 * @in B - value to interpolate to
 * @in t - Interpolation factor. <br>0.0 yields A, 1.0 yields B, and 0.5 yields the midpoint between A and B.
 * @out result - the interpolated value
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void LerpBlock(in T a, in T b, in T t, out T c)
{
    c = mix(a, b, t);
}

/**
 * Given a known range of values and a target value, the inverse lerp function returns the normalized position of the
 * target value within the range of values, expressed as a value between 0 and 1. This value represents the proportion
 * of the distance between the minimum and maximum values of the range that the target value is located.
 *
 * The output of this function is not clamped, so it can return values outside the range of 0 to 1 if the given value is
 * outside the range of [min, max].
 *
 * Note that the minimum and maximum values of the range must not be equal, otherwise the result will be undefined.
 *
 * @displayName Inverse Lerp
 * @in min - minimum value of the range
 * @in max - maximum value of the range
 * @in value - value to find the normalized position of within the range
 * @out t - the normalized position of the value within the range (min yields 0, max yields 1, and the midpoint yields
 * 0.5)
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void InverseLerpBlock(in T min, in T max, in T value, out T result)
{
    result = (value - min) / (max - min);
}

/**
 * Returns the absolute value of the input value (component-wise).
 *
 * @displayName Abs
 * @in value - value to take the absolute value of
 * @out result - the absolute value of the input value
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void AbsBlock(in T x, out T result)
{
    result = abs(x);
}

/**
 * Returns the remainder of the division of A by B (component-wise).
 *
 * @displayName Mod
 * @in Dividend - the value to be divided
 * @in Divisor - the value to divide by
 * @out result - the remainder of the (component-wise) division of A by B
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ModBlock(in T x, in T y, out T result)
{
    result = mod(x, y);
}

#endif // BASIC_VEC2_BLOCKS_H
