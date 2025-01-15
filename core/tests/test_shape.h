//
//  test_shape.h
//  engine-unit-tests
//
//  Created by Gaetan de Villele on 09/09/2022.
//

#pragma once

#include "acutest.h"

#include "scene.h"
#include "shape.h"
#include "transform.h"

// functions that are NOT tested:
// shape_add_buffer
// shape_retain_count
// shape_free
// shape_is_resizable
// shape_flush
// shape_set_palette
// shape_get_block
// shape_get_block_immediate
// shape_add_block_as_transaction
// shape_remove_block_as_transaction
// shape_paint_block_as_transaction
// shape_apply_current_transaction
// shape_add_block
// shape_paint_block
// shape_get_chunk_and_position_within
// shape_get_max_fixed_size
// shape_aabox_model_to_world
// shape_get_local_aabb
// shape_get_world_aabb
// shape_compute_size_and_origin
// shape_reset_box
// shape_expand_box
// shape_make_space_for_block
// shape_make_space
// shape_refresh_vertices
// shape_refresh_all_vertices
// shape_get_first_vertex_buffer
// shape_new_chunk_iterator
// shape_get_nb_chunks
// shape_get_nb_blocks
// shape_get_octree
// shape_log_vertex_buffers
// shape_set_model_locked
// shape_is_model_locked
// shape_set_pivot
// shape_get_pivot
// shape_reset_pivot_to_center
// shape_block_to_local
// shape_block_to_world
// shape_local_to_block
// shape_world_to_block
// shape_block_lua_to_internal
// shape_block_internal_to_lua
// shape_block_lua_to_internal_float
// shape_block_internal_to_lua_float
// shape_set_position
// shape_set_local_position
// shape_get_position
// shape_get_local_position
// shape_get_model_origin
// shape_set_rotation
// shape_set_rotation_euler
// shape_set_local_rotation
// shape_set_local_rotation_euler
// shape_get_rotation
// shape_get_rotation_euler
// shape_get_local_rotation
// shape_get_local_rotation_euler
// shape_set_local_scale
// shape_get_local_scale
// shape_get_lossy_scale
// shape_get_model_matrix
// shape_set_parent
// shape_remove_parent
// shape_get_root_transform
// shape_get_pivot_transform
// shape_move_children
// shape_count_shape_descendants
// shape_get_transform_children_iterator
// shape_get_rigidbody
// shape_get_collision_groups
// shape_ensure_rigidbody
// shape_get_physics_enabled
// shape_set_physics_enabled
// shape_fit_collider_to_bounding_box
// shape_get_local_collider
// shape_compute_world_collider
// shape_set_physics_simulation_mode
// shape_set_physics_properties
// shape_box_cast
// shape_ray_cast
// shape_point_overlap
// shape_box_overlap
// shape_is_hidden
// shape_set_draw_mode
// shape_get_draw_mode
// shape_set_shadow_decal
// shape_has_shadow_decal
// shape_set_unlit
// shape_is_unlit
// shape_set_layers
// shape_get_layers
// shape_debug_points_of_interest
// shape_get_poi_iterator
// shape_get_point_of_interest
// shape_set_point_of_interest
// shape_get_point_rotation_iterator
// shape_set_point_rotation
// shape_get_point_rotation
// shape_remove_point
// shape_clear_baked_lighting
// shape_compute_baked_lighting
// shape_uses_baked_lighting
// shape_uses_baked_lighting
// shape_create_lighting_data_blob
// shape_set_lighting_data_from_blob
// shape_get_light_without_checking
// shape_set_light
// shape_get_light_or_default
// shape_compute_baked_lighting_removed_block
// shape_compute_baked_lighting_added_block
// shape_compute_baked_lighting_replaced_block
// shape_is_lua_mutable
// shape_set_lua_mutable
// shape_history_setEnabled
// shape_history_getEnabled
// shape_history_setKeepTransactionPending
// shape_history_getKeepTransactionPending
// shape_history_canUndo
// shape_history_canRedo
// shape_history_undo
// shape_history_redo
// shape_enableAnimations
// shape_disableAnimations
// shape_getIgnoreAnimations

