// -------------------------------------------------------------
//  Cubzh Core
//  blockChange.h
//  Created by Gaetan de Villele on August 2, 2021.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "config.h"

typedef struct _BlockChange BlockChange;
typedef struct _Block Block;

/// Creates a new BlockChange with the provided block
BlockChange *blockChange_new(const SHAPE_COLOR_INDEX_INT_T colorIndex,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z);

///
void blockChange_free(BlockChange *const bc);

///
void blockChange_freeFunc(void *bc);

/// Updates the color of a BlockChange.
void blockChange_amend(BlockChange *const bc, const SHAPE_COLOR_INDEX_INT_T colorIndex);

///
const Block *blockChange_getBlock(const BlockChange *const bc);

///
void blockChange_getXYZ(const BlockChange *const bc,
                        SHAPE_COORDS_INT_T *const x,
                        SHAPE_COORDS_INT_T *const y,
                        SHAPE_COORDS_INT_T *const z);

void blockChange_set_previous_color(BlockChange *bc, const SHAPE_COLOR_INDEX_INT_T colorIndex);
SHAPE_COLOR_INDEX_INT_T blockChange_get_previous_color(const BlockChange *bc);

#ifdef __cplusplus
} // extern "C"
#endif
