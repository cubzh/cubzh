// -------------------------------------------------------------
//  Cubzh Core
//  matrix4x4.h
//  Created by Adrien Duermael on April 17, 2016.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "float3.h"
#include "float4.h"

// matrix mode is column-major
// Note: column-row notation here (X:column, Y:row) ; as opposed to standard notation row-column such as Mij
// TODO: refacto this into row-column notation
typedef struct Matrix4x4 {
    float x1y1, x1y2, x1y3, x1y4, // 1st column
        x2y1, x2y2, x2y3, x2y4,   // 2nd column
        x3y1, x3y2, x3y3, x3y4,   // 3rd column
        x4y1, x4y2, x4y3, x4y4;   // 4th column
} Matrix4x4;

/// identity matrix
extern const Matrix4x4 matrix4x4_identity;

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
                         const float x4y4);

void matrix4x4_free(Matrix4x4 *m);

Matrix4x4 *matrix4x4_new_copy(const Matrix4x4 *m);

Matrix4x4 *matrix4x4_new_identity(void);

Matrix4x4 *matrix4x4_new_look_at(const float3 *eye, const float3 *center, const float3 *up);

void matrix4x4_set_look_at(Matrix4x4 *m, const float3 *eye, const float3 *center, const float3 *up);

Matrix4x4 *matrix4x4_new_off_center_orthographic(const float left,
                                                 const float right,
                                                 const float bottom,
                                                 const float top,
                                                 const float near,
                                                 const float far);
void matrix4x4_set_off_center_orthographic(Matrix4x4 *m,
                                           const float left,
                                           const float right,
                                           const float bottom,
                                           const float top,
                                           const float near,
                                           const float far);

Matrix4x4 *matrix4x4_new_translate(const float x, const float y, const float z);
void matrix4x4_set_translation(Matrix4x4 *m, const float x, const float y, const float z);

Matrix4x4 *matrix4x4_new_scale(const float3 *scale);
void matrix4x4_set_scale(Matrix4x4 *m, const float scale);
void matrix4x4_set_scaleXYZ(Matrix4x4 *m, const float x, const float y, const float z);
float matrix4x4_get_scale(const Matrix4x4 *m);
void matrix4x4_get_scaleXYZ(const Matrix4x4 *m, float3 *scale);

float matrix4x4_get_trace(const Matrix4x4 *m);

Matrix4x4 *matrix4x4_new_from_axis_rotation(const float radians,
                                            const float x,
                                            const float y,
                                            const float z);
void matrix4x4_set_from_axis_rotation(Matrix4x4 *m,
                                      const float radians,
                                      const float x,
                                      const float y,
                                      const float z);
Matrix4x4 *matrix4x4_new_from_euler_xyz(const float x, const float y, const float z);
void matrix4x4_set_from_euler_xyz(Matrix4x4 *m, const float x, const float y, const float z);
Matrix4x4 *matrix4x4_new_from_euler_zyx(const float x, const float y, const float z);
void matrix4x4_set_from_euler_zyx(Matrix4x4 *m, const float x, const float y, const float z);
Matrix4x4 *matrix4x4_new_rotation(const Matrix4x4 *m);
void matrix4x4_get_rotation(const Matrix4x4 *m, Matrix4x4 *rot);
void matrix4x4_get_euler(const Matrix4x4 *rot, float3 *euler);

/// sets matrix4x4 value to another matrix4x4 value
Matrix4x4 *matrix4x4_copy(Matrix4x4 *dest, const Matrix4x4 *src);

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
                   const float x4y4);

void matrix4x4_set_identity(Matrix4x4 *m);

Matrix4x4 *matrix4x4_op_multiply(Matrix4x4 *m1, const Matrix4x4 *m2);

Matrix4x4 *matrix4x4_op_multiply_2(const Matrix4x4 *m1, Matrix4x4 *m2);

void matrix4x4_op_multiply_vec(float4 *result, const float4 *vec, const Matrix4x4 *mtx);
void matrix4x4_op_multiply_vec_point(float3 *result, const float3 *vec, const Matrix4x4 *mtx);
void matrix4x4_op_multiply_vec_vector(float3 *result, const float3 *vec, const Matrix4x4 *mtx);

Matrix4x4 *matrix4x4_op_transpose(Matrix4x4 *m);

void *matrix4x4_op_invert(Matrix4x4 *m);

void matrix4x4_op_scale(Matrix4x4 *m, const float3 *scale);
void matrix4x4_op_unscale(Matrix4x4 *m, const float3 *scale);

#ifdef __cplusplus
} // extern "C"
#endif
