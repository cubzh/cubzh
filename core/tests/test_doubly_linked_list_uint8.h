// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_doubly_linked_list_uint8.h
//  Created by Nino PLANE on November 2, 2022.
// -------------------------------------------------------------

#pragma once

#include "doubly_linked_list_uint8.h"

// Create a list and verify if it's empty
void test_doubly_linked_list_uint8_new(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();

    TEST_CHECK(list->front == NULL);
    TEST_CHECK(list->back == NULL);

    doubly_linked_list_uint8_free(list);
}

// Create a node and check if the init of the node is correctly done with all the values.
void test_doubly_linked_list_uint8_node_new(void) {
    DoublyLinkedListUint8Node *list = doubly_linked_list_uint8_node_new(10);

    DoublyLinkedListUint8Node *check = doubly_linked_list_uint8_node_previous(list);
    TEST_CHECK(check == NULL);
    check = doubly_linked_list_uint8_node_next(list);
    TEST_CHECK(check == NULL);
    uint8_t valueCheck = doubly_linked_list_uint8_node_get_value(list);
    TEST_CHECK(valueCheck == 10);

    doubly_linked_list_uint8_node_free(list);
}

// Create a list with 2 nodes and check if the values of the nodes are the right ones
void test_doubly_linked_list_uint8_node_get_value(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    doubly_linked_list_uint8_push_front(list, 5);
    doubly_linked_list_uint8_push_front(list, 10);

    uint8_t valueCheck = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(valueCheck == 10);
    valueCheck = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(valueCheck == 5);

    doubly_linked_list_uint8_free(list);
}

// Create a list with a node, then change the value of the node and check if the value
// is put in the list
void test_doubly_linked_list_uint8_node_set_value(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    doubly_linked_list_uint8_push_front(list, 0);

    doubly_linked_list_uint8_node_set_value(list->front, 10);
    uint8_t valueCheck = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(valueCheck == 10);

    doubly_linked_list_uint8_free(list);
}

// Create a doubly link list and push from the front different nodes then check the
/// value of a->front and a->back at each state
void test_doubly_linked_list_uint8_push_front(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    // size_t checkSize = doubly_linked_list_uint8_node_count(list);
    // TEST_CHECK(checkSize == 0);

    // doubly_linked_list_uint8_push_front()
    DoublyLinkedListUint8Node *afront = doubly_linked_list_uint8_push_front(list, 5); // [5]
    TEST_CHECK(list->front == afront);
    TEST_CHECK(list->back == afront);
    uint8_t check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 5);
    // checkSize = doubly_linked_list_uint8_node_count(list);
    // TEST_CHECK(checkSize == 1);

    DoublyLinkedListUint8Node *bfront = doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    TEST_CHECK(list->front == bfront);
    TEST_CHECK(list->back == afront);
    check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 10);
    // checkSize = doubly_linked_list_uint8_node_count(list);
    // TEST_CHECK(checkSize == 2);

    DoublyLinkedListUint8Node *cfront = doubly_linked_list_uint8_push_front(list,
                                                                            15); // [15, 10, 5]
    TEST_CHECK(list->front == cfront);
    TEST_CHECK(list->back == afront);
    check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 15);
    // checkSize = doubly_linked_list_uint8_node_count(list);
    // TEST_CHECK(checkSize == 3);

    doubly_linked_list_uint8_free(list);
}

// Create a doubly link list and push from the back different nodes then check the
// values of a->front and a->back at each state
void test_doubly_linked_list_uint8_push_back(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();

    DoublyLinkedListUint8Node *aback = doubly_linked_list_uint8_push_back(list, 5); // [5]
    TEST_CHECK(list->front == aback);
    TEST_CHECK(list->back == aback);
    uint8_t check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 5);

    DoublyLinkedListUint8Node *bback = doubly_linked_list_uint8_push_back(list, 10); // [5, 10]
    TEST_CHECK(list->front == aback);
    TEST_CHECK(list->back == bback);
    check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 10);

    DoublyLinkedListUint8Node *cback = doubly_linked_list_uint8_push_back(list, 15); // [5, 10, 15]
    TEST_CHECK(list->front == aback);
    TEST_CHECK(list->back == cback);
    check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 15);

    doubly_linked_list_uint8_free(list);
}

