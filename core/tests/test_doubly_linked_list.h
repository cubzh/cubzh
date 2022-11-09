// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_doubly_linked_list.h
//  Created by Nino PLANE on November 8, 2022.
// -------------------------------------------------------------

#pragma once

#include "doubly_linked_list.h"

// Create a list and check if the init of the node is correctly done
void test_doubly_linked_list_new(void) {
    DoublyLinkedList *list = doubly_linked_list_new();

    TEST_CHECK(list->first == NULL);
    TEST_CHECK(list->last == NULL);

    doubly_linked_list_free(list);
}

// Create a node and check if the init of the node is correctly done with his pointer.
void test_doubly_linked_list_node_new(void) {
    int a = 10;
    int *ptr = &a;
    DoublyLinkedListNode *node = doubly_linked_list_node_new(ptr);

    DoublyLinkedListNode *check = doubly_linked_list_node_previous(node);
    TEST_CHECK(check == NULL);
    check = doubly_linked_list_node_next(node);
    TEST_CHECK(check == NULL);
    int *pointerCheck = doubly_linked_list_node_pointer(node);
    TEST_CHECK(*pointerCheck == 10);

    doubly_linked_list_node_free(node);
}

// Create 3 differents nodes and check if their pointer contains the right value
void test_doubly_linked_list_node_pointer(void) {
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *anode = doubly_linked_list_node_new(aptr);
    DoublyLinkedListNode *bnode = doubly_linked_list_node_new(bptr);
    DoublyLinkedListNode *cnode = doubly_linked_list_node_new(cptr);
    int *pointerCheck = doubly_linked_list_node_pointer(anode);
    TEST_CHECK(*pointerCheck == 5);
    pointerCheck = doubly_linked_list_node_pointer(bnode);
    TEST_CHECK(*pointerCheck == 10);
    pointerCheck = doubly_linked_list_node_pointer(cnode);
    TEST_CHECK(*pointerCheck == 15);

    doubly_linked_list_node_free(anode);
    doubly_linked_list_node_free(bnode);
    doubly_linked_list_node_free(cnode);
}

// Create a node and change the pointer in it.
// At each change check the value of the pointer in the node
void test_doubly_linked_list_node_set_pointer(void) {
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *node = doubly_linked_list_node_new(aptr);
    int *pointerCheck = doubly_linked_list_node_pointer(node);
    TEST_CHECK(*pointerCheck == 5);
    doubly_linked_list_node_set_pointer(node, bptr);
    pointerCheck = doubly_linked_list_node_pointer(node);
    TEST_CHECK(*pointerCheck == 10);
    doubly_linked_list_node_set_pointer(node, cptr);
    pointerCheck = doubly_linked_list_node_pointer(node);
    TEST_CHECK(*pointerCheck == 15);

    doubly_linked_list_node_free(node);
}
// Create a doubly link list and push from the first, different nodes and check the
// value of a->first and a->last at each state
void test_doubly_linked_list_push_first(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *afirst = doubly_linked_list_push_first(list, aptr); // [5]
    TEST_CHECK(list->first == afirst);
    TEST_CHECK(list->last == afirst);
    int *pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(*pointerCheck == 5);

    DoublyLinkedListNode *bfirst = doubly_linked_list_push_first(list, bptr); // [10, 5]
    TEST_CHECK(list->first == bfirst);
    TEST_CHECK(list->last == afirst);
    pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(*pointerCheck == 10);

    DoublyLinkedListNode *cfirst = doubly_linked_list_push_first(list, cptr); // [15, 10, 5]
    TEST_CHECK(list->first == cfirst);
    TEST_CHECK(list->last == afirst);
    pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(*pointerCheck == 15);

    doubly_linked_list_free(list);
}

// Create a doubly link list and push from the last, different nodes and check the
// value of a->first and a->last at each state
void test_doubly_linked_list_push_last(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *alast = doubly_linked_list_push_last(list, aptr); // [5]
    TEST_CHECK(list->first == alast);
    TEST_CHECK(list->last == alast);
    int *pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(*pointerCheck == 5);

    DoublyLinkedListNode *blast = doubly_linked_list_push_last(list, bptr); // [5, 10]
    TEST_CHECK(list->first == alast);
    TEST_CHECK(list->last == blast);
    pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(*pointerCheck == 10);

    DoublyLinkedListNode *clast = doubly_linked_list_push_last(list, cptr); // [5, 10, 15]
    TEST_CHECK(list->first == alast);
    TEST_CHECK(list->last == clast);
    pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(*pointerCheck == 15);

    doubly_linked_list_free(list);
}

