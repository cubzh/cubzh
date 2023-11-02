// -------------------------------------------------------------
//  Cubzh Core
//  block.h
//  Created by Adrien Duermael on July 19, 2015.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

#include "color_palette.h"
#include "colors.h"
#include "int3.h"

// forward declarations
typedef struct _Shape Shape;

// Block used in octree
// colorIndex carries information such as: air/solid block, emissive, transparent
typedef struct _Block {
    SHAPE_COLOR_INDEX_INT_T colorIndex;
} Block; /* 1 byte */

// a solid block by default with color index 0
Block *block_new(void);

// an air block is a block with color index 255
Block *block_new_air(void);

// a block with the given color index
Block *block_new_with_color(const SHAPE_COLOR_INDEX_INT_T colorIndex);

Block *block_new_copy(const Block *block);

void block_free(Block *b);

void block_set_color_index(Block *block, const SHAPE_COLOR_INDEX_INT_T index);

SHAPE_COLOR_INDEX_INT_T block_get_color_index(const Block *block);

// a non-null, non-air block is a solid block
bool block_is_solid(const Block *const block);

// a solid non-transparent block is an opaque block
bool block_is_opaque(const Block *block, const ColorPalette *palette);

// a solid block w/ alpha < 255 is a transparent block
bool block_is_transparent(Block *block, const ColorPalette *palette);

// a block can be a light and/or AO caster when it comes to sampling vertex light values
// - AO caster means that adjacent vertices will consider this block in the final AO value
// - light caster means adjacent vertices will consider this block in the final light value
void block_is_ao_and_light_caster(Block *block, const ColorPalette *palette, bool *ao, bool *light);

// helper function that efficiently gathers all lighting properties for a block
void block_is_any(Block *block,
                  const ColorPalette *palette,
                  bool *solid,
                  bool *opaque,
                  bool *transparent,
                  bool *aoCaster,
                  bool *lightCaster);

// An AwareBlock knows more information about itself than a simple Block:
// - absolute world position
// - position within Chunk
// - touched face in case of collision
// It's better to use them only when necessary, to consume less memory.
typedef struct _AwareBlock AwareBlock;

AwareBlock *aware_block_new(const Block *block,
                            const int3 *worldPos,
                            const int3 *chunkPos,
                            FACE_INDEX_INT_T faceIndex);

AwareBlock *aware_block_new_copy(const AwareBlock *aBlockSource);

Block *aware_block_get_block(AwareBlock *aBlock);

SHAPE_COLOR_INDEX_INT_T aware_block_get_color_index(AwareBlock *aBlock);

int3 *aware_block_get_shape_pos(AwareBlock *aBlock);

int3 *aware_block_get_chunk_pos(AwareBlock *aBlock);

void aware_block_set_touched_face(AwareBlock *aBlock, FACE_INDEX_INT_T faceIndex);

int3 *aware_block_get_shape_target_pos(AwareBlock *aBlock);

// All AwareBlock struct variables are copied
// full_block_free should be used to free memory
void aware_block_free(AwareBlock *aBlock);

// Similar to aware_block_free, but takes a void* to adopt
// same prototype as free function
void aware_block_free_2(void *aBlockVoided);

bool block_equal(const Block *b1, const Block *b2);

/// @returns false if coordinates is already maximum/minimum
bool block_getNeighbourBlockCoordinates(const SHAPE_COORDS_INT_T x,
                                        const SHAPE_COORDS_INT_T y,
                                        const SHAPE_COORDS_INT_T z,
                                        const int face,
                                        SHAPE_COORDS_INT_T *newX,
                                        SHAPE_COORDS_INT_T *newY,
                                        SHAPE_COORDS_INT_T *newZ);

#ifdef __cplusplus
} // extern "C"
#endif
