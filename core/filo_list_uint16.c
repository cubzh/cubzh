// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_uint16.c
//  Created by Gaetan de Villele on February 10, 2019.
// -------------------------------------------------------------

#include "filo_list_uint16.h"

#include <stdlib.h>

struct _FiloListUInt16 {
    FiloListUInt16Node *first;
};

struct _FiloListUInt16Node {
    FiloListUInt16Node *next; /* 8 bytes */
    // stored integer
    uint16_t value; /* 2 bytes */
    char pad[6];
};

// private prototypes

FiloListUInt16Node *filo_list_uint16_node_new(uint16_t value);
void filo_list_uint16_node_free(FiloListUInt16Node *node);

//---------------------
// FiloListUInt16
//---------------------

FiloListUInt16 *filo_list_uint16_new(void) {
    FiloListUInt16 *list = (FiloListUInt16 *)malloc(sizeof(FiloListUInt16));
    list->first = NULL;
    return list;
}

void filo_list_uint16_free(FiloListUInt16 *list) {
    while (list->first != NULL) {
        filo_list_uint16_pop(list, NULL);
    }
    free(list);
}

void filo_list_uint16_push(FiloListUInt16 *list, uint16_t value) {
    FiloListUInt16Node *newNode = filo_list_uint16_node_new(value);
    if (list->first != NULL)
        newNode->next = list->first;
    list->first = newNode;
}

bool filo_list_uint16_pop(FiloListUInt16 *list, uint16_t *i) {
    if (list == NULL || list->first == NULL) {
        return false;
    }

    FiloListUInt16Node *node = list->first;
    if (i != NULL) {
        *i = node->value;
    }
    list->first = node->next;

    filo_list_uint16_node_free(node);
    return true;
}

//---------------------
// FiloListUint16Node
//---------------------

FiloListUInt16Node *filo_list_uint16_node_new(uint16_t value) {
    FiloListUInt16Node *node = (FiloListUInt16Node *)malloc(sizeof(FiloListUInt16Node));
    node->next = NULL;
    node->value = value;
    return node;
}

void filo_list_uint16_node_free(FiloListUInt16Node *node) {
    free(node);
}
