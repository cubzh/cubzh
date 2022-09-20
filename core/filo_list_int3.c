// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_int3.c
//  Created by Adrien Duermael on January 20, 2018.
// -------------------------------------------------------------

#include "filo_list_int3.h"

#include <stdio.h>

#include "cclog.h"

struct _FiloListInt3Node {
    FiloListInt3Node *next; /* 8 bytes */
    int3 *value;            /* 8 bytes */
};

// private prototypes

FiloListInt3Node *filo_list_int3_node_new(FiloListInt3 *list);
void filo_list_int3_node_free(FiloListInt3Node *node);
FiloListInt3Node *filo_list_int3_pop_node(FiloListInt3 *list);
FiloListInt3Node *filo_list_int3_pop_node_no_gen(FiloListInt3 *list);
FiloListInt3Node *filo_list_int3_pop_in_use_node(FiloListInt3 *list);
void filo_list_int3_push_node(FiloListInt3 *list, FiloListInt3Node *node);
void filo_list_int3_push_in_use_node(FiloListInt3 *list, FiloListInt3Node *node);

// FiloListInt3Node *filo_list_int3_node_new(int32_t x, int32_t y, int32_t z);
// void filo_list_int3_node_free(FiloListInt3Node *node);

//---------------------
// FiloListUInt32
//---------------------

FiloListInt3 *filo_list_int3_new(size_t maxNodes) {
    FiloListInt3 *list = (FiloListInt3 *)malloc(sizeof(FiloListInt3));
    list->first = NULL;
    list->inUseFirst = NULL;
    list->maxNodes = maxNodes;
    list->nbNodes = 0;
    return list;
}

void filo_list_int3_free(FiloListInt3 *list) {
    FiloListInt3Node *node;
    while (list->first != NULL) {
        node = filo_list_int3_pop_node(list);
        filo_list_int3_node_free(node);
    }
    while (list->inUseFirst != NULL) {
        node = filo_list_int3_pop_in_use_node(list);
        filo_list_int3_node_free(node);
    }
    free(list);
}

void filo_list_int3_push(FiloListInt3 *list, const int32_t x, const int32_t y, const int32_t z) {
    int3 *i3 = int3_new(x, y, z);
    // look in recycle bin first
    FiloListInt3Node *node = filo_list_int3_pop_in_use_node(list);
    if (node == NULL) { // if no node available, create one
        node = filo_list_int3_node_new(list);
    }
    node->value = i3;
    filo_list_int3_push_node(list, node);
}

void filo_list_int3_push_node(FiloListInt3 *list, FiloListInt3Node *node) {
    if (list->first != NULL)
        node->next = list->first;
    list->first = node;
}

void filo_list_int3_push_in_use_node(FiloListInt3 *list, FiloListInt3Node *node) {
    if (list->inUseFirst != NULL)
        node->next = list->inUseFirst;
    list->inUseFirst = node;
    node->value = NULL; // value is supposed to be retained somewhere else now
}

bool filo_list_int3_pop(FiloListInt3 *list, int3 **f3Ptr) {
    if (f3Ptr == NULL) {
        return false;
    }
    FiloListInt3Node *node = filo_list_int3_pop_node(list);
    if (node == NULL) {
        return false;
    }

    // NOTE: aduermael: had a crash because of a NULL value once
    // leaving a breakpoint
    if (node->value == NULL) {
        cclog_error("🔥 node->value not supposed to be NULL");
    }

    *f3Ptr = node->value;
    // put node in in use pool (sets note->value to NULL)
    filo_list_int3_push_in_use_node(list, node);
    return true;
}

bool filo_list_int3_pop_no_gen(FiloListInt3 *list, int3 **f3Ptr) {
    if (f3Ptr == NULL) {
        return false;
    }
    FiloListInt3Node *node = filo_list_int3_pop_node_no_gen(list);
    if (node == NULL) {
        return false;
    }
    *f3Ptr = node->value;
    // put node in in use pool (sets note->value to NULL)
    filo_list_int3_push_in_use_node(list, node);
    return true;
}

bool filo_list_int3_pop_value_no_gen(FiloListInt3 *list, int3 *i3) {
    if (i3 == NULL) {
        return false;
    }
    FiloListInt3Node *node = filo_list_int3_pop_node_no_gen(list);
    if (node == NULL) {
        return false;
    }
    int3_copy(i3, node->value);
    int3_free(node->value);
    // put node in in use pool (sets note->value to NULL)
    filo_list_int3_push_in_use_node(list, node);
    return true;
}

void filo_list_int3_recycle(FiloListInt3 *list, int3 *f3) {
    // look in recycle bin first
    FiloListInt3Node *node = filo_list_int3_pop_in_use_node(list);
    if (node == NULL) { // if no node available, create one
        node = filo_list_int3_node_new(list);
    }
    node->value = f3;
    filo_list_int3_push_node(list, node);
}

FiloListInt3Node *filo_list_int3_pop_node(FiloListInt3 *list) {
    if (list == NULL) {
        cclog_error("🔥 popping int3 from NULL list");
        return NULL;
    }

    FiloListInt3Node *node;

    if (list->first == NULL) { // create node none is available
        node = filo_list_int3_node_new(list);
        node->value = int3_new(0, 0, 0);
    } else {
        node = list->first;
        list->first = node->next;
    }
    node->next = NULL;
    return node;
}

FiloListInt3Node *filo_list_int3_pop_node_no_gen(FiloListInt3 *list) {
    if (list == NULL) {
        cclog_error("🔥 popping int3 from NULL list");
        return NULL;
    }

    if (list->first == NULL) { // create node none is available
        return NULL;
    }

    FiloListInt3Node *node = list->first;
    list->first = node->next;
    node->next = NULL;
    return node;
}

FiloListInt3Node *filo_list_int3_pop_in_use_node(FiloListInt3 *list) {
    if (list == NULL || list->inUseFirst == NULL) {
        return NULL;
    }
    FiloListInt3Node *node = list->inUseFirst;
    list->inUseFirst = node->next;
    node->next = NULL;
    return node;
}

//---------------------
// FiloListInt3Node
//---------------------

FiloListInt3Node *filo_list_int3_node_new(FiloListInt3 *list) {
    list->nbNodes++;
    if (list->maxNodes > 0 && list->nbNodes > list->maxNodes) {
        // it's ok to go over max, but we want to see a warning
        cclog_warning("⚠️ max int3 nodes: %zu, nb nodes: %zu", list->maxNodes, list->nbNodes);
    }
    FiloListInt3Node *node = (FiloListInt3Node *)malloc(sizeof(FiloListInt3Node));
    node->next = NULL;
    node->value = NULL;
    return node;
}

void filo_list_int3_node_free(FiloListInt3Node *node) {
    int3_free(node->value);
    free(node);
}
