// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_transaction.h
//  Created by Xavier Legland on October 20, 2022.
// -------------------------------------------------------------

#pragma once

#include "transaction.h"

// function that are NOT tested:
// transaction_free
// transaction_resetIndex3DIterator

// check default values
void test_transaction_new(void) {
    Transaction *t = transaction_new();

    TEST_CHECK(transaction_getMustConsiderNewBounds(t) == false);

    transaction_free(t);
}

// add a block and check its color index
void test_transaction_getCurrentBlockAt(void) {
    Transaction *t = transaction_new();
    const SHAPE_COORDS_INT_T x = 1, y = 2, z = 3;
    const SHAPE_COLOR_INDEX_INT_T color_index = 1;
    const bool ok = transaction_addBlock(t, x, y, z, color_index);

    TEST_CHECK(ok);

    const Block *block = transaction_getCurrentBlockAt(t, x, y, z);
    TEST_CHECK(block->colorIndex == color_index);

    transaction_free(t);
}

// same tests as test_transaction_getCurrentBlockAt
void test_transaction_addBlock(void) {
    Transaction *t = transaction_new();
    const SHAPE_COORDS_INT_T x = 1, y = 2, z = 3;
    const SHAPE_COLOR_INDEX_INT_T color_index = 1;
    const bool ok = transaction_addBlock(t, x, y, z, color_index);

    TEST_CHECK(ok);

    const Block *block = transaction_getCurrentBlockAt(t, x, y, z);
    TEST_CHECK(block->colorIndex == color_index);

    transaction_free(t);
}

// remove a block and check if it is an air block
void test_transaction_removeBlock(void) {
    Transaction *t = transaction_new();
    const SHAPE_COORDS_INT_T x = 1, y = 2, z = 3;
    transaction_removeBlock(t, x, y, z);
    const Block *block = transaction_getCurrentBlockAt(t, x, y, z);

    TEST_CHECK(block->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    transaction_free(t);
}

// check color index of replaced block
void test_transaction_replaceBlock(void) {
    Transaction *t = transaction_new();
    const SHAPE_COORDS_INT_T x = 1, y = 2, z = 3;
    const SHAPE_COLOR_INDEX_INT_T color_index = 2;
    transaction_addBlock(t, x, y, z, 1);
    transaction_replaceBlock(t, x, y, z, color_index);
    const Block *block = transaction_getCurrentBlockAt(t, x, y, z);

    TEST_CHECK(block->colorIndex == color_index);

    transaction_free(t);
}

// check that adding a block sets MustConsiderNewBounds to true
void test_transaction_getMustConsiderNewBounds(void) {
    Transaction *t = transaction_new();
    const SHAPE_COORDS_INT_T x = 1, y = 2, z = 3;
    const SHAPE_COLOR_INDEX_INT_T color_index = 1;
    transaction_addBlock(t, x, y, z, color_index);

    TEST_CHECK(transaction_getMustConsiderNewBounds(t));

    transaction_free(t);
}

// check new min / max values
void test_transaction_getNewBounds(void) {
    Transaction *t = transaction_new();
    const SHAPE_COLOR_INDEX_INT_T color_index = 1;
    SHAPE_COORDS_INT_T minX, minY, minZ, maxX, maxY, maxZ;
    transaction_addBlock(t, 1, 2, 3, color_index);
    transaction_addBlock(t, 5, 6, 1, color_index);
    transaction_getNewBounds(t, &minX, &minY, &minZ, &maxX, &maxY, &maxZ);

    TEST_CHECK(minX == 1);
    TEST_CHECK(minY == 2);
    TEST_CHECK(minZ == 1);
    TEST_CHECK(maxX == 5);
    TEST_CHECK(maxY == 6);
    TEST_CHECK(maxZ == 3);

    transaction_free(t);
}

// check that index 3d is not empty if we add a block
void test_transaction_getIndex3DIterator(void) {
    Transaction *t = transaction_new();
    transaction_addBlock(t, 1, 2, 3, 4);
    const Index3DIterator *it = transaction_getIndex3DIterator(t);
    const BlockChange *bc = (const BlockChange*)index3d_iterator_pointer(it);
    
    TEST_CHECK(bc != NULL);
    transaction_free(t);
}