// check default values
void test_shape_make(void) {
    Shape *s = shape_make();
    int3 box_size = {1, 1, 1};

    TEST_CHECK(shape_get_palette((const Shape *)s) == NULL);
    shape_get_bounding_box_size(s, &box_size);
    TEST_CHECK(box_size.x == 0);
    TEST_CHECK(box_size.y == 0);
    TEST_CHECK(box_size.z == 0);
    TEST_CHECK(shape_get_layers((const Shape *)s) == 1);
    TEST_CHECK(shape_get_draw_mode((const Shape *)s) == SHAPE_DRAWMODE_DEFAULT);
    TEST_CHECK(shape_is_lua_mutable(s) == false);

    shape_free((Shape *const)s);
}

// check that the copy is independant from the source
void test_shape_make_copy(void) {
    Shape *src = shape_make();
    shape_set_lua_mutable(src, true);
    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        shape_set_palette(src, color_palette_new(atlas), false);
    }
    Shape *copy = shape_make_copy(src);

    TEST_CHECK(shape_is_lua_mutable(copy));

    shape_set_lua_mutable(src, false);
    TEST_CHECK(shape_is_lua_mutable(copy));

    shape_free((Shape *const)src);
    shape_free((Shape *const)copy);
}

// check that we can retain a shape
void test_shape_retain(void) {
    Shape *s = shape_make();
    // Transform *t = transform_utils_make_with_shape(s);

    bool ok = shape_retain((Shape *const)s);
    TEST_CHECK(ok);

    ok = shape_retain((Shape *const)s);
    TEST_CHECK(ok);

    shape_release((Shape *const)s);
    shape_release((Shape *const)s);
    shape_free((Shape *const)s);
}

// check that shape_release does not crash
void test_shape_release(void) {
    Shape *s = shape_make();
    // Transform *t = transform_utils_make_with_shape(s);
    shape_retain((Shape *const)s);

    shape_release((Shape *const)s);
    shape_release((Shape *const)s);
}

// check for coherent id
void test_shape_get_id(void) {
    const Shape *s = shape_make();
    const uint16_t id = shape_get_id(s);

    TEST_CHECK(id < 1000);

    shape_free((Shape *const)s);
}

// check that shape's palette atlas is the one provided
void test_shape_get_palette(void) {
    Shape *s = shape_make();
    // const SHAPE_COLOR_INDEX_INT_T idx = 5;
    // const SHAPE_COORDS_INT_T x = 1, y = 2, z = 3;
    ColorAtlas *atlas = color_atlas_new();
    TEST_ASSERT(atlas != NULL);
    shape_set_palette(s, color_palette_new(atlas), false);
    ColorPalette *p = shape_get_palette((const Shape *)s);

    TEST_CHECK(color_palette_get_atlas((const ColorPalette *)p) == atlas);

    shape_free((Shape *const)s);
}

// check that the block is removed (air)
void test_shape_remove_block(void) {
    Shape *s = shape_make();
    const SHAPE_COLOR_INDEX_INT_T idx = 5;
    const SHAPE_COORDS_INT_T x = 1, y = 2, z = 3;
    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        shape_set_palette(s, color_palette_new(atlas), false);
    }
    shape_add_block(s, idx, x, y, z, true);
    const bool ok = shape_remove_block(s, x, y, z);

    TEST_CHECK(ok);

    shape_apply_current_transaction(s, false);
    TEST_CHECK(block_is_solid(shape_get_block(s, x, y, z)) == false);

    shape_free((Shape *const)s);
}

