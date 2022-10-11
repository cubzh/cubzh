// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_list.c
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#include "acutest.h"

#include "test_hash_uint32_int.h"
#include "test_float3.h"
#include "test_shape.h"

TEST_LIST = {
    { "hash_uint32_int", test_hash_uint32_int },

    // float3
    { "float3_new(Number3)", test_float3_new },
    { "float3_copy", test_float3_copy },
    { "float3_const", test_float3_const },
    { "float3_products", test_float3_products },
    { "float3_length", test_float3_length },
    { "float3_min_max", test_float3_min_max },
    { "float3_operations", test_float3_operations },

    // shape
    { "test_shape_addblock_1", test_shape_addblock_1 },
    // { "test_shape_addblock_2", test_shape_addblock_2 },
    // { "test_shape_addblock_3", test_shape_addblock_3 },

    { NULL, NULL }     /* zeroed record marking the end of the list */
};
