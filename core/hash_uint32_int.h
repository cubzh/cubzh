// -------------------------------------------------------------
//  Cubzh Core
//  hash_uint32.h
//  Created by Adrien Duermael on August 15, 2022.
// -------------------------------------------------------------

// Allows to register uint32 values and quickly find out if some value is registered.
// In that kind of hash, the key stored and the value are the same.

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdlib.h>

#include "colors.h"

typedef struct _HashUInt32Int HashUInt32Int;

HashUInt32Int *hash_uint32_int_new(void);
void hash_uint32_int_free(HashUInt32Int *h);

// inserts value, doesn't do anything if already inserted
void hash_uint32_int_set(HashUInt32Int *h, uint32_t key, int value);

// returns true if the value is found, setting outValue
bool hash_uint32_int_get(HashUInt32Int *h, uint32_t key, int *outValue);

// deletes value if found in the hash
void hash_uint32_int_delete(HashUInt32Int *h, uint32_t key);

#ifdef __cplusplus
} // extern "C"
#endif
