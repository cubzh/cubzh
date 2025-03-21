// -------------------------------------------------------------
//  Cubzh Core
//  vertextbuffer.c
//  Created by Adrien Duermael on July 7, 2017.
// -------------------------------------------------------------

#include "vertextbuffer.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "cclog.h"
#include "chunk.h"
#include "config.h"
#include "filo_list_uint32.h"

#ifdef DEBUG
#define VERTEX_BUFFER_DEBUG 1
#else
#define VERTEX_BUFFER_DEBUG 0
#endif

// takes the 4 low bits of a and casts into uint8_t
#define TO_UINT4(a) (uint8_t)((a) & 0x0F)

// Vertex buffers are used from outside Cubzh Core
// when implementing renderers (like Swift/Metal renderer)
// Giving each vertex buffer a proper ID is useful to know when
// they need to be referenced/unreferenced
static uint32_t vertex_buffer_next_id = 0;
static FiloListUInt32 *vertex_buffer_destroyed_ids = NULL;

static uint32_t vertex_buffer_get_new_id(void) {
    uint32_t i = vertex_buffer_next_id;
    vertex_buffer_next_id++; // TODO: mutex
    return i;
}

static void vertex_buffer_add_destroyed_id(uint32_t id) {
    if (vertex_buffer_destroyed_ids == NULL) {
        vertex_buffer_destroyed_ids = filo_list_uint32_new();
    }
    filo_list_uint32_push(vertex_buffer_destroyed_ids, id);
}

bool vertex_buffer_pop_destroyed_id(uint32_t *id) {
    return filo_list_uint32_pop(vertex_buffer_destroyed_ids, id);
}

struct _VertexBufferMemArea {
    // where to start writing bytes
    VertexAttributes *start; /* 8 bytes */

    // vertex buffer that owns the mem area
    VertexBuffer *vb; /* 8 bytes */

    // allows to merge consecutive gaps
    // chunk == NULL means the mem area is a gap
    Chunk *chunk; /* 8 bytes */

    VertexBufferMemArea *_globalListNext;     /* 8 bytes */
    VertexBufferMemArea *_globalListPrevious; /* 8 bytes */

    // next area that belongs to the same group
    // (same chunk or gaps)
    VertexBufferMemArea *_groupListNext; /* 8 bytes */
    // previous area that belongs to the same group
    // (same chunk or gaps)
    VertexBufferMemArea *_groupListPrevious; /* 8 bytes */

    // indexing within owner buffer
    uint32_t startIdx; /* 4 bytes */
    uint32_t count;    /* 4 bytes */

    // Dirty vbma will be re-uploaded next render
    bool dirty; /* 1 byte */

    // padding
    char pad[7];
};

VertexBufferMemArea *vertex_buffer_mem_area_new(VertexBuffer *vb,
                                                VertexAttributes *start,
                                                uint32_t startIdx,
                                                uint32_t count);
void vertex_buffer_mem_area_free_all(VertexBufferMemArea *front);
bool vertex_buffer_mem_area_assign_to_chunk(VertexBufferMemArea *vbma,
                                            Chunk *chunk,
                                            bool transparent);
void vertex_buffer_new_empty_gap_at_end(VertexBuffer *vb);
VertexBufferMemArea *vertex_buffer_mem_area_split_and_make_gap(VertexBufferMemArea *vbma,
                                                               uint32_t vbma_size);
bool vertex_buffer_mem_area_is_gap(const VertexBufferMemArea *vbma);
bool vertex_buffer_mem_area_is_null_or_empty(const VertexBufferMemArea *vbma);
void vertex_buffer_mem_area_free(VertexBufferMemArea *vbma);
bool vertex_buffer_mem_area_insert_after(VertexBufferMemArea *vbma1,
                                         VertexBufferMemArea *vbma2,
                                         bool transparent);

void vertex_buffer_mem_area_leave_group_list(VertexBufferMemArea *vbma, bool transparent);
void vertex_buffer_mem_area_leave_global_list(VertexBufferMemArea *vbma);

void _vertex_buffer_memcpy(VertexAttributes *dst,
                           VertexAttributes *src,
                           size_t count,
                           size_t offset);
VertexAttributes *_vertex_buffer_data_add_ptr(VertexAttributes *ptr, size_t count);

// debug
#if VERTEX_BUFFER_DEBUG == 1
void vertex_buffer_check_mem_area_chain(VertexBuffer *vb);
#endif // VERTEX_BUFFER_DEBUG == 1

//---------------------
// MARK: VertexBuffer
//---------------------

// Only one buffer will be allocated for a small shape, but bigger ones
// may need more, there will be one draw call per buffer
struct _VertexBuffer {
    VertexAttributes *data; /* 8 bytes */
    // draw write slices define data index ranges that need re-upload after a structural change
    // populated when updating chunks during shape_refresh_vertices()
    // flushed by renderer calling vertex_buffer_flush_draw_slices() after re-upload
    DoublyLinkedList *drawSlices; /* 8 bytes */

    // mem areas used by chunks to store vertices
    // (references to memory areas within vertex buffer)
    VertexBufferMemArea *firstMemArea; /* 8 bytes */
    VertexBufferMemArea *lastMemArea;  /* 8 bytes */

    // list of mem areas that are not used by any chunk
    VertexBufferMemArea *firstMemAreaGap; /* 8 bytes */
    VertexBufferMemArea *lastMemAreaGap;  /* 8 bytes */

    // vertex buffer can be enlisted
    VertexBuffer *next; /* 8 bytes */

    // vertex buffer's unique id
    uint32_t id; /* 4 bytes */

    // how many vertices can fit with the size allocated for mem areas
    // when reaching this amount, a different vb must be used
    uint32_t maxCount; /* 4 bytes */
    uint32_t count;    /* 4 bytes */

    // draw write slices count
    uint16_t nbDrawSlices; /* 2 bytes */

    bool isTransparent; /* 1 byte */

    char pad[1];
};

// vb optionally writes lighting data
static bool vertex_buffer_lighting_enabled = true;

// MARK: DEBUG UTILS
#if VERTEX_BUFFER_DEBUG == 1
typedef struct {
    uint32_t nbVertices;
    bool isGap;
    char chunkID[64];
    char pad[3];
} VbmaRepresentation;

typedef struct {
    VbmaRepresentation *vbmas;
    uint32_t n;
    char pad[4];
} VbSnapshot;

VbSnapshot *vertex_buffer_snapshot(const VertexBuffer *vb) {

    VbSnapshot *vbs = (VbSnapshot *)malloc(sizeof(VbSnapshot));
    if (vbs == NULL) {
        return NULL;
    }
    vbs->n = 0;

    // determine number of mem areas
    VertexBufferMemArea *vbma = vb->firstMemArea;
    while (vbma != NULL) {
        vbs->n++;
        vbma = vbma->_globalListNext;
    }

    vbs->vbmas = (VbmaRepresentation *)malloc(sizeof(VbmaRepresentation) * vbs->n);
    if (vbs->vbmas == NULL) {
        free(vbs);
        return NULL;
    }

    //
    vbma = vb->firstMemArea;
    int i = 0;
    while (vbma != NULL) {
        vbs->vbmas[i].nbVertices = vbma->count;
        vbs->vbmas[i].isGap = vbma->chunk == NULL;
        if (vbma->chunk != NULL) {
            sprintf(vbs->vbmas[i].chunkID, "%p", (void *)vbma->chunk);
        } else {
            snprintf(vbs->vbmas[i].chunkID, 4, "GAP");
        }
        i++;
        vbma = vbma->_globalListNext;
    }

    return vbs;
}

