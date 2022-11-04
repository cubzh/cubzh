// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_filo_list_uint32.h
//  Created by Nino PLANE on October 18, 2022.
// -------------------------------------------------------------

#pragma once

#include "filo_list_uint32.h"

// functions that are NOT tested:
// filo_list_uint32_free
// filo_list_uint32_new

void test_filo_list_uint32_push(void) {
    FiloListUInt32 *uint32list = filo_list_uint32_new();

    uint32_t a = 0;
    uint32_t b = 0;

    filo_list_uint32_push(uint32list, a);
    filo_list_uint32_push(uint32list, b);

    filo_list_uint32_pop(uint32list, &a);
    a = 4294967295;
    filo_list_uint32_push(uint32list, a);
    filo_list_uint32_pop(uint32list, &b);
    TEST_CHECK(b == 4294967295);
    filo_list_uint32_free(uint32list);
}

void test_filo_list_uint32_pop(void) {
    FiloListUInt32 *uint32list = filo_list_uint32_new();

    uint32_t a = 1;
    uint32_t b = 2;
    uint32_t c = 3;

    filo_list_uint32_push(uint32list, a);
    filo_list_uint32_push(uint32list, b);
    filo_list_uint32_push(uint32list, c);

    TEST_CHECK(filo_list_uint32_pop(uint32list, &a));
    TEST_CHECK(a == 3);
    TEST_CHECK(filo_list_uint32_pop(uint32list, &b));
    TEST_CHECK(b == 2);
    TEST_CHECK(filo_list_uint32_pop(uint32list, &c));
    TEST_CHECK(c == 1);
    filo_list_uint32_free(uint32list);
}
