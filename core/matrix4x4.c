// -------------------------------------------------------------
//  Cubzh Core
//  matrix4x4.c
//  Created by Adrien Duermael on April 17, 2016.
// -------------------------------------------------------------

#include "matrix4x4.h"

#include <math.h>
#include <stdlib.h>

static float float4x4_cos, float4x4_cosp, float4x4_sin;
static float float4x4_s_length, float4x4_s_height, float4x4_s_depth;
static float3 float4x4_v, float4x4_vx, float4x4_vy, float4x4_vz;

Matrix4x4 *matrix4x4_new(const float x1y1,
                         const float x2y1,
                         const float x3y1,
                         const float x4y1,
                         const float x1y2,
                         const float x2y2,
                         const float x3y2,
                         const float x4y2,
                         const float x1y3,
                         const float x2y3,
                         const float x3y3,
                         const float x4y3,
                         const float x1y4,
                         const float x2y4,
                         const float x3y4,
                         const float x4y4) {

    Matrix4x4 *m = (Matrix4x4 *)malloc(sizeof(Matrix4x4));
    m->x1y1 = x1y1;
    m->x2y1 = x2y1;
    m->x3y1 = x3y1;
    m->x4y1 = x4y1;
    m->x1y2 = x1y2;
    m->x2y2 = x2y2;
    m->x3y2 = x3y2;
    m->x4y2 = x4y2;
    m->x1y3 = x1y3;
    m->x2y3 = x2y3;
    m->x3y3 = x3y3;
    m->x4y3 = x4y3;
    m->x1y4 = x1y4;
    m->x2y4 = x2y4;
    m->x3y4 = x3y4;
    m->x4y4 = x4y4;

    return m;
}

void matrix4x4_free(Matrix4x4 *m) {
    free(m);
}

Matrix4x4 *matrix4x4_new_copy(const Matrix4x4 *m) {
    if (m == NULL) {
        return NULL;
    }
    Matrix4x4 *mCopy = matrix4x4_new(m->x1y1,
                                     m->x2y1,
                                     m->x3y1,
                                     m->x4y1,
                                     m->x1y2,
                                     m->x2y2,
                                     m->x3y2,
                                     m->x4y2,
                                     m->x1y3,
                                     m->x2y3,
                                     m->x3y3,
                                     m->x4y3,
                                     m->x1y4,
                                     m->x2y4,
                                     m->x3y4,
                                     m->x4y4);
    return mCopy;
}

const Matrix4x4 matrix4x4_identity = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};

