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

/// Creates a new BlockChange with the provided Blocks `before` and `after`.
/// BlockChange takes ownership over both Blocks (freed in blockChange_free)
BlockChange *blockChange_new(Block *const before,
                             Block *const after,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z);

///
void blockChange_free(BlockChange *const bc);

///
void blockChange_freeFunc(void *bc);

/// Updates the BlockState `after` of a BlockChange.
void blockChange_amend(BlockChange *const bc, Block *amend);

///
Block *blockChange_getBefore(const BlockChange *const bc);

///
Block *blockChange_getAfter(const BlockChange *const bc);

///
void blockChange_getXYZ(const BlockChange *const bc,
                        SHAPE_COORDS_INT_T *const x,
                        SHAPE_COORDS_INT_T *const y,
                        SHAPE_COORDS_INT_T *const z);

#ifdef __cplusplus
} // extern "C"
#endif
