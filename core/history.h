// -------------------------------------------------------------
//  Cubzh Core
//  history.h
//  Created by Adrien Duermael on November 15, 2016.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

// An history is used to keep the last actions received by a World
// It can be used to undo/redo operations.
typedef struct _History History;
typedef struct _Shape Shape;
typedef struct _Transaction Transaction;

///
History *history_new(void);

///
void history_free(History *const h);

///
void history_discardTransactionsMoreRecentThanCursor(History *const h);

///
void history_pushTransaction(History *const h, Transaction *const tr);

///
bool history_can_undo(const History *const h);
Transaction *history_getTransactionToUndo(History *const h);

///
bool history_can_redo(const History *const h);
Transaction *history_getTransactionToRedo(History *const h);

#ifdef __cplusplus
} // extern "C"
#endif
