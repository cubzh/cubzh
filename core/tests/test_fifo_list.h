// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_fifo_list.h
//  Created by Nino PLANE on November 14, 2022.
// -------------------------------------------------------------

#pragma once

#include "fifo_list.h"

// Function who are not tested :
// --- fifo_list_free()
// --- fifo_list_empty_freefunc()

// Create a new list and test if the base value are correct (list empty + size of 0)
void test_fifo_list_new(void) {
    FifoList *list = fifo_list_new();
    void *ptrCheck;
    uint32_t sizeCheck;

    ptrCheck = fifo_list_pop(list);
    TEST_CHECK(ptrCheck == NULL);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 0);

    fifo_list_free(list);
}

// Create a list and insert into it 3 differents nodes. Flush the list and check if the list is now
// empty.
void test_fifo_list_flush(void) {
    FifoList *list = fifo_list_new();
    int a = -10;
    int b = 10;
    int c = 0;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    void *ptrCheck;
    uint32_t sizeCheck;
    fifo_list_push(list, aptr); // [-10]
    fifo_list_push(list, bptr); // [-10, 10]
    fifo_list_push(list, cptr); // [-10, 10, 0]

    fifo_list_flush(list, fifo_list_empty_freefunc);
    ptrCheck = fifo_list_pop(list);
    TEST_CHECK(ptrCheck == NULL);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 0);

    fifo_list_free(list);
}

// Create a empty list and check the size of it. Add a node to the list and recheck it size.
// Flush the list and check it size a last time.
void test_fifo_list_get_size(void) {
    FifoList *list = fifo_list_new();
    int a = 10;
    int *aptr = &a;
    uint32_t sizeCheck;

    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 0);
    fifo_list_push(list, aptr);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 1);
    fifo_list_flush(list, fifo_list_empty_freefunc);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 0);

    fifo_list_free(list);
}

// Create a list and push 3 differents nodes into it. After that we pop, one by one the nodes.
// Then at each step check the size of the list and check if the popped pointer is the right one.
void test_fifo_list_pop(void) {
    FifoList *list = fifo_list_new();
    int a = -10;
    int b = 10;
    int c = 0;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    int *ptrCheck;
    uint32_t sizeCheck;
    fifo_list_push(list, aptr); // [-10]
    fifo_list_push(list, bptr); // [-10, 10]
    fifo_list_push(list, cptr); // [-10, 10, 0]

    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 3);
    ptrCheck = (int *)fifo_list_pop(list);
    TEST_CHECK(*ptrCheck == -10);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 2);
    ptrCheck = (int *)fifo_list_pop(list);
    TEST_CHECK(*ptrCheck == 10);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 1);
    ptrCheck = (int *)fifo_list_pop(list);
    TEST_CHECK(*ptrCheck == 0);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 0);

    fifo_list_free(list);
}

// Create a list and push a node into it. Then check the size and pop the node
// to check if the pointer is the good one.
void test_fifo_list_push(void) {
    FifoList *list = fifo_list_new();
    int a = 10;
    int *aptr = &a;
    int *ptrCheck;
    uint32_t sizeCheck;

    fifo_list_push(list, aptr);
    sizeCheck = fifo_list_get_size(list);
    TEST_CHECK(sizeCheck == 1);
    ptrCheck = (int *)fifo_list_pop(list);
    TEST_CHECK(*ptrCheck == 10);

    fifo_list_free(list);
}

// Create a new list and add some node into it. Then copy the list into a new one.
// After that check if all the values are copied in the new list.
void test_fifo_list_new_copy(void) {
    FifoList *list = fifo_list_new();
    int a = -10;
    int b = 10;
    int *aptr = &a;
    int *bptr = &b;
    int *ptrCheck;
    uint32_t sizeCheck;
    fifo_list_push(list, aptr);
    fifo_list_push(list, bptr);

    FifoList *listCopy = fifo_list_new_copy(list);
    sizeCheck = fifo_list_get_size(listCopy);
    TEST_CHECK(sizeCheck == 2);
    ptrCheck = (int *)fifo_list_pop(listCopy);
    TEST_CHECK(*ptrCheck == -10);
    ptrCheck = (int *)fifo_list_pop(listCopy);
    TEST_CHECK(*ptrCheck == 10);

    fifo_list_free(listCopy);
    fifo_list_free(list);
}
