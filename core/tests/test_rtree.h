// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_rtree.h
//  Created by Xavier Legland on November 14, 2022.
// -------------------------------------------------------------

#pragma once

#include "rtree.h"
#include "transform.h"

// functions that are NOT tested:
// rtree_get_height
// rtree_get_root
// rtree_node_get_children_count
// rtree_node_get_children_iterator
// rtree_node_get_leaf_ptr
// rtree_node_is_leaf
// rtree_node_set_collision_masks
// rtree_recurse
// rtree_insert
// rtree_remove
// rtree_find_and_remove
// rtree_refresh_collision_masks
// rtree_query_overlap_func
// rtree_query_overlap_box
// rtree_query_cast_all_func
// rtree_query_cast_all_ray
// rtree_query_cast_all_box_step_func
// rtree_query_cast_all_box
// rtree_utils_broadphase_steps
// debug_rtree_get_insert_calls
// debug_rtree_get_split_calls
// debug_rtree_get_remove_calls
// debug_rtree_get_condense_calls
// debug_rtree_reset_calls
// debug_rtree_integrity_check
// debug_rtree_reset_all_aabb

void test_rtree_new(void) {
    Rtree *r = rtree_new(2, 4);
    RtreeNode *root = rtree_get_root(r);

    TEST_CHECK(rtree_get_height(r) == 1);
    TEST_CHECK(root != NULL);
    TEST_CHECK(rtree_node_get_groups(root) == PHYSICS_GROUP_ALL_SYSTEM);
    TEST_CHECK(rtree_node_get_collides_with(root) == PHYSICS_GROUP_ALL_SYSTEM);

    rtree_free(r);
}

void test_rtree_node_get_aabb(void) {
    Rtree *r = rtree_new(2, 4);
    Box *b = box_new_2(0.0f, 0.0f, 0.0f, 1.0f, 2.0f, 3.0f);
    uint16_t groups = 4, collidesWith = 3;
    Transform *t = transform_new(HierarchyTransform);
    rtree_create_and_insert(r, b, groups, collidesWith, (void *)t);
    RtreeNode *root = rtree_get_root(r);
    const float3 aabbMin = {0.0f, 0.0f, 0.0f};
    const float3 aabbMax = {1.0f, 2.0f, 3.0f};

    TEST_CHECK(float3_isEqual(&(rtree_node_get_aabb(root)->min), &aabbMin, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&(rtree_node_get_aabb(root)->max), &aabbMax, EPSILON_ZERO));

    rtree_free(r);
    transform_release(t);
}

void test_rtree_node_get_groups(void) {
    Rtree *r = rtree_new(2, 4);
    RtreeNode *root = rtree_get_root(r);

    TEST_CHECK(rtree_get_height(r) == 1);
    TEST_CHECK(root != NULL);
    TEST_CHECK(rtree_node_get_groups(root) == PHYSICS_GROUP_ALL_SYSTEM);

    rtree_free(r);
}

void test_rtree_node_get_collides_with(void) {
    Rtree *r = rtree_new(2, 4);
    RtreeNode *root = rtree_get_root(r);

    TEST_CHECK(rtree_get_height(r) == 1);
    TEST_CHECK(root != NULL);
    TEST_CHECK(rtree_node_get_collides_with(root) == PHYSICS_GROUP_ALL_SYSTEM);

    rtree_free(r);
}

void test_rtree_create_and_insert(void) {
    Rtree *r = rtree_new(2, 4);
    Box *b = box_new_2(0.0f, 0.0f, 0.0f, 1.0f, 2.0f, 3.0f);
    uint16_t groups = 4, collidesWith = 3;
    Transform *t = transform_new(HierarchyTransform);
    rtree_create_and_insert(r, b, groups, collidesWith, (void *)t);
    RtreeNode *root = rtree_get_root(r);
    const float3 aabbMin = {0.0f, 0.0f, 0.0f};
    const float3 aabbMax = {1.0f, 2.0f, 3.0f};

    TEST_CHECK(float3_isEqual(&(rtree_node_get_aabb(root)->min), &aabbMin, EPSILON_ZERO));
    TEST_CHECK(float3_isEqual(&(rtree_node_get_aabb(root)->max), &aabbMax, EPSILON_ZERO));

    rtree_free(r);
    transform_release(t);
}