Matrix4x4 *matrix4x4_new_identity(void) {
    return matrix4x4_new(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
}

Matrix4x4 *matrix4x4_new_look_at(const float3 *eye, const float3 *center, const float3 *up) {
    Matrix4x4 *m = (Matrix4x4 *)malloc(sizeof(Matrix4x4));
    matrix4x4_set_look_at(m, eye, center, up);
    return m;
}

void matrix4x4_set_look_at(Matrix4x4 *m,
                           const float3 *eye,
                           const float3 *center,
                           const float3 *up) {
    float3_copy(&float4x4_vz, center);
    float3_op_substract(&float4x4_vz, eye);
    float3_normalize(&float4x4_vz);

    float3_copy(&float4x4_vx, up);
    float3_cross_product(&float4x4_vx, &float4x4_vz);
    float3_normalize(&float4x4_vx);

    float3_copy(&float4x4_vy, &float4x4_vz);
    float3_cross_product(&float4x4_vy, &float4x4_vx);
    // no need to normalize, because cross product of 2 normalized vectors
    // is a normalized vector
    // |a x b| = |a| x |b|

    m->x1y1 = float4x4_vx.x;
    m->x1y2 = float4x4_vy.x;
    m->x1y3 = float4x4_vz.x;
    m->x1y4 = 0.0;

    m->x2y1 = float4x4_vx.y;
    m->x2y2 = float4x4_vy.y;
    m->x2y3 = float4x4_vz.y;
    m->x2y4 = 0.0;

    m->x3y1 = float4x4_vx.z;
    m->x3y2 = float4x4_vy.z;
    m->x3y3 = float4x4_vz.z;
    m->x3y4 = 0.0;

    m->x4y1 = -float3_dot_product(&float4x4_vx, eye);
    m->x4y2 = -float3_dot_product(&float4x4_vy, eye);
    m->x4y3 = -float3_dot_product(&float4x4_vz, eye);
    m->x4y4 = 1.0;
}

Matrix4x4 *matrix4x4_new_off_center_orthographic(const float left,
                                                 const float right,
                                                 const float bottom,
                                                 const float top,
                                                 const float near,
                                                 const float far) {

    Matrix4x4 *m = (Matrix4x4 *)malloc(sizeof(Matrix4x4));
    matrix4x4_set_off_center_orthographic(m, left, right, bottom, top, near, far);
    return m;
}

void matrix4x4_set_off_center_orthographic(Matrix4x4 *m,
                                           const float left,
                                           const float right,
                                           const float bottom,
                                           const float top,
                                           const float near,
                                           const float far) {
    float4x4_s_length = 1.0f / (right - left);
    float4x4_s_height = 1.0f / (top - bottom);
    float4x4_s_depth = 1.0f / (far - near);

    m->x1y1 = float4x4_s_length * 2.0f;
    m->x1y2 = 0.0f;
    m->x1y3 = 0.0f;
    m->x1y4 = 0.0f;

    m->x2y1 = 0.0f;
    m->x2y2 = float4x4_s_height * 2.0f;
    m->x2y3 = 0.0f;
    m->x2y4 = 0.0f;

    m->x3y1 = 0.0f;
    m->x3y2 = 0.0f;
    m->x3y3 = float4x4_s_depth;
    m->x3y4 = 0.0f;

    m->x4y1 = -float4x4_s_length * (left + right);
    m->x4y2 = -float4x4_s_height * (top + bottom);
    m->x4y3 = -float4x4_s_depth * near;
    m->x4y4 = 1.0f;
}

void matrix4x4_set(Matrix4x4 *m,
                   const float x1y1,
                   const float x2y1,
                   const float x3y1,
                   const float x4y1,
                   const float x1y2,
                   const float x2y2,
                   const float x3y2,
                   const float x4y2,
                   const float x1y3,
                   const float x2y3,
                   const float x3y3,
                   const float x4y3,
                   const float x1y4,
                   const float x2y4,
                   const float x3y4,
                   const float x4y4) {

    m->x1y1 = x1y1;
    m->x2y1 = x2y1;
    m->x3y1 = x3y1;
    m->x4y1 = x4y1;
    m->x1y2 = x1y2;
    m->x2y2 = x2y2;
    m->x3y2 = x3y2;
    m->x4y2 = x4y2;
    m->x1y3 = x1y3;
    m->x2y3 = x2y3;
    m->x3y3 = x3y3;
    m->x4y3 = x4y3;
    m->x1y4 = x1y4;
    m->x2y4 = x2y4;
    m->x3y4 = x3y4;
    m->x4y4 = x4y4;
}

void matrix4x4_set_identity(Matrix4x4 *m) {
    matrix4x4_set(m, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
}

/// sets matrix4x4 value to another matrix4x4 value
Matrix4x4 *matrix4x4_copy(Matrix4x4 *dest, const Matrix4x4 *src) {

    dest->x1y1 = src->x1y1;
    dest->x2y1 = src->x2y1;
    dest->x3y1 = src->x3y1;
    dest->x4y1 = src->x4y1;

    dest->x1y2 = src->x1y2;
    dest->x2y2 = src->x2y2;
    dest->x3y2 = src->x3y2;
    dest->x4y2 = src->x4y2;

    dest->x1y3 = src->x1y3;
    dest->x2y3 = src->x2y3;
    dest->x3y3 = src->x3y3;
    dest->x4y3 = src->x4y3;

    dest->x1y4 = src->x1y4;
    dest->x2y4 = src->x2y4;
    dest->x3y4 = src->x3y4;
    dest->x4y4 = src->x4y4;

    return dest;
}

Matrix4x4 *matrix4x4_op_multiply(Matrix4x4 *m1, const Matrix4x4 *m2) {

    matrix4x4_set(
        m1,
        m1->x1y1 * m2->x1y1 + m1->x2y1 * m2->x1y2 + m1->x3y1 * m2->x1y3 + m1->x4y1 * m2->x1y4,
        m1->x1y1 * m2->x2y1 + m1->x2y1 * m2->x2y2 + m1->x3y1 * m2->x2y3 + m1->x4y1 * m2->x2y4,
        m1->x1y1 * m2->x3y1 + m1->x2y1 * m2->x3y2 + m1->x3y1 * m2->x3y3 + m1->x4y1 * m2->x3y4,
        m1->x1y1 * m2->x4y1 + m1->x2y1 * m2->x4y2 + m1->x3y1 * m2->x4y3 + m1->x4y1 * m2->x4y4,

        m1->x1y2 * m2->x1y1 + m1->x2y2 * m2->x1y2 + m1->x3y2 * m2->x1y3 + m1->x4y2 * m2->x1y4,
        m1->x1y2 * m2->x2y1 + m1->x2y2 * m2->x2y2 + m1->x3y2 * m2->x2y3 + m1->x4y2 * m2->x2y4,
        m1->x1y2 * m2->x3y1 + m1->x2y2 * m2->x3y2 + m1->x3y2 * m2->x3y3 + m1->x4y2 * m2->x3y4,
        m1->x1y2 * m2->x4y1 + m1->x2y2 * m2->x4y2 + m1->x3y2 * m2->x4y3 + m1->x4y2 * m2->x4y4,

        m1->x1y3 * m2->x1y1 + m1->x2y3 * m2->x1y2 + m1->x3y3 * m2->x1y3 + m1->x4y3 * m2->x1y4,
        m1->x1y3 * m2->x2y1 + m1->x2y3 * m2->x2y2 + m1->x3y3 * m2->x2y3 + m1->x4y3 * m2->x2y4,
        m1->x1y3 * m2->x3y1 + m1->x2y3 * m2->x3y2 + m1->x3y3 * m2->x3y3 + m1->x4y3 * m2->x3y4,
        m1->x1y3 * m2->x4y1 + m1->x2y3 * m2->x4y2 + m1->x3y3 * m2->x4y3 + m1->x4y3 * m2->x4y4,

        m1->x1y4 * m2->x1y1 + m1->x2y4 * m2->x1y2 + m1->x3y4 * m2->x1y3 + m1->x4y4 * m2->x1y4,
        m1->x1y4 * m2->x2y1 + m1->x2y4 * m2->x2y2 + m1->x3y4 * m2->x2y3 + m1->x4y4 * m2->x2y4,
        m1->x1y4 * m2->x3y1 + m1->x2y4 * m2->x3y2 + m1->x3y4 * m2->x3y3 + m1->x4y4 * m2->x3y4,
        m1->x1y4 * m2->x4y1 + m1->x2y4 * m2->x4y2 + m1->x3y4 * m2->x4y3 + m1->x4y4 * m2->x4y4);

    return m1;
}

Matrix4x4 *matrix4x4_op_multiply_2(const Matrix4x4 *m1, Matrix4x4 *m2) {

    matrix4x4_set(
        m2,
        m1->x1y1 * m2->x1y1 + m1->x2y1 * m2->x1y2 + m1->x3y1 * m2->x1y3 + m1->x4y1 * m2->x1y4,
        m1->x1y1 * m2->x2y1 + m1->x2y1 * m2->x2y2 + m1->x3y1 * m2->x2y3 + m1->x4y1 * m2->x2y4,
        m1->x1y1 * m2->x3y1 + m1->x2y1 * m2->x3y2 + m1->x3y1 * m2->x3y3 + m1->x4y1 * m2->x3y4,
        m1->x1y1 * m2->x4y1 + m1->x2y1 * m2->x4y2 + m1->x3y1 * m2->x4y3 + m1->x4y1 * m2->x4y4,

        m1->x1y2 * m2->x1y1 + m1->x2y2 * m2->x1y2 + m1->x3y2 * m2->x1y3 + m1->x4y2 * m2->x1y4,
        m1->x1y2 * m2->x2y1 + m1->x2y2 * m2->x2y2 + m1->x3y2 * m2->x2y3 + m1->x4y2 * m2->x2y4,
        m1->x1y2 * m2->x3y1 + m1->x2y2 * m2->x3y2 + m1->x3y2 * m2->x3y3 + m1->x4y2 * m2->x3y4,
        m1->x1y2 * m2->x4y1 + m1->x2y2 * m2->x4y2 + m1->x3y2 * m2->x4y3 + m1->x4y2 * m2->x4y4,

        m1->x1y3 * m2->x1y1 + m1->x2y3 * m2->x1y2 + m1->x3y3 * m2->x1y3 + m1->x4y3 * m2->x1y4,
        m1->x1y3 * m2->x2y1 + m1->x2y3 * m2->x2y2 + m1->x3y3 * m2->x2y3 + m1->x4y3 * m2->x2y4,
        m1->x1y3 * m2->x3y1 + m1->x2y3 * m2->x3y2 + m1->x3y3 * m2->x3y3 + m1->x4y3 * m2->x3y4,
        m1->x1y3 * m2->x4y1 + m1->x2y3 * m2->x4y2 + m1->x3y3 * m2->x4y3 + m1->x4y3 * m2->x4y4,

        m1->x1y4 * m2->x1y1 + m1->x2y4 * m2->x1y2 + m1->x3y4 * m2->x1y3 + m1->x4y4 * m2->x1y4,
        m1->x1y4 * m2->x2y1 + m1->x2y4 * m2->x2y2 + m1->x3y4 * m2->x2y3 + m1->x4y4 * m2->x2y4,
        m1->x1y4 * m2->x3y1 + m1->x2y4 * m2->x3y2 + m1->x3y4 * m2->x3y3 + m1->x4y4 * m2->x3y4,
        m1->x1y4 * m2->x4y1 + m1->x2y4 * m2->x4y2 + m1->x3y4 * m2->x4y3 + m1->x4y4 * m2->x4y4);

    return m2;
}

void matrix4x4_op_multiply_vec(float4 *result, const float4 *vec, const Matrix4x4 *mtx) {
    result->x = vec->x * mtx->x1y1 + vec->y * mtx->x2y1 + vec->z * mtx->x3y1 + vec->w * mtx->x4y1;
    result->y = vec->x * mtx->x1y2 + vec->y * mtx->x2y2 + vec->z * mtx->x3y2 + vec->w * mtx->x4y2;
    result->z = vec->x * mtx->x1y3 + vec->y * mtx->x2y3 + vec->z * mtx->x3y3 + vec->w * mtx->x4y3;
    result->w = vec->x * mtx->x1y4 + vec->y * mtx->x2y4 + vec->z * mtx->x3y4 + vec->w * mtx->x4y4;
}

void matrix4x4_op_multiply_vec_point(float3 *result, const float3 *vec, const Matrix4x4 *mtx) {
    result->x = vec->x * mtx->x1y1 + vec->y * mtx->x2y1 + vec->z * mtx->x3y1 + mtx->x4y1;
    result->y = vec->x * mtx->x1y2 + vec->y * mtx->x2y2 + vec->z * mtx->x3y2 + mtx->x4y2;
    result->z = vec->x * mtx->x1y3 + vec->y * mtx->x2y3 + vec->z * mtx->x3y3 + mtx->x4y3;
}

void matrix4x4_op_multiply_vec_vector(float3 *result, const float3 *vec, const Matrix4x4 *mtx) {
    result->x = vec->x * mtx->x1y1 + vec->y * mtx->x2y1 + vec->z * mtx->x3y1;
    result->y = vec->x * mtx->x1y2 + vec->y * mtx->x2y2 + vec->z * mtx->x3y2;
    result->z = vec->x * mtx->x1y3 + vec->y * mtx->x2y3 + vec->z * mtx->x3y3;
}

Matrix4x4 *matrix4x4_op_transpose(Matrix4x4 *m) {

    matrix4x4_set(m,
                  m->x1y1,
                  m->x1y2,
                  m->x1y3,
                  m->x1y4,
                  m->x2y1,
                  m->x2y2,
                  m->x2y3,
                  m->x2y4,
                  m->x3y1,
                  m->x3y2,
                  m->x3y3,
                  m->x3y4,
                  m->x4y1,
                  m->x4y2,
                  m->x4y3,
                  m->x4y4);

    return m;
}

//// if the matrix can't be inverted, given matrix
//// will remain unmodified
//// adapted from http://stackoverflow.com/a/1148405
void *matrix4x4_op_invert(Matrix4x4 *m) {

    float det;

    Matrix4x4 *m2 = matrix4x4_new_copy(m);

    m->x1y1 = m2->x2y2 * m2->x3y3 * m2->x4y4 - m2->x2y2 * m2->x3y4 * m2->x4y3 -
              m2->x3y2 * m2->x2y3 * m2->x4y4 + m2->x3y2 * m2->x2y4 * m2->x4y3 +
              m2->x4y2 * m2->x2y3 * m2->x3y4 - m2->x4y2 * m2->x2y4 * m2->x3y3;

    m->x2y1 = -m2->x2y1 * m2->x3y3 * m2->x4y4 + m2->x2y1 * m2->x3y4 * m2->x4y3 +
              m2->x3y1 * m2->x2y3 * m2->x4y4 - m2->x3y1 * m2->x2y4 * m2->x4y3 -
              m2->x4y1 * m2->x2y3 * m2->x3y4 + m2->x4y1 * m2->x2y4 * m2->x3y3;

    m->x3y1 = m2->x2y1 * m2->x3y2 * m2->x4y4 - m2->x2y1 * m2->x3y4 * m2->x4y2 -
              m2->x3y1 * m2->x2y2 * m2->x4y4 + m2->x3y1 * m2->x2y4 * m2->x4y2 +
              m2->x4y1 * m2->x2y2 * m2->x3y4 - m2->x4y1 * m2->x2y4 * m2->x3y2;

    m->x4y1 = -m2->x2y1 * m2->x3y2 * m2->x4y3 + m2->x2y1 * m2->x3y3 * m2->x4y2 +
              m2->x3y1 * m2->x2y2 * m2->x4y3 - m2->x3y1 * m2->x2y3 * m2->x4y2 -
              m2->x4y1 * m2->x2y2 * m2->x3y3 + m2->x4y1 * m2->x2y3 * m2->x3y2;

    m->x1y2 = -m2->x1y2 * m2->x3y3 * m2->x4y4 + m2->x1y2 * m2->x3y4 * m2->x4y3 +
              m2->x3y2 * m2->x1y3 * m2->x4y4 - m2->x3y2 * m2->x1y4 * m2->x4y3 -
              m2->x4y2 * m2->x1y3 * m2->x3y4 + m2->x4y2 * m2->x1y4 * m2->x3y3;

    m->x2y2 = m2->x1y1 * m2->x3y3 * m2->x4y4 - m2->x1y1 * m2->x3y4 * m2->x4y3 -
              m2->x3y1 * m2->x1y3 * m2->x4y4 + m2->x3y1 * m2->x1y4 * m2->x4y3 +
              m2->x4y1 * m2->x1y3 * m2->x3y4 - m2->x4y1 * m2->x1y4 * m2->x3y3;

    m->x3y2 = -m2->x1y1 * m2->x3y2 * m2->x4y4 + m2->x1y1 * m2->x3y4 * m2->x4y2 +
              m2->x3y1 * m2->x1y2 * m2->x4y4 - m2->x3y1 * m2->x1y4 * m2->x4y2 -
              m2->x4y1 * m2->x1y2 * m2->x3y4 + m2->x4y1 * m2->x1y4 * m2->x3y2;

    m->x4y2 = m2->x1y1 * m2->x3y2 * m2->x4y3 - m2->x1y1 * m2->x3y3 * m2->x4y2 -
              m2->x3y1 * m2->x1y2 * m2->x4y3 + m2->x3y1 * m2->x1y3 * m2->x4y2 +
              m2->x4y1 * m2->x1y2 * m2->x3y3 - m2->x4y1 * m2->x1y3 * m2->x3y2;

    m->x1y3 = m2->x1y2 * m2->x2y3 * m2->x4y4 - m2->x1y2 * m2->x2y4 * m2->x4y3 -
              m2->x2y2 * m2->x1y3 * m2->x4y4 + m2->x2y2 * m2->x1y4 * m2->x4y3 +
              m2->x4y2 * m2->x1y3 * m2->x2y4 - m2->x4y2 * m2->x1y4 * m2->x2y3;

    m->x2y3 = -m2->x1y1 * m2->x2y3 * m2->x4y4 + m2->x1y1 * m2->x2y4 * m2->x4y3 +
              m2->x2y1 * m2->x1y3 * m2->x4y4 - m2->x2y1 * m2->x1y4 * m2->x4y3 -
              m2->x4y1 * m2->x1y3 * m2->x2y4 + m2->x4y1 * m2->x1y4 * m2->x2y3;

    m->x3y3 = m2->x1y1 * m2->x2y2 * m2->x4y4 - m2->x1y1 * m2->x2y4 * m2->x4y2 -
              m2->x2y1 * m2->x1y2 * m2->x4y4 + m2->x2y1 * m2->x1y4 * m2->x4y2 +
              m2->x4y1 * m2->x1y2 * m2->x2y4 - m2->x4y1 * m2->x1y4 * m2->x2y2;

    m->x4y3 = -m2->x1y1 * m2->x2y2 * m2->x4y3 + m2->x1y1 * m2->x2y3 * m2->x4y2 +
              m2->x2y1 * m2->x1y2 * m2->x4y3 - m2->x2y1 * m2->x1y3 * m2->x4y2 -
              m2->x4y1 * m2->x1y2 * m2->x2y3 + m2->x4y1 * m2->x1y3 * m2->x2y2;

    m->x1y4 = -m2->x1y2 * m2->x2y3 * m2->x3y4 + m2->x1y2 * m2->x2y4 * m2->x3y3 +
              m2->x2y2 * m2->x1y3 * m2->x3y4 - m2->x2y2 * m2->x1y4 * m2->x3y3 -
              m2->x3y2 * m2->x1y3 * m2->x2y4 + m2->x3y2 * m2->x1y4 * m2->x2y3;

    m->x2y4 = m2->x1y1 * m2->x2y3 * m2->x3y4 - m2->x1y1 * m2->x2y4 * m2->x3y3 -
              m2->x2y1 * m2->x1y3 * m2->x3y4 + m2->x2y1 * m2->x1y4 * m2->x3y3 +
              m2->x3y1 * m2->x1y3 * m2->x2y4 - m2->x3y1 * m2->x1y4 * m2->x2y3;

    m->x3y4 = -m2->x1y1 * m2->x2y2 * m2->x3y4 + m2->x1y1 * m2->x2y4 * m2->x3y2 +
              m2->x2y1 * m2->x1y2 * m2->x3y4 - m2->x2y1 * m2->x1y4 * m2->x3y2 -
              m2->x3y1 * m2->x1y2 * m2->x2y4 + m2->x3y1 * m2->x1y4 * m2->x2y2;

    m->x4y4 = m2->x1y1 * m2->x2y2 * m2->x3y3 - m2->x1y1 * m2->x2y3 * m2->x3y2 -
              m2->x2y1 * m2->x1y2 * m2->x3y3 + m2->x2y1 * m2->x1y3 * m2->x3y2 +
              m2->x3y1 * m2->x1y2 * m2->x2y3 - m2->x3y1 * m2->x1y3 * m2->x2y2;

    det = m2->x1y1 * m->x1y1 + m2->x1y2 * m->x2y1 + m2->x1y3 * m->x3y1 + m2->x1y4 * m->x4y1;

    if (det == 0.0f) {
        // restore m using copy (m2)
        matrix4x4_copy(m, m2);
        free(m2);
        return m;
    }

    free(m2);

    det = 1.0f / det;

    m->x1y1 = m->x1y1 * det;
    m->x2y1 = m->x2y1 * det;
    m->x3y1 = m->x3y1 * det;
    m->x4y1 = m->x4y1 * det;

    m->x1y2 = m->x1y2 * det;
    m->x2y2 = m->x2y2 * det;
    m->x3y2 = m->x3y2 * det;
    m->x4y2 = m->x4y2 * det;

    m->x1y3 = m->x1y3 * det;
    m->x2y3 = m->x2y3 * det;
    m->x3y3 = m->x3y3 * det;
    m->x4y3 = m->x4y3 * det;

    m->x1y4 = m->x1y4 * det;
    m->x2y4 = m->x2y4 * det;
    m->x3y4 = m->x3y4 * det;
    m->x4y4 = m->x4y4 * det;

    return m;
}

void matrix4x4_op_scale(Matrix4x4 *m, const float3 *scale) {
    m->x1y1 *= scale->x;
    m->x2y1 *= scale->x;
    m->x3y1 *= scale->x;
    m->x4y1 *= scale->x;
    m->x1y2 *= scale->y;
    m->x2y2 *= scale->y;
    m->x3y2 *= scale->y;
    m->x4y2 *= scale->y;
    m->x1y3 *= scale->z;
    m->x2y3 *= scale->z;
    m->x3y3 *= scale->z;
    m->x4y3 *= scale->z;
}

void matrix4x4_op_unscale(Matrix4x4 *m, const float3 *scale) {
    m->x1y1 /= scale->x;
    m->x2y1 /= scale->x;
    m->x3y1 /= scale->x;
    m->x4y1 /= scale->x;
    m->x1y2 /= scale->y;
    m->x2y2 /= scale->y;
    m->x3y2 /= scale->y;
    m->x4y2 /= scale->y;
    m->x1y3 /= scale->z;
    m->x2y3 /= scale->z;
    m->x3y3 /= scale->z;
    m->x4y3 /= scale->z;
}

Matrix4x4 *matrix4x4_new_translate(const float x, const float y, const float z) {

    Matrix4x4 *m = matrix4x4_new_identity();
    m->x4y1 = x;
    m->x4y2 = y;
    m->x4y3 = z;

    return m;
}

void matrix4x4_set_translation(Matrix4x4 *m, const float x, const float y, const float z) {
    matrix4x4_set(m, 1, 0, 0, x, 0, 1, 0, y, 0, 0, 1, z, 0, 0, 0, 1);
}

Matrix4x4 *matrix4x4_new_scale(const float3 *scale) {
    return matrix4x4_new(scale->x, 0, 0, 0, 0, scale->y, 0, 0, 0, 0, scale->z, 0, 0, 0, 0, 1);
}

void matrix4x4_set_scale(Matrix4x4 *m, const float scale) {
    matrix4x4_set(m, scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1);
}

void matrix4x4_set_scaleXYZ(Matrix4x4 *m, const float x, const float y, const float z) {
    matrix4x4_set(m, x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0, 0, 0, 0, 1);
}

float matrix4x4_get_scale(const Matrix4x4 *m) {
    return sqrtf(m->x1y1 * m->x1y1 + m->x2y1 * m->x2y1 + m->x3y1 * m->x3y1);
}

void matrix4x4_get_scaleXYZ(const Matrix4x4 *m, float3 *scale) {
    scale->x = sqrtf(m->x1y1 * m->x1y1 + m->x2y1 * m->x2y1 + m->x3y1 * m->x3y1);
    scale->y = sqrtf(m->x1y2 * m->x1y2 + m->x2y2 * m->x2y2 + m->x3y2 * m->x3y2);
    scale->z = sqrtf(m->x1y3 * m->x1y3 + m->x2y3 * m->x2y3 + m->x3y3 * m->x3y3);
}

float matrix4x4_get_trace(const Matrix4x4 *m) {
    return m->x1y1 + m->x2y2 + m->x3y3 + m->x4y4;
}

Matrix4x4 *matrix4x4_new_from_axis_rotation(const float radians,
                                            const float x,
                                            const float y,
                                            const float z) {

    float3_set(&float4x4_v, x, y, z);
    float3_normalize(&float4x4_v);

    float4x4_cos = cosf(radians);
    float4x4_cosp = 1.0f - float4x4_cos;
    float4x4_sin = sinf(radians);

    Matrix4x4 *m = matrix4x4_new(
        float4x4_cos + float4x4_cosp * float4x4_v.x * float4x4_v.x,
        float4x4_cosp * float4x4_v.x * float4x4_v.y - float4x4_v.z * float4x4_sin,
        float4x4_cosp * float4x4_v.x * float4x4_v.z + float4x4_v.y * float4x4_sin,
        0.0,
        float4x4_cosp * float4x4_v.x * float4x4_v.y + float4x4_v.z * float4x4_sin,
        float4x4_cos + float4x4_cosp * float4x4_v.y * float4x4_v.y,
        float4x4_cosp * float4x4_v.y * float4x4_v.z - float4x4_v.x * float4x4_sin,
        0.0,
        float4x4_cosp * float4x4_v.x * float4x4_v.z - float4x4_v.y * float4x4_sin,
        float4x4_cosp * float4x4_v.y * float4x4_v.z + float4x4_v.x * float4x4_sin,
        float4x4_cos + float4x4_cosp * float4x4_v.z * float4x4_v.z,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0);

    return m;
}

void matrix4x4_set_from_axis_rotation(Matrix4x4 *m,
                                      const float radians,
                                      const float x,
                                      const float y,
                                      const float z) {

    float3_set(&float4x4_v, x, y, z);
    float3_normalize(&float4x4_v);

    float4x4_cos = cosf(radians);
    float4x4_cosp = 1.0f - float4x4_cos;
    float4x4_sin = sinf(radians);

    matrix4x4_set(m,
                  float4x4_cos + float4x4_cosp * float4x4_v.x * float4x4_v.x,
                  float4x4_cosp * float4x4_v.x * float4x4_v.y - float4x4_v.z * float4x4_sin,
                  float4x4_cosp * float4x4_v.x * float4x4_v.z + float4x4_v.y * float4x4_sin,
                  0.0,
                  float4x4_cosp * float4x4_v.x * float4x4_v.y + float4x4_v.z * float4x4_sin,
                  float4x4_cos + float4x4_cosp * float4x4_v.y * float4x4_v.y,
                  float4x4_cosp * float4x4_v.y * float4x4_v.z - float4x4_v.x * float4x4_sin,
                  0.0,
                  float4x4_cosp * float4x4_v.x * float4x4_v.z - float4x4_v.y * float4x4_sin,
                  float4x4_cosp * float4x4_v.y * float4x4_v.z + float4x4_v.x * float4x4_sin,
                  float4x4_cos + float4x4_cosp * float4x4_v.z * float4x4_v.z,
                  0.0,
                  0.0,
                  0.0,
                  0.0,
                  1.0);
}

Matrix4x4 *matrix4x4_new_from_euler_xyz(const float x, const float y, const float z) {
    Matrix4x4 *rot = matrix4x4_new_identity();
    matrix4x4_set_from_euler_xyz(rot, x, y, z);
    return rot;
}

/// ref: http://www.opengl-tutorial.org/assets/faq_quaternions/index.html#Q36
/// note: same implementation used in bx/math.cpp w/ mtxRotateXYZ
void matrix4x4_set_from_euler_xyz(Matrix4x4 *m, const float x, const float y, const float z) {
    const float a = cosf(x);
    const float b = sinf(x);
    const float c = cosf(y);
    const float d = sinf(y);
    const float e = cosf(z);
    const float f = sinf(z);

    const float ad = a * d;
    const float bd = b * d;

    matrix4x4_set(m,
                  c * e,
                  -c * f,
                  d,
                  0.0f,
                  bd * e + a * f,
                  -bd * f + a * e,
                  -b * c,
                  0.0f,
                  -ad * e + b * f,
                  ad * f + b * e,
                  a * c,
                  0.0f,
                  0.0f,
                  0.0f,
                  0.0f,
                  1.0f);
}

Matrix4x4 *matrix4x4_new_from_euler_zyx(const float x, const float y, const float z) {
    Matrix4x4 *rot = matrix4x4_new_identity();
    matrix4x4_set_from_euler_zyx(rot, x, y, z);
    return rot;
}

/// ref: http://www.opengl-tutorial.org/assets/faq_quaternions/index.html#Q36
/// note: same implementation used in bx/math.cpp w/ mtxRotateZYX
void matrix4x4_set_from_euler_zyx(Matrix4x4 *m, const float x, const float y, const float z) {
    const float a = cosf(x);
    const float b = sinf(x);
    const float c = cosf(y);
    const float d = sinf(y);
    const float e = cosf(z);
    const float f = sinf(z);

    const float ad = a * d;
    const float bd = b * d;

    matrix4x4_set(m,
                  c * e,
                  bd * e - a * f,
                  ad * e + b * f,
                  0.0f,
                  c * f,
                  bd * f + a * e,
                  ad * f - b * e,
                  0.0f,
                  -d,
                  b * c,
                  a * c,
                  0.0f,
                  0.0f,
                  0.0f,
                  0.0f,
                  1.0f);
}

Matrix4x4 *matrix4x4_new_rotation(const Matrix4x4 *m) {
    Matrix4x4 *rot = matrix4x4_new_identity();
    matrix4x4_get_rotation(m, rot);
    return rot;
}

void matrix4x4_get_rotation(const Matrix4x4 *m, Matrix4x4 *rot) {
    matrix4x4_copy(rot, m);

    // remove translation
    rot->x4y1 = rot->x4y2 = rot->x4y3 = 0.0f;

    // remove scale
    const float sx = sqrtf(m->x1y1 * m->x1y1 + m->x2y1 * m->x2y1 + m->x3y1 * m->x3y1);
    const float sy = sqrtf(m->x1y2 * m->x1y2 + m->x2y2 * m->x2y2 + m->x3y2 * m->x3y2);
    const float sz = sqrtf(m->x1y3 * m->x1y3 + m->x2y3 * m->x2y3 + m->x3y3 * m->x3y3);
    rot->x1y1 /= sx;
    rot->x2y1 /= sx;
    rot->x3y1 /= sx;
    rot->x1y2 /= sy;
    rot->x2y2 /= sy;
    rot->x3y2 /= sy;
    rot->x1y3 /= sz;
    rot->x2y3 /= sz;
    rot->x3y3 /= sz;
}

/// ref: http://www.opengl-tutorial.org/assets/faq_quaternions/index.html#Q37
/// @param rot rotation matrix (no scale, no translation)
/// @param euler output in radians
void matrix4x4_get_euler(const Matrix4x4 *rot, float3 *euler) {
    const float d = asinf(rot->x3y1);
    const float c = cosf(d);

    euler->y = d;

    if (fabsf(c) > .005f) {
        euler->x = atan2f(-rot->x3y2 / c, rot->x3y3 / c);
        euler->z = atan2f(-rot->x2y1 / c, rot->x1y1 / c);
    } else {
        euler->x = 0.0f;
        euler->z = atan2f(rot->x1y2, rot->x2y2);
    }

    // remap to [0:2PI]
    if (euler->x < 0)
        euler->x += (float)(2 * M_PI);
    if (euler->y < 0)
        euler->y += (float)(2 * M_PI);
    if (euler->z < 0)
        euler->z += (float)(2 * M_PI);

    // ref: https://www.geometrictools.com/Documentation/EulerAngles.pdf
    /*if (rot->x3y1 < 1.0f) {
        if (rot->x3y1 > -1.0f) {
            euler->y = asinf(rot->x3y1);
            euler->x = atan2f(-rot->x3y2, rot->x3y3);
            euler->z = atan2f(-rot->x2y1, rot->x1y1);
        } else {
            euler->y = -(float)M_PI_2;
            euler->x = -atan2f(rot->x1y2, rot->x2y2);
            euler->z = 0.0f;
        }
    } else {
        euler->y = (float)M_PI_2;
        euler->x = atan2f(rot->x1y2, rot->x2y2);
        euler->z = 0.0f;
    }*/
}

/// SRT matrix implementation based on bx/math.cpp mtxSRT (w/ transposed matrix)
Matrix4x4 *matrix4x4_new_SRT(float sx,
                             float sy,
                             float sz,
                             float ax,
                             float ay,
                             float az,
                             float tx,
                             float ty,
                             float tz) {
    const float a = sinf(ax);
    const float b = cosf(ax);
    const float c = sinf(ay);
    const float d = cosf(ay);
    const float e = sinf(az);
    const float f = cosf(az);

    const float ae = a * e;
    const float df = d * f;

    Matrix4x4 *m = matrix4x4_new(sx * (df - ae * c),
                                 sy * (f * a * c + d * e),
                                 sz * -b * c,
                                 tx,
                                 sx * -b * e,
                                 sy * b * f,
                                 sz * a,
                                 ty,
                                 sx * (f * c + d * ae),
                                 sy * (c * e - df * a),
                                 sz * b * d,
                                 tz,
                                 0.0f,
                                 0.0f,
                                 0.0f,
                                 1.0f);

    return m;
}
