// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_float3.h
//  Created by Adrien Duermael on June 7, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdlib.h>

#include "float3.h"

typedef struct _FiloListFloat3Node FiloListFloat3Node;

typedef struct {
    FiloListFloat3Node *first;
    FiloListFloat3Node *inUseFirst; // recycle pool
    size_t maxNodes;
    size_t nbNodes;
} FiloListFloat3;

// Note: nodes are recycled, only released with filo_list_float3_free
FiloListFloat3 *filo_list_float3_new(size_t maxNodes);

void filo_list_float3_free(FiloListFloat3 *list);

// returns false if list is NULL or empty
bool filo_list_float3_pop(FiloListFloat3 *list, float3 **f3Ptr);

// passed float3* is not supposed to be used after this call
void filo_list_float3_recycle(FiloListFloat3 *list, float3 *f3);

#ifdef __cplusplus
} // extern "C"
#endif
