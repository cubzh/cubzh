// -------------------------------------------------------------
//  Cubzh Core
//  quaternion.h
//  Created by Arthur Cormerais on january 27, 2021.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "matrix4x4.h"

#define DEBUG_QUATERNION_RUN_TESTS false

typedef struct _Quaternion Quaternion;

/// Note about normalization:
/// - all functions requiring a normalized quaternion will do it internally
/// - functions output can be unnormalized
///
/// Basic operations implementation come from the OpenGL holy-bible:
/// http://www.opengl-tutorial.org/assets/faq_quaternions/index.html#Q47
/// /!\ handedness in this ref is right
///
/// Our handedness : left
/// Our convention: yaw (Y), pitch (X), roll (Z)
/// Our euler order: XYZ (currently used), or ZYX (incomplete)
/// /!\ Check that a reference uses the same conventions as there are many possible combinations
struct _Quaternion {
    float x, y, z, w;
    bool normalized;
};

static const Quaternion quaternion_identity = {0.0f, 0.0f, 0.0f, 1.0f, true};

Quaternion *quaternion_new(const float x,
                           const float y,
                           const float z,
                           const float w,
                           const bool normalized);
Quaternion *quaternion_new_identity(void);
void quaternion_free(Quaternion *q);

void quaternion_set(Quaternion *q1, const Quaternion *q2);
void quaternion_set_identity(Quaternion *q);

float quaternion_magnitude(Quaternion *q);
float quaternion_square_magnitude(Quaternion *q);
float quaternion_angle(Quaternion *q);
bool quaternion_is_zero(Quaternion *q, float epsilon);
bool quaternion_is_normalized(Quaternion *q, float epsilon);
bool quaternion_is_equal(Quaternion *q1, Quaternion *q2, float epsilon);
float quaternion_angle_between(Quaternion *q1, Quaternion *q2);

Quaternion *quaternion_op_scale(Quaternion *q, float f);
Quaternion *quaternion_op_unscale(Quaternion *q, float f);
Quaternion *quaternion_op_conjugate(Quaternion *q);
Quaternion *quaternion_op_normalize(Quaternion *q);
Quaternion *quaternion_op_inverse(Quaternion *q);
Quaternion quaternion_op_mult(const Quaternion *q1, const Quaternion *q2);  // applies q2 then q1
Quaternion *quaternion_op_mult_left(Quaternion *q1, const Quaternion *q2);  // writes & returns q1
Quaternion *quaternion_op_mult_right(const Quaternion *q1, Quaternion *q2); // writes & returns q2
Quaternion *quaternion_op_lerp(const Quaternion *from,
                               const Quaternion *to,
                               Quaternion *lerped,
                               const float t);
float quaternion_op_dot(const Quaternion *q1, const Quaternion *q2);

void quaternion_to_rotation_matrix(Quaternion *q, Matrix4x4 *mtx);
void rotation_matrix_to_quaternion(const Matrix4x4 *mtx, Quaternion *q);
void quaternion_to_axis_angle(Quaternion *q, float3 *axis, float *angle);
void axis_angle_to_quaternion(float3 *axis, const float angle, Quaternion *q);
void quaternion_to_euler(Quaternion *q, float3 *euler);
void euler_to_quaternion(const float x, const float y, const float z, Quaternion *q);
void euler_to_quaternion_vec(const float3 *euler, Quaternion *q);

void quaternion_rotate_vector(Quaternion *q, float3 *v);
void quaternion_op_mult_euler(float3 *euler1, const float3 *euler2);
float4 *quaternion_to_float4(Quaternion *q);
Quaternion *quaternion_from_float4(float4 *f);

void quaternion_run_unit_tests(void);

#ifdef __cplusplus
} // extern "C"
#endif
