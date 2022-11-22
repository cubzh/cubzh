// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_matrix4x4.h
//  Created by Xavier Legland on October 13, 2022.
// -------------------------------------------------------------

#pragma once

#include "matrix4x4.h"

// functions that are NOT tested:
// matrix4x4_new_look_at
// matrix4x4_new_from_axis_rotation
// matrix4x4_new_from_euler_xyz
// matrix4x4_set_from_euler_xyz
// matrix4x4_new_from_euler_zyx
// matrix4x4_set_from_euler_zyx
// matrix4x4_new_rotation
// matrix4x4_get_rotation
// matrix4x4_set_identity
// matrix4x4_op_multiply
// matrix4x4_op_scale

// check if all values are set correctly
void test_matrix4x4_new(void) {
    Matrix4x4 *m = matrix4x4_new(0.0f,
                                 1.0f,
                                 2.0f,
                                 3.0f,
                                 4.0f,
                                 5.0f,
                                 6.0f,
                                 7.0f,
                                 8.0f,
                                 9.0f,
                                 10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f);

    TEST_CHECK(m->x1y1 == 0.0f);
    TEST_CHECK(m->x2y1 == 1.0f);
    TEST_CHECK(m->x3y1 == 2.0f);
    TEST_CHECK(m->x4y1 == 3.0f);
    TEST_CHECK(m->x1y2 == 4.0f);
    TEST_CHECK(m->x2y2 == 5.0f);
    TEST_CHECK(m->x3y2 == 6.0f);
    TEST_CHECK(m->x4y2 == 7.0f);
    TEST_CHECK(m->x1y3 == 8.0f);
    TEST_CHECK(m->x2y3 == 9.0f);
    TEST_CHECK(m->x3y3 == 10.0f);
    TEST_CHECK(m->x4y3 == 11.0f);
    TEST_CHECK(m->x1y4 == 12.0f);
    TEST_CHECK(m->x2y4 == 13.0f);
    TEST_CHECK(m->x3y4 == 14.0f);
    TEST_CHECK(m->x4y4 == 15.0f);

    matrix4x4_free(m);
}

// check if the values are copied and do not depend on the source
void test_matrix4x4_new_copy(void) {
    Matrix4x4 *source = matrix4x4_new(1.0f,
                                      2.0f,
                                      3.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f,
                                      0.0f);
    Matrix4x4 *copy = matrix4x4_new_copy(source);
    TEST_CHECK(copy != NULL);

    // memory addresses must be different
    TEST_CHECK(source != copy);

    // copy values must be identical to source's
    TEST_CHECK(copy->x1y1 == source->x1y1 && copy->x2y1 == source->x2y1 && copy->x3y1 == source->x3y1);

    // modify source's values
    source->x1y1 = 4.0f;
    TEST_CHECK(source->x1y1 == 4.0f);

    // make sure copy has not changed
    TEST_CHECK(copy->x1y1 == 1.0f);

    matrix4x4_free(source);
    matrix4x4_free(copy);
}

// check that the numbers are correct
void test_matrix4x4_new_identity(void) {
    Matrix4x4 *m = matrix4x4_new_identity();

    TEST_CHECK(m->x1y1 == 1.0f && m->x2y2 == 1.0f && m->x3y3 == 1.0f && m->x4y4 == 1.0f);
    TEST_CHECK(m->x2y1 == 0.0f && m->x3y1 == 0.0f && m->x4y1 == 0.0f);
    TEST_CHECK(m->x1y2 == 0.0f && m->x3y2 == 0.0f && m->x4y2 == 0.0f);
    TEST_CHECK(m->x1y3 == 0.0f && m->x2y3 == 0.0f && m->x4y3 == 0.0f);
    TEST_CHECK(m->x1y4 == 0.0f && m->x2y4 == 0.0f && m->x3y4 == 0.0f);

    matrix4x4_free(m);
}

// check that the values are correct
void test_matrix4x4_new_off_center_orthographic(void) {
    const float l = -2.0f, r = 2.0f, b = 0.0f, t = 8.0f, n = 2.0f, f = 8.0f;
    Matrix4x4 *m = matrix4x4_new_off_center_orthographic(l, r, b, t, n, f);

    // check constants
    TEST_CHECK(m->x1y2 == 0.0f && m->x1y3 == 0.0f && m->x1y4 == 0.0f && m->x2y1 == 0.0f && m->x2y3 == 0.0f &&
               m->x2y4 == 0.0f && m->x3y1 == 0.0f && m->x3y2 == 0.0f && m->x3y4 == 0.0f && m->x4y4 == 1.0f);

    TEST_CHECK(float_isEqual(m->x1y1, 0.5f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x2y2, 0.25f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x3y3, 1.0f / 6.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x4y1, 0.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x4y2, -1.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x4y3, -1.0f / 3.0f, EPSILON_ZERO));

    matrix4x4_free(m);
}

