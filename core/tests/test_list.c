// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_list.c
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#include "acutest.h"

#include "test_hash_uint32_int.h"
#include "test_shape.h"

TEST_LIST = {
    { "hash_uint32_int", test_hash_uint32_int },

    // shape
    { "test_shape_addblock_1", test_shape_addblock_1 },
    // { "test_shape_addblock_2", test_shape_addblock_2 },
    // { "test_shape_addblock_3", test_shape_addblock_3 },

    { NULL, NULL }     /* zeroed record marking the end of the list */
};
