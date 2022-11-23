// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_flood_fill_lighting.h
//  Created by Nino PLANE on November 22, 2022.
// -------------------------------------------------------------

#pragma once

#include "flood_fill_lighting.h"
#include "int3.h"

// Function that are not tested :
// light_node_queue_recycle
// light_node_queue_free
// light_removal_node_queue_free
// light_removal_node_queue_recycle
// light_removal_node_get_light

// Create a new queue and check if the created queue is empty.
void test_light_node_queue_new(void) {
    LightNodeQueue *q = light_node_queue_new();

    LightNode *check = light_node_queue_pop(q);
    TEST_CHECK(check == NULL);

    light_node_queue_free(q);
}

// Create a queue and insert in it 2 nodes one by one. Then pop each node to check if their coords
// are the good ones.
void test_light_node_get_coords(void) {
    LightNodeQueue *q = light_node_queue_new();
    int3 *coords = int3_new(-10, 0, 10);
    int3 *int3Check = int3_new(1, 1, 1);
    light_node_queue_push(q, coords);

    LightNode *check = light_node_queue_pop(q);
    light_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coords->x);
    TEST_CHECK(int3Check->y == coords->y);
    TEST_CHECK(int3Check->z == coords->z);

    int3_set(coords, 185, 516, -1684);
    light_node_queue_push(q, coords);
    check = light_node_queue_pop(q);
    light_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coords->x);
    TEST_CHECK(int3Check->y == coords->y);
    TEST_CHECK(int3Check->z == coords->z);

    int3_free(coords);
    int3_free(int3Check);
    light_node_queue_free(q);
}

// Create a queue and insert in it a node. Pop the node and check if this is the good one.
void test_light_node_queue_push(void) {
    LightNodeQueue *q = light_node_queue_new();
    int3 *coords = int3_new(-10, 0, 10);

    light_node_queue_push(q, coords);
    LightNode *check = light_node_queue_pop(q);
    int3 *int3Check = int3_new(0, 0, 0);
    light_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coords->x);
    TEST_CHECK(int3Check->y == coords->y);
    TEST_CHECK(int3Check->z == coords->z);

    int3_free(coords);
    int3_free(int3Check);
    light_node_queue_free(q);
}

// Create a queue and insert in it 3 different nodes. To check if the pop is done correctly, we pop
// the nodes one by one and check if they are popped in the right order. We also check if their
// values are correct.
void test_light_node_queue_pop(void) {
    LightNodeQueue *q = light_node_queue_new();
    int3 *coordsA = int3_new(-10, 0, 10);
    int3 *coordsB = int3_new(-8654321, 541656, 51466484);
    int3 *coordsC = int3_new(984, -54684887, 1563);
    light_node_queue_push(q, coordsA); // [coordsA]
    light_node_queue_push(q, coordsB); // [coordsB, coordsA]
    light_node_queue_push(q, coordsC); // [coordsC, coordsB, coordsA]

    LightNode *check = light_node_queue_pop(q); // [coordsB, coordsA]
    int3 *int3Check = int3_new(0, 0, 0);
    light_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coordsC->x);
    TEST_CHECK(int3Check->y == coordsC->y);
    TEST_CHECK(int3Check->z == coordsC->z);

    check = light_node_queue_pop(q); // [coordsA]
    light_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coordsB->x);
    TEST_CHECK(int3Check->y == coordsB->y);
    TEST_CHECK(int3Check->z == coordsB->z);

    check = light_node_queue_pop(q); // []
    light_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coordsA->x);
    TEST_CHECK(int3Check->y == coordsA->y);
    TEST_CHECK(int3Check->z == coordsA->z);

    check = light_node_queue_pop(q);
    TEST_CHECK(check == NULL);

    int3_free(coordsA);
    int3_free(coordsB);
    int3_free(coordsC);
    int3_free(int3Check);
    light_node_queue_free(q);
}