void vertex_buffer_snapshot_free(VbSnapshot *vbs) {
    free(vbs->vbmas);
    free(vbs);
}

void vertex_buffer_log_diff(VbSnapshot *snap1, VbSnapshot *snap2) {

    uint32_t nb1 = 0;
    uint32_t nb2 = 0;

    for (uint32_t i = 0; i < snap1->n || i < snap2->n; i++) {
        if (i < snap1->n) {
            if (snap1->vbmas[i].isGap == false) {
                nb1 += snap1->vbmas[i].nbVertices;
            }
            cclog_info("[%04u] - %16s", snap1->vbmas[i].nbVertices, snap1->vbmas[i].chunkID);
        } else {
            cclog_info("[%04u] - %16s", 0, "EMPTY");
        }

        cclog_trace(" | ");

        if (i < snap2->n) {
            if (snap2->vbmas[i].isGap == false) {
                nb2 += snap2->vbmas[i].nbVertices;
            }
            cclog_info("[%04u] - %16s", snap2->vbmas[i].nbVertices, snap2->vbmas[i].chunkID);
        }
    }

    cclog_info("[%04u] - %16s", nb1, "TOTAL");
    cclog_trace(" | ");
    cclog_info("[%04u] - %16s", nb2, "TOTAL");
}
// END DEBUG UTILS
#endif

VertexBuffer *vertex_buffer_new(bool transparent) {
    return vertex_buffer_new_with_max_count(SHAPE_BUFFER_MAX_COUNT, transparent);
}

VertexBuffer *vertex_buffer_new_with_max_count(uint32_t n, bool transparent) {
    VertexBuffer *vb = (VertexBuffer *)malloc(sizeof(VertexBuffer));
    if (vb == NULL) {
        return NULL;
    }
    vb->id = vertex_buffer_get_new_id();

    // this represents the maximum number of faces from all chunks in that vertex buffer
    vb->maxCount = n;

    // pointers to first and last mem areas
    vb->firstMemArea = NULL;
    vb->lastMemArea = NULL;
    vb->firstMemAreaGap = NULL;
    vb->lastMemAreaGap = NULL;

    vb->count = 0;
    // nothing to initialize, the vertices won't be used if count == 0

    vb->next = NULL;

    // container for draw buffers pointer
    vb->data = (VertexAttributes *)malloc(n * DRAWBUFFER_VERTICES_BYTES);

    vb->drawSlices = doubly_linked_list_new();
    vb->nbDrawSlices = 0;

    vb->isTransparent = transparent;

    return vb;
}

void vertex_buffer_count_incr(VertexBuffer *vb, uint32_t v) {
    vb->count += v;
#if VERTEX_BUFFER_DEBUG == 1
    if (vb->count > vb->maxCount) {
        cclog_debug("⚠️⚠️⚠️ vertex_buffer_count_incr too many vertices!");
    }
#endif
}

void vertex_buffer_count_decr(VertexBuffer *vb, uint32_t v) {
    vb->count -= v;
#if VERTEX_BUFFER_DEBUG == 1
    if (vb->count > vb->maxCount) {
        cclog_debug("⚠️⚠️⚠️ vertex_buffer_count_decr too many vertices!");
    }
#endif
}

bool vertex_buffer_is_fragmented(const VertexBuffer *vb) {
    return (vb->firstMemAreaGap != NULL);
}

void vertex_buffer_free(VertexBuffer *vb) {
    vertex_buffer_add_destroyed_id(vb->id);

    free(vb->data);
    vertex_buffer_mem_area_free_all(vb->firstMemArea);

    doubly_linked_list_flush(vb->drawSlices, free);
    doubly_linked_list_free(vb->drawSlices);

    //!\\ vb->next has to be freed manually or using vertex_buffer_free_all
    free(vb);
}

void vertex_buffer_free_all(VertexBuffer *front) {
    VertexBuffer *vb = front;
    VertexBuffer *tmp;
    while (vb != NULL) {
        tmp = vb;
        vb = vb->next;
        vertex_buffer_free(tmp);
    }
}

bool vertex_buffer_is_not_full(const VertexBuffer *vb) {
    return vb != NULL && vb->count < vb->maxCount;
}

void vertex_buffer_insert_after(VertexBuffer *vb1, VertexBuffer *vb2) {
    if (vb2 == NULL)
        return;
    vb1->next = vb2->next;
    vb2->next = vb1;
}

VertexBuffer *vertex_buffer_get_next(const VertexBuffer *vb) {
    return vb->next;
}

VertexBufferMemArea *vertex_buffer_get_first_mem_area(const VertexBuffer *vb) {
    return vb->firstMemArea;
}

uint32_t vertex_buffer_get_id(const VertexBuffer *vb) {
    return vb->id;
}

VertexAttributes *vertex_buffer_get_draw_buffer(const VertexBuffer *vb) {
    return vb->data;
}

DoublyLinkedList *vertex_buffer_get_draw_slices(const VertexBuffer *vb) {
    return vb->drawSlices;
}

void vertex_buffer_log_draw_slices(const VertexBuffer *vb) {
    if (vb->nbDrawSlices > 0) {
        cclog_trace("-- DRAW SLICES --");
        DoublyLinkedListNode *itr = doubly_linked_list_first(vb->drawSlices);
        DrawBufferWriteSlice *ws;
        while (itr != NULL) {
            ws = (DrawBufferWriteSlice *)doubly_linked_list_node_pointer(itr);
            cclog_info("[%d,%d]", ws->from, ws->to);
            itr = doubly_linked_list_node_next(itr);
        }
        cclog_trace("-----------------");
    }
}

void vertex_buffer_add_draw_slice(VertexBuffer *vb, uint32_t start, uint32_t count) {
    if (count == 0) {
        cclog_error("⚠️ vertex_buffer_add_draw_slice: empty, slice skipped");
        return;
    }
    DrawBufferWriteSlice value = {start, start + count - 1};

    DrawBufferWriteSlice *leftMerged = NULL, *rightMerged = NULL;
    DoublyLinkedListNode *rightMergedNode = NULL;
    DoublyLinkedListNode *itr = doubly_linked_list_first(vb->drawSlices);
    DrawBufferWriteSlice *ws;
    while (itr != NULL) {
        ws = (DrawBufferWriteSlice *)doubly_linked_list_node_pointer(itr);
        if (value.from == ws->to + 1) {
            ws->to = value.to;
            leftMerged = ws;
        } else if (value.to == ws->from - 1) {
            ws->from = value.from;
            rightMerged = ws;
            rightMergedNode = itr;
        }
        itr = doubly_linked_list_node_next(itr);
    }
    // reduce if merged right & left, or insert if not merged at all
    if (leftMerged != NULL && rightMerged != NULL) {
        leftMerged->to = rightMerged->to;
        doubly_linked_list_delete_node(vb->drawSlices, rightMergedNode);
        free(rightMerged);
        vb->nbDrawSlices--;
    } else if (leftMerged == NULL && rightMerged == NULL) {
        DrawBufferWriteSlice *node = (DrawBufferWriteSlice *)malloc(sizeof(DrawBufferWriteSlice));
        if (node != NULL) {
            node->from = value.from;
            node->to = value.to;
            doubly_linked_list_push_last(vb->drawSlices, node);
            vb->nbDrawSlices++;
        }
    }
}

