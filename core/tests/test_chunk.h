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
// --- chunk_get_origin()
// --- chunk_get_nb_blocks()
//////
void test_chunk_new(void) {
    Chunk *chunk = chunk_new(0, 10, -10);
    SHAPE_COORDS_INT3_T origin = chunk_get_origin(chunk);
    int NBBlocks = chunk_get_nb_blocks(chunk);

    TEST_CHECK(origin.x == 0);
    TEST_CHECK(origin.y == 10);
    TEST_CHECK(origin.z == -10);
    TEST_CHECK(NBBlocks == 0);

    chunk_free(chunk, false);
}

// Create a chunk and 3 differents blocks and place them in the chunk at different coords. Check if
// the function is played and if the block is at the right spot Also check all of these function :
// --- chunk_add_block()
// --- chunk_paint_block()
// --- chunk_get_block()
// --- chunk_get_block_2()
// --- chunk_get_block_coords_in_shape()
// --- chunk_get_bounding_box()
// --- chunk_remove_block()
/////
void test_chunk_Block(void) {
    Chunk *chunk = chunk_new(10, 8, 5);
    Block *ABlock = block_new();
    Block *BBlock = block_new_air();
    Block *CBlock = block_new_with_color(155);

    // chunk_add_block()
    TEST_CHECK(chunk_add_block(chunk, *ABlock, 4, 4, 4) == true);
    TEST_CHECK(chunk_add_block(chunk, *BBlock, 5, 5, 5) ==
               false); // adding an air block should do nothing
    TEST_CHECK(chunk_add_block(chunk, *CBlock, 6, 6, 6) == true);
    TEST_CHECK(chunk_add_block(chunk, *ABlock, 4, 4, 4) == false);

    block_free(ABlock);
    block_free(BBlock);
    block_free(CBlock);

    // chunk_paint_block()
    // Paint the blocks with differents colors
    TEST_CHECK(chunk_paint_block(chunk, 4, 4, 4, 1, NULL) == true);
    TEST_CHECK(chunk_paint_block(chunk, 6, 6, 6, 3, NULL) == true);
    TEST_CHECK(chunk_paint_block(chunk, 0, 0, 0, 0, NULL) == false);

    // chunk_get_block()
    // Check if the block is placed at the right spot in the chunk
    // Also check if the previous function of paint worked
    Block *check = chunk_get_block(chunk, 4, 4, 4);
    TEST_CHECK(check->colorIndex == 1);
    check = chunk_get_block(chunk, 6, 6, 6);
    TEST_CHECK(check->colorIndex == 3);
    check = chunk_get_block(chunk, 11, 9, 6);
    TEST_CHECK(check->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    // chunk_get_block_2()
    CHUNK_COORDS_INT3_T pos = {4, 4, 4};
    check = chunk_get_block_2(chunk, pos);
    TEST_CHECK(check->colorIndex == 1);
    pos = (CHUNK_COORDS_INT3_T){6, 6, 6};
    check = chunk_get_block_2(chunk, pos);
    TEST_CHECK(check->colorIndex == 3);
    pos = (CHUNK_COORDS_INT3_T){11, 9, 6};
    check = chunk_get_block_2(chunk, pos);
    TEST_CHECK(check->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    int NBBlocks = chunk_get_nb_blocks(chunk);
    TEST_CHECK(NBBlocks == 2);

    // chunk_get_block_coords_in_shape()
    SHAPE_COORDS_INT3_T coords = {11, 9, 6};
    coords = chunk_get_block_coords_in_shape(chunk, 4, 4, 4);
    TEST_CHECK(coords.x == 14);
    TEST_CHECK(coords.y == 12);
    TEST_CHECK(coords.z == 9);
    coords = chunk_get_block_coords_in_shape(chunk, 5, 5, 5);
    TEST_CHECK(coords.x == 15);
    TEST_CHECK(coords.y == 13);
    TEST_CHECK(coords.z == 10);
    coords = chunk_get_block_coords_in_shape(chunk, 6, 6, 6);
    TEST_CHECK(coords.x == 16);
    TEST_CHECK(coords.y == 14);
    TEST_CHECK(coords.z == 11);

    // chunk_get_bounding_box()
    float3 min, max;
    chunk_get_bounding_box(chunk, &min, &max);
    TEST_CHECK(min.x == 4 && min.y == 4 && min.z == 4 && max.x == 7 && max.y == 7 && max.z == 7);

    // chunk_remove_block()
    TEST_CHECK(chunk_remove_block(chunk, 4, 4, 4, NULL) == true);
    check = chunk_get_block(chunk, 4, 4, 4);
    TEST_CHECK(check->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);
    NBBlocks = chunk_get_nb_blocks(chunk);
    TEST_CHECK(NBBlocks == 1);
    TEST_CHECK(chunk_remove_block(chunk, 6, 6, 6, NULL) == true);
    check = chunk_get_block(chunk, 6, 6, 6);
    TEST_CHECK(check->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);
    NBBlocks = chunk_get_nb_blocks(chunk);
    TEST_CHECK(NBBlocks == 0);
    TEST_CHECK(chunk_remove_block(chunk, 0, 0, 0, NULL) == false);

    chunk_free(chunk, false);
}

// Create a chunk and set differents values on the "display bool" of this chunk.
// Then check if the bool is set with the good values
void test_chunk_needs_display(void) {
    Chunk *chunk = chunk_new(10, 10, 10);

    TEST_CHECK(chunk_is_dirty(chunk) == false);
    chunk_set_dirty(chunk, true);
    TEST_CHECK(chunk_is_dirty(chunk) == true);
    chunk_set_dirty(chunk, false);
    TEST_CHECK(chunk_is_dirty(chunk) == false);

    chunk_free(chunk, false);
}
