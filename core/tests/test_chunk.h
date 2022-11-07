// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_chunk.h
//  Created by Nino PLANE on October 31, 2022.
// -------------------------------------------------------------

#pragma once

#include "block.h"
#include "chunk.h"
#include "int3.h"

///// Some function are left untested :
// --- chunk_get_neighbor()
// --- chunk_leave_neighborhood()
// --- chunk_move_in_neighborhood()
// --- chunk_get_vbma()
// --- chunk_set_vbma()
// --- chunk_write_vertices()
/////

// Create a chunk and check if the default values are the one used
// Also check all of these function :
// --- chunk_new()
// --- chunk_get_pos()
// --- chunk_get_nb_blocks()
//////
void test_chunk_new(void) {
    Chunk *chunk = chunk_new(0, 10, -10);
    const int3 *GetPos = chunk_get_pos(chunk);
    int NBBlocks = chunk_get_nb_blocks(chunk);

    TEST_CHECK(GetPos->x == 0);
    TEST_CHECK(GetPos->y == 10);
    TEST_CHECK(GetPos->z == -10);
    TEST_CHECK(NBBlocks == 0);

    chunk_destroy(chunk);
}

// Create a chunk and 3 differents blocks and place them in the chunk at different coords. Check if
// the function is played and if the block is at the right spot Also check all of these function :
// --- chunk_addBlock()
// --- chunk_paint_block()
// --- chunk_get_block()
// --- chunk_get_block_2()
// --- chunk_get_block_pos()
// --- chunk_get_inner_bounds()
// --- chunk_removeBlock()
/////
void test_chunk_Block(void) {
    Chunk *chunk = chunk_new(10, 8, 5);
    Block *ABlock = block_new();
    Block *BBlock = block_new_air();
    Block *CBlock = block_new_with_color(155);

    // chunk_addBlock()
    TEST_CHECK(chunk_addBlock(chunk, ABlock, 4, 4, 4) == true);
    TEST_CHECK(chunk_addBlock(chunk, BBlock, 5, 5, 5) == true);
    TEST_CHECK(chunk_addBlock(chunk, CBlock, 6, 6, 6) == true);
    TEST_CHECK(chunk_addBlock(chunk, ABlock, 5, 5, 5) == false);

    // chunk_paint_block()
    // Paint the blocks with differents colors
    TEST_CHECK(chunk_paint_block(chunk, 4, 4, 4, 1) == true);
    TEST_CHECK(chunk_paint_block(chunk, 5, 5, 5, 2) == true);
    TEST_CHECK(chunk_paint_block(chunk, 6, 6, 6, 3) == true);
    TEST_CHECK(chunk_paint_block(chunk, 0, 0, 0, 0) == false);

    // chunk_get_block()
    // Check if the block is placed at the right spot in the chunk
    // Also check if the previous function of paint worked
    Block *check = chunk_get_block(chunk, 4, 4, 4);
    TEST_CHECK(check->colorIndex == 1);
    check = chunk_get_block(chunk, 5, 5, 5);
    TEST_CHECK(check->colorIndex == 2);
    check = chunk_get_block(chunk, 6, 6, 6);
    TEST_CHECK(check->colorIndex == 3);
    check = chunk_get_block(chunk, 11, 9, 6);
    TEST_CHECK(check == NULL);

    // chunk_get_block_2()
    int3 pos = {4, 4, 4};
    check = chunk_get_block_2(chunk, &pos);
    TEST_CHECK(check->colorIndex == 1);
    int3_set(&pos, 5, 5, 5);
    check = chunk_get_block_2(chunk, &pos);
    TEST_CHECK(check->colorIndex == 2);
    int3_set(&pos, 6, 6, 6);
    check = chunk_get_block_2(chunk, &pos);
    TEST_CHECK(check->colorIndex == 3);
    int3_set(&pos, 11, 9, 6);
    check = chunk_get_block_2(chunk, &pos);
    TEST_CHECK(check == NULL);

    int NBBlocks = chunk_get_nb_blocks(chunk);
    TEST_CHECK(NBBlocks == 3);

    // chunk_get_block_pos()
    chunk_get_block_pos(chunk, 4, 4, 4, &pos);
    TEST_CHECK(pos.x == 14);
    TEST_CHECK(pos.y == 12);
    TEST_CHECK(pos.z == 9);
    chunk_get_block_pos(chunk, 5, 5, 5, &pos);
    TEST_CHECK(pos.x == 15);
    TEST_CHECK(pos.y == 13);
    TEST_CHECK(pos.z == 10);
    chunk_get_block_pos(chunk, 6, 6, 6, &pos);
    TEST_CHECK(pos.x == 16);
    TEST_CHECK(pos.y == 14);
    TEST_CHECK(pos.z == 11);

    // chunk_get_inner_bounds()
    CHUNK_COORDS_INT_T minX = 0;
    CHUNK_COORDS_INT_T minY = 0;
    CHUNK_COORDS_INT_T minZ = 0;
    CHUNK_COORDS_INT_T maxX = 0;
    CHUNK_COORDS_INT_T maxY = 0;
    CHUNK_COORDS_INT_T maxZ = 0;
    chunk_get_inner_bounds(chunk, &minX, &maxX, &minY, &maxY, &minZ, &maxZ);
    TEST_CHECK(minX == 4 && minY == 4 && minZ == 4 && maxX == 7 && maxY == 7 && maxZ == 7);

    // chunk_removeBlock()
    TEST_CHECK(chunk_removeBlock(chunk, 4, 4, 4) == true);
    check = chunk_get_block(chunk, 4, 4, 4);
    TEST_CHECK(check == NULL);
    NBBlocks = chunk_get_nb_blocks(chunk);
    TEST_CHECK(NBBlocks == 2);
    TEST_CHECK(chunk_removeBlock(chunk, 5, 5, 5) == true);
    check = chunk_get_block(chunk, 5, 5, 5);
    TEST_CHECK(check == NULL);
    NBBlocks = chunk_get_nb_blocks(chunk);
    TEST_CHECK(NBBlocks == 1);
    TEST_CHECK(chunk_removeBlock(chunk, 6, 6, 6) == true);
    check = chunk_get_block(chunk, 6, 6, 6);
    TEST_CHECK(check == NULL);
    NBBlocks = chunk_get_nb_blocks(chunk);
    TEST_CHECK(NBBlocks == 0);
    TEST_CHECK(chunk_removeBlock(chunk, 0, 0, 0) == false);

    chunk_destroy(chunk);
}

// Create a chunk and set diffrents values on the "display bool" of this chunk.
// Then check if the bool is set with the good values
void test_chunk_needs_display(void) {
    Chunk *chunk = chunk_new(10, 10, 10);

    TEST_CHECK(chunk_needs_display(chunk) == false);
    chunk_set_needs_display(chunk, true);
    TEST_CHECK(chunk_needs_display(chunk) == true);
    chunk_set_needs_display(chunk, false);
    TEST_CHECK(chunk_needs_display(chunk) == false);

    chunk_destroy(chunk);
}
