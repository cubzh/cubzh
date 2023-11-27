// -------------------------------------------------------------
//  Cubzh Core
//  transaction.h
//  Created by Gaetan de Villele on July 22, 2021.
// -------------------------------------------------------------

#pragma once

#include "colors.h"

typedef struct _Block Block;
typedef struct _Index3D Index3D;
typedef struct _Index3DIterator Index3DIterator;
typedef struct _Transaction Transaction;

///
Transaction *transaction_new(void);

///
void transaction_free(Transaction *const tr);

/// x, y, z are Lua coordinates.
/// @returns changed block ptr or NULL if there is no block change for given coordinates.
/// The returned Block is owned by the transaction.
const Block *transaction_getCurrentBlockAt(const Transaction *const tr,
                                           const SHAPE_COORDS_INT_T x,
                                           const SHAPE_COORDS_INT_T y,
                                           const SHAPE_COORDS_INT_T z);

/// x, y, z are Lua coords
bool transaction_addBlock(Transaction *const tr,
                          const SHAPE_COORDS_INT_T x,
                          const SHAPE_COORDS_INT_T y,
                          const SHAPE_COORDS_INT_T z,
                          const SHAPE_COLOR_INDEX_INT_T colorIndex);

/// x, y, z are Lua coords
void transaction_removeBlock(const Transaction *const tr,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z);

/// x, y, z are Lua coords
void transaction_replaceBlock(const Transaction *const tr,
                              const SHAPE_COORDS_INT_T x,
                              const SHAPE_COORDS_INT_T y,
                              const SHAPE_COORDS_INT_T z,
                              const SHAPE_COLOR_INDEX_INT_T colorIndex);

/// Returns iterator at current position
/// Creating a new one if needed, starting at first operation.
/// The iterator is freed with its transaction.
/// To start over, transaction_resetIndex3DIterator should be called.
Index3DIterator *transaction_getIndex3DIterator(Transaction *const tr);

/// Resets transaction's Index3DIterator
void transaction_resetIndex3DIterator(Transaction *const tr);