// Create a list with 3 differents nodes and for each node created
// in the doubly linked link we check if the next node is the right one
void test_doubly_linked_list_node_next(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *afirst = doubly_linked_list_push_first(list, aptr); // [5]
    DoublyLinkedListNode *bfirst = doubly_linked_list_push_first(list, bptr); // [10, 5]
    DoublyLinkedListNode *cfirst = doubly_linked_list_push_first(list, cptr); // [15, 10, 5]

    DoublyLinkedListNode *NodeCheck = doubly_linked_list_node_next(afirst);
    TEST_CHECK(NodeCheck == NULL);
    NodeCheck = doubly_linked_list_node_next(bfirst);
    TEST_CHECK(NodeCheck == afirst);
    NodeCheck = doubly_linked_list_node_next(cfirst);
    TEST_CHECK(NodeCheck == bfirst);

    doubly_linked_list_free(list);
}

// Create a list with 3 differents nodes and for each node created
// in the doubly linked link we check if the previous node is the right one
void test_doubly_linked_list_node_previous(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *afirst = doubly_linked_list_push_first(list, aptr); // [5]
    DoublyLinkedListNode *bfirst = doubly_linked_list_push_first(list, bptr); // [10, 5]
    DoublyLinkedListNode *cfirst = doubly_linked_list_push_first(list, cptr); // [15, 10, 5]

    DoublyLinkedListNode *NodeCheck = doubly_linked_list_node_previous(afirst);
    TEST_CHECK(NodeCheck == bfirst);
    NodeCheck = doubly_linked_list_node_previous(bfirst);
    TEST_CHECK(NodeCheck == cfirst);
    NodeCheck = doubly_linked_list_node_previous(cfirst);
    TEST_CHECK(NodeCheck == NULL);

    doubly_linked_list_free(list);
}

// Create a list with 3 differents nodes and for each node created
// count the amount of total nodes in the list
void test_doubly_linked_list_node_count(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    size_t check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 0);
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    doubly_linked_list_push_first(list, aptr); // [5]
    check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 1);
    doubly_linked_list_push_first(list, bptr); // [10, 5]
    check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 2);
    doubly_linked_list_push_first(list, cptr); // [15, 10, 5]
    check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 3);

    doubly_linked_list_free(list);
}

// Create a new list with differents nodes,
// then we flush the list to get a new empty list
void test_doubly_linked_list_flush(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int *aptr = (int *)malloc(sizeof(int));
    int *bptr = (int *)malloc(sizeof(int));
    int *cptr = (int *)malloc(sizeof(int));
    *aptr = 5;
    *bptr = 10;
    *cptr = 15;
    doubly_linked_list_push_first(list, aptr); // [5]
    doubly_linked_list_push_first(list, bptr); // [10, 5]
    doubly_linked_list_push_first(list, cptr); // [15, 10, 5]
    size_t check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 3);

    doubly_linked_list_flush(list, free);
    check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 0);
    TEST_CHECK(list->first == NULL);
    TEST_CHECK(list->last == NULL);

    doubly_linked_list_free(list);
}

// Create a list with 3 nodes with differents pointers and check if a pointer is in the list.
void test_doubly_linked_list_contains(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    doubly_linked_list_push_first(list, aptr);
    doubly_linked_list_push_first(list, bptr);
    DoublyLinkedListNode *cNode = doubly_linked_list_node_new(cptr);

    TEST_CHECK(doubly_linked_list_contains(list, aptr) == true);
    TEST_CHECK(doubly_linked_list_contains(list, bptr) == true);
    TEST_CHECK(doubly_linked_list_contains(list, cptr) == false);

    doubly_linked_list_flush(list, NULL);

    TEST_CHECK(doubly_linked_list_contains(list, aptr) == false);
    TEST_CHECK(doubly_linked_list_contains(list, bptr) == false);
    TEST_CHECK(doubly_linked_list_contains(list, cptr) == false);

    doubly_linked_list_node_free(cNode);
    doubly_linked_list_free(list);
}

// Create a list with 3 nodes with differents values and then pop the first node.
// We then check if the poped value is the correct one and if the value isn't in the list anymore.
void test_doubly_linked_list_pop_first(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    doubly_linked_list_push_first(list, aptr);
    doubly_linked_list_push_first(list, bptr);
    doubly_linked_list_push_first(list, cptr);

    int *pointerCheck = doubly_linked_list_pop_first(list);
    TEST_CHECK(*pointerCheck == 15);
    size_t checkSize = doubly_linked_list_node_count(list);
    TEST_CHECK(checkSize == 2);
    pointerCheck = doubly_linked_list_pop_first(list);
    TEST_CHECK(*pointerCheck == 10);
    checkSize = doubly_linked_list_node_count(list);
    TEST_CHECK(checkSize == 1);
    pointerCheck = doubly_linked_list_pop_first(list);
    TEST_CHECK(*pointerCheck == 5);
    checkSize = doubly_linked_list_node_count(list);
    TEST_CHECK(checkSize == 0);
    TEST_CHECK(list->first == NULL);
    TEST_CHECK(list->last == NULL);

    doubly_linked_list_free(list);
}

