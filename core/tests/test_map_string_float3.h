// -------------------------------------------------------------
//  Cubzh Core
//  map_string_float3.h
//  Created by Nino PLANE on November 15, 2022.
// -------------------------------------------------------------

#pragma once

#include "float3.h"
#include "map_string_float3.h"

// Functions that are not tested :
// --- map_string_float3_free()
// --- map_string_float3_iterator_free()
// --- map_string_float3_debug()

// Create a new map and iterate on it to check if the init value is NULL.
void test_map_string_float3_new(void) {
    MapStringFloat3 *map = map_string_float3_new();
    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    float3 *check = map_string_float3_iterator_current_value(mapIterator);

    TEST_CHECK(check == NULL);

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a 2 different map, one with a node and one null. Try to create an iterator on both
// and check what value the iterator got.
void test_map_string_float3_iterator_new(void) {
    MapStringFloat3 *map = map_string_float3_new();
    MapStringFloat3 *mapNull = NULL;
    const char *aKey = "key";
    float3 *float3A = float3_new(-10, 0, 10);

    TEST_CHECK(map_string_float3_iterator_new(mapNull) == NULL);
    map_string_float3_set_key_value(map, aKey, float3A);
    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    float3 *iteratorCheck = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(iteratorCheck, float3A, 0.1f));

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it a node with a set key and a float3. Then check if the the node is in the
// map.
void test_map_string_float3_set_key_value(void) {
    MapStringFloat3 *map = map_string_float3_new();
    const char *aKey = "key";
    float3 *float3A = float3_new(-10, 0, 10);

    map_string_float3_set_key_value(map, aKey, float3A);
    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    float3 *iteratorCheck = map_string_float3_iterator_current_value(mapIterator);
    const char *checkChar = map_string_float3_iterator_current_key(mapIterator);
    TEST_CHECK(float3_isEqual(iteratorCheck, float3A, 0.1f));
    TEST_CHECK(strcmp(checkChar, aKey) == 0);

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it 3 different nodes. Then check if the nodes are all in the map and if they
// are in the correct order (filo).
void test_map_string_float3_iterator_next(void) {
    MapStringFloat3 *map = map_string_float3_new();
    const char *aKey = "key1";
    const char *bKey = "key2";
    const char *cKey = "key3";
    float3 *float3A = float3_new(-10, 0, 10);
    float3 *float3B = float3_new(-1000, 0, 1000);
    float3 *float3C = float3_new(-5, 0, 5);
    map_string_float3_set_key_value(map, aKey, float3A); // [float3A]
    map_string_float3_set_key_value(map, bKey, float3B); // [float3B, float3A]
    map_string_float3_set_key_value(map, cKey, float3C); // [float3C, float3B, float3A]

    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    float3 *iteratorCheck = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(iteratorCheck, float3C, 0.1f));
    map_string_float3_iterator_next(mapIterator);
    iteratorCheck = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(iteratorCheck, float3B, 0.1f));
    map_string_float3_iterator_next(mapIterator);
    iteratorCheck = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(iteratorCheck, float3A, 0.1f));

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it 2 diffrent nodes one by one. At each step check if the current key is the
// good one.
void test_map_string_float3_iterator_current_key(void) {
    MapStringFloat3 *map = map_string_float3_new();

    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    const char *checkChar = map_string_float3_iterator_current_key(mapIterator);
    TEST_CHECK(checkChar == NULL);
    const char *aKey = "key";
    float3 *float3A = float3_new(-10, 0, 10);
    map_string_float3_set_key_value(map, aKey, float3A);
    mapIterator = map_string_float3_iterator_new(map);
    checkChar = map_string_float3_iterator_current_key(mapIterator);
    TEST_CHECK(strcmp(checkChar, aKey) == 0);
    const char *bKey = "1654984654131648945415";
    float3 *float3B = float3_new(-5, 0, 5);
    map_string_float3_set_key_value(map, bKey, float3B);
    mapIterator = map_string_float3_iterator_new(map);
    checkChar = map_string_float3_iterator_current_key(mapIterator);
    TEST_CHECK(strcmp(checkChar, bKey) == 0);

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it 2 diffrents nodes one by one. At each step check if the current float3 is
// the good one.
void test_map_string_float3_iterator_current_value(void) {
    MapStringFloat3 *map = map_string_float3_new();

    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    float3 *checkFloat3 = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(checkFloat3 == NULL);
    const char *aKey = "key";
    float3 *float3A = float3_new(-10, 0, 10);
    map_string_float3_set_key_value(map, aKey, float3A);
    mapIterator = map_string_float3_iterator_new(map);
    checkFloat3 = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(checkFloat3, float3A, 0.1f));
    const char *bKey = "1654984654131648945415";
    float3 *float3B = float3_new(-5, 0, 5);
    map_string_float3_set_key_value(map, bKey, float3B);
    mapIterator = map_string_float3_iterator_new(map);
    checkFloat3 = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(checkFloat3, float3B, 0.1f));

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it a node. After that change the value of the node with a other float3.
// Check if the value of the node in the map is now the new float3.
void test_map_string_float3_iterator_replace_current_value(void) {
    MapStringFloat3 *map = map_string_float3_new();
    const char *aKey = "key";
    float3 *float3A = float3_new(-10, 0, 10);
    map_string_float3_set_key_value(map, aKey, float3A);

    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    float3 *checkFloat3 = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(checkFloat3, float3A, 0.1f));
    float3 *newFloat3 = float3_new(-100, 0, 100);
    map_string_float3_iterator_replace_current_value(mapIterator, newFloat3);
    checkFloat3 = map_string_float3_iterator_current_value(mapIterator);
    TEST_CHECK(float3_isEqual(checkFloat3, newFloat3, 0.1f));

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it 3 differents nodes. Use an iterator to go one by one on each element of
// the map. Check if the iterator return NULL if it's the end of the map.
void test_map_string_float3_iterator_is_done(void) {
    MapStringFloat3 *map = map_string_float3_new();
    const char *aKey = "key1";
    const char *bKey = "key2";
    const char *cKey = "key3";
    float3 *float3A = float3_new(-10, 0, 10);
    float3 *float3B = float3_new(-1000, 0, 1000);
    float3 *float3C = float3_new(-5, 0, 5);
    map_string_float3_set_key_value(map, aKey, float3A); // [float3A]
    map_string_float3_set_key_value(map, bKey, float3B); // [float3B, float3A]
    map_string_float3_set_key_value(map, cKey, float3C); // [float3C, float3B, float3A]

    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    TEST_CHECK(map_string_float3_iterator_is_done(mapIterator) == false);
    map_string_float3_iterator_next(mapIterator);
    TEST_CHECK(map_string_float3_iterator_is_done(mapIterator) == false);
    map_string_float3_iterator_next(mapIterator);
    TEST_CHECK(map_string_float3_iterator_is_done(mapIterator) == false);
    map_string_float3_iterator_next(mapIterator);
    TEST_CHECK(map_string_float3_iterator_is_done(mapIterator));

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it 3 differents nodes. For each element, check if we get the correct value
// for a set key.
void test_map_string_float3_value_for_key(void) {
    MapStringFloat3 *map = map_string_float3_new();
    const char *aKey = "key1";
    const char *bKey = "key2";
    const char *cKey = "key3";
    float3 *float3A = float3_new(-10, 0, 10);
    float3 *float3B = float3_new(-1000, 0, 1000);
    float3 *float3C = float3_new(-5, 0, 5);
    map_string_float3_set_key_value(map, aKey, float3A); // [float3A]
    map_string_float3_set_key_value(map, bKey, float3B); // [float3B, float3A]
    map_string_float3_set_key_value(map, cKey, float3C); // [float3C, float3B, float3A]

    const float3 *checkFloat3 = map_string_float3_value_for_key(map, aKey);
    TEST_CHECK(float3_isEqual(checkFloat3, float3A, 0.1f));
    checkFloat3 = map_string_float3_value_for_key(map, bKey);
    TEST_CHECK(float3_isEqual(checkFloat3, float3B, 0.1f));
    checkFloat3 = map_string_float3_value_for_key(map, cKey);
    TEST_CHECK(float3_isEqual(checkFloat3, float3C, 0.1f));

    map_string_float3_free(map);
}

// Create a map and add it 3 differents nodes. For each element, check if we get the correct value
// for a set key. Also check if the float3 can be changed
void test_map_string_mutable_float3_value_for_key(void) {
    MapStringFloat3 *map = map_string_float3_new();
    const char *aKey = "key1";
    const char *bKey = "key2";
    const char *cKey = "key3";
    float3 *float3A = float3_new(-10, 0, 10);
    float3 *float3B = float3_new(-1000, 0, 1000);
    float3 *float3C = float3_new(-5, 0, 5);
    map_string_float3_set_key_value(map, aKey, float3A); // [float3A]
    map_string_float3_set_key_value(map, bKey, float3B); // [float3B, float3A]
    map_string_float3_set_key_value(map, cKey, float3C); // [float3C, float3B, float3A]

    float3 *checkFloat3 = map_string_mutable_float3_value_for_key(map, aKey);
    TEST_CHECK(float3_isEqual(checkFloat3, float3A, 0.1f));
    checkFloat3 = map_string_mutable_float3_value_for_key(map, bKey);
    TEST_CHECK(float3_isEqual(checkFloat3, float3B, 0.1f));
    checkFloat3 = map_string_mutable_float3_value_for_key(map, cKey);
    TEST_CHECK(float3_isEqual(checkFloat3, float3C, 0.1f));
    float3 *newFloat3 = float3_new(7, 7, 7);
    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    map_string_float3_iterator_replace_current_value(mapIterator, newFloat3);
    checkFloat3 = map_string_mutable_float3_value_for_key(map, cKey);
    TEST_CHECK(float3_isEqual(checkFloat3, newFloat3, 0.1f));

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}

// Create a map and add it 3 differents nodes. For each nodes, we take it one by one, out of the map
// and check if the map doesn't contain the node anymore. Check at the end if the map is empty.
void test_map_string_float3_remove_key(void) {
    MapStringFloat3 *map = map_string_float3_new();
    const char *aKey = "key1";
    const char *bKey = "key2";
    const char *cKey = "key3";
    float3 *float3A = float3_new(-10, 0, 10);
    float3 *float3B = float3_new(-1000, 0, 1000);
    float3 *float3C = float3_new(-5, 0, 5);
    map_string_float3_set_key_value(map, aKey, float3A); // [float3A]
    map_string_float3_set_key_value(map, bKey, float3B); // [float3B, float3A]
    map_string_float3_set_key_value(map, cKey, float3C); // [float3C, float3B, float3A]

    MapStringFloat3Iterator *mapIterator = map_string_float3_iterator_new(map);
    const char *checkChar = map_string_float3_iterator_current_key(mapIterator);
    TEST_CHECK(strcmp(checkChar, cKey) == 0);
    map_string_float3_remove_key(map, cKey); // [float3B, float3A]
    const float3 *checkFloat3 = map_string_float3_value_for_key(map, cKey);
    TEST_CHECK(checkFloat3 == NULL);
    map_string_float3_remove_key(map, bKey); // [float3A]
    checkFloat3 = map_string_float3_value_for_key(map, bKey);
    TEST_CHECK(checkFloat3 == NULL);
    map_string_float3_remove_key(map, aKey); // []
    checkFloat3 = map_string_float3_value_for_key(map, aKey);
    TEST_CHECK(checkFloat3 == NULL);
    mapIterator = map_string_float3_iterator_new(map);
    TEST_CHECK(map_string_float3_iterator_is_done(mapIterator));

    map_string_float3_iterator_free(mapIterator);
    map_string_float3_free(map);
}
