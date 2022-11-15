// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_quaternion.h
//  Created by Xavier Legland on October 18, 2022.
// -------------------------------------------------------------

#pragma once

#include "quaternion.h"

// functions that are NOT tested:
// quaternion_magnitude
// quaternion_angle
// quaternion_is_normalized
// quaternion_op_mult_left
// quaternion_op_mult_euler
// quaternion_to_float4
// quaternion_from_float4

// test that the the values are set
void test_quaternion_new(void) {
    Quaternion *q = quaternion_new(1.0f, 2.0f, 3.0f, 4.0f, false);

    TEST_CHECK(q->x == 1.0f);
    TEST_CHECK(q->y == 2.0f);
    TEST_CHECK(q->z == 3.0f);
    TEST_CHECK(q->w == 4.0f);
    TEST_CHECK(q->normalized == false);

    quaternion_free(q);
}

// check default values
void test_quaternion_new_identity(void) {
    Quaternion *q = quaternion_new_identity();

    TEST_CHECK(q->x == 0.0f);
    TEST_CHECK(q->y == 0.0f);
    TEST_CHECK(q->z == 0.0f);
    TEST_CHECK(q->w == 1.0f);
    TEST_CHECK(q->normalized);

    quaternion_free(q);
}

// check that the values are copied
void test_quaternion_set(void) {
    Quaternion *a = quaternion_new(1.0f, 2.0f, 3.0f, 4.0f, false);
    Quaternion *b = quaternion_new_identity();
    quaternion_set(b, a);

    TEST_CHECK(b->x == 1.0f);
    TEST_CHECK(b->y == 2.0f);
    TEST_CHECK(b->z == 3.0f);
    TEST_CHECK(b->w == 4.0f);
    TEST_CHECK(b->normalized == false);

    quaternion_free(a);
    quaternion_free(b);
}

// check default values
void test_quaternion_set_identity(void) {
    Quaternion *q = quaternion_new(1.0f, 2.0f, 3.0f, 4.0f, false);
    quaternion_set_identity(q);

    TEST_CHECK(q->x == 0.0f);
    TEST_CHECK(q->y == 0.0f);
    TEST_CHECK(q->z == 0.0f);
    TEST_CHECK(q->w == 1.0f);
    TEST_CHECK(q->normalized);

    quaternion_free(q);
}

// check that the result correspond to the expected value
void test_quaternion_square_magnitude(void) {
    Quaternion *q = quaternion_new(2.0f, 3.0f, 4.0f, 5.0f, false);
    const float result = quaternion_square_magnitude(q);
    const float expected = 54.0f;

    TEST_CHECK(float_isEqual(result, expected, EPSILON_QUATERNION_ERROR));

    quaternion_free(q);
}

// check on a zero and a non zero quaternion
void test_quaternion_is_zero(void) {
    Quaternion *a = quaternion_new(1.0f, 2.0f, 3.0f, 4.0f, false);
    Quaternion *b = quaternion_new_identity();

    TEST_CHECK(quaternion_is_zero(a, EPSILON_QUATERNION_ERROR) == false);
    TEST_CHECK(quaternion_is_zero(b, EPSILON_QUATERNION_ERROR));

    quaternion_free(a);
    quaternion_free(b);
}

// check that 2 identical quaternions are equal
void test_quaternion_is_equal(void) {
    Quaternion *a = quaternion_new(1.0f, 1.5f, -1.0f, 0.0f, false);
    Quaternion *b = quaternion_new(1.0f, 1.5f, -1.0f, 0.0f, false);

    TEST_CHECK(quaternion_is_equal(a, b, EPSILON_QUATERNION_ERROR));

    quaternion_free(a);
    quaternion_free(b);
}

