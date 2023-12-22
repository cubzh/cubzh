// -------------------------------------------------------------
//  Cubzh Core
//  float3.h
//  Created by Adrien Duermael on July 19, 2015.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// C
#include <stdbool.h>

// float3 structure definition
typedef struct _float3 {
    /// value for the X axis
    float x; //  4 bytes
    /// value for the Y axis
    float y; //  4 bytes
    /// value for the Z axis
    float z; //  4 bytes
} float3;    // 12 bytes

static const float3 float3_zero = {0.0f, 0.0f, 0.0f};
static const float3 float3_one = {1.0f, 1.0f, 1.0f};
static const float3 float3_right = {1.0f, 0.0f, 0.0f};
static const float3 float3_left = {-1.0f, 0.0f, 0.0f};
static const float3 float3_up = {0.0f, 1.0f, 0.0f};
static const float3 float3_down = {0.0f, -1.0f, 0.0f};
static const float3 float3_forward = {0.0f, 0.0f, 1.0f};
static const float3 float3_backward = {0.0f, 0.0f, -1.0f};

// shared float3 pool to avoid allocations
float3 *float3_pool_pop(void);
float3 *float3_pool_pop_and_set(const float x, const float y, const float z);
float3 *float3_pool_pop_and_copy(const float3 *src);
void float3_pool_recycle(float3 *f3);

/// allocates a float3 structure
float3 *float3_new(const float x, const float y, const float z);
float3 *float3_new_zero(void);
float3 *float3_new_one(void);

/// allocates a float3 structure
float3 *float3_new_copy(const float3 *f);

/// free a float3 structure
void float3_free(float3 *f);

/// set float3 value to another float3 value
void float3_copy(float3 *dest, const float3 *src);

/// f1 = f1 X f2 (f1 is modified)
void float3_cross_product(float3 *f1, const float3 *f2);
void float3_cross_product2(const float3 *f1, float3 *f2);
float3 float3_cross_product3(const float3 *f1, const float3 *f2);

/// f1 • f2 dot product
float float3_dot_product(const float3 *const f1, const float3 *const f2);

/// computes and returns the square length of a float3 (cheaper than float3_length)
float float3_sqr_length(const float3 *f);

/// computes and returns the length of a float3
float float3_length(const float3 *f);
float float3_distance(const float3 *f1, const float3 *f2);

/// normalizes a float3
void float3_normalize(float3 *const f);

/// returns the member-wise max of a float3
float float3_mmax(const float3 *f);
float3 float3_mmax2(const float3 *f1, const float3 *f2);

/// returns the member-wise min of a float3
float float3_mmin(const float3 *f);
float3 float3_mmin2(const float3 *f1, const float3 *f2);

/** sets norm of a float3
 current norm has to be > 0. */
void float3_set_norm(float3 *f, float n);

/// sums two float3 (first argument is modified)
void float3_op_add(float3 *f1, const float3 *f2);
void float3_op_add_scalar(float3 *f3, const float f);

/// substract f2 from f1 (first argument is modified)
void float3_op_substract(float3 *f1, const float3 *f2);
void float3_op_substract_scalar(float3 *f3, const float f);

void float3_op_mult(float3 *f1, const float3 *f2);

/// multiplies float3 by a scale factor
void float3_op_scale(float3 *f, const float scale);
void float3_op_unscale(float3 *f, const float scale);

void float3_op_clamp(float3 *f, const float min, const float max);

void float3_rotate(float3 *f, const float rx, const float ry, const float rz);
void float3_rotate_around_axis(float3 *f, float3 *axis, const float angle);
float float3_angle_between(float3 *v1, float3 *v2);

/// changes value of a float3
void float3_set(float3 *f, const float x, const float y, const float z);
void float3_set_zero(float3 *f);
void float3_set_one(float3 *f);

///
void float3_lerp(const float3 *a, const float3 *b, const float t, float3 *res);

/// lerps with hsv colors where x, y and z are r, g and b for a and b
/// and x, y and z are h, s and v for res
// void float3_hsv_lerp(const float3 *a, const float3 *b, const float t, float3 *res);

///
bool float3_isEqual(const float3 *f3_1, const float3 *f3_2, const float epsilon);
bool float3_isZero(const float3 *f3, const float epsilon);
bool float3_is_valid(const float3 *f3);

#ifdef __cplusplus
} // extern "C"
#endif
