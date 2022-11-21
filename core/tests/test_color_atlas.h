// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_hash_uint32_int.h
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#pragma once

#include "color_atlas.h"
#include "color_palette.h"
#include "shape.h"


void test_color_atlas_colors_playing_with_shapes(void) {

    RGBAColor color1 = {.r = 1, .g = 1, .b = 1, .a = 1};
    RGBAColor color2 = {.r = 2, .g = 2, .b = 1, .a = 2};
    RGBAColor color3 = {.r = 3, .g = 3, .b = 1, .a = 3};
    RGBAColor color4 = {.r = 4, .g = 4, .b = 1, .a = 4};
    
    SHAPE_COLOR_INDEX_INT_T p1c1 = 0;
    SHAPE_COLOR_INDEX_INT_T p1c2 = 0;
    SHAPE_COLOR_INDEX_INT_T p1c3 = 0;
    
    SHAPE_COLOR_INDEX_INT_T p2c1 = 0;
    SHAPE_COLOR_INDEX_INT_T p2c2 = 0;
    SHAPE_COLOR_INDEX_INT_T p2c3 = 0;
    
    bool ok;
    
    Shape *s1 = shape_make_with_octree(1,
                                       1,
                                       1,
                                       false, // lighting
                                       true,  // isMutable
                                       true); // isResizable
    
    TEST_ASSERT(s1 != NULL);
    
    Shape *s2 = shape_make_with_octree(1,
                                       1,
                                       1,
                                       false, // lighting
                                       true,  // isMutable
                                       true); // isResizable
    
    TEST_ASSERT(s2 != NULL);

    
    ColorAtlas *atlas = color_atlas_new();
    TEST_ASSERT(atlas != NULL);
    const bool sharedColors = true;
    
    shape_set_palette(s1, color_palette_new(atlas, sharedColors));
    shape_set_palette(s2, color_palette_new(atlas, sharedColors));
    

    ColorPalette *p1 = shape_get_palette(s1);
    TEST_ASSERT(p1 != NULL);
    
    ColorPalette *p2 = shape_get_palette(s2);
    TEST_ASSERT(p2 != NULL);
    
    { // add color 1 in both palettes
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(p1, color1, &entryIdx);
        TEST_ASSERT(ok);
        p1c1 = color_palette_entry_idx_to_ordered_idx(p1, entryIdx);
        
        ok = color_palette_check_and_add_color(p2, color1, &entryIdx);
        TEST_ASSERT(ok);
        p2c1 = color_palette_entry_idx_to_ordered_idx(p2, entryIdx);
    }

    { // add color 2 in both palettes
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        
        ok = color_palette_check_and_add_color(p1, color2, &entryIdx);
        TEST_ASSERT(ok);
        p1c2 = color_palette_entry_idx_to_ordered_idx(p1, entryIdx);
        
        ok = color_palette_check_and_add_color(p2, color2, &entryIdx);
        TEST_ASSERT(ok);
        p2c2 = color_palette_entry_idx_to_ordered_idx(p2, entryIdx);
    }

    { // add color 3 in both palettes
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        
        ok = color_palette_check_and_add_color(p1, color3, &entryIdx);
        TEST_ASSERT(ok);
        p1c3 = color_palette_entry_idx_to_ordered_idx(p1, entryIdx);
        
        ok = color_palette_check_and_add_color(p2, color3, &entryIdx);
        TEST_ASSERT(ok);
        p2c3 = color_palette_entry_idx_to_ordered_idx(p2, entryIdx);
    }
    
//    RGBAColor *color = color_atlas_get_color(atlas, 42);
//    printf("color: %d, %d, %d", color->r, color->g, color->b);
    
    shape_add_block_with_color(s1, p1c1, 0, 0, 0, true, false, false, false);
    shape_add_block_with_color(s1, p1c2, 1, 0, 0, true, false, false, false);
    shape_add_block_with_color(s1, p1c3, 2, 0, 0, true, false, false, false);
    
    TEST_CHECK(color_atlas_get_color_count(atlas) == 3);
    
    shape_add_block_with_color(s2, p2c1, 0, 0, 0, true, false, false, false);
    shape_add_block_with_color(s2, p2c2, 1, 0, 0, true, false, false, false);
    shape_add_block_with_color(s2, p2c3, 2, 0, 0, true, false, false, false);
    
    TEST_CHECK(color_atlas_get_color_count(atlas) == 3);
    
    shape_remove_block(s1, 2, 0, 0, NULL, false, false, false);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 3);
    
    shape_remove_block(s2, 2, 0, 0, NULL, false, false, false);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 2);
    
    shape_add_block_with_color(s1, p1c3, 2, 0, 0, true, false, false, false);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 3);
    
    shape_add_block_with_color(s2, p2c3, 2, 0, 0, true, false, false, false);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 3);
    
    color_palette_set_color(p1, p1c3, color4);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 4);
    
    // -- color_palette_set_color(p1, p1c3, color4);
    
    // remove s2
    shape_release(s2);
    s2 = NULL;
    TEST_CHECK(color_atlas_get_color_count(atlas) == 3);
    
    shape_remove_block(s1, 2, 0, 0, NULL, false, false, false);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 2);
    
    shape_remove_block(s1, 1, 0, 0, NULL, false, false, false);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 1);
    
    shape_remove_block(s1, 0, 0, 0, NULL, false, false, false);
    TEST_CHECK(color_atlas_get_color_count(atlas) == 0);
    
    // TODO: test colors that aren't shared
    
    shape_release(s1);
    color_atlas_free(atlas);
}
