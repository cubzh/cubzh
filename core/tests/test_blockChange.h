// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_blockChange.h
//  Created by Nino PLANE on October 25, 2022.
// -------------------------------------------------------------

#pragma once

#include "block.h"
#include "blockChange.h"

// Function that are not tested :
// - blockChange_free()
// - blockChange_freeFunc()

// Create 2 different blockChange and check the return values of all the "get" functions
void test_blockChange_get(void) {
    Block* a = block_new();
    Block* b = block_new();
    Block* c = block_new_air();
    Block* d = block_new_air();
    BlockChange* BlockA = blockChange_new(a, c, 0, 0, 0);
    BlockChange* BlockB = blockChange_new(d, b, 3, 5, 2);
    Block* blockCheck = NULL;
    SHAPE_COORDS_INT_T coordsCheckX = NULL;
    SHAPE_COORDS_INT_T coordsCheckY = NULL;
    SHAPE_COORDS_INT_T coordsCheckZ = NULL;

    // Get the block stocked in "before" and check him with his colorIndex
    blockCheck = blockChange_getBefore(BlockA);
    TEST_CHECK(blockCheck->colorIndex == 0);
    blockCheck = blockChange_getBefore(BlockB);
    TEST_CHECK(blockCheck->colorIndex == 255);

    // Get the block stocked in "after" and check him with his colorIndex
    blockCheck = blockChange_getAfter(BlockA);
    TEST_CHECK(blockCheck->colorIndex == 255);
    blockCheck = blockChange_getAfter(BlockB);
    TEST_CHECK(blockCheck->colorIndex == 0);

    // Get the coords stocked in the x, y, z, values of the BlockChange and check them 
    blockChange_getXYZ(BlockA, &coordsCheckX, &coordsCheckY, &coordsCheckZ);
    TEST_CHECK(coordsCheckX == 0);
    TEST_CHECK(coordsCheckY == 0);
    TEST_CHECK(coordsCheckZ == 0);
    blockChange_getXYZ(BlockB, &coordsCheckX, &coordsCheckY, &coordsCheckZ);
    TEST_CHECK(coordsCheckX == 3);
    TEST_CHECK(coordsCheckY == 5);
    TEST_CHECK(coordsCheckZ == 2);

    blockChange_free(BlockA);
    blockChange_free(BlockB);
}

// Create a BlockChange and change his block stocked in the "after" value and check him with his colorIndex 
void test_blockChange_amend(void) {
    Block* a = block_new();
    Block* b = block_new();
    BlockChange* BlockC = blockChange_new(a, b, 0, 0, 0);

    Block* c = block_new_with_color(35);
    blockChange_amend(BlockC, c);
    Block* blockCheck = blockChange_getAfter(BlockC);
    TEST_CHECK(blockCheck->colorIndex == 35);
    Block* d = block_new();
    blockChange_amend(BlockC, d);
    blockCheck = blockChange_getAfter(BlockC);
    TEST_CHECK(blockCheck->colorIndex == 0);

    blockChange_free(BlockC);
}
