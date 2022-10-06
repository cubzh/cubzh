// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_hash_uint32_int.h
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#pragma once

#include "hash_uint32_int.h"

void test_hash_uint32_int(void) {
    
    int v = 0;
    bool found = false;
    
    HashUInt32Int *h = hash_uint32_int_new();
    
    uint32_t key = 286331153; // 00010001000100010001000100010001
    hash_uint32_int_set(h, key, 42);
    found = hash_uint32_int_get(h, key, &v);
    TEST_CHECK(found == true);
    TEST_CHECK(v == 42);
    
    hash_uint32_int_set(h, 1, 1);
    found = hash_uint32_int_get(h, 1, &v);
    TEST_CHECK(found == true);
    TEST_CHECK(v == 1);
    
    hash_uint32_int_delete(h, 1);
    found = hash_uint32_int_get(h, 1, &v);
    TEST_CHECK(found == false);
    
    hash_uint32_int_set(h, 1, 3);
    found = hash_uint32_int_get(h, 1, &v);
    TEST_CHECK(found == true);
    TEST_CHECK(v == 3);
    
    hash_uint32_int_set(h, 1, 5);
    found = hash_uint32_int_get(h, 1, &v);
    TEST_CHECK(found == true);
    TEST_CHECK(v == 5);
    
    hash_uint32_int_set(h, 2, 7);
    found = hash_uint32_int_get(h, 2, &v);
    TEST_CHECK(found == true);
    TEST_CHECK(v == 7);
    
    found = hash_uint32_int_get(h, 3, &v);
    TEST_CHECK(found == false);
    
    hash_uint32_int_free(h);
}