// same tests as for new_off_center_orthographic
void test_matrix4x4_set_off_center_orthographic(void) {
    const float l = -2.0f, r = 2.0f, b = 0.0f, t = 8.0f, n = 2.0f, f = 8.0f;
    Matrix4x4 *m = matrix4x4_new_identity();
    matrix4x4_set_off_center_orthographic(m, l, r, b, t, n, f);

    TEST_CHECK(m->x1y2 == 0.0f && m->x1y3 == 0.0f && m->x1y4 == 0.0f && m->x2y1 == 0.0f && m->x2y3 == 0.0f &&
               m->x2y4 == 0.0f && m->x3y1 == 0.0f && m->x3y2 == 0.0f && m->x3y4 == 0.0f && m->x4y4 == 1.0f);

    TEST_CHECK(float_isEqual(m->x1y1, 0.5f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x2y2, 0.25f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x3y3, 1.0f / 6.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x4y1, 0.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x4y2, -1.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x4y3, -1.0f / 3.0f, EPSILON_ZERO));

    matrix4x4_free(m);
}

// check values
void test_matrix4x4_new_translate(void) {
    Matrix4x4 *m = matrix4x4_new_translate(55.0f, 66.0f, 77.0f);

    TEST_CHECK(m->x4y1 == 55.0f && m->x4y2 == 66.0f && m->x4y3 == 77.0f);
    // same check as for identity without the above values
    TEST_CHECK(m->x1y1 == 1.0f && m->x2y2 == 1.0f && m->x3y3 == 1.0f && m->x4y4 == 1.0f);
    TEST_CHECK(m->x2y1 == 0.0f && m->x3y1 == 0.0f);
    TEST_CHECK(m->x1y2 == 0.0f && m->x3y2 == 0.0f);
    TEST_CHECK(m->x1y3 == 0.0f && m->x2y3 == 0.0f);
    TEST_CHECK(m->x1y4 == 0.0f && m->x2y4 == 0.0f && m->x3y4 == 0.0f);

    matrix4x4_free(m);
}

// same tests as for new_translate
void test_matrix4x4_set_translation(void) {
    Matrix4x4 *m = matrix4x4_new(0.0f,
                                 1.0f,
                                 2.0f,
                                 3.0f,
                                 4.0f,
                                 5.0f,
                                 6.0f,
                                 7.0f,
                                 8.0f,
                                 9.0f,
                                 10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f);
    matrix4x4_set_translation(m, 55.0f, 66.0f, 77.0f);

    TEST_CHECK(m->x4y1 == 55.0f && m->x4y2 == 66.0f && m->x4y3 == 77.0f);
    // same check as for identity without the above values
    TEST_CHECK(m->x1y1 == 1.0f && m->x2y2 == 1.0f && m->x3y3 == 1.0f && m->x4y4 == 1.0f);
    TEST_CHECK(m->x2y1 == 0.0f && m->x3y1 == 0.0f);
    TEST_CHECK(m->x1y2 == 0.0f && m->x3y2 == 0.0f);
    TEST_CHECK(m->x1y3 == 0.0f && m->x2y3 == 0.0f);
    TEST_CHECK(m->x1y4 == 0.0f && m->x2y4 == 0.0f && m->x3y4 == 0.0f);

    matrix4x4_free(m);
}

// check values
void test_matrix4x4_new_scale(void) {
    const float x = 11.0f, y = 22.0f, z = 33.0f;
    const float3 scale = {x, y, z};
    Matrix4x4 *m = matrix4x4_new_scale(&scale);

    TEST_CHECK(m->x1y1 == x && m->x2y2 == y && m->x3y3 == z && m->x4y4 == 1.0f);
    TEST_CHECK(m->x2y1 == 0.0f && m->x3y1 == 0.0f && m->x4y1 == 0.0f);
    TEST_CHECK(m->x1y2 == 0.0f && m->x3y2 == 0.0f && m->x4y2 == 0.0f);
    TEST_CHECK(m->x1y3 == 0.0f && m->x2y3 == 0.0f && m->x4y3 == 0.0f);
    TEST_CHECK(m->x1y4 == 0.0f && m->x2y4 == 0.0f && m->x3y4 == 0.0f);

    matrix4x4_free(m);
}

