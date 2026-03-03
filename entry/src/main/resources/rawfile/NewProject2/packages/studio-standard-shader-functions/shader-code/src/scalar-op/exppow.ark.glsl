#ifndef EXPPOW_VEC2_BLOCKS_H
#define EXPPOW_VEC2_BLOCKS_H

///******************************************************
// * Exponential / Power functions
// ******************************************************/

/**
 * Returns the result of the component-wise power function. Equivalent to `pow(A, B)` and to `vecN(pow(A.x, B.x), ...,
 * pow(A.n, B.n))`.
 *
 * @displayName Power
 * @in A - The base of the power function.
 * @in B - The exponent of the power function.
 * @out result - The result of the component-wise power function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void PowerBlock(in T a, in T b, out T result)
{
    result = pow(a, b);
}

/**
 * Returns the result of the component-wise logarithm with base 2. Equivalent to `log2(x)` and to `vecN(log2(x.x), ...,
 * log2(x.n))`.
 *
 * @displayName Log2
 * @in x - The values to calculate the logarithm of. Cannot be 0.
 * @out result - The result of the logarithm.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void Log2Block(in T x, out T result)
{
    result = log2(x);
}

/**
 * Returns the result of the component-wise logarithm with base e. Equivalent to `log(x)` and to `vecN(log(x.x), ...,
 * log(x.n))`.
 *
 * @displayName Log_e
 * @in x - The values to calculate the logarithm of. Cannot be 0.
 * @out result - The result of the logarithm.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void LogBlock(in T x, out T result)
{
    result = log(x);
}

/**
 * Returns the result of the component-wise logarithm with a custom base. Equivalent to `log(x) / log(base)` and to
 * `vecN(log(x.x) / log(base.x), ..., log(x.n) / log(base.n))`.
 *
 * @displayName Log_<base>
 * @in x - The values to calculate the logarithm of. Cannot be 0.
 * @in base - The base of the logarithm. Cannot be 0.
 * @out result - The result of the logarithm such that `base^result = x`.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void LogWithCustomBaseBlock(in T x, in T base, out T res)
{
    res = log(x) / log(base);
}

/**
 * Returns the result of the component-wise exponential function with base 2. Equivalent to `exp2(x)` and to
 * `vecN(exp2(x.x), ..., exp2(x.n))`.
 *
 * @displayName Exp2
 * @in x - The values to calculate the exponential of.
 * @out 2^x - The result of the exponential function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void Exp2Block(in T x, out T result)
{
    result = exp2(x);
}

/**
 * Returns the result of the component-wise exponential function. Equivalent to `exp(x)` and to `vecN(exp(x.x), ...,
 * exp(x.n))`.
 *
 * @displayName Exp_e
 * @in x - The values to calculate the exponential of.
 * @out e^x - The result of the exponential function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void ExpBlock(in T x, out T result)
{
    result = exp(x);
}

/**
 * Returns the result of the component-wise square root function. Equivalent to `sqrt(x)` and to `vecN(sqrt(x.x), ...,
 * sqrt(x.n))`. The square root of a number is a positive number that, when multiplied by itself, gives the original
 * number.
 *
 * @displayName Sqrt
 * @in x - The value to calculate the square root of. Components cannot be negative, otherwise the result is undefined.
 * @out result - The result of the square root function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void SqrtBlock(in T x, out T result)
{
    result = sqrt(x);
}

/**
 * Returns the result of the component-wise inverse square root function. Equivalent to `1 / sqrt(x)` and to
 * `vecN(1 / sqrt(x.x), ..., 1 / sqrt(x.n))`.
 *
 * @displayName InvSqrt
 * @in x - The value to calculate the inverse square root of. Components should be positive, otherwise the result is
 * undefined.
 * @out result - The result of the component-wise inverse square root function.
 * @templateArg T = float | vec2 | vec3 | vec4
 */
void InvSqrtBlock(in T x, out T result)
{
    result = inversesqrt(x);
}
#endif // EXPPOW_VEC2_BLOCKS_H
