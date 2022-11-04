// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_utils.h
//  Created by Nino PLANE on October 10, 2022.
// -------------------------------------------------------------

#pragma once

#include "config.h"
#include "utils.h"

void test_utils_float_isEqual(void) {

    TEST_CHECK(float_isEqual(1.0f, 1.0f, 0.5f));
    TEST_CHECK(float_isEqual(10000.0f, 10000.0f, 0.5f));
    TEST_CHECK(float_isEqual(1.0f, 2.0f, 0.5f) == false);
    TEST_CHECK(float_isEqual(100000.0f, 2.0f, 0.5f) == false);
    TEST_CHECK(float_isEqual(0.0f, 0.0f, 0.5f));
    TEST_CHECK(float_isEqual(-1.0f, -1.0f, 1.0f));
    TEST_CHECK(float_isEqual(-5.0f, -10.0f, -1.0f) == false);
}

void test_utils_float_isZero(void) {
    TEST_CHECK(float_isZero(1.0f, 0.5f) == false);
    TEST_CHECK(float_isZero(0.0f, 1.0f));
    TEST_CHECK(float_isZero(-1.0f, 0.5f) == false);
}

void test_utils_is_float_to_coords_inbounds(void) {
    TEST_CHECK(utils_is_float_to_coords_inbounds(32767.0f));
    TEST_CHECK(utils_is_float_to_coords_inbounds(32768.0f) == false);
    TEST_CHECK(utils_is_float_to_coords_inbounds(0.0f));
    TEST_CHECK(utils_is_float_to_coords_inbounds(-32768.0f));
    TEST_CHECK(utils_is_float_to_coords_inbounds(-32769.0f == false));
}

void test_utils_is_float3_to_coords_inbounds(void) {
    TEST_CHECK(utils_is_float3_to_coords_inbounds(0.0f, 0.0f, 0.0f));
    TEST_CHECK(utils_is_float3_to_coords_inbounds(32767.0f, 32767.0f, 32767.0f));
    TEST_CHECK(utils_is_float3_to_coords_inbounds(-32768.0f, -32768.0f, -32768.0f));
    TEST_CHECK(utils_is_float3_to_coords_inbounds(32767.1f, 32767.1f, 32767.1f) == false);
    TEST_CHECK(utils_is_float3_to_coords_inbounds(-32768.1f, -32768.1f, -32768.1f) == false);
}

