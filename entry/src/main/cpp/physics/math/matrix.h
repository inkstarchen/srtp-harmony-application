//
// Created on 2026/3/6.
//
// Node APIs are not fully supported. To solve the compilation error of the interface cannot be found,
// please include "napi/native_api.h".

#ifndef DAYNOTE_MATRIX_H
#define DAYNOTE_MATRIX_H
#include "quaternion.h"
#include "vec.h"
struct Matrix3
{
    float m[3][3];

    Matrix3()
    {
        setIdentity();
    }

    Matrix3(
        float m00, float m01, float m02,
        float m10, float m11, float m12,
        float m20, float m21, float m22)
    {
        m[0][0] = m00; m[0][1] = m01; m[0][2] = m02;
        m[1][0] = m10; m[1][1] = m11; m[1][2] = m12;
        m[2][0] = m20; m[2][1] = m21; m[2][2] = m22;
    }

    static Matrix3 identity()
    {
        return Matrix3(
            1,0,0,
            0,1,0,
            0,0,1
        );
    }

    void setIdentity()
    {
        *this = identity();
    }
    
    Matrix3 operator+(const Matrix3& b) const
    {
        Matrix3 r;
    
        for(int i=0;i<3;i++)
            for(int j=0;j<3;j++)
                r.m[i][j] = m[i][j] + b.m[i][j];
    
        return r;
    }
    
    Matrix3 operator-(const Matrix3& b) const
    {
        Matrix3 r;
    
        for(int i=0;i<3;i++)
            for(int j=0;j<3;j++)
                r.m[i][j] = m[i][j] - b.m[i][j];
    
        return r;
    }
    
    Matrix3 operator*(float s) const
    {
        Matrix3 r;
    
        for(int i=0;i<3;i++)
            for(int j=0;j<3;j++)
                r.m[i][j] = m[i][j] * s;
    
        return r;
    }
    
    Matrix3 operator*(const Matrix3& b) const
    {
        Matrix3 r;
    
        for(int i=0;i<3;i++)
            for(int j=0;j<3;j++)
            {
                r.m[i][j] =
                    m[i][0] * b.m[0][j] +
                    m[i][1] * b.m[1][j] +
                    m[i][2] * b.m[2][j];
            }
    
        return r;
    }
    
    Vector3 operator*(const Vector3& v) const
    {
        Vector3 r;
    
        r.x = m[0][0]*v.x + m[0][1]*v.y + m[0][2]*v.z;
        r.y = m[1][0]*v.x + m[1][1]*v.y + m[1][2]*v.z;
        r.z = m[2][0]*v.x + m[2][1]*v.y + m[2][2]*v.z;
    
        return r;
    }
    
    Matrix3 transpose() const
    {
        Matrix3 r;
    
        for(int i=0;i<3;i++)
            for(int j=0;j<3;j++)
                r.m[i][j] = m[j][i];
    
        return r;
    }
    
    float determinant() const
    {
        return
            m[0][0]*(m[1][1]*m[2][2] - m[1][2]*m[2][1]) -
            m[0][1]*(m[1][0]*m[2][2] - m[1][2]*m[2][0]) +
            m[0][2]*(m[1][0]*m[2][1] - m[1][1]*m[2][0]);
    }
    
    Matrix3 inverse() const
    {
        float det = determinant();
    
        if(det == 0)
            return Matrix3();
    
        float invDet = 1.0f / det;
    
        Matrix3 r;
    
        r.m[0][0] =  (m[1][1]*m[2][2] - m[1][2]*m[2][1]) * invDet;
        r.m[0][1] = -(m[0][1]*m[2][2] - m[0][2]*m[2][1]) * invDet;
        r.m[0][2] =  (m[0][1]*m[1][2] - m[0][2]*m[1][1]) * invDet;
    
        r.m[1][0] = -(m[1][0]*m[2][2] - m[1][2]*m[2][0]) * invDet;
        r.m[1][1] =  (m[0][0]*m[2][2] - m[0][2]*m[2][0]) * invDet;
        r.m[1][2] = -(m[0][0]*m[1][2] - m[0][2]*m[1][0]) * invDet;
    
        r.m[2][0] =  (m[1][0]*m[2][1] - m[1][1]*m[2][0]) * invDet;
        r.m[2][1] = -(m[0][0]*m[2][1] - m[0][1]*m[2][0]) * invDet;
        r.m[2][2] =  (m[0][0]*m[1][1] - m[0][1]*m[1][0]) * invDet;
    
        return r;
    }
    

};

static Matrix3 skew(const Vector3& v)
{
    return Matrix3(
         0, -v.z,  v.y,
         v.z,  0, -v.x,
        -v.y, v.x,  0
    );
}

static Matrix3 quaternionToMatrix(const Quaternion& q)
{
    float x = q.x;
    float y = q.y;
    float z = q.z;
    float w = q.w;

    float xx = x * x;
    float yy = y * y;
    float zz = z * z;

    float xy = x * y;
    float xz = x * z;
    float yz = y * z;

    float wx = w * x;
    float wy = w * y;
    float wz = w * z;

    return Matrix3(
        1 - 2*(yy + zz), 2*(xy - wz),     2*(xz + wy),
        2*(xy + wz),     1 - 2*(xx + zz), 2*(yz - wx),
        2*(xz - wy),     2*(yz + wx),     1 - 2*(xx + yy)
    );
}

#endif //DAYNOTE_MATRIX_H
