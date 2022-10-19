// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_float4.h
//  Created by Xavier Legland on October 17, 2022.
// -------------------------------------------------------------

#pragma once

#include "float4.h"

// functions that are NOT tested:
// float4_new_zero
// float4_new_copy
// float4_free
// float4_copy
// float4_set

void test_float4_new(void) {
    float4 *f4 = float4_new(1.0f, 2.0f, 3.0f, 4.0f);

    TEST_CHECK(f4->x == 1.0f);
    TEST_CHECK(f4->y == 2.0f);
    TEST_CHECK(f4->z == 3.0f);
    TEST_CHECK(f4->w == 4.0f);

    float4_free(f4);
}