void test_utils_axes_mask(void) {

    {
        uint8_t value = 7;
        uint8_t value2 = 25;

        utils_axes_mask_set(&value, AxesMaskX, true);
        TEST_CHECK(value == 7);

        utils_axes_mask_set(&value, AxesMaskZ, false);
        TEST_CHECK(value == 7);

        utils_axes_mask_set(&value2, AxesMaskY, true);
        TEST_CHECK(value2 == 29);

        utils_axes_mask_set(&value2, AxesMaskNY, false);
        TEST_CHECK(value2 == 21);
    }

    {
        uint8_t value = 255;
        uint8_t value2 = 0;

        bool check;
        bool check2;

        check = utils_axes_mask_get(value, AxesMaskX);
        check2 = utils_axes_mask_get(value2, AxesMaskX);
        TEST_CHECK(check == true);
        TEST_CHECK(check2 == false);

        check = utils_axes_mask_get(value, AxesMaskY);
        check2 = utils_axes_mask_get(value2, AxesMaskY);
        TEST_CHECK(check == true);
        TEST_CHECK(check2 == false);

        check = utils_axes_mask_get(value, AxesMaskZ);
        check2 = utils_axes_mask_get(value2, AxesMaskZ);
        TEST_CHECK(check == true);
        TEST_CHECK(check2 == false);

        check = utils_axes_mask_get(value, AxesMaskNX);
        check2 = utils_axes_mask_get(value2, AxesMaskNX);
        TEST_CHECK(check == true);
        TEST_CHECK(check2 == false);

        check = utils_axes_mask_get(value, AxesMaskNY);
        check2 = utils_axes_mask_get(value2, AxesMaskNY);
        TEST_CHECK(check == true);
        TEST_CHECK(check2 == false);

        check = utils_axes_mask_get(value, AxesMaskNZ);
        check2 = utils_axes_mask_get(value2, AxesMaskNZ);
        TEST_CHECK(check == true);
        TEST_CHECK(check2 == false);
    }

    {
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskX) == FACE_RIGHT);
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskNX) == FACE_LEFT);
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskY) == FACE_TOP);
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskNY) == FACE_DOWN);
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskZ) == FACE_FRONT);
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskNZ) == FACE_BACK);
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskAll) == FACE_NONE);
        TEST_CHECK(utils_axes_mask_value_to_face(AxesMaskNone) == FACE_NONE);
        TEST_CHECK(utils_axes_mask_value_to_face(200) == FACE_NONE);
        TEST_CHECK((utils_axes_mask_value_to_face(AxesMaskX) == FACE_NONE) == false);
    }

    {
        TEST_CHECK(utils_axes_mask_swapped(AxesMaskX) == 2);
        TEST_CHECK(utils_axes_mask_swapped(AxesMaskNX) == 1);
        TEST_CHECK(utils_axes_mask_swapped(AxesMaskY) == 8);
        TEST_CHECK(utils_axes_mask_swapped(AxesMaskNY) == 4);
        TEST_CHECK(utils_axes_mask_swapped(AxesMaskZ) == 32);
        TEST_CHECK(utils_axes_mask_swapped(AxesMaskNZ) == 16);
    }

    {
        TEST_CHECK(utils_axes_mask_value_swapped(AxesMaskX) == AxesMaskNX);
        TEST_CHECK(utils_axes_mask_value_swapped(AxesMaskNX) == AxesMaskX);
        TEST_CHECK(utils_axes_mask_value_swapped(AxesMaskY) == AxesMaskNY);
        TEST_CHECK(utils_axes_mask_value_swapped(AxesMaskNY) == AxesMaskY);
        TEST_CHECK(utils_axes_mask_value_swapped(AxesMaskZ) == AxesMaskNZ);
        TEST_CHECK(utils_axes_mask_value_swapped(AxesMaskNZ) == AxesMaskZ);
        TEST_CHECK(utils_axes_mask_value_swapped(255) == AxesMaskNone);
        TEST_CHECK(utils_axes_mask_value_swapped(0) == AxesMaskNone);
    }

    {
        TEST_CHECK(utils_axis_index_to_mask_value(AxisIndexX) == AxesMaskX);
        TEST_CHECK(utils_axis_index_to_mask_value(AxisIndexNX) == AxesMaskNX);
        TEST_CHECK(utils_axis_index_to_mask_value(AxisIndexY) == AxesMaskY);
        TEST_CHECK(utils_axis_index_to_mask_value(AxisIndexNY) == AxesMaskNY);
        TEST_CHECK(utils_axis_index_to_mask_value(AxisIndexZ) == AxesMaskZ);
        TEST_CHECK(utils_axis_index_to_mask_value(AxisIndexNZ) == AxesMaskNZ);
    }
}

void test_utils_string_new_join(void) {

    char *str = NULL;
    char *verif = NULL;

    str = _string_new_join(1, "Hello");
    verif = "Hello";
    TEST_CHECK(strcmp(str, verif) == 0);
    free(str);

    str = _string_new_join(1, "123890 _&@/()[]{}");
    verif = "123890 _&@/()[]{}";
    TEST_CHECK(strcmp(str, verif) == 0);
    free(str);

    str = _string_new_join(5, "Hello", "World", "This", "Is", "Moon");
    verif = "HelloWorldThisIsMoon";
    TEST_CHECK(strcmp(str, verif) == 0);
    free(str);
}

