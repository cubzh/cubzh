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
#include "int3.h"
#include "octree.h"
#include "shape.h"

typedef struct _Chunk Chunk;

enum Neighbor {
    Left = 0,
    LeftBack = 1,
    Back = 2,
    RightBack = 3,
    Right = 4,
    RightFront = 5,
    Front = 6,
    LeftFront = 7, // middle
    Top = 8,
    TopLeft = 9,
    TopLeftBack = 10,
    TopBack = 11,
    TopRightBack = 12,
    TopRight = 13,
    TopRightFront = 14,
    TopFront = 15,
    TopLeftFront = 16, // top
    Bottom = 17,
    BottomLeft = 18,
    BottomLeftBack = 19,
    BottomBack = 20,
    BottomRightBack = 21,
    BottomRight = 22,
    BottomRightFront = 23,
    BottomFront = 24,
    BottomLeftFront = 25 // bottom
};

Chunk *chunk_new(const SHAPE_COORDS_INT_T x, const SHAPE_COORDS_INT_T y, const SHAPE_COORDS_INT_T z);

void chunk_destroy(Chunk *chunk);

Chunk *chunk_get_neighbor(const Chunk *chunk, enum Neighbor location);
void chunk_leave_neighborhood(Chunk *chunk);
void chunk_move_in_neighborhood(Chunk *chunk,
                                Chunk *topLeftBack,
                                Chunk *topBack,
                                Chunk *topRightBack, // top
                                Chunk *topLeft,
                                Chunk *top,
                                Chunk *topRight,
                                Chunk *topLeftFront,
                                Chunk *topFront,
                                Chunk *topRightFront,
                                Chunk *bottomLeftBack,
                                Chunk *bottomBack,
                                Chunk *bottomRightBack, // bottom
                                Chunk *bottomLeft,
                                Chunk *bottom,
                                Chunk *bottomRight,
                                Chunk *bottomLeftFront,
                                Chunk *bottomFront,
                                Chunk *bottomRightFront,
                                Chunk *leftBack,
                                Chunk *back,
                                Chunk *rightBack, // middle
                                Chunk *left,
                                /* self */ Chunk *right,
                                Chunk *leftFront,
                                Chunk *front,
                                Chunk *rightFront);

// add block un chunk at given position
bool chunk_addBlock(Chunk *chunk,
                    Block *block,
                    const CHUNK_COORDS_INT_T x,
                    const CHUNK_COORDS_INT_T y,
                    const CHUNK_COORDS_INT_T z);

// return true if the block has been removed, false otherwise
bool chunk_removeBlock(Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z);

// return 1 if the block has been painted, 0 otherwise
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

// return true if chunk needs to be displayed
bool chunk_needs_display(const Chunk *chunk);

void chunk_set_needs_display(Chunk *chunk, bool b);

const int3 *chunk_get_pos(const Chunk *chunk);

void chunk_get_block_pos(const Chunk *chunk,
                         const CHUNK_COORDS_INT_T x,
                         const CHUNK_COORDS_INT_T y,
                         const CHUNK_COORDS_INT_T z,
                         int3 *pos);

int chunk_get_nb_blocks(const Chunk *chunk);

void *chunk_get_vbma(const Chunk *chunk, bool transparent);
void chunk_set_vbma(Chunk *chunk, void *vbma, bool transparent);

// octree will be used if not NULL, ignored otherwise
void chunk_write_vertices(Shape *shape, Chunk *chunk);

// returns min/max limits defined by blocks within the chunk
// can be used to precisely define bounds around the cubes.
void chunk_get_inner_bounds(const Chunk *chunk,
                            CHUNK_COORDS_INT_T *min_x,
                            CHUNK_COORDS_INT_T *max_x,
                            CHUNK_COORDS_INT_T *min_y,
                            CHUNK_COORDS_INT_T *max_y,
                            CHUNK_COORDS_INT_T *min_z,
                            CHUNK_COORDS_INT_T *max_z);

#ifdef __cplusplus
} // extern "C"
#endif
