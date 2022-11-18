// -------------------------------------------------------------
//  Cubzh Core
//  index3d.c
//  Created by Adrien Duermael on December 3, 2016.
// -------------------------------------------------------------

// index3d can be used to store pointers in 3d space
// storing and retrieving pointers is a little slower compared
// to 3d arrays. But it takes a lot less space in memory and
// request time is constant and reliable.
// index3d also automatically stores pointers in a doubly_linked_list, in no
// specific order. It's useful when we want to iterate over all entries quickly.

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "doubly_linked_list.h"
#include "function_pointers.h"

typedef struct _Index3D Index3D;

// Index3DIterator can be used to quickly iterate over all stored pointers
// (uses the doubly_linked_list)
typedef struct _Index3DIterator Index3DIterator;

// constructor
// returns an empty Index3D
Index3D *index3d_new(void);

// destructor
// index3d_flush should be called prior to index3d_free, to make sure
// memory referenced by stored poiters doesn't leak
void index3d_free(Index3D *index);

///
bool index3d_is_empty(const Index3D *const index);

// index3d_flush flushes all indexed pointers and releases memory for
// each one of them.
// see world.c/entity_list_with_distance_free to help for implementation
void index3d_flush(Index3D *index, pointer_free_function ptr);

// index3d_insert inserts ptr at given position, optionally maintaining given iterator
void index3d_insert(Index3D *index,
                    void *ptr,
                    const int32_t x,
                    const int32_t y,
                    const int32_t z,
                    Index3DIterator *it);

// index3d_get returns pointer at given position. NULL can be returned
void *index3d_get(const Index3D *index, const int32_t x, const int32_t y, const int32_t z);

// index3d_remove removes ptr from index at given position, optionally maintaining given iterator
// @returns removed pointer or NULL if not found. Its caller's responsibility to free memory.
void *index3d_remove(Index3D *index,
                     const int32_t x,
                     const int32_t y,
                     const int32_t z,
                     Index3DIterator *it);

// returns new iterator
Index3DIterator *index3d_iterator_new(Index3D *index);

// destructor
void index3d_iterator_free(Index3DIterator *it);

// returns pointer pointed by iterator at current position
void *index3d_iterator_pointer(const Index3DIterator *it);

// moves iterator to next position
void index3d_iterator_next(Index3DIterator *it);

// returns 1 if iterator is at end position, 0 otherwise
bool index3d_iterator_is_at_end(const Index3DIterator *it);

#ifdef __cplusplus
} // extern "C"
#endif
