
#ifndef VECTOR_OP_BLOCKS_H
#define VECTOR_OP_BLOCKS_H

/**
 * Returns the length of a vector.
 *
 * @displayName Vector Length
 * @in v - The vector to calculate the length of.
 * @out result - The length of the vector.
 * @templateArg T = vec2 | vec3 | vec4
 */
void VecLengthBlock(in T v, out float result)
{
    result = length(v);
}

/**
 * Returns the squared length of a vector. This function avoids calculating a square root, so it is much more efficient
 * if you only need to compare lengths.
 *
 * @displayName Vector Length Squared
 * @in v - The vector to calculate the squared length of.
 * @out result - The squared length of the vector.
 * @templateArg T = vec2 | vec3 | vec4
 */
void VecLengthSquaredBlock(in T v, out float result)
{
    result = dot(v, v);
}

/**
 * Returns a vector in the same direction as the input vector but with a length of 1. The input vector should not be
 * the zero vector.
 *
 * @displayName Normalize
 * @in v - The vector to normalize. Should not be the zero vector.
 * @out result - The normalized vector.
 * @templateArg T = vec2 | vec3 | vec4
 */
void VecNormalizeBlock(in T v, out T result)
{
    result = normalize(v);
}

/**
 * Returns the distance between two vectors.
 *
 * @displayName Distance
 * @in u - The first vector.
 * @in v - The second vector.
 * @out result - The distance between the two vectors u and v.
 * @templateArg T = vec2 | vec3 | vec4
 */
void VecDistanceBlock(in T u, in T v, out float result)
{
    result = distance(u, v);
}

/**
 * Returns the squared distance between two vectors. This function avoids calculating the square root, so it is much
 * more efficient.
 *
 * @displayName Distance Squared
 * @in u - The first vector.
 * @in v - The second vector.
 * @out result - The squared distance between the two vectors u and v.
 * @templateArg T = vec2 | vec3 | vec4
 *
 */
void VecDistanceSquaredBlock(in T u, in T v, out float result)
{
    result = dot(u - v, u - v);
}

/**
 * Returns the reflection of the incident vector off a surface with the specified normal.
 *
 * @displayName Reflect
 * @in I - The incident vector.
 * @in N - The normal of the reflecting surface.
 * @out result - The reflected vector.
 * @templateArg T = vec2 | vec3 | vec4
 */
void VecReflectBlock(in T I, in T N, out T result)
{
    result = reflect(I, N);
}

/**
 * Returns the refraction vector of an incident vector I incident on a surface with the specified normal N and the ratio
 * of indices of refraction (η).
 *
 * @displayName Refract
 * @in I - The incident vector.
 * @in N - The normal of the refracting surface.
 * @in η - The ratio of indices of refraction (eta).
 * @out result - The refracted vector.
 * @templateArg T = vec2 | vec3 | vec4
 */
void VecRefractBlock(in T I, in T N, in float eta, out T result)
{
    result = refract(I, N, eta);
}

/**
 * Returns the dot product of the given vectors. This is calculated as the sum of the products of the two
 * vectors' corresponding components: `u·v = u.x·v.x + u.y·v.y + ...`.
 *
 * @displayName Dot Product
 * @in u - The first vector.
 * @in v - The second vector.
 * @out result - The dot product of the two vectors u and v.
 * @templateArg T = vec2 | vec3 | vec4
 *
 */
void VecDotBlock(in T A, in T B, out float result)
{
    result = dot(A, B);
}

/**
 * Returns the angle in radians between the vector and the positive X axis. The result is in the range [-π, π].
 *
 * @displayName ATan2
 * @in v - The 2d vector to get the angle of. If the coordinates are (0, 0), the result is undefined.
 * @out angle - The angle in radians between the vector and the positive X axis.
 */
void Atan2Block(in vec2 A, out float result)
{
    result = atan(A.y, A.x);
}

/**
 * Returns the cross product of the given vectors. The cross product is a vector perpendicular to both u and v.
 *
 * @displayName Cross Product
 * @in u - The first vector.
 * @in v - The second vector.
 * @out result - The cross product of the vectors u and v.
 */
void CrossProductBlock(in vec3 A, in vec3 B, out vec3 result)
{
    result = cross(A, B);
}

/**
 * Constructs a vec2 from the given components. [DEPRECATED]. Use attached constant blocks or drop down the node inputs
 * instead.
 *
 * @displayName Construct Vec2
 * @in x - The x component of the vector.
 * @in y - The y component of the vector.
 * @out result - The constructed vector.
 */
    void Vec2SwizzleBlock(in float x, in float y, out vec2 result)
{
    result = vec2(x, y);
}

/**
 * Constructs a vec3 from the given components. [DEPRECATED]. Use attached constant blocks or drop down the node inputs
 * instead.
 *
 * @displayName Construct Vec3
 * @in x - The x component of the vector.
 * @in y - The y component of the vector.
 * @in z - The z component of the vector.
 * @out result - The constructed vector.
 */
void Vec3SwizzleBlock(in float x, in float y, in float z, out vec3 result)
{
    result = vec3(x, y, z);
}

/**
 * Constructs a vec4 from the given components. [DEPRECATED]. Use attached constant blocks or drop down the node inputs
 * instead.
 *
 * @displayName Construct Vec4
 * @in x - The x component of the vector.
 * @in y - The y component of the vector.
 * @in z - The z component of the vector.
 * @in w - The w component of the vector.
 * @out result - The constructed vector.
 */
void Vec4SwizzleBlock(in float x, in float y, in float z, in float w, out vec4 result)
{
    result = vec4(x, y, z, w);
}

/**
 * Applies tiling and offset to the given UV coordinates.
 *
 * @displayName UV Tiling and Offset
 * @in uv - The input UV coordinates to modify.
 * @in tiling - The tiling factor (scaling factor) for the UV coordinates.
 * @in offset - The offset to apply to the UV coordinates.
 * @out result - The modified UV coordinates after applying tiling and offset.
 */
void VecTileOffsetBlock(in vec2 uv, in vec2 tiling = vec2(1,1), in vec2 offset, out vec2 result)
{
    result = (uv * tiling) + offset;
}


#endif // VECTOR_OP_BLOCKS_H
