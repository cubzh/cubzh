// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_filo_list_int3.h
//  Created by Xavier Legland on October 17, 2022.
// -------------------------------------------------------------

#pragma once

#include "filo_list_int3.h"

// functions that are NOT tested:
// filo_list_int3_new
// filo_list_int3_free
// filo_list_int3_pop_no_gen
// filo_list_int3_pop_value_no_gen
// filo_list_int3_push

// check default value
void test_filo_list_int3_pop(void) {
	FiloListInt3* list = filo_list_int3_new(2);
	int3* a;
	int3* b;

	TEST_CHECK(filo_list_int3_pop(list, &a));
	TEST_CHECK(a->x == 0);
	TEST_CHECK(filo_list_int3_pop(list, &b));

	filo_list_int3_free(list);
}

// check that the recycled int3 is used again
void test_filo_list_int3_recycle(void) {
	FiloListInt3* list = filo_list_int3_new(2);
	int3* a;
	int3* b;
	int3* c;
	filo_list_int3_pop(list, &a);
	filo_list_int3_pop(list, &b);
	int3_set(b, 1, 2, 3);

	filo_list_int3_recycle(list, b);
	filo_list_int3_pop(list, &c);
	TEST_CHECK(c->x == 1);

	filo_list_int3_free(list);
}