void vertex_buffer_fill_draw_slices(VertexBuffer *vb) {
    VertexBufferMemArea *vbma = vb->firstMemArea;
    uint32_t idx = 0;
    while (vbma != NULL) {
        if (vbma->dirty) {
            if (vertex_buffer_mem_area_is_gap(vbma) == false) {
                vertex_buffer_add_draw_slice(vb, idx, vbma->count);
            }
            vbma->dirty = false;
        }
        idx += vbma->count;
        vbma = vbma->_globalListNext;
    }
}

void vertex_buffer_flush_draw_slices(VertexBuffer *vb) {
    // just for safety, but normally draw slices were consumed before calling this
    doubly_linked_list_flush(vb->drawSlices, free);
    vb->nbDrawSlices = 0;
}

uint16_t vertex_buffer_get_nb_draw_slices(const VertexBuffer *vb) {
    return vb->nbDrawSlices;
}

uint32_t vertex_buffer_get_count(const VertexBuffer *vb) {
    return vb->count;
}

uint32_t vertex_buffer_get_max_count(const VertexBuffer *vb) {
    return vb->maxCount;
}

void vertex_buffer_mem_area_remove(VertexBufferMemArea *vbma, bool transparent) {
    // leave group list
    vertex_buffer_mem_area_leave_group_list(vbma, transparent);

#if VERTEX_BUFFER_DEBUG == 1
    if (vbma->_globalListNext == NULL && vbma->vb->lastMemArea != vbma) {
        cclog_debug("⚠️⚠️⚠️ vbma->_globalListNext == NULL though not lastMemArea");
    }
#endif

    // remove from main list
    vertex_buffer_mem_area_leave_global_list(vbma);

    vertex_buffer_mem_area_free(vbma);
}

void vertex_buffer_remove_last_mem_area(VertexBuffer *vb) {
    vertex_buffer_count_decr(vb, vb->lastMemArea->count);
    vertex_buffer_mem_area_remove(vb->lastMemArea, vb->isTransparent);
}

// reorganizes data to fill the gaps
void vertex_buffer_fill_gaps(VertexBuffer *vb) {
#if VERTEX_BUFFER_DEBUG == 1
    vertex_buffer_check_mem_area_chain(vb);
#endif

    // no gap remaining at the end of this function
    vb->firstMemAreaGap = NULL;

    // here we know there are gaps, and none of them is at the end
    // of global mem area list

    // vb->firstMemAreaGap may not be the first gap in the
    // global mem area list... So need to start filling up the
    // first gap in the global list.

    // start at first mem area
    VertexBufferMemArea *cursor = vb->firstMemArea;
    VertexBufferMemArea *vbma;

    while (cursor != NULL) {
        // loop until finding a gap to fill
        while (cursor != NULL && vertex_buffer_mem_area_is_gap(cursor) == false) {

            // merge with following mem areas referencing same chunk
            // also destroy mem areas with 0 vertices
            while (cursor->_globalListNext != NULL &&
                   (cursor->_globalListNext->chunk == cursor->chunk ||
                    cursor->_globalListNext->count == 0)) {

                // vbma that will be destroyed
                vbma = cursor->_globalListNext;
                cursor->count += vbma->count; // can be 0
                // maintain dirty flag
                if (vbma->count > 0 && vbma->dirty) {
                    cursor->dirty = true;
                }

                vertex_buffer_mem_area_remove(vbma, vb->isTransparent);
            }

            cursor = cursor->_globalListNext;
        }

        // already reached the end of the list
        if (cursor == NULL) {
            break;
        }

        // HERE: cursor is a gap & not the end of the list

#if VERTEX_BUFFER_DEBUG == 1
        if (cursor->chunk != NULL) {
            cclog_debug("⚠️⚠️⚠️ cursor is supposed to be a gap");
        }

        if (cursor->_globalListNext == NULL && cursor != vb->lastMemArea) {
            cclog_debug("⚠️⚠️⚠️ cursor is supposed to be vb->lastMemArea (1)");
        }
#endif

        // merge gap pointed by cursor with following gaps
        // also destroy mem areas with 0 vertices
        while (cursor->_globalListNext != NULL &&
               (vertex_buffer_mem_area_is_gap(cursor->_globalListNext) == true ||
                cursor->_globalListNext->count == 0)) {

#if VERTEX_BUFFER_DEBUG == 1
            if (cursor->chunk != NULL) {
                cclog_debug("⚠️⚠️⚠️ cursor is supposed to be a gap");
            }
#endif
            // vbma that will be destroyed
            vbma = cursor->_globalListNext;
            cursor->count += vbma->count; // can be 0

#if VERTEX_BUFFER_DEBUG == 1
            if (cursor->_globalListNext->_globalListPrevious != cursor) {
                cclog_debug("⚠️⚠️⚠️ global list chain error (1)");
            }
#endif

#if VERTEX_BUFFER_DEBUG == 1
            if (vbma->_globalListPrevious != cursor) {
                cclog_debug("⚠️⚠️⚠️ global list chain error (2)");
            }
#endif

            vertex_buffer_mem_area_remove(vbma, vb->isTransparent);

#if VERTEX_BUFFER_DEBUG == 1
            if (cursor->_globalListNext == NULL) {
                if (cursor->_globalListPrevious == NULL) {
                    cclog_debug("⚠️⚠️⚠️ cursor not enlisted!");
                }
                if (cursor != vb->lastMemArea) {
                    cclog_debug("⚠️⚠️⚠️ cursor is supposed to be vb->lastMemArea (3)");
                }
            }
#endif
        }

        // at this point: no gap after gap pointed by cursor
        // and no vbma with size of 0
#if VERTEX_BUFFER_DEBUG == 1
        if (cursor->_globalListNext != NULL &&
            (vertex_buffer_mem_area_is_gap(cursor->_globalListNext) == true ||
             cursor->_globalListNext->count == 0)) {

            cclog_debug("⚠️⚠️⚠️ error when merging gaps");
        }
        if (vertex_buffer_mem_area_is_gap(cursor) == false) {
            cclog_debug("⚠️⚠️⚠️ cursor is supposed to be a gap");
        }
#endif

        // already reached the end of the list
        if (cursor->_globalListNext == NULL) {
#if VERTEX_BUFFER_DEBUG == 1
            if (cursor != vb->lastMemArea) {
                cclog_debug("⚠️⚠️⚠️ cursor is supposed to be vb->lastMemArea (2)");
            }
#endif
            vertex_buffer_remove_last_mem_area(vb);
            break; // breaks main loop
        }

        uint32_t written = 0;

        // loop until gap is filled with vertices
        // taking them from non gap mem areas at the end of the list
        while (written < cursor->count) {
            // options
            // 1) cursor == vb->lastMemArea
            // -> split and remove last part, or remove whole gap if written==0
            // -> BREAK
            if (cursor == vb->lastMemArea) {
                if (written > 0) {
                    vertex_buffer_mem_area_split_and_make_gap(cursor, written);
                }
                // remove created gap or mem area if written == 0
                vertex_buffer_remove_last_mem_area(vb);
                // maintain cursor == vb->lastMemArea to exit main loop
                cursor = vb->lastMemArea;
                break;
            }
            // 2) vb->lastMemArea is an other gap
            // -> remove it and continue
            else if (vertex_buffer_mem_area_is_gap(vb->lastMemArea)) {
                vertex_buffer_remove_last_mem_area(vb);
                continue;
            }
            // 3) vb->lastMemArea is not a gap but has no vertices
            // -> remove it and continue
            else if (vb->lastMemArea->count == 0) {
                vertex_buffer_remove_last_mem_area(vb);
                continue;
            }

            // HERE: lastMemArea is not a gap and has vertices

            if (vertex_buffer_mem_area_is_gap(cursor)) {
                // assign to same chunk as last mem area
                vertex_buffer_mem_area_insert_after(cursor, vb->lastMemArea, vb->isTransparent);
            }

            // 1) chunk is different than the one being written
            // -> if written == 0, make it gap again
            // -> otherwise split
            // -> BREAK
            if (cursor->chunk != vb->lastMemArea->chunk) {
                if (written == 0) {
                    // make it a gap again
                    cclog_warning("⚠️ vertex_buffer_fill_gaps: gap is skipped");
                    vertex_buffer_mem_area_make_gap(cursor, vb->isTransparent);
                } else {
                    vertex_buffer_mem_area_split_and_make_gap(cursor, written);
                    // gap can't be removed because not at last position
                }
                break;
            }
            // 2) rightVbma has exact amount of vertices:
            // -> memcpy all, remove last vbma
            // -> LOOP WILL EXIT
            else if (cursor->count == vb->lastMemArea->count) {
                _vertex_buffer_memcpy(cursor->start,
                                      vb->lastMemArea->start,
                                      vb->lastMemArea->count,
                                      0);
                cursor->dirty = true;

                written += vb->lastMemArea->count;

                vertex_buffer_remove_last_mem_area(vb);
                continue;
            }
            // 3) last vbma has enough vertices:
            // -> memcpy end of rightVbma, split, remove last part
            // -> LOOP WILL EXIT
            else if (cursor->count < vb->lastMemArea->count) {
                uint32_t diff = vb->lastMemArea->count - cursor->count;

                _vertex_buffer_memcpy(cursor->start, vb->lastMemArea->start, cursor->count, diff);
                cursor->dirty = true;

                written += cursor->count;

                vertex_buffer_mem_area_split_and_make_gap(vb->lastMemArea, diff);

                vertex_buffer_remove_last_mem_area(vb);
            }
            // 4) last vbma has not enough vertices:
            // -> memcpy all, split gap, remove last vbma
            else {
                _vertex_buffer_memcpy(cursor->start,
                                      vb->lastMemArea->start,
                                      vb->lastMemArea->count,
                                      0);
                cursor->dirty = true;

                written += vb->lastMemArea->count;

                vertex_buffer_mem_area_split_and_make_gap(cursor, written);

                vertex_buffer_remove_last_mem_area(vb);
            }
        } // end while (loop until gap is filled with vertices)

#if VERTEX_BUFFER_DEBUG == 1
        if (cursor == NULL) {
            cclog_debug("⚠️⚠️⚠️ cursor shouldn't be NULL");
        }
#endif

        cursor = cursor->_globalListNext;

    } // end of main loop: while (cursor != NULL)
#if VERTEX_BUFFER_DEBUG == 1
    vertex_buffer_check_mem_area_chain(vb);
#endif
}

//---------------------
// MARK: Draw buffers
//---------------------

void _vertex_buffer_memcpy(VertexAttributes *dst,
                           VertexAttributes *src,
                           size_t count,
                           size_t offset) {
    memcpy(dst, src + offset, count * DRAWBUFFER_VERTICES_BYTES);
}

VertexAttributes *_vertex_buffer_data_add_ptr(VertexAttributes *ptr, size_t count) {
    ptr += count;
    return ptr;
}

//---------------------
// MARK: VertexBufferMemArea
//---------------------

bool vertex_buffer_mem_area_is_gap(const VertexBufferMemArea *vbma) {
    return vbma->chunk == NULL;
}

bool vertex_buffer_mem_area_is_null_or_empty(const VertexBufferMemArea *vbma) {
    return vbma == NULL || vbma->count == 0;
}

// creates new VertexBufferMemArea
VertexBufferMemArea *vertex_buffer_mem_area_new(VertexBuffer *vb,
                                                VertexAttributes *start,
                                                uint32_t startIdx,
                                                uint32_t count) {
    VertexBufferMemArea *vbma = (VertexBufferMemArea *)malloc(sizeof(VertexBufferMemArea));
    if (vbma == NULL) {
        return NULL;
    }
    vbma->vb = vb;
    vbma->_globalListNext = NULL;
    vbma->_globalListPrevious = NULL;
    vbma->_groupListNext = NULL;
    vbma->_groupListPrevious = NULL;
    vbma->chunk = NULL;
    vbma->startIdx = startIdx;
    vbma->count = count;
    vbma->start = start;
    vbma->dirty = false;
    return vbma;
}

void vertex_buffer_mem_area_free(VertexBufferMemArea *vbma) {
    free(vbma);
}

void vertex_buffer_mem_area_leave_group_list(VertexBufferMemArea *vbma, bool transparent) {
    // maybe it is the front mem area of chunk (if not a gap)
    if (vertex_buffer_mem_area_is_gap(vbma) == false) {
        if (chunk_get_vbma(vbma->chunk, transparent) == vbma) {
            chunk_set_vbma(vbma->chunk, vbma->_groupListNext, transparent);
        }
    } else { // not the front mem area of a chunk
        if (vbma == vbma->vb->firstMemAreaGap) {
            vbma->vb->firstMemAreaGap = vbma->_groupListNext;
        }
        if (vbma == vbma->vb->lastMemAreaGap) {
            vbma->vb->lastMemAreaGap = vbma->_groupListPrevious;
        }
    }

    if (vbma->_groupListNext != NULL) {
        vbma->_groupListNext->_groupListPrevious = vbma->_groupListPrevious;
    }
    if (vbma->_groupListPrevious != NULL) {
        vbma->_groupListPrevious->_groupListNext = vbma->_groupListNext;
    }

    vbma->_groupListNext = NULL;
    vbma->_groupListPrevious = NULL;
}

void vertex_buffer_mem_area_leave_global_list(VertexBufferMemArea *vbma) {

#if VERTEX_BUFFER_DEBUG == 1
    if (vbma->_globalListNext == NULL && vbma != vbma->vb->lastMemArea) {
        cclog_debug("⚠️⚠️⚠️ vbma should be last mem area or have non NULL _globalListNext");
    }

    if (vbma->_globalListNext != NULL && vbma == vbma->vb->lastMemArea) {
        cclog_debug("⚠️⚠️⚠️ vbma shouldn't be last mem area (non NULL _globalListNext)");
    }
#endif

    if (vbma == vbma->vb->lastMemArea) {
        // printf("new last mem area: %p\n", vbma->_globalListPrevious);
        vbma->vb->lastMemArea = vbma->_globalListPrevious;
    }

    if (vbma == vbma->vb->firstMemArea) {
        vbma->vb->firstMemArea = vbma->_globalListNext;
    }

    if (vbma->_globalListNext != NULL) {
        vbma->_globalListNext->_globalListPrevious = vbma->_globalListPrevious;
    }
    if (vbma->_globalListPrevious != NULL) {
        vbma->_globalListPrevious->_globalListNext = vbma->_globalListNext;
    }

    vbma->_globalListNext = NULL;
    vbma->_globalListPrevious = NULL;
}

// this is used to create a new mem area at the end, as only gaps
// can be used by chunks. The mem area will have a size of zero, but
// the last mem area is allowed to increase in size as vertices are added
//!\\ if this gap gets assigned to a chunk without being written, another
// empty gap can be added pointing to the same location in vertex buffer's
// vertices. This one would then become useless, empty forever until it
// finally/eventually gets merged with another gap.
void vertex_buffer_new_empty_gap_at_end(VertexBuffer *vb) {
    VertexAttributes *start;
    uint32_t startdIdx;

    if (vb->lastMemArea != NULL) {
        start = _vertex_buffer_data_add_ptr(vb->lastMemArea->start, vb->lastMemArea->count);
        startdIdx = vb->lastMemArea->startIdx + vb->lastMemArea->count;
    } else {
        // no lastMemArea means no mem area at all
        // so we should start at beginning of the buffers in vb->data
        start = vb->data;
        startdIdx = 0;
    }

    VertexBufferMemArea *memArea = vertex_buffer_mem_area_new(vb, start, startdIdx, 0);

    // if firstMemArea == NULL, lastMemArea has to be NULL
    // it simply means the vertex buffer has no mem area yet
    if (vb->firstMemArea == NULL) {
        vb->firstMemArea = memArea;
        vb->lastMemArea = memArea;
    } else if (vb->lastMemArea != NULL) { // add as last mem area
        vb->lastMemArea->_globalListNext = memArea;
        memArea->_globalListPrevious = vb->lastMemArea;
        vb->lastMemArea = memArea;
    }

    // enlist with other gaps if some exist already
    if (vb->firstMemAreaGap == NULL) {
        vb->firstMemAreaGap = memArea;
        vb->lastMemAreaGap = memArea;
    } else {
        vb->lastMemAreaGap->_groupListNext = memArea;
        memArea->_groupListPrevious = vb->lastMemAreaGap;
        vb->lastMemAreaGap = memArea;
    }
#if VERTEX_BUFFER_DEBUG == 1
    vertex_buffer_check_mem_area_chain(vb);
#endif
}

// assigns mem area to chunk, only works if mem area is a gap
// it's not possible to move a mem area from one chunk to another without
// going through the gap state
// returns true on success, false otherwise
bool vertex_buffer_mem_area_assign_to_chunk(VertexBufferMemArea *vbma,
                                            Chunk *chunk,
                                            bool transparent) {

    if (vertex_buffer_mem_area_is_gap(vbma) == false) {
        return false;
    }

    vertex_buffer_mem_area_leave_group_list(vbma, transparent);

    vbma->chunk = chunk;

    VertexBufferMemArea *memArea = (VertexBufferMemArea *)chunk_get_vbma(chunk, transparent);

    // if chunk has no mem area, vbma simply becomes the first one
    if (memArea == NULL) {
        chunk_set_vbma(chunk, vbma, transparent);
    }
    // otherwise go to last mem area of this chunk
    else {
        while (memArea->_groupListNext != NULL) {
            memArea = memArea->_groupListNext;
        }
        // add vbma at the end of the list
        vbma->_groupListPrevious = memArea;
        memArea->_groupListNext = vbma;
    }

    return true;
}

// inserts vbma1 after vbma2
// if vbma2 is a gap, vbma1 will become a gap
// otherwise, it will be attributed to the same chunk as vbma2
bool vertex_buffer_mem_area_insert_after(VertexBufferMemArea *vbma1,
                                         VertexBufferMemArea *vbma2,
                                         bool transparent) {
    if (vbma2 == NULL)
        return false;

    vertex_buffer_mem_area_leave_group_list(vbma1, transparent);

    vbma1->chunk = vbma2->chunk;

    if (vbma2->_groupListNext != NULL) {
        vbma2->_groupListNext->_groupListPrevious = vbma1;
        vbma1->_groupListNext = vbma2->_groupListNext;
    }

    vbma2->_groupListNext = vbma1;
    vbma1->_groupListPrevious = vbma2;

    return true;
}

// a vbmaw is permanently bound to a shape and chunk, while the vbma to write onto can change
// - vbma can be wherever there is room within allocated vb memory
// - occasionally, a new vb can be created for the shape if it is at full capacity,
// this is because vb capacity vs. chunk size can be set independently
struct _VertexBufferMemAreaWriter {
    VertexAttributes *cursor;  /* 8 bytes */
    Shape *s;                  /* 8 bytes */
    Chunk *c;                  /* 8 bytes */
    VertexBufferMemArea *vbma; /* 8 bytes */
    // amount of vertices written in current mem area
    // this is being reset when jumping to a different mem area
    uint32_t writtenCount; /* 4 bytes */
    bool isTransparent;    /* 1 byte */
    char pad[3];           /* 3 bytes */
};

void vertex_buffer_mem_area_writer_reset(VertexBufferMemAreaWriter *vbmaw,
                                         VertexBufferMemArea *vbma) {
    vbmaw->vbma = vbma;
    if (vbmaw->vbma != NULL) {
        vbmaw->cursor = vbmaw->vbma->start;
    } else {
        vbmaw->cursor = NULL;
    }
    vbmaw->writtenCount = 0;
}

void vertex_buffer_mem_area_writer_write(VertexBufferMemAreaWriter *vbmaw,
                                         float x,
                                         float y,
                                         float z,
                                         ATLAS_COLOR_INDEX_INT_T color,
                                         FACE_INDEX_INT_T faceIndex,
                                         FACE_AMBIENT_OCCLUSION_STRUCT_T ao,
                                         bool vLighting,
                                         VERTEX_LIGHT_STRUCT_T vlight1,
                                         VERTEX_LIGHT_STRUCT_T vlight2,
                                         VERTEX_LIGHT_STRUCT_T vlight3,
                                         VERTEX_LIGHT_STRUCT_T vlight4) {

    // check if no vbma assigned or the end of the memory area has been reached
    if (vbmaw->vbma == NULL || vbmaw->writtenCount == vbmaw->vbma->count) {
        while (true) {
            if (vbmaw->vbma != NULL) {
                // 1) see if there's already a next area for same chunk we can use
                if (vertex_buffer_mem_area_is_null_or_empty(vbmaw->vbma->_groupListNext) == false) {
                    vertex_buffer_mem_area_writer_reset(vbmaw, vbmaw->vbma->_groupListNext);
                    break;
                }

                // 2) if current vb is not full and vbma is the last area, extend it
                if (vertex_buffer_is_not_full(vbmaw->vbma->vb) &&
                    vbmaw->vbma == vbmaw->vbma->vb->lastMemArea) {
                    vbmaw->vbma->count += DRAWBUFFER_VERTICES_PER_FACE;
                    vertex_buffer_count_incr(vbmaw->vbma->vb, DRAWBUFFER_VERTICES_PER_FACE);
                    break;
                }
            }

            // 3) check across ALL vb for the current shape & same render...
            VertexBuffer *vb = shape_get_first_vertex_buffer(vbmaw->s, vbmaw->isTransparent);
            while (vb != NULL) {
                // 2a) ...if there's a vbma gap we can use
                if (vertex_buffer_mem_area_is_null_or_empty(vb->firstMemAreaGap) == false) {
                    if (vertex_buffer_mem_area_insert_after(vb->firstMemAreaGap,
                                                            vbmaw->vbma,
                                                            vb->isTransparent)) {
                        vertex_buffer_mem_area_writer_reset(vbmaw, vbmaw->vbma->_groupListNext);
                    } else {
                        vertex_buffer_mem_area_writer_reset(vbmaw, vb->firstMemAreaGap);
                        vertex_buffer_mem_area_assign_to_chunk(vb->firstMemAreaGap,
                                                               vbmaw->c,
                                                               vbmaw->isTransparent);
                    }
                    break;
                }

                // 2b) ...if there's available memory, create a new area at the end, will be
                // extended as written
                if (vertex_buffer_is_not_full(vb)) {
                    vertex_buffer_new_empty_gap_at_end(vb);
                    if (vertex_buffer_mem_area_insert_after(vb->firstMemAreaGap,
                                                            vbmaw->vbma,
                                                            vb->isTransparent)) {
                        vertex_buffer_mem_area_writer_reset(vbmaw, vbmaw->vbma->_groupListNext);
                    } else {
                        vertex_buffer_mem_area_writer_reset(vbmaw, vb->firstMemAreaGap);
                        vertex_buffer_mem_area_assign_to_chunk(vb->firstMemAreaGap,
                                                               vbmaw->c,
                                                               vbmaw->isTransparent);
                    }

                    vbmaw->vbma->count += DRAWBUFFER_VERTICES_PER_FACE;
                    vertex_buffer_count_incr(vb, DRAWBUFFER_VERTICES_PER_FACE);
                    break;
                }

                vb = vertex_buffer_get_next(vb);
            }
            // if available memory found, exit now
            if (vbmaw->vbma != NULL && vbmaw->writtenCount < vbmaw->vbma->count) {
                break;
            }

            // 4) all the available vb are at capacity and we need a new one
            else {
                VertexBuffer *newVb = shape_add_buffer(vbmaw->s, vbmaw->isTransparent);

                // immediately create a new vbma for this vb
                vertex_buffer_new_empty_gap_at_end(newVb);
                if (vertex_buffer_mem_area_insert_after(newVb->firstMemAreaGap,
                                                        vbmaw->vbma,
                                                        newVb->isTransparent)) {
                    vertex_buffer_mem_area_writer_reset(vbmaw, vbmaw->vbma->_groupListNext);
                } else {
                    vertex_buffer_mem_area_writer_reset(vbmaw, newVb->firstMemAreaGap);
                    vertex_buffer_mem_area_assign_to_chunk(newVb->firstMemAreaGap,
                                                           vbmaw->c,
                                                           vbmaw->isTransparent);
                }

                vbmaw->vbma->count += DRAWBUFFER_VERTICES_PER_FACE;
                vertex_buffer_count_incr(vbmaw->vbma->vb, DRAWBUFFER_VERTICES_PER_FACE);
                break;
            }
            // Note: no allocation, each vb is allocated already for full vbma capacity
        }
    }

    if (vbmaw->vbma == NULL) {
        cclog_error("⚠️⚠️⚠️ vertex_buffer_mem_area_writer_write: writer has no vbma");
        return;
    }

#if GLOBAL_LIGHTING_ENABLED == false
    DEFAULT_LIGHT(vlight1)
    DEFAULT_LIGHT(vlight2)
    DEFAULT_LIGHT(vlight3)
    DEFAULT_LIGHT(vlight4)
#endif

#if ENABLE_TRANSPARENCY_AO_RECEIVER == 0
    if (vbmaw->isTransparent) {
        ao.ao1 = 0;
        ao.ao2 = 0;
        ao.ao3 = 0;
        ao.ao4 = 0;
    }
#endif

    // Check for triangle shift
    bool aoShift;
    if (vLighting) {
#if TRIANGLE_SHIFT_MODE == 3
        // sunlight delta
        float diag13 = (float)(abs(vlight1.ambient - vlight3.ambient));
        float diag24 = (float)(abs(vlight2.ambient - vlight4.ambient));
        if (diag13 > TRIANGLE_SHIFT_MIXED_THRESHOLD || diag24 > TRIANGLE_SHIFT_MIXED_THRESHOLD) {
            aoShift = diag13 > diag24;
        } else {
            // luminance at each vertex
            float lum1 = 0.299f * vlight1.red + 0.587f * vlight1.green + 0.114f * vlight1.blue;
            float lum2 = 0.299f * vlight2.red + 0.587f * vlight2.green + 0.114f * vlight2.blue;
            float lum3 = 0.299f * vlight3.red + 0.587f * vlight3.green + 0.114f * vlight3.blue;
            float lum4 = 0.299f * vlight4.red + 0.587f * vlight4.green + 0.114f * vlight4.blue;

            // luminance delta
            float diag13_lum = fabsf(lum1 - lum3);
            float diag24_lum = fabsf(lum2 - lum4);

            if (diag13_lum > TRIANGLE_SHIFT_MIXED_THRESHOLD_LUMA ||
                diag24_lum > TRIANGLE_SHIFT_MIXED_THRESHOLD_LUMA) {
                aoShift = diag13_lum > diag24_lum;
            } else {
                aoShift = ao.ao1 + ao.ao3 > ao.ao2 + ao.ao4;
            }
        }
#elif TRIANGLE_SHIFT_MODE == 2
        uint8_t diag13 = abs(vlight1.ambient - vlight3.ambient);
        uint8_t diag24 = abs(vlight2.ambient - vlight4.ambient);
        if (diag13 > TRIANGLE_SHIFT_MIXED_THRESHOLD || diag24 > TRIANGLE_SHIFT_MIXED_THRESHOLD) {
            aoShift = diag13 > diag24;
        } else {
            aoShift = ao.ao1 + ao.ao3 > ao.ao2 + ao.ao4;
        }
#elif TRIANGLE_SHIFT_MODE == 1
        aoShift = abs(vlight1.ambient - vlight3.ambient) > abs(vlight2.ambient - vlight4.ambient);
#else
        aoShift = ao.ao1 + ao.ao3 > ao.ao2 + ao.ao4;
#endif
    } else {
        aoShift = ao.ao1 + ao.ao3 > ao.ao2 + ao.ao4;
    }

    // ready to write

    // Local indices in vbma from its cursor pointers
    const uint32_t vbma_idxVertices = vbmaw->writtenCount;

    // For metadata packing,
    // - AO index (2 bits)
    // - face index (3 bits)
    // - vertex lighting SRGB (4 bits each)
    const uint8_t packed_faceIndex = (uint8_t)(faceIndex * 4);
    float packed_srgb1, packed_srgb2, packed_srgb3, packed_srgb4;
    if (vLighting) {
        // Dim global lighting ambient value with AO
        vlight1.ambient = TO_UINT4(
            maximum(0, (uint8_t)(vlight1.ambient * 0.9f + 0.1f) - AO_GRADIENT[ao.ao1]));
        vlight2.ambient = TO_UINT4(
            maximum(0, (uint8_t)(vlight2.ambient * 0.9f + 0.1f) - AO_GRADIENT[ao.ao2]));
        vlight3.ambient = TO_UINT4(
            maximum(0, (uint8_t)(vlight3.ambient * 0.9f + 0.1f) - AO_GRADIENT[ao.ao3]));
        vlight4.ambient = TO_UINT4(
            maximum(0, (uint8_t)(vlight4.ambient * 0.9f + 0.1f) - AO_GRADIENT[ao.ao4]));

        packed_srgb1 = vlight1.ambient * 32 + vlight1.red * 512 + vlight1.green * 8192 +
                       vlight1.blue * 131072;
        packed_srgb2 = vlight2.ambient * 32 + vlight2.red * 512 + vlight2.green * 8192 +
                       vlight2.blue * 131072;
        packed_srgb3 = vlight3.ambient * 32 + vlight3.red * 512 + vlight3.green * 8192 +
                       vlight3.blue * 131072;
        packed_srgb4 = vlight4.ambient * 32 + vlight4.red * 512 + vlight4.green * 8192 +
                       vlight4.blue * 131072;
    } else {
        packed_srgb1 = packed_srgb2 = packed_srgb3 = packed_srgb4 = DEFAULT_LIGHT_PACKED;
    }
    const float v1_metadata = (float)(ao.ao1 + packed_faceIndex + packed_srgb1);
    const float v2_metadata = (float)(ao.ao2 + packed_faceIndex + packed_srgb2);
    const float v3_metadata = (float)(ao.ao3 + packed_faceIndex + packed_srgb3);
    const float v4_metadata = (float)(ao.ao4 + packed_faceIndex + packed_srgb4);

    // Vertex attributes
    VertexAttributes v1, v2, v3, v4;
    switch (faceIndex) {
        case FACE_RIGHT_CTC: {
            v1 = (VertexAttributes){x + 1.0f, y + 1.0f, z, (float)color, v1_metadata};
            v2 = (VertexAttributes){x + 1.0f, y, z, (float)color, v2_metadata};
            v3 = (VertexAttributes){x + 1.0f, y, z + 1.0f, (float)color, v3_metadata};
            v4 = (VertexAttributes){x + 1.0f, y + 1.0f, z + 1.0f, (float)color, v4_metadata};
            break;
        }
        case FACE_LEFT_CTC: {
            v1 = (VertexAttributes){x, y, z, (float)color, v1_metadata};
            v2 = (VertexAttributes){x, y + 1.0f, z, (float)color, v2_metadata};
            v3 = (VertexAttributes){x, y + 1.0f, z + 1.0f, (float)color, v3_metadata};
            v4 = (VertexAttributes){x, y, z + 1.0f, (float)color, v4_metadata};
            break;
        }
        case FACE_TOP_CTC: {
            v1 = (VertexAttributes){x + 1.0f, y + 1.0f, z, (float)color, v1_metadata};
            v2 = (VertexAttributes){x + 1.0f, y + 1.0f, z + 1.0f, (float)color, v2_metadata};
            v3 = (VertexAttributes){x, y + 1.0f, z + 1.0f, (float)color, v3_metadata};
            v4 = (VertexAttributes){x, y + 1.0f, z, (float)color, v4_metadata};
            break;
        }
        case FACE_DOWN_CTC: {
            v1 = (VertexAttributes){x, y, z, (float)color, v1_metadata};
            v2 = (VertexAttributes){x, y, z + 1.0f, (float)color, v2_metadata};
            v3 = (VertexAttributes){x + 1.0f, y, z + 1.0f, (float)color, v3_metadata};
            v4 = (VertexAttributes){x + 1.0f, y, z, (float)color, v4_metadata};
            break;
        }
        case FACE_FRONT_CTC: {
            v1 = (VertexAttributes){x, y, z + 1.0f, (float)color, v1_metadata};
            v2 = (VertexAttributes){x, y + 1.0f, z + 1.0f, (float)color, v2_metadata};
            v3 = (VertexAttributes){x + 1.0f, y + 1.0f, z + 1.0f, (float)color, v3_metadata};
            v4 = (VertexAttributes){x + 1.0f, y, z + 1.0f, (float)color, v4_metadata};
            break;
        }
        case FACE_BACK_CTC: {
            v1 = (VertexAttributes){x, y + 1.0f, z, (float)color, v1_metadata};
            v2 = (VertexAttributes){x, y, z, (float)color, v2_metadata};
            v3 = (VertexAttributes){x + 1.0f, y, z, (float)color, v3_metadata};
            v4 = (VertexAttributes){x + 1.0f, y + 1.0f, z, (float)color, v4_metadata};
            break;
        }
    }
    if (aoShift) {
        vbmaw->cursor[vbma_idxVertices] = v1;
        vbmaw->cursor[vbma_idxVertices + 1] = v2;
        vbmaw->cursor[vbma_idxVertices + 2] = v3;
        vbmaw->cursor[vbma_idxVertices + 3] = v4;
    } else {
        vbmaw->cursor[vbma_idxVertices] = v4;
        vbmaw->cursor[vbma_idxVertices + 1] = v1;
        vbmaw->cursor[vbma_idxVertices + 2] = v2;
        vbmaw->cursor[vbma_idxVertices + 3] = v3;
    }

    vbmaw->writtenCount += DRAWBUFFER_VERTICES_PER_FACE;
    vbmaw->vbma->dirty = true;
}

// call this when done writing
void vertex_buffer_mem_area_writer_done(VertexBufferMemAreaWriter *vbmaw) {
    if (vbmaw->vbma == NULL)
        return;

    // 1) remaining areas (unused) should become gaps
    // Note: do NOT decrement vb vertices because a gap still represents a space in memory that
    // needs to be filled, otherwise vb will consider that there is available space (count <
    // maxCount) for new vbma to be created at the end
    while (vbmaw->vbma->_groupListNext != NULL) {
        vertex_buffer_mem_area_make_gap(vbmaw->vbma->_groupListNext, vbmaw->isTransparent);
    }

#if VERTEX_BUFFER_DEBUG == 1
    if (vbmaw->vbma->_groupListNext != NULL) {
        cclog_debug("⚠️⚠️⚠️ vertex_buffer_mem_area_writer_done: _groupListNext should be NULL");
    }
#endif

    // 2) make gap if vbma unused
    if (vbmaw->writtenCount == 0) {
        vertex_buffer_mem_area_make_gap(vbmaw->vbma, vbmaw->isTransparent);
    }
    // check if in the middle of an area
    else if (vbmaw->writtenCount < vbmaw->vbma->count) {

        uint32_t diff = vbmaw->vbma->count - vbmaw->writtenCount;

        // 3) if vbma is the last area of its vb, just reduce it
        // reducing vertex buffer's nb vertices as well
        if (vbmaw->vbma == vbmaw->vbma->vb->lastMemArea) {
            vbmaw->vbma->count = vbmaw->writtenCount;
            vertex_buffer_count_decr(vbmaw->vbma->vb, diff);
        }
        // 4) split and create a gap
        // ⚠️ gaps have to be filled up before next draw
        else {
            vertex_buffer_mem_area_split_and_make_gap(vbmaw->vbma, vbmaw->writtenCount);
        }
    }
}

VertexBufferMemAreaWriter *vertex_buffer_mem_area_writer_new(Shape *s,
                                                             Chunk *c,
                                                             VertexBufferMemArea *vbma,
                                                             bool transparent) {
    VertexBufferMemAreaWriter *vbmaw = (VertexBufferMemAreaWriter *)malloc(
        sizeof(VertexBufferMemAreaWriter));
    if (vbmaw == NULL) {
        return NULL;
    }
    vbmaw->s = s;
    vbmaw->c = c;
    vbmaw->isTransparent = transparent;
    vertex_buffer_mem_area_writer_reset(vbmaw, vbma);
    return vbmaw;
}

