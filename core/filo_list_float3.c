// -------------------------------------------------------------
//  Cubzh Core
//  filo_list_float3.c
//  Created by Adrien Duermael on June 7, 2019.
// -------------------------------------------------------------

#include "filo_list_float3.h"

#include <stdio.h>
#include <stdlib.h>

#include "cclog.h"

struct _FiloListFloat3Node {
    FiloListFloat3Node *next; /* 8 bytes */
    float3 *value;            /* 8 bytes */
};

// private prototypes

FiloListFloat3Node *filo_list_float3_node_new(FiloListFloat3 *list);
void filo_list_float3_node_free(FiloListFloat3Node *node);
FiloListFloat3Node *filo_list_float3_pop_node(FiloListFloat3 *list);
FiloListFloat3Node *filo_list_float3_pop_in_use_node(FiloListFloat3 *list);
void filo_list_float3_push_node(FiloListFloat3 *list, FiloListFloat3Node *node);
void filo_list_float3_push_in_use_node(FiloListFloat3 *list, FiloListFloat3Node *node);

//---------------------
// FiloListUFloat32
//---------------------

FiloListFloat3 *filo_list_float3_new(size_t maxNodes) {
    FiloListFloat3 *list = (FiloListFloat3 *)malloc(sizeof(FiloListFloat3));
    list->first = NULL;
    list->inUseFirst = NULL;
    list->maxNodes = maxNodes;
    list->nbNodes = 0;
    return list;
}

void filo_list_float3_free(FiloListFloat3 *list) {
    FiloListFloat3Node *node;
    while (list->first != NULL) {
        node = filo_list_float3_pop_node(list);
        filo_list_float3_node_free(node);
    }
    while (list->inUseFirst != NULL) {
        node = filo_list_float3_pop_in_use_node(list);
        filo_list_float3_node_free(node);
    }
    free(list);
}

void filo_list_float3_push_node(FiloListFloat3 *list, FiloListFloat3Node *node) {
    if (list->first != NULL)
        node->next = list->first;
    list->first = node;
}

void filo_list_float3_push_in_use_node(FiloListFloat3 *list, FiloListFloat3Node *node) {
    if (list->inUseFirst != NULL)
        node->next = list->inUseFirst;
    list->inUseFirst = node;
    node->value = NULL; // value is supposed to be retained somewhere else now
}

bool filo_list_float3_pop(FiloListFloat3 *list, float3 **f3Ptr) {
    if (f3Ptr == NULL) {
        return false;
    }
    FiloListFloat3Node *node = filo_list_float3_pop_node(list);
    if (node == NULL) {
        return false;
    }
    *f3Ptr = node->value;
    // put node in in use pool (sets note->value to NULL)
    filo_list_float3_push_in_use_node(list, node);
    return true;
}

void filo_list_float3_recycle(FiloListFloat3 *list, float3 *f3) {
    if (f3 == NULL) {
        return;
    }
    // look in recycle bin first
    FiloListFloat3Node *node = filo_list_float3_pop_in_use_node(list);
    if (node == NULL) { // if no node available, create one
        cclog_warning("⚠️ one recycled float3 at least doesn't come from float3 list");
        node = filo_list_float3_node_new(list);
    }
    node->value = f3;
    filo_list_float3_push_node(list, node);
}

FiloListFloat3Node *filo_list_float3_pop_node(FiloListFloat3 *list) {
    if (list == NULL) {
        cclog_error("🔥 popping float3 from NULL list");
        return NULL;
    }

    FiloListFloat3Node *node;

    if (list->first == NULL) { // create node none is available
        node = filo_list_float3_node_new(list);
        node->value = float3_new(0, 0, 0);
    } else {
        node = list->first;
        list->first = node->next;
    }
    node->next = NULL;
    return node;
}

FiloListFloat3Node *filo_list_float3_pop_in_use_node(FiloListFloat3 *list) {
    if (list == NULL || list->inUseFirst == NULL) {
        return NULL;
    }
    FiloListFloat3Node *node = list->inUseFirst;
    list->inUseFirst = node->next;
    node->next = NULL;
    return node;
}

//---------------------
// FiloListFloat3Node
//---------------------

FiloListFloat3Node *filo_list_float3_node_new(FiloListFloat3 *list) {
    list->nbNodes++;
    if (list->nbNodes > list->maxNodes) {
        // it's ok to go over max, but we want to see a warning
        cclog_warning("⚠️ max float3 nodes: %zu, nb nodes: %zu", list->maxNodes, list->nbNodes);
    }
    FiloListFloat3Node *node = (FiloListFloat3Node *)malloc(sizeof(FiloListFloat3Node));
    node->next = NULL;
    node->value = NULL;
    return node;
}

void filo_list_float3_node_free(FiloListFloat3Node *node) {
    float3_free(node->value);
    free(node);
}
