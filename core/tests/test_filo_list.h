// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_filo_list.h
//  Created by Nino PLANE on November 14, 2022.
// -------------------------------------------------------------

#pragma once

#include "filo_list.h"

// Create a list and check if it's empty
void test_filo_list_new(void) {
    FiloList *list = filo_list_new();
    void *ptrCheck;

    ptrCheck = filo_list_pop(list);
    TEST_CHECK(ptrCheck == NULL);

    filo_list_free(list);
}

// Create a list and push a node into it. Then pop the node to check if the pointer is the good one.
void test_filo_list_push(void) {
    FiloList *list = filo_list_new();
    int a = 10;
    int *aptr = &a;
    int *ptrCheck;

    filo_list_push(list, aptr);
    ptrCheck = (int *)filo_list_pop(list);
    TEST_CHECK(*ptrCheck == 10);

    filo_list_free(list);
}

// Create a list and push 3 differents nodes into it. After that we pop, one by one the nodes.
// Then at each step we check if the popped pointer is the right one.
void test_filo_list_pop(void) {
    FiloList *list = filo_list_new();
    int a = -10;
    int b = 10;
    int c = 0;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    int *ptrCheck;
    filo_list_push(list, aptr); // [-10]
    filo_list_push(list, bptr); // [-10, 10]
    filo_list_push(list, cptr); // [-10, 10, 0]

    ptrCheck = (int *)filo_list_pop(list);
    TEST_CHECK(*ptrCheck == 0);
    ptrCheck = (int *)filo_list_pop(list);
    TEST_CHECK(*ptrCheck == 10);
    ptrCheck = (int *)filo_list_pop(list);
    TEST_CHECK(*ptrCheck == -10);

    filo_list_free(list);
}
