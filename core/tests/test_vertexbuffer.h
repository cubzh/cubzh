// -------------------------------------------------------------
//  Cubzh Core Unit Tests
//  test_vertexbuffer.h
//  Created by Xavier Legland on October , 2022.
// -------------------------------------------------------------

#pragma once

#include "vertextbuffer.h"

// functions that are NOT tested:
// vertex_buffer_mem_area_writer_new
// vertex_buffer_mem_area_writer_free
// vertex_buffer_mem_area_writer_write_vertex
// vertex_buffer_mem_area_writer_done
// vertex_buffer_new
// vertex_buffer_get_id
// vertex_buffer_get_draw_slices
// vertex_buffer_log_draw_slices
// vertex_buffer_add_draw_slice
// vertex_buffer_fill_draw_slices
// vertex_buffer_flush_draw_slices
// vertex_buffer_get_nb_draw_slices
// vertex_buffer_get_count
// vertex_buffer_has_room_for_new_chunk
// vertex_buffer_log_draw_slices
// vertex_buffer_is_fragmented
// vertex_buffer_fill_gaps
// vertex_buffer_mem_area_make_gap
// vertex_buffer_mem_area_flush
// vertex_buffer_mem_area_get_vb
// vertex_buffer_mem_area_get_group_next
// vertex_buffer_has_dirty_mem_areas
// vertex_buffer_log_mem_areas

// check that we can pop an id once a vb has been freed
void test_vertex_buffer_pop_destroyed_id(void) {
    VertexBuffer *vb = vertex_buffer_new(false, false);
    vertex_buffer_free(vb);
    uint32_t result = 1;

    TEST_CHECK(vertex_buffer_pop_destroyed_id(&result));
}

// check default values
void test_vertex_buffer_new_with_max_count(void) {
    VertexBuffer *vb = vertex_buffer_new_with_max_count(3, false, false);

    TEST_CHECK(vertex_buffer_get_max_count(vb) == 3);
    TEST_CHECK(vertex_buffer_get_count(vb) == 0);
    TEST_CHECK(vertex_buffer_get_next(vb) == NULL);
    TEST_CHECK(vertex_buffer_get_draw_slices(vb) != NULL);
    TEST_CHECK(vertex_buffer_get_nb_draw_slices(vb) == 0);

    vertex_buffer_free(vb);
    // reset the id filo list to its initial state
    uint32_t id;
    vertex_buffer_pop_destroyed_id(&id);
}

// check that 2 vb have been freed
void test_vertex_buffer_free_all(void) {
    VertexBuffer *a = vertex_buffer_new_with_max_count(3, false, false);
    VertexBuffer *b = vertex_buffer_new_with_max_count(3, false, false);
    uint32_t id;
    vertex_buffer_insert_after(b, a);
    vertex_buffer_free_all(a);

    TEST_CHECK(vertex_buffer_pop_destroyed_id(&id));
    TEST_CHECK(vertex_buffer_pop_destroyed_id(&id));
    TEST_CHECK(vertex_buffer_pop_destroyed_id(&id) == false);
}

// a 0-sized buffer must be full from the start
void test_vertex_buffer_is_not_full(void) {
    VertexBuffer *a = vertex_buffer_new_with_max_count(3, false, false);
    VertexBuffer *b = vertex_buffer_new_with_max_count(0, false, false);

    TEST_CHECK(vertex_buffer_has_capacity(a, 1));
    TEST_CHECK(vertex_buffer_has_capacity(b, 1) == false);

    vertex_buffer_free(a);
    vertex_buffer_free(b);
    uint32_t id;
    vertex_buffer_pop_destroyed_id(&id);
    vertex_buffer_pop_destroyed_id(&id);
}

// check that the order stays the same
void test_vertex_buffer_insert_after(void) {
    VertexBuffer *a = vertex_buffer_new_with_max_count(3, false, false);
    VertexBuffer *b = vertex_buffer_new_with_max_count(3, false, false);
    vertex_buffer_insert_after(b, a);

    TEST_CHECK(vertex_buffer_get_next(a) == b);

    vertex_buffer_free_all(a);
    uint32_t id;
    vertex_buffer_pop_destroyed_id(&id);
    vertex_buffer_pop_destroyed_id(&id);
}

// check that the chain is complete
void test_vertex_buffer_get_next(void) {
    VertexBuffer *a = vertex_buffer_new_with_max_count(3, false, false);
    VertexBuffer *b = vertex_buffer_new_with_max_count(3, false, false);
    VertexBuffer *c = vertex_buffer_new_with_max_count(3, false, false);
    vertex_buffer_insert_after(b, a);
    vertex_buffer_insert_after(c, b);

    TEST_CHECK(vertex_buffer_get_next(a) == b);
    TEST_CHECK(vertex_buffer_get_next(b) == c);

    vertex_buffer_free_all(a);
    uint32_t id;
    vertex_buffer_pop_destroyed_id(&id);
    vertex_buffer_pop_destroyed_id(&id);
    vertex_buffer_pop_destroyed_id(&id);
}

// check that we get the correct max count
void test_vertex_buffer_get_max_count(void) {
    const size_t len = 500;
    VertexBuffer *vb = vertex_buffer_new_with_max_count(500, false, false);

    TEST_CHECK(vertex_buffer_get_max_count(vb) == len);

    vertex_buffer_free(vb);
    uint32_t id;
    vertex_buffer_pop_destroyed_id(&id);
}

// set lighting_enabled to true and false
void test_vertex_buffer_set_lighting_enabled(void) {
    const bool previous_value = vertex_buffer_get_lighting_enabled();

    vertex_buffer_set_lighting_enabled(true);
    TEST_CHECK(vertex_buffer_get_lighting_enabled());

    vertex_buffer_set_lighting_enabled(false);
    TEST_CHECK(vertex_buffer_get_lighting_enabled() == false);

    vertex_buffer_set_lighting_enabled(previous_value);
}

// same tests as for vertex_buffer_set_lighting_enabled
void test_vertex_buffer_get_lighting_enabled(void) {
    const bool previous_value = vertex_buffer_get_lighting_enabled();

    vertex_buffer_set_lighting_enabled(true);
    TEST_CHECK(vertex_buffer_get_lighting_enabled());

    vertex_buffer_set_lighting_enabled(false);
    TEST_CHECK(vertex_buffer_get_lighting_enabled() == false);

    vertex_buffer_set_lighting_enabled(previous_value);
}
