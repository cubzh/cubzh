// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_float3.h
//  Created by Nino PLANE on October 18, 2022.
// -------------------------------------------------------------

#pragma once

#include "filo_list_float3.h"

// function that are NOT tested:
// filo_list_float3_new
// filo_list_float3_free

void test_filo_list_float3_pop(void) {
    FiloListFloat3Node* float3list = filo_list_float3_new(3);
    float3* a;
    float3* b;
    float3* c;

    TEST_CHECK(filo_list_float3_pop(float3list, &a));
    TEST_CHECK(a->x == 0.0f && a->y == 0.0f && a->z == 0.0f);
    TEST_CHECK(filo_list_float3_pop(float3list, &b));
    TEST_CHECK(b->x == 0.0f && b->y == 0.0f && b->z == 0.0f);
    TEST_CHECK(filo_list_float3_pop(float3list, &c));
    TEST_CHECK(c->x == 0.0f && c->y == 0.0f && c->z == 0.0f);
}

void test_filo_list_float3_recycle(void){
    FiloListFloat3Node* float3list = filo_list_float3_new(3);
    float3* a;
    float3* b;
    float3* c;
    filo_list_float3_pop(float3list, &a);
    filo_list_float3_pop(float3list, &b);
    float3_set(b, 1.0f, 2.0f, 3.0f);

    filo_list_float3_recycle(float3list, b);
    filo_list_float3_pop(float3list, c);
    TEST_CHECK(c->x == 1.0f && c->y == 2.0f && c->z == 3.0f);

    filo_list_float3_free(float3list);
}
