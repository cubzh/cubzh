// -------------------------------------------------------------
//  Cubzh Core
//  hash_uint32.c
//  Created by Adrien Duermael on August 15, 2022.
// -------------------------------------------------------------

#include "hash_uint32.h"

#include <stdio.h>

#include "cclog.h"
#include "config.h"

#define HASH_UINT32_BIT_SHIFT 2
// 32 / 2 = 16 levels
#define HASH_TREE_LEVELS 16
#define HASH_TREE_LEVELS_MINUS_ONE 15
#define HASH_UINT32_CHILDREN_PER_NODE 16
// % 16 (modulo) == & 15 (binary operation)
#define HASH_UINT32_BIN_MODULO 15 // 1111

typedef struct _HashUInt32Node HashUInt32Node;

struct _HashUInt32Node {
    void **slots;
    HashUInt32Node *parent;
    uint8_t level;
    uint8_t index;
};

struct _HashUInt32 {
    HashUInt32Node *rootNode;
    pointer_free_function freeFunc;
};

// when leaf == true, each branch slot contains a value, not another branch
HashUInt32Node *_hash_uint32_node_new(HashUInt32Node *parent, uint8_t index, uint8_t level) {
    vx_assert(level <= HASH_TREE_LEVELS);
    HashUInt32Node *const n = (HashUInt32Node *)malloc(sizeof(HashUInt32Node));
    void **slots = (void **)malloc(sizeof(void *) * HASH_UINT32_CHILDREN_PER_NODE);
    for (int i = 0; i < HASH_UINT32_CHILDREN_PER_NODE; ++i) {
        slots[i] = NULL;
    }
    n->slots = slots;
    n->parent = parent;
    n->level = level;
    n->index = index;
    return n;
}

// frees node and all children
// + sets parent slot to NULL
void _hash_uint32_node_free(HashUInt32Node *n, pointer_free_function freeFunc) {
    HashUInt32Node *cursor = n;
    HashUInt32Node *tmp = NULL;
    uint8_t slotCursor = 0;
    HashUInt32Node **slots;

    while (cursor != NULL) {
        if (slotCursor == HASH_UINT32_CHILDREN_PER_NODE ||
            cursor->level == HASH_TREE_LEVELS_MINUS_ONE) {
            // done freeing all children, or reached last level
            tmp = cursor->parent;
            slotCursor = cursor->index + 1;
            for (int i = 0; i < HASH_UINT32_CHILDREN_PER_NODE; ++i) {
                if (cursor->slots[i] != NULL) {
                    if (cursor->level == HASH_TREE_LEVELS_MINUS_ONE) {
                        if (freeFunc != NULL) {
                            freeFunc(cursor->slots[i]);
                        }
                    } else {
                        free(cursor->slots[i]);
                    }
                    cursor->slots[i] = NULL;
                }
            }
            if (tmp != NULL) {
                // set parent slot to NULL
                tmp->slots[cursor->index] = NULL;
            }
            if (cursor == n) {
                // don't free nodes above n
                tmp = NULL;
            }
            free(cursor->slots);
            free(cursor);
            cursor = tmp;
            continue;
        }

        slots = (HashUInt32Node **)(cursor->slots);
        if (slots[slotCursor] != NULL) {
            cursor = slots[slotCursor];
            slotCursor = 0;
            continue;
        }
        ++slotCursor; // child is NULL, go see next
    }
}

HashUInt32 *hash_uint32_new(pointer_free_function freeFunc) {
    HashUInt32 *h = (HashUInt32 *)malloc(sizeof(HashUInt32));
    h->rootNode = _hash_uint32_node_new(NULL, 0, 1);
    h->freeFunc = freeFunc;
    return h;
}

void hash_uint32_free(HashUInt32 *h) {
    _hash_uint32_node_free(h->rootNode, h->freeFunc);
    free(h);
}

void hash_uint32_set(HashUInt32 *const h, uint32_t key, void *value) {
    uint8_t level = 1;
    HashUInt32Node *n = h->rootNode;
    vx_assert(n != NULL);
    uint8_t modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);
    HashUInt32Node **slots;

    while (true) {
        slots = (HashUInt32Node **)(n->slots);
        // cclog_debug("LEVEL: %d - modulo: %d", level, modulo);
        ++level;
        if (slots[modulo] == NULL) {
            slots[modulo] = _hash_uint32_node_new(n, modulo, level);
        }
        n = slots[modulo];
        key = key >> HASH_UINT32_BIT_SHIFT;
        modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);

        if (level == HASH_TREE_LEVELS_MINUS_ONE) {
            //vx_assert_d(n->slots[modulo] == NULL);
            n->slots[modulo] = value;
            return;
        }
    }
}

bool hash_uint32_get(HashUInt32 *h, uint32_t key, void **outValue) {
    int level = 1;
    HashUInt32Node *n = h->rootNode;
    vx_assert(n != NULL);
    uint8_t modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);
    HashUInt32Node **slots;

    while (true) {
        slots = (HashUInt32Node **)(n->slots);

        if (slots[modulo] == NULL) {
            return false;
        }
        n = slots[modulo];
        ++level;
        key = key >> HASH_UINT32_BIT_SHIFT;
        modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);

        if (level == HASH_TREE_LEVELS_MINUS_ONE) {
            if (n->slots[modulo] == NULL) {
                return false;
            }
            if (outValue != NULL) {
                *outValue = n->slots[modulo];
            }
            return true;
        }
    }

    vx_assert(false); // should never reach this point
    return false;
}

void hash_uint32_delete(HashUInt32 *h, uint32_t key) {
    int level = 1;
    HashUInt32Node *n = h->rootNode;
    HashUInt32Node *tmp = NULL;
    vx_assert(n != NULL);
    uint8_t modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);
    HashUInt32Node **slots;

    while (true) {
        slots = (HashUInt32Node **)(n->slots);

        if (slots[modulo] == NULL) {
            // not found, nothing to delete
            return;
        }
        n = slots[modulo];
        ++level;
        key = key >> HASH_UINT32_BIT_SHIFT;
        modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);

        if (level == HASH_TREE_LEVELS_MINUS_ONE) {
            if (n->slots[modulo] == NULL) {
                // not found, nothing to delete
                return;
            }
            if (h->freeFunc != NULL) {
                h->freeFunc(n->slots[modulo]);
            }
            n->slots[modulo] = NULL;
            break;
        }
    }

    // cleanup empty parents (except root node)
    while (n != NULL && n->level > 1) {
        for (int i = 0; i < HASH_UINT32_CHILDREN_PER_NODE; ++i) {
            if (n->slots[i] != NULL) {
                return; // at least one slot not empty, stop
            }
        }
        tmp = n->parent;
        _hash_uint32_node_free(n, NULL);
        n = tmp;
    }
}

void hash_uint32_flush(HashUInt32 *h) {
    for (int i = 0; i < HASH_UINT32_CHILDREN_PER_NODE; ++i) {
        if (h->rootNode->slots[i] != NULL) {
            _hash_uint32_node_free(h->rootNode->slots[i], h->freeFunc);
            h->rootNode->slots[i] = NULL;
        }
    }
}
