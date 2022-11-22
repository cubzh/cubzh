// -------------------------------------------------------------
//  Cubzh Core
//  doubly_linked_list_uint8.h
//  Created by Gaetan de Villele on November 3, 2021.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "function_pointers.h"

typedef struct _DoublyLinkedListUint8Node DoublyLinkedListUint8Node;

typedef struct {
    DoublyLinkedListUint8Node *front;
    DoublyLinkedListUint8Node *back;
} DoublyLinkedListUint8;

//--------------------
// MARK: - DoublyLinkedListUint8 -
//--------------------

/// constructor
DoublyLinkedListUint8 *doubly_linked_list_uint8_new(void);

/// pop and free all nodes, the list itself is not freed
void doubly_linked_list_uint8_flush(DoublyLinkedListUint8 *const list);

/// destructor
void doubly_linked_list_uint8_free(DoublyLinkedListUint8 *const list);

/// pushes value to the front of the list, returns pointer to created node
DoublyLinkedListUint8Node *doubly_linked_list_uint8_push_front(DoublyLinkedListUint8 *const list,
                                                               const uint8_t value);

/// pushes pointer to the back of the list, returns pointer to created node
DoublyLinkedListUint8Node *doubly_linked_list_uint8_push_back(DoublyLinkedListUint8 *const list,
                                                              const uint8_t value);

///
bool doubly_linked_list_uint8_pop_front(DoublyLinkedListUint8 *const list, uint8_t *const valuePtr);

///
bool doubly_linked_list_uint8_pop_back(DoublyLinkedListUint8 *const list, uint8_t *const valuePtr);

/// returns front node
DoublyLinkedListUint8Node *doubly_linked_list_uint8_front(const DoublyLinkedListUint8 *const list);

/// returns back node
DoublyLinkedListUint8Node *doubly_linked_list_uint8_back(const DoublyLinkedListUint8 *const list);

/// removes node from list
void doubly_linked_list_uint8_delete_node(DoublyLinkedListUint8 *const list,
                                          DoublyLinkedListUint8Node *const node);

///
DoublyLinkedListUint8Node *doubly_linked_list_uint8_insert_node_before(DoublyLinkedListUint8 *const list,
                                                                       DoublyLinkedListUint8Node *const node,
                                                                       const uint8_t value);

///
DoublyLinkedListUint8Node *doubly_linked_list_uint8_insert_node_after(DoublyLinkedListUint8 *const list,
                                                                      DoublyLinkedListUint8Node *const node,
                                                                      const uint8_t value);

/// iterates over nodes to return list count
size_t doubly_linked_list_uint8_node_count(const DoublyLinkedListUint8 *const list);

///
bool doubly_linked_list_uint8_contains(const DoublyLinkedListUint8 *const list, const uint8_t value);

//--------------------
// MARK: - DoublyLinkedListUint8Node -
//--------------------

/// constructor
DoublyLinkedListUint8Node *doubly_linked_list_uint8_node_new(const uint8_t value);

/// destructor
void doubly_linked_list_uint8_node_free(DoublyLinkedListUint8Node *const node);

/// returns previous node (can be NULL)
DoublyLinkedListUint8Node *doubly_linked_list_uint8_node_previous(
    const DoublyLinkedListUint8Node *const node);

/// returns next node (can be NULL)
DoublyLinkedListUint8Node *doubly_linked_list_uint8_node_next(const DoublyLinkedListUint8Node *const node);

/// returns stored value
uint8_t doubly_linked_list_uint8_node_get_value(const DoublyLinkedListUint8Node *const node);

/// sets stored value
void doubly_linked_list_uint8_node_set_value(DoublyLinkedListUint8Node *const node, const uint8_t value);

#ifdef __cplusplus
} // extern "C"
#endif