// same tests as for new_scale
void test_matrix4x4_set_scale(void) {
    const float scale = 13.0f;
    Matrix4x4 *m = matrix4x4_new_identity();
    matrix4x4_set_scale(m, scale);

    TEST_CHECK(m->x1y1 == scale && m->x2y2 == scale && m->x3y3 == scale && m->x4y4 == 1.0f);
    TEST_CHECK(m->x2y1 == 0.0f && m->x3y1 == 0.0f && m->x4y1 == 0.0f);
    TEST_CHECK(m->x1y2 == 0.0f && m->x3y2 == 0.0f && m->x4y2 == 0.0f);
    TEST_CHECK(m->x1y3 == 0.0f && m->x2y3 == 0.0f && m->x4y3 == 0.0f);
    TEST_CHECK(m->x1y4 == 0.0f && m->x2y4 == 0.0f && m->x3y4 == 0.0f);

    matrix4x4_free(m);
}

// check the scale values
void test_matrix4x4_set_scaleXYZ(void) {
    const float x = 11.0f, y = 22.0f, z = 33.0f;
    Matrix4x4 *m = matrix4x4_new_identity();
    matrix4x4_set_scaleXYZ(m, x, y, z);

    TEST_CHECK(m->x1y1 == x && m->x2y2 == y && m->x3y3 == z && m->x4y4 == 1.0f);
    TEST_CHECK(m->x2y1 == 0.0f && m->x3y1 == 0.0f && m->x4y1 == 0.0f);
    TEST_CHECK(m->x1y2 == 0.0f && m->x3y2 == 0.0f && m->x4y2 == 0.0f);
    TEST_CHECK(m->x1y3 == 0.0f && m->x2y3 == 0.0f && m->x4y3 == 0.0f);
    TEST_CHECK(m->x1y4 == 0.0f && m->x2y4 == 0.0f && m->x3y4 == 0.0f);

    matrix4x4_free(m);
}

// check the scale
void test_matrix4x4_get_scale(void) {
    const float scale = 13.0f;
    Matrix4x4 *m = matrix4x4_new_identity();
    matrix4x4_set_scale(m, scale);

    const float result = matrix4x4_get_scale(m);
    TEST_CHECK(float_isEqual(scale, result, EPSILON_ZERO));

    matrix4x4_free(m);
}

// check the scale values
void test_matrix4x4_get_scaleXYZ(void) {
    Matrix4x4 *m = matrix4x4_new(3.0f,
                                 4.0f,
                                 12.0f,
                                 3.0f,
                                 4.0f,
                                 3.0f,
                                 12.0f,
                                 7.0f,
                                 0.0f,
                                 0.0f,
                                 0.0f,
                                 11.0f,
                                 -12.0f,
                                 -13.0f,
                                 -14.0f,
                                 -15.0f);
    float3 f3 = {1.0f, 2.0f, 3.0f};
    const float3 expected = {13.0f, 13.0f, 0.0f};

    matrix4x4_get_scaleXYZ(m, &f3);
    TEST_CHECK(float3_isEqual(&f3, &expected, EPSILON_ZERO));

    matrix4x4_free(m);
}

// check the trace value
void test_matrix4x4_get_trace(void) {
    Matrix4x4 *m = matrix4x4_new_identity();
    m->x1y1 = 2.0f;
    m->x2y2 = 3.0f;
    m->x3y3 = 4.0f;
    m->x4y4 = 5.0f;

    TEST_CHECK(float_isEqual(matrix4x4_get_trace(m), 14.0f, EPSILON_ZERO));

    matrix4x4_free(m);
}

// find the given angle
void test_matrix4x4_get_euler(void) {
    Matrix4x4 *m = matrix4x4_new_from_euler_xyz(PI_F * 0.5f, 0.0f, 0.0f);
    float3 result = {0.0f, 0.0f, 0.0f};
    const float3 expected = {PI_F * 0.5f, 0.0f, 0.0f};

    matrix4x4_get_euler(m, &result);
    TEST_CHECK(float3_isEqual(&result, &expected, EPSILON_ZERO_RAD));

    matrix4x4_free(m);
}

// check that modifying the source does not affect the copy
void test_matrix4x4_copy(void) {
    Matrix4x4 *source = matrix4x4_new_identity();
    Matrix4x4 *copy = matrix4x4_new_identity();
    source->x1y1 = 10.0f;
    source->x1y2 = 20.0f;
    source->x1y3 = 30.0f;
    source->x1y4 = 40.0f;

    matrix4x4_copy(copy, source);
    TEST_CHECK(copy->x1y1 == 10.0f && copy->x1y2 == 20.0f && copy->x1y3 == 30.0f && copy->x1y4 == 40.0f);
    source->x1y1 = 15.0f;
    TEST_CHECK(copy->x1y1 != 15.0f);

    matrix4x4_free(source);
    matrix4x4_free(copy);
}

