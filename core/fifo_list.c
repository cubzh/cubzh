// -------------------------------------------------------------
//  Cubzh Core
//  fifo_list.c
//  Created by Adrien Duermael on June 27, 2019.
// -------------------------------------------------------------

#include "fifo_list.h"

#include <stdio.h>
#include <stdlib.h>

struct _FifoListNode {
    FifoListNode *next;
    // stored pointer
    void *ptr;
};

struct _FifoList {
    FifoListNode *first;
    FifoListNode *last;
    uint32_t size;
};

// private prototypes

FifoListNode *fifo_list_node_new(void *ptr);
void fifo_list_node_free(FifoListNode *node);

//---------------------
// FifoList
//---------------------

FifoList *fifo_list_new(void) {
    FifoList *list = (FifoList *)malloc(sizeof(FifoList));
    list->first = NULL;
    list->last = NULL;
    list->size = 0;
    return list;
}

FifoList *fifo_list_new_copy(const FifoList *list) {
    FifoList *copy = fifo_list_new();
    FifoListNode *n = list->first;
    while (n != NULL) {
        fifo_list_push(copy, n->ptr);
        n = n->next;
    }
    return copy;
}

void fifo_list_free(FifoList *list, pointer_free_function freeFunc) {
    while (list->first != NULL) {
        void *storedPtr = fifo_list_pop(list);
        if (freeFunc != NULL) {
            freeFunc(storedPtr);
        }
    }
    free(list);
}

void fifo_list_push(FifoList *list, void *ptr) {
    FifoListNode *newNode = fifo_list_node_new(ptr);
    if (list->first == NULL) {
        list->first = newNode;
        list->last = newNode;
    } else {
        list->last->next = newNode;
        list->last = newNode;
    }
    list->size++;
}

void *fifo_list_pop(FifoList *list) {

    if (list->first == NULL) {
        return NULL;
    }

    FifoListNode *node = list->first;
    void *ptr = node->ptr;
    list->first = node->next;

    if (list->first == NULL) {
        list->last = NULL;
    }

    fifo_list_node_free(node);
    list->size--;
    return ptr;
}

void fifo_list_empty_freefunc(void *a) {
    (void)a;
}

void fifo_list_flush(FifoList *list, pointer_free_function freeFunc) {
    while (list->first != NULL) {
        freeFunc(fifo_list_pop(list));
    }
    list->size = 0;
}

//---------------------
// FifoListNode
//---------------------

FifoListNode *fifo_list_node_new(void *ptr) {
    FifoListNode *node = (FifoListNode *)malloc(sizeof(FifoListNode));
    node->next = NULL;
    node->ptr = ptr;
    return node;
}

void fifo_list_node_free(FifoListNode *node) {
    free(node);
}

uint32_t fifo_list_get_size(const FifoList *list) {
    return list->size;
}
