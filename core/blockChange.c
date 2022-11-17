// -------------------------------------------------------------
//  Cubzh Core
//  blockChange.c
//  Created by Gaetan de Villele on August 2, 2021.
// -------------------------------------------------------------

#include "blockChange.h"

#include <stdlib.h>

#include "block.h"

typedef struct _BlockChange {
    // a block is used here in order to allow shape_get_block to return a pending block,
    // it won't be used inside shape and will be freed by transaction_free
    Block *block; // 8 bytes
    // once change is applied, stores the color index that was replaced
    SHAPE_COLOR_INDEX_INT_T previousColor; // 8 bytes
    SHAPE_COORDS_INT_T x;                  // 2 bytes
    SHAPE_COORDS_INT_T y;                  // 2 bytes
    SHAPE_COORDS_INT_T z;                  // 2 bytes
    char pad[2];
} BlockChange;

BlockChange *blockChange_new(const SHAPE_COLOR_INDEX_INT_T colorIndex,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z) {
    BlockChange *bc = (BlockChange *)malloc(sizeof(BlockChange));
    if (bc == NULL) {
        return NULL;
    }
    bc->block = block_new_with_color(colorIndex);
    bc->previousColor = SHAPE_COLOR_INDEX_AIR_BLOCK;
    bc->x = x;
    bc->y = y;
    bc->z = z;
    return bc;
}

void blockChange_free(BlockChange *const bc) {
    if (bc != NULL) {
        block_free(bc->block);
    }
    free(bc);
}

void blockChange_freeFunc(void *bc) {
    blockChange_free((BlockChange *)bc);
}

void blockChange_amend(BlockChange *const bc, const SHAPE_COLOR_INDEX_INT_T colorIndex) {
    vx_assert(bc != NULL);
    bc->block->colorIndex = colorIndex;
}

Block *blockChange_getBlock(const BlockChange *const bc) {
    vx_assert(bc != NULL);
    return bc->block;
}

void blockChange_getXYZ(const BlockChange *const bc,
                        SHAPE_COORDS_INT_T *const x,
                        SHAPE_COORDS_INT_T *const y,
                        SHAPE_COORDS_INT_T *const z) {
    vx_assert(bc != NULL);
    if (x != NULL) {
        *x = bc->x;
    }
    if (y != NULL) {
        *y = bc->y;
    }
    if (z != NULL) {
        *z = bc->z;
    }
}

void blockChange_set_previous_color(BlockChange *bc, const SHAPE_COLOR_INDEX_INT_T colorIndex) {
    bc->previousColor = colorIndex;
}

SHAPE_COLOR_INDEX_INT_T blockChange_get_previous_color(const BlockChange *bc) {
    return bc->previousColor;
}
