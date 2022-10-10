//
//  test_shape.h
//  engine-unit-tests
//
//  Created by Gaetan de Villele on 09/09/2022.
//

#pragma once

#include "scene.h"
#include "shape.h"

//
// history : used
// palette : used
//
// - adds 1 block in 0,0,0
// - adds 2 blocks in -Z limit
// - removes 1 block in -Z limit
// - adds 1 block in +Z limit
void test_shape_addblock_1(void) {
    SHAPE_COLOR_INDEX_INT_T COLOR1 = 0;
    SHAPE_COLOR_INDEX_INT_T COLOR2 = 0;
    SHAPE_COLOR_INDEX_INT_T COLOR3 = 0;
    bool ok = false;
    Block *b = NULL;

    Scene *sc = scene_new();
    TEST_ASSERT(sc != NULL);

    // create a mutable shape having an octree
    Shape *sh = shape_make_with_octree(1, 1, 1,
                                       false, // lighting
                                       true, // isMutable
                                       true); // isResizable
    TEST_ASSERT(sh != NULL);

    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        const bool sharedColors = true;
        shape_set_palette(sh, color_palette_new(atlas, sharedColors));
    }

    ColorPalette *palette = shape_get_palette(sh);
    TEST_ASSERT(palette != NULL);

    { // add color 1
        RGBAColor color = {.r =  1, .g =  1, .b =  1, .a =  1};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx);
        TEST_ASSERT(ok);
        COLOR1 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 2
        RGBAColor color = {.r =  2, .g =  2, .b =  2, .a =  2};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx);
        TEST_ASSERT(ok);
        COLOR2 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 3
        RGBAColor color = {.r =  3, .g =  3, .b =  3, .a =  3};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx);
        TEST_ASSERT(ok);
        COLOR3 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    // add block 0
    ok = shape_add_block_from_lua(sh, sc, COLOR1, 0, 0, 0);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, 0, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR1);

    // add block 1
    ok = shape_add_block_from_lua(sh, sc, COLOR1, 0, 0, -1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -1, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR1);

    // add block 2
    ok = shape_add_block_from_lua(sh, sc, COLOR2, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR2);

    // remove block 2
    ok = shape_remove_block_from_lua(sh, sc, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    // add block 3
    ok = shape_add_block_from_lua(sh, sc, COLOR3, 0, 0, 1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, 1, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR3);

    // free resources
    shape_free(sh);
    scene_free(sc);
}

// same as addblock_1 but without the first block in 0,0,0
void test_shape_addblock_2(void) {
    SHAPE_COLOR_INDEX_INT_T COLOR1 = 0;
    SHAPE_COLOR_INDEX_INT_T COLOR2 = 0;
    SHAPE_COLOR_INDEX_INT_T COLOR3 = 0;
    bool ok = false;
    Block *b = NULL;

    Scene *sc = scene_new();
    TEST_ASSERT(sc != NULL);

    // create a mutable shape having an octree
    Shape *sh = shape_make_with_octree(1, 1, 1,
                                       false, // lighting
                                       true, // isMutable
                                       true); // isResizable
    TEST_ASSERT(sh != NULL);

    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        const bool sharedColors = true;
        shape_set_palette(sh, color_palette_new(atlas, sharedColors));
    }

    ColorPalette *palette = shape_get_palette(sh);
    TEST_ASSERT(palette != NULL);

    { // add color 1
        RGBAColor color = {.r =  1, .g =  1, .b =  1, .a =  1};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx);
        TEST_ASSERT(ok);
        COLOR1 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 2
        RGBAColor color = {.r =  2, .g =  2, .b =  2, .a =  2};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx);
        TEST_ASSERT(ok);
        COLOR2 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 3
        RGBAColor color = {.r =  3, .g =  3, .b =  3, .a =  3};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx);
        TEST_ASSERT(ok);
        COLOR3 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    // add block 1
    ok = shape_add_block_from_lua(sh, sc, COLOR1, 0, 0, -1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -1, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR1);

    // add block 2
    ok = shape_add_block_from_lua(sh, sc, COLOR2, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR2);

    // remove block 2
    ok = shape_remove_block_from_lua(sh, sc, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    // add block 3
    ok = shape_add_block_from_lua(sh, sc, COLOR3, 0, 0, 1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh, false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, 1, true);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR3);

    // free resources
    shape_free(sh);
    scene_free(sc);
}


// uses pending transaction WITHOUT applying it
//void test_shape_addblock_1(void) {
//    // TODO: add colors to shape's palette
//    const SHAPE_COLOR_INDEX_INT_T COLOR1 = 42;
//    const SHAPE_COLOR_INDEX_INT_T COLOR2 = 43;
//    const SHAPE_COLOR_INDEX_INT_T COLOR3 = 44;
//    bool ok = false;
//    Block *b = NULL;
//
//    Scene *sc = scene_new();
//    TEST_CHECK(sc != NULL);
//
//    Shape *sh = shape_make();
//    TEST_CHECK(sh != NULL);
//
//    // add block 1
//    ok = shape_add_block_from_lua(sh, sc, COLOR1, 0, 0, -1);
//    TEST_CHECK(ok);
//    b = shape_get_block(sh, 0, 0, -1, true);
//    TEST_CHECK(b != NULL);
//    TEST_CHECK(b->colorIndex == COLOR1);
//
//    // add block 2
//    ok = shape_add_block_from_lua(sh, sc, COLOR2, 0, 0, -2);
//    TEST_CHECK(ok);
//    b = shape_get_block(sh, 0, 0, -2, true);
//    TEST_CHECK(b != NULL);
//    TEST_CHECK(b->colorIndex == COLOR2);
//
//    // remove block 2
//    ok = shape_remove_block_from_lua(sh, sc, 0, 0, -2);
//    TEST_CHECK(ok);
//    b = shape_get_block(sh, 0, 0, -2, true);
//    TEST_CHECK(b != NULL);
//    TEST_CHECK(b->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);
//
//    // add block 3
//    ok = shape_add_block_from_lua(sh, sc, COLOR3, 0, 0, 1);
//    TEST_CHECK(ok);
//    b = shape_get_block(sh, 0, 0, 1, true);
//    TEST_CHECK(b != NULL);
//    TEST_CHECK(b->colorIndex == COLOR3);
//
//    // free resources
//    shape_free(sh);
//    scene_free(sc);
//}
