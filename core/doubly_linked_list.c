// -------------------------------------------------------------
//  Cubzh Core
//  doubly_linked_list.c
//  Created by Adrien Duermael on July 26, 2017.
// -------------------------------------------------------------

#include "doubly_linked_list.h"

// C
#include <assert.h>
#include <stdlib.h>

#include "cclog.h"

struct _DoublyLinkedListNode {
    DoublyLinkedListNode *previous; // toward first
    DoublyLinkedListNode *next;     // toward last
    void *ptr;                      // stored pointer
};

//---------------------
// DoublyLinkedList
//---------------------

DoublyLinkedList *doubly_linked_list_new(void) {
    DoublyLinkedList *list = (DoublyLinkedList *)malloc(sizeof(DoublyLinkedList));
    list->first = NULL;
    list->last = NULL;
    return list;
}

bool doubly_linked_list_copy(DoublyLinkedList *const dst, DoublyLinkedList *const src) {
    // source and destination lists pointers cannot be NULL
    if (dst == NULL || src == NULL) {
        return false;
    }

    // destination list must be empty
    if (doubly_linked_list_is_empty(dst) == false) {
        return false;
    }

    // copy content
    DoublyLinkedListNode *node = doubly_linked_list_first(src);
    while (node != NULL) {
        // get value of stored pointer
        void *ptr = doubly_linked_list_node_pointer(node);
        // insert this pointer value into the `dst` list
        doubly_linked_list_push_last(dst, ptr);
        // move to next node
        node = doubly_linked_list_node_next(node);
    }

    return true;
}

void doubly_linked_list_flush(DoublyLinkedList *list, pointer_free_function ptr) {
    void *data;
    while (list->last != NULL) {
        data = doubly_linked_list_pop_last(list);
        if (ptr != NULL) {
            ptr(data);
        }
    }
}

void doubly_linked_list_free(DoublyLinkedList *const list) {
    while (list->last != NULL) {
        doubly_linked_list_pop_last(list);
    }
    free(list);
}

DoublyLinkedListNode *doubly_linked_list_push_last(DoublyLinkedList *const list, void *const ptr) {
    DoublyLinkedListNode *newNode = doubly_linked_list_node_new(ptr);
    if (newNode == NULL) {
        return NULL;
    }

    if (list->last == NULL) {
        assert(list->first == NULL);
        list->last = newNode;
        list->first = newNode; // list->first has to be NULL if list->last is
        return newNode;
    }

    list->last->next = newNode;
    newNode->previous = list->last;
    list->last = newNode;

    return newNode;
}

DoublyLinkedListNode *doubly_linked_list_push_first(DoublyLinkedList *const list, void *const ptr) {
    DoublyLinkedListNode *newNode = doubly_linked_list_node_new(ptr);
    if (newNode == NULL) {
        return NULL;
    }

    if (list->first == NULL) {
        assert(list->last == NULL);
        list->first = newNode;
        list->last = newNode; // list->last has to be NULL if list->first is
        return newNode;
    }

    list->first->previous = newNode;
    newNode->next = list->first;
    list->first = newNode;

    return newNode;
}

void *doubly_linked_list_pop_last(DoublyLinkedList *list) {
    if (list->last == NULL) {
        return NULL;
    }

    DoublyLinkedListNode *node = list->last;

    void *ptr = node->ptr;

    list->last = node->previous;

    if (list->last != NULL) {
        list->last->next = NULL;
    } else { // meaning the list is empty, first should be set to NULL
        list->first = NULL;
    }

    doubly_linked_list_node_free(node);

    return ptr;
}

void *doubly_linked_list_pop_first(DoublyLinkedList *list) {
    if (list->first == NULL) {
        return NULL;
    }

    DoublyLinkedListNode *node = list->first;

    void *ptr = node->ptr;

    list->first = node->next;

    if (list->first != NULL) {
        list->first->previous = NULL;
    } else { // meaning the list is empty, last should be set to NULL
        list->last = NULL;
    }

    doubly_linked_list_node_free(node);

    return ptr;
}

DoublyLinkedListNode *doubly_linked_list_last(const DoublyLinkedList *list) {
    if (list == NULL)
        return NULL;
    return list->last;
}

DoublyLinkedListNode *doubly_linked_list_first(const DoublyLinkedList *list) {
    if (list == NULL)
        return NULL;
    return list->first;
}

DoublyLinkedListNode *doubly_linked_list_delete_node(DoublyLinkedList *const list,
                                                     DoublyLinkedListNode *const node) {
    if (list == NULL || node == NULL) {
        return NULL;
    }

    // make sure node is part of the list
    if (doubly_linked_list_contains_node(list, node) == false) {
        return NULL;
    }

    DoublyLinkedListNode *result = NULL;
    if (node->next != NULL) {
        node->next->previous = node->previous;
        result = node->next;
    }

    if (node->previous != NULL) {
        node->previous->next = node->next;
    }

    if (node == list->last) {
        list->last = node->previous;
        if (list->last != NULL) {
            list->last->next = NULL;
        }
    }

    if (node == list->first) {
        list->first = node->next;
        if (list->first != NULL) {
            list->first->previous = NULL;
        }
    }

    doubly_linked_list_node_free(node);

    return result;
}

