// -------------------------------------------------------------
//  Cubzh Core
//  int3.c
//  Created by Gaetan de Villele on November 26, 2016.
// -------------------------------------------------------------

#include "int3.h"

#include <stdlib.h>

#include "config.h"
#include "filo_list_int3.h"

static FiloListInt3 *int3_pool(void) {
    static FiloListInt3 p = {NULL, NULL, 10, 0};
    return &p;
}

int3 *int3_pool_pop(void) {
    int3 *i3;
    filo_list_int3_pop(int3_pool(), &i3);
    return i3;
}

void int3_pool_recycle(int3 *i3) {
    filo_list_int3_recycle(int3_pool(), i3);
}

int3 *int3_new(const int32_t x, const int32_t y, const int32_t z) {
    int3 *i = (int3 *)malloc(sizeof(int3));
    i->x = x;
    i->y = y;
    i->z = z;
    return i;
}

int3 *int3_new_copy(const int3 *i) {
    if (i == NULL) {
        return NULL;
    }
    return int3_new(i->x, i->y, i->z);
}

void int3_free(int3 *i) {
    free(i);
}

void int3_set(int3 *i, const int32_t x, const int32_t y, const int32_t z) {
    i->x = x;
    i->y = y;
    i->z = z;
}

void int3_copy(int3 *dest, const int3 *src) {
    dest->x = src->x;
    dest->y = src->y;
    dest->z = src->z;
}

void int3_op_add(int3 *i1, const int3 *i2) {
    i1->x += i2->x;
    i1->y += i2->y;
    i1->z += i2->z;
}

void int3_op_add_int(int3 *i, int v) {
    i->x += v;
    i->y += v;
    i->z += v;
}

void int3_op_substract(int3 *i1, const int3 *i2) {
    i1->x -= i2->x;
    i1->y -= i2->y;
    i1->z -= i2->z;
}

void int3_op_substract_int(int3 *i, int v) {
    i->x -= v;
    i->y -= v;
    i->z -= v;
}

void int3_op_min(int3 *i, int x, int y, int z) {
    i->x = minimum(i->x, x);
    i->y = minimum(i->y, y);
    i->z = minimum(i->z, z);
}

void int3_op_max(int3 *i, int x, int y, int z) {
    i->x = maximum(i->x, x);
    i->y = maximum(i->y, y);
    i->z = maximum(i->z, z);
}

void int3_op_div_int(int3 *i, int v) {
    i->x /= v;
    i->y /= v;
    i->z /= v;
}

void int3_op_div_ints(int3 *i, int x, int y, int z) {
    i->x /= x;
    i->y /= y;
    i->z /= z;
}
