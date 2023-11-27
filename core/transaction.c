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

    // no padding
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

const Block *transaction_getCurrentBlockAt(const Transaction *const tr,
                                           const SHAPE_COORDS_INT_T x,
                                           const SHAPE_COORDS_INT_T y,
                                           const SHAPE_COORDS_INT_T z) {
    vx_assert(tr != NULL);
    vx_assert(tr->index3D != NULL);

    void *data = index3d_get(tr->index3D, x, y, z);

    if (data == NULL) {
        return NULL;
    }

    return blockChange_getBlock((BlockChange *)data);
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
#ifdef DEBUG
        void *ptr = index3d_remove(tr->index3D, x, y, z, tr->iterator);
        vx_assert(ptr == data);
#else
        index3d_remove(tr->index3D, x, y, z, tr->iterator);
#endif
    }
    index3d_insert(tr->index3D, bc, x, y, z, tr->iterator);

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
#ifdef DEBUG
        void *ptr = index3d_remove(tr->index3D, x, y, z, tr->iterator);
        vx_assert(ptr == data);
#else
        index3d_remove(tr->index3D, x, y, z, tr->iterator);
#endif
    }
    index3d_insert(tr->index3D, bc, x, y, z, tr->iterator);
}

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
#ifdef DEBUG
        void *ptr = index3d_remove(tr->index3D, x, y, z, tr->iterator);
        vx_assert(ptr == data);
#else
        index3d_remove(tr->index3D, x, y, z, tr->iterator);
#endif
    }
    index3d_insert(tr->index3D, bc, x, y, z, tr->iterator);
}

Index3DIterator *transaction_getIndex3DIterator(Transaction *const tr) {
    if (tr == NULL || tr->index3D == NULL) {
        return NULL;
    }
    if (tr->iterator != NULL) {
        return tr->iterator;
    }
    tr->iterator = index3d_iterator_new(tr->index3D);
    return tr->iterator;
}

void transaction_resetIndex3DIterator(Transaction *const tr) {
    if (tr != NULL && tr->iterator != NULL) {
        index3d_iterator_free(tr->iterator);
        tr->iterator = NULL;
    }
}
