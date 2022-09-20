// -------------------------------------------------------------
//  Cubzh Core
//  map_string_float3.h
//  Created by Adrien Duermael on August 7, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdlib.h>

#include "float3.h"

// types
typedef struct _MapStringFloat3 MapStringFloat3;
typedef struct _MapStringFloat3Iterator MapStringFloat3Iterator;

MapStringFloat3 *map_string_float3_new(void);
void map_string_float3_free(MapStringFloat3 *m);

MapStringFloat3Iterator *map_string_float3_iterator_new(const MapStringFloat3 *m);
void map_string_float3_iterator_free(MapStringFloat3Iterator *i);

void map_string_float3_iterator_next(MapStringFloat3Iterator *i);
const char *map_string_float3_iterator_current_key(const MapStringFloat3Iterator *i);
float3 *map_string_float3_iterator_current_value(const MapStringFloat3Iterator *i);
void map_string_float3_iterator_replace_current_value(const MapStringFloat3Iterator *i, float3 *f3);

bool map_string_float3_iterator_is_done(const MapStringFloat3Iterator *i);

void map_string_float3_debug(MapStringFloat3 *m);

// the float3 value is released when removed from the map
void map_string_float3_set_key_value(MapStringFloat3 *m, const char *key, float3 *f3);
const float3 *map_string_float3_value_for_key(MapStringFloat3 *m, const char *key);
float3 *map_string_mutable_float3_value_for_key(MapStringFloat3 *m, const char *key);
// removes value for given key (float3* is release)
void map_string_float3_remove_key(MapStringFloat3 *m, const char *key);

#ifdef __cplusplus
} // extern "C"
#endif
