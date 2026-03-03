#ifndef STUDIO_STANDARD_SHADER_FUNCTIONS_CONTIONALS
#define STUDIO_STANDARD_SHADER_FUNCTIONS_CONTIONALS

/**
 * Compares a and b, then returns the corresponding value from the inputs.
 *
 * @displayName Compare Switch
 * @templateArg T = float | vec2 | vec3 | vec4
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @in tolerance - The tolerance to use when checking if a == b.
 * @in a == b - The value to return if a and b are equal.
 * @in a > b - The value to return if a is greater than b.
 * @in a < b - The value to return if a is less than b.
 * @out result - The corresponding input value based on the comparison.
 */
void CompareSwitchBlock(
    in float a, in float b, in float tolerance, in T ifAEqualsB, in T ifAGreaterThanB, in T ifALessThanB, out T result)
{
    if (abs(a - b) <= tolerance) {
        result = ifAEqualsB;
    } else if (a > b) {
        result = ifAGreaterThanB;
    } else {
        result = ifALessThanB;
    }
}

/**
 * If the condition is true, returns the first value, otherwise the second one.
 *
 * @displayName If
 * @templateArg T = float | vec2 | vec3 | vec4
 * @in condition - The condition to check.
 * @in if true - The value to return if the condition is true.
 * @in if false - The value to return if the condition is false.
 * @out result - The corresponding input number based on the condition.
 */
void IfBlock(in bool condition, in T ifTrue, in T ifFalse, out T result)
{
    if (condition) {
        result = ifTrue;
    } else {
        result = ifFalse;
    }
}

/**
 * Returns whether a is less than b.
 *
 * @displayName Less
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a < b - Whether a is less than b.
 * @templateArg T = float | int | uint
 */
fun LessBlock(in T a, in T b, out bool result)
{
    result = a < b;
}

/**
 * Returns whether a is less than or equal to b.
 *
 * @displayName Less or Equal
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a ≤ b - Whether a is less than or equal to b.
 * @templateArg T = float | int | uint
 */
fun LessEqualBlock(in T a, in T b, out bool result)
{
    result = a <= b;
}

/**
 * Returns whether a is greater than b.
 *
 * @displayName Greater
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a > b - Whether a is greater than b.
 * @templateArg T = float | int | uint
 */
fun GreaterBlock(in T a, in T b, out bool result)
{
    result = a > b;
}

/**
 * Returns whether a is greater than or equal to b.
 *
 * @displayName Greater or Equal
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a ≥ b - Whether a is greater than or equal to b.
 * @templateArg T = float | int | uint
 */
fun GreaterEqualBlock(in T a, in T b, out bool result)
{
    result = a >= b;
}

/**
 * Returns whether a is equal to b.
 *
 * @displayName Equal
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a == b - Whether a is equal to b.
 * @templateArg T = float | vec2 | vec3 | vec4 | int | uint
 */
fun EqualToBlock(in T a, in T b, out bool result)
{
    result = a == b;
}

/**
 * Determines whether the value 'a' is within the range defined by 'min' and
 * 'max', inclusive. This means it checks if 'a' is greater than or equal to
 * 'min' and less than or equal to 'max'.
 *
 * @displayName In Range
 * @in a - The value to check.
 * @in min - The minimum value.
 * @in max - The maximum value.
 * @out in range - Whether a is between min and max, inclusive.
 * @templateArg T = float | int | uint
 */
fun InRangeBlock(in T a, in T min, in T max, out bool result)
{
    result = a >= min && a <= max;
}

/**
 * Determines whether the value 'a' falls outside the inclusive range of 'min'
 * and 'max'. It returns true if 'a' is strictly less than 'min' or strictly
 * greater than 'max'. Essentially, this function checks if 'a' does not lie
 * within or on the boundaries of the given range, thus being the inverse
 * condition of the 'InRange' function.
 *
 * @displayName Out of Range
 * @in a - The value to check.
 * @in min - The minimum value.
 * @in max - The maximum value.
 * @out out of range - Whether a is outside of min and max, exclusive.
 * @templateArg T = float | int | uint
 */
