// -------------------------------------------------------------
//  Cubzh Core
//  float4.c
//  Created by Gaetan de Villele on November 5, 2015.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// float4 structure definition
typedef struct {
    float x; //  4 bytes
    float y; //  4 bytes
    float z; //  4 bytes
    float w; //  4 bytes
} float4;    // 16 bytes

/// allocates a new float4 structure
float4 *float4_new(const float x, const float y, const float z, const float w);
float4 *float4_new_zero(void);

/// allocates a new float4 structure
float4 *float4_new_copy(const float4 *f);

/// frees a float4 structure
void float4_free(float4 *f);

/// set float4 value to another float4 value
void float4_copy(float4 *dest, const float4 *src);

void float4_set(float4 *f, const float x, const float y, const float z, const float w);

#ifdef __cplusplus
} // extern "C"
#endif
