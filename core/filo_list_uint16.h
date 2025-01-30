// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_uint16.h
//  Created by Gaetan de Villele on February 10, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

typedef struct _FiloListUInt16 FiloListUInt16;
typedef struct _FiloListUInt16Node FiloListUInt16Node;

FiloListUInt16 *filo_list_uint16_new(void);

void filo_list_uint16_free(FiloListUInt16 *list);

void filo_list_uint16_push(FiloListUInt16 *list, uint16_t i);

// pops last inserted value, returns true on success
// false if list is empty or NULL
bool filo_list_uint16_pop(FiloListUInt16 *list, uint16_t *i);

FiloListUInt16Node *filo_list_uint16_get_first(FiloListUInt16 *list);
FiloListUInt16Node *filo_list_uint16_node_next(FiloListUInt16Node *node);
uint16_t filo_list_uint16_node_get_value(FiloListUInt16Node *node);

#ifdef __cplusplus
} // extern "C"
#endif
