// -------------------------------------------------------------
//  Cubzh Core
//  octree.h
//  Created by Adrien Duermael on December 19, 2018.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "box.h"
#include "doubly_linked_list.h"

typedef enum {
    octree_1x1x1 = 1,
    octree_2x2x2 = 1,
    octree_4x4x4 = 2,
    octree_8x8x8 = 3,
    octree_16x16x16 = 4,
    octree_32x32x32 = 5,
    octree_64x64x64 = 6,
    octree_128x128x128 = 7,
    octree_256x256x256 = 8,
    octree_512x512x512 = 9,
    octree_1024x1024x1024 = 10
} OctreeLevelsForSize;

typedef struct _Octree Octree;
typedef struct _OctreeNode OctreeNode;
typedef struct _OctreeNodeValue OctreeNodeValue;

Octree *octree_new_with_default_element(const OctreeLevelsForSize levels,
                                        const void *element,
                                        const size_t elementSize);

// destructor
void octree_free(Octree *const tree);

void octree_flush(Octree *tree);

void *octree_get_element(const Octree *octree, const size_t x, const size_t y, const size_t z);

void *octree_get_element_without_checking(const Octree *octree,
                                          const size_t x,
                                          const size_t y,
                                          const size_t z);

// Useful when storing values in empty nodes.
// if node is empty, *element will be set to NULL and *empty will point
// to what's currently stored at (x, y, z).
void octree_get_element_or_empty_value(const Octree *octree,
                                       const size_t x,
                                       const size_t y,
                                       const size_t z,
                                       void **element,
                                       void **empty);

bool octree_set_element(const Octree *octree, const void *element, size_t x, size_t y, size_t z);

bool octree_remove_element(const Octree *octree, size_t x, size_t y, size_t z, void *emptyElement);

void octree_log(const Octree *octree);

void octree_non_recursive_iteration(const Octree *octree);

void *octree_get_nodes(const Octree *octree);
size_t octree_get_nodes_size(const Octree *octree);
void *octree_get_elements(const Octree *octree);
size_t octree_get_elements_size(const Octree *octree);
uint8_t octree_get_levels(const Octree *octree);
size_t octree_get_dimension(const Octree *octree);
uint64_t octree_get_hash(const Octree *octree, uint64_t crc);

// MARK: Octree iterator

typedef struct _OctreeIterator OctreeIterator;

OctreeIterator *octree_iterator_new(const Octree *octree);

void octree_iterator_free(OctreeIterator *oi);

// useful to test collisions with node
bool octree_iterator_is_at_last_level(OctreeIterator *oi);

// useful to test collisions with node
void octree_iterator_get_node_box(const OctreeIterator *oi, Box *box);

// Returns element pointed by iterator
// Returns NULL if there's no element at this location or if iterator is not pointing a leaf.
void *octree_iterator_get_element(const OctreeIterator *oi);

// Returns iterator's current node size
uint16_t octree_iterator_get_current_node_size(const OctreeIterator *oi);

// Returns iterator's current position
void octree_iterator_get_current_position(const OctreeIterator *oi,
                                          uint16_t *x,
                                          uint16_t *y,
                                          uint16_t *z);

// jumps to next element, skipping current branch if skip_current_branch is true.
void octree_iterator_next(OctreeIterator *oi, bool skip_current_branch, bool *found);

// returns true when done iterating
bool octree_iterator_is_done(const OctreeIterator *oi);

#ifdef __cplusplus
} // extern "C"
#endif