DoublyLinkedListNode *doubly_linked_list_insert_node_previous(DoublyLinkedList *list,
                                                              DoublyLinkedListNode *node,
                                                              void *ptr) {

    DoublyLinkedListNode *newNode = doubly_linked_list_node_new(ptr);

    if (node->previous != NULL) {
        node->previous->next = newNode;
        newNode->previous = node->previous;
    } else {
        list->first = newNode;
    }
    node->previous = newNode;
    newNode->next = node;

    return newNode;
}

DoublyLinkedListNode *doubly_linked_list_insert_node_next(DoublyLinkedList *list,
                                                          DoublyLinkedListNode *node,
                                                          void *ptr) {

    DoublyLinkedListNode *newNode = doubly_linked_list_node_new(ptr);

    if (node->next != NULL) {
        node->next->previous = newNode;
        newNode->next = node->next;
    } else {
        list->last = newNode;
    }
    node->next = newNode;
    newNode->previous = node;

    return newNode;
}

void doubly_linked_list_sort_ascending(DoublyLinkedList *list,
                                       pointer_doubly_linked_list_sort_func func) {
    DoublyLinkedListNode *last = list->last;
    DoublyLinkedListNode *current = NULL;
    void *ptr = NULL;
    while (last != NULL) {
        current = list->first;
        while (current != last) {
            if (func(current, last)) {
                ptr = current->ptr;
                current->ptr = last->ptr;
                last->ptr = ptr;
            }
            current = current->next;
        }
        last = last->previous;
    }
}

size_t doubly_linked_list_node_count(const DoublyLinkedList *list) {
    if (list->last == NULL) {
        return 0;
    }

    size_t count = 0;
    DoublyLinkedListNode *n = list->last;
    while (n != NULL) {
        count++;
        n = n->previous;
    }

    return count;
}

DoublyLinkedListNode *doubly_linked_list_node_at_index(const DoublyLinkedList *list, size_t i) {
    size_t count = 0;
    DoublyLinkedListNode *n = list->first;
    while (n != NULL) {
        if (count == i) {
            return n;
        }
        ++count;
        n = n->next;
    }

    return NULL;
}

DoublyLinkedListNode *doubly_linked_list_find(const DoublyLinkedList *list, void *ptr) {
    DoublyLinkedListNode *n = list->first;
    while (n != NULL) {
        if (n->ptr == ptr) {
            return n;
        }
        n = n->next;
    }

    return NULL;
}

bool doubly_linked_list_contains_node(const DoublyLinkedList *const list,
                                      const DoublyLinkedListNode *const node) {
    DoublyLinkedListNode *n = list->first;
    while (n != NULL) {
        if (n == node) {
            return true;
        }
        n = n->next;
    }
    return false;
}

bool doubly_linked_list_contains(const DoublyLinkedList *list, void *ptr) {
    DoublyLinkedListNode *n = list->first;
    while (n != NULL) {
        if (n->ptr == ptr) {
            return true;
        }
        n = n->next;
    }
    return false;
}

bool doubly_linked_list_contains_func(const DoublyLinkedList *list,
                                      pointer_doubly_linked_list_contains_func func,
                                      void *ptr,
                                      void **out) {
    DoublyLinkedListNode *n = list->first;
    while (n != NULL) {
        if (func(n->ptr, ptr)) {
            if (out != NULL) {
                *out = n->ptr;
            }
            return true;
        }
        n = n->next;
    }

    return false;
}

bool doubly_linked_list_is_empty(const DoublyLinkedList *const list) {
    return list->first == NULL && list->last == NULL;
}

void doubly_linked_list_print(const DoublyLinkedList *const list) {
    cclog_debug("--- list --- %p", list);
    // copy content
    DoublyLinkedListNode *node = doubly_linked_list_first(list);
    while (node != NULL) {
        // get value of stored pointer
        void *ptr = doubly_linked_list_node_pointer(node);
        // print pointer
        cclog_debug("%p", ptr);
        // move to next node
        node = doubly_linked_list_node_next(node);
    }
    cclog_debug("------------");
}

//---------------------
// DoublyLinkedNode
//---------------------

DoublyLinkedListNode *doubly_linked_list_node_new(void *ptr) {
    DoublyLinkedListNode *node = (DoublyLinkedListNode *)malloc(sizeof(DoublyLinkedListNode));
    node->previous = NULL;
    node->next = NULL;
    node->ptr = ptr;
    return node;
}

void doubly_linked_list_node_free(DoublyLinkedListNode *node) {
    if (node->next != NULL) {
        node->next->previous = node->previous;
    }
    if (node->previous != NULL) {
        node->previous->next = node->next;
    }
    free(node);
}

DoublyLinkedListNode *doubly_linked_list_node_next(const DoublyLinkedListNode *node) {
    if (node == NULL)
        return NULL;
    return node->next;
}

DoublyLinkedListNode *doubly_linked_list_node_previous(const DoublyLinkedListNode *node) {
    if (node == NULL)
        return NULL;
    return node->previous;
}

void *doubly_linked_list_node_pointer(const DoublyLinkedListNode *node) {
    if (node == NULL)
        return NULL;
    return node->ptr;
}

void doubly_linked_list_node_set_pointer(DoublyLinkedListNode *node, void *ptr) {
    node->ptr = ptr;
}
