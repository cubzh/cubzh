// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_list.c
//  Created by Adrien Duermael on August 28, 2022.
// -------------------------------------------------------------

#include "acutest.h"

#include "test_block.h"
#include "test_blockChange.h"
#include "test_box.h"
#include "test_chunk.h"
#include "test_config.h"
#include "test_doubly_linked_list.h"
#include "test_doubly_linked_list_uint8.h"
#include "test_filo_list_float3.h"
#include "test_filo_list_int3.h"
#include "test_filo_list_uint16.h"
#include "test_filo_list_uint32.h"
#include "test_float3.h"
#include "test_float4.h"
#include "test_hash_uint32_int.h"
#include "test_int3.h"
#include "test_matrix4x4.h"
#include "test_quaternion.h"
#include "test_shape.h"
#include "test_stream.h"
#include "test_transaction.h"
#include "test_transform.h"
#include "test_utils.h"
#include "test_weakptr.h"

TEST_LIST = {

    // block
    {"test_block_new", test_block_new},
    {"test_block_new_air", test_block_new_air},
    {"test_block_new_with_color", test_block_new_with_color},
    {"test_block_new_copy", test_block_new_copy},
    {"test_block_set_color_index", test_block_set_color_index},
    {"test_block_get_color_index", test_block_get_color_index},
    {"test_block_is_solid", test_block_is_solid},
    {"test_block_equal", test_block_equal},
    // { "test_block_is_opaque", test_block_is_opaque },
    // { "test_block_is_transparent", test_block_is_transparent },
    // { "test_block_is_ao_and_light_caster", test_block_is_ao_and_light_caster },
    // { "test_block_is_any", test_block_is_any },
    {"test_aware_block_get", test_aware_block_get},
    {"test_aware_block_new_copy", test_aware_block_new_copy},
    {"test_aware_block_set_touched_face", test_aware_block_set_touched_face},
    {"test_block_getNeighbourBlockCoordinates", test_block_getNeighbourBlockCoordinates},

    // blockChange
    {"test_blockChange_get", test_blockChange_get},
    {"test_blockChange_amend", test_blockChange_amend},

    // box
    {"test_box_new", test_box_new},
    {"test_box_new_2", test_box_new_2},
    {"test_box_new_copy", test_box_new_copy},
    {"test_box_set_bottom_center_position", test_box_set_bottom_center_position},
    {"test_box_get_center", test_box_get_center},
    {"test_box_copy", test_box_copy},
    {"test_box_collide", test_box_collide},
    {"test_box_contains", test_box_contains},
    {"test_box_set_broadphase_box", test_box_set_broadphase_box},
    {"test_box_get_size", test_box_get_size},
    {"test_box_is_empty", test_box_is_empty},
    {"test_box_squarify", test_box_squarify},
    {"test_box_op_merge", test_box_op_merge},
    {"test_box_get_volume", test_box_get_volume},
    {"test_box_to_aabox_no_rot", test_box_to_aabox_no_rot},
    {"test_box_to_aabox2", test_box_to_aabox2},

    // chunk
    {"test_chunk_new", test_chunk_new},
    {"test_chunk_Block", test_chunk_Block},
    {"test_chunk_needs_display", test_chunk_needs_display},

    // config
    {"test_upper_power_of_two", test_upper_power_of_two},

    // doubly_linked_list_uint8
    {"doubly_linked_list_uint8_new", test_doubly_linked_list_uint8_new},
    {"doubly_linked_list_uint8_node_new", test_doubly_linked_list_uint8_node_new},
    {"doubly_linked_list_uint8_node_get_value", test_doubly_linked_list_uint8_node_get_value},
    {"doubly_linked_list_uint8_node_set_value", test_doubly_linked_list_uint8_node_set_value},
    {"doubly_linked_list_uint8_push_front", test_doubly_linked_list_uint8_push_front},
    {"doubly_linked_list_uint8_push_back", test_doubly_linked_list_uint8_push_back},
    {"doubly_linked_list_uint8_node_next", test_doubly_linked_list_uint8_node_next},
    {"doubly_linked_list_uint8_node_previous", test_doubly_linked_list_uint8_node_previous},
    {"doubly_linked_list_uint8_node_count", test_doubly_linked_list_uint8_node_count},
    {"doubly_linked_list_uint8_node_flush", test_doubly_linked_list_uint8_node_flush},
    {"doubly_linked_list_uint8_contains", test_doubly_linked_list_uint8_contains},
    {"doubly_linked_list_uint8_pop_front", test_doubly_linked_list_uint8_pop_front},
    {"doubly_linked_list_uint8_pop_back", test_doubly_linked_list_uint8_pop_back},
    {"doubly_linked_list_uint8_front", test_doubly_linked_list_uint8_front},
    {"doubly_linked_list_uint8_back", test_doubly_linked_list_uint8_back},
    {"doubly_linked_list_uint8_insert_node_before",
     test_doubly_linked_list_uint8_insert_node_before},
    {"doubly_linked_list_uint8_insert_node_after", test_doubly_linked_list_uint8_insert_node_after},
    {"doubly_linked_list_uint8_delete_node", test_doubly_linked_list_uint8_delete_node},
    // doubly_linked_list
    {"doubly_linked_list_new", test_doubly_linked_list_new},
    {"doubly_linked_list_node_new", test_doubly_linked_list_node_new},
    {"doubly_linked_list_node_pointer", test_doubly_linked_list_node_pointer},
    {"doubly_linked_list_node_set_pointer", test_doubly_linked_list_node_set_pointer},
    {"doubly_linked_list_push_first", test_doubly_linked_list_push_first},
    {"doubly_linked_list_push_last", test_doubly_linked_list_push_last},
    {"doubly_linked_list_node_next", test_doubly_linked_list_node_next},
    {"doubly_linked_list_node_previous", test_doubly_linked_list_node_previous},
    {"doubly_linked_list_node_count", test_doubly_linked_list_node_count},
    {"doubly_linked_list_flush", test_doubly_linked_list_flush},
    {"doubly_linked_list_contains", test_doubly_linked_list_contains},
    {"doubly_linked_list_pop_first", test_doubly_linked_list_pop_first},
    {"doubly_linked_list_pop_back", test_doubly_linked_list_pop_last},
    {"doubly_linked_list_first", test_doubly_linked_list_first},
    {"doubly_linked_list_last", test_doubly_linked_list_last},
    {"doubly_linked_list_insert_node_next", test_doubly_linked_list_insert_node_next},
    {"doubly_linked_list_insert_node_previous", test_doubly_linked_list_insert_node_previous},
    {"doubly_linked_list_delete_node", test_doubly_linked_list_delete_node},
    {"doubly_linked_list_node_at_index", test_doubly_linked_list_node_at_index},
    {"doubly_linked_list_sort_ascending", test_doubly_linked_list_sort_ascending},

    // filo_list_float3
    {"filo_list_float3_pop", test_filo_list_float3_pop},
    {"filo_list_float3_recycle", test_filo_list_float3_recycle},

    // filo_list_int3
    {"filo_list_int3_pop", test_filo_list_int3_pop},
    {"filo_list_int3_recycle", test_filo_list_int3_recycle},

    // filo_list_uint16
    {"test_filo_list_uint16_push", test_filo_list_uint16_push},
    {"test_filo_list_uint16_pop", test_filo_list_uint16_pop},

    // filo_list_uint32
    {"test_filo_list_uint32_push", test_filo_list_uint32_push},
    {"test_filo_list_uint32_pop", test_filo_list_uint32_pop},

    // float3
    {"float3_new(Number3)", test_float3_new},
    {"float3_copy", test_float3_copy},
    {"float3_const", test_float3_const},
    {"float3_products", test_float3_products},
    {"float3_length", test_float3_length},
    {"float3_min_max", test_float3_min_max},
    {"float3_operations", test_float3_operations},

    // float4
    {"float4_new", test_float4_new},

    // hash_uint32
    {"hash_uint32_int", test_hash_uint32_int},

    // int3
    {"int3_pool_pop", test_int3_pool_pop},
    {"int3_pool_recycle", test_int3_pool_recycle},
    {"int3_new", test_int3_new},
    {"int3_new_copy", test_int3_new_copy},
    {"int3_set", test_int3_set},
    {"int3_copy", test_int3_copy},
    {"int3_op_add", test_int3_op_add},
    {"int3_op_add_int", test_int3_op_add_int},
    {"int3_op_substract_int", test_int3_op_substract_int},
    {"int3_op_min", test_int3_op_min},
    {"int3_op_max", test_int3_op_max},
    {"int3_op_div_ints", test_int3_op_div_ints},

    // matrix4x4
    {"matrix4x4_new", test_matrix4x4_new},
    {"matrix4x4_copy", test_matrix4x4_new_copy},
    {"matrix4x4_identity", test_matrix4x4_new_identity},
    {"matrix4x4_new_off_center_orthographic", test_matrix4x4_new_off_center_orthographic},
    {"matrix4x4_new_transate", test_matrix4x4_new_translate},
    {"matrix4x4_set_translation", test_matrix4x4_set_translation},
    {"matrix4x4_new_scale", test_matrix4x4_new_scale},
    {"matrix4x4_set_scale", test_matrix4x4_set_scale},
    {"matrix4x4_set_scaleXYZ", test_matrix4x4_set_scaleXYZ},
    {"matrix4x4_get_scale", test_matrix4x4_get_scale},
    {"matrix4x4_get_scaleXYZ", test_matrix4x4_get_scaleXYZ},
    {"matrix4x4_get_trace", test_matrix4x4_get_trace},
    {"matrix4x4_get_euler", test_matrix4x4_get_euler},
    {"matrix4x4_copy", test_matrix4x4_copy},
    {"matrix4x4_op_multiply_2", test_matrix4x4_op_multiply_2},
    {"matrix4x4_op_multiply_vec", test_matrix4x4_op_multiply_vec},
    {"matrix4x4_op_multiply_vec_point", test_matrix4x4_op_multiply_vec_point},
    {"matrix4x4_op_multiply_vec_vector", test_matrix4x4_op_multiply_vec_vector},
    {"matrix4x4_op_invert", test_matrix4x4_op_invert},
    {"matrix4x4_op_unscale", test_matrix4x4_op_unscale},

    // quaternion
    {"quaternion_new", test_quaternion_new},
    {"quaternion_new_identity", test_quaternion_new_identity},
    {"quaternion_set", test_quaternion_set},
    {"quaternion_set_identity", test_quaternion_set_identity},
    {"quaternion_square_magnitude", test_quaternion_square_magnitude},
    {"quaternion_is_zero", test_quaternion_is_zero},
    {"quaternion_is_equal", test_quaternion_is_equal},
    {"quaternion_angle_between", test_quaternion_angle_between},
    {"quaternion_op_scale", test_quaternion_op_scale},
    {"quaternion_op_unscale", test_quaternion_op_unscale},
    {"quaternion_op_conjugate", test_quaternion_op_conjugate},
    {"quaternion_op_normalize", test_quaternion_op_normalize},
    {"quaternion_op_inverse", test_quaternion_op_inverse},
    {"quaternion_op_mult", test_quaternion_op_mult},
    {"quaternion_op_mult_right", test_quaternion_op_mult_right},
    {"quaternion_op_lerp", test_quaternion_op_lerp},
    {"quaternion_op_dot", test_quaternion_op_dot},
    {"quaternion_to_rotation_matrix", test_quaternion_to_rotation_matrix},
    {"rotation_matrix_to_quaternion", test_rotation_matrix_to_quaternion},
    {"quaternion_to_axis_angle", test_quaternion_to_axis_angle},
    {"axis_angle_to_quaternion", test_axis_angle_to_quaternion},
    {"quaternion_to_euler", test_quaternion_to_euler},
    {"euler_to_quaternion", test_euler_to_quaternion},
    {"euler_to_quaternion_vec", test_euler_to_quaternion_vec},
    {"quaternion_rotate_vector", test_quaternion_rotate_vector},
    {"quaternion_coherence_check", test_quaternion_coherence_check},

    // shape
    {"test_shape_addblock_1", test_shape_addblock_1},
    // { "test_shape_addblock_2", test_shape_addblock_2 },
    // { "test_shape_addblock_3", test_shape_addblock_3 },

    // stream
    {"stream_new_buffer_read", test_stream_new_buffer_read},
    {"stream_new_file_read", test_stream_new_file_read},
    {"stream_read", test_stream_read},
    {"stream_read_uint8", test_stream_read_uint8},
    {"stream_read_uint16", test_stream_read_uint16},
    {"stream_read_uint32", test_stream_read_uint32},
    {"stream_read_float32", test_stream_read_float32},
    {"stream_read_string", test_stream_read_string},
    {"stream_skip", test_stream_skip},
    {"stream_get_cursor_position", test_stream_get_cursor_position},
    {"stream_set_cursor_position", test_stream_set_cursor_position},
    {"stream_reached_the_end", test_stream_reached_the_end},

    // transaction
    {"transaction_new", test_transaction_new},
    {"transaction_getCurrentBlockAt", test_transaction_getCurrentBlockAt},
    {"transaction_addBlock", test_transaction_addBlock},
    {"transaction_removeBlock", test_transaction_removeBlock},
    {"transaction_replaceBlock", test_transaction_replaceBlock},
    {"transaction_getMustConsiderNewBounds", test_transaction_getMustConsiderNewBounds},
    {"transaction_getNewBounds", test_transaction_getNewBounds},
    {"transaction_getIndex3DIterator", test_transaction_getIndex3DIterator},

    // transform
    {"transform_rotation_position", test_transform_rotation_position},
    {"transform_child", test_transform_child},
    {"transform_children", test_transform_children},
    {"transform_retain", test_transform_retain},
    {"transform_flush", test_transform_flush},

    // utils
    {"test_utils_float_isEqual", test_utils_float_isEqual},
    {"test_utils_float_isZero", test_utils_float_isZero},
    {"test_utils_is_float_to_coords_inbounds", test_utils_is_float_to_coords_inbounds},
    {"test_utils_is_float3_to_coords_inbounds", test_utils_is_float3_to_coords_inbounds},
    {"test_utils_axes_mask", test_utils_axes_mask},
    {"test_utils_string_new_join", test_utils_string_new_join},
    {"test_utils_string_new_copy", test_utils_string_new_copy},
    {"test_utils_string_new_substring", test_utils_string_new_substring},
    {"test_utils_string_new_copy_with_limit", test_utils_string_new_copy_with_limit},
    {"test_utils_stringArray_new", test_utils_stringArray_new},
    {"test_utils_stringArray_n_append", test_utils_stringArray_n_append},
    {"test_utils_string_split", test_utils_string_split},

    // weakptr
    {"weakptr_new", test_weakptr_new},
    {"weakptr_retain", test_weakptr_retain},
    {"weakptr_release", test_weakptr_release},
    {"weakptr_get", test_weakptr_get},
    {"weakptr_get_or_release", test_weakptr_get_or_release},
    {"weakptr_invalidate", test_weakptr_invalidate},

    {NULL, NULL} /* zeroed record marking the end of the list */
};
