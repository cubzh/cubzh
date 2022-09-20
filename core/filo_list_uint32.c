// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_uint32.c
//  Created by Adrien Duermael on August 14, 2017.
// -------------------------------------------------------------

#include "filo_list_uint32.h"

#include <stdlib.h>

struct _FiloListUInt32 {
    FiloListUInt32Node *first;
};

struct _FiloListUInt32Node {
    FiloListUInt32Node *next; /* 8 bytes */
    // stored integer
    uint32_t value; /* 4 bytes */
    char pad[4];
};

FiloListUInt32Node *filo_list_uint32_node_new(uint32_t value);
void filo_list_uint32_node_free(FiloListUInt32Node *node);

FiloListUInt32 *filo_list_uint32_new(void) {
    FiloListUInt32 *list = (FiloListUInt32 *)malloc(sizeof(FiloListUInt32));
    list->first = NULL;
    return list;
}

void filo_list_uint32_free(FiloListUInt32 *list) {
    while (list->first != NULL) {
        filo_list_uint32_pop(list, NULL);
    }
    free(list);
}

void filo_list_uint32_push(FiloListUInt32 *list, uint32_t value) {
    FiloListUInt32Node *newNode = filo_list_uint32_node_new(value);
    if (list->first != NULL)
        newNode->next = list->first;
    list->first = newNode;
}

bool filo_list_uint32_pop(FiloListUInt32 *list, uint32_t *i) {
    if (list == NULL || list->first == NULL) {
        return false;
    }

    FiloListUInt32Node *node = list->first;
    if (i != NULL) {
        *i = node->value;
    }
    list->first = node->next;

    filo_list_uint32_node_free(node);
    return true;
}

FiloListUInt32Node *filo_list_uint32_node_new(uint32_t value) {
    FiloListUInt32Node *node = (FiloListUInt32Node *)malloc(sizeof(FiloListUInt32Node));
    node->next = NULL;
    node->value = value;
    return node;
}

void filo_list_uint32_node_free(FiloListUInt32Node *node) {
    free(node);
}
