// -------------------------------------------------------------
//  Cubzh Core
//  doubly_linked_list.h
//  Created by Adrien Duermael on July 26, 2017.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "function_pointers.h"

#include <stdbool.h>
#include <stdlib.h>

// types
typedef struct _DoublyLinkedListNode DoublyLinkedListNode;

typedef struct {
    DoublyLinkedListNode *first;
    DoublyLinkedListNode *last;
} DoublyLinkedList;

//--------------------
// MARK: - DoublyLinkedList -
//--------------------

// constructor
DoublyLinkedList *doubly_linked_list_new(void);

// pop and free all nodes, the list itself is not freed
void doubly_linked_list_flush(DoublyLinkedList *list, pointer_free_function ptr);
// destructor
//!\\ stored pointers won't be released
void doubly_linked_list_free(DoublyLinkedList *list);

// push to last/first and return pointer to created node
DoublyLinkedListNode *doubly_linked_list_push_last(DoublyLinkedList *list, void *ptr);
DoublyLinkedListNode *doubly_linked_list_push_first(DoublyLinkedList *list, void *ptr);

void *doubly_linked_list_pop_last(DoublyLinkedList *list);
void *doubly_linked_list_pop_first(DoublyLinkedList *list);

DoublyLinkedListNode *doubly_linked_list_last(const DoublyLinkedList *list);
DoublyLinkedListNode *doubly_linked_list_first(const DoublyLinkedList *list);

// removes node from list
//!\\ stored pointer won't be released
DoublyLinkedListNode *doubly_linked_list_delete_node(DoublyLinkedList *list,
                                                     DoublyLinkedListNode *node);
DoublyLinkedListNode *doubly_linked_list_insert_node_next(DoublyLinkedList *list,
                                                          DoublyLinkedListNode *node,
                                                          void *ptr);
DoublyLinkedListNode *doubly_linked_list_insert_node_previous(DoublyLinkedList *list,
                                                              DoublyLinkedListNode *node,
                                                              void *ptr);

typedef bool (*pointer_doubly_linked_list_sort_func)(DoublyLinkedListNode *n1,
                                                     DoublyLinkedListNode *n2);
void doubly_linked_list_sort_ascending(DoublyLinkedList *list,
                                       pointer_doubly_linked_list_sort_func func);

// iterates over nodes to return list count
size_t doubly_linked_list_node_count(const DoublyLinkedList *list);

// iterates over nodes to return node at index
DoublyLinkedListNode *doubly_linked_list_node_at_index(const DoublyLinkedList *list, size_t i);

DoublyLinkedListNode *doubly_linked_list_find(const DoublyLinkedList *list, void *ptr);
bool doubly_linked_list_contains(const DoublyLinkedList *list, void *ptr);
typedef bool (*pointer_doubly_linked_list_contains_func)(void *nodePtr, void *data);
bool doubly_linked_list_contains_func(const DoublyLinkedList *list,
                                      pointer_doubly_linked_list_contains_func func,
                                      void *ptr,
                                      void **out);

bool doubly_linked_list_is_empty(const DoublyLinkedList *list);

//--------------------
// MARK: - DoublyLinkedListNode -
//--------------------

// constructor
DoublyLinkedListNode *doubly_linked_list_node_new(void *ptr);

// destructor
//!\\ stored pointer won't be released
void doubly_linked_list_node_free(DoublyLinkedListNode *node);

// returns next node (can be NULL)
DoublyLinkedListNode *doubly_linked_list_node_next(const DoublyLinkedListNode *node);

// returns previous node (can be NULL)
DoublyLinkedListNode *doubly_linked_list_node_previous(const DoublyLinkedListNode *node);

// returns stored pointer
void *doubly_linked_list_node_pointer(const DoublyLinkedListNode *node);

// sets stored pointer
void doubly_linked_list_node_set_pointer(DoublyLinkedListNode *node, void *ptr);

#ifdef __cplusplus
} // extern "C"
#endif
