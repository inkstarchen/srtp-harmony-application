#ifndef ROUND_VEC2_BLOCKS_H
#define ROUND_VEC2_BLOCKS_H

///******************************************************
// * Rounding functions
// ******************************************************/

/**
 * Returns the largest integer less than or equal to the component value. Example: `floor(1.5) = 1.0`,
 * `floor(-1.5) = -2`.
 *
 * @displayName Floor
 * @in x - The value to floor.
 * @out result - The result of the floor function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void FloorBlock(in T x, out T result)
{
    result = floor(x);
}

/**
 * Returns the smallest integer greater than or equal to the component value. Example: `ceil(1.5) = 2.0`,
 * `ceil(-1.5) = -1`.
 *
 * @displayName Ceil
 * @in x - The value to ceil.
 * @out result - The result of the ceiling.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void CeilBlock(in T x, out T result)
{
    result = ceil(x);
}

/**
 * Returns the integer part of the component value, so it rounds towards zero. Example: `trunc(1.5) = 1.0`,
 * `trunc(-1.5) = -1`.
 *
 * @displayName Trunc
 * @in x - The value to truncate.
 * @out result - The truncated value.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void TruncBlock(in T x, out T result)
{
    result = trunc(x);
}

/**
 * Returns the nearest integer number to the component value. 0.5 is implementation dependent. Example:
 * `round(1.5) = 2.0`, `round(-1.5) = -2`.
 *
 * @displayName Round
 * @in x - The value to round.
 * @out result - The rounded value.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void RoundBlock(in T x, out T result)
{
    result = round(x);
}

/**
 * Returns the fractional part of the component value but for negative values it's just continuing the repeating saw
 * pattern of interval 1. The value is calculated as `x - floor(x)`. Example: `fract(1.3) = 0.3`, `fract(-1.3) = 0.7`.
 *
 * @displayName Fractional Part
 * @in x - The value to get the fractional part of.
 * @out result - The fractional part of the input value.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void FractBlock(in T x, out T result)
{
    result = fract(x);
}

/**
 * Returns the nearest even integer number to the component value. Equivalent to `round(x / 2) * 2`. Example:
 * `roundEven(1.1) = 2.0`
 *
 * @displayName Round To Even
 * @in x - The value to round.
 * @out result - The even rounded value.
 * @templateArg T = float | vec2 | vec3 | vec4
 *
 */
void RoundEven(in T x, out T result)
{
    result = round(x / 2.0f) * 2.0f;
}
#endif // ROUND_VEC2_BLOCKS_H