// check that the box is coherent
void test_shape_get_bounding_box_size(void) {
    Shape *s = shape_make();
    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        shape_set_palette(s, color_palette_new(atlas), false);
    }
    shape_add_block(s, 1, 1, 2, 3, true);
    int3 result = {0, 0, 0};
    shape_get_bounding_box_size(s, &result);

    TEST_CHECK(result.x == 1);
    TEST_CHECK(result.y == 1);
    TEST_CHECK(result.z == 1);

    shape_free((Shape *const)s);
}

// same tests as test_shape_get_bounding_box_size
void test_shape_get_model_aabb(void) {
    Shape *s = shape_make();
    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        shape_set_palette(s, color_palette_new(atlas), false);
    }
    shape_add_block(s, 1, 1, 2, 3, true);
    int3 result = {0, 0, 0};
    const Box aabb = shape_get_model_aabb(s);
    box_get_size_int(&aabb, &result);

    TEST_CHECK(result.x == 1);
    TEST_CHECK(result.y == 1);
    TEST_CHECK(result.z == 1);

    shape_free((Shape *const)s);
}

// check that the fullname is the one we provided
void test_shape_set_fullname(void) {
    Shape *s = shape_make();
    const char *name = "shape_name";
    shape_set_fullname(s, name);

    TEST_CHECK(strcmp(shape_get_fullname(s), name) == 0);
    TEST_CHECK(shape_get_fullname(s) != name);

    shape_free((Shape *const)s);
}

// same test as test_shape_set_fullname
void test_shape_get_fullname(void) {
    Shape *s = shape_make();
    const char *name = "shape_name";
    shape_set_fullname(s, name);

    TEST_CHECK(strcmp(shape_get_fullname(s), name) == 0);

    shape_free((Shape *const)s);
}

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
    const Block *b = NULL;

    Scene *sc = scene_new(NULL);
    TEST_ASSERT(sc != NULL);

    // create a mutable shape having an octree
    Shape *sh = shape_make_2(true); // isMutable
    TEST_ASSERT(sh != NULL);

    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        shape_set_palette(sh, color_palette_new(atlas), false);
    }

    ColorPalette *palette = shape_get_palette(sh);
    TEST_ASSERT(palette != NULL);

    { // add color 1
        RGBAColor color = {.r = 1, .g = 1, .b = 1, .a = 1};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx, false);
        TEST_ASSERT(ok);
        COLOR1 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 2
        RGBAColor color = {.r = 2, .g = 2, .b = 2, .a = 2};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx, false);
        TEST_ASSERT(ok);
        COLOR2 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 3
        RGBAColor color = {.r = 3, .g = 3, .b = 3, .a = 3};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx, false);
        TEST_ASSERT(ok);
        COLOR3 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    // add block 0
    ok = shape_add_block_as_transaction(sh, sc, COLOR1, 0, 0, 0);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, 0);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR1);

    // add block 1
    ok = shape_add_block_as_transaction(sh, sc, COLOR1, 0, 0, -1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -1);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR1);

    // add block 2
    ok = shape_add_block_as_transaction(sh, sc, COLOR2, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR2);

    // remove block 2
    ok = shape_remove_block_as_transaction(sh, sc, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2);
    TEST_ASSERT(b->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    // add block 3
    ok = shape_add_block_as_transaction(sh, sc, COLOR3, 0, 0, 1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, 1);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR3);

    // free resources
    shape_free((Shape *const)sh);
    scene_free(sc);
}

