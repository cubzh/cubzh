// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_uint32.h
//  Created by Adrien Duermael on August 14, 2017.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

typedef struct _FiloListUInt32 FiloListUInt32;
typedef struct _FiloListUInt32Node FiloListUInt32Node;

FiloListUInt32 *filo_list_uint32_new(void);

void filo_list_uint32_free(FiloListUInt32 *list);

void filo_list_uint32_push(FiloListUInt32 *list, uint32_t i);

// pops last inserted value, returns true on success
// false if list is empty or NULL
bool filo_list_uint32_pop(FiloListUInt32 *list, uint32_t *i);

bool filo_list_uint32_is_empty(FiloListUInt32 *list);

#ifdef __cplusplus
} // extern "C"
#endif
