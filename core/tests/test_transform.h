//
//  test_transform.h
//  engine-unit-tests
//
//  Created by Xavier Legland on 10/05/2022.
//

#pragma once

#include "scene.h"
#include "transform.h"

void test_transform_rotation_position(void) {
    Transform* t = transform_make_default();
    TEST_ASSERT(t != NULL);

    {
        Quaternion* q = quaternion_new(1.0f, 2.0f, 3.0f, 0.5f, false);
        transform_set_rotation(t, q);
        Quaternion* r = transform_get_rotation(t);
        TEST_CHECK(quaternion_is_equal(r, q, EPSILON_ZERO));
        TEST_CHECK(r->normalized == q->normalized);

        quaternion_free(q);
    }

    {
        transform_set_position(t, 1.0f, 2.0f, 3.0f);
        const float3* pos1 = transform_get_position(t);
        const float3 expected1 = { 1.0f, 2.0f, 3.0f };
        TEST_CHECK(float3_isEqual(pos1, &expected1, EPSILON_ZERO));

        float3* pos2 = float3_new(4.0f, 5.0f, 6.0f);
        const float3 expected2 = { 4.0f, 5.0f, 6.0f };
        transform_set_position_vec(t, pos2);
        TEST_CHECK(float3_isEqual(pos1, &expected2, EPSILON_ZERO));

        float3_free(pos2);
    }

    {
        Transform* p = transform_make_default();
        Transform* c = transform_make_default();
        TEST_ASSERT(p != NULL && c != NULL);

        transform_set_parent(c, p, true);

        transform_set_position(p, 2.0f, 4.0f, 6.0f);
        transform_set_local_position(c, -1.0f, -2.0f, -3.0f);

        const float3* result = transform_get_position(c);
        const float3 expected = { 1.0f, 2.0f, 3.0f };
        TEST_CHECK(float3_isEqual(result, &expected, EPSILON_ZERO));

        transform_release(p);
        transform_release(c);
    }
    transform_release(t);
}

void test_transform_child(void) {
    Transform* t = transform_make_default();
    TEST_ASSERT(t != NULL);

    {
        Transform* child = transform_make_default();
        TEST_ASSERT(child != NULL);
        transform_set_parent(child, t, true);
        TEST_CHECK(transform_get_parent(child) == t);

        transform_set_position(t, 2.0f, 4.0f, 6.0f);
        transform_set_local_position(child, 1.0f, 2.0f, 3.0f);
        const float3* pos1 = transform_get_local_position(child);
        const float3 expected1 = { 1.0f, 2.0f, 3.0f };
        TEST_CHECK(float3_isEqual(pos1, &expected1, EPSILON_ZERO));

        const float3* pos2 = transform_get_position(child);
        const float3 expected2 = { 3.0f, 6.0f, 9.0f };
        TEST_CHECK(float3_isEqual(pos2, &expected2, EPSILON_ZERO));

        Quaternion* rot1 = quaternion_new(PI_F * 0.5f, 0.0f, 0.0f, 0.0f, false);
        transform_set_rotation(t, rot1);
        transform_set_local_rotation(child, rot1);
        const Quaternion* rot2 = transform_get_rotation(child);
        Quaternion* expected3 = quaternion_new(0.0f, 0.0f, 0.0f, -PI_F, false);
        TEST_CHECK(quaternion_is_equal(rot2, expected3, EPSILON_QUATERNION_ERROR));
        quaternion_free(rot1);
        quaternion_free(expected3);

        transform_set_rotation_euler(t, 0.0f, PI_F * 0.25f, 0.0f);
        transform_set_local_rotation_euler(child, 0.0f, PI_F * 0.125f, 0.0f);
        float3* rot4 = float3_new_zero();
        transform_get_rotation_euler(child, rot4);
        const float3 expected4 = { 0.0f, PI_F * 0.375f, 0.0f };
        TEST_CHECK(float3_isEqual(rot4, &expected4, EPSILON_QUATERNION_ERROR));

        float3_free(rot4);
        transform_release(child);
    }

    {
        Transform* child = transform_make_default();
        TEST_ASSERT(child != NULL);
        transform_set_position(child, 10.0f, 20.0f, 30.0f);
        transform_set_parent(child, t, true);
        const float3* pos = transform_get_position(child);
        const float3 expected = { 10.0f, 20.0f, 30.0f };
        TEST_CHECK(float3_isEqual(pos, &expected, EPSILON_ZERO));

        transform_release(child);
    }

    transform_release(t);
}

