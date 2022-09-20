// -------------------------------------------------------------
//  Cubzh Core
//  int3.h
//  Created by Gaetan de Villele on November 26, 2016.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

typedef struct _int3 {
    int32_t x;
    int32_t y;
    int32_t z;
} int3;

static const int3 int3_zero = {0, 0, 0};

// shared int3 pool to avoid allocations
int3 *int3_pool_pop(void);
void int3_pool_recycle(int3 *i3);

///
int3 *int3_new(const int32_t x, const int32_t y, const int32_t z);

///
int3 *int3_new_copy(const int3 *i);

///
void int3_free(int3 *i);

///
void int3_set(int3 *i, const int32_t x, const int32_t y, const int32_t z);

///
void int3_copy(int3 *dest, const int3 *src);

///
void int3_op_add(int3 *i1, const int3 *i2);

///
void int3_op_add_int(int3 *i, int v);

///
void int3_op_substract(int3 *i1, const int3 *i2);

///
void int3_op_substract_int(int3 *i, int v);

///
void int3_op_min(int3 *i, int x, int y, int z);

///
void int3_op_max(int3 *i, int x, int y, int z);

///
void int3_op_div_int(int3 *i, int v);

///
void int3_op_div_ints(int3 *i, int x, int y, int z);

#ifdef __cplusplus
} // extern "C"
#endif