// Create a new removal queue and check if the created queue is empty.
void test_light_removal_node_queue_new(void) {
    LightRemovalNodeQueue *q = light_removal_node_queue_new();

    LightRemovalNode *check = light_removal_node_queue_pop(q);
    TEST_CHECK(check == NULL);

    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert a node in it. We now check if the queue isn't empty anymore
void test_light_removal_node_queue_push(void) {
    LightRemovalNodeQueue *q = light_removal_node_queue_new();
    int3 *coords = int3_new(-10, 0, 10);
    VERTEX_LIGHT_STRUCT_T light;
    DEFAULT_LIGHT(light);
    uint8_t srgb = 15;
    SHAPE_COLOR_INDEX_INT_T blockID = 100;
    light_removal_node_queue_push(q, coords, light, srgb, blockID);

    LightRemovalNode *check = light_removal_node_queue_pop(q);
    TEST_CHECK(check != NULL);

    int3_free(coords);
    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert a node in it. Then we pop the node and check if the queue
// is now empty and if the values of the popped value are correct.
void test_light_removal_node_queue_pop(void) {
    LightRemovalNodeQueue *q = light_removal_node_queue_new();
    int3 *coords = int3_new(-10, 0, 10);
    VERTEX_LIGHT_STRUCT_T light;
    DEFAULT_LIGHT(light);
    uint8_t srgb = 15;
    SHAPE_COLOR_INDEX_INT_T blockID = 100;
    light_removal_node_queue_push(q, coords, light, srgb, blockID);

    LightRemovalNode *check = light_removal_node_queue_pop(q);
    TEST_CHECK(check != NULL);
    int3 *int3Check = int3_new(0, 0, 0);
    light_removal_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coords->x);
    TEST_CHECK(int3Check->y == coords->y);
    TEST_CHECK(int3Check->z == coords->z);

    int3_free(coords);
    int3_free(int3Check);
    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert 2 different nodes in it. Then we pop them one by one from
// the queue and check if the coords of the popped node are correct.
void test_light_removal_node_get_coords(void) {
    LightRemovalNodeQueue *q = light_removal_node_queue_new();
    // Node A
    int3 *coordsA = int3_new(-10, 0, 10);
    VERTEX_LIGHT_STRUCT_T lightA;
    DEFAULT_LIGHT(lightA);
    uint8_t srgbA = 15;
    SHAPE_COLOR_INDEX_INT_T blockIDA = 100;
    light_removal_node_queue_push(q, coordsA, lightA, srgbA, blockIDA);

    // Node B
    int3 *coordsB = int3_new(29684, -45, 116516);
    VERTEX_LIGHT_STRUCT_T lightB;
    ZERO_LIGHT(lightB);
    uint8_t srgbB = 30;
    SHAPE_COLOR_INDEX_INT_T blockIDB = 255;
    light_removal_node_queue_push(q, coordsB, lightB, srgbB, blockIDB);

    // Check for Node B
    LightRemovalNode *check = light_removal_node_queue_pop(q);
    int3 *int3Check = int3_new(0, 0, 0);
    light_removal_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coordsB->x);
    TEST_CHECK(int3Check->y == coordsB->y);
    TEST_CHECK(int3Check->z == coordsB->z);

    // Check for Node A
    check = light_removal_node_queue_pop(q);
    light_removal_node_get_coords(check, int3Check);
    TEST_CHECK(int3Check->x == coordsA->x);
    TEST_CHECK(int3Check->y == coordsA->y);
    TEST_CHECK(int3Check->z == coordsA->z);

    int3_free(coordsA);
    int3_free(coordsB);
    int3_free(int3Check);
    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert 2 different nodes in it. Then we pop them one by one from
// the queue and check if the srgb of the popped node is correct.
void test_light_removal_node_get_srgb(void) {
    LightRemovalNodeQueue *q = light_removal_node_queue_new();
    // Node A
    int3 *coordsA = int3_new(-10, 0, 10);
    VERTEX_LIGHT_STRUCT_T lightA;
    DEFAULT_LIGHT(lightA);
    uint8_t srgbA = 15;
    SHAPE_COLOR_INDEX_INT_T blockIDA = 100;
    light_removal_node_queue_push(q, coordsA, lightA, srgbA, blockIDA);

    // Node B
    int3 *coordsB = int3_new(29684, -45, 116516);
    VERTEX_LIGHT_STRUCT_T lightB;
    ZERO_LIGHT(lightB);
    uint8_t srgbB = 30;
    SHAPE_COLOR_INDEX_INT_T blockIDB = 255;
    light_removal_node_queue_push(q, coordsB, lightB, srgbB, blockIDB);

    // Check for Node B
    LightRemovalNode *check = light_removal_node_queue_pop(q);
    uint8_t checkSrgb = light_removal_node_get_srgb(check);
    TEST_CHECK(checkSrgb == srgbB);

    // Check for Node A
    check = light_removal_node_queue_pop(q);
    checkSrgb = light_removal_node_get_srgb(check);
    TEST_CHECK(checkSrgb == srgbA);

    int3_free(coordsA);
    int3_free(coordsB);
    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert 2 different nodes in it. Then we pop them one by one from
// the queue and check if the coords of the popped node is correct.
void test_light_removal_node_get_block_id(void) {
    LightRemovalNodeQueue *q = light_removal_node_queue_new();
    // Node A
    int3 *coordsA = int3_new(-10, 0, 10);
    VERTEX_LIGHT_STRUCT_T lightA;
    DEFAULT_LIGHT(lightA);
    uint8_t srgbA = 15;
    SHAPE_COLOR_INDEX_INT_T blockIDA = 100;
    light_removal_node_queue_push(q, coordsA, lightA, srgbA, blockIDA);

    // Node B
    int3 *coordsB = int3_new(29684, -45, 116516);
    VERTEX_LIGHT_STRUCT_T lightB;
    ZERO_LIGHT(lightB);
    uint8_t srgbB = 30;
    SHAPE_COLOR_INDEX_INT_T blockIDB = 255;
    light_removal_node_queue_push(q, coordsB, lightB, srgbB, blockIDB);

    // Check for Node B
    LightRemovalNode *check = light_removal_node_queue_pop(q);
    SHAPE_COLOR_INDEX_INT_T checkBlockID = light_removal_node_get_block_id(check);
    TEST_CHECK(checkBlockID == blockIDB);

    // Check for Node A
    check = light_removal_node_queue_pop(q);
    checkBlockID = light_removal_node_get_block_id(check);
    TEST_CHECK(checkBlockID == blockIDA);

    int3_free(coordsA);
    int3_free(coordsB);
    light_removal_node_queue_free(q);
}
