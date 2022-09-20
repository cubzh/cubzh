// -------------------------------------------------------------
//  Cubzh Core
//  float4.c
//  Created by Gaetan de Villele on November 5, 2015.
// -------------------------------------------------------------

#include "float4.h"

#include <stdlib.h>

float4 *float4_new(const float x, const float y, const float z, const float w) {
    float4 *f = (float4 *)malloc(sizeof(float4));
    f->x = x;
    f->y = y;
    f->z = z;
    f->w = w;
    return f;
}

float4 *float4_new_zero() {
    return float4_new(0.0f, 0.0f, 0.0f, 0.0f);
}

/// allocates a new float4 structure
float4 *float4_new_copy(const float4 *f) {
    return float4_new(f->x, f->y, f->z, f->w);
}

/// frees a float4 structure
void float4_free(float4 *f) {
    free(f);
}

/// set float4 value to another float4 value
void float4_copy(float4 *dest, const float4 *src) {
    dest->x = src->x;
    dest->y = src->y;
    dest->z = src->z;
    dest->w = src->w;
}

void float4_set(float4 *f, const float x, const float y, const float z, const float w) {
    f->x = x;
    f->y = y;
    f->z = z;
    f->w = w;
}
