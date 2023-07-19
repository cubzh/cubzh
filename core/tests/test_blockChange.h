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
    BlockChange *BlockA = blockChange_new(255, 0, 0, 0);
    BlockChange *BlockB = blockChange_new(0, 3, 5, 2);
    const Block *blockCheck = NULL;
    SHAPE_COORDS_INT_T coordsCheckX = 0;
    SHAPE_COORDS_INT_T coordsCheckY = 0;
    SHAPE_COORDS_INT_T coordsCheckZ = 0;

    // Get the block and check it with his colorIndex
    blockCheck = blockChange_getBlock(BlockA);
    TEST_CHECK(blockCheck->colorIndex == 255);
    blockCheck = blockChange_getBlock(BlockB);
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

// Create a BlockChange and change his block stocked in the "after" value and check him with his
// colorIndex
void test_blockChange_amend(void) {
    BlockChange *BlockC = blockChange_new(0, 0, 0, 0);

    blockChange_amend(BlockC, 35);
    const Block *blockCheck = blockChange_getBlock(BlockC);
    TEST_CHECK(blockCheck->colorIndex == 35);
    blockChange_amend(BlockC, 0);
    blockCheck = blockChange_getBlock(BlockC);
    TEST_CHECK(blockCheck->colorIndex == 0);

    blockChange_free(BlockC);
}
