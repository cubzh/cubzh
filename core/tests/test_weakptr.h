// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_weakptr.h
//  Created by Xavier Legland on October 19, 2022.
// -------------------------------------------------------------

#pragma once

#include "weakptr.h"

#include "float3.h"

// check that the pointer is stored
void test_weakptr_new(void) {
    float3 *f3 = float3_new_zero();
    Weakptr *wp = weakptr_new((void *)f3);

    TEST_CHECK((float3 *)weakptr_get(wp) == f3);

    float3_free(weakptr_get(wp));
    weakptr_release(wp);
}

// check that the pointer is not released right away
void test_weakptr_retain(void) {
    float3 *f3 = float3_new_zero();
    Weakptr *wp = weakptr_new((void *)f3); // 1

    const bool result = weakptr_retain(wp); // 2
    TEST_CHECK(result);

    weakptr_release(wp); // 1
    TEST_CHECK(weakptr_get(wp) != NULL);

    weakptr_release(wp); // 0
    float3_free(f3);
}

// check return values
void test_weakptr_release(void) {
    float3 *f3 = float3_new_zero();
    Weakptr *wp = weakptr_new((void *)f3); // 1
    weakptr_retain(wp);                    // 2

    bool freed = weakptr_release(wp); // 1
    TEST_CHECK(freed == false);       // released but not freed
    TEST_CHECK(weakptr_get(wp) != NULL);

    freed = weakptr_release(wp); // 0
    TEST_CHECK(freed);

    float3_free(f3);
}

// check that the pointer is the same
void test_weakptr_get(void) {
    float3 *f3 = float3_new(1.0f, 2.0f, 3.0f);
    Weakptr *wp = weakptr_new((void *)f3);

    TEST_CHECK(((float3 *)weakptr_get(wp))->x == 1.0f);
    TEST_CHECK(((float3 *)weakptr_get(wp))->y == 2.0f);
    TEST_CHECK(((float3 *)weakptr_get(wp))->z == 3.0f);

    weakptr_release(wp);
    float3_free(f3);
}

// release the Weakptr with weakptr_get_or_release
void test_weakptr_get_or_release(void) {
    Weakptr *wp = weakptr_new(NULL);
    void *result = weakptr_get_or_release(wp);

    TEST_CHECK(result == NULL);
}

// check that the stored value is set to NULL
void test_weakptr_invalidate(void) {
    float3 *f3 = float3_new_zero();
    Weakptr *wp = weakptr_new(f3);
    weakptr_retain(wp); // prevent wp from being freed
    weakptr_invalidate(wp);

    void *result = weakptr_get(wp);
    TEST_CHECK(result == NULL);

    float3_free(f3);
    weakptr_release(wp);
}