void test_utils_string_new_copy(void) {

    char *str = NULL;

    str = string_new_copy("Hello");
    TEST_CHECK(strcmp(str, "Hello") == 0);
    free(str);

    str = string_new_copy("01234 _&@/()[]{}");
    TEST_CHECK(strcmp(str, "01234 _&@/()[]{}") == 0);
    free(str);
}

void test_utils_string_new_substring(void) {

    char *end = "Hello World This Is Moon";
    char *res = NULL;

    res = string_new_substring(end + 0, end + 5);
    TEST_CHECK(strcmp(res, "Hello") == 0);
    free(res);

    res = string_new_substring(end + 0, end + 14);
    TEST_CHECK(strcmp(res, "Hello World Th") == 0);
    free(res);

    res = string_new_substring(end + 7, end + 9);
    TEST_CHECK(strcmp(res, "or") == 0);
    free(res);

    res = string_new_substring(end + 4, end + 18);
    TEST_CHECK(strcmp(res, "o World This I") == 0);
    free(res);
}

void test_utils_string_new_copy_with_limit(void) {

    char *str = "This is a sentance";
    char *res = NULL;

    res = string_new_copy_with_limit(str, 9);
    TEST_CHECK(strcmp(res, "This is a") == 0);
    free(res);

    res = string_new_copy_with_limit(str, 999);
    TEST_CHECK(strcmp(res, "This is a sentance") == 0);
    free(res);

    res = string_new_copy_with_limit(str, 0);
    TEST_CHECK(strcmp(res, "") == 0);
    free(res);
}

void test_utils_stringArray_new(void) {

    stringArray_t *arr = stringArray_new();
    TEST_CHECK(arr != NULL);
    int lenght = stringArray_length(arr);
    const char *check = stringArray_get((const stringArray_t *)arr, 0);
    TEST_CHECK(check == NULL);
    TEST_CHECK(lenght == 0);
    stringArray_free(arr);
}

void test_utils_stringArray_n_append(void) {

    bool verif;
    char *str = NULL;
    stringArray_t *arr = stringArray_new();

    str = "Hello";
    verif = stringArray_n_append(arr, str, strlen(str));
    TEST_CHECK(verif == true);
    int length = stringArray_length(arr);
    TEST_CHECK(length == 1);

    str = "01234 _&@/()[]{}";
    verif = stringArray_n_append(arr, str, strlen(str));
    TEST_CHECK(verif == true);
    length = stringArray_length(arr);
    TEST_CHECK(length == 2);

    str = "Hello World";
    verif = stringArray_n_append(arr, str, 5);
    TEST_CHECK(verif == true);
    length = stringArray_length(arr);
    TEST_CHECK(length == 3);

    char *check = (char *)stringArray_get(arr, 0);
    TEST_CHECK(strcmp(check, "Hello") == 0);
    check = (char *)stringArray_get(arr, 1);
    TEST_CHECK(strcmp(check, "01234 _&@/()[]{}") == 0);
    check = (char *)stringArray_get(arr, 2);
    TEST_CHECK(strcmp(check, "Hello") == 0);
    stringArray_free(arr);
}

void test_utils_string_split(void) {
    char *str = "Hello World This Is Moon";
    char *delimiters = " ";
    char *check = NULL;
    const stringArray_t *arr = string_split(str, delimiters);

    check = (char *)stringArray_get(arr, 0);
    TEST_CHECK(strcmp(check, "Hello") == 0);

    check = (char *)stringArray_get(arr, 1);
    TEST_CHECK(strcmp(check, "World") == 0);

    check = (char *)stringArray_get(arr, 2);
    TEST_CHECK(strcmp(check, "This") == 0);

    check = (char *)stringArray_get(arr, 3);
    TEST_CHECK(strcmp(check, "Is") == 0);

    check = (char *)stringArray_get(arr, 4);
    TEST_CHECK(strcmp(check, "Moon") == 0);

    check = (char *)stringArray_get(arr, 5);
    TEST_CHECK(check == NULL);

    stringArray_free((stringArray_t *)arr);
}
