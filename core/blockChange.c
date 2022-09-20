// -------------------------------------------------------------
//  Cubzh Core
//  blockChange.c
//  Created by Gaetan de Villele on August 2, 2021.
// -------------------------------------------------------------

#include "blockChange.h"

#include <stdlib.h>

#include "block.h"

typedef struct _BlockChange {
    Block *before;        // 8 bytes
    Block *after;         // 8 bytes
    SHAPE_COORDS_INT_T x; // 2 bytes
    SHAPE_COORDS_INT_T y; // 2 bytes
    SHAPE_COORDS_INT_T z; // 2 bytes
    char pad[2];
} BlockChange;

BlockChange *blockChange_new(Block *const before,
                             Block *const after,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z) {
    // TODO: if before == after then return NULL
    BlockChange *bc = (BlockChange *)malloc(sizeof(BlockChange));
    if (bc == NULL) {
        return NULL;
    }
    bc->before = before;
    bc->after = after;
    bc->x = x;
    bc->y = y;
    bc->z = z;
    return bc;
}

void blockChange_free(BlockChange *const bc) {
    if (bc != NULL) {
        block_free(bc->before);
        block_free(bc->after);
    }
    free(bc);
}

void blockChange_freeFunc(void *bc) {
    blockChange_free((BlockChange *)bc);
}

void blockChange_amend(BlockChange *const bc, Block *amend) {
    vx_assert(bc != NULL);
    block_free(bc->after);
    bc->after = amend;
}

Block *blockChange_getBefore(const BlockChange *const bc) {
    vx_assert(bc != NULL);
    return bc->before;
}

Block *blockChange_getAfter(const BlockChange *const bc) {
    vx_assert(bc != NULL);
    return bc->after;
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
