// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_list.c
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#include "acutest.h"

#include "test_hash_uint32_int.h"
#include "test_int3.h"
#include "test_filo_list_int3.h"
#include "test_float3.h"
#include "test_float4.h"
#include "test_matrix4x4.h"
#include "test_shape.h"
#include "test_transform.h"
#include "test_utils.h"

TEST_LIST = {
    { "hash_uint32_int", test_hash_uint32_int },

    // filo_list_int3
    { "filo_list_int3_pop", test_filo_list_int3_pop },
    { "filo_list_int3_recycle", test_filo_list_int3_recycle },

    // float3
    { "float3_new(Number3)", test_float3_new },
    { "float3_copy", test_float3_copy },
    { "float3_const", test_float3_const },
    { "float3_products", test_float3_products },
    { "float3_length", test_float3_length },
    { "float3_min_max", test_float3_min_max },
    { "float3_operations", test_float3_operations },
    
    // float4
    { "float4_new", test_float4_new },

    // int3
    { "int3_pool_pop", test_int3_pool_pop },
    { "int3_pool_recycle", test_int3_pool_recycle },
    { "int3_new", test_int3_new },
    { "int3_new_copy", test_int3_new_copy },
    { "int3_set", test_int3_set },
    { "int3_copy", test_int3_copy },
    { "int3_op_add", test_int3_op_add },
    { "int3_op_add_int", test_int3_op_add_int },
    { "int3_op_substract_int", test_int3_op_substract_int },
    { "int3_op_min", test_int3_op_min },
    { "int3_op_max", test_int3_op_max },
    { "int3_op_div_ints", test_int3_op_div_ints },

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

    // shape
    { "test_shape_addblock_1", test_shape_addblock_1 },
    // { "test_shape_addblock_2", test_shape_addblock_2 },
    // { "test_shape_addblock_3", test_shape_addblock_3 },
    
    // transform
    { "transform_rotation_position", test_transform_rotation_position },
    { "transform_child", test_transform_child },
    { "transform_children", test_transform_children },
    { "transform_retain", test_transform_retain },
    { "transform_flush", test_transform_flush },

    // utils
    { "test_utils_float_isEqual", test_utils_float_isEqual },
    { "test_utils_float_isZero", test_utils_float_isZero },
    { "test_utils_is_float_to_coords_inbounds", test_utils_is_float_to_coords_inbounds },
    { "test_utils_is_float3_to_coords_inbounds", test_utils_is_float3_to_coords_inbounds },
    { "test_utils_axes_mask", test_utils_axes_mask },
    { "test_utils_string_new_join", test_utils_string_new_join },
    { "test_utils_string_new_copy", test_utils_string_new_copy },
    { "test_utils_string_new_substring", test_utils_string_new_substring },
    { "test_utils_string_new_copy_with_limit", test_utils_string_new_copy_with_limit },
    { "test_utils_stringArray_new", test_utils_stringArray_new},
    { "test_utils_stringArray_n_append", test_utils_stringArray_n_append},
    { "test_utils_string_split", test_utils_string_split},

    { NULL, NULL }     /* zeroed record marking the end of the list */
};
