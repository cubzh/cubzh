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

#include "function_pointers.h"

typedef struct _HashUInt32 HashUInt32;

/// @param freeFunc if NULL, hashmap doesn't free values
HashUInt32 *hash_uint32_new(pointer_free_function freeFunc);
void hash_uint32_free(HashUInt32 *h);

/// inserts or update value
void hash_uint32_set(HashUInt32 *const h, uint32_t key, void *value);

/// returns true if the value is found, setting outValue
bool hash_uint32_get(HashUInt32 *h, uint32_t key, void **outValue);

/// deletes value if found in the hash
void hash_uint32_delete(HashUInt32 *h, uint32_t key);

void hash_uint32_flush(HashUInt32 *h);

#ifdef __cplusplus
} // extern "C"
#endif