// check abritrary values form result
void test_matrix4x4_op_multiply_2(void) {
    Matrix4x4 *a = matrix4x4_new(0.0f,
                                 1.0f,
                                 2.0f,
                                 3.0f,
                                 4.0f,
                                 5.0f,
                                 6.0f,
                                 7.0f,
                                 8.0f,
                                 9.0f,
                                 10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f);
    Matrix4x4 *b = matrix4x4_new(10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f,
                                 16.0f,
                                 17.0f,
                                 18.0f,
                                 19.0f,
                                 20.0f,
                                 21.0f,
                                 22.0f,
                                 23.0f,
                                 24.0f,
                                 25.0f);

    matrix4x4_op_multiply_2(a, b);
    TEST_CHECK(float_isEqual(b->x1y1, 116.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(b->x4y1, 134.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(b->x4y4, 1046.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(b->x2y3, 666.0f, EPSILON_ZERO));

    matrix4x4_free(a);
    matrix4x4_free(b);
}

// check all result values
void test_matrix4x4_op_multiply_vec(void) {
    Matrix4x4 *m = matrix4x4_new(0.0f,
                                 1.0f,
                                 2.0f,
                                 3.0f,
                                 4.0f,
                                 5.0f,
                                 6.0f,
                                 7.0f,
                                 8.0f,
                                 9.0f,
                                 10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f);
    const float4 multiplier = {2.0f, 3.0f, 4.0f, 5.0f};
    float4 result = {0.0f, 0.0f, 0.0f, 0.0f};

    matrix4x4_op_multiply_vec(&result, &multiplier, m);
    TEST_CHECK(float_isEqual(result.x, 26.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(result.y, 82.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(result.z, 138.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(result.w, 194.0f, EPSILON_ZERO));

    matrix4x4_free(m);
}

// check all result values
void test_matrix4x4_op_multiply_vec_point(void) {
    Matrix4x4 *m = matrix4x4_new(0.0f,
                                 1.0f,
                                 2.0f,
                                 3.0f,
                                 4.0f,
                                 5.0f,
                                 6.0f,
                                 7.0f,
                                 8.0f,
                                 9.0f,
                                 10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f);
    const float3 multiplier = {2.0f, 3.0f, 4.0f};
    float3 result = {0.0f, 0.0f, 0.0f};

    matrix4x4_op_multiply_vec_point(&result, &multiplier, m);
    TEST_CHECK(float_isEqual(result.x, 14.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(result.y, 54.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(result.z, 94.0f, EPSILON_ZERO));

    matrix4x4_free(m);
}

// check all result values
void test_matrix4x4_op_multiply_vec_vector(void) {
    Matrix4x4 *m = matrix4x4_new(0.0f,
                                 1.0f,
                                 2.0f,
                                 3.0f,
                                 4.0f,
                                 5.0f,
                                 6.0f,
                                 7.0f,
                                 8.0f,
                                 9.0f,
                                 10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f);
    const float3 multiplier = {2.0f, 3.0f, 4.0f};
    float3 result = {0.0f, 0.0f, 0.0f};

    matrix4x4_op_multiply_vec_vector(&result, &multiplier, m);
    TEST_CHECK(float_isEqual(result.x, 11.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(result.y, 47.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(result.z, 83.0f, EPSILON_ZERO));

    matrix4x4_free(m);
}

// check first row
void test_matrix4x4_op_invert(void) {
    Matrix4x4 *m = matrix4x4_new(10.0f,
                                 11.0f,
                                 -412.0f,
                                 513.0f,
                                 14.0f,
                                 -315.0f,
                                 216.0f,
                                 17.0f,
                                 118.0f,
                                 19.0f,
                                 20.0f,
                                 -321.0f,
                                 22.0f,
                                 -423.0f,
                                 24.0f,
                                 25.0f);

    matrix4x4_op_invert(m);
    TEST_CHECK(float_isEqual(m->x1y1, 0.00510333665f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x1y2, 0.000382280559f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x1y3, 7.69150647e-05f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x1y4, 0.00190341240f, EPSILON_ZERO));

    matrix4x4_free(m);
}

// check second column
void test_matrix4x4_op_unscale(void) {
    Matrix4x4 *m = matrix4x4_new(0.0f,
                                 1.0f,
                                 2.0f,
                                 3.0f,
                                 4.0f,
                                 5.0f,
                                 6.0f,
                                 7.0f,
                                 8.0f,
                                 9.0f,
                                 10.0f,
                                 11.0f,
                                 12.0f,
                                 13.0f,
                                 14.0f,
                                 15.0f);
    const float3 scale = {2.0f, 3.0f, 4.0f};

    matrix4x4_op_unscale(m, &scale);
    TEST_CHECK(float_isEqual(m->x2y1, 0.5f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x2y2, 5.0f / 3.0f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x2y3, 2.25f, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(m->x2y4, 13.0f, EPSILON_ZERO));

    matrix4x4_free(m);
}
