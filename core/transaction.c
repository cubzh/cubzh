// -------------------------------------------------------------
//  Cubzh Core
//  transaction.c
//  Created by Gaetan de Villele on July 22, 2021.
// -------------------------------------------------------------

#include "transaction.h"

#include <stdlib.h>

#include "block.h"
#include "blockChange.h"
#include "box.h"
#include "index3d.h"

struct _Transaction {

    // block changes
    Index3D *index3D; // 8 bytes

    // iterator is kept as an internal variable
    // to maintain iterator position when
    // transactions are voluntarily kept pending
    Index3DIterator *iterator;

    // new shape bounds
    SHAPE_COORDS_INT_T newMinX; // 2 bytes
    SHAPE_COORDS_INT_T newMaxX; // 2 bytes
    SHAPE_COORDS_INT_T newMinY; // 2 bytes
    SHAPE_COORDS_INT_T newMaxY; // 2 bytes
    SHAPE_COORDS_INT_T newMinZ; // 2 bytes
    SHAPE_COORDS_INT_T newMaxZ; // 2 bytes
    bool mustConsiderNewBounds; // 1 byte

    char pad[3];
};

///
Transaction *transaction_new(void) {
    Index3D *index3D = index3d_new();
    if (index3D == NULL) {
        return NULL;
    }

    Transaction *tr = (Transaction *)malloc(sizeof(Transaction));
    if (tr == NULL) {
        index3d_free(index3D);
        return NULL;
    }

    tr->index3D = index3D;
    tr->iterator = NULL;

    tr->newMinX = 0;
    tr->newMaxX = 0;

    tr->newMinY = 0;
    tr->newMaxY = 0;

    tr->newMinZ = 0;
    tr->newMaxZ = 0;

    tr->mustConsiderNewBounds = false;

    return tr;
}

void transaction_free(Transaction *const tr) {
    if (tr == NULL) {
        return;
    }
    index3d_flush(tr->index3D, blockChange_freeFunc);
    index3d_free(tr->index3D);
    tr->index3D = NULL;
    if (tr->iterator != NULL) {
        index3d_iterator_free(tr->iterator);
        tr->iterator = NULL;
    }
    free(tr);
}

Block *transaction_getCurrentBlockAt(const Transaction *const tr,
                                     const SHAPE_COORDS_INT_T x,
                                     const SHAPE_COORDS_INT_T y,
                                     const SHAPE_COORDS_INT_T z) {
    vx_assert(tr != NULL);
    vx_assert(tr->index3D != NULL);

    void *data = index3d_get(tr->index3D, x, y, z);

    if (data == NULL) {
        return NULL;
    }

    BlockChange *bc = (BlockChange *)data;

    return blockChange_getBlock(bc);
}

bool transaction_addBlock(Transaction *const tr,
                          const SHAPE_COORDS_INT_T x,
                          const SHAPE_COORDS_INT_T y,
                          const SHAPE_COORDS_INT_T z,
                          const SHAPE_COLOR_INDEX_INT_T colorIndex) {
    vx_assert(tr != NULL);
    vx_assert(tr->index3D != NULL);

    void *data = index3d_get(tr->index3D, x, y, z);

    BlockChange *bc = NULL;
    if (data == NULL) { // index doesn't contain a BlockChange for those coords

        bc = blockChange_new(colorIndex, x, y, z);
    } else { // index does contain a BlockChange for those coords already

        bc = (BlockChange *)data;
        blockChange_amend(bc, colorIndex);

        // this updates index3d iterator's internal list, remove it to push it again
        // after transaction cursor
        index3d_remove(tr->index3D, x, y, z, tr->iterator);
    }
    index3d_insert(tr->index3D, bc, x, y, z, tr->iterator);

    // update transaction bounds
    if (tr->mustConsiderNewBounds == false) {
        tr->newMinX = x;
        tr->newMinY = y;
        tr->newMinZ = z;
        tr->newMaxX = x;
        tr->newMaxY = y;
        tr->newMaxZ = z;
        tr->mustConsiderNewBounds = true;
    } else {
        if (x < tr->newMinX) {
            tr->newMinX = x;
        }
        if (y < tr->newMinY) {
            tr->newMinY = y;
        }
        if (z < tr->newMinZ) {
            tr->newMinZ = z;
        }
        if (x > tr->newMaxX) {
            tr->newMaxX = x;
        }
        if (y > tr->newMaxY) {
            tr->newMaxY = y;
        }
        if (z > tr->newMaxZ) {
            tr->newMaxZ = z;
        }
    }

    return true; // block is considered added
}