// Create a doubly link list and push from the front different nodes then check for
// each node created if the next node is the right one
void test_doubly_linked_list_uint8_node_next(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();

    DoublyLinkedListUint8Node *afront = doubly_linked_list_uint8_push_front(list, 5);  // [5]
    DoublyLinkedListUint8Node *bfront = doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    DoublyLinkedListUint8Node *cfront = doubly_linked_list_uint8_push_front(list,
                                                                            15); // [15, 10, 5]

    DoublyLinkedListUint8Node *NodeCheck = doubly_linked_list_uint8_node_next(afront);
    TEST_CHECK(NodeCheck == NULL);
    NodeCheck = doubly_linked_list_uint8_node_next(bfront);
    TEST_CHECK(NodeCheck == afront);
    NodeCheck = doubly_linked_list_uint8_node_next(cfront);
    TEST_CHECK(NodeCheck == bfront);

    doubly_linked_list_uint8_free(list);
}

// Create a doubly link list and push from the front different nodes then check for
// each node created if the previous node is the right one
void test_doubly_linked_list_uint8_node_previous(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();

    DoublyLinkedListUint8Node *afront = doubly_linked_list_uint8_push_front(list, 5);  // [5]
    DoublyLinkedListUint8Node *bfront = doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    DoublyLinkedListUint8Node *cfront = doubly_linked_list_uint8_push_front(list,
                                                                            15); // [15, 10, 5]

    DoublyLinkedListUint8Node *NodeCheck = doubly_linked_list_uint8_node_previous(afront);
    TEST_CHECK(NodeCheck == bfront);
    NodeCheck = doubly_linked_list_uint8_node_previous(bfront);
    TEST_CHECK(NodeCheck == cfront);
    NodeCheck = doubly_linked_list_uint8_node_previous(cfront);
    TEST_CHECK(NodeCheck == NULL);

    doubly_linked_list_uint8_free(list);
}

// Create a doubly linked list and check each time we add a node the number of
// total node in the list
void test_doubly_linked_list_uint8_node_count(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    size_t checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 0);

    doubly_linked_list_uint8_push_front(list, 5); // [5]
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 1);
    doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 2);
    doubly_linked_list_uint8_push_front(list, 15); // [15, 10, 5]
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 3);

    doubly_linked_list_uint8_free(list);
}

// Create a doubly linked list and we flush it to get a new empty list
void test_doubly_linked_list_uint8_node_flush(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();

    doubly_linked_list_uint8_push_front(list, 5);  // [5]
    doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    doubly_linked_list_uint8_push_front(list, 15); // [15, 10, 5]
    size_t checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 3);
    doubly_linked_list_uint8_flush(list);
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 0);
    TEST_CHECK(list->front == NULL);
    TEST_CHECK(list->back == NULL);

    doubly_linked_list_uint8_free(list);
}

// Create a list with 3 nodes with differents values and check if a value is in the list.
void test_doubly_linked_list_uint8_contains(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    doubly_linked_list_uint8_push_front(list, 5);
    doubly_linked_list_uint8_push_front(list, 10);
    DoublyLinkedListUint8Node *cNode = doubly_linked_list_uint8_node_new(15);

    TEST_CHECK(doubly_linked_list_uint8_contains(list, 0) == false);
    TEST_CHECK(doubly_linked_list_uint8_contains(list, 5) == true);
    TEST_CHECK(doubly_linked_list_uint8_contains(list, 10) == true);
    TEST_CHECK(doubly_linked_list_uint8_contains(list, 15) == false);

    doubly_linked_list_uint8_flush(list);

    TEST_CHECK(doubly_linked_list_uint8_contains(list, 0) == false);
    TEST_CHECK(doubly_linked_list_uint8_contains(list, 5) == false);
    TEST_CHECK(doubly_linked_list_uint8_contains(list, 10) == false);
    TEST_CHECK(doubly_linked_list_uint8_contains(list, 15) == false);

    doubly_linked_list_uint8_node_free(cNode);
    doubly_linked_list_uint8_free(list);
}