// check the angle with 2 quaternions
void test_quaternion_angle_between(void) {
    // we set normalized to true even if it is not
    Quaternion *a = quaternion_new(1.0f, 0.0f, 0.0f, 0.25f, true);
    Quaternion *b = quaternion_new(-0.75, 0.0f, 0.0f, 1.0f, true);
    const float result = quaternion_angle_between(a, b);
    const float expected = 4.0f * PI_F / 3.0f;

    TEST_CHECK(float_isEqual(result, expected, EPSILON_QUATERNION_ERROR));

    quaternion_free(a);
    quaternion_free(b);
}

// check that scaling and unscaling does the same thing
void test_quaternion_op_scale(void) {
    Quaternion q1 = {2.0f, 3.0f, 4.0f, 5.0f, false};
    Quaternion q2 = quaternion_identity;
    quaternion_set(&q2, &q1);
    quaternion_op_unscale(quaternion_op_scale(&q2, .2f), .2f);
    Quaternion *q3 = quaternion_new(2.0f, 3.0f, 4.0f, 5.0f, false);
    quaternion_op_scale(q3, 3.0f);

    TEST_CHECK(quaternion_is_equal(&q1, &q2, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q3->x, 6.0f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q3->y, 9.0f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q3->z, 12.0f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q3->w, 15.0f, EPSILON_QUATERNION_ERROR));

    quaternion_free(q3);
}

// check values
void test_quaternion_op_unscale(void) {
    Quaternion *q = quaternion_new(1.0f, 2.0f, 3.0f, 4.0f, false);
    quaternion_op_unscale(q, 4.0f);

    TEST_CHECK(float_isEqual(q->x, 0.25f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q->y, 0.5f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q->z, 0.75f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q->w, 1.0f, EPSILON_QUATERNION_ERROR));

    quaternion_free(q);
}