void transaction_removeBlock(const Transaction *const tr,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z) {
    vx_assert(tr != NULL);
    vx_assert(tr->index3D != NULL);

    void *data = index3d_get(tr->index3D, x, y, z);

    BlockChange *bc = NULL;
    if (data == NULL) { // index doesn't contain a BlockChange for those coords

        bc = blockChange_new(SHAPE_COLOR_INDEX_AIR_BLOCK, x, y, z);
    } else { // index does contain a BlockChange for those coords already

        bc = (BlockChange *)data;
        blockChange_amend(bc, SHAPE_COLOR_INDEX_AIR_BLOCK);

        // this updates index3d iterator's internal list, remove it to push it again
        // after transaction cursor
        index3d_remove(tr->index3D, x, y, z, tr->iterator);
    }
    index3d_insert(tr->index3D, bc, x, y, z, tr->iterator);
}

// x, y, z are Lua coords
void transaction_replaceBlock(const Transaction *const tr,
                              const SHAPE_COORDS_INT_T x,
                              const SHAPE_COORDS_INT_T y,
                              const SHAPE_COORDS_INT_T z,
                              const SHAPE_COLOR_INDEX_INT_T colorIndex) {
    vx_assert(tr != NULL);
    vx_assert(tr->index3D != NULL);

    void *data = index3d_get(tr->index3D, x, y, z);

    BlockChange *bc = NULL;
    if (data == NULL) { // index doesn't contain a BlockChange for those coords

        bc = blockChange_new(colorIndex, x, y, z);
    } else { // index does contain a BlockChange for those coords already

        bc = (BlockChange *)data;
        blockChange_amend(bc, colorIndex);

        // this updates index3d iterator's internal list, remove it to push it again
        // after transaction cursor
        index3d_remove(tr->index3D, x, y, z, tr->iterator);
    }
    index3d_insert(tr->index3D, bc, x, y, z, tr->iterator);
}

bool transaction_getMustConsiderNewBounds(const Transaction *const tr) {
    return tr != NULL && tr->mustConsiderNewBounds;
}

void transaction_getNewBounds(const Transaction *const tr,
                              SHAPE_COORDS_INT_T *const minX,
                              SHAPE_COORDS_INT_T *const minY,
                              SHAPE_COORDS_INT_T *const minZ,
                              SHAPE_COORDS_INT_T *const maxX,
                              SHAPE_COORDS_INT_T *const maxY,
                              SHAPE_COORDS_INT_T *const maxZ) {
    vx_assert(tr != NULL);
    if (minX != NULL) {
        *minX = tr->newMinX;
    }
    if (minY != NULL) {
        *minY = tr->newMinY;
    }
    if (minZ != NULL) {
        *minZ = tr->newMinZ;
    }
    if (maxX != NULL) {
        *maxX = tr->newMaxX;
    }
    if (maxY != NULL) {
        *maxY = tr->newMaxY;
    }
    if (maxZ != NULL) {
        *maxZ = tr->newMaxZ;
    }
}

Index3DIterator *transaction_getIndex3DIterator(Transaction *tr) {
    if (tr == NULL || tr->index3D == NULL) {
        return NULL;
    }
    if (tr->iterator != NULL) {
        return tr->iterator;
    }
    tr->iterator = index3d_iterator_new(tr->index3D);
    return tr->iterator;
}

void transaction_resetIndex3DIterator(Transaction *tr) {
    if (tr != NULL && tr->iterator != NULL) {
        index3d_iterator_free(tr->iterator);
        tr->iterator = NULL;
    }
}