fun OutOfRangeBlock(in T a, in T min, in T max, out bool result)
{
    result = a < min || a > max;
}

// is inf, is nan, is finite:
/**
 * Returns whether the given value is either positive or negative infinite
 * value.
 *
 * @displayName Is Infinite
 * @in a - The value to check.
 * @out infinite - Whether a is infinite (-inf or inf).
 */
fun IsInfiniteBlock(in float a, out bool inf)
{
    inf = isinf(a); // todo: add other template specializations for vec2, vec3,
                    // vec4 once the generic system gets better
}

/**
 * Returns whether the given value is a NaN (not a number).
 *
 * @displayName Is NaN
 * @in a - The value to check.
 * @out nan - Whether a is NaN.
 */
fun IsNaNBlock(in float a, out bool nan)
{
    nan = isnan(a); // todo: add other template specializations for vec2, vec3,
                    // vec4 once the generic system gets better
}

/**
 * Returns whether at least one of the given inputs is true.
 *
 * @displayName Or
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out ∨ - Whether a or b is true.
 */
fun OrBlock(in bool a, in bool b, out bool result)
{
    result = a || b;
}

/**
 * Returns whether the given value is positive.
 *
 * @displayName Is Positive
 * @in a - The value to check.
 * @out positive - Whether a is greater than 0.
 */
fun IsPositiveBlock(in float a, out bool result)
{
    result = a > 0.0;
}

/**
 * Returns whether the given value is negative.
 *
 * @displayName Is Negative
 * @in a - The value to check.
 * @out negative - Whether a is less than 0.
 */
fun IsNegativeBlock(in float a, out bool result)
{
    result = a < 0.0;
}

/**
 * Returns whether both of the given inputs are true.
 *
 * @displayName And
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out ∧ - Whether a and b are true.
 */
fun AndBlock(in bool a, in bool b, out bool result)
{
    result = a && b;
}

/**
 * Negates the given input - returns whether it is false.
 *
 * @displayName Not
 * @in a - The value to negate.
 * @out ¬a - Whether a is false.
 */
fun NotBlock(in bool a, out bool result)
{
    result = !a;
}

/**
 * Returns whether a implies b. This says that if a is true, then b must also
 * be. If a is false, then b can be either true or false.
 *
 * @displayName Implies
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a → b - Whether a implies b.
 */
fun ImpliesBlock(in bool a, in bool b, out bool result)
{
    result = !a || b;
}

/**
 * Returns whether a is equivalent to b. This says that a and b must have the
 * same truth value.
 *
 * @displayName Logical Equivalence
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a ↔ b - Whether a is equivalent to b.
 */
fun LogicalEquivalenceBlock(in bool a, in bool b, out bool result)
{
    result = a == b;
}

/**
 * Returns true iff a and b have different truth values. (Exclusive Or)
 *
 * @displayName Xor
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a ⊕ b - Whether a is not equivalent to b.
 */
fun XorBlock(in bool a, in bool b, out bool result)
{
    result = a != b;
}

/**
 * Returns true iff both a and b are false. Equivalent to not(a or b).
 *
 * @displayName Nor
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a ↓ b - Whether a nor b.
 */
fun NorBlock(in bool a, in bool b, out bool result)
{
    result = !(a || b);
}

/**
 * Returns true iff at least one of a and b is false. Equivalent to not(a and
 * b).
 *
 * @displayName Nand
 * @in a - The first value to compare.
 * @in b - The second value to compare.
 * @out a ↑ b - Whether a nand b.
 */
fun NandBlock(in bool a, in bool b, out bool result)
{
    result = !(a && b);
}

#endif // STUDIO_STANDARD_SHADER_FUNCTIONS_CONTIONALS