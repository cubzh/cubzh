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

// 'faces' buffer contains face center position as RGBA32F [X:Y:Z:color]
#define DRAWBUFFER_FACES 4
// face 'metadata' buffer as RG8 [ao:face+aoShift]
#define DRAWBUFFER_METADATA 2
// vertex 'lighting' buffer as RG8 [sun+r:g+b]
#define DRAWBUFFER_LIGHTING 2
#define DRAWBUFFER_LIGHTING_PER_FACE DRAWBUFFER_LIGHTING * 4
#define DRAWBUFFER_FACES_BYTES DRAWBUFFER_FACES * sizeof(float)
#define DRAWBUFFER_METADATA_BYTES DRAWBUFFER_METADATA * sizeof(uint8_t)
#define DRAWBUFFER_LIGHTING_BYTES DRAWBUFFER_LIGHTING * sizeof(uint8_t)
#define DRAWBUFFER_LIGHTING_PER_FACE_BYTES DRAWBUFFER_LIGHTING_BYTES * 4

extern bool vertex_buffer_pop_destroyed_id(uint32_t *id);

// one draw per vertex buffer
// vertex buffers can be listed, for example when a shape requires more than one

struct {
    uint32_t from, to;
} typedef DrawBufferWriteSlice;

// Buffers maintained by VertexBuffer used by renderer for each draw call
// To be used as value-type simply to keep the buffer pointers together
struct {
    float *faces;      // RGBA32F  [X:Y:Z:color]
    uint8_t *metadata; // RG8      [ao:face+aoShift]
    uint8_t *lighting; // RG8      [sun+r:g+b]
} typedef DrawBufferPtrs;

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
                                         float x,
                                         float y,
                                         float z,
                                         ATLAS_COLOR_INDEX_INT_T color,
                                         FACE_INDEX_INT_T index,
                                         FACE_AMBIENT_OCCLUSION_STRUCT_T ao,
                                         // vertex lighting ie. smooth lighting
                                         VERTEX_LIGHT_STRUCT_T vlight1,
                                         VERTEX_LIGHT_STRUCT_T vlight2,
                                         VERTEX_LIGHT_STRUCT_T vlight3,
                                         VERTEX_LIGHT_STRUCT_T vlight4);

void vertex_buffer_mem_area_writer_done(VertexBufferMemAreaWriter *vbmaw);

// a vb may optionally write to a lighting buffer ie. if it belongs to the map shape w/ octree
VertexBuffer *vertex_buffer_new(bool lighting, bool transparent);
VertexBuffer *vertex_buffer_new_with_max_count(size_t n, bool lighting, bool transparent);

void vertex_buffer_free(VertexBuffer *vb);
void vertex_buffer_free_all(VertexBuffer *front);

bool vertex_buffer_is_not_full(const VertexBuffer *vb);
bool vertex_buffer_has_room_for_new_chunk(const VertexBuffer *vb);

// inserts vb1 after vb2
void vertex_buffer_insert_after(VertexBuffer *vb1, VertexBuffer *vb2);

VertexBuffer *vertex_buffer_get_next(const VertexBuffer *vb);

uint32_t vertex_buffer_get_id(const VertexBuffer *vb);

DrawBufferPtrs vertex_buffer_get_draw_buffers(const VertexBuffer *vb);
DoublyLinkedList *vertex_buffer_get_draw_slices(const VertexBuffer *vb);

void vertex_buffer_log_draw_slices(const VertexBuffer *vb);

void vertex_buffer_add_draw_slice(VertexBuffer *vb, uint32_t start, uint32_t count);
void vertex_buffer_fill_draw_slices(VertexBuffer *vb);
void vertex_buffer_flush_draw_slices(VertexBuffer *vb);
size_t vertex_buffer_get_nb_draw_slices(const VertexBuffer *vb);

size_t vertex_buffer_get_nb_vertices(const VertexBuffer *vb);
size_t vertex_buffer_get_max_length(const VertexBuffer *vb);

bool vertex_buffer_is_fragmented(const VertexBuffer *vb);

bool vertex_buffer_is_enlisted(const VertexBuffer *vb);
void vertex_buffer_set_enlisted(VertexBuffer *vb, const bool b);

void vertex_buffer_fill_gaps(VertexBuffer *vb);

void vertex_buffer_mem_area_make_gap(VertexBufferMemArea *vbma, bool transparent);
void vertex_buffer_mem_area_flush(VertexBufferMemArea *vbma);

VertexBuffer *vertex_buffer_mem_area_get_vb(VertexBufferMemArea *vbma);
VertexBufferMemArea *vertex_buffer_mem_area_get_group_next(VertexBufferMemArea *vbma);

bool vertex_buffer_has_dirty_mem_areas(const VertexBuffer *vb);

void vertex_buffer_log_mem_areas(const VertexBuffer *vb);

void vertex_buffer_set_lighting_enabled(bool value);
bool vertex_buffer_get_lighting_enabled(void);

#ifdef __cplusplus
} // extern "C"
#endif
