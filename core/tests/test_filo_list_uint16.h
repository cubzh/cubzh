// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_filo_list_int3.h
//  Created by Nino PLANE on October 18, 2022.
// -------------------------------------------------------------

#pragma once

#include "filo_list_uint16.h"

// functions that are NOT tested:
//filo_list_uint16_free
//filo_list_uint16_new

void test_filo_list_uint16_push(void) {
    FiloListUInt16* uint16list = filo_list_uint16_new();

    uint16_t a = 0;
    uint16_t b = 0;

    filo_list_uint16_push(uint16list, a);
    filo_list_uint16_push(uint16list, b);

    filo_list_uint16_pop(uint16list, &a);
    a = 65535;
    filo_list_uint16_push(uint16list, a);
    filo_list_uint16_pop(uint16list, &b);
    TEST_CHECK(b == 65535);
    filo_list_uint16_free(uint16list);
}

void test_filo_list_uint16_pop(void) {
    FiloListUInt16* uint16list = filo_list_uint16_new();

    uint16_t a = 1;
    uint16_t b = 2;
    uint16_t c = 3;

    filo_list_uint16_push(uint16list, a);
    filo_list_uint16_push(uint16list, b);
    filo_list_uint16_push(uint16list, c);

    TEST_CHECK(filo_list_uint16_pop(uint16list, &a));
    TEST_CHECK(a == 3);
    TEST_CHECK(filo_list_uint16_pop(uint16list, &b));
    TEST_CHECK(b == 2);
    TEST_CHECK(filo_list_uint16_pop(uint16list, &c));
    TEST_CHECK(c == 1);
    filo_list_uint16_free(uint16list);
}