// Create a list with 3 nodes with differents values and then pop the last node.
// We then check if the poped value is the correct one and if the value isn't in the list anymore.
void test_doubly_linked_list_pop_last(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    doubly_linked_list_push_first(list, aptr);
    doubly_linked_list_push_first(list, bptr);
    doubly_linked_list_push_first(list, cptr);

    int *pointerCheck = doubly_linked_list_pop_last(list);
    TEST_CHECK(*pointerCheck == 5);
    size_t checkSize = doubly_linked_list_node_count(list);
    TEST_CHECK(checkSize == 2);
    pointerCheck = doubly_linked_list_pop_last(list);
    TEST_CHECK(*pointerCheck == 10);
    checkSize = doubly_linked_list_node_count(list);
    TEST_CHECK(checkSize == 1);
    pointerCheck = doubly_linked_list_pop_last(list);
    TEST_CHECK(*pointerCheck == 15);
    checkSize = doubly_linked_list_node_count(list);
    TEST_CHECK(checkSize == 0);
    TEST_CHECK(list->first == NULL);
    TEST_CHECK(list->last == NULL);

    doubly_linked_list_free(list);
}

// Create a list with 2 nodes with differents values and then check if we get the good right one
// in the first position of the list without taking it out of it
void test_doubly_linked_list_first(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int *aptr = &a;
    int *bptr = &b;
    doubly_linked_list_push_first(list, aptr);
    doubly_linked_list_push_first(list, bptr);

    DoublyLinkedListNode *nodeCheck = doubly_linked_list_first(list);
    int *pointerCheck = doubly_linked_list_node_pointer(nodeCheck);
    TEST_CHECK(*pointerCheck == 10);

    doubly_linked_list_free(list);
}

// Create a list with 2 nodes with differents values and then check if we get the good right one
// in the last position of the list without taking it out of it
void test_doubly_linked_list_last(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int *aptr = &a;
    int *bptr = &b;
    doubly_linked_list_push_first(list, aptr);
    doubly_linked_list_push_first(list, bptr);

    DoublyLinkedListNode *nodeCheck = doubly_linked_list_last(list);
    int *pointerCheck = doubly_linked_list_node_pointer(nodeCheck);
    TEST_CHECK(*pointerCheck == 5);

    doubly_linked_list_free(list);
}

// Create a list with a node, then insert a node in the list previous the first one. Then we do it a
// second time. We check at each step if the values in the list are correct, and if the links are
// not broken.
void test_doubly_linked_list_insert_node_next(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *aNode = doubly_linked_list_push_first(list, aptr);

    DoublyLinkedListNode *bNode = doubly_linked_list_insert_node_next(list, aNode, bptr);
    int *pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(*pointerCheck == 5);
    pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(*pointerCheck == 10);
    DoublyLinkedListNode *NodeCheck = doubly_linked_list_node_next(aNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 10);
    NodeCheck = doubly_linked_list_node_previous(bNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 5);

    DoublyLinkedListNode *cNode = doubly_linked_list_insert_node_next(list, aNode, cptr);
    NodeCheck = doubly_linked_list_node_next(aNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 15);
    NodeCheck = doubly_linked_list_node_previous(bNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 15);
    NodeCheck = doubly_linked_list_node_previous(cNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 5);
    NodeCheck = doubly_linked_list_node_next(cNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 10);
    size_t check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 3);

    doubly_linked_list_free(list);
}

// Create a list with a node, then insert a node in the list after the first one. Then we do it a
// second time. We check at each step if the values in the list are correct, and if the links are
// not broken.
void test_doubly_linked_list_insert_node_previous(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *aNode = doubly_linked_list_push_first(list, aptr);

    DoublyLinkedListNode *bNode = doubly_linked_list_insert_node_previous(list, aNode, bptr);
    int *pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(*pointerCheck == 10);
    pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(*pointerCheck == 5);
    DoublyLinkedListNode *NodeCheck = doubly_linked_list_node_previous(aNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 10);
    NodeCheck = doubly_linked_list_node_next(bNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 5);

    DoublyLinkedListNode *cNode = doubly_linked_list_insert_node_previous(list, aNode, cptr);
    NodeCheck = doubly_linked_list_node_previous(aNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 15);
    NodeCheck = doubly_linked_list_node_next(bNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 15);
    NodeCheck = doubly_linked_list_node_previous(cNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 10);
    NodeCheck = doubly_linked_list_node_next(cNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 5);
    size_t check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 3);

    doubly_linked_list_free(list);
}

