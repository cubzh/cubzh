// -------------------------------------------------------------
//  Cubzh Core
//  block.h
//  Created by Nino PLANE on October 19, 2022.
// -------------------------------------------------------------

#pragma once

#include "block.h"

// Create a new block and check if his colorIndex is 0
void test_block_new(void) {
    Block* a = block_new();

    TEST_CHECK(a->colorIndex == 0);
    block_free(a);
}

// Create a new block of air and check if his colorIndex is 255
void test_block_new_air(void) {
    Block* a = block_new_air();

    TEST_CHECK(a->colorIndex == 255);
    block_free(a);
}

// Create a new block with a set color and check if his colorIndex is the color that we set
void test_block_new_with_color(void) {
    SHAPE_COLOR_INDEX_INT_T color = 152;

    Block *a = block_new_with_color(color);
    TEST_CHECK(a->colorIndex == 152);
    block_free(a);
}

// Create 2 block with different colorIndex and copy them into 2 new blocks. Then we check the colorIndex of the news blocks
void test_block_new_copy(void) {
    SHAPE_COLOR_INDEX_INT_T color = 152;
    Block *a = block_new_with_color(color);
    Block *b = block_new();

    Block *c = block_new_copy(a);
    TEST_CHECK(c->colorIndex == 152);
    Block *d = block_new_copy(b);
    TEST_CHECK(d->colorIndex == 0);
    block_free(a);
    block_free(b);
    block_free(c);
    block_free(d);
}

// Create a normal block, then assign him a color, and check if he have the correct colorIndex
void test_block_set_color_index(void) {
    Block* a = block_new();
    SHAPE_COLOR_INDEX_INT_T color = 152;

    block_set_color_index(a, color);
    TEST_CHECK(a->colorIndex == 152);
    block_free(a);
}

// Create 2 block with different colorIndex, then create a colorCheck to get the colorIndex of each of them and check if it's the good value
void test_block_get_color_index(void) {
    Block* a = block_new();
    Block* b = block_new_air();
    SHAPE_COLOR_INDEX_INT_T color = 152;
    block_set_color_index(a, color);

    SHAPE_COLOR_INDEX_INT_T colorCheck;
    colorCheck = block_get_color_index(a);
    TEST_CHECK(colorCheck == 152);
    colorCheck = block_get_color_index(b);
    TEST_CHECK(colorCheck == 255);
    block_free(a);
    block_free(b);
}

// Create 2 block with different colorIndex then check if the colorIndex is != 255
void test_block_is_solid(void) {
    Block* a = block_new();
    Block* b = block_new_air();

    TEST_CHECK(block_is_solid(a) == true);
    TEST_CHECK(block_is_solid(b) == false);
    block_free(a);
    block_free(b);
}

// Create 4 block with 2 different type and check them with each other to see is they are equal
void test_block_equal(void) {
    Block* a = block_new();
    Block* b = block_new();
    Block* c = block_new_air();
    Block* d = block_new_air();

    TEST_CHECK(block_equal(a, b) == true);
    TEST_CHECK(block_equal(c, d) == true);
    TEST_CHECK(block_equal(a, c) == false);
    block_free(a);
    block_free(b);
    block_free(c);
    block_free(d);
}

// ColorAtlas must be created before using color_palette_get_default_2021 and deleted afterwards
// With current API, some state is needed. How can we do ? Should we change the colorPalette API ?
// void test_block_is_opaque(void) {
//     Block* a = block_new();
//     Block* b = block_new_air();
//     ColorAtlas* ColorA = color_atlas_new();
//     ColorPalette* ColorP = color_palette_get_default_2021(ColorA);
//     TEST_CHECK(block_is_opaque(a, ColorP) == true);
//     TEST_CHECK(block_is_opaque(b, ColorP) == false);
//     block_free(a);
//     block_free(b);
// }
// void test_block_is_transparent(void) {
//     Block* a = block_new();
//     Block* b = block_new_air();
//     ColorAtlas* ColorA = color_atlas_new();
//     ColorPalette* ColorP = color_palette_get_default_2021(ColorA);
//     TEST_CHECK(block_is_transparent(a, ColorP) == false);
//     TEST_CHECK(block_is_transparent(b, ColorP) == true);
//     block_free(a);
//     block_free(b);
// }
// void test_block_is_ao_and_light_caster(void) {
// }
// void test_block_is_any(void) {
// }

