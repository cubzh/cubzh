// -------------------------------------------------------------
//  Cubzh Core
//  hash_uint32.c
//  Created by Adrien Duermael on August 15, 2022.
// -------------------------------------------------------------

#include "hash_uint32_int.h"

#include "cclog.h"
#include <stdio.h>

#define HASH_UINT32_BIT_SHIFT 4
// 32 / 4 = 8 levels
#define HASH_TREE_LEVELS 8
#define HASH_TREE_LEVELS_MINUS_ONE 7
#define HASH_UINT32_CHILDREN_PER_NODE 16
// % 16 (modulo) == & 15 (binary operation)
#define HASH_UINT32_BIN_MODULO 15 // 1111

typedef struct _HashUInt32IntNode HashUInt32IntNode;

struct _HashUInt32IntNode {
    void **slots;
    HashUInt32IntNode *parent;
    uint8_t level;
    uint8_t index;
};

struct _HashUInt32Int {
    HashUInt32IntNode *rootNode;
};

// when leaf == true, each branch slot contains a value, not another branch
HashUInt32IntNode *hash_uint32_node_new(HashUInt32IntNode *parent, uint8_t index, uint8_t level) {
    vx_assert(level <= HASH_TREE_LEVELS);
    HashUInt32IntNode *n = (HashUInt32IntNode *)malloc(sizeof(HashUInt32IntNode));
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
void hash_uint32_node_free(HashUInt32IntNode *n) {
    HashUInt32IntNode *cursor = n;
    HashUInt32IntNode *tmp = NULL;
    uint8_t slotCursor = 0;
    HashUInt32IntNode **slots;

    while (cursor != NULL) {
        if (slotCursor == HASH_UINT32_CHILDREN_PER_NODE ||
            cursor->level == HASH_TREE_LEVELS_MINUS_ONE) {
            // done freeing all children, or reached last level
            tmp = cursor->parent;
            slotCursor = cursor->index + 1;
            for (int i = 0; i < HASH_UINT32_CHILDREN_PER_NODE; ++i) {
                if (cursor->slots[i] != NULL) {
                    free(cursor->slots[i]);
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

        slots = (HashUInt32IntNode **)(cursor->slots);
        if (slots[slotCursor] != NULL) {
            cursor = slots[slotCursor];
            slotCursor = 0;
            continue;
        }
        ++slotCursor; // child is NULL, go see next
    }
}

HashUInt32Int *hash_uint32_int_new(void) {
    HashUInt32Int *h = (HashUInt32Int *)malloc(sizeof(HashUInt32Int));
    h->rootNode = hash_uint32_node_new(NULL, 0, 1);
    return h;
}

void hash_uint32_int_free(HashUInt32Int *h) {
    hash_uint32_node_free(h->rootNode);
    free(h);
}

void hash_uint32_int_set(HashUInt32Int *h, uint32_t key, int value) {
    int level = 1;
    HashUInt32IntNode *n = h->rootNode;
    vx_assert(n != NULL);
    uint8_t modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);
    HashUInt32IntNode **slots;

    while (true) {
        slots = (HashUInt32IntNode **)(n->slots);
        // cclog_debug("LEVEL: %d - modulo: %d", level, modulo);
        ++level;
        if (slots[modulo] == NULL) {
            slots[modulo] = hash_uint32_node_new(n, modulo, level);
        }
        n = slots[modulo];
        key = key >> HASH_UINT32_BIT_SHIFT;
        modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);

        if (level == HASH_TREE_LEVELS_MINUS_ONE) {
            slots = (HashUInt32IntNode **)(n->slots);
            int *i = (int *)slots[modulo];

            if (i == NULL) {
                slots[modulo] = (void *)malloc(sizeof(int *));
                i = (int *)slots[modulo];
            }

            *i = value;
            return;
        }
    }
}

bool hash_uint32_int_get(HashUInt32Int *h, uint32_t key, int *outValue) {
    int level = 1;
    HashUInt32IntNode *n = h->rootNode;
    vx_assert(n != NULL);
    uint8_t modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);
    HashUInt32IntNode **slots;

    while (true) {
        slots = (HashUInt32IntNode **)(n->slots);

        if (slots[modulo] == NULL) {
            return false;
        }
        n = slots[modulo];
        ++level;
        key = key >> HASH_UINT32_BIT_SHIFT;
        modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);

        if (level == HASH_TREE_LEVELS_MINUS_ONE) {

            slots = (HashUInt32IntNode **)(n->slots);
            int *i = (int *)slots[modulo];

            if (i == NULL) {
                return false;
            }

            *outValue = *i;
            return true;
        }
    }

    vx_assert(false); // should never reach this point
    return false;
}

void hash_uint32_int_delete(HashUInt32Int *h, uint32_t key) {
    int level = 1;
    HashUInt32IntNode *n = h->rootNode;
    HashUInt32IntNode *tmp = NULL;
    vx_assert(n != NULL);
    uint8_t modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);
    HashUInt32IntNode **slots;

    while (true) {
        slots = (HashUInt32IntNode **)(n->slots);

        if (slots[modulo] == NULL) {
            // not found, nothing to delete
            return;
        }
        n = slots[modulo];
        ++level;
        key = key >> HASH_UINT32_BIT_SHIFT;
        modulo = (uint8_t)(key & HASH_UINT32_BIN_MODULO);

        if (level == HASH_TREE_LEVELS_MINUS_ONE) {

            slots = (HashUInt32IntNode **)(n->slots);

            if (slots[modulo] == NULL) {
                // not found, nothing to delete
                return;
            }

            free(slots[modulo]); // free int* (value)
            slots[modulo] = NULL;
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
        hash_uint32_node_free(n);
        n = tmp;
    }
}
