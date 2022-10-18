// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_int3.h
//  Created by Xavier Legland on October 17, 2022.
// -------------------------------------------------------------

#pragma once

#include "int3.h"

// functions that are NOT tested:
// int3_op_substract
// int3_op_div_int

// test that the first int3 is set to { 0, 0, 0 }
void test_int3_pool_pop(void) {
    int3* i3 = int3_pool_pop();

    TEST_CHECK(i3->x == 0);
    TEST_CHECK(i3->y == 0);
    TEST_CHECK(i3->z == 0);

    int3_free(i3);
}

// check that there is no crash
void test_int3_pool_recycle(void) {
    int3* a = int3_pool_pop();
    int3_pool_recycle(a);
    int3* b = int3_pool_pop();
    int3* c = int3_pool_pop();

    TEST_CHECK(b != NULL);
    TEST_CHECK(c != NULL);

    int3_pool_recycle(b);
    int3_pool_recycle(c);
}

// check that the values correspond to arguments
void test_int3_new(void) {
    int3* i3 = int3_new(4, 5, 6);

    TEST_CHECK(i3->x == 4);
    TEST_CHECK(i3->y == 5);
    TEST_CHECK(i3->z == 6);

    int3_free(i3);
}

// check that the values are independent
void test_int3_new_copy(void) {
    int3* source = int3_pool_pop();
    source->x = 2;
    int3* copy = int3_new_copy(source);

    TEST_CHECK(copy->x == 2);
    source->x = 10;
    TEST_CHECK(copy->x == 2);

    int3_free(source);
    int3_free(copy);
}

// check that the values correspond to arguments
void test_int3_set(void) {
    int3* i3 = int3_pool_pop();
    int3_set(i3, 7, 8, 9);

    TEST_CHECK(i3->x == 7);
    TEST_CHECK(i3->y == 8);
    TEST_CHECK(i3->z == 9);

    int3_free(i3);
}

// check that the values are independent
void test_int3_copy(void) {
    int3* source = int3_pool_pop();
    int3* copy = int3_pool_pop();
    source->x = 2;
    int3_copy(copy, source);

    TEST_CHECK(copy->x == 2);
    source->x = 10;
    TEST_CHECK(copy->x == 2);

    int3_free(source);
    int3_free(copy);
}

// check if the additions are correct
void test_int3_op_add(void) {
    int3* a = int3_pool_pop();
    int3* b = int3_pool_pop();
    a->x = -5;
    b->x = 1;
    a->y = 8;
    b->y = 16;
    a->z = 10;
    b->z = -10;
    int3_op_add(a, b);

    TEST_CHECK(a->x == -4);
    TEST_CHECK(a->y == 24);
    TEST_CHECK(a->z == 0);

    int3_free(a);
    int3_free(b);
}

// check if the additions are correct
void test_int3_op_add_int(void) {
    int3* i3 = int3_pool_pop();
    int3_set(i3, -10, 50, 40);
    int3_op_add_int(i3, 5);

    TEST_CHECK(i3->x == -5);
    TEST_CHECK(i3->y == 55);
    TEST_CHECK(i3->z == 45);

    int3_free(i3);
}

// check if the subtractions are correct
void test_int3_op_substract_int(void) {
    int3* i3 = int3_pool_pop();
    int3_set(i3, -10, 50, 40);
    int3_op_substract_int(i3, 5);

    TEST_CHECK(i3->x == -15);
    TEST_CHECK(i3->y == 45);
    TEST_CHECK(i3->z == 35);

    int3_free(i3);
}

// check if the correct value is chosen
void test_int3_op_min(void) {
    int3* i3 = int3_pool_pop();
    int3_set(i3, -20, 15, 15);
    int3_op_min(i3, -5, 5, 15);

    TEST_CHECK(i3->x == -20);
    TEST_CHECK(i3->y == 5);
    TEST_CHECK(i3->z == 15);

    int3_free(i3);
}

// check if the correct value is chosen
void test_int3_op_max(void) {
    int3* i3 = int3_pool_pop();
    int3_set(i3, -20, 15, 15);
    int3_op_max(i3, -5, 5, 15);

    TEST_CHECK(i3->x == -5);
    TEST_CHECK(i3->y == 15);
    TEST_CHECK(i3->z == 15);

    int3_free(i3);
}

// check if the operations are correct
void test_int3_op_div_ints(void) {
    int3* i3 = int3_pool_pop();
    int3_set(i3, -44, 21, 11);
    int3_op_div_ints(i3, 2, 3, 5);

    TEST_CHECK(i3->x == -22);
    TEST_CHECK(i3->y == 7);
    TEST_CHECK(i3->z == 2);

    int3_free(i3);
}
