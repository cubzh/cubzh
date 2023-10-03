// -------------------------------------------------------------
//  Cubzh Core
//  chunk.h
//  Created by Adrien Duermael on July 18, 2015.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "block.h"
#include "color_palette.h"
#include "colors.h"
#include "config.h"
#include "function_pointers.h"
#include "index3d.h"
#include "octree.h"
#include "shape.h"

typedef struct _Chunk Chunk;

// Enum used to index all 26 neighbors
typedef enum {
    X = 0,
    X_Y = 1,
    X_Y_Z = 2,
    X_Y_NZ = 3,
    X_NY = 4,
    X_NY_Z = 5,
    X_NY_NZ = 6,
    X_Z = 7,
    X_NZ = 8,

    NX = 9,
    NX_Y = 10,
    NX_Y_Z = 11,
    NX_Y_NZ = 12,
    NX_NY = 13,
    NX_NY_Z = 14,
    NX_NY_NZ = 15,
    NX_Z = 16,
    NX_NZ = 17,

    Y = 18,
    Y_Z = 19,
    Y_NZ = 20,

    NY = 21,
    NY_Z = 22,
    NY_NZ = 23,

    Z = 24,
    NZ = 25
} Neighbor;

Chunk *chunk_new(const SHAPE_COORDS_INT_T x,
                 const SHAPE_COORDS_INT_T y,
                 const SHAPE_COORDS_INT_T z);
void chunk_free(Chunk *chunk, bool updateNeighbors);
void chunk_free_func(void *c);
void chunk_set_dirty(Chunk *chunk, bool b);
bool chunk_is_dirty(const Chunk *chunk);
SHAPE_COORDS_INT3_T chunk_get_origin(const Chunk *chunk);
int chunk_get_nb_blocks(const Chunk *chunk);
Octree *chunk_get_octree(const Chunk *c);
void chunk_set_rtree_leaf(Chunk *c, void *ptr);
void *chunk_get_rtree_leaf(const Chunk *c);

bool chunk_add_block(Chunk *chunk,
                     const Block block,
                     const CHUNK_COORDS_INT_T x,
                     const CHUNK_COORDS_INT_T y,
                     const CHUNK_COORDS_INT_T z);

bool chunk_remove_block(Chunk *chunk,
                        const CHUNK_COORDS_INT_T x,
                        const CHUNK_COORDS_INT_T y,
                        const CHUNK_COORDS_INT_T z);

bool chunk_paint_block(Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z,
                       const SHAPE_COLOR_INDEX_INT_T colorIndex);

Block *chunk_get_block(const Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z);

Block *chunk_get_block_2(const Chunk *chunk, const int3 *pos);

void chunk_get_block_pos(const Chunk *chunk,
                         const CHUNK_COORDS_INT_T x,
                         const CHUNK_COORDS_INT_T y,
                         const CHUNK_COORDS_INT_T z,
                         SHAPE_COORDS_INT3_T *pos);

void chunk_get_bounding_box(const Chunk *chunk, float3 *min, float3 *max);

// MARK: - Neighbors -

Chunk *chunk_get_neighbor(const Chunk *chunk, Neighbor location);
void chunk_move_in_neighborhood(Index3D *chunks, Chunk *chunk, const int3 *chunk_coords);
void chunk_leave_neighborhood(Chunk *chunk);

// MARK: - Buffers -

void *chunk_get_vbma(const Chunk *chunk, bool transparent);
void chunk_set_vbma(Chunk *chunk, void *vbma, bool transparent);
void chunk_write_vertices(Shape *shape, Chunk *chunk);

#ifdef __cplusplus
} // extern "C"
#endif
