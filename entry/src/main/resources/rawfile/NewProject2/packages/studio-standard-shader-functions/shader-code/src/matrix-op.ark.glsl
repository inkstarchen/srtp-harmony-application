
#ifndef MATRIX_OP_BLOCKS_H
#define MATRIX_OP_BLOCKS_H

// =====================
//    Row Constructions
// =====================
/**
 * Constructs a mat2 from two vectors representing the rows of the matrix.
 *
 * @displayName Construct Mat2 from Rows
 * @in row0 - The first row of the matrix.
 * @in row1 - The second row of the matrix.
 * @out result - The constructed 2x2 matrix.
 */
void Mat2RowConstructBlock(in vec2 row0, in vec2 row1, out mat2 result)
{
    result = transpose(mat2(
        row0.x, row0.y,
        row1.x, row1.y
    ));
}

/**
 * Constructs a mat3 from three vectors representing the rows of the matrix.
 *
 * @displayName Construct Mat3 from Rows
 * @in row0 - The first row of the matrix.
 * @in row1 - The second row of the matrix.
 * @in row2 - The third row of the matrix.
 * @out result - The constructed 3x3 matrix.
 */
void Mat3RowConstructBlock(in vec3 row0, in vec3 row1, in vec3 row2, out mat3 result)
{
    result = transpose(mat3(
        row0.x, row0.y, row0.z,
        row1.x, row1.y, row1.z,
        row2.x, row2.y, row2.z
    ));
}

/**
 * Constructs a mat4 from four vectors representing the rows of the matrix.
 *
 * @displayName Construct Mat4 from Rows
 * @in row0 - The first row of the matrix.
 * @in row1 - The second row of the matrix.
 * @in row2 - The third row of the matrix.
 * @in row3 - The fourth row of the matrix.
 * @out result - The constructed 4x4 matrix.
 */
void Mat4RowConstructBlock(in vec4 row0, in vec4 row1, in vec4 row2, in vec4 row3, out mat4 result)
{
    result = transpose(mat4(
        row0.x, row0.y, row0.z, row0.w,
        row1.x, row1.y, row1.z, row1.w,
        row2.x, row2.y, row2.z, row2.w,
        row3.x, row3.y, row3.z, row3.w
    ));
}

// =====================
//    Row Destructions
// =====================
/**
 * Extracts the rows of a mat2 as individual vec2 vectors.
 *
 * @displayName Destruct Mat2 to Rows
 * @in matrix - The input 2x2 matrix to destruct.
 * @out row0 - The first row of the matrix.
 * @out row1 - The second row of the matrix.
 */
void Mat2RowDestructBlock(in mat2 matrix, out vec2 row0, out vec2 row1)
{
    mat2 transposed = transpose(matrix);
    row0 = transposed[0];
    row1 = transposed[1];
}

/**
 * Extracts the rows of a mat3 as individual vec3 vectors.
 *
 * @displayName Destruct Mat3 to Rows
 * @in matrix - The input 3x3 matrix to destruct.
 * @out row0 - The first row of the matrix.
 * @out row1 - The second row of the matrix.
 * @out row2 - The third row of the matrix.
 */
void Mat3RowDestructBlock(in mat3 matrix, out vec3 row0, out vec3 row1, out vec3 row2)
{
    mat3 transposed = transpose(matrix);
    row0 = transposed[0];
    row1 = transposed[1];
    row2 = transposed[2];
}

/**
 * Extracts the rows of a mat4 as individual vec4 vectors.
 *
 * @displayName Destruct Mat4 to Rows
 * @in matrix - The input 4x4 matrix to destruct.
 * @out row0 - The first row of the matrix.
 * @out row1 - The second row of the matrix.
 * @out row2 - The third row of the matrix.
 * @out row3 - The fourth row of the matrix.
 */
void Mat4RowDestructBlock(in mat4 matrix, out vec4 row0, out vec4 row1, out vec4 row2, out vec4 row3)
{
    mat4 transposed = transpose(matrix);
    row0 = transposed[0];
    row1 = transposed[1];
    row2 = transposed[2];
    row3 = transposed[3];
}

// =====================
//    BASIC OPERATIONS
// =====================

/**
 * Returns the inverse of the given matrix.
 *
 * @displayName Matrix Inverse
 * @in matrix - The input matrix to invert.
 * @out result - The inverse of the input matrix.
 * @templateArg T = mat2 | mat3 | mat4
 */
void MatInverseBlock(in T matrix, out T result)
{
    result = inverse(matrix);
}

/**
 * Returns the determinant of the given matrix.
 *
 * @displayName Matrix Determinant
 * @in matrix - The input matrix.
 * @out result - The determinant value of the input matrix.
 * @templateArg T = mat2 | mat3 | mat4
 */
void MatDeterminantBlock(in T matrix, out float result)
{
    result = determinant(matrix);
}

/**
 * Returns the transpose of the given matrix.
 *
 * @displayName Matrix Transpose
 * @in matrix - The input matrix to transpose.
 * @out result - The transposed matrix.
 * @templateArg T = mat2 | mat3 | mat4
 */
void MatTransposeBlock(in T matrix, out T result)
{
    result = transpose(matrix);
}

// =====================
//    MULTIPLY OPERATIONS
// Normal mat with mat operation is handled at scaler-op/basic.ark.glsl -> MultiplyBlock
// =====================


/**
 * Multiplies a mat2 with a vec2.
 *
 * @displayName Mat2 Vec2 Multiply
 * @in matrix - The 2x2 matrix.
 * @in vector - The 2-component vector.
 * @out result - The resulting 2-component vector.
 */
void Mat2Vec2MultiplyBlock(in mat2 matrix, in vec2 vector, out vec2 result)
{
    result = matrix * vector;
}

/**
 * Multiplies a mat3 with a vec3.
 *
 * @displayName Mat3 Vec3 Multiply
 * @in matrix - The 3x3 matrix.
 * @in vector - The 3-component vector.
 * @out result - The resulting 3-component vector.
 */
void Mat3Vec3MultiplyBlock(in mat3 matrix, in vec3 vector, out vec3 result)
{
    result = matrix * vector;
}

/**
 * Multiplies a mat4 with a vec4.
 *
 * @displayName Mat4 Vec4 Multiply
 * @in matrix - The 4x4 matrix.
 * @in vector - The 4-component vector.
 * @out result - The resulting 4-component vector.
 */
void Mat4Vec4MultiplyBlock(in mat4 matrix, in vec4 vector, out vec4 result)
{
    result = matrix * vector;
}

/**
 * Multiplies a 4x4 matrix by a vector, where the matrix is passed as 4 column vectors (Deprecated)
 *
 * @displayName Matrix Vector Multiply
 * @in col0 - First column of the matrix
 * @in col1 - Second column of the matrix
 * @in col2 - Third column of the matrix
 * @in col3 - Fourth column of the matrix
 * @in vector - Vector to multiply with the matrix
 * @out result - Result of the matrix-vector multiplication
 */
void MatrixVectorMultiplyBlock(
    in vec4 col0, 
    in vec4 col1, 
    in vec4 col2, 
    in vec4 col3, 
    in vec4 vector, 
    out vec4 outResult)
{
    outResult.x = dot(col0, vector);
    outResult.y = dot(col1, vector);
    outResult.z = dot(col2, vector);
    outResult.w = dot(col3, vector);
}

#endif // MATRIX_OP_BLOCKS_H