void vertex_buffer_mem_area_writer_free(VertexBufferMemAreaWriter *vbmaw) {
    free(vbmaw);
}

void vertex_buffer_mem_area_free_all(VertexBufferMemArea *front) {
    VertexBufferMemArea *vbma = front;
    VertexBufferMemArea *tmp;
    while (vbma != NULL) {
        tmp = vbma;
        vbma = vbma->_globalListNext;
        vertex_buffer_mem_area_free(tmp);
    }
}

// makes vbma a gap
void vertex_buffer_mem_area_make_gap(VertexBufferMemArea *vbma, bool transparent) {
    // don't do anything if already a gap
    if (vertex_buffer_mem_area_is_gap(vbma)) {
        return;
    }

    vertex_buffer_mem_area_leave_group_list(vbma, transparent);

    vbma->chunk = NULL;
    vbma->dirty = false;

    // enlist with other gaps if some exist already
    if (vbma->vb->firstMemAreaGap == NULL) {
        vbma->vb->firstMemAreaGap = vbma;
        vbma->vb->lastMemAreaGap = vbma;
    } else {
        vbma->vb->lastMemAreaGap->_groupListNext = vbma;
        vbma->_groupListPrevious = vbma->vb->lastMemAreaGap;
        vbma->vb->lastMemAreaGap = vbma;
    }
}

Chunk *vertex_buffer_mem_area_get_chunk(const VertexBufferMemArea *vbma) {
    return vbma->chunk;
}

VertexBuffer *vertex_buffer_mem_area_get_vb(const VertexBufferMemArea *vbma) {
    return vbma->vb;
}

uint32_t vertex_buffer_mem_area_get_start_idx(const VertexBufferMemArea *vbma) {
    return vbma->startIdx;
}

uint32_t vertex_buffer_mem_area_get_count(const VertexBufferMemArea *vbma) {
    return vbma->count;
}

VertexBufferMemArea *vertex_buffer_mem_area_get_global_next(VertexBufferMemArea *vbma) {
    return vbma->_globalListNext;
}

VertexBufferMemArea *vertex_buffer_mem_area_get_group_next(VertexBufferMemArea *vbma) {
    return vbma->_groupListNext;
}

// splits vbma reducing it to vbma_size
// the other mem area part will be returned as a gap mem area in its vb
// already queued and/or merged with other gaps
// vbma->_groupListNext & vbma->_groupListPrevious remain intact
VertexBufferMemArea *vertex_buffer_mem_area_split_and_make_gap(VertexBufferMemArea *vbma,
                                                               uint32_t vbma_size) {

#if VERTEX_BUFFER_DEBUG == 1
    vertex_buffer_check_mem_area_chain(vbma->vb);
    if (vbma_size > vbma->count) {
        cclog_error("⚠️⚠️⚠️ vertex_buffer_mem_area_split_and_make_gap: can't split");
        return NULL;
    }
#endif

    uint32_t diff = vbma->count - vbma_size;

    vbma->count = vbma_size;

    VertexAttributes *start = _vertex_buffer_data_add_ptr(vbma->start, vbma_size);
    VertexBufferMemArea *gap = vertex_buffer_mem_area_new(vbma->vb,
                                                          start,
                                                          vbma->startIdx + vbma_size,
                                                          diff);

    // insert in global list
    if (vbma->_globalListNext != NULL) {
        vbma->_globalListNext->_globalListPrevious = gap;
    }
    gap->_globalListNext = vbma->_globalListNext;
    vbma->_globalListNext = gap;
    gap->_globalListPrevious = vbma;

    if (vbma == vbma->vb->lastMemArea) {
        vbma->vb->lastMemArea = gap;
    }

    // enlist with other gaps if some exist already
    if (vbma->vb->firstMemAreaGap == NULL) {
        vbma->vb->firstMemAreaGap = gap;
        vbma->vb->lastMemAreaGap = gap;
    } else {
        vbma->vb->lastMemAreaGap->_groupListNext = gap;
        gap->_groupListPrevious = vbma->vb->lastMemAreaGap;
        vbma->vb->lastMemAreaGap = gap;
    }

#if VERTEX_BUFFER_DEBUG == 1
    vertex_buffer_check_mem_area_chain(vbma->vb);
#endif

    return gap;
}

void vertex_buffer_mem_area_flush(VertexBufferMemArea *vbma) {
    // write nothing to let vertex_buffer_mem_area_writer_done recycle all vbma
    VertexBufferMemAreaWriter *writer = vertex_buffer_mem_area_writer_new(NULL, NULL, vbma, false);
    vertex_buffer_mem_area_writer_done(writer);
    vertex_buffer_mem_area_writer_free(writer);
}

bool vertex_buffer_has_dirty_mem_areas(const VertexBuffer *vb) {

    VertexBufferMemArea *vbma = vb->firstMemArea;

    while (vbma != NULL) {
        if (vbma->dirty) {
            return true;
        }
        vbma = vbma->_globalListNext;
    }

    return false;
}

void vertex_buffer_log_mem_areas(const VertexBuffer *vb) {
    VertexBufferMemArea *vbma = vb->firstMemArea;
    VertexBufferMemArea *previousVbma = NULL;

    while (vbma != NULL) {

        const char *check = "";
        const char *dirty = "";

        if (vbma->dirty)
            dirty = "💩";

        if (previousVbma != NULL) {
            if (vbma->start ==
                _vertex_buffer_data_add_ptr(previousVbma->start, previousVbma->count)) {
                check = "✅";
            } else {
                check = "❌";
            }
        }

        if (vbma->chunk == NULL) {
            cclog_info("-- [%04u] - GAP - (start: %p) %s%s",
                       vbma->count,
                       (void *)vbma->start,
                       check,
                       dirty);
        } else {
            const SHAPE_COORDS_INT3_T o = chunk_get_origin(vbma->chunk);
            cclog_info("-- [%04u] - chunk(%d, %d, %d) - (start: %p) %s%s",
                       vbma->count,
                       o.x,
                       o.y,
                       o.z,
                       (void *)vbma->start,
                       check,
                       dirty);
        }
        previousVbma = vbma;
        vbma = vbma->_globalListNext;
    }
}

#if VERTEX_BUFFER_DEBUG == 1
void vertex_buffer_check_mem_area_chain(VertexBuffer *vb) {
    VertexBufferMemArea *vbma = vb->firstMemArea;
    VertexBufferMemArea *previousVbma = NULL;

    // printf("========== VERTEX BUFFER MEM AREAS ==========\n");

    while (vbma != NULL) {

        //        if (vertex_buffer_mem_area_is_gap(vbma)) {
        //            printf("|G");
        //        } else {
        //            printf("|%d", vbma->count);
        //        }

        if (previousVbma != NULL) {

            if (vbma->start !=
                _vertex_buffer_data_add_ptr(previousVbma->start, previousVbma->count)) {
                cclog_warning("⚠️⚠️⚠️ mem area chain broken: start != previous->start + size");
            }
        }
        previousVbma = vbma;
        vbma = vbma->_globalListNext;
    }

    //    printf("|\n");
    //    printf("=============================================\n");
}
#endif // VERTEX_BUFFER_DEBUG == 1

void vertex_buffer_set_lighting_enabled(bool value) {
    vertex_buffer_lighting_enabled = value;
}

bool vertex_buffer_get_lighting_enabled(void) {
    return vertex_buffer_lighting_enabled;
}