// Create a list with 3 nodes with differents values and then pop the front node.
// We then check if the poped value is the correct one and if the value isn't in the list anymore.
void test_doubly_linked_list_uint8_pop_front(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    doubly_linked_list_uint8_push_front(list, 5);  // [5]
    doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    doubly_linked_list_uint8_push_front(list, 15); // [15, 10, 5]
    uint8_t valueCheck = 0;

    TEST_CHECK(doubly_linked_list_uint8_pop_front(list, &valueCheck) == true); // [10, 5]
    TEST_CHECK(valueCheck == 15);
    size_t checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 2);
    TEST_CHECK(doubly_linked_list_uint8_pop_front(list, &valueCheck) == true); // [5]
    TEST_CHECK(valueCheck == 10);
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 1);
    TEST_CHECK(doubly_linked_list_uint8_pop_front(list, &valueCheck) == true); // []
    TEST_CHECK(valueCheck == 5);
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 0);
    TEST_CHECK(list->front == NULL);
    TEST_CHECK(list->back == NULL);

    doubly_linked_list_uint8_free(list);
}

// Create a list with 3 nodes with differents values and then pop the back node.
// We then check if the poped value is the correct one and if the value isn't in the list anymore.
void test_doubly_linked_list_uint8_pop_back(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    doubly_linked_list_uint8_push_front(list, 5);  // [5]
    doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    doubly_linked_list_uint8_push_front(list, 15); // [15, 10, 5]
    uint8_t valueCheck = 0;

    TEST_CHECK(doubly_linked_list_uint8_pop_back(list, &valueCheck) == true); // [15, 10]
    TEST_CHECK(valueCheck == 5);
    size_t checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 2);
    TEST_CHECK(doubly_linked_list_uint8_pop_back(list, &valueCheck) == true); // [15]
    TEST_CHECK(valueCheck == 10);
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 1);
    TEST_CHECK(doubly_linked_list_uint8_pop_back(list, &valueCheck) == true); // []
    TEST_CHECK(valueCheck == 15);
    checkSize = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(checkSize == 0);
    TEST_CHECK(list->front == NULL);
    TEST_CHECK(list->back == NULL);

    doubly_linked_list_uint8_free(list);
}

// Create a list with 2 nodes with differents values and then check if the front one
// is the one we wanted without taking it out of the list
void test_doubly_linked_list_uint8_front(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    doubly_linked_list_uint8_push_front(list, 5);
    doubly_linked_list_uint8_push_front(list, 10);

    DoublyLinkedListUint8Node *nodeCheck = doubly_linked_list_uint8_front(list);
    size_t check = doubly_linked_list_uint8_node_get_value(nodeCheck);
    TEST_CHECK(check == 10);

    doubly_linked_list_uint8_free(list);
}

// Create a list with 2 nodes with differents values and then check if the back one
// is the one we wanted without taking it out of the list
void test_doubly_linked_list_uint8_back(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    doubly_linked_list_uint8_push_front(list, 5);
    doubly_linked_list_uint8_push_front(list, 10);

    DoublyLinkedListUint8Node *nodeCheck = doubly_linked_list_uint8_back(list);
    size_t check = doubly_linked_list_uint8_node_get_value(nodeCheck);
    TEST_CHECK(check == 5);

    doubly_linked_list_uint8_free(list);
}

