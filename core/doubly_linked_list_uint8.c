// -------------------------------------------------------------
//  Cubzh Core
//  doubly_linked_list_uint8.c
//  Created by Gaetan de Villele on November 3, 2021.
// -------------------------------------------------------------

#include "doubly_linked_list_uint8.h"

#include <stdlib.h>

//
//                              << PREVIOUS <<
// toward list FRONT <-- [NODE]                [NODE] --> toward list BACK
//                              >>   NEXT   >>
//
//

struct _DoublyLinkedListUint8Node {
    DoublyLinkedListUint8Node *previous; // toward front
    DoublyLinkedListUint8Node *next;     // toward back
    uint8_t value;                       // stored value
};

//---------------------
// DoublyLinkedListUint8
//---------------------

DoublyLinkedListUint8 *doubly_linked_list_uint8_new(void) {
    DoublyLinkedListUint8 *list = (DoublyLinkedListUint8 *)malloc(sizeof(DoublyLinkedListUint8));
    list->front = NULL;
    list->back = NULL;
    return list;
}

void doubly_linked_list_uint8_flush(DoublyLinkedListUint8 *const list) {
    while (list->front != NULL) {
        doubly_linked_list_uint8_pop_front(list, NULL);
    }
}

void doubly_linked_list_uint8_free(DoublyLinkedListUint8 *const list) {
    doubly_linked_list_uint8_flush(list);
    free(list);
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_push_front(DoublyLinkedListUint8 *const list,
                                                               const uint8_t value) {
    DoublyLinkedListUint8Node *const newNode = doubly_linked_list_uint8_node_new(value);

    if (list->front == NULL) {
        list->front = newNode;
        list->back = newNode; // list->back has to be NULL if list->front is
        return newNode;
    }

    list->front->previous = newNode;
    newNode->next = list->front;
    list->front = newNode;

    return newNode;
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_push_back(DoublyLinkedListUint8 *const list,
                                                              const uint8_t value) {
    DoublyLinkedListUint8Node *newNode = doubly_linked_list_uint8_node_new(value);

    if (list->back == NULL) {
        list->back = newNode;
        list->front = newNode; // list->front has to be NULL if list->back is
        return newNode;
    }

    list->back->next = newNode;
    newNode->previous = list->back;
    list->back = newNode;

    return newNode;
}

bool doubly_linked_list_uint8_pop_front(DoublyLinkedListUint8 *const list,
                                        uint8_t *const valuePtr) {
    if (list->front == NULL) {
        return false;
    }

    DoublyLinkedListUint8Node *node = list->front;

    if (valuePtr != NULL) {
        *valuePtr = node->value;
    }

    list->front = node->next;

    if (list->front != NULL) {
        list->front->previous = NULL;
    } else { // meaning the list is empty, back should be set to NULL
        list->back = NULL;
    }

    doubly_linked_list_uint8_node_free(node);

    return true;
}

bool doubly_linked_list_uint8_pop_back(DoublyLinkedListUint8 *const list, uint8_t *const valuePtr) {
    if (list->back == NULL) {
        return false;
    }

    DoublyLinkedListUint8Node *node = list->back;

    if (valuePtr != NULL) {
        *valuePtr = node->value;
    }

    list->back = node->previous;

    if (list->back != NULL) {
        list->back->next = NULL;
    } else { // meaning the list is empty, front should be set to NULL
        list->front = NULL;
    }

    doubly_linked_list_uint8_node_free(node);

    return true;
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_front(const DoublyLinkedListUint8 *const list) {
    if (list == NULL) {
        return NULL;
    }
    return list->front;
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_back(const DoublyLinkedListUint8 *const list) {
    if (list == NULL) {
        return NULL;
    }
    return list->back;
}

void doubly_linked_list_uint8_delete_node(DoublyLinkedListUint8 *const list,
                                          DoublyLinkedListUint8Node *const node) {

    if (node->previous != NULL) {
        node->previous->next = node->next;
    }

    if (node->next != NULL) {
        node->next->previous = node->previous;
    }

    if (node == list->front) {
        list->front = node->next;
        if (list->front != NULL) {
            list->front->previous = NULL;
        }
    }

    if (node == list->back) {
        list->back = node->previous;
        if (list->back != NULL) {
            list->back->next = NULL;
        }
    }

    doubly_linked_list_uint8_node_free(node);
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_insert_node_before(
    DoublyLinkedListUint8 *const list,
    DoublyLinkedListUint8Node *const node,
    const uint8_t value) {
    DoublyLinkedListUint8Node *newNode = doubly_linked_list_uint8_node_new(value);

    if (node->previous != NULL) {
        node->previous->next = newNode;
        newNode->previous = node->previous;
    } else {
        list->front = newNode;
    }
    node->previous = newNode;
    newNode->next = node;

    return newNode;
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_insert_node_after(
    DoublyLinkedListUint8 *const list,
    DoublyLinkedListUint8Node *const node,
    const uint8_t value) {

    DoublyLinkedListUint8Node *newNode = doubly_linked_list_uint8_node_new(value);

    if (node->next != NULL) {
        node->next->previous = newNode;
        newNode->next = node->next;
    } else {
        list->back = newNode;
    }
    node->next = newNode;
    newNode->previous = node;

    return newNode;
}

size_t doubly_linked_list_uint8_node_count(const DoublyLinkedListUint8 *const list) {
    if (list->front == NULL) {
        return 0;
    }

    size_t count = 0;
    DoublyLinkedListUint8Node *n = list->front;

    while (n != NULL) {
        ++count;
        n = n->next;
    }

    return count;
}

bool doubly_linked_list_uint8_contains(const DoublyLinkedListUint8 *const list,
                                       const uint8_t value) {
    DoublyLinkedListUint8Node *node = list->front;
    while (node != NULL) {
        if (node->value == value) {
            return true;
        }
        node = doubly_linked_list_uint8_node_next(node);
    }
    return false;
}

//---------------------
// DoublyLinkedNode
//---------------------

DoublyLinkedListUint8Node *doubly_linked_list_uint8_node_new(const uint8_t value) {
    DoublyLinkedListUint8Node *node = (DoublyLinkedListUint8Node *)malloc(
        sizeof(DoublyLinkedListUint8Node));
    node->previous = NULL;
    node->next = NULL;
    node->value = value;
    return node;
}

void doubly_linked_list_uint8_node_free(DoublyLinkedListUint8Node *const node) {
    if (node->previous != NULL) {
        node->previous->next = node->next;
    }
    if (node->next != NULL) {
        node->next->previous = node->previous;
    }
    free(node);
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_node_previous(
    const DoublyLinkedListUint8Node *const node) {
    if (node == NULL) {
        return NULL;
    }
    return node->previous;
}

DoublyLinkedListUint8Node *doubly_linked_list_uint8_node_next(
    const DoublyLinkedListUint8Node *const node) {
    if (node == NULL) {
        return NULL;
    }
    return node->next;
}

uint8_t doubly_linked_list_uint8_node_get_value(const DoublyLinkedListUint8Node *const node) {
    if (node == NULL) {
        return 0;
    }
    return node->value;
}

void doubly_linked_list_uint8_node_set_value(DoublyLinkedListUint8Node *const node,
                                             const uint8_t value) {
    if (node != NULL) {
        node->value = value;
    }
}