// Create 2 AwareBlock and check all the different "get" function
void test_aware_block_get(void) {
    Block* a = block_new();
    int3* shapePosA = int3_new(0, 0, 0);
    int3* chunkPosA = int3_new(0, 0, 0);
    AwareBlock* aBlock = aware_block_new(a, shapePosA, chunkPosA, 0);
    Block* b = block_new_air();
    int3* shapePosB = int3_new(1, 1, 1);
    int3* chunkPosB = int3_new(1, 1, 1);
    AwareBlock* bBlock = aware_block_new(b, shapePosB, chunkPosB, 1);
    int3* checkShapePos = NULL;
    int3* checkChunkPos = NULL;
    int3* checkShapeTargetPos = NULL;
    Block* checkBlock = NULL;
    SHAPE_COLOR_INDEX_INT_T checkColor = NULL;

    // Get the block of an AwareBlock and check his colorIndex
    checkBlock = aware_block_get_block(aBlock);
    TEST_CHECK(checkBlock->colorIndex == 0);
    checkBlock = aware_block_get_block(bBlock);
    TEST_CHECK(checkBlock->colorIndex == 255);

    // Get the colorIndex of the block inside the AwareBlock and check him
    checkColor = aware_block_get_color_index(aBlock);
    TEST_CHECK(checkColor == 0);
    checkColor = aware_block_get_color_index(bBlock);
    TEST_CHECK(checkColor == 255);

    // Get the int3 of the ShapePos inside de AwareBlock and check him
    checkShapePos = aware_block_get_shape_pos(aBlock);
    TEST_CHECK(checkShapePos->x == 0);
    TEST_CHECK(checkShapePos->y == 0);
    TEST_CHECK(checkShapePos->z == 0);
    checkShapePos = aware_block_get_shape_pos(bBlock);
    TEST_CHECK(checkShapePos->x == 1);
    TEST_CHECK(checkShapePos->y == 1);
    TEST_CHECK(checkShapePos->z == 1);

    // Get the int3 of the ChunkPos inside de AwareBlock and check him
    checkChunkPos = aware_block_get_chunk_pos(aBlock);
    TEST_CHECK(checkChunkPos->x == 0);
    TEST_CHECK(checkChunkPos->y == 0);
    TEST_CHECK(checkChunkPos->z == 0);
    checkChunkPos = aware_block_get_chunk_pos(bBlock);
    TEST_CHECK(checkChunkPos->x == 1);
    TEST_CHECK(checkChunkPos->y == 1);
    TEST_CHECK(checkChunkPos->z == 1);

    // Get the int3 of the ShapeTargetPos inside de AwareBlock and check him with different faceIndex
    checkShapeTargetPos = aware_block_get_shape_target_pos(aBlock);
    TEST_CHECK(checkShapeTargetPos->x == 1);
    TEST_CHECK(checkShapeTargetPos->y == 0);
    TEST_CHECK(checkShapeTargetPos->z == 0);
    checkShapeTargetPos = aware_block_get_shape_target_pos(bBlock);
    TEST_CHECK(checkShapeTargetPos->x == 0);
    TEST_CHECK(checkShapeTargetPos->y == 1);
    TEST_CHECK(checkShapeTargetPos->z == 1);

    block_free(a);
    block_free(b);
    int3_free(shapePosA);
    int3_free(chunkPosA);
    int3_free(shapePosB);
    int3_free(chunkPosB);
    aware_block_free(aBlock);
    aware_block_free(bBlock);
}

// Create a AwareBlock and copy all his information into a second one. Then check all the information of the new AwareBlock
void test_aware_block_new_copy(void) {
    Block* a = block_new();
    int3* shapePos = int3_new(1, 1, 1);
    int3* chunkPos = int3_new(1, 1, 1);
    AwareBlock* aBlock = aware_block_new(a, shapePos, chunkPos, 3);
    AwareBlock* bBlock = aware_block_new_copy(aBlock);
    int3* checkShapePos = NULL;
    int3* checkChunkPos = NULL;
    int3* checkShapeTargetPos = NULL;
    Block* checkBlock = NULL;
    SHAPE_COLOR_INDEX_INT_T checkColor = NULL;

    checkBlock = aware_block_get_block(bBlock);
    TEST_CHECK(checkBlock->colorIndex == 0);
    checkColor = aware_block_get_color_index(bBlock);
    TEST_CHECK(checkColor == 0);
    checkShapePos = aware_block_get_shape_pos(bBlock);
    TEST_CHECK(checkShapePos->x == 1);
    TEST_CHECK(checkShapePos->y == 1);
    TEST_CHECK(checkShapePos->z == 1);
    checkChunkPos = aware_block_get_chunk_pos(bBlock);
    TEST_CHECK(checkChunkPos->x == 1);
    TEST_CHECK(checkChunkPos->y == 1);
    TEST_CHECK(checkChunkPos->z == 1);
    checkShapeTargetPos = aware_block_get_shape_target_pos(bBlock);
    TEST_CHECK(checkShapeTargetPos->x == 1);
    TEST_CHECK(checkShapeTargetPos->y == 1);
    TEST_CHECK(checkShapeTargetPos->z == 0);

    block_free(a);
    int3_free(shapePos);
    int3_free(chunkPos);
    aware_block_free(aBlock);
    aware_block_free(bBlock);
}

