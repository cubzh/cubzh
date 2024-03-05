//
// -------------------------------------------------------------
//  Cubzh Core
//  vertextbuffer.h
//  Created by Adrien Duermael on July 7, 2017.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "doubly_linked_list.h"
#include "shape.h"

typedef struct _VertexBuffer VertexBuffer;
typedef struct _Chunk Chunk;

//---------------------
// MARK: Draw buffers size per face
//---------------------

struct {
    float x, y, z, color;
    float metadata;
} typedef VertexAttributes;

#define DRAWBUFFER_VERTICES_BYTES sizeof(VertexAttributes)
#define DRAWBUFFER_VERTICES_PER_FACE 4
#define DRAWBUFFER_INDICES_BYTES sizeof(uint32_t)
#define DRAWBUFFER_INDICES_PER_FACE 6

extern bool vertex_buffer_pop_destroyed_id(uint32_t *id);

struct {
    uint32_t from, to;
} typedef DrawBufferWriteSlice;

// A ChunkVertexMemory is an area in vertex buffer's memory that contains
// vertices.
// Vertices for a single chunk can ideally be stored in one single area.
// But since we want all vertices (from different chunks) to be stored without
// gaps, we have to take vertices from the last areas when removing a chunk
// to fill them. As a result, chunk vertices can be scattered, storred in
// different areas.
// Each chunk keeps a pointer to the are responsible for its vertices and can
// ask for them to be destroyed.
typedef struct _VertexBufferMemArea VertexBufferMemArea;
typedef struct _VertexBufferMemAreaWriter VertexBufferMemAreaWriter;

VertexBufferMemAreaWriter *vertex_buffer_mem_area_writer_new(Shape *s,
                                                             Chunk *c,
                                                             VertexBufferMemArea *vbma,
                                                             bool transparent);
void vertex_buffer_mem_area_writer_free(VertexBufferMemAreaWriter *vbmaw);

void vertex_buffer_mem_area_writer_write(VertexBufferMemAreaWriter *vbmaw,
                                         VertexBufferMemAreaWriter *ibmaw,
                                         HashUInt32 *vertexMap,
                                         CHUNK_COORDS_INT3_T coords_in_chunk,
                                         SHAPE_COORDS_INT3_T coords_in_shape,
                                         SHAPE_COLOR_INDEX_INT_T shapeColorIdx,
                                         ATLAS_COLOR_INDEX_INT_T color,
                                         FACE_INDEX_INT_T faceIndex,
                                         FACE_AMBIENT_OCCLUSION_STRUCT_T ao,
                                         bool vLighting,
                                         VERTEX_LIGHT_STRUCT_T vlight1,
                                         VERTEX_LIGHT_STRUCT_T vlight2,
                                         VERTEX_LIGHT_STRUCT_T vlight3,
                                         VERTEX_LIGHT_STRUCT_T vlight4);

/// @param current is true, bmaw is done writing in current bma only
void vertex_buffer_mem_area_writer_done(VertexBufferMemAreaWriter *vbmaw, const bool current);

// a vb may optionally write to a lighting buffer ie. if it belongs to the map shape w/ octree
VertexBuffer *vertex_buffer_new(bool transparent, bool isVertexAttributes);
VertexBuffer *vertex_buffer_new_with_max_count(uint32_t n,
                                               bool transparent,
                                               bool isVertexAttributes);

void vertex_buffer_free(VertexBuffer *vb);
void vertex_buffer_free_all(VertexBuffer *front);

bool vertex_buffer_has_capacity(const VertexBuffer *vb, const size_t count);
bool vertex_buffer_has_room_for_new_chunk(const VertexBuffer *vb);

// inserts vb1 after vb2
void vertex_buffer_insert_after(VertexBuffer *vb1, VertexBuffer *vb2);

VertexBuffer *vertex_buffer_get_next(const VertexBuffer *vb);
VertexBufferMemArea *vertex_buffer_get_first_mem_area(const VertexBuffer *vb);

uint32_t vertex_buffer_get_id(const VertexBuffer *vb);

void *vertex_buffer_get_buffer(const VertexBuffer *vb);
DoublyLinkedList *vertex_buffer_get_draw_slices(const VertexBuffer *vb);

void vertex_buffer_log_draw_slices(const VertexBuffer *vb);

void vertex_buffer_add_draw_slice(VertexBuffer *vb, uint32_t start, uint32_t count);
void vertex_buffer_fill_draw_slices(VertexBuffer *vb);
void vertex_buffer_flush_draw_slices(VertexBuffer *vb);
uint16_t vertex_buffer_get_nb_draw_slices(const VertexBuffer *vb);

uint32_t vertex_buffer_get_count(const VertexBuffer *vb);
uint32_t vertex_buffer_get_max_count(const VertexBuffer *vb);

bool vertex_buffer_is_fragmented(const VertexBuffer *vb);

void vertex_buffer_fill_gaps(VertexBuffer *vb, const bool mergeOnly);

void vertex_buffer_mem_area_make_gap(VertexBufferMemArea *vbma, bool transparent);
void vertex_buffer_mem_area_flush(VertexBufferMemArea *vbma);

Chunk *vertex_buffer_mem_area_get_chunk(const VertexBufferMemArea *vbma);
VertexBuffer *vertex_buffer_mem_area_get_vb(const VertexBufferMemArea *vbma);
uint32_t vertex_buffer_mem_area_get_start_idx(const VertexBufferMemArea *vbma);
uint32_t vertex_buffer_mem_area_get_count(const VertexBufferMemArea *vbma);
VertexBufferMemArea *vertex_buffer_mem_area_get_global_next(VertexBufferMemArea *vbma);
VertexBufferMemArea *vertex_buffer_mem_area_get_group_next(VertexBufferMemArea *vbma);

bool vertex_buffer_has_dirty_mem_areas(const VertexBuffer *vb);

void vertex_buffer_log_mem_areas(const VertexBuffer *vb);

void vertex_buffer_set_lighting_enabled(bool value);
bool vertex_buffer_get_lighting_enabled(void);

#ifdef __cplusplus
} // extern "C"
#endif