void test_transform_children(void) {
    Transform* p = transform_make_default();
    Transform* c1 = transform_make_default();
    Transform* c2 = transform_make_default();
    TEST_ASSERT(p != NULL && c1 != NULL && c2 != NULL);
    TEST_CHECK(transform_get_children_count(p) == (size_t)0);
    TEST_CHECK(transform_is_parented(c1) == false);

    transform_set_parent(c1, p, true);
    TEST_CHECK(transform_get_children_count(p) == (size_t)1);
    TEST_CHECK(transform_get_children_count(c1) == (size_t)0);
    TEST_CHECK(transform_is_parented(c1));

    transform_set_parent(c2, p, false);
    TEST_CHECK(transform_get_children_count(p) == (size_t)2);
    TEST_CHECK(transform_get_children_count(c2) == (size_t)0);

    DoublyLinkedListNode* children_it = transform_get_children_iterator(p);
    bool c1_present = ((Transform*)doubly_linked_list_node_pointer(children_it)) == c1;
    bool c2_present = ((Transform*)doubly_linked_list_node_pointer(children_it)) == c2;
    bool wrong_parent = false;
    DoublyLinkedListNode* next = children_it;
    Transform* ptr = NULL;
    while ((next = doubly_linked_list_node_next(next)) != NULL) {
        ptr = (Transform*)doubly_linked_list_node_pointer(next);
        if (ptr == c1) {
            c1_present = true;
        }
        if (ptr == c2) {
            c2_present = true;
        }
        if (transform_get_parent(ptr) != p) {
            wrong_parent = true;
        }
    }

    TEST_CHECK(c1_present);
    TEST_CHECK(c2_present);
    TEST_CHECK(wrong_parent == false);

    transform_remove_parent(c1, false);
    TEST_CHECK(transform_get_children_count(p) == (size_t)1);
    TEST_CHECK(transform_is_parented(c1) == false);
    transform_remove_parent(c2, false);
    TEST_CHECK(transform_get_children_count(p) == (size_t)0);

    transform_release(c1);
    transform_release(c2);
}

void test_transform_retain(void) {
    Transform* t = transform_make_default();
    Transform* c = transform_make_default();
    Transform* p = transform_make_default();
    TEST_ASSERT(t != NULL && c != NULL && p != NULL);

    TEST_CHECK(transform_retain_count(t) == (uint16_t)1);

    bool result = transform_retain(t);
    TEST_CHECK(transform_retain_count(t) == (uint16_t)2);
    result = transform_release(t);
    TEST_CHECK(result == false);
    TEST_CHECK(transform_retain_count(t) == (uint16_t)1);

    transform_set_parent(c, t, false);
    TEST_CHECK(transform_retain_count(t) == (uint16_t)1);
    TEST_CHECK(transform_retain_count(c) == (uint16_t)2);

    transform_set_parent(t, p, false);
    TEST_CHECK(transform_retain_count(t) == (uint16_t)2);
    TEST_CHECK(transform_retain_count(p) == (uint16_t)1);

    transform_remove_parent(t, false);
    TEST_CHECK(transform_retain_count(t) == (uint16_t)1);
    TEST_CHECK(transform_retain_count(c) == (uint16_t)2);
    TEST_CHECK(transform_retain_count(p) == (uint16_t)1);

    transform_release(t);
    TEST_CHECK(transform_retain_count(p) == (uint16_t)1);
    TEST_CHECK(transform_retain_count(c) == (uint16_t)1);

    transform_release(c);
    transform_release(p);
}

void test_transform_flush(void) {
    Transform* t = transform_make_default();
    Transform* c = transform_make_default();
    Transform* p = transform_make_default();
    transform_set_parent(t, p, false);
    transform_set_parent(c, t, false);
    TEST_CHECK(transform_is_parented(t));
    TEST_CHECK(transform_get_children_count(t) == (size_t)1);

    transform_set_rotation_euler(t, PI_F * 0.5f, 0.0f, 0.0f);
    transform_set_local_rotation_euler(t, 0.0f, PI_F * 0.25f, 0.0f);
    transform_set_position(t, 8.0f, 9.0f, 10.f);
    transform_set_local_position(t, 0.1f, 0.2f, 0.3f);
    transform_set_local_scale(t, 5.0f, 6.0f, 7.0f);

    const float3 expected_scale = { 5.0f, 6.0f, 7.0f };
    TEST_CHECK(float3_isEqual(transform_get_local_scale(t), &expected_scale, EPSILON_ZERO));

    const float3 expected_rot = { 0.0f, PI_F * 0.25f, 0.0f };
    float3* rot = float3_new_zero();
    transform_get_rotation_euler(t, rot);
    TEST_CHECK(float3_isEqual(rot, &expected_rot, EPSILON_ZERO_RAD));

    const float3 expected_local_rot = { 0.0f, PI_F * 0.25f, 0.0f };
    float3* local_rot = float3_new_zero();
    transform_get_local_rotation_euler(t, local_rot);
    TEST_CHECK(float3_isEqual(local_rot, &expected_local_rot, EPSILON_ZERO_RAD));

    const float3 expected_pos = { 0.1f, 0.2f, 0.3f };
    TEST_CHECK(float3_isEqual(transform_get_position(t), &expected_pos, EPSILON_ZERO));
    const float3 expected_local_pos = { 0.1f, 0.2f, 0.3f };
    TEST_CHECK(float3_isEqual(transform_get_local_position(t), &expected_local_pos, EPSILON_ZERO));

    transform_flush(t);

    TEST_CHECK(float3_isEqual(transform_get_local_scale(t), &float3_one, EPSILON_ZERO));
    const Quaternion rot_zero = { 0.0f, 0.0f, 0.0f, 1.0f, false };
    TEST_CHECK(quaternion_is_equal(transform_get_rotation(t), &rot_zero, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(quaternion_is_equal(transform_get_local_rotation(t), &rot_zero, EPSILON_QUATERNION_ERROR));
    TEST_CHECK(float3_isZero(transform_get_position(t), EPSILON_ZERO));
    TEST_CHECK(float3_isZero(transform_get_local_position(t), EPSILON_ZERO));
    TEST_CHECK(transform_is_parented(t) == false);
    TEST_CHECK(transform_get_children_count(t) == (size_t)0);
    TEST_CHECK(transform_is_any_dirty(t) == false);

    float3_free(rot);
    float3_free(local_rot);

    transform_release(t);
    transform_release(c);
    transform_release(p);
}