// Create a AwareBlock and change the faceIndex with all possibilities, then check the int3 of his ShapeTargetPos 
void test_aware_block_set_touched_face(void) {
    Block* a = block_new();
    int3* shapePos = int3_new(0, 0, 0);
    int3* chunkPos = int3_new(0, 0, 0);
    AwareBlock* aBlock = aware_block_new(a, shapePos, chunkPos, 0);
    int3* checkShapeTargetPos = NULL;

    aware_block_set_touched_face(aBlock, 1);
    checkShapeTargetPos = aware_block_get_shape_target_pos(aBlock);
    TEST_CHECK(checkShapeTargetPos->x == -1);
    TEST_CHECK(checkShapeTargetPos->y == 0);
    TEST_CHECK(checkShapeTargetPos->z == 0);

    aware_block_set_touched_face(aBlock, 2);
    checkShapeTargetPos = aware_block_get_shape_target_pos(aBlock);
    TEST_CHECK(checkShapeTargetPos->x == 0);
    TEST_CHECK(checkShapeTargetPos->y == 0);
    TEST_CHECK(checkShapeTargetPos->z == 1);

    aware_block_set_touched_face(aBlock, 3);
    checkShapeTargetPos = aware_block_get_shape_target_pos(aBlock);
    TEST_CHECK(checkShapeTargetPos->x == 0);
    TEST_CHECK(checkShapeTargetPos->y == 0);
    TEST_CHECK(checkShapeTargetPos->z == -1);

    aware_block_set_touched_face(aBlock, 4);
    checkShapeTargetPos = aware_block_get_shape_target_pos(aBlock);
    TEST_CHECK(checkShapeTargetPos->x == 0);
    TEST_CHECK(checkShapeTargetPos->y == 1);
    TEST_CHECK(checkShapeTargetPos->z == 0);

    aware_block_set_touched_face(aBlock, 5);
    checkShapeTargetPos = aware_block_get_shape_target_pos(aBlock);
    TEST_CHECK(checkShapeTargetPos->x == 0);
    TEST_CHECK(checkShapeTargetPos->y == -1);
    TEST_CHECK(checkShapeTargetPos->z == 0);

    aware_block_set_touched_face(aBlock, 6);
    checkShapeTargetPos = aware_block_get_shape_target_pos(aBlock);
    TEST_CHECK(checkShapeTargetPos == NULL);

    block_free(a);
    int3_free(shapePos);
    int3_free(chunkPos);
    aware_block_free(aBlock);
}

// Create a AwareBlock and get the neighbours blocks of all his faces then check the int3 of their coords 
void test_block_getNeighbourBlockCoordinates(void) {
    Block* a = block_new();
    int3* shapePos = int3_new(3, 5, 2);
    int3* chunkPos = int3_new(0, 0, 0);
    AwareBlock* aBlock = aware_block_new(a, shapePos, chunkPos, 0);
    int3* checkShapePos = NULL;
    SHAPE_COORDS_INT_T newx = NULL;
    SHAPE_COORDS_INT_T newy = NULL;
    SHAPE_COORDS_INT_T newz = NULL;

    checkShapePos = aware_block_get_shape_pos(aBlock);
    block_getNeighbourBlockCoordinates(checkShapePos->x, checkShapePos->y, checkShapePos->z, 0, &newx, &newy, &newz);
    TEST_CHECK(newx == 4 && newy == 5 && newz == 2);
    block_getNeighbourBlockCoordinates(checkShapePos->x, checkShapePos->y, checkShapePos->z, 1, &newx, &newy, &newz);
    TEST_CHECK(newx == 2 && newy == 5 && newz == 2);
    block_getNeighbourBlockCoordinates(checkShapePos->x, checkShapePos->y, checkShapePos->z, 2, &newx, &newy, &newz);
    TEST_CHECK(newx == 3 && newy == 5 && newz == 3);
    block_getNeighbourBlockCoordinates(checkShapePos->x, checkShapePos->y, checkShapePos->z, 3, &newx, &newy, &newz);
    TEST_CHECK(newx == 3 && newy == 5 && newz == 1);
    block_getNeighbourBlockCoordinates(checkShapePos->x, checkShapePos->y, checkShapePos->z, 4, &newx, &newy, &newz);
    TEST_CHECK(newx == 3 && newy == 6 && newz == 2);
    block_getNeighbourBlockCoordinates(checkShapePos->x, checkShapePos->y, checkShapePos->z, 5, &newx, &newy, &newz);
    TEST_CHECK(newx == 3 && newy == 4 && newz == 2);

    block_free(a);
    int3_free(shapePos);
    int3_free(chunkPos);
    aware_block_free(aBlock);
}