// same as addblock_1 but without the first block in 0,0,0
void test_shape_addblock_2(void) {
    SHAPE_COLOR_INDEX_INT_T COLOR1 = 0;
    SHAPE_COLOR_INDEX_INT_T COLOR2 = 0;
    SHAPE_COLOR_INDEX_INT_T COLOR3 = 0;
    bool ok = false;
    const Block *b = NULL;

    Scene *sc = scene_new(NULL);
    TEST_ASSERT(sc != NULL);

    // create a mutable shape having an octree
    Shape *sh = shape_make_2(true); // isMutable
    TEST_ASSERT(sh != NULL);

    {
        ColorAtlas *atlas = color_atlas_new();
        TEST_ASSERT(atlas != NULL);
        shape_set_palette(sh, color_palette_new(atlas), false);
    }

    ColorPalette *palette = shape_get_palette(sh);
    TEST_ASSERT(palette != NULL);

    { // add color 1
        RGBAColor color = {.r = 1, .g = 1, .b = 1, .a = 1};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx, false);
        TEST_ASSERT(ok);
        COLOR1 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 2
        RGBAColor color = {.r = 2, .g = 2, .b = 2, .a = 2};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx, false);
        TEST_ASSERT(ok);
        COLOR2 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    { // add color 3
        RGBAColor color = {.r = 3, .g = 3, .b = 3, .a = 3};
        SHAPE_COLOR_INDEX_INT_T entryIdx;
        ok = color_palette_check_and_add_color(palette, color, &entryIdx, false);
        TEST_ASSERT(ok);
        COLOR3 = color_palette_entry_idx_to_ordered_idx(palette, entryIdx);
    }

    // add block 1
    ok = shape_add_block_as_transaction(sh, sc, COLOR1, 0, 0, -1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -1);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR1);

    // add block 2
    ok = shape_add_block_as_transaction(sh, sc, COLOR2, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR2);

    // remove block 2
    ok = shape_remove_block_as_transaction(sh, sc, 0, 0, -2);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, -2);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    // add block 3
    ok = shape_add_block_as_transaction(sh, sc, COLOR3, 0, 0, 1);
    TEST_ASSERT(ok);
    shape_apply_current_transaction(sh,
                                    false /* false means transaction is pushed into the history */);
    b = shape_get_block(sh, 0, 0, 1);
    TEST_ASSERT(b != NULL);
    TEST_ASSERT(b->colorIndex == COLOR3);

    // free resources
    shape_free((Shape *const)sh);
    scene_free(sc);
}

// uses pending transaction WITHOUT applying it
void test_shape_addblock_3(void) {
    // TODO: add colors to shape's palette
    const SHAPE_COLOR_INDEX_INT_T COLOR1 = 42;
    const SHAPE_COLOR_INDEX_INT_T COLOR2 = 43;
    const SHAPE_COLOR_INDEX_INT_T COLOR3 = 44;
    bool ok = false;
    const Block *b = NULL;

    Scene *sc = scene_new(NULL);
    TEST_CHECK(sc != NULL);

    Shape *sh = shape_make();
    TEST_CHECK(sh != NULL);

    // add block 1
    ok = shape_add_block_as_transaction(sh, sc, COLOR1, 0, 0, -1);
    TEST_CHECK(ok);
    b = shape_get_block(sh, 0, 0, -1);
    TEST_CHECK(b != NULL);
    TEST_CHECK(b->colorIndex == COLOR1);

    // add block 2
    ok = shape_add_block_as_transaction(sh, sc, COLOR2, 0, 0, -2);
    TEST_CHECK(ok);
    b = shape_get_block(sh, 0, 0, -2);
    TEST_CHECK(b != NULL);
    TEST_CHECK(b->colorIndex == COLOR2);

    // remove block 2
    ok = shape_remove_block_as_transaction(sh, sc, 0, 0, -2);
    TEST_CHECK(ok);
    b = shape_get_block(sh, 0, 0, -2);
    TEST_CHECK(b != NULL);
    TEST_CHECK(b->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK);

    // add block 3
    ok = shape_add_block_as_transaction(sh, sc, COLOR3, 0, 0, 1);
    TEST_CHECK(ok);
    b = shape_get_block(sh, 0, 0, 1);
    TEST_CHECK(b != NULL);
    TEST_CHECK(b->colorIndex == COLOR3);

    // free resources
    shape_free((Shape *const)sh);
    scene_free(sc);
}