// Create a list with 3 nodes with differents values, then we delete the node in the middle, after
// that the first one and then the remaining one. We check at each step if the values in the list
// are correct, and if the links are not broken.
void test_doubly_linked_list_delete_node(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    DoublyLinkedListNode *aNode = doubly_linked_list_push_first(list, aptr);
    DoublyLinkedListNode *bNode = doubly_linked_list_push_first(list, bptr);
    DoublyLinkedListNode *cNode = doubly_linked_list_push_first(list, cptr);

    doubly_linked_list_delete_node(list, bNode);
    int *pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(*pointerCheck == 15);
    pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(*pointerCheck == 5);
    DoublyLinkedListNode *NodeCheck = doubly_linked_list_node_previous(aNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 15);
    NodeCheck = doubly_linked_list_node_next(cNode);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 5);
    size_t check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 2);

    doubly_linked_list_delete_node(list, cNode);
    pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(*pointerCheck == 5);
    pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(*pointerCheck == 5);
    NodeCheck = doubly_linked_list_node_next(aNode);
    TEST_CHECK(NodeCheck == NULL);
    NodeCheck = doubly_linked_list_node_previous(aNode);
    TEST_CHECK(NodeCheck == NULL);
    check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 1);

    doubly_linked_list_delete_node(list, aNode);
    pointerCheck = doubly_linked_list_node_pointer(list->first);
    TEST_CHECK(pointerCheck == NULL);
    pointerCheck = doubly_linked_list_node_pointer(list->last);
    TEST_CHECK(pointerCheck == NULL);
    check = doubly_linked_list_node_count(list);
    TEST_CHECK(check == 0);

    doubly_linked_list_free(list);
}

// Create a doubly linked list with 3 node and check with a set index, if the pointer of the node
// are the right one.
void test_doubly_linked_list_node_at_index(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 5;
    int b = 10;
    int c = 15;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    doubly_linked_list_push_first(list, aptr);
    doubly_linked_list_push_first(list, bptr);
    doubly_linked_list_push_first(list, cptr);

    DoublyLinkedListNode *NodeCheck = doubly_linked_list_node_at_index(list, 0);
    int *pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 15);
    NodeCheck = doubly_linked_list_node_at_index(list, 1);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 10);
    NodeCheck = doubly_linked_list_node_at_index(list, 2);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 5);

    doubly_linked_list_free(list);
}

// Compare 2 nodes who have int* pointer and return true if pointer of a > pointer of b
bool _node_is_superior(DoublyLinkedListNode *a, DoublyLinkedListNode *b) {
    int *aPtr = (int *)doubly_linked_list_node_pointer(a);
    int *bPtr = (int *)doubly_linked_list_node_pointer(b);
    return *aPtr > *bPtr;
}

// Create a doubly linked list with 5 differents nodes, with various values in their pointer.
// Then use the 'sort_ascending' function to sort them in the list. We check if the
// sort is correct and if the values are in the correct order.
void test_doubly_linked_list_sort_ascending(void) {
    DoublyLinkedList *list = doubly_linked_list_new();
    int a = 21;
    int b = -8;
    int c = 119;
    int d = -15;
    int e = 0;
    int *aptr = &a;
    int *bptr = &b;
    int *cptr = &c;
    int *dptr = &d;
    int *eptr = &e;
    doubly_linked_list_push_first(list, aptr);
    doubly_linked_list_push_first(list, bptr);
    doubly_linked_list_push_first(list, cptr);
    doubly_linked_list_push_first(list, dptr);
    doubly_linked_list_push_first(list, eptr);

    doubly_linked_list_sort_ascending(list, _node_is_superior);
    DoublyLinkedListNode *NodeCheck = doubly_linked_list_node_at_index(list, 0);
    int *pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == -15);
    NodeCheck = doubly_linked_list_node_at_index(list, 1);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == -8);
    NodeCheck = doubly_linked_list_node_at_index(list, 2);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 0);
    NodeCheck = doubly_linked_list_node_at_index(list, 3);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 21);
    NodeCheck = doubly_linked_list_node_at_index(list, 4);
    pointerCheck = doubly_linked_list_node_pointer(NodeCheck);
    TEST_CHECK(*pointerCheck == 119);

    doubly_linked_list_free(list);
}
