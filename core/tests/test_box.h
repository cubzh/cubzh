// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_box.h
//  Created by Nino PLANE on October 25, 2022.
// -------------------------------------------------------------

#pragma once

#include "box.h"
#include "float3.h"
#include "int3.h"
#include "matrix4x4.h"

//////// Function that are not tested :
// --- box_free()
// --- box_swept()
// --- box_to_aabox()
////////


// Create a new box and check if the min and max are set at a float3_zero
void test_box_new(void) {
    Box* a = box_new();

    float3 limitCheck = {0.0f, 0.0f, 0.0f};
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_free(a);
}

// Create a new box and check if the min and max are set at the values we wanted
void test_box_new_2(void) {
    Box* a = box_new_2(0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f);

    float3 limitCheck = {0.0f, 0.0f, 0.0f};
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == false);

    float3_set(&limitCheck, 1.0f, 1.0f, 1.0f);
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_free(a);
}

// Create a box with set min and max then copy them into a new box. Then we check the values in the new box
void test_box_new_copy(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new_copy(a);

    float3 limitCheck = {3.0f, 5.0f, 2.0f};
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == false);

    float3_set(&limitCheck, 13.0f, 15.0f, 12.0f);
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == true);

    TEST_CHECK(float3_isEqual(&a->min, &b->min, EPSILON_0_0001_F));
    TEST_CHECK(float3_isEqual(&a->max, &b->max, EPSILON_0_0001_F));

    box_free(a);
    box_free(b);
}

// Create a box with set min and max and set a new center for the box in a float3.
// We now set the new center of the box and check if the values are corrects.
void test_box_set_bottom_center_position(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    float3 setcenter = {10.0f, 10.0f, 10.0f};

    box_set_bottom_center_position(a, &setcenter);

    float3 limitCheck = {5.0f, 10.0f, 5.0f};
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == false);

    float3_set(&limitCheck, 15.0f, 20.0f, 15.0f);
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_free(a);
}

// Create 2 boxes with differents values and check both of their center 
void test_box_get_center(void) {
    Box* a = box_new_2(0.0f, 0.0f, 0.0f, 10.0f, 10.0f, 10.0f);
    Box* b = box_new_2(8.0f, 15.0f, 1.0f, 16.0f, 35.0f, 2.0f);
    float3 getcenter = {0.0f, 0.0f, 0.0f};
    float3 centerCheck = {5.0f, 5.0f, 5.0f};

    box_get_center(a, &getcenter);
    TEST_CHECK(float3_isEqual(&getcenter, &centerCheck, EPSILON_0_0001_F) == true);
    box_get_center(b, &getcenter);
    float3_set(&centerCheck, 12.0f, 25.0f, 1.5f);
    TEST_CHECK(float3_isEqual(&getcenter, &centerCheck, EPSILON_0_0001_F) == true);

    box_free(a);
    box_free(b);
}

// Create 2 boxes with differents values. We then copy one of the box into the other and check if the value are correctly copied
void test_box_copy(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new_2(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
    float3 limitCheck = {3.0f, 5.0f, 2.0f};

    box_copy(b, a);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == false);
    float3_set(&limitCheck, 13.0f, 15.0f, 12.0f);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_free(a);
    box_free(b);
}

// Create 3 differents boxes and check if they are colliding with each others
void test_box_collide(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new_2(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
    Box* c = box_new_2(2.0f, 4.0f, 1.0f, 14.0f, 16.0f, 13.0f);

    TEST_CHECK(box_collide(a, b) == false);
    TEST_CHECK(box_collide(c, b) == false);
    TEST_CHECK(box_collide(a, c) == true);

    TEST_CHECK(box_collide_epsilon(a, b, EPSILON_COLLISION) == false);
    TEST_CHECK(box_collide_epsilon(c, b, EPSILON_COLLISION) == false);
    TEST_CHECK(box_collide_epsilon(a, c, EPSILON_COLLISION) == true);

    box_free(a);
    box_free(b);
    box_free(c);
}

// Create a box and a point with set coords then set severals times a new point to check if he is in the box
void test_box_contains(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    float3 pointCheck = {0.0f, 0.0f, 0.0f};

    TEST_CHECK(box_contains(a, &pointCheck) == false);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == false);
    float3_set(&pointCheck, 8.0f, 10.0f, 7.0f);
    TEST_CHECK(box_contains(a, &pointCheck) == true);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == true);
    float3_set(&pointCheck, 3.0f, 5.0f, 2.0f);
    TEST_CHECK(box_contains(a, &pointCheck) == true);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == true);
    float3_set(&pointCheck, 13.0f, 15.0f, 12.0f);
    TEST_CHECK(box_contains(a, &pointCheck) == true);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == true);
    float3_set(&pointCheck, 2.9f, 4.9f, 1.9f);
    TEST_CHECK(box_contains(a, &pointCheck) == false);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == false);
    float3_set(&pointCheck, 13.1f, 15.1f, 12.1f);
    TEST_CHECK(box_contains(a, &pointCheck) == false);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == false);
    float3_set(&pointCheck, 3.1f, 5.1f, 2.1f);
    TEST_CHECK(box_contains(a, &pointCheck) == true);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == true);
    float3_set(&pointCheck, 12.9f, 14.9f, 11.9f);
    TEST_CHECK(box_contains(a, &pointCheck) == true);
    TEST_CHECK(box_contains_epsilon(a, &pointCheck, EPSILON_COLLISION) == true);

    box_free(a);
}

