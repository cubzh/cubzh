// -------------------------------------------------------------
//  Cubzh Core
//  filo_list.c
//  Created by Adrien Duermael on August 14, 2017.
// -------------------------------------------------------------

#include "filo_list.h"

#include <stdlib.h>

typedef struct _FiloListNode FiloListNode;

struct _FiloList {
    FiloListNode *first;
};

struct _FiloListNode {
    FiloListNode *next;
    // stored pointer
    void *ptr;
};

FiloListNode *filo_list_node_new(void *ptr);
void filo_list_node_free(FiloListNode *node);

FiloList *filo_list_new(void) {
    FiloList *list = (FiloList *)malloc(sizeof(FiloList));
    list->first = NULL;
    return list;
}

void filo_list_free(FiloList *list) {
    while (list->first != NULL) {
        filo_list_pop(list);
    }
    free(list);
}

void filo_list_push(FiloList *list, void *ptr) {
    FiloListNode *newNode = filo_list_node_new(ptr);
    if (list->first != NULL) {
        newNode->next = list->first;
    }
    list->first = newNode;
}

void *filo_list_pop(FiloList *list) {
    if (list->first == NULL) {
        return NULL;
    }

    FiloListNode *node = list->first;
    list->first = node->next;
    void *ptr = node->ptr;

    filo_list_node_free(node);
    return ptr;
}

FiloListNode *filo_list_node_new(void *ptr) {
    FiloListNode *node = (FiloListNode *)malloc(sizeof(FiloListNode));
    node->next = NULL;
    node->ptr = ptr;
    return node;
}

void filo_list_node_free(FiloListNode *node) {
    free(node);
}
