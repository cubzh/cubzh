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
    LightNodeQueue *const q = light_node_queue_new();

    LightNode *const check = light_node_queue_pop(q);
    TEST_CHECK(check == NULL);

    light_node_queue_free(q);
}

// Create a queue and insert in it 2 nodes one by one. Then pop each node to check if their coords
// are the good ones.
void test_light_node_get_coords(void) {
    const SHAPE_COORDS_INT3_T coords1 = {-10, 0, 10};
    const SHAPE_COORDS_INT3_T coords2 = {185, 516, -1684};
    SHAPE_COORDS_INT3_T int3Check = {0, 0, 0};
    LightNode *check = NULL;

    LightNodeQueue *const q = light_node_queue_new();

    light_node_queue_push(q, &coords1);
    check = light_node_queue_pop(q);
    light_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coords1.x);
    TEST_CHECK(int3Check.y == coords1.y);
    TEST_CHECK(int3Check.z == coords1.z);

    light_node_queue_push(q, &coords2);
    check = light_node_queue_pop(q);
    light_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coords2.x);
    TEST_CHECK(int3Check.y == coords2.y);
    TEST_CHECK(int3Check.z == coords2.z);

    light_node_queue_free(q);
}

// Create a queue and insert in it a node. Pop the node and check if this is the good one.
void test_light_node_queue_push(void) {
    const SHAPE_COORDS_INT3_T coords = {-10, 0, 10};
    SHAPE_COORDS_INT3_T int3Check = {0, 0, 0};

    LightNodeQueue *q = light_node_queue_new();
    light_node_queue_push(q, &coords);

    LightNode *check = light_node_queue_pop(q);
    light_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coords.x);
    TEST_CHECK(int3Check.y == coords.y);
    TEST_CHECK(int3Check.z == coords.z);

    light_node_queue_free(q);
}

// Create a queue and insert in it 3 different nodes. To check if the pop is done correctly, we pop
// the nodes one by one and check if they are popped in the right order. We also check if their
// values are correct.
void test_light_node_queue_pop(void) {
    const SHAPE_COORDS_INT3_T coordsA = {-10, 0, 10};
    const SHAPE_COORDS_INT3_T coordsB = {-3565, 17368, 20724};
    const SHAPE_COORDS_INT3_T coordsC = {984, -27863, 1563};
    SHAPE_COORDS_INT3_T int3Check = {0, 0, 0};
    LightNode *check = NULL;

    LightNodeQueue *q = light_node_queue_new();
    light_node_queue_push(q, &coordsA); // [coordsA]
    light_node_queue_push(q, &coordsB); // [coordsB, coordsA]
    light_node_queue_push(q, &coordsC); // [coordsC, coordsB, coordsA]

    check = light_node_queue_pop(q); // [coordsB, coordsA]
    light_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coordsC.x);
    TEST_CHECK(int3Check.y == coordsC.y);
    TEST_CHECK(int3Check.z == coordsC.z);

    check = light_node_queue_pop(q); // [coordsA]
    light_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coordsB.x);
    TEST_CHECK(int3Check.y == coordsB.y);
    TEST_CHECK(int3Check.z == coordsB.z);

    check = light_node_queue_pop(q); // []
    light_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coordsA.x);
    TEST_CHECK(int3Check.y == coordsA.y);
    TEST_CHECK(int3Check.z == coordsA.z);

    check = light_node_queue_pop(q);
    TEST_CHECK(check == NULL);

    light_node_queue_free(q);
}

// MARK: - LightRemovalQueue -