// Create a box and a float3 with set values then create a broadphase box with it. Check the values of the broadphase box after creating it
void test_box_set_broadphase_box(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new();
    float3 addToBpBox = {5.0f, 5.0f, 5.0f};
    float3 limitCheck = {3.0f, 5.0f, 2.0f};

    box_set_broadphase_box(a, &addToBpBox, b);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == false);
    float3_set(&limitCheck, 18.0f, 20.0f, 17.0f);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == true);

    float3_set(&addToBpBox, -1.0f, -3.0f, -2.0f);
    box_set_broadphase_box(a, &addToBpBox, b);
    float3_set(&limitCheck, 2.0f, 2.0f, 0.0f);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == false);
    float3_set(&limitCheck, 13.0f, 15.0f, 12.0f);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_free(a);
    box_free(b);
}

// Create 2 boxes and check the sizes of both of them.
void test_box_get_size(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new();
    float3 boxSizeFloat = {0.0f, 0.0f, 0.0f};
    float3 boxSizeFloatCheck = {10.0f, 10.0f, 10.0f};

    box_get_size_float(a, &boxSizeFloat);
    TEST_CHECK(float3_isEqual(&boxSizeFloat, &boxSizeFloatCheck, EPSILON_0_0001_F) == true);
    box_get_size_float(b, &boxSizeFloat);
    float3_set(&boxSizeFloatCheck, 0.0f, 0.0f, 0.0f);
    TEST_CHECK(float3_isEqual(&boxSizeFloat, &boxSizeFloatCheck, EPSILON_0_0001_F) == true);

    int3 boxSizeInt = {0, 0, 0};
    int3 boxSizeIntCheck = {10, 10, 10};
    box_get_size_int(a, &boxSizeInt);
    TEST_CHECK(boxSizeInt.x == boxSizeIntCheck.x);
    TEST_CHECK(boxSizeInt.y == boxSizeIntCheck.y);
    TEST_CHECK(boxSizeInt.z == boxSizeIntCheck.z);
    box_get_size_int(b, &boxSizeInt);
    int3_set(&boxSizeIntCheck, 0, 0, 0);
    TEST_CHECK(boxSizeInt.x == boxSizeIntCheck.x);
    TEST_CHECK(boxSizeInt.y == boxSizeIntCheck.y);
    TEST_CHECK(boxSizeInt.z == boxSizeIntCheck.z);

    box_free(a);
    box_free(b);
}

