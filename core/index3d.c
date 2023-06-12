// -------------------------------------------------------------
//  Cubzh Core
//  index3d.c
//  Created by Adrien Duermael on December 3, 2016.
// -------------------------------------------------------------

#include "index3d.h"

#include <stdbool.h>
#include <stdlib.h>

#include "cclog.h"

// has to be a power of two
#define INDEX_NODE_SIZE 64
#define INDEX_NODE_BITWISE_MODULO (INDEX_NODE_SIZE - 1)
// the extra slot is used to go from x > y and y > z or store the actual pointer
#define INDEX_NODE_ARRAY_SIZE (INDEX_NODE_SIZE + 1)
#define INDEX_DIVIDE_BYTES 6

struct _Index3D {
    void **topLevelNode;
    DoublyLinkedList *list;
};

struct _Index3DIterator {
    DoublyLinkedListNode *current;
};

//-------------------
// Index3D
//-------------------

static void **_new_node(void) {
    void **arr = (void **)malloc(INDEX_NODE_ARRAY_SIZE * sizeof(void *));
    for (int i = 0; i < INDEX_NODE_ARRAY_SIZE; i++) {
        arr[i] = NULL;
    }
    return arr;
}

void *index3d_get(const Index3D *index, const int32_t x, const int32_t y, const int32_t z) {

    // only use unsigned integers for bitwise operations:
    static uint32_t ux;
    static uint32_t uy;
    static uint32_t uz;

    ux = (uint32_t)x;
    uy = (uint32_t)y;
    uz = (uint32_t)z;

    //    static void** currentNode;
    void **currentNode = index->topLevelNode;

    static uint32_t modulo;
    static uint32_t quotient;
    modulo = ux & INDEX_NODE_BITWISE_MODULO;
    quotient = ux >> INDEX_DIVIDE_BYTES;

    // look for x

    while (1) {
        // found, go to y
        if (quotient == 0 && modulo == 0) {
            currentNode = (void **)currentNode[INDEX_NODE_ARRAY_SIZE - 1];
            if (currentNode == NULL) {
                // not found
                return NULL;
            }
            break;
        }

        currentNode = (void **)currentNode[modulo];

        if (currentNode == NULL) {
            // not found
            return NULL;
        }

        if (quotient == 0) {
            // making sure we're going to y in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    // look for y

    modulo = uy & INDEX_NODE_BITWISE_MODULO;
    quotient = uy >> INDEX_DIVIDE_BYTES;

    while (1) {
        // found, go to z
        if (quotient == 0 && modulo == 0) {
            currentNode = (void **)currentNode[INDEX_NODE_ARRAY_SIZE - 1];
            if (currentNode == NULL) {
                // not found
                return NULL;
            }
            break;
        }

        currentNode = (void **)currentNode[modulo];

        if (currentNode == NULL) {
            // not found
            return NULL;
        }

        if (quotient == 0) {
            // making sure we're going to z in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    // look for z

    modulo = uz & INDEX_NODE_BITWISE_MODULO;
    quotient = uz >> INDEX_DIVIDE_BYTES;

    while (1) {
        // found!!!!
        if (quotient == 0 && modulo == 0) {
            return doubly_linked_list_node_pointer(
                (const DoublyLinkedListNode *)currentNode[INDEX_NODE_ARRAY_SIZE - 1]);
        }

        currentNode = (void **)currentNode[modulo];

        if (currentNode == NULL) {
            // not found
            return NULL;
        }

        if (quotient == 0) {
            // making sure we're going to z in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    return NULL;
}

void *index3d_remove(Index3D *index,
                     const int32_t x,
                     const int32_t y,
                     const int32_t z,
                     Index3DIterator *it) {

    // only use unsigned integers for bitwise operations:
    uint32_t ux = (uint32_t)x;
    uint32_t uy = (uint32_t)y;
    uint32_t uz = (uint32_t)z;

    void **currentNode = index->topLevelNode;

    uint32_t modulo = ux & INDEX_NODE_BITWISE_MODULO;
    uint32_t quotient = ux >> INDEX_DIVIDE_BYTES;

    // look for x

    while (1) {
        // found, go to y
        if (quotient == 0 && modulo == 0) {
            currentNode = (void **)currentNode[INDEX_NODE_ARRAY_SIZE - 1];
            if (currentNode == NULL) {
                // not found
                return NULL;
            }
            break;
        }

        currentNode = (void **)currentNode[modulo];

        if (currentNode == NULL) {
            // not found
            return NULL;
        }

        if (quotient == 0) {
            // making sure we're going to y in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    // look for y

    modulo = uy & INDEX_NODE_BITWISE_MODULO;
    quotient = uy >> INDEX_DIVIDE_BYTES;

    while (1) {
        // found, go to z
        if (quotient == 0 && modulo == 0) {
            currentNode = (void **)currentNode[INDEX_NODE_ARRAY_SIZE - 1];
            if (currentNode == NULL) {
                // not found
                return NULL;
            }
            break;
        }

        currentNode = (void **)currentNode[modulo];

        if (currentNode == NULL) {
            // not found
            return NULL;
        }

        if (quotient == 0) {
            // making sure we're going to z in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    // look for z

    modulo = uz & INDEX_NODE_BITWISE_MODULO;
    quotient = uz >> INDEX_DIVIDE_BYTES;

    while (1) {
        // found!!!!
        if (quotient == 0 && modulo == 0) {
            // Note: maybe the node itself can be destroyed if contains nothing
            // else, but it's good enough for now.
            void *node = currentNode[INDEX_NODE_ARRAY_SIZE - 1];
            currentNode[INDEX_NODE_ARRAY_SIZE - 1] = NULL;

            // optionally maintain ongoing iterator, if at node being removed
            if (it != NULL && it->current == node) {
                it->current = doubly_linked_list_node_previous(it->current);
            }

            void *ptr = doubly_linked_list_node_pointer((const DoublyLinkedListNode *)node);
            doubly_linked_list_delete_node(index->list, (DoublyLinkedListNode *)node);
            return ptr;
        }

        currentNode = (void **)currentNode[modulo];

        if (currentNode == NULL) {
            // not found
            return NULL;
        }

        if (quotient == 0) {
            // making sure we're going to z in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    return NULL;
}

void index3d_insert(Index3D *index,
                    void *ptr,
                    const int32_t x,
                    const int32_t y,
                    const int32_t z,
                    Index3DIterator *it) {

    // only use unsigned integers for bitwise operations:
    uint32_t ux = (uint32_t)x;
    uint32_t uy = (uint32_t)y;
    uint32_t uz = (uint32_t)z;

    void **currentNode = index->topLevelNode;

    uint32_t modulo = ux & INDEX_NODE_BITWISE_MODULO;
    uint32_t quotient = ux >> INDEX_DIVIDE_BYTES;

    // set x

    while (1) {
        // printf("x -- q: %u - m: %u\n", quotient, modulo);
        // found, go to y
        if (quotient == 0 && modulo == 0) {
            if (currentNode[INDEX_NODE_ARRAY_SIZE - 1] == NULL) {
                currentNode[INDEX_NODE_ARRAY_SIZE - 1] = _new_node();
            }
            currentNode = (void **)currentNode[INDEX_NODE_ARRAY_SIZE - 1];
            break;
        }

        if (currentNode[modulo] == NULL) {
            currentNode[modulo] = _new_node();
        }
        currentNode = (void **)currentNode[modulo];

        if (quotient == 0) {
            // making sure we're going to y in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    // set y

    modulo = uy & INDEX_NODE_BITWISE_MODULO;
    quotient = uy >> INDEX_DIVIDE_BYTES;

    while (1) {
        // printf("y -- q: %u - m: %u\n", quotient, modulo);
        // found, go to z
        if (quotient == 0 && modulo == 0) {
            if (currentNode[INDEX_NODE_ARRAY_SIZE - 1] == NULL) {
                currentNode[INDEX_NODE_ARRAY_SIZE - 1] = _new_node();
            }
            currentNode = (void **)currentNode[INDEX_NODE_ARRAY_SIZE - 1];
            break;
        }

        if (currentNode[modulo] == NULL) {
            currentNode[modulo] = _new_node();
        }
        currentNode = (void **)currentNode[modulo];

        if (quotient == 0) {
            // making sure we're going to y in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }

    // set z

    modulo = uz & INDEX_NODE_BITWISE_MODULO;
    quotient = uz >> INDEX_DIVIDE_BYTES;

    while (1) {
        // printf("z -- q: %u - m: %u\n", quotient, modulo);
        // found, go to z
        if (quotient == 0 && modulo == 0) {
            DoublyLinkedListNode *node = doubly_linked_list_push_last(index->list, ptr);
            currentNode[INDEX_NODE_ARRAY_SIZE - 1] = node;

            // optionally maintain ongoing iterator, if at the end
            if (it != NULL && it->current == NULL) {
                it->current = node;
            }
            break;
        }

        if (currentNode[modulo] == NULL) {
            currentNode[modulo] = _new_node();
        }
        currentNode = (void **)currentNode[modulo];

        if (quotient == 0) {
            // making sure we're going to y in next loop
            modulo = 0;
        } else {
            // go deeper
            modulo = quotient & INDEX_NODE_BITWISE_MODULO;
            quotient = quotient >> INDEX_DIVIDE_BYTES;
        }
    }
}

/// returns whether index is empty
bool index3d_is_empty(const Index3D *const index) {
    for (int i = 0; i < INDEX_NODE_ARRAY_SIZE; i++) {
        if (index->topLevelNode[i] != NULL) {
            return false;
        }
    }
    return true;
}

void index3d_flush_node(Index3D *index,
                        void **node,
                        uint8_t dimension,
                        pointer_free_function freePtr) {
    if (node == NULL)
        return;

    int lastIndex = INDEX_NODE_ARRAY_SIZE - 1;

    for (int i = 0; i < lastIndex; i++) {
        if (node[i] != NULL) {
            index3d_flush_node(index, (void **)(node[i]), dimension, freePtr);
            free(node[i]);
            node[i] = NULL;
        }
    }

    // go to next dimension or free content if looking in 3rd one
    if (node[lastIndex] != NULL) {
        if (dimension < 3) {
            index3d_flush_node(index, (void **)(node[lastIndex]), dimension + 1, freePtr);
            free(node[lastIndex]);
            node[lastIndex] = NULL;
        } else {
            void *ptr = doubly_linked_list_node_pointer(
                (const DoublyLinkedListNode *)(node[lastIndex]));
            if (freePtr != NULL) {
                freePtr(ptr);
            }
            doubly_linked_list_delete_node(index->list, (DoublyLinkedListNode *)(node[lastIndex]));
            node[lastIndex] = NULL;
        }
    }
}

Index3D *index3d_new(void) {
    Index3D *index = (Index3D *)malloc(sizeof(Index3D));
    index->topLevelNode = _new_node();
    index->list = doubly_linked_list_new();
    return index;
}

void index3d_free(Index3D *index) {
    if (index == NULL) {
        return;
    }
    if (index3d_is_empty(index) == false) {
        cclog_error("⚠️ index3d_free error: index is not empty (possible memory leak)");
    }
    doubly_linked_list_free(index->list);
    free(index->topLevelNode);
    free(index);
}

void index3d_flush(Index3D *index, pointer_free_function ptr) {
    if (index3d_is_empty(index) == true) {
        return;
    }
    // list nodes are freed correctly within index3d_flush_node
    index3d_flush_node(index, index->topLevelNode, 1, ptr);
    // so it's now safe to free the list and create a new one
    doubly_linked_list_free(index->list);
    index->list = doubly_linked_list_new();
}

//-------------------
// Index3DIterator
//-------------------

Index3DIterator *index3d_iterator_new(Index3D *index) {
    Index3DIterator *it = (Index3DIterator *)malloc(sizeof(Index3DIterator));
    it->current = doubly_linked_list_first(index->list);
    return it;
}

void index3d_iterator_free(Index3DIterator *it) {
    // the list nodes are the Index3D's responsibility
    free(it);
}

void *index3d_iterator_pointer(const Index3DIterator *it) {
    return doubly_linked_list_node_pointer(it->current);
}

void index3d_iterator_next(Index3DIterator *it) {
    it->current = doubly_linked_list_node_next(it->current);
}

bool index3d_iterator_is_at_end(const Index3DIterator *it) {
    return doubly_linked_list_node_next(it->current) == NULL;
}