// check that x, y and z are multiplied by -1
void test_quaternion_op_conjugate(void) {
    Quaternion *q = quaternion_new(1.0f, -2.0f, 3.0f, 4.0f, false);
    quaternion_op_conjugate(q);

    TEST_CHECK(float_isEqual(q->x, -1.0f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q->y, 2.0f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q->z, -3.0f, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(q->w, 4.0f, EPSILON_QUATERNION_ERROR));

    quaternion_free(q);
}

// check that the square magnitude is equal to 1
void test_quaternion_op_normalize(void) {
    Quaternion *q = quaternion_new(1.0f, -2.0f, 3.0f, 4.0f, false);
    quaternion_op_normalize(q);

    TEST_CHECK(float_isEqual(quaternion_square_magnitude(q), 1.0f, EPSILON_QUATERNION_ERROR));

    quaternion_free(q);
}

// check that inversing twice gives the same result
void test_quaternion_op_inverse(void) {
    Quaternion a = {2.0f, 3.0f, 4.0f, 5.0f, false};
    Quaternion b = quaternion_identity;
    quaternion_set(&b, &a);
    quaternion_op_inverse(quaternion_op_inverse(&b));

    TEST_CHECK(quaternion_is_equal(&a, &b, EPSILON_QUATERNION_ERROR));
}

// check that q * (1 / q) == q
void test_quaternion_op_mult(void) {
    const float3 f3 = {.x = 0.1f, .y = 0.3f, .z = 2.1f};
    Quaternion a = quaternion_identity;
    Quaternion b = quaternion_identity;
    Quaternion c = quaternion_identity;
    euler_to_quaternion_vec(&f3, &b);
    c = quaternion_op_mult(&a, &b);
    c = quaternion_op_mult(&c, quaternion_op_inverse(&b));
    Quaternion *d = quaternion_new(2.0f, 3.0f, 4.0f, 5.0f, true);
    Quaternion *e = quaternion_new(-7.0f, 8.0f, 9.0f, 1.0f, true);
    Quaternion result = quaternion_op_mult(d, e);
    Quaternion expected = {-38.0f, -3.0f, 86.0f, -41.0f, false};

    TEST_CHECK(quaternion_is_equal(&c, &a, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(quaternion_is_equal(&result, &expected, EPSILON_QUATERNION_ERROR));

    quaternion_free(d);
    quaternion_free(e);
}

// check with arbitrary values
void test_quaternion_op_mult_right(void) {
    Quaternion *a = quaternion_new(2.0f, 3.0f, 4.0f, 5.0f, true);
    Quaternion *b = quaternion_new(-7.0f, 8.0f, 9.0f, 1.0f, true);
    Quaternion expected = {-38.0f, -3.0f, 86.0f, -41.0f, false};
    quaternion_op_mult_right(a, b);

    TEST_CHECK(quaternion_is_equal(b, &expected, EPSILON_QUATERNION_ERROR));

    quaternion_free(a);
    quaternion_free(b);
}

// check that 0 gives start value and 1 gives end value
void test_quaternion_op_lerp(void) {
    Quaternion a = {-1.0f, 0.0f, 0.5f, 0.25f, false};
    Quaternion b = quaternion_identity;
    Quaternion c = quaternion_identity;
    Quaternion d = quaternion_identity;
    float3 f3;
    float3_set(&f3, 0.1f, 0.3f, 2.1f);
    euler_to_quaternion_vec(&f3, &b);
    quaternion_op_lerp(&a, &b, &c, 0.0f);
    quaternion_op_lerp(&a, &b, &d, 1.0f);
    Quaternion *e = quaternion_new(1.0f, 2.0f, 3.0f, 0.0f, false);
    Quaternion *f = quaternion_new_identity();
    Quaternion result;
    quaternion_op_lerp(e, f, &result, 0.5f);
    const Quaternion expected = {0.5f, 1.0f, 1.5f, 0.5f, false};

    TEST_CHECK(float_isEqual(c.x, a.x, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(c.y, a.y, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(c.z, a.z, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(c.w, a.w, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(quaternion_is_equal(&d, &b, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(result.x, expected.x, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(result.y, expected.y, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(result.z, expected.z, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(result.w, expected.w, EPSILON_QUATERNION_ERROR));

    quaternion_free(e);
    quaternion_free(f);
}

// check with arbitrary values
void test_quaternion_op_dot(void) {
    Quaternion *a = quaternion_new(1.0f, 2.0f, 3.0f, 4.0f, false);
    Quaternion *b = quaternion_new(5.0f, 6.0f, 7.0f, 8.0f, false);
    float result = quaternion_op_dot(a, b);
    float expected = 70.0f;

    TEST_CHECK(float_isEqual(result, expected, EPSILON_QUATERNION_ERROR));

    quaternion_free(a);
    quaternion_free(b);
}

// check that quaternion -> matrix -> quaternion gives the input value
void test_quaternion_to_rotation_matrix(void) {
    Quaternion a = quaternion_identity;
    Quaternion b = quaternion_identity;
    Matrix4x4 *mtx = matrix4x4_new_identity();
    float3 f3 = {9.2f, 1.5f, 0.8f};
    euler_to_quaternion_vec(&f3, &a);
    quaternion_to_rotation_matrix(&a, mtx);
    rotation_matrix_to_quaternion(mtx, &b);

    TEST_CHECK(quaternion_is_equal(&a, &b, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(mtx->x1y4 == 0.0f && mtx->x2y4 == 0.0f && mtx->x3y4 == 0.0f);
    TEST_CHECK(mtx->x4y1 == 0.0f && mtx->x4y2 == 0.0f && mtx->x4y3 == 0.0f);
    TEST_CHECK(mtx->x4y4 == 1.0f);

    matrix4x4_free(mtx);
}

// same tests as before
void test_rotation_matrix_to_quaternion(void) {
    Quaternion a = quaternion_identity;
    Quaternion b = quaternion_identity;
    Matrix4x4 *mtx = matrix4x4_new_identity();
    float3 f3 = {9.2f, 1.5f, 0.8f};
    euler_to_quaternion_vec(&f3, &a);
    quaternion_to_rotation_matrix(&a, mtx);
    rotation_matrix_to_quaternion(mtx, &b);

    TEST_CHECK(quaternion_is_equal(&a, &b, EPSILON_QUATERNION_ERROR));

    matrix4x4_free(mtx);
}

// check that quaternion -> angle -> quaternion gives the input value
void test_quaternion_to_axis_angle(void) {
    Quaternion q = quaternion_identity;
    float f;
    float3 a, b;
    axis_angle_to_quaternion(&a, 0.6f, &q);
    quaternion_to_axis_angle(&q, &b, &f);

    // TEST_CHECK(float3_isEqual(&a, &b, EPSILON_QUATERNION_ERROR));
    // TEST_CHECK(float_isEqual(f, 0.6f, EPSILON_QUATERNION_ERROR));
}

// same tests as before
void test_axis_angle_to_quaternion(void) {
    Quaternion q = quaternion_identity;
    float f;
    float3 a, b;
    axis_angle_to_quaternion(&a, 0.6f, &q);
    quaternion_to_axis_angle(&q, &b, &f);

    // TEST_CHECK(float3_isEqual(&a, &b, EPSILON_QUATERNION_ERROR));
    // TEST_CHECK(float_isEqual(f, 0.6f, EPSILON_QUATERNION_ERROR));
}

// check that quaternion -> euler -> quaternion gives the input value
void test_quaternion_to_euler(void) {
    Quaternion q = quaternion_identity;
    float3 a, b;
    float3_set(&a, 0.2f, 1.5f, 0.8f);
    euler_to_quaternion_vec(&a, &q);
    quaternion_to_euler(&q, &b);

    TEST_CHECK(float3_isEqual(&a, &b, EPSILON_QUATERNION_ERROR));
}

// same tests as before
void test_euler_to_quaternion(void) {
    Quaternion q = quaternion_identity;
    float3 a, b;
    float3_set(&a, 0.2f, 1.5f, 0.8f);
    euler_to_quaternion(a.x, a.y, a.z, &q);
    quaternion_to_euler(&q, &b);

    TEST_CHECK(float3_isEqual(&a, &b, EPSILON_QUATERNION_ERROR));
}

// same tests as before
void test_euler_to_quaternion_vec(void) {
    Quaternion q = quaternion_identity;
    float3 a, b;
    float3_set(&a, 0.2f, 1.5f, 0.8f);
    euler_to_quaternion_vec(&a, &q);
    quaternion_to_euler(&q, &b);

    TEST_CHECK(float3_isEqual(&a, &b, EPSILON_QUATERNION_ERROR));
}

// check that rot -> rot^-1 == rot
void test_quaternion_rotate_vector(void) {
    Quaternion q = {-1.0f, 0.0f, 0.5f, 0.25f, false};
    float3 a, b;
    float3_set(&a, 3.0f, -8.0f, 2.0f);
    float3_copy(&b, &a);
    quaternion_rotate_vector(&q, &b);
    quaternion_rotate_vector(quaternion_op_inverse(&q), &b);

    TEST_CHECK(float3_isEqual(&a, &b, EPSILON_QUATERNION_ERROR));
}

// legacy tests
void test_quaternion_coherence_check(void) {
    Quaternion q1 = quaternion_identity;
    Quaternion q2 = quaternion_identity;
    Quaternion q3 = quaternion_identity;
    Quaternion q4 = quaternion_identity;
    float f;
    float3 e1, e2, e3, e4;
    float3 v1, v2;
    Matrix4x4 *mtx1 = matrix4x4_new_identity();
    Matrix4x4 *mtx2 = matrix4x4_new_identity();

    float3_set(&e1, .2f, 1.5f, .8f);
    float3_set(&e2, .1f, .3f, 2.1f);
    float3_set(&v1, 3, -8, 2);
    float3_normalize(&v1);

    // Redundant checks
    // Euler
    euler_to_quaternion_vec(&e1, &q1);
    quaternion_to_euler(&q1, &e3);
    TEST_CHECK(float3_isEqual(&e1, &e3, EPSILON_QUATERNION_ERROR));

    // Rotation matrix
    quaternion_to_rotation_matrix(&q1, mtx1);
    rotation_matrix_to_quaternion(mtx1, &q2);
    TEST_CHECK(quaternion_is_equal(&q1, &q2, EPSILON_QUATERNION_ERROR));

    // Axis-angle
    axis_angle_to_quaternion(&v1, .6f, &q2);
    quaternion_to_axis_angle(&q2, &v2, &f);
    TEST_CHECK(float3_isEqual(&v1, &v2, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float_isEqual(f, .6f, EPSILON_QUATERNION_ERROR));

    // Inverse
    quaternion_set(&q2, &q1);
    quaternion_op_inverse(quaternion_op_inverse(&q2));
    TEST_CHECK(quaternion_is_equal(&q1, &q2, EPSILON_QUATERNION_ERROR));

    // Scale
    quaternion_set(&q2, &q1);
    quaternion_op_unscale(quaternion_op_scale(&q2, .2f), .2f);
    TEST_CHECK(quaternion_is_equal(&q1, &q2, EPSILON_QUATERNION_ERROR));

    // Mult
    euler_to_quaternion_vec(&e2, &q2);
    q3 = quaternion_op_mult(&q1, &q2);
    q3 = quaternion_op_mult(&q3, quaternion_op_inverse(&q2));
    TEST_CHECK(quaternion_is_equal(&q3, &q1, EPSILON_QUATERNION_ERROR));

    // Lerp
    euler_to_quaternion_vec(&e2, &q2);
    quaternion_op_lerp(&q1, &q2, &q3, 0.0f);
    TEST_CHECK(quaternion_is_equal(&q3, &q1, EPSILON_QUATERNION_ERROR));
    quaternion_op_lerp(&q1, &q2, &q3, 1.0f);
    TEST_CHECK(quaternion_is_equal(&q3, &q2, EPSILON_QUATERNION_ERROR));

    // Rotate
    float3_copy(&v2, &v1);
    quaternion_rotate_vector(&q1, &v2);
    quaternion_rotate_vector(quaternion_op_inverse(&q1), &v2);
    TEST_CHECK(float3_isEqual(&v1, &v2, EPSILON_QUATERNION_ERROR));

    // Singularities checks
    // TODO check every quarter-turn steps (not sure where our singularities are)

    // Error tolerance check
    // number of calculations could increase with scene depth, how deep can we go without
    // normalizing?
    /*quaternion_set(&q2, &q1);
     for (int i = 0; i < 200; ++i) {
     q2 = quaternion_op_mult(&q2, &q1);
     TEST_CHECK(quaternion_is_normalized(&q2, EPSILON_QUATERNION_ERROR) == true)
     }*/
    // on Android, answer is: 36 times

    // Quaternion & matrix coherence check
    q3 = quaternion_op_mult(&q1, &q2);

    quaternion_to_rotation_matrix(&q1, mtx1);
    quaternion_to_rotation_matrix(&q2, mtx2);
    matrix4x4_op_multiply(mtx1, mtx2);

    rotation_matrix_to_quaternion(mtx1, &q4);
    TEST_CHECK(quaternion_is_equal(&q4, &q3, EPSILON_QUATERNION_ERROR));

    quaternion_to_rotation_matrix(&q3, mtx2);
    matrix4x4_get_euler(mtx1, &e3);
    matrix4x4_get_euler(mtx2, &e4);
    TEST_CHECK(float3_isEqual(&e3, &e4, EPSILON_QUATERNION_ERROR));

    matrix4x4_free(mtx1);
    matrix4x4_free(mtx2);
}