// Create 3 boxes and check if they are empty are not, if their min and max are equal
void test_box_is_empty(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new_2(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
    Box* c = box_new_2(-3.0f, -5.0f, -2.0f, -3.0f, -5.0f, -2.0f);

    TEST_CHECK(box_is_empty(a) == false);
    TEST_CHECK(box_is_empty(b) == true);
    TEST_CHECK(box_is_empty(c) == true);

    box_free(a);
    box_free(b);
    box_free(c);
}

// Create 2 boxes that are not square and squarify them with the differents options : NoSquarify, MinSquarify, MaxSquarify
void test_box_squarify(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 8.0f, 7.0f, 10.0f);
    Box* b = box_new_2(3.0f, 5.0f, 2.0f, 8.0f, 7.0f, 10.0f);
    float3 limitCheck = {3.0f, 5.0f, 2.0f};

    box_squarify(a, NoSquarify);
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == false);
    float3_set(&limitCheck, 8.0f, 7.0f, 10.0f);
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_squarify(a, MinSquarify);
    float3_set(&limitCheck, 3.0f, 5.0f, 3.5f);
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == false);
    float3_set(&limitCheck, 8.0f, 7.0f, 8.5f);
    TEST_CHECK(float3_isEqual(&a->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&a->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_squarify(b, MaxSquarify);
    float3_set(&limitCheck, 1.5f, 5.0f, 2.0f);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == false);
    float3_set(&limitCheck, 9.5f, 7.0f, 10.0f);
    TEST_CHECK(float3_isEqual(&b->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&b->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_free(a);
}

// Create 2 boxes and merge them together to get the min of the a->min and b->min then the max of a->max and b->max
void test_box_op_merge(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new_2(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
    Box* result = box_new();
    float3 limitCheck = {0.0f, 0.0f, 0.0f};

    box_op_merge(a, b, result);
    TEST_CHECK(float3_isEqual(&result->min, &limitCheck, EPSILON_0_0001_F) == true);
    TEST_CHECK(float3_isEqual(&result->max, &limitCheck, EPSILON_0_0001_F) == false);
    float3_set(&limitCheck, 13.0f, 15.0f, 12.0f);
    TEST_CHECK(float3_isEqual(&result->min, &limitCheck, EPSILON_0_0001_F) == false);
    TEST_CHECK(float3_isEqual(&result->max, &limitCheck, EPSILON_0_0001_F) == true);

    box_free(a);
    box_free(b);
    box_free(result);
}

// Create 3 boxes and check each of their volumes 
void test_box_get_volume(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new();
    Box* c = box_new_2(0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f);

    float result = box_get_volume(a);
    TEST_CHECK(result == 1000.0f);
    result = box_get_volume(b);
    TEST_CHECK(result == 0.0f);
    result = box_get_volume(c);
    TEST_CHECK(result == 1.0f);

    box_free(a);
    box_free(b);
    box_free(c);
}

// Create a box, and 3 float3, one for the translation, one for the offset and one for the scale with set values. Then create the aabox of the original box with the 3 float3. Check the values of this new aabox 
void test_box_to_aabox_no_rot(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new();
    float3 BTranslation = {5.0f, 0.0f, 5.0f};
    float3 BOffset = {0.0f, 0.0f, 0.0f};
    float3 BScale = {1.5f, 1.5f, 1.5f};

    box_to_aabox_no_rot(a, b, &BTranslation, &BOffset, &BScale, false);
    TEST_CHECK(b->min.x == 9.5f);
    TEST_CHECK(b->min.y == 7.5f);
    TEST_CHECK(b->min.z == 8.0f);
    TEST_CHECK(b->max.x == 24.5f);
    TEST_CHECK(b->max.y == 22.5f);
    TEST_CHECK(b->max.z == 23.0f);

    Box* c = box_new_2(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);
    box_to_aabox_no_rot(c, b, &BTranslation, &BOffset, &BScale, false);
    TEST_CHECK(b->min.x == 5.0f);
    TEST_CHECK(b->min.y == 0.0f);
    TEST_CHECK(b->min.z == 5.0f);
    TEST_CHECK(b->max.x == 5.0f);
    TEST_CHECK(b->max.y == 0.0f);
    TEST_CHECK(b->max.z == 5.0f);

    box_free(a);
    box_free(b);
    box_free(c);
}

// Create a box, an offset and a matrix with set values then create the aabox of the original box. Check the values of the new aabox
void test_box_to_aabox2(void) {
    Box* a = box_new_2(3.0f, 5.0f, 2.0f, 13.0f, 15.0f, 12.0f);
    Box* b = box_new();
    float3 BOffset = {1.0f, 1.0f, 1.0f};
    Matrix4x4* BMatrix = matrix4x4_new(1.0f, 1.0f, 1.0f, 1.0f, 2.0f, 2.0f, 2.0f, 2.0f, 3.0f, 3.0f, 3.0f, 3.0f, 4.0f, 4.0f, 4.0f, 4.0f);

    box_to_aabox2(a, b, BMatrix, &BOffset, false);
    TEST_CHECK(b->min.x == 14.0f);
    TEST_CHECK(b->min.y == 28.0f);
    TEST_CHECK(b->min.z == 42.0f);
    TEST_CHECK(b->max.x == 44.0f);
    TEST_CHECK(b->max.y == 88.0f);
    TEST_CHECK(b->max.z == 132.0f);

    float3_set(&BOffset, 2.0f, 2.0f, 2.0f);
    box_to_aabox2(a, b, BMatrix, &BOffset, false);
    TEST_CHECK(b->min.x == 17.0f);
    TEST_CHECK(b->min.y == 34.0f);
    TEST_CHECK(b->min.z == 51.0f);
    TEST_CHECK(b->max.x == 47.0f);
    TEST_CHECK(b->max.y == 94.0f);
    TEST_CHECK(b->max.z == 141.0f);

    box_free(a);
    box_free(b);
    matrix4x4_free(BMatrix);
}
