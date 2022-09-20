// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_int3.h
//  Created by Adrien Duermael on January 20, 2018.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdlib.h>

#include "int3.h"

// types
typedef struct _FiloListInt3Node FiloListInt3Node;

typedef struct {
    FiloListInt3Node *first;
    FiloListInt3Node *inUseFirst; // recycle pool
    size_t maxNodes;
    size_t nbNodes;
} FiloListInt3;

// Note: nodes are recycled, only released with filo_list_float3_free
// maxNodes == 0 means no max
FiloListInt3 *filo_list_int3_new(size_t maxNodes);

void filo_list_int3_free(FiloListInt3 *list);

// pops last inserted value, returns true on success
// setting value of i3
// returns false if list is empty or NULL
bool filo_list_int3_pop_no_gen(FiloListInt3 *list, int3 **i3Ptr);
// same as filo_list_int3_pop_no_gen, but the value is returned, stored
// int3 is freed.
bool filo_list_int3_pop_value_no_gen(FiloListInt3 *list, int3 *i3);

// same as filo_list_int3_pop_no_gen, but generates int3s if list is empty.
bool filo_list_int3_pop(FiloListInt3 *list, int3 **i3Ptr);

// passed int3* is not supposed to be used after this call
void filo_list_int3_recycle(FiloListInt3 *list, int3 *i3);

// passed int3* is not supposed to be used after this call
// void filo_list_int3_push(FiloListInt3* list, int3* i3);
void filo_list_int3_push(FiloListInt3 *list, const int32_t x, const int32_t y, const int32_t z);

#ifdef __cplusplus
} // extern "C"
#endif
