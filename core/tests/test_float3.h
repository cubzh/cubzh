// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_hash_uint32_int.h
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#pragma once

#include "float3.h"

#include "config.h"
#include "utils.h"

void test_float3_new(void) {
    float3 *f3 = float3_new(1.0f, 2.0f, 3.0f);
    TEST_CHECK(f3->x == 1.0f);
    TEST_CHECK(f3->y == 2.0f);
    TEST_CHECK(f3->z == 3.0f);
    const float3 expected = { 1.0f, 2.0f, 3.0f };
    TEST_CHECK(float3_isEqual(f3, &expected, EPSILON_ZERO));

    float3 *f0 = float3_new_zero();
    TEST_CHECK(f0->x == 0.0f);
    TEST_CHECK(f0->y == 0.0f);
    TEST_CHECK(f0->z == 0.0f);
    TEST_CHECK(float3_isZero(f0, EPSILON_ZERO));

    float3 *f1 = float3_new_one();
    TEST_CHECK(f1->x == 1.0f);
    TEST_CHECK(f1->y == 1.0f);
    TEST_CHECK(f1->z == 1.0f);

    float3_free(f3);
    float3_free(f0);
    float3_free(f1);
}

void test_float3_copy(void) {
    float3 *f3 = float3_new(5.0f, 7.0f, 11.0f);

    float3 *c = float3_new_zero();
    float3_copy(c, f3);

    const float3 expected1 = { 5.0f, 7.0f, 11.0f };
    TEST_CHECK(float3_isEqual(c, &expected1, EPSILON_ZERO));

    f3->x = 13.0f;
    f3->y = 17.0f;
    f3->z = 19.0f;
    const float3 expected2 = { 13.0f, 17.0f, 19.0f };
    TEST_CHECK(float3_isEqual(f3, &expected2, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(c, &expected1, EPSILON_ZERO));

    float3_free(f3);
    float3_free(c);
}

void test_float3_const(void) {
    const float3 expected_zero = {0.0f, 0.0f, 0.0f};
    const float3 expected_one = {1.0f, 1.0f, 1.0f};
    const float3 expected_right = {1.0f, 0.0f, 0.0f};
    const float3 expected_left = {-1.0f, 0.0f, 0.0f};
    const float3 expected_up = {0.0f, 1.0f, 0.0f};
    const float3 expected_down = {0.0f, -1.0f, 0.0f};
    const float3 expected_forward = {0.0f, 0.0f, 1.0f};
    const float3 expected_backward = {0.0f, 0.0f, -1.0f};

    TEST_CHECK(float3_isEqual(&float3_zero, &expected_zero, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&float3_one, &expected_one, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&float3_right, &expected_right, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&float3_left, &expected_left, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&float3_up, &expected_up, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&float3_down, &expected_down, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&float3_forward, &expected_forward, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&float3_backward, &expected_backward, EPSILON_ZERO));
}

void test_float3_products(void) {
    float3 *f1 = float3_new(1.0f, 2.0f, 3.0f);
    float3 *f2 = float3_new(1.0f, 5.0f, 7.0f);
    float3 *f3 = float3_new_zero();
    float3_copy(f3, f1);

    const float3 expected_cross = { -1.0f, -4.0f, 3.0f};
    float3_cross_product(f1, f2);
    TEST_CHECK(float3_isEqual(f1, &expected_cross, EPSILON_ZERO));

    const float expected_dot = 32.0f;
    const float result_dot = float3_dot_product(f3, f2);
    TEST_CHECK(float_isEqual(result_dot, expected_dot, EPSILON_ZERO) == true);

    float3_free(f1);
    float3_free(f2);
    float3_free(f3);
}

void test_float3_length(void) {
    {
        float3 *f1 = float3_new(3.0f, 4.0f, 12.0f);

        const float expected_length = 13.0f;
        const float result_length = float3_length(f1);
        TEST_CHECK(float_isEqual(result_length, expected_length, EPSILON_ZERO));
        float3_free(f1);
    }

    {
        float3 *f1 = float3_new(3.0f, 4.0f, 5.0f);

        const float expected_sqr_length = 50.0f;
        const float result_sqr_length = float3_sqr_length(f1);
        TEST_CHECK(float_isEqual(result_sqr_length, expected_sqr_length, EPSILON_ZERO));
        float3_free(f1);
    }

    {
        float3 *f1 = float3_new(12.0f, 3.0f, 4.0f);
        float3 *f2 = float3_new_zero();

        const float expected_dist = 13.0f;
        const float result_dist = float3_distance(f1, f2);
        TEST_CHECK(float_isEqual(result_dist, expected_dist, EPSILON_ZERO));
        float3_free(f1);
        float3_free(f2);
    }

    {
        float3 *f1 = float3_new(3.0f, 4.0f, 12.0f);
        float3_normalize(f1);

        const float3 expected_norm = { 3.0f / 13.0f, 4.0f / 13.0f, 12.0f / 13.0f };
        TEST_CHECK(float3_isEqual(f1, &expected_norm, EPSILON_ZERO));
        float3_free(f1);
    }

    {
        float3 *f1 = float3_new(7.0f, 9.0f, 11.0f);
        float3_set_norm(f1, 5.0f);

        TEST_CHECK(float_isEqual(float3_length(f1), 5.0f, EPSILON_ZERO));
        float3_free(f1);
    }
}

void test_float3_min_max(void) {
    float3 *f1 = float3_new(-5.0f, 1.0f, 100.0f);
    float3 *f2 = float3_new(2.0f, -50.0f, 6.0f);
    const float3 expected_max = { 2.0f, 1.0f, 100.0f };
    const float3 expected_min = { -5.0f, -50.0f, 6.0f };
    const float3 result_max = float3_mmax2(f1, f2);
    const float3 result_min = float3_mmin2(f1, f2);
    
    TEST_CHECK(float_isEqual(float3_mmax(f1), 100.0f, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&result_max, &expected_max, EPSILON_ZERO));
    TEST_CHECK(float_isEqual(float3_mmin(f1), -5.0f, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&result_min, &expected_min, EPSILON_ZERO));

    float3_free(f1);
    float3_free(f2);
}

void test_float3_operations(void) {
    {
        float3 *f1 = float3_new(5.0f, 9.0f, 11.0f);
        float3 *f2 = float3_new(13.0f, 17.0f, 19.0f);
        const float3 expected = { 18.0f, 26.0f, 30.0f };

        float3_op_add(f1, f2);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
        float3_free(f2);
    }
    
    {
        float3 *f1 = float3_new(5.0f, -9.0f, 11.0f);
        float scalar = 3.0f;
        const float3 expected = { 8.0f, -6.0f, 14.0f };

        float3_op_add_scalar(f1, scalar);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
    }

    {
        float3 *f1 = float3_new(5.0f, 9.0f, 11.0f);
        float3 *f2 = float3_new(13.0f, 17.0f, 11.0f);
        const float3 expected = { -8.0f, -8.0f, 0.0f };

        float3_op_substract(f1, f2);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
        float3_free(f2);
    }
    
    {
        float3 *f1 = float3_new(5.0f, -9.0f, 11.0f);
        float scalar = 3.0f;
        const float3 expected = { 2.0f, -12.0f, 8.0f };

        float3_op_substract_scalar(f1, scalar);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
    }

    {
        float3 *f1 = float3_new(-5.0f, 9.0f, -11.0f);
        float3 *f2 = float3_new(13.0f, -17.0f, -19.0f);
        const float3 expected = { -65.0f, -153.0f, 209.0f };

        float3_op_mult(f1, f2);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
        float3_free(f2);
    }
    
    {
        float3 *f1 = float3_new(5.0f, -9.0f, 11.0f);
        float scalar = 5.0f;
        const float3 expected = { 25.0f, -45.0f, 55.0f };

        float3_op_scale(f1, scalar);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
    }
    
    {
        float3 *f1 = float3_new(15.0f, -9.0f, 11.0f);
        float scalar = 3.0f;
        const float3 expected = { 5.0f, -3.0f, 11.0f / 3.0f };

        float3_op_unscale(f1, scalar);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
    }

    {
        float3 *f1 = float3_new(-105.0f, 56.0f, 30.0f);
        float min = -100.0f;
        float max = 35.0f;
        const float3 expected = { -100.0f, 35.0f, 30.f };

        float3_op_clamp(f1, min, max);
        TEST_CHECK(float3_isEqual(f1, &expected, EPSILON_ZERO));

        float3_free(f1);
    }
}
