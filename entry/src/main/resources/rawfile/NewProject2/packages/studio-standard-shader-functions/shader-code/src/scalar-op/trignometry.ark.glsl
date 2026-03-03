#ifndef TRIGONOMETRY_BLOCKS_H
#define TRIGONOMETRY_BLOCKS_H

///******************************************************
// * Trigonometric functions
// ******************************************************/

/**
 * Returns the sine of the input value (component-wise).
 *
 * @displayName Sin
 * @in x - The angle(s) in radians to calculate the sine of.
 * @out result - The result(s) of the sine function (between -1 and 1).
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void SinBlock(in T x, out T result)
{
    result = sin(x);
}

/**
 * Returns the cosine of the input value (component-wise).
 *
 * @displayName Cos
 * @in x - The angle(s) in radians to calculate the cosine of.
 * @out result - The result(s) of the cosine function (between -1 and 1).
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void CosBlock(in T x, out T result)
{
    result = cos(x);
}

/**
 * Returns the tangent of the input value (component-wise).
 *
 * @displayName Tan
 * @in x - The angle(s) in radians to calculate the tangent of.
 * @out result - The result(s) of the tangent function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void TanBlock(in T x, out T result)
{
    result = tan(x);
}

/**
 * Returns the angle whose sine is the input value (component-wise).
 *
 * @displayName ArcSin
 * @in x - The value(s) to calculate the arc sine of.
 * @out result - The result(s) of the arc sine function in radians.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ASinBlock(in T x, out T result)
{
    result = asin(x);
}

/**
 * Returns the angle whose cosine is the input value (component-wise).
 *
 * @displayName ArcCos
 * @in x - The value(s) to calculate the arc cosine of.
 * @out result - The result(s) of the arc cosine function in radians.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ACosBlock(in T x, out T result)
{
    result = acos(x);
}

/**
 * Returns the angle whose tangent is the input value (component-wise).
 *
 * @displayName ArcTan
 * @in x - The value(s) to calculate the arc tangent of.
 * @out result - The result(s) of the arc tangent function in radians.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ATanBlock(in T x, out T result)
{
    result = atan(x);
}

/**
 * Returns the hyperbolic sine of the input value (component-wise).
 *
 * @displayName SinH
 * @in x - The value(s) to calculate the hyperbolic sine of.
 * @out result - The result(s) of the hyperbolic sine function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void SinHBlock(in T x, out T result)
{
    result = sinh(x);
}

/**
 * Returns the hyperbolic cosine of the input value (component-wise).
 *
 * @displayName CosH
 * @in x - The value(s) to calculate the hyperbolic cosine of.
 * @out result - The result(s) of the hyperbolic cosine function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void CosHBlock(in T x, out T result)
{
    result = cosh(x);
}

/**
 * Returns the hyperbolic tangent of the input value (component-wise).
 *
 * @displayName TanH
 * @in x - The value(s) to calculate the hyperbolic tangent of.
 * @out result - The result(s) of the hyperbolic tangent function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void TanHBlock(in T x, out T result)
{
    result = tanh(x);
}

/**
 * Returns the angle whose hyperbolic sine is the input value (component-wise).
 *
 * @displayName ArcSinH
 * @in x - The value(s) to calculate the arc hyperbolic sine of.
 * @out result - The result(s) of the arc hyperbolic sine function in radians.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ASinHBlock(in T x, out T result)
{
    result = asinh(x);
}

/**
 * Returns the angle whose hyperbolic cosine is the input value (component-wise).
 *
 * @displayName ArcCosH
 * @in x - The value(s) to calculate the arc hyperbolic cosine of.
 * @out result - The result(s) of the arc hyperbolic cosine function in radians.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ACosHBlock(in T x, out T result)
{
    result = acosh(x);
}

/**
 * Returns the angle whose hyperbolic tangent is the input value (component-wise).
 *
 * @displayName ArcTanH
 * @in x - The value(s) to calculate the arc hyperbolic tangent of.
 * @out result - The result(s) of the arc hyperbolic tangent function in radians.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ATanHBlock(in T x, out T result)
{
    result = atanh(x);
}

#endif // TRIGONOMETRY_BLOCKS