// Create a new removal queue and check if the created queue is empty.
void test_light_removal_node_queue_new(void) {
    LightRemovalNodeQueue *q = light_removal_node_queue_new();

    LightRemovalNode *check = light_removal_node_queue_pop(q);
    TEST_CHECK(check == NULL);

    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert a node in it. We now check if the queue isn't empty anymore
void test_light_removal_node_queue_push(void) {
    const SHAPE_COORDS_INT3_T coords = {-10, 0, 10};
    LightRemovalNode *check = NULL;

    LightRemovalNodeQueue *q = light_removal_node_queue_new();
    VERTEX_LIGHT_STRUCT_T light;
    DEFAULT_LIGHT(light);
    uint8_t srgb = 15;
    SHAPE_COLOR_INDEX_INT_T blockID = 100;
    light_removal_node_queue_push(q, &coords, light, srgb, blockID);

    check = light_removal_node_queue_pop(q);
    TEST_CHECK(check != NULL);
    // TODO: free `check`
    check = NULL;

    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert a node in it. Then we pop the node and check if the queue
// is now empty and if the values of the popped value are correct.
void test_light_removal_node_queue_pop(void) {
    const SHAPE_COORDS_INT3_T coords = {-10, 0, 10};
    LightRemovalNode *check = NULL;
    SHAPE_COORDS_INT3_T int3Check = {0, 0, 0};

    LightRemovalNodeQueue *q = light_removal_node_queue_new();
    VERTEX_LIGHT_STRUCT_T light;
    DEFAULT_LIGHT(light);
    uint8_t srgb = 15;
    SHAPE_COLOR_INDEX_INT_T blockID = 100;
    light_removal_node_queue_push(q, &coords, light, srgb, blockID);

    check = light_removal_node_queue_pop(q);
    TEST_CHECK(check != NULL);
    light_removal_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coords.x);
    TEST_CHECK(int3Check.y == coords.y);
    TEST_CHECK(int3Check.z == coords.z);

    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert 2 different nodes in it. Then we pop them one by one from
// the queue and check if the coords of the popped node are correct.
void test_light_removal_node_get_coords(void) {
    const SHAPE_COORDS_INT3_T coordsA = {-10, 0, 10};
    const SHAPE_COORDS_INT3_T coordsB = {29684, -45, -14556};
    LightRemovalNode *check = NULL;
    SHAPE_COORDS_INT3_T int3Check = {0, 0, 0};

    LightRemovalNodeQueue *q = light_removal_node_queue_new();

    // Node A
    VERTEX_LIGHT_STRUCT_T lightA;
    DEFAULT_LIGHT(lightA);
    uint8_t srgbA = 15;
    SHAPE_COLOR_INDEX_INT_T blockIDA = 100;
    light_removal_node_queue_push(q, &coordsA, lightA, srgbA, blockIDA);

    // Node B
    VERTEX_LIGHT_STRUCT_T lightB;
    ZERO_LIGHT(lightB);
    uint8_t srgbB = 30;
    SHAPE_COLOR_INDEX_INT_T blockIDB = 255;
    light_removal_node_queue_push(q, &coordsB, lightB, srgbB, blockIDB);

    // Check for Node B
    check = light_removal_node_queue_pop(q);
    light_removal_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coordsB.x);
    TEST_CHECK(int3Check.y == coordsB.y);
    TEST_CHECK(int3Check.z == coordsB.z);

    // Check for Node A
    check = light_removal_node_queue_pop(q);
    light_removal_node_get_coords(check, &int3Check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(int3Check.x == coordsA.x);
    TEST_CHECK(int3Check.y == coordsA.y);
    TEST_CHECK(int3Check.z == coordsA.z);

    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert 2 different nodes in it. Then we pop them one by one from
// the queue and check if the srgb of the popped node is correct.
void test_light_removal_node_get_srgb(void) {
    const SHAPE_COORDS_INT3_T coordsA = {-10, 0, 10};
    const SHAPE_COORDS_INT3_T coordsB = {29684, -45, -14556};
    LightRemovalNode *check = NULL;
    uint8_t checkSrgb = 0;

    LightRemovalNodeQueue *q = light_removal_node_queue_new();

    // Node A
    VERTEX_LIGHT_STRUCT_T lightA;
    DEFAULT_LIGHT(lightA);
    uint8_t srgbA = 15;
    SHAPE_COLOR_INDEX_INT_T blockIDA = 100;
    light_removal_node_queue_push(q, &coordsA, lightA, srgbA, blockIDA);

    // Node B
    VERTEX_LIGHT_STRUCT_T lightB;
    ZERO_LIGHT(lightB);
    uint8_t srgbB = 30;
    SHAPE_COLOR_INDEX_INT_T blockIDB = 255;
    light_removal_node_queue_push(q, &coordsB, lightB, srgbB, blockIDB);

    // Check for Node B
    check = light_removal_node_queue_pop(q);
    checkSrgb = light_removal_node_get_srgb(check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(checkSrgb == srgbB);

    // Check for Node A
    check = light_removal_node_queue_pop(q);
    checkSrgb = light_removal_node_get_srgb(check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(checkSrgb == srgbA);

    light_removal_node_queue_free(q);
}

// Create a new removal queue and insert 2 different nodes in it. Then we pop them one by one from
// the queue and check if the coords of the popped node is correct.
void test_light_removal_node_get_block_id(void) {
    const SHAPE_COORDS_INT3_T coordsA = {-10, 0, 10};
    const SHAPE_COORDS_INT3_T coordsB = {29684, -45, -14556};
    LightRemovalNode *check = NULL;
    SHAPE_COLOR_INDEX_INT_T checkBlockID = 0;

    LightRemovalNodeQueue *q = light_removal_node_queue_new();

    // Node A
    VERTEX_LIGHT_STRUCT_T lightA;
    DEFAULT_LIGHT(lightA);
    uint8_t srgbA = 15;
    SHAPE_COLOR_INDEX_INT_T blockIDA = 100;
    light_removal_node_queue_push(q, &coordsA, lightA, srgbA, blockIDA);

    // Node B
    VERTEX_LIGHT_STRUCT_T lightB;
    ZERO_LIGHT(lightB);
    uint8_t srgbB = 30;
    SHAPE_COLOR_INDEX_INT_T blockIDB = 255;
    light_removal_node_queue_push(q, &coordsB, lightB, srgbB, blockIDB);

    // Check for Node B
    check = light_removal_node_queue_pop(q);
    checkBlockID = light_removal_node_get_block_id(check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(checkBlockID == blockIDB);

    // Check for Node A
    check = light_removal_node_queue_pop(q);
    checkBlockID = light_removal_node_get_block_id(check);
    // TODO: free `check`
    check = NULL;
    TEST_CHECK(checkBlockID == blockIDA);

    light_removal_node_queue_free(q);
}