// Create a list with a node, then insert a node in the list before the first one. Then we do it a
// second time. We check at each step if the values in the list are correct, and if the links are
// not broken.
void test_doubly_linked_list_uint8_insert_node_before(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    DoublyLinkedListUint8Node *aNode = doubly_linked_list_uint8_push_front(list, 5);

    DoublyLinkedListUint8Node *bNode = doubly_linked_list_uint8_insert_node_before(list, aNode, 10);
    size_t check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 10);
    check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 5);
    DoublyLinkedListUint8Node *NodeCheck = doubly_linked_list_uint8_node_previous(aNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 10);
    NodeCheck = doubly_linked_list_uint8_node_next(bNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 5);

    DoublyLinkedListUint8Node *cNode = doubly_linked_list_uint8_insert_node_before(list, aNode, 15);
    NodeCheck = doubly_linked_list_uint8_node_previous(aNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 15);
    NodeCheck = doubly_linked_list_uint8_node_next(bNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 15);
    NodeCheck = doubly_linked_list_uint8_node_previous(cNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 10);
    NodeCheck = doubly_linked_list_uint8_node_next(cNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 5);
    check = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(check == 3);

    doubly_linked_list_uint8_free(list);
}

// Create a list with a node, then insert a node in the list after the first one. Then we do it a
// second time. We check at each step if the values in the list are correct, and if the links are
// not broken.
void test_doubly_linked_list_uint8_insert_node_after(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    DoublyLinkedListUint8Node *aNode = doubly_linked_list_uint8_push_front(list, 5);

    DoublyLinkedListUint8Node *bNode = doubly_linked_list_uint8_insert_node_after(list, aNode, 10);
    size_t check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 5);
    check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 10);
    DoublyLinkedListUint8Node *NodeCheck = doubly_linked_list_uint8_node_next(aNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 10);
    NodeCheck = doubly_linked_list_uint8_node_previous(bNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 5);

    DoublyLinkedListUint8Node *cNode = doubly_linked_list_uint8_insert_node_after(list, aNode, 15);
    NodeCheck = doubly_linked_list_uint8_node_next(aNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 15);
    NodeCheck = doubly_linked_list_uint8_node_previous(bNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 15);
    NodeCheck = doubly_linked_list_uint8_node_previous(cNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 5);
    NodeCheck = doubly_linked_list_uint8_node_next(cNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 10);
    check = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(check == 3);

    doubly_linked_list_uint8_free(list);
}

// Create a list with 3 nodes with differents values, then we delete the node in the middle, after
// that the front one and then the remaining one. We check at each step if the values in the list
// are correct, and if the links are not broken.
void test_doubly_linked_list_uint8_delete_node(void) {
    DoublyLinkedListUint8 *list = doubly_linked_list_uint8_new();
    DoublyLinkedListUint8Node *aNode = doubly_linked_list_uint8_push_front(list, 5);  // [5]
    DoublyLinkedListUint8Node *bNode = doubly_linked_list_uint8_push_front(list, 10); // [10, 5]
    DoublyLinkedListUint8Node *cNode = doubly_linked_list_uint8_push_front(list, 15); // [15, 10, 5]

    doubly_linked_list_uint8_delete_node(list, bNode); // [15, 5]
    size_t check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 15);
    check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 5);
    DoublyLinkedListUint8Node *NodeCheck = doubly_linked_list_uint8_node_previous(aNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 15);
    NodeCheck = doubly_linked_list_uint8_node_next(cNode);
    check = doubly_linked_list_uint8_node_get_value(NodeCheck);
    TEST_CHECK(check == 5);
    check = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(check == 2);

    doubly_linked_list_uint8_delete_node(list, cNode); // [5]
    check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 5);
    check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 5);
    NodeCheck = doubly_linked_list_uint8_node_next(aNode);
    TEST_CHECK(NodeCheck == NULL);
    NodeCheck = doubly_linked_list_uint8_node_previous(aNode);
    TEST_CHECK(NodeCheck == NULL);
    check = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(check == 1);

    doubly_linked_list_uint8_delete_node(list, aNode); // []
    check = doubly_linked_list_uint8_node_get_value(list->front);
    TEST_CHECK(check == 0);
    check = doubly_linked_list_uint8_node_get_value(list->back);
    TEST_CHECK(check == 0);
    check = doubly_linked_list_uint8_node_count(list);
    TEST_CHECK(check == 0);

    doubly_linked_list_uint8_free(list);
}
