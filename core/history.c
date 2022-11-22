// -------------------------------------------------------------
//  Cubzh Core
//  history.c
//  Created by Adrien Duermael on November 15, 2016.
// -------------------------------------------------------------

#include "history.h"

#include <stdbool.h>
#include <stdlib.h>

#include "block.h"
#include "cclog.h"
#include "int3.h"
#include "shape.h"
#include "transaction.h"

typedef struct _HistoryTransaction HistoryTransaction;

void _history_flush(History *const h);

struct _HistoryTransaction {
    HistoryTransaction *previousAction; // 8 bytes
    HistoryTransaction *nextAction;     // 8 bytes
    Transaction *transaction;           // 8 bytes
};

HistoryTransaction *history_transaction_new(Transaction *const tr) {
    HistoryTransaction *ht = (HistoryTransaction *)malloc(sizeof(HistoryTransaction));
    ht->previousAction = NULL;
    ht->nextAction = NULL;
    ht->transaction = tr;
    return ht;
}

void history_transaction_free(HistoryTransaction *const ht) {
    if (ht != NULL) {
        transaction_free(ht->transaction);
        free(ht);
    }
}

struct _History {
    // history
    HistoryTransaction *latest; // 8 bytes
    HistoryTransaction *oldest; // 8 bytes
    HistoryTransaction *cursor; // 8 bytes

    uint16_t limit;     // 2 bytes
    uint16_t nbActions; // 2 bytes

    char pad[4]; // 4 bytes
};

History *history_new(void) {
    History *h = (History *)malloc(sizeof(History));
    // h->pendingTransaction = NULL;
    h->latest = NULL;
    h->oldest = NULL;
    h->cursor = NULL;
    h->limit = NB_UNDOABLE_ACTIONS;
    h->nbActions = 0;
    return h;
}

void history_free(History *const h) {
    if (h != NULL) {
        // transaction_free(h->pendingTransaction);
        _history_flush(h);
        free(h);
    }
}

void history_pushTransaction(History *const h, Transaction *const tr) {
    vx_assert(h != NULL);
    vx_assert(tr != NULL);

    if (h == NULL || tr == NULL) {
        return;
    }

    HistoryTransaction *const htr = history_transaction_new(tr);

    if (h->oldest == NULL) {
        // history doesn't contain anything yet, we are setting the first transaction in it.
        // cursor and latest should be NULL
        if (h->cursor != NULL || h->latest != NULL) {
            cclog_error("HISTORY",
                        "cursor (%p) and latest (%p) should be NULL",
                        (void *)h->cursor,
                        (void *)h->latest);
            history_transaction_free(htr);
            return;
        }
        h->oldest = htr;
        h->cursor = htr;
        h->latest = htr;
        h->nbActions = 1;

    } else {
        // there is at least one transaction in history
        // cursor and latest should NOT be NULL
        if (h->latest == NULL || h->cursor == NULL) {
            cclog_error("HISTORY",
                        "latest (%p) and cursor (%p) should NOT be NULL",
                        (void *)h->latest,
                        (void *)h->cursor);
            history_transaction_free(htr);
            return;
        }

        // If a transaction is pushed after one or several "undo" operations,
        // we forget about the previous timeline as a new one is created.
        // (deletes all actions after h->cursor)
        history_discardTransactionsMoreRecentThanCursor(h);

        // update cross-references between current latest and new latest
        htr->previousAction = h->latest;
        h->latest->nextAction = htr;
        // set new latest
        h->latest = htr;
        h->cursor = h->latest;
        h->nbActions++;
    }

    // if there's no space to add an action, we remove the oldest ones
    while (h->nbActions > h->limit) {
        if (h->oldest != NULL) {
            // there is at least one action in history
            HistoryTransaction *toDelete = h->oldest;

            if (h->oldest->nextAction == NULL) {
                // there is only one action in history, empty the history
                h->oldest = NULL;
                h->cursor = NULL;
                h->latest = NULL;
            } else {
                // there are more than one action in history
                // set new oldest action
                h->oldest = h->oldest->nextAction;
                // new oldest cannot have a previous
                h->oldest->previousAction = NULL;
            }

            history_transaction_free(toDelete);
            h->nbActions--;
        } else {
            // do nothing if there is no oldest action (cursor and latest should be NULL)
            if (h->cursor != NULL || h->latest != NULL) {
                cclog_error("HISTORY",
                            "cursor (%p) and latest (%p) should be NULL [2]",
                            (void *)h->cursor,
                            (void *)h->latest);
                return;
            }
        }
    }
}

bool history_can_undo(const History *const h) {
    if (h == NULL) {
        cclog_error("HISTORY", "history_can_undo: history reference is NULL");
        return false;
    }
    return h->cursor != NULL;
}

Transaction *history_getTransactionToUndo(History *const h) {
    if (h == NULL) {
        cclog_error("HISTORY", "%s error: history reference is NULL", __func__);
        return NULL;
    }

    if (h->cursor == NULL) {
        return NULL;
    }

    // transaction to undo
    Transaction *tr = h->cursor->transaction;

    // update h->cursor with h->cursor->previous value
    h->cursor = h->cursor->previousAction;

    return tr;
}

bool history_can_redo(const History *const h) {
    return (h->cursor == NULL && h->oldest != NULL) || (h->cursor != NULL && h->cursor->nextAction != NULL);
}

Transaction *history_getTransactionToRedo(History *const h) {
    if (h == NULL) {
        cclog_error("HISTORY", "%s error: history reference is NULL", __func__);
        return NULL;
    }

    Transaction *tr = NULL;

    if (h->cursor == NULL) {
        // the transaction to redo is "oldest"
        if (h->oldest != NULL) {
            tr = h->oldest->transaction;
            h->cursor = h->oldest;
        }
    } else if (h->cursor->nextAction != NULL) {
        tr = h->cursor->nextAction->transaction;
        // update h->cursor with h->cursor->next value
        h->cursor = h->cursor->nextAction;
    }

    return tr;
}

void _history_flush(History *const h) {
    if (h == NULL) {
        return;
    }
    // free all actions
    HistoryTransaction *oldest = h->oldest;
    while (oldest != NULL) {
        HistoryTransaction *toDelete = oldest;
        oldest = oldest->nextAction;
        history_transaction_free(toDelete);
        h->nbActions--;
    }
    h->oldest = NULL;
    h->cursor = NULL;
    h->latest = NULL;
    h->nbActions = 0;
}

void history_discardTransactionsMoreRecentThanCursor(History *const h) {
    if (h == NULL) {
        return;
    }
    if (h->cursor == h->latest) {
        return;
    }

    HistoryTransaction *afterCursor = NULL;
    if (h->cursor != NULL) {
        afterCursor = h->cursor->nextAction;
    } else {
        afterCursor = h->oldest;
        h->oldest = NULL; // oldest is about to be freed, we can set it to NULL already
    }

    // deletes all actions after h->cursor
    while (afterCursor != NULL) {
        HistoryTransaction *toDelete = afterCursor;
        afterCursor = afterCursor->nextAction;
        history_transaction_free(toDelete);
        h->nbActions--;
    }

    if (h->cursor != NULL) {
        h->cursor->nextAction = NULL;
    }
    h->latest = h->cursor;
}
