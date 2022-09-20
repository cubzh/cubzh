// -------------------------------------------------------------
//  Cubzh Core
//  fifo_list.h
//  Created by Adrien Duermael on June 27, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

#include "function_pointers.h"
#ifdef DEBUG
#include <stdbool.h>
#endif

// types
typedef struct _FifoListNode FifoListNode;
typedef struct _FifoList FifoList;

FifoList *fifo_list_new(void);
FifoList *fifo_list_new_copy(const FifoList *list);
// ! \\ stored pointers won't be released
void fifo_list_free(FifoList *list);
void fifo_list_push(FifoList *list, void *ptr);
void *fifo_list_pop(FifoList *list);
void fifo_list_flush(FifoList *list, pointer_free_function freeFunc);
void fifo_list_empty_freefunc(void *a);
uint32_t fifo_list_get_size(const FifoList *list);

#ifdef __cplusplus
} // extern "C"
#endif
