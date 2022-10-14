// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_list.c
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#include "acutest.h"

#include "test_hash_uint32_int.h"
#include "test_float3.h"
#include "test_matrix4x4.h"
#include "test_transform.h"
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
    
    // float4

    // matrix4x4
    { "matrix4x4_new", test_matrix4x4_new },
    { "matrix4x4_copy", test_matrix4x4_new_copy },
    { "matrix4x4_identity", test_matrix4x4_new_identity },
    { "matrix4x4_new_off_center_orthographic", test_matrix4x4_new_off_center_orthographic },
    { "matrix4x4_new_transate", test_matrix4x4_new_translate },
    { "matrix4x4_set_translation", test_matrix4x4_set_translation },
    { "matrix4x4_new_scale", test_matrix4x4_new_scale },
    { "matrix4x4_set_scale", test_matrix4x4_set_scale },
    { "matrix4x4_set_scaleXYZ", test_matrix4x4_set_scaleXYZ },
    { "matrix4x4_get_scale", test_matrix4x4_get_scale },
    { "matrix4x4_get_scaleXYZ", test_matrix4x4_get_scaleXYZ },
    { "matrix4x4_get_trace", test_matrix4x4_get_trace },
    { "matrix4x4_get_euler", test_matrix4x4_get_euler },
    { "matrix4x4_copy", test_matrix4x4_copy },
    { "matrix4x4_op_multiply_2", test_matrix4x4_op_multiply_2 },
    { "matrix4x4_op_multiply_vec", test_matrix4x4_op_multiply_vec },
    { "matrix4x4_op_multiply_vec_point", test_matrix4x4_op_multiply_vec_point },
    { "matrix4x4_op_multiply_vec_vector", test_matrix4x4_op_multiply_vec_vector },
    { "matrix4x4_op_invert", test_matrix4x4_op_invert },
    { "matrix4x4_op_unscale", test_matrix4x4_op_unscale },
    
    // transform
    { "transform_rotation_position", test_transform_rotation_position },
    { "transform_child", test_transform_child },
    { "transform_children", test_transform_children },
    { "transform_retain", test_transform_retain },
    { "transform_flush", test_transform_flush },

    // shape
    { "test_shape_addblock_1", test_shape_addblock_1 },
    // { "test_shape_addblock_2", test_shape_addblock_2 },
    // { "test_shape_addblock_3", test_shape_addblock_3 },

    { NULL, NULL }     /* zeroed record marking the end of the list */
};
