// -------------------------------------------------------------
//  Cubzh Core
//  shape.c
//  Created by Adrien Duermael on July 12, 2017.
// -------------------------------------------------------------

#include "shape.h"

#include <float.h>
#include <math.h>
#include <string.h>

#include "blockChange.h"
#include "cclog.h"
#include "easings.h"
#include "filo_list_uint16.h"
#include "history.h"
#include "rigidBody.h"
#include "scene.h"
#include "transaction.h"
#include "utils.h"

#ifdef DEBUG
#define SHAPE_LIGHTING_DEBUG false
#endif

// --------------------------------------------------
//
// MARK: - Types -
//
// --------------------------------------------------

typedef struct _ChunkList ChunkList;

struct _ChunkList {
    Chunk *chunk;
    ChunkList *next;
};

ChunkList *chunk_list_push_new_element(Chunk *c, ChunkList *next) {
    ChunkList *cl = (ChunkList *)malloc(sizeof(ChunkList));
    cl->next = next;
    cl->chunk = c;
    return cl;
}

void chunk_list_free(ChunkList *cl) {
    // no need to free chunks as they have to be referenced elsewhere
    free(cl);
}

struct _Shape {
    // list of colors used by the shape model, mapped onto color atlas indices
    ColorPalette *palette;

    // points of interest
    MapStringFloat3 *POIs;          // 8 bytes
    MapStringFloat3 *pois_rotation; // 8 bytes

    Transform *transform;
    Transform *pivot;

    // model axis-aligned bounding box (box->max - 1 is the max block)
    Box *box;
    // cached world axis-aligned bounding box, may be NULL if no cache
    Box *worldAABB;

    // Octree is NULL by default, unless the shape is initialized with
    // shape_make_with_octree.
    Octree *octree; // 8 bytes

    // NULL if shape does not use lighting
    VERTEX_LIGHT_STRUCT_T *lightingData;

    // buffers storing faces data used for rendering
    VertexBuffer *firstVB_opaque, *firstVB_transparent;
    VertexBuffer *lastVB_opaque, *lastVB_transparent;
    // 3D indexed chunks
    Index3D *chunks;
    // List of chunks in need for display update
    ChunkList *needsDisplay;

    // fragmented vertex buffers
    DoublyLinkedList *fragmentedVBs;

    ///
    History *history;

    /// Current shape transaction (to be applied at the end of frame)
    /// uses Lua coords
    Transaction *pendingTransaction;

    // name of the original item <username>.<itemname>, used for baked files
    char *fullname;

    // keeping track of total amount of chunks
    size_t nbChunks;
    // keeping track of total amount of blocks
    size_t nbBlocks;

    // shape's id
    ShapeId id; // 2 bytes
    // shape fixed size if applicable, else 0
    uint16_t maxWidth, maxHeight, maxDepth; // 3 * 2 bytes

    // octree resize offset, default zero until a resize occurs, is used to convert internal to Lua
    // coords in order to maintain consistent coordinates in a play session
    // /!\ nowhere in Cubzh Core should this be used, it should be used when
    // input/outputting values to Lua
    int3 offset; // 3 * 4 bytes

    // internal flag used for variable-size VB allocation, see shape_add_vertex_buffer
    uint8_t vbAllocationFlag_opaque;      // 1 byte
    uint8_t vbAllocationFlag_transparent; // 1 byte

    ShapeDrawMode drawMode; // 1 byte
    bool shadowDecal;       // 1 byte
    bool usesLighting;      // 1 byte
    bool isUnlit;           // 1 byte
    uint8_t layers;         // 1 byte

    bool isMutable;                        // 1 byte
    bool isResizable;                      // 1 byte
    bool historyEnabled;                   // 1 byte
    bool historyKeepingTransactionPending; // 1 byte

    // no automatic refresh, no model changes until unlocked
    bool isBakeLocked; // 1 byte

    // char pad[1];
};

// --------------------------------------------------
//
// MARK: - static variables -
//
// --------------------------------------------------
// TODO: use mutex when accessing or modifying newShapeId or recycledShapeIds
static ShapeId nextShapeId = 1;
static FiloListUInt16 *availableShapeIds = NULL;

/// array referencing all the shapes allocated
// TODO: use mutex when accessing or modifying _shapesIndex
// TODO: use a List instead of a buffer for _shapesIndex
static Shape **_shapesIndex = NULL;
static size_t _shapesIndexLength = 0;

// MARK: - private static functions prototypes -

// returns true if block was added
static bool _add_block_in_chunks(Index3D *chunks,
                                 Block *newBlock,
                                 const SHAPE_COORDS_INT_T x,
                                 const SHAPE_COORDS_INT_T y,
                                 const SHAPE_COORDS_INT_T z,
                                 int3 *block_ldfPos,
                                 bool *chunkAdded,
                                 Chunk **added_or_existing_chunk,
                                 Block **added_or_existing_block);

// --------------------------------------------------
//
// MARK: - static functions prototypes -
//
// --------------------------------------------------

/// add a block at (x, y, z) local to shape
static bool _shape_add_block(Shape *shape,
                             SHAPE_COORDS_INT_T x,
                             SHAPE_COORDS_INT_T y,
                             SHAPE_COORDS_INT_T z,
                             Block **added_or_existing_block);

/// returns a valid shape id, either a new one or a recycled one
static ShapeId getValidShapeId(void);

///
static void recycleShapeId(const ShapeId shapeId);

///
static bool _storeShapeInIndex(Shape *s);

// CURRENTLY UNUSED
/// Finds and returns a Shape by its id.
// static Shape* _getShapeFromIndexWithId(const ShapeId id);

/// removes a shape from the shape index and returns whether the operation succeeded
static bool _removeShapeFromIndex(const Shape *s);

// MARK: - private functions prototypes -

bool _has_fixed_size(const Shape *s);
bool _is_out_of_fixed_size(const Shape *s,
                           const SHAPE_COORDS_INT_T x,
                           const SHAPE_COORDS_INT_T y,
                           const SHAPE_COORDS_INT_T z);
Octree *_new_octree(Shape *s,
                    const SHAPE_COORDS_INT_T w,
                    const SHAPE_COORDS_INT_T h,
                    const SHAPE_COORDS_INT_T d);
void _set_vb_allocation_flag_one_frame(Shape *s);

bool _lighting_is_enabled(Shape *s);

/// internal functions used to flag the relevant data when lighting has changed
void _lighting_set_dirty(Shape *s, int3 *bbMin, int3 *bbMax, int x, int y, int z);
void _lighting_postprocess_dirty(Shape *s, int3 *bbMin, int3 *bbMax);

//// internal functions used to compute and update light propagation (sun & emission)
/// check a neighbor air block for light removal upon adding a block
void _light_removal_processNeighbor(Shape *s,
                                    int3 *bbMin,
                                    int3 *bbMax,
                                    VERTEX_LIGHT_STRUCT_T light,
                                    uint8_t srgb,
                                    bool equals,
                                    int3 *neighborPos,
                                    Block *neighbor,
                                    LightNodeQueue *lightQueue,
                                    LightRemovalNodeQueue *lightRemovalQueue);
/// insert light values and if necessary (lightQueue != NULL) add it to the light propagation queue
void _light_enqueue_source(int3 *pos,
                           Shape *shape,
                           VERTEX_LIGHT_STRUCT_T source,
                           LightNodeQueue *lightQueue);
/// propagate light values at a given block
void _light_block_propagate(Shape *s,
                            int3 *bbMin,
                            int3 *bbMax,
                            VERTEX_LIGHT_STRUCT_T current,
                            int3 *neighborPos,
                            Block *neighbor,
                            bool air,
                            bool transparent,
                            LightNodeQueue *lightQueue,
                            uint8_t stepS,
                            uint8_t stepRGB);
/// light propagation algorithm
void _light_propagate(Shape *s,
                      int3 *bbMin,
                      int3 *bbMax,
                      LightNodeQueue *lightQueue,
                      int srcX,
                      int srcY,
                      int srcZ);
/// light removal also enqueues back any light source that needs recomputing
void _light_removal(Shape *s,
                    int3 *bbMin,
                    int3 *bbMax,
                    LightRemovalNodeQueue *lightRemovalQueue,
                    LightNodeQueue *lightQueue);
/// lighting data realloc used after a shape resize
void _light_realloc(Shape *s,
                    const SHAPE_SIZE_INT_T dx,
                    const SHAPE_SIZE_INT_T dy,
                    const SHAPE_SIZE_INT_T dz,
                    const SHAPE_SIZE_INT_T offsetX,
                    const SHAPE_SIZE_INT_T offsetY,
                    const SHAPE_SIZE_INT_T offsetZ);
void _shape_check_all_vb_fragmented(Shape *s, VertexBuffer *first);
void _shape_fill_draw_slices(VertexBuffer *vb);

///
bool _shape_apply_transaction(Shape *const sh, Transaction *tr);

///
bool _shape_undo_transaction(Shape *const sh, Transaction *tr);

void _shape_clear_cached_world_aabb(Shape *s);

// --------------------------------------------------
//
// MARK: - public functions -
//
// --------------------------------------------------
//

// Shape allocator
Shape *shape_make() {
    Shape *s = (Shape *)malloc(sizeof(Shape));

    int3_set(&s->offset, 0, 0, 0);

    s->palette = NULL;

    s->POIs = map_string_float3_new();
    s->pois_rotation = map_string_float3_new();

    s->box = box_new();
    s->worldAABB = NULL;

    s->octree = NULL;

    s->transform = NULL;
    s->pivot = NULL;

    s->lightingData = NULL;
    s->usesLighting = false;
    s->isUnlit = false;
    s->layers = 1; // CAMERA_LAYERS_0

    s->chunks = index3d_new();

    // vertex buffers will be created on demand during refresh
    s->firstVB_opaque = NULL;
    s->lastVB_opaque = NULL;
    s->firstVB_transparent = NULL;
    s->lastVB_transparent = NULL;
    s->vbAllocationFlag_opaque = 0;
    s->vbAllocationFlag_transparent = 0;

    s->needsDisplay = NULL;
    s->history = NULL;
    s->fullname = NULL;
    s->pendingTransaction = NULL;
    s->nbChunks = 0;
    s->nbBlocks = 0;
    s->fragmentedVBs = doubly_linked_list_new();

    // shapes's id
    s->id = getValidShapeId();

    s->maxWidth = s->maxHeight = s->maxDepth = 0;

    s->drawMode = SHAPE_DRAWMODE_DEFAULT;
    s->shadowDecal = false;

    s->isMutable = false;
    s->isResizable = false;

    s->historyEnabled = false;
    s->historyKeepingTransactionPending = false;

    s->isBakeLocked = false;

    // store allocated shape in the index
    if (_storeShapeInIndex(s) == false) {
        cclog_warning("🔥 failed to store shape in index 1");
    }

    transform_make_with_shape(s);
    return s;
}

Shape *shape_make_copy(Shape *origin) {
    // apply transactions of the origin if needed
    shape_apply_current_transaction(origin, true);

    Shape *s = shape_make();
    s->palette = color_palette_new_copy(origin->palette);

    int3_set(&s->offset, origin->offset.x, origin->offset.y, origin->offset.z);

    // copy each point of interest
    MapStringFloat3Iterator *it = map_string_float3_iterator_new(origin->POIs);
    float3 *f3 = NULL;
    const char *key = NULL;
    while (map_string_float3_iterator_is_done(it) == false) {
        f3 = map_string_float3_iterator_current_value(it);
        key = map_string_float3_iterator_current_key(it);

        if (f3 != NULL && key != NULL) {
            shape_set_point_of_interest(s, key, f3);
        }

        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);

    // copy each POI rotation
    it = map_string_float3_iterator_new(origin->pois_rotation);
    while (map_string_float3_iterator_is_done(it) == false) {
        f3 = map_string_float3_iterator_current_value(it);
        key = map_string_float3_iterator_current_key(it);

        if (f3 != NULL && key != NULL) {
            shape_set_point_rotation(s, key, f3);
        }

        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);

    box_copy(s->box, origin->box);

    s->usesLighting = origin->usesLighting;
    s->isUnlit = origin->isUnlit;
    s->isMutable = origin->isMutable;
    s->isResizable = origin->isResizable;

    if (origin->octree != NULL) {
        s->octree = _new_octree(s, origin->maxWidth, origin->maxHeight, origin->maxDepth);

        s->maxWidth = origin->maxWidth;
        s->maxHeight = origin->maxHeight;
        s->maxDepth = origin->maxDepth;
    }

    Block *b = NULL;
    for (SHAPE_COORDS_INT_T x = 0; x <= origin->maxWidth; x += 1) {
        for (SHAPE_COORDS_INT_T y = 0; y <= origin->maxHeight; y += 1) {
            for (SHAPE_COORDS_INT_T z = 0; z <= origin->maxDepth; z += 1) {
                b = shape_get_block(origin, x, y, z, false);
                if (b != NULL && b->colorIndex != SHAPE_COLOR_INDEX_AIR_BLOCK) {
                    shape_add_block_with_color(s,
                                               b->colorIndex,
                                               x,
                                               y,
                                               z,
                                               false,
                                               false,
                                               false,
                                               false);
                }
            }
        }
    }

    if (s->usesLighting) {
        size_t lightingSize = s->maxWidth * s->maxHeight * s->maxDepth *
                              sizeof(VERTEX_LIGHT_STRUCT_T);
        s->lightingData = (VERTEX_LIGHT_STRUCT_T *)malloc(lightingSize);
        memcpy(s->lightingData, origin->lightingData, lightingSize);
    }

    if (origin->fullname != NULL) {
        s->fullname = string_new_copy(origin->fullname);
    }

    return s;
}

void shape_set_transform(Shape *const s, Transform *const t) {
    s->transform = t;
}

Shape *shape_make_with_fixed_size(const uint16_t width,
                                  const uint16_t height,
                                  const uint16_t depth,
                                  bool lighting,
                                  const bool isMutable) {

    Shape *s = shape_make();

    s->usesLighting = lighting;

    s->maxWidth = width;
    s->maxHeight = height;
    s->maxDepth = depth;

    s->isMutable = isMutable;

    return s;
}

Shape *shape_make_with_octree(const uint16_t width,
                              const uint16_t height,
                              const uint16_t depth,
                              bool lighting,
                              const bool isMutable,
                              const bool isResizable) {

    Shape *s = shape_make();

    s->octree = _new_octree(s, width, height, depth);
    s->usesLighting = lighting;

    // NOTE: remove chunks when fully using octree?

    s->maxWidth = width;
    s->maxHeight = height;
    s->maxDepth = depth;

    s->isMutable = isMutable;
    s->isResizable = isResizable;

    return s;
}

// Creates a new empty vertex buffer for the shape
// - enabling lighting buffer if it uses lighting
// - enabling transparency if requested
// after calling that function shape's lastVB_* will be empty
//
// The buffer capacity is an estimation that should on average reduce occupancy waste,
// 1) for a shape that was never drawn:
// - a) if it's the first buffer, it should ideally fit the entire shape at once (estimation)
// - b) if more space is required, subsequent buffers are scaled using VERTEX_BUFFER_INIT_SCALE_RATE
// this makes it possible to fit a worst-case scenario "cheese" map even if we know it practically
// won't happen 2) for a shape that has been drawn before:
// - a) first buffer should be of a minimal size to fit a few runtime structural changes
// (estimation)
// - b) subsequent buffers are scaled using VERTEX_BUFFER_RUNTIME_SCALE_RATE
// this approach should fit a game that by design do not result in a lot of structural changes,
// in just one buffer ; and should accommodate a game which by design requires a lot of structural
// changes, in just a handful of buffers down the chain
VertexBuffer *shape_add_vertex_buffer(Shape *shape, bool transparency) {
    // estimate new VB capacity
    size_t capacity;
    uint8_t *flag = transparency ? &shape->vbAllocationFlag_transparent
                                 : &shape->vbAllocationFlag_opaque;
    switch (*flag) {
        // uninitialized or last buffer capacity was capped (1a)
        case 0: {
            int3 *size = int3_pool_pop();
            shape_get_bounding_box_size(shape, size);

            // estimation based on maximum of shape shell vs. shape volume block-occupancy
            size_t shell = (minimum(size->z, 2) * size->x * size->y +
                            minimum(size->y, 2) * size->x * maximum(size->z - 2, 0) +
                            minimum(size->x, 2) * maximum(size->z - 2, 0) *
                                maximum(size->y - 2, 0));
            float volume = (float)(size->x * size->y * size->z) * VERTEX_BUFFER_VOLUME_OCCUPANCY;
            if (shell >= volume) {
                capacity = (size_t)(ceilf(
                    (float)shell * VERTEX_BUFFER_SHELL_FACTOR *
                    (transparency ? VERTEX_BUFFER_TRANSPARENT_FACTOR : 1.0f)));
            } else {
                capacity = (size_t)(ceilf(
                    volume * VERTEX_BUFFER_VOLUME_FACTOR *
                    (transparency ? VERTEX_BUFFER_TRANSPARENT_FACTOR : 1.0f)));
            }

            // if this shape is exceptionally big and caps max VB count, next VB should be created
            // at full capacity as well
            if (capacity < VERTEX_BUFFER_MAX_COUNT) {
                *flag = 1;
            }
            capacity = CLAMP(capacity, VERTEX_BUFFER_MIN_COUNT, VERTEX_BUFFER_MAX_COUNT);

            int3_pool_recycle(size);
            break;
        }
        // initialized within this frame and last buffer capacity was uncapped (1b)
        case 1: {
            size_t prev = vertex_buffer_get_max_length(transparency ? shape->lastVB_transparent
                                                                    : shape->lastVB_opaque);

            // restart buffer series when minimum capacity has been reached already (if downscaling
            // buffers)
            if (prev == VERTEX_BUFFER_MIN_COUNT) {
                *flag = 0;
                return shape_add_vertex_buffer(shape, transparency);
            }

            capacity = CLAMP((size_t)(ceilf(prev * VERTEX_BUFFER_INIT_SCALE_RATE)),
                             VERTEX_BUFFER_MIN_COUNT,
                             VERTEX_BUFFER_MAX_COUNT);
            break;
        }
        // initialized for more than a frame, first structural change (2a)
        case 2: {
            capacity = VERTEX_BUFFER_RUNTIME_COUNT;
            *flag = 3;
            break;
        }
        // initialized for more than a frame, subsequent structural change (2b)
        case 3: {
            size_t prev = vertex_buffer_get_max_length(transparency ? shape->lastVB_transparent
                                                                    : shape->lastVB_opaque);
            capacity = CLAMP((size_t)(ceilf(prev * VERTEX_BUFFER_RUNTIME_SCALE_RATE)),
                             VERTEX_BUFFER_MIN_COUNT,
                             VERTEX_BUFFER_MAX_COUNT);
            break;
        }
        default: {
            capacity = VERTEX_BUFFER_MAX_COUNT;
            break;
        }
    }

    // ensure VB capacity is a multiple of 2 for texture size
    size_t texSize = (size_t)(ceilf(sqrtf(capacity)));
#if VERTEX_BUFFER_TEX_UPPER_POT
    texSize = upper_power_of_two(texSize);
#endif
    capacity = texSize * texSize;

    // create and add new VB to the appropriate chain
    const bool lighting = vertex_buffer_get_lighting_enabled() && shape_uses_baked_lighting(shape);
    VertexBuffer *vb = vertex_buffer_new_with_max_count(capacity, lighting, transparency);
    if (transparency) {
        if (shape->lastVB_transparent != NULL) {
            vertex_buffer_insert_after(vb, shape->lastVB_transparent);
            shape->lastVB_transparent = vb;
        } else {
            // if lastVB_transparent is NULL, firstVB_transparent has to be NULL
            shape->firstVB_transparent = vb;
            shape->lastVB_transparent = shape->firstVB_transparent;
        }
    } else {
        if (shape->lastVB_opaque != NULL) {
            vertex_buffer_insert_after(vb, shape->lastVB_opaque);
            shape->lastVB_opaque = vb;
        } else {
            // if lastVB_opaque is NULL, firstVB_opaque has to be NULL
            shape->firstVB_opaque = vb;
            shape->lastVB_opaque = shape->firstVB_opaque;
        }
    }
    return vb;
}

// adds chunk to the list of chunks in need for display (a chunk can only be
// added once)
void shape_chunk_needs_display(Shape *shape, Chunk *c) {
    if (c == NULL)
        return;
    if (chunk_needs_display(c) == false) {
        ChunkList *cl;
        if (shape->needsDisplay == NULL) {
            cl = (ChunkList *)malloc(sizeof(ChunkList));
            cl->chunk = c;
            cl->next = NULL;
        } else {
            cl = chunk_list_push_new_element(c, shape->needsDisplay);
        }
        shape->needsDisplay = cl;
        chunk_set_needs_display(c, true);
    }
}

void shape_chunk_cancel_needs_display(Shape *shape, Chunk *c) {
    if (c == NULL) {
        return;
    }
    if (shape->needsDisplay == NULL)
        return;

    if (chunk_needs_display(c)) {

        chunk_set_needs_display(c, false);

        ChunkList *cl = shape->needsDisplay;
        if (cl->chunk == c) {
            cl = cl->next;
            chunk_list_free(shape->needsDisplay);
            shape->needsDisplay = cl;
            return;
        }

        ChunkList *clPrevious = cl;
        cl = cl->next;

        while (cl != NULL) {
            if (cl->chunk == c) {
                clPrevious->next = cl->next;
                chunk_list_free(cl);
                return;
            }
            clPrevious = cl;
            cl = cl->next;
        }
    }
}

// wrapper to silent warning
// TODO: a quicker version of chunk_destroy could be used when we know
// all mem areas are getting removed anyway
void shape_chunk_free(void *c) {
    chunk_destroy((Chunk *)c);
}

void shape_flush(Shape *shape) {
    if (shape != NULL) {

        index3d_flush(shape->chunks, shape_chunk_free);

        map_string_float3_free(shape->POIs);
        shape->POIs = map_string_float3_new();

        map_string_float3_free(shape->pois_rotation);
        shape->pois_rotation = map_string_float3_new();

        if (_has_fixed_size(shape)) {
            if (shape->octree != NULL) {
                octree_flush(shape->octree);
            }
            if (shape->lightingData != NULL) {
                size_t lightingSize = shape->maxWidth * shape->maxHeight * shape->maxDepth *
                                      sizeof(VERTEX_LIGHT_STRUCT_T);
                memset(shape->lightingData, 0, lightingSize);
            }
        }

        box_copy(shape->box, &box_zero);

        RigidBody *rb = shape_get_rigidbody(shape);
        if (rb != NULL) {
            rigidbody_reset(rb);
        }

        // free all vertex buffers
        vertex_buffer_free_all(shape->firstVB_opaque);
        shape->firstVB_opaque = NULL;
        shape->lastVB_opaque = NULL;
        vertex_buffer_free_all(shape->firstVB_transparent);
        shape->firstVB_transparent = NULL;
        shape->lastVB_transparent = NULL;

        // flush needsDisplay list
        ChunkList *cl;
        while (shape->needsDisplay != NULL) {
            cl = shape->needsDisplay;
            shape->needsDisplay = cl->next;
            chunk_list_free(cl);
        }

        // no need to flush fragmentedVBs,
        // vertex_buffer_free_all has been called previously
        doubly_linked_list_free(shape->fragmentedVBs);

        shape->nbChunks = 0;
        shape->nbBlocks = 0;
        shape->fragmentedVBs = doubly_linked_list_new();
    }
}

bool shape_retain(Shape *const shape) {
    if (shape == NULL)
        return false;
    return transform_retain(shape->transform);
}

uint16_t shape_retain_count(const Shape *const s) {
    if (s == NULL)
        return 0;
    return transform_retain_count(s->transform);
}

void shape_free(Shape *const shape) {
    if (shape == NULL) {
        return;
    }

    if (shape->palette != NULL) {
        color_palette_free(shape->palette);
        shape->palette = NULL;
    }

    if (shape->POIs != NULL) {
        map_string_float3_free(shape->POIs);
        shape->POIs = NULL;
    }

    if (shape->pois_rotation != NULL) {
        map_string_float3_free(shape->pois_rotation);
        shape->pois_rotation = NULL;
    }

    if (shape->box != NULL) {
        box_free(shape->box);
        shape->box = NULL;
    }

    if (shape->worldAABB != NULL) {
        box_free(shape->worldAABB);
        shape->worldAABB = NULL;
    }

    if (shape->pivot != NULL) {
        transform_release(shape->pivot); // created in shape_set_pivot
        shape->pivot = NULL;
    }

    if (shape->octree != NULL) {
        octree_free(shape->octree);
        shape->octree = NULL;
    }
    if (shape->lightingData != NULL) {
        free(shape->lightingData);
        shape->lightingData = NULL;
    }

    index3d_flush(shape->chunks, shape_chunk_free);
    index3d_free(shape->chunks);

    // free all vertex buffers
    vertex_buffer_free_all(shape->firstVB_opaque);
    vertex_buffer_free_all(shape->firstVB_transparent);

    // no need to flush fragmentedVBs,
    // vertex_buffer_free_all has been called previously
    doubly_linked_list_free(shape->fragmentedVBs);
    shape->fragmentedVBs = NULL;

    _removeShapeFromIndex(shape);
    const ShapeId shapeId = shape->id;

    // free needsDisplay list
    ChunkList *cl = NULL;
    while (shape->needsDisplay != NULL) {
        cl = shape->needsDisplay;
        shape->needsDisplay = cl->next;
        chunk_list_free(cl);
    }

    // free history
    history_free(shape->history);
    shape->history = NULL;

    // free current transaction
    transaction_free(shape->pendingTransaction);
    shape->pendingTransaction = NULL;

    free(shape);

    // recycle shape id
    recycleShapeId(shapeId);
}

void shape_release(Shape *const shape) {
    if (shape == NULL) {
        return;
    }
    transform_release(shape->transform);
}

ShapeId shape_get_id(const Shape *shape) {
    return shape->id;
}

bool shape_is_resizable(const Shape *shape) {
    return shape->isResizable;
}

// sets "needs display" to neighbor chunks when updating
// blocks on the edges.
void shape_chunk_inform_neighbors_about_change(Shape *shape,
                                               const Chunk *chunk,
                                               const int3 *block_pos) {

    if (block_pos->x == 0) { // left side
        shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Left));
        if (block_pos->y == 0) {
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Bottom));
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomLeft));
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, LeftFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomLeftFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, LeftBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomLeftBack));
            }
        } else if (block_pos->y == CHUNK_HEIGHT_MINUS_ONE) {
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Top));
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopLeft));
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, LeftFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopLeftFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, LeftBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopLeftBack));
            }
        } else { // middle
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, LeftFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, LeftBack));
            }
        }
    } else if (block_pos->x == CHUNK_WIDTH_MINUS_ONE) { // right side
        shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Right));
        if (block_pos->y == 0) {
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Bottom));
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomRight));
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, RightFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomRightFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, RightBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomRightBack));
            }
        } else if (block_pos->y == CHUNK_HEIGHT_MINUS_ONE) {
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Top));
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopRight));
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, RightFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopFront));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopRightFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, RightBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopBack));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopRightBack));
            }
        } else { // middle
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, RightFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, RightBack));
            }
        }
    } else { // not on left side, not on right side, all corner cases handled
        if (block_pos->y == 0) {
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Bottom));
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, BottomBack));
            }
        } else if (block_pos->y == CHUNK_HEIGHT_MINUS_ONE) {
            shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Top));
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopFront));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, TopBack));
            }
        } else { // middle
            if (block_pos->z == 0) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Front));
            } else if (block_pos->z == CHUNK_DEPTH_MINUS_ONE) {
                shape_chunk_needs_display(shape, chunk_get_neighbor(chunk, Back));
            }
        }
    }
}

// offset is always applied in this function
bool shape_add_block_from_lua(Shape *const shape,
                              Scene *scene,
                              const SHAPE_COLOR_INDEX_INT_T colorIndex,
                              const SHAPE_COORDS_INT_T luaX,
                              const SHAPE_COORDS_INT_T luaY,
                              const SHAPE_COORDS_INT_T luaZ) {
    vx_assert(shape != NULL);

    // a new block cannot be added if their is an existing block at those coords
    const Block *existingBlock = shape_get_block(shape,
                                                 luaX,
                                                 luaY,
                                                 luaZ,
                                                 true); // xyz are lua coords

    if (block_is_solid(existingBlock) == true) {
        // There is already a solid block at the given coordinates, we cannot
        // add a new block.
        return false;
    }

    if (shape->pendingTransaction == NULL) {
        shape->pendingTransaction = transaction_new();
        if (shape->history != NULL) {
            history_discardTransactionsMoreRecentThanCursor(shape->history);
        }
    }

    if (transaction_addBlock(shape->pendingTransaction, luaX, luaY, luaZ, colorIndex)) {
        // register awake box for the map
        if (shape_uses_baked_lighting(shape)) {
            SHAPE_COORDS_INT_T x = luaX, y = luaY, z = luaZ;
            shape_block_lua_to_internal(shape, &x, &y, &z);
            scene_register_awake_map_box(scene, x, y, z);
        }
        return true;
    } else {
        return false;
    }
}

bool shape_remove_block_from_lua(Shape *const shape,
                                 Scene *scene,
                                 const SHAPE_COORDS_INT_T luaX,
                                 const SHAPE_COORDS_INT_T luaY,
                                 const SHAPE_COORDS_INT_T luaZ) {
    vx_assert(shape != NULL);

    // check whether a block already exists at the given coordinates
    const Block *existingBlock = shape_get_block(shape,
                                                 luaX,
                                                 luaY,
                                                 luaZ,
                                                 true); // xyz are lua coords

    if (block_is_solid(existingBlock) == false) {
        return false; // block was not removed
    }

    if (shape->pendingTransaction == NULL) {
        shape->pendingTransaction = transaction_new();
        if (shape->history != NULL) {
            history_discardTransactionsMoreRecentThanCursor(shape->history);
        }
    }

    transaction_removeBlock(shape->pendingTransaction, luaX, luaY, luaZ);

    // register awake box for the map
    if (shape_uses_baked_lighting(shape)) {
        SHAPE_COORDS_INT_T x = luaX, y = luaY, z = luaZ;
        shape_block_lua_to_internal(shape, &x, &y, &z);
        scene_register_awake_map_box(scene, x, y, z);
    }

    return true; // block is considered removed
}

bool shape_replace_block_from_lua(Shape *const shape,
                                  const SHAPE_COLOR_INDEX_INT_T newColorIndex,
                                  const SHAPE_COORDS_INT_T luaX,
                                  const SHAPE_COORDS_INT_T luaY,
                                  const SHAPE_COORDS_INT_T luaZ) {
    vx_assert(shape != NULL);

    // check whether a block already exists at the given coordinates
    const Block *existingBlock = shape_get_block(shape,
                                                 luaX,
                                                 luaY,
                                                 luaZ,
                                                 true); // xyz are lua coords

    if (block_is_solid(existingBlock) == false) {
        // There is no solid block at those coordinates.
        return false; // block was not replaced
    }

    if (block_get_color_index(existingBlock) == newColorIndex) {
        // Trying to replace a cube by one with the exact same color index.
        return false; // block was not replaced
    }

    if (shape->pendingTransaction == NULL) {
        shape->pendingTransaction = transaction_new();
        if (shape->history != NULL) {
            history_discardTransactionsMoreRecentThanCursor(shape->history);
        }
    }

    transaction_replaceBlock(shape->pendingTransaction, luaX, luaY, luaZ, newColorIndex);

    return true; // block is considered replaced
}

void shape_apply_current_transaction(Shape *const shape, bool keepPending) {
    vx_assert(shape != NULL);
    if (shape->pendingTransaction == NULL || shape->isBakeLocked) {
        return; // no transaction to apply
    }

    const bool done = _shape_apply_transaction(shape, shape->pendingTransaction);
    if (done == false) {
        transaction_free(shape->pendingTransaction);
        shape->pendingTransaction = NULL;
        return;
    }

    keepPending = keepPending || (shape->historyEnabled && shape->historyKeepingTransactionPending);
    if (keepPending == false) {
        if (shape->historyEnabled == true && shape->history != NULL) {
            // history is enabled, store the transaction in the history
            transaction_resetIndex3DIterator(shape->pendingTransaction);
            history_pushTransaction(shape->history, shape->pendingTransaction);
        } else {
            // otherwise, simply delete transaction
            transaction_free(shape->pendingTransaction);
        }
        shape->pendingTransaction = NULL;
    }
}

bool shape_add_block_with_color(Shape *shape,
                                SHAPE_COLOR_INDEX_INT_T colorIndex,
                                SHAPE_COORDS_INT_T x,
                                SHAPE_COORDS_INT_T y,
                                SHAPE_COORDS_INT_T z,
                                const bool resizeIfNeeded,
                                const bool applyOffset,
                                const bool lighting,
                                bool useDefaultColor) {
    Block *block = NULL;

    if (resizeIfNeeded) {
        // returns if no need to make space
        // NOTE: offset not applied on x, y & z here.
        shape_make_space_for_block(shape, x, y, z, applyOffset);
    }

    // apply current offset
    // (could have been updated within shape_make_space_for_block)
    // that's why we apply it now, not at at the beginning of the function.
    if (applyOffset) {
        shape_block_lua_to_internal(shape, &x, &y, &z);
    }

    const bool added = _shape_add_block(shape, x, y, z, &block);

    if (added) {
        // if caller wants to express colorIndex as a default color, we translate it here
        if (useDefaultColor) {
            color_palette_check_and_add_default_color_2021(shape->palette, colorIndex, &colorIndex);
        } else {
            color_palette_increment_color(shape->palette, colorIndex);
        }

        block_set_color_index(block, colorIndex);
        if (shape->octree != NULL) {
            octree_set_element(shape->octree, (void *)block, x, y, z);
        }

        if (lighting) {
            shape_compute_baked_lighting_added_block(shape, x, y, z, colorIndex);
        }
    }

    return added;
}

/// returns whether the block has been removed
///
/// /!\ *blockBefore must be freed by the caller.
bool shape_remove_block(Shape *shape,
                        SHAPE_COORDS_INT_T x,
                        SHAPE_COORDS_INT_T y,
                        SHAPE_COORDS_INT_T z,
                        Block **blockBefore,
                        const bool applyOffset,
                        const bool lighting,
                        const bool shrinkBox) {

    if (shape == NULL) {
        return false;
    }

    if (applyOffset) {
        shape_block_lua_to_internal(shape, &x, &y, &z);
    }

    // make sure block removed is within fixed boundaries
    if (_has_fixed_size(shape) && _is_out_of_fixed_size(shape, x, y, z)) {
        cclog_error("⚠️ trying to remove block from outside shape's fixed boundaries");
        return false;
    }

    bool removed = false;

    Chunk *chunk = NULL;

    int3 globalPos;
    int3 posInChunk;
    int3 chunkPos;

    int3_set(&globalPos, x, y, z);
    int3_set(&posInChunk, 0, 0, 0);
    int3_set(&chunkPos, 0, 0, 0);

    shape_get_chunk_and_position_within(shape, &globalPos, &chunk, &chunkPos, &posInChunk);

    // found chunk?
    if (chunk != NULL) {
        Block *block = chunk_get_block(chunk, posInChunk.x, posInChunk.y, posInChunk.z);
        if (block == NULL) {
            return false;
        }

        SHAPE_COLOR_INDEX_INT_T colorIdx = block->colorIndex;
        if (blockBefore != NULL) {
            *blockBefore = block_new_copy(block);
        }
        removed = chunk_removeBlock(chunk, posInChunk.x, posInChunk.y, posInChunk.z);

        if (removed) {
            shape->nbBlocks--;
            shape_chunk_inform_neighbors_about_change(shape, chunk, &posInChunk);
            shape_chunk_needs_display(shape, chunk);

            // note: box.min inclusive, box.max exclusive
            const bool shouldUpdateBB = x <= (SHAPE_COORDS_INT_T)shape->box->min.x ||
                                        x >= (SHAPE_COORDS_INT_T)shape->box->max.x - 1 ||
                                        y <= (SHAPE_COORDS_INT_T)shape->box->min.y ||
                                        y >= (SHAPE_COORDS_INT_T)shape->box->max.y - 1 ||
                                        z <= (SHAPE_COORDS_INT_T)shape->box->min.z ||
                                        z >= (SHAPE_COORDS_INT_T)shape->box->max.z - 1;

            if (shouldUpdateBB && shrinkBox) {
                shape_shrink_box(shape);
            }
            if (shape->octree != NULL) {
                Block *air = block_new_air();
                octree_remove_element(shape->octree, x, y, z, air);
                block_free((Block *)air);
            }

            if (lighting) {
                shape_compute_baked_lighting_removed_block(shape, x, y, z, colorIdx);
            }

            color_palette_decrement_color(shape->palette, colorIdx);
        }

        // if chunk is now empty, do not destroy it right now and wait until shape_refresh_vertices:
        // 1) in case we reuse this chunk in the meantime
        // 2) to make sure vb nbVertices is always in sync with its data
    }

    return removed;
}

/// /!\ *blockBefore must be freed by the caller.
/// /!\ *blockAfter must be freed by the caller.
bool shape_paint_block(Shape *shape,
                       SHAPE_COLOR_INDEX_INT_T colorIndex,
                       SHAPE_COORDS_INT_T x,
                       SHAPE_COORDS_INT_T y,
                       SHAPE_COORDS_INT_T z,
                       Block **blockBefore,
                       Block **blockAfter,
                       const bool applyOffset,
                       const bool lighting) {

    if (applyOffset) {
        shape_block_lua_to_internal(shape, &x, &y, &z);
    }

    bool painted = false;

    Chunk *chunk = NULL;

    static int3 globalPos;
    static int3 posInChunk;
    static int3 chunkPos;

    int3_set(&globalPos, x, y, z);

    shape_get_chunk_and_position_within(shape, &globalPos, &chunk, &chunkPos, &posInChunk);

    // found chunk?
    if (chunk != NULL) {
        Block *block = chunk_get_block(chunk, posInChunk.x, posInChunk.y, posInChunk.z);
        if (block == NULL) {
            return false;
        }

        const uint8_t prevColor = block->colorIndex;
        if (blockBefore != NULL) {
            *blockBefore = block_new_copy(block);
        }

        color_palette_decrement_color(shape->palette, prevColor);

        color_palette_increment_color(shape->palette, colorIndex);

        painted = chunk_paint_block(chunk, posInChunk.x, posInChunk.y, posInChunk.z, colorIndex);
        if (blockAfter != NULL) {
            *blockAfter = block_new_copy(block);
        }
        if (painted) {
            shape_chunk_needs_display(shape, chunk);

            // Note: block in chunk index and block in octree are 2 different copies
            if (shape->octree != NULL) {
                octree_set_element(shape->octree, (const void *)(&colorIndex), x, y, z);
            }

            if (lighting) {
                shape_compute_baked_lighting_replaced_block(shape, x, y, z, colorIndex, false);
            }
        }
    }

    return painted;
}

ColorPalette *shape_get_palette(const Shape *shape) {
    return shape->palette;
}

void shape_set_palette(Shape *shape, ColorPalette *palette) {
    if (shape->palette != NULL) {
        color_palette_free(shape->palette);
    }
    shape->palette = palette;
}

Block *shape_get_block(const Shape *const shape,
                       SHAPE_COORDS_INT_T x,
                       SHAPE_COORDS_INT_T y,
                       SHAPE_COORDS_INT_T z,
                       const bool luaCoords) {
    Block *b = NULL;

    // look for the block in the current transaction
    if (shape->pendingTransaction != NULL) {
        SHAPE_COORDS_INT_T luaX = x;
        SHAPE_COORDS_INT_T luaY = y;
        SHAPE_COORDS_INT_T luaZ = z;
        if (luaCoords == false) {
            shape_block_internal_to_lua(shape, &luaX, &luaY, &luaZ);
        }
        b = transaction_getCurrentBlockAt(shape->pendingTransaction, luaX, luaY, luaZ);
    }

    // transaction doesn't contain a block state for those coords,
    // let's check in the shape blocks
    if (b == NULL) {
        b = shape_get_block_immediate(shape, x, y, z, luaCoords);
    }

    return b;
}

Block *shape_get_block_immediate(const Shape *const shape,
                                 SHAPE_COORDS_INT_T x,
                                 SHAPE_COORDS_INT_T y,
                                 SHAPE_COORDS_INT_T z,
                                 const bool luaCoords) {
    if (luaCoords) {
        shape_block_lua_to_internal(shape, &x, &y, &z);
    }

    Block *b = NULL;
    if (shape_is_within_fixed_bounds(shape, x, y, z)) {
        if (shape->octree != NULL) {
            b = (Block *)octree_get_element_without_checking(shape->octree, x, y, z);
        } else {
            static int3 globalPos;
            static int3 posInChunk;

            int3_set(&globalPos, x, y, z);

            static Chunk *chunk;

            shape_get_chunk_and_position_within(shape, &globalPos, &chunk, NULL, &posInChunk);

            // found chunk?
            if (chunk != NULL) {
                b = chunk_get_block(chunk, posInChunk.x, posInChunk.y, posInChunk.z);
            }
        }
    }
    return b;
}

void shape_get_chunk_neighbors(const Shape *shape,
                               const Chunk *c,
                               Chunk **left,
                               Chunk **right,
                               Chunk **top,
                               Chunk **bottom,
                               Chunk **front,
                               Chunk **back) {
    static int3 neighbor_ldf_pos;

    const int3 *pos = chunk_get_pos(c);

    // left
    int3_set(&neighbor_ldf_pos,
             (pos->x - CHUNK_WIDTH) >> CHUNK_WIDTH_SQRT,
             pos->y >> CHUNK_HEIGHT_SQRT,
             pos->z >> CHUNK_DEPTH_SQRT);
    *left = (Chunk *)
        index3d_get(shape->chunks, neighbor_ldf_pos.x, neighbor_ldf_pos.y, neighbor_ldf_pos.z);

    // right
    int3_set(&neighbor_ldf_pos,
             (pos->x + CHUNK_WIDTH) >> CHUNK_WIDTH_SQRT,
             pos->y >> CHUNK_HEIGHT_SQRT,
             pos->z >> CHUNK_DEPTH_SQRT);
    *right = (Chunk *)
        index3d_get(shape->chunks, neighbor_ldf_pos.x, neighbor_ldf_pos.y, neighbor_ldf_pos.z);

    // top
    int3_set(&neighbor_ldf_pos,
             pos->x >> CHUNK_WIDTH_SQRT,
             (pos->y + CHUNK_HEIGHT) >> CHUNK_HEIGHT_SQRT,
             pos->z >> CHUNK_DEPTH_SQRT);
    *top = (Chunk *)
        index3d_get(shape->chunks, neighbor_ldf_pos.x, neighbor_ldf_pos.y, neighbor_ldf_pos.z);

    // bottom
    int3_set(&neighbor_ldf_pos,
             pos->x >> CHUNK_WIDTH_SQRT,
             (pos->y - CHUNK_HEIGHT) >> CHUNK_HEIGHT_SQRT,
             pos->z >> CHUNK_DEPTH_SQRT);
    *bottom = (Chunk *)
        index3d_get(shape->chunks, neighbor_ldf_pos.x, neighbor_ldf_pos.y, neighbor_ldf_pos.z);

    // front
    int3_set(&neighbor_ldf_pos,
             pos->x >> CHUNK_WIDTH_SQRT,
             pos->y >> CHUNK_HEIGHT_SQRT,
             (pos->z - CHUNK_DEPTH) >> CHUNK_DEPTH_SQRT);
    *front = (Chunk *)
        index3d_get(shape->chunks, neighbor_ldf_pos.x, neighbor_ldf_pos.y, neighbor_ldf_pos.z);

    // back
    int3_set(&neighbor_ldf_pos,
             pos->x >> CHUNK_WIDTH_SQRT,
             pos->y >> CHUNK_HEIGHT_SQRT,
             (pos->z + CHUNK_DEPTH) >> CHUNK_DEPTH_SQRT);
    *back = (Chunk *)
        index3d_get(shape->chunks, neighbor_ldf_pos.x, neighbor_ldf_pos.y, neighbor_ldf_pos.z);
}

void shape_get_chunk_and_position_within(const Shape *shape,
                                         const int3 *pos,
                                         Chunk **chunk,
                                         int3 *chunk_pos,
                                         int3 *pos_in_chunk) {
    static int3 chunk_ldfPos;

    int3_set(&chunk_ldfPos,
             pos->x >> CHUNK_WIDTH_SQRT,
             pos->y >> CHUNK_HEIGHT_SQRT,
             pos->z >> CHUNK_DEPTH_SQRT);

    if (chunk_pos != NULL) {
        chunk_pos->x = chunk_ldfPos.x;
        chunk_pos->y = chunk_ldfPos.y;
        chunk_pos->z = chunk_ldfPos.z;
    }

    if (pos_in_chunk != NULL) {
        pos_in_chunk->x = pos->x & CHUNK_WIDTH_MINUS_ONE;
        pos_in_chunk->y = pos->y & CHUNK_HEIGHT_MINUS_ONE;
        pos_in_chunk->z = pos->z & CHUNK_DEPTH_MINUS_ONE;
    }

    *chunk = (Chunk *)index3d_get(shape->chunks, chunk_ldfPos.x, chunk_ldfPos.y, chunk_ldfPos.z);
}

void shape_get_bounding_box_size(const Shape *shape, int3 *size) {
    if (size == NULL)
        return;
    box_get_size_int(shape->box, size);
}

void shape_get_fixed_size(const Shape *shape, int3 *size) {
    if (size == NULL)
        return;
    if (_has_fixed_size(shape)) {
        size->x = shape->maxWidth;
        size->y = shape->maxHeight;
        size->z = shape->maxDepth;
    } else {
        shape_get_bounding_box_size(shape, size);
    }
}

uint16_t shape_get_max_fixed_size(const Shape *shape) {
    if (_has_fixed_size(shape)) {
        return maximum(shape->maxWidth, maximum(shape->maxHeight, shape->maxDepth));
    } else {
        return maximum(
            shape->box->max.x - shape->box->min.x,
            maximum(shape->box->max.y - shape->box->min.y, shape->box->max.z - shape->box->min.z));
    }
}

bool shape_is_within_fixed_bounds(const Shape *shape,
                                  const SHAPE_COORDS_INT_T x,
                                  const SHAPE_COORDS_INT_T y,
                                  const SHAPE_COORDS_INT_T z) {
    return (x >= 0 && x < shape->maxWidth && y >= 0 && y < shape->maxHeight && z >= 0 &&
            z < shape->maxDepth);
}

void shape_box_to_aabox(const Shape *s,
                        const Box *box,
                        Box *aabox,
                        bool isCollider,
                        bool squarify) {
    if (s == NULL)
        return;
    if (box == NULL)
        return;
    if (aabox == NULL)
        return;

    const float3 *offset = s->pivot != NULL ? transform_get_local_position(s->pivot) : &float3_zero;
    if (isCollider) {
        if (rigidbody_is_dynamic(shape_get_rigidbody(s))) {
            transform_utils_box_to_dynamic_collider(s->transform,
                                                    box,
                                                    aabox,
                                                    offset,
                                                    squarify ? MinSquarify : NoSquarify);
        } else {
            transform_utils_box_to_static_collider(s->transform,
                                                   box,
                                                   aabox,
                                                   offset,
                                                   squarify ? MinSquarify : NoSquarify);
        }
    } else {
        transform_utils_box_to_aabb(s->transform,
                                    box,
                                    aabox,
                                    offset,
                                    squarify ? MinSquarify : NoSquarify);
    }
}

const Box *shape_get_model_aabb(const Shape *shape) {
    return shape->box;
}

void shape_get_local_aabb(const Shape *s, Box *box, bool squarify) {
    if (s == NULL || box == NULL)
        return;

    const float3 *offset = s->pivot != NULL ? transform_get_local_position(s->pivot) : &float3_zero;
    transform_refresh(s->transform, false, true); // refresh mtx for intra-frame calculations
    box_to_aabox2(s->box, box, transform_get_mtx(s->transform), offset, squarify);
}

void shape_get_world_aabb(Shape *s, Box *box, bool squarify) {
    if (s->worldAABB == NULL || transform_is_any_dirty(s->transform)) {
        shape_box_to_aabox(s, s->box, box, false, false);
        if (s->worldAABB == NULL) {
            s->worldAABB = box_new_copy(box);
        } else {
            box_copy(s->worldAABB, box);
        }
        transform_reset_any_dirty(s->transform);
    } else {
        box_copy(box, s->worldAABB);
    }
    if (squarify) {
        box_squarify(box, MinSquarify);
    }
}

// compute the size of the shape (a cube containing the shape)
bool shape_compute_size_and_origin(const Shape *shape,
                                   SHAPE_SIZE_INT_T *size_x,
                                   SHAPE_SIZE_INT_T *size_y,
                                   SHAPE_SIZE_INT_T *size_z,
                                   SHAPE_COORDS_INT_T *origin_x,
                                   SHAPE_COORDS_INT_T *origin_y,
                                   SHAPE_COORDS_INT_T *origin_z) {

    // shape boundaries
    // the min can be > 0 and max can be < 0 so we can set these values now.
    // we take the ones from first chunk.
    int32_t min_x = 0;
    int32_t min_y = 0;
    int32_t min_z = 0;
    int32_t max_x = 0;
    int32_t max_y = 0;
    int32_t max_z = 0;

    Index3DIterator *it = index3d_iterator_new(shape->chunks);

    if (index3d_iterator_pointer(it) == NULL) {
        // no chunk
        *size_x = 0;
        *size_y = 0;
        *size_z = 0;
        *origin_x = 0;
        *origin_y = 0;
        *origin_z = 0;
        return false; // empty shape
    }

    bool firstChunk = true;

    CHUNK_COORDS_INT_T c_min_x = 0;
    CHUNK_COORDS_INT_T c_max_x = 0;
    CHUNK_COORDS_INT_T c_min_y = 0;
    CHUNK_COORDS_INT_T c_max_y = 0;
    CHUNK_COORDS_INT_T c_min_z = 0;
    CHUNK_COORDS_INT_T c_max_z = 0;

    // loop on all the chunks
    while (true) {
        // process current chunk
        Chunk *c = (Chunk *)index3d_iterator_pointer(it);

        // Compute inner bounds only if chunk is NOT empty.
        // Empty chunks end up being removed but they could
        // still be present here.
        if (chunk_get_nb_blocks(c) > 0) {

            // get chunk's inner bounds to refine limits
            chunk_get_inner_bounds(c, &c_min_x, &c_max_x, &c_min_y, &c_max_y, &c_min_z, &c_max_z);

            // Note: chunk should never be NULL

            // get its position
            const int3 *p = chunk_get_pos(c);

            if (firstChunk) {
                min_x = p->x + c_min_x;
                min_y = p->y + c_min_y;
                min_z = p->z + c_min_z;
                max_x = p->x + c_max_x;
                max_y = p->y + c_max_y;
                max_z = p->z + c_max_z;
                firstChunk = false;
            } else {
                // update min/max on all 3 axis
                min_x = (p->x + c_min_x < min_x) ? (p->x + c_min_x) : (min_x);
                max_x = (p->x + c_max_x > max_x) ? (p->x + c_max_x) : (max_x);
                min_y = (p->y + c_min_y < min_y) ? (p->y + c_min_y) : (min_y);
                max_y = (p->y + c_max_y > max_y) ? (p->y + c_max_y) : (max_y);
                min_z = (p->z + c_min_z < min_z) ? (p->z + c_min_z) : (min_z);
                max_z = (p->z + c_max_z > max_z) ? (p->z + c_max_z) : (max_z);
            }
        }

        // select next chunk and exit the loop if there is no next chunk
        if (index3d_iterator_is_at_end(it)) {
            break;
        }
        index3d_iterator_next(it);
    }

    index3d_iterator_free(it);

    *size_x = (uint32_t)(max_x - min_x);
    *size_y = (uint32_t)(max_y - min_y);
    *size_z = (uint32_t)(max_z - min_z);

    *origin_x = min_x;
    *origin_y = min_y;
    *origin_z = min_z;

    return true; // non-empty shape
}

void shape_shrink_box(Shape *shape) {
    if (shape == NULL) {
        cclog_error("[shape_shrink_box] shape arg is NULL. Abort.");
        return;
    }
    SHAPE_SIZE_INT_T size_x, size_y, size_z;
    SHAPE_COORDS_INT_T origin_x, origin_y, origin_z;
    shape_compute_size_and_origin(shape,
                                  &size_x,
                                  &size_y,
                                  &size_z,
                                  &origin_x,
                                  &origin_y,
                                  &origin_z);

    shape->box->min.x = origin_x;
    shape->box->min.y = origin_y;
    shape->box->min.z = origin_z;

    shape->box->max.x = (float)(origin_x + size_x);
    shape->box->max.y = (float)(origin_y + size_y);
    shape->box->max.z = (float)(origin_z + size_z);

    _shape_clear_cached_world_aabb(shape);
    shape_fit_collider_to_bounding_box(shape);
}

void shape_expand_box(Shape *shape,
                      const SHAPE_COORDS_INT_T x,
                      const SHAPE_COORDS_INT_T y,
                      const SHAPE_COORDS_INT_T z) {

    if (box_is_empty(shape->box)) {
        float3_set(&shape->box->min, x, y, z);
        float3_set(&shape->box->max, x + 1, y + 1, z + 1);
    } else {
        if (x < shape->box->min.x) {
            shape->box->min.x = x;
        }
        if (y < shape->box->min.y) {
            shape->box->min.y = y;
        }
        if (z < shape->box->min.z) {
            shape->box->min.z = z;
        }
        if (x >= shape->box->max.x) {
            shape->box->max.x = x + 1;
        }
        if (y >= shape->box->max.y) {
            shape->box->max.y = y + 1;
        }
        if (z >= shape->box->max.z) {
            shape->box->max.z = z + 1;
        }
    }

    shape_fit_collider_to_bounding_box(shape);
    _shape_clear_cached_world_aabb(shape);
}

// NOTE: offset is supposed to already be applied when calling this.
void shape_make_space_for_block(Shape *shape,
                                SHAPE_COORDS_INT_T x,
                                SHAPE_COORDS_INT_T y,
                                SHAPE_COORDS_INT_T z,
                                const bool applyOffset) {
    shape_make_space(shape, x, y, z, x, y, z, applyOffset);
}

// required min & max are block coordinates (min is inclusive, max is non inclusive)
void shape_make_space(Shape *const shape,
                      SHAPE_COORDS_INT_T requiredMinX,
                      SHAPE_COORDS_INT_T requiredMinY,
                      SHAPE_COORDS_INT_T requiredMinZ,
                      SHAPE_COORDS_INT_T requiredMaxX,
                      SHAPE_COORDS_INT_T requiredMaxY,
                      SHAPE_COORDS_INT_T requiredMaxZ,
                      const bool applyOffset) {

    // octree_log(shape->octree);
    // cclog_info("📏 MAKE SPACE | new bounds needed : (%d, %d, %d) -> (%d, %d, %d)",
    //      requiredMinX, requiredMinY, requiredMinZ, requiredMaxX, requiredMaxY, requiredMaxZ);
    // cclog_info("📏 MAKE SPACE | offset : %d %d %d", shape->offset.x, shape->offset.y,
    // shape->offset.z);

    // no need to make space if there is no fixed/allocated size (no octree nor lighting)
    if (_has_fixed_size(shape) == false) {
        cclog_warning(
            "⚠️ shape_make_space: not needed if shape has no fixed size (no octree nor "
            "lighting)");
        return;
    }

    // skip if shape is not allowed to resize
    if (shape->isResizable == false) {
        cclog_warning("⚠️ shape_make_space: trying to resize a non-resizable shape");
        return;
    }

    // Convert provided coordinates from Lua coords into "core" coords if needed.
    if (applyOffset == true) {
        shape_block_lua_to_internal(shape,
                                    &requiredMinX,
                                    &requiredMinY,
                                    &requiredMinZ); // value += offset
        shape_block_lua_to_internal(shape,
                                    &requiredMaxX,
                                    &requiredMaxY,
                                    &requiredMaxZ); // value += offset
    }

    // Check if a resize is needed.
    // If required min/max are within fixed bounds, then extra space is not needed.
    if (shape_is_within_fixed_bounds(shape, requiredMinX, requiredMinY, requiredMinZ) &&
        shape_is_within_fixed_bounds(shape, requiredMaxX, requiredMaxY, requiredMaxZ)) {
        return;
    }

    // cclog_info("📏 RESIZE IS NEEDED");

    // current shape's bounding box limits

    int3 min; // inclusive
    int3_set(&min, shape->box->min.x, shape->box->min.y, shape->box->min.z);

    int3 max; // non inclusive
    int3_set(&max, shape->box->max.x, shape->box->max.y, shape->box->max.z);

    // cclog_trace("📏 CURRENT BOUNDING BOX: (%d,%d,%d) -> (%d,%d,%d)",
    //       min.x, min.y, min.z, max.x, max.y, max.z);

    // additional space required
    int3 spaceRequiredMin = int3_zero;
    int3 spaceRequiredMax = int3_zero;

    if (requiredMinX < min.x) {
        spaceRequiredMin.x = requiredMinX - min.x; // negative, space on the left required
    }

    if (requiredMaxX + 1 > max.x) {
        spaceRequiredMax.x = requiredMaxX + 1 - max.x;
    }

    if (requiredMinY < min.y) {
        spaceRequiredMin.y = requiredMinY - min.y;
    }

    if (requiredMaxY + 1 > max.y) {
        spaceRequiredMax.y = requiredMaxY + 1 - max.y;
    }

    if (requiredMinZ < min.z) {
        spaceRequiredMin.z = requiredMinZ - min.z;
    }

    if (requiredMaxZ + 1 > max.z) {
        spaceRequiredMax.z = requiredMaxZ + 1 - max.z;
    }

    int3 boundingBoxSize; // size of current bounding box
    shape_get_bounding_box_size(shape, &boundingBoxSize);

    vx_assert(spaceRequiredMax.x >= 0);
    vx_assert(spaceRequiredMax.y >= 0);
    vx_assert(spaceRequiredMax.z >= 0);

    int3 requiredSize;
    int3_set(&requiredSize,
             boundingBoxSize.x + abs(spaceRequiredMin.x) + spaceRequiredMax.x,
             boundingBoxSize.y + abs(spaceRequiredMin.y) + spaceRequiredMax.y,
             boundingBoxSize.z + abs(spaceRequiredMin.z) + spaceRequiredMax.z);

    // cclog_info("📏 REQUIRED SIZE: (%d,%d,%d)",
    //       requiredSize.x, requiredSize.y, requiredSize.z);
    // cclog_info("📏 SPACE REQUIRED: min(%d, %d, %d) max(%d, %d, %d)",
    //       spaceRequiredMin.x, spaceRequiredMin.y, spaceRequiredMin.z,
    //       spaceRequiredMax.x, spaceRequiredMax.y, spaceRequiredMax.z);

    if (shape->octree == NULL) {
        cclog_error("shape_make_space not implemented for shape with no octree yet.");
        return;
    }

    // see if octree is big enough, if not we have to create a new one
    // In that case, chunks will have to be recomputed too.
    Octree *octree = NULL;
    Index3D *chunks = NULL;
    size_t nbChunks = 0;

    // largest dimension (among x, y, z)
    const size_t requiredSizeMax = (size_t)(maximum(maximum(requiredSize.x, requiredSize.y),
                                                    requiredSize.z));
    size_t octree_size = octree_get_dimension(shape->octree);

    int3 delta = int3_zero;

    if (requiredSizeMax > octree_size) {

        // cclog_info("📏 OCTREE NOT BIG ENOUGH");
        octree = _new_octree(shape, requiredSize.x, requiredSize.y, requiredSize.z);
        chunks = index3d_new();

        octree_size = octree_get_dimension(octree);

        // min/max is shape's current bounding box
        // `octree_size` is the new octree size

        if (spaceRequiredMin.x < 0 && min.x + spaceRequiredMin.x < 0) {
            delta.x = -(min.x + spaceRequiredMin.x);
        } else if (spaceRequiredMax.x > 0 && max.x + spaceRequiredMax.x > (int)octree_size) {
            delta.x = (int)octree_size - (max.x + spaceRequiredMax.x);
        }

        if (spaceRequiredMin.y < 0 && min.y + spaceRequiredMin.y < 0) {
            delta.y = -(min.y + spaceRequiredMin.y);
        } else if (spaceRequiredMax.y > 0 && max.y + spaceRequiredMax.y > (int)octree_size) {
            delta.y = (int)octree_size - (max.y + spaceRequiredMax.y);
        }

        if (spaceRequiredMin.z < 0 && min.z + spaceRequiredMin.z < 0) {
            delta.z = -(min.z + spaceRequiredMin.z);
        } else if (spaceRequiredMax.z > 0 && max.z + spaceRequiredMax.z > (int)octree_size) {
            delta.z = (int)octree_size - (max.z + spaceRequiredMax.z);
        }

    } else {

        // octree is big enough, let's see if there's enough room around the
        // bounding box to just change its size.

        // NOTE: the bounding box origin can't be below {0,0,0}
        // But shape->offset can be used to represent blocks with negative coordinates

        // When shape_make_space_for_block is called, the offset is already applied.
        // But a block with x == -3 could be offsetted to -1, and that means
        // the bounding box needs to move to be able to contain it.
        // The offset is updated as we move the bounding box.

        if (spaceRequiredMin.x < 0 && min.x + spaceRequiredMin.x < 0) {
            delta.x = -(min.x + spaceRequiredMin.x);
        } else if (spaceRequiredMax.x > 0 && max.x + spaceRequiredMax.x > (int)octree_size) {
            delta.x = (int)octree_size - (max.x + spaceRequiredMax.x);
        }

        if (spaceRequiredMin.y < 0 && min.y + spaceRequiredMin.y < 0) {
            delta.y = -(min.y + spaceRequiredMin.y);
        } else if (spaceRequiredMax.y > 0 && max.y + spaceRequiredMax.y > (int)octree_size) {
            delta.y = (int)octree_size - (max.y + spaceRequiredMax.y);
        }

        if (spaceRequiredMin.z < 0 && min.z + spaceRequiredMin.z < 0) {
            delta.z = -(min.z + spaceRequiredMin.z);
        } else if (spaceRequiredMax.z > 0 && max.z + spaceRequiredMax.z > (int)octree_size) {
            delta.z = (int)octree_size - (max.z + spaceRequiredMax.z);
        }

        if (delta.x != 0 || delta.y != 0 || delta.z != 0) {
            // octree is big enough, but there's no room around the bounding box
            // it needs to be moved to make space for new block.
            // delta is the minimum movement to be applied.
            // But if putting the bounding box at the center satisfies the constraint
            // then it's a preferable option.
            // Let's see for each axis.

            // cclog_info("📏 NO ROOM AROUND BOUNDING BOX");
            // cclog_info("📏 DELTA: (%d, %d, %d)", delta.x, delta.y, delta.z);

            // let's simply recreate the octree in that case
            // but maybe it could be better optimized to just move the blocks

            // NOTE: aduermael: allocating an octree with the same size
            // for operation to be the same as when copying cubes to a larger octree.
            // It would be more lines of code but better optimized to
            // just move blocks within the octree in that case.
            octree = _new_octree(shape, octree_size, octree_size, octree_size);
            chunks = index3d_new();

        } else {
            // octree is big enough AND there's enough room around the bounding box.
            // Let's just make it larger.
            // offset doesn't even have to be changed.
            // The bounding box increases by itself when adding cubes.
            // So we just change the max size.

            // cclog_info("📏 THERE'S ROOM AROUND THE BOUNDING BOX");
            // cclog_info("📏 SPACE REQUIRED: (%d, %d, %d) / (%d, %d, %d)",
            //       spaceRequiredMin.x, spaceRequiredMin.y, spaceRequiredMin.z,
            //       spaceRequiredMax.x, spaceRequiredMax.y, spaceRequiredMax.z);

            if (requiredMaxX >= shape->maxWidth) {
                shape->maxWidth = requiredMaxX + 1;
            }
            if (requiredMaxY >= shape->maxHeight) {
                shape->maxHeight = requiredMaxY + 1;
            }
            if (requiredMaxZ >= shape->maxDepth) {
                shape->maxDepth = requiredMaxZ + 1;
            }

            const uint16_t ax = abs(spaceRequiredMin.x) + spaceRequiredMax.x;
            const uint16_t ay = abs(spaceRequiredMin.y) + spaceRequiredMax.y;
            const uint16_t az = abs(spaceRequiredMin.z) + spaceRequiredMax.z;

            _light_realloc(shape, ax, ay, az, 0, 0, 0);

            return;
        }
    }

    if (chunks == NULL && octree == NULL) {
        return;
    }

    // NOTE: see if we could do this for all 3 cases
    const uint16_t ax = abs(spaceRequiredMin.x) + spaceRequiredMax.x;
    const uint16_t ay = abs(spaceRequiredMin.y) + spaceRequiredMax.y;
    const uint16_t az = abs(spaceRequiredMin.z) + spaceRequiredMax.z;

    if (requiredSize.x > shape->maxWidth)
        shape->maxWidth = requiredSize.x;
    if (requiredSize.y > shape->maxHeight)
        shape->maxHeight = requiredSize.y;
    if (requiredSize.z > shape->maxDepth)
        shape->maxDepth = requiredSize.z;

    // empty current dirty chunks list, if any
    ChunkList *cl = NULL;
    while (shape->needsDisplay != NULL) {
        cl = shape->needsDisplay;
        shape->needsDisplay = cl->next;
        chunk_list_free(cl);
    }
    // shape->needsDisplay is now NULL

    // copy with offsets to blocks position
    Block *block = NULL;
    Block *block_copy = NULL;
    int ox, oy, oz;
    Chunk *chunk = NULL;
    bool chunkAdded = false;

    for (SHAPE_SIZE_INT_T xx = min.x; xx < max.x; ++xx) {
        for (SHAPE_SIZE_INT_T yy = min.y; yy < max.y; ++yy) {
            for (SHAPE_SIZE_INT_T zz = min.z; zz < max.z; ++zz) {

                block = shape_get_block(shape, xx, yy, zz, false);

                if (block_is_solid(block)) {
                    // get offseted position
                    ox = xx + delta.x;
                    oy = yy + delta.y;
                    oz = zz + delta.z;

                    // check if it is within new bounds
                    vx_assert(ox >= 0 && oy >= 0 && oz >= 0 && ox < shape->maxWidth &&
                              oy < shape->maxHeight && oz < shape->maxDepth);

                    vx_assert(octree != NULL);

                    block_copy = block_new_copy(block);

                    // block is again copied within octree_set_element
                    octree_set_element(octree, (const void *)block_copy, ox, oy, oz);

                    // block_copy is stored here, its memory is handled by responsible chunk
                    _add_block_in_chunks(chunks,
                                         block_copy,
                                         ox,
                                         oy,
                                         oz,
                                         NULL,
                                         &chunkAdded,
                                         &chunk,
                                         NULL);

                    // flag this chunk as dirty (needs display)
                    if (chunkAdded) {
                        nbChunks++;
                        shape_chunk_needs_display(shape, chunk);
                    }
                }
            }
        }
    }

    // offset POIS
    {
        MapStringFloat3Iterator *it = shape_get_poi_iterator(shape);

        float3 *poiPosition = NULL;

        while (map_string_float3_iterator_is_done(it) == false) {
            poiPosition = map_string_float3_iterator_current_value(it);
            if (poiPosition == NULL) {
                continue;
            }

            poiPosition->x += (float)(delta.x);
            poiPosition->y += (float)(delta.y);
            poiPosition->z += (float)(delta.z);

            map_string_float3_iterator_next(it);
        }
        map_string_float3_iterator_free(it);
    }

    // offset bounding box
    float3 fDelta;
    float3_set(&fDelta, (float)(delta.x), (float)(delta.y), (float)(delta.z));
    float3_op_add(&shape->box->min, &fDelta);
    float3_op_add(&shape->box->max, &fDelta);
    _shape_clear_cached_world_aabb(shape);

    // fit collider to bounding box
    shape_fit_collider_to_bounding_box(shape);

    // offset pivot
    float3 pivot = shape_get_pivot(shape, false);
    shape_set_pivot(shape,
                    pivot.x + fDelta.x,
                    pivot.y + fDelta.y,
                    pivot.z + fDelta.z,
                    false); // remove offset

    // offset lighting data
    _light_realloc(shape, ax, ay, az, delta.x, delta.y, delta.z);

    octree_free(shape->octree);

    index3d_flush(shape->chunks, shape_chunk_free);
    index3d_free(shape->chunks);

    shape->octree = octree;
    shape->chunks = chunks;
    // cclog_info("-- assign new chunks");

    // update offset
    int3_op_add(&shape->offset, &delta);
}

void shape_refresh_vertices(Shape *shape) {
    // to improve efficiency, write into buffers only if shape was fully initialized,
    // if light is computed later, we would need to rewrite the entire buffer
    if (shape_uses_baked_lighting(shape) && shape_has_baked_lighting_data(shape) == false) {
        // cclog_trace("⚠   shape_refresh_vertices: shape lighting not initialized, skipping...");
        return;
    }

    if (shape->isBakeLocked) {
        _shape_fill_draw_slices(shape->firstVB_opaque);
        _shape_fill_draw_slices(shape->firstVB_transparent);
        return;
    }

    ChunkList *tmp;

    while (shape->needsDisplay != NULL) {
        Chunk *c = shape->needsDisplay->chunk;
        // Note: chunk should never be NULL
        // Note: no need to check chunk_needs_display, it has to be true

        // if the chunk has been emptied, we can remove it from shape index and destroy it
        // Note: this will create gaps in all the vb used for this chunk ie. make them fragmented
        if (chunk_get_nb_blocks(c) == 0) {
            const int3 *pos = chunk_get_pos(c);
            int3 *ldfPos = int3_pool_pop();
            int3_set(ldfPos,
                     pos->x >> CHUNK_WIDTH_SQRT,
                     pos->y >> CHUNK_HEIGHT_SQRT,
                     pos->z >> CHUNK_DEPTH_SQRT);
            index3d_remove(shape->chunks, ldfPos->x, ldfPos->y, ldfPos->z, NULL);
            int3_pool_recycle(ldfPos);

            shape->nbChunks--;

            chunk_destroy(c);

            c = NULL;
        }
        // else chunk has data that needs updating
        else {
            chunk_write_vertices(shape, c);
        }

        tmp = shape->needsDisplay;
        shape->needsDisplay = shape->needsDisplay->next;
        chunk_list_free(tmp);

        if (c != NULL) {
            chunk_set_needs_display(c, false);
        }
    }

    // check all vertex buffers used by this shape, to see if they have to be defragmented
    _shape_check_all_vb_fragmented(shape, shape->firstVB_opaque);
    _shape_check_all_vb_fragmented(shape, shape->firstVB_transparent);

    // DEFRAGMENTATION

    // fill remaining mem area gaps (for all vertex buffers involved)
    VertexBuffer *fragmentedVB = (VertexBuffer *)doubly_linked_list_pop_first(shape->fragmentedVBs);

    // bool log = true; // fragmentedVB != NULL;

    //    if (log) {
    //        shape_log_vertex_buffers(shape, true);
    //    }

    while (fragmentedVB != NULL) {
        vertex_buffer_fill_gaps(fragmentedVB);
        vertex_buffer_set_enlisted(fragmentedVB, false);

        fragmentedVB = (VertexBuffer *)doubly_linked_list_pop_first(shape->fragmentedVBs);
    }

    //    if (log) {
    //        shape_log_vertex_buffers(shape, true);
    //    }

    // fill draw slices after defragmentation
    _shape_fill_draw_slices(shape->firstVB_opaque);
    _shape_fill_draw_slices(shape->firstVB_transparent);

    _set_vb_allocation_flag_one_frame(shape);
}

void shape_refresh_all_vertices(Shape *s) {
    // refresh all chunks
    Index3DIterator *it = index3d_iterator_new(s->chunks);
    while (index3d_iterator_pointer(it) != NULL) {
        chunk_write_vertices(s, index3d_iterator_pointer(it));
        index3d_iterator_next(it);
    }

    // refresh draw slices after full refresh
    _shape_fill_draw_slices(s->firstVB_opaque);
    _shape_fill_draw_slices(s->firstVB_transparent);

    // flush needsDisplay list
    ChunkList *cl;
    while (s->needsDisplay != NULL) {
        cl = s->needsDisplay;
        s->needsDisplay = cl->next;
        chunk_list_free(cl);
    }
}

VertexBuffer *shape_get_first_vertex_buffer(const Shape *shape, bool transparent) {
    return transparent ? shape->firstVB_transparent : shape->firstVB_opaque;
}

Index3DIterator *shape_new_chunk_iterator(const Shape *shape) {
    Index3DIterator *it = index3d_iterator_new(shape->chunks);
    return it;
}

size_t shape_get_nb_chunks(const Shape *shape) {
    return shape->nbChunks;
}

size_t shape_get_nb_blocks(const Shape *shape) {
    return shape->nbBlocks;
}

const Octree *shape_get_octree(const Shape *shape) {
    return shape->octree;
}

void shape_log_vertex_buffers(const Shape *shape, bool dirtyOnly, bool transparent) {
    VertexBuffer *vb = transparent ? shape->firstVB_transparent : shape->firstVB_opaque;
    int i = 1;

    bool firstDisplay = true;

    while (vb != NULL) {

        if (dirtyOnly) {
            if (vertex_buffer_has_dirty_mem_areas(vb) == false) {
                vb = vertex_buffer_get_next(vb);
                i++;
                continue;
            }
        }

        if (firstDisplay) {
            cclog_debug("");
            if (dirtyOnly) {
                cclog_debug("SHAPE'S (DIRTY) VERTEX BUFFERS:");
            } else {
                cclog_debug("SHAPE'S VERTEX BUFFERS:");
            }
            cclog_debug("--------------------------");
            firstDisplay = false;
        }

        cclog_debug("#%d", i);
        cclog_debug("--------------------------");
        vertex_buffer_log_mem_areas(vb);
        vb = vertex_buffer_get_next(vb);
        i++;
    }
}

void shape_set_model_locked(Shape *s, bool toggle) {
    s->isBakeLocked = toggle;
}

bool shape_is_model_locked(Shape *s) {
    return s->isBakeLocked;
}

void shape_set_fullname(Shape *s, const char *fullname) {
    if (s->fullname != NULL) {
        free(s->fullname);
    }
    s->fullname = string_new_copy(fullname);
}

const char *shape_get_fullname(const Shape *s) {
    return s->fullname;
}

// MARK: - Transform -

void shape_set_pivot(Shape *s, const float x, const float y, const float z, bool removeOffset) {
    if (s == NULL) {
        return;
    }

    // avoid unnecessary pivot
    if (s->pivot == NULL && float_isZero(x, EPSILON_ZERO) && float_isZero(y, EPSILON_ZERO) &&
        float_isZero(z, EPSILON_ZERO)) {
        return;
    }

    if (s->pivot == NULL) {
        // add a pivot internal transform, managed by shape
        s->pivot = transform_make_with_ptr(HierarchyTransform, s, 0, NULL);
        transform_set_parent(s->pivot, s->transform, false);
    }

    if (removeOffset) {
        transform_set_local_position(s->pivot,
                                     -x + (float)(s->offset.x),
                                     -y + (float)(s->offset.y),
                                     -z + (float)(s->offset.z));
    } else {
        transform_set_local_position(s->pivot, -x, -y, -z);
    }
}

float3 shape_get_pivot(const Shape *s, bool applyOffset) {
    if (s == NULL || s->pivot == NULL)
        return float3_zero;

    const float3 *p = transform_get_local_position(s->pivot);
    float3 np = {-p->x, -p->y, -p->z};
    if (applyOffset) {
        np.x -= (float)(s->offset.x);
        np.y -= (float)(s->offset.y);
        np.z -= (float)(s->offset.z);
    }
    return np;
}

void shape_reset_pivot_to_center(Shape *s) {
    if (s == NULL)
        return;

    int3 size;
    shape_get_bounding_box_size(s, &size);
    shape_set_pivot(s,
                    s->box->min.x + size.x * .5f,
                    s->box->min.y + size.y * .5f,
                    s->box->min.z + size.z * .5f,
                    false);
}

float3 shape_block_to_local(const Shape *s, const float x, const float y, const float z) {
    if (s == NULL)
        return float3_zero;

    const float3 offsetedPivot = shape_get_pivot(s, true);
    float3 local = {x - offsetedPivot.x, y - offsetedPivot.y, z - offsetedPivot.z};
    return local;
}

float3 shape_block_to_world(const Shape *s, const float x, const float y, const float z) {
    if (s == NULL)
        return float3_zero;

    Transform *t = shape_get_root_transform(s);
    float3 local = shape_block_to_local(s, x, y, z);
    float3 world;
    transform_refresh(t, false, true); // refresh ltw for intra-frame calculations
    transform_utils_position_ltw(t, &local, &world);
    return world;
}

float3 shape_local_to_block(const Shape *s, const float x, const float y, const float z) {
    if (s == NULL)
        return float3_zero;

    float3 offsetedPivot = shape_get_pivot(s, true);
    float3 block = {x + offsetedPivot.x, y + offsetedPivot.y, z + offsetedPivot.z};
    return block;
}

float3 shape_world_to_block(const Shape *s, const float x, const float y, const float z) {
    if (s == NULL)
        return float3_zero;

    Transform *t = shape_get_root_transform(s);
    float3 world = {x, y, z};
    float3 local;
    transform_refresh(t, false, true); // refresh wtl for intra-frame calculations
    transform_utils_position_wtl(t, &world, &local);
    return shape_local_to_block(s, local.x, local.y, local.z);
}

void shape_block_lua_to_internal(const Shape *s,
                                 SHAPE_COORDS_INT_T *x,
                                 SHAPE_COORDS_INT_T *y,
                                 SHAPE_COORDS_INT_T *z) {
    if (s == NULL || x == NULL || y == NULL || z == NULL) {
        return;
    }

    *x += s->offset.x;
    *y += s->offset.y;
    *z += s->offset.z;
}

void shape_block_internal_to_lua(const Shape *s,
                                 SHAPE_COORDS_INT_T *x,
                                 SHAPE_COORDS_INT_T *y,
                                 SHAPE_COORDS_INT_T *z) {
    if (s == NULL || x == NULL || y == NULL || z == NULL)
        return;

    *x -= s->offset.x;
    *y -= s->offset.y;
    *z -= s->offset.z;
}

void shape_block_lua_to_internal_float(const Shape *s, float *x, float *y, float *z) {
    if (s == NULL || x == NULL || y == NULL || z == NULL)
        return;

    *x += s->offset.x;
    *y += s->offset.y;
    *z += s->offset.z;
}

void shape_block_internal_to_lua_float(const Shape *s, float *x, float *y, float *z) {
    if (s == NULL || x == NULL || y == NULL || z == NULL)
        return;

    *x -= s->offset.x;
    *y -= s->offset.y;
    *z -= s->offset.z;
}

void shape_set_position(Shape *s, const float x, const float y, const float z) {
    if (s == NULL) {
        return;
    }
    transform_set_position(s->transform, x, y, z);
}

void shape_set_local_position(Shape *s, const float x, const float y, const float z) {
    if (s == NULL) {
        return;
    }
    transform_set_local_position(s->transform, x, y, z);
}

const float3 *shape_get_position(const Shape *s) {
    if (s == NULL) {
        return NULL;
    }
    return transform_get_position(s->transform);
}

const float3 *shape_get_local_position(const Shape *s) {
    if (s == NULL) {
        return NULL;
    }
    return transform_get_local_position(s->transform);
}

const float3 *shape_get_model_origin(const Shape *s) {
    if (s == NULL)
        return &float3_zero;

    return transform_get_position(s->pivot != NULL ? s->pivot : s->transform);
}

void shape_set_rotation(Shape *s, Quaternion *q) {
    if (s == NULL)
        return;

    transform_set_rotation(s->transform, q);
}

void shape_set_rotation_euler(Shape *s, const float x, const float y, const float z) {
    if (s == NULL)
        return;

    transform_set_rotation_euler(s->transform, x, y, z);
}

void shape_set_local_rotation(Shape *s, Quaternion *q) {
    if (s == NULL)
        return;

    transform_set_local_rotation(s->transform, q);
}

void shape_set_local_rotation_euler(Shape *s, const float x, const float y, const float z) {
    if (s == NULL)
        return;

    transform_set_local_rotation_euler(s->transform, x, y, z);
}

Quaternion *shape_get_rotation(const Shape *s) {
    if (s == NULL)
        return NULL;

    return transform_get_rotation(s->transform);
}

void shape_get_rotation_euler(const Shape *s, float3 *euler) {
    if (s == NULL)
        return;

    transform_get_rotation_euler(s->transform, euler);
}

Quaternion *shape_get_local_rotation(const Shape *s) {
    if (s == NULL)
        return NULL;

    return transform_get_local_rotation(s->transform);
}

void shape_get_local_rotation_euler(const Shape *s, float3 *euler) {
    if (s == NULL)
        return;

    transform_get_local_rotation_euler(s->transform, euler);
}

///
void shape_set_local_scale(Shape *s, const float x, const float y, const float z) {
    if (s == NULL) {
        return;
    }
    transform_set_local_scale(s->transform, x, y, z);
}

const float3 *shape_get_local_scale(const Shape *s) {
    if (s == NULL) {
        return &float3_zero;
    }
    return transform_get_local_scale(s->transform);
}

void shape_get_lossy_scale(const Shape *s, float3 *scale) {
    if (s == NULL) {
        return;
    }
    transform_get_lossy_scale(s->transform, scale);
}

/// returns a pointer on the shape's model matrix
const Matrix4x4 *shape_get_model_matrix(Shape *s) {
    if (s == NULL) {
        return NULL;
    }
    return transform_get_ltw(shape_get_pivot_transform(s));
}

bool shape_set_parent(Shape *s, Transform *parent, const bool keepWorld) {
    if (s == NULL) {
        return false;
    }
    if (parent == NULL) {
        return false;
    }

    return transform_set_parent(s->transform, parent, keepWorld);
}

bool shape_remove_parent(Shape *s, const bool keepWorld) {
    if (s == NULL) {
        return false;
    }

    return transform_remove_parent(s->transform, keepWorld);
}

Transform *shape_get_root_transform(const Shape *s) {
    return s->transform;
}

Transform *shape_get_pivot_transform(const Shape *s) {
    return s->pivot != NULL ? s->pivot : s->transform;
}

void shape_move_children(Shape *from, Shape *to, const bool keepWorld) {
    if (from->pivot == NULL) {
        transform_utils_move_children(from->transform, to->transform, keepWorld);
    } else {
        // move children excluding pivot
        if (transform_get_children_count(from->transform) > 1) {
            size_t count = 0;
            Transform_Array children = transform_get_children_copy(from->transform, &count);
            for (size_t i = 0; i < count; ++i) {
                if (children[i] != from->pivot) {
                    transform_set_parent(children[i], to->transform, keepWorld);
                }
            }
            free(children);
        }
        // if anything was parented to pivot, move them too
        if (transform_get_children_count(from->pivot) > 0) {
            transform_utils_move_children(from->pivot, shape_get_pivot_transform(to), keepWorld);
        }
    }
}

uint32_t shape_count_shape_descendants(const Shape *s) {
    uint32_t nbDescendants = 0;

    DoublyLinkedListNode *n = shape_get_transform_children_iterator(s);
    Transform *childTransform = NULL;
    Shape *child = NULL;
    while (n != NULL) {
        childTransform = (Transform *)(doubly_linked_list_node_pointer(n));

        child = transform_get_shape(childTransform);
        if (child == NULL) { // not a shape
            n = doubly_linked_list_node_next(n);
            continue;
        }
        nbDescendants += 1;

        // Recursively find descendants of child
        nbDescendants += shape_count_shape_descendants(child);
        n = doubly_linked_list_node_next(n);
    }
    return nbDescendants;
}

DoublyLinkedListNode *shape_get_transform_children_iterator(const Shape *s) {
    return transform_get_children_iterator(shape_get_root_transform((s)));
}

// MARK: - Physics -

RigidBody *shape_get_rigidbody(const Shape *s) {
    vx_assert(s != NULL);
    vx_assert(s->transform != NULL);
    return transform_get_rigidbody(s->transform);
}

uint8_t shape_get_collision_groups(const Shape *s) {
    vx_assert(s != NULL);
    RigidBody *rb = shape_get_rigidbody(s);
    if (rb == NULL)
        return PHYSICS_GROUP_NONE;
    return rigidbody_get_groups(rb);
}

void shape_ensure_rigidbody(Shape *s, const uint8_t groups, const uint8_t collidesWith) {
    vx_assert(s != NULL);

    RigidBody *rb = shape_get_rigidbody(s);

    if (rb == NULL) {
        rb = rigidbody_new(RigidbodyModeStatic, groups, collidesWith);
        transform_set_rigidbody(s->transform, rb);
        shape_fit_collider_to_bounding_box(s);
    } else {
        rigidbody_set_groups(rb, groups);
        rigidbody_set_collides_with(rb, collidesWith);
    }
}

bool shape_get_physics_enabled(const Shape *s) {
    vx_assert(s != NULL);
    return rigidbody_get_simulation_mode(shape_get_rigidbody(s)) == RigidbodyModeDynamic;
}

void shape_set_physics_enabled(const Shape *s, const bool enabled) {
    vx_assert(s != NULL);
    if (shape_get_rigidbody(s) == NULL)
        return;
    shape_set_physics_simulation_mode(s, enabled ? RigidbodyModeDynamic : RigidbodyModeStatic);
}

void shape_fit_collider_to_bounding_box(const Shape *s) {
    vx_assert(s != NULL);
    RigidBody *rb = shape_get_rigidbody(s);
    if (rb == NULL)
        return;
    rigidbody_set_collider(rb, s->box);
}

const Box *shape_get_local_collider(const Shape *s) {
    vx_assert(s != NULL);
    RigidBody *rb = shape_get_rigidbody(s);
    if (rb == NULL)
        return NULL;
    return rigidbody_get_collider(rb);
}

void shape_compute_world_collider(const Shape *s, Box *box) {
    vx_assert(s != NULL);
    RigidBody *rb = shape_get_rigidbody(s);
    if (rb == NULL)
        return;
    shape_box_to_aabox(s,
                       rigidbody_get_collider(rb),
                       box,
                       true,
                       rigidbody_get_collider_custom(rb) == false);
}

void shape_set_physics_simulation_mode(const Shape *s, const uint8_t value) {
    vx_assert(s != NULL);
    RigidBody *rb = shape_get_rigidbody(s);
    if (rb == NULL)
        return;

    // reset rigidbody when disabling physics, but keep changes made in Lua prior to enabling
    // physics
    if (value != RigidbodyModeDynamic &&
        rigidbody_get_simulation_mode(rb) == RigidbodyModeDynamic) {
        rigidbody_reset(rb);
    }
    rigidbody_set_simulation_mode(rb, value);
}

void shape_set_physics_properties(const Shape *s,
                                  const float mass,
                                  const float friction,
                                  const float bounciness) {
    vx_assert(s != NULL);
    RigidBody *rb = shape_get_rigidbody(s);
    if (rb == NULL)
        return;
    rigidbody_set_mass(rb, mass);
    rigidbody_set_friction(rb, friction);
    rigidbody_set_bounciness(rb, bounciness);
}

// MARK: - Graphics -

bool shape_is_hidden(Shape *s) {
    if (s == NULL) {
        return false;
    }
    return transform_is_hidden(s->transform);
}

void shape_set_draw_mode(Shape *s, ShapeDrawMode m) {
    if (s == NULL) {
        return;
    }
    s->drawMode = m;
}

ShapeDrawMode shape_get_draw_mode(const Shape *s) {
    if (s == NULL) {
        return SHAPE_DRAWMODE_DEFAULT;
    }
    return s->drawMode;
}

void shape_set_shadow_decal(Shape *s, const bool toggle) {
    if (s == NULL) {
        return;
    }
    s->shadowDecal = toggle;
}

bool shape_has_shadow_decal(const Shape *s) {
    if (s == NULL) {
        return false;
    }
    return s->shadowDecal;
}

void shape_set_unlit(Shape *s, const bool value) {
    s->isUnlit = value;
}

bool shape_is_unlit(const Shape *s) {
    return s->isUnlit;
}

void shape_set_layers(Shape *s, const uint8_t value) {
    s->layers = value;
}

uint8_t shape_get_layers(const Shape *s) {
    return s->layers;
}

// MARK: -

float shape_box_swept(const Shape *s,
                      const Box *b,
                      const float3 *v,
                      const bool withReplacement,
                      float3 *swept3,
                      float3 *extraReplacement,
                      const float epsilon) {

    if (s->octree == NULL) {
        cclog_error("shape_box_swept can't be used if octree is NULL.");
        return 1.0f;
    }

    OctreeIterator *oi = octree_iterator_new(s->octree);

    Box broadPhaseBox, tmpBox;

    box_set_broadphase_box(b, v, &broadPhaseBox);

    bool leaf = false;
    bool collides;
    // size_t nbcubes = 0;
    float3 tmpNormal, tmpReplacement;
    float minSwept = 1.0f;
    float swept = 1.0f;

    float3 scale;
    shape_get_lossy_scale(s, &scale);
    const float3 *modelOrigin = shape_get_model_origin(s);

    if (swept3 != NULL) {
        float3_set_one(swept3);
    }

    if (extraReplacement != NULL) {
        float3_set_zero(extraReplacement);
    }
#if PHYSICS_EXTRA_REPLACEMENTS
    float blockedX = false, blockedY = false, blockedZ = false;
#endif

    while (octree_iterator_is_done(oi) == false) {

        octree_iterator_get_node_box(oi, &tmpBox);
        box_to_aabox_no_rot(&tmpBox, &tmpBox, modelOrigin, &float3_zero, &scale, false);

        collides = box_collide(&tmpBox, &broadPhaseBox);

        if (leaf) {
            if (collides) {
                // nbcubes++;
                swept = box_swept(b,
                                  v,
                                  &tmpBox,
                                  withReplacement,
                                  &tmpNormal,
                                  &tmpReplacement,
                                  epsilon);
                if (swept < minSwept) {
                    minSwept = swept;
                }
                if (swept3 != NULL) {
                    if (tmpNormal.x != 0.0f) {
                        swept3->x = minimum(swept, swept3->x);
                    } else if (tmpNormal.y != 0.0f) {
                        swept3->y = minimum(swept, swept3->y);
                    } else if (tmpNormal.z != 0.0f) {
                        swept3->z = minimum(swept, swept3->z);
                    }
                }
#if PHYSICS_EXTRA_REPLACEMENTS
                if (extraReplacement != NULL) {
                    if (tmpReplacement.x != 0.0f && blockedX == false) {
                        // previous replacement is positive and new replacement is positive & bigger
                        if (extraReplacement->x >= 0.0f && tmpReplacement.x > extraReplacement->x) {
                            extraReplacement->x = tmpReplacement.x;
                        }
                        // previous replacement is negative and new replacement is negative & bigger
                        else if (extraReplacement->x <= 0.0f &&
                                 tmpReplacement.x < extraReplacement->x) {
                            extraReplacement->x = tmpReplacement.x;
                        }
                        // previous & new replacements are opposite... this axis is blocked,
                        // set to 0 to avoid stuttering and wait for another axis to replace
                        else if (extraReplacement->x * tmpReplacement.x < 0.0f) {
                            extraReplacement->x = 0.0f;
                            blockedX = true;
                        }
                    }
                    if (tmpReplacement.y != 0.0f && blockedY == false) {
                        if (extraReplacement->y >= 0.0f && tmpReplacement.y > extraReplacement->y) {
                            extraReplacement->y = tmpReplacement.y;
                        } else if (extraReplacement->y <= 0.0f &&
                                   tmpReplacement.y < extraReplacement->y) {
                            extraReplacement->y = tmpReplacement.y;
                        } else if (extraReplacement->y * tmpReplacement.y < 0.0f) {
                            extraReplacement->y = 0.0f;
                            blockedX = true;
                        }
                    }
                    if (tmpReplacement.z != 0.0f && blockedZ == false) {
                        if (extraReplacement->z >= 0.0f && tmpReplacement.z > extraReplacement->z) {
                            extraReplacement->z = tmpReplacement.z;
                        } else if (extraReplacement->z <= 0.0f &&
                                   tmpReplacement.z < extraReplacement->z) {
                            extraReplacement->z = tmpReplacement.z;
                        } else if (extraReplacement->z * tmpReplacement.z < 0.0f) {
                            extraReplacement->z = 0.0f;
                            blockedX = true;
                        }
                    }
                }
#endif
            }
        }

        octree_iterator_next(oi, collides == false && leaf == false, &leaf);
    }

    // printf("found %zu cubes\n", nbcubes);

    octree_iterator_free(oi);

    return minSwept;
}

///
bool shape_ray_cast(const Shape *sh,
                    const Ray *worldRay,
                    float *worldDistance,
                    float3 *localImpact,
                    Block **block,
                    uint16_t *x,
                    uint16_t *y,
                    uint16_t *z) {

    if (sh == NULL) {
        return false;
    }
    if (worldRay == NULL) {
        return false;
    }

    if (sh->octree == NULL) {
        cclog_error("shape_ray_cast can't be used if octree is NULL");
        return false;
    }

    OctreeIterator *oi = octree_iterator_new(sh->octree);

    Box tmpBox;
    bool leaf = false;
    bool collides = false;
    Block *b = NULL;
    // uint16_t nodeSize = 0;
    float d = 0;
    float minDistance = FLT_MAX;
    uint16_t _x = 0;
    uint16_t _y = 0;
    uint16_t _z = 0;

    // we want a local ray to intersect with octree coordinates
    Transform *t = shape_get_pivot_transform(sh); // octree coordinates use model origin
    float3 localRayPoint, localRayDir;
    transform_utils_position_wtl(t, worldRay->origin, &localRayPoint);
    transform_utils_vector_wtl(t, worldRay->dir, &localRayDir);
    float3_normalize(&localRayDir);
    Ray *localRay = ray_new(&localRayPoint, &localRayDir);

    while (octree_iterator_is_done(oi) == false) {
        octree_iterator_get_node_box(oi, &tmpBox);

        collides = ray_intersect_with_box(localRay, &tmpBox.min, &tmpBox.max, &d);
        if (d > minDistance) {
            collides = false; // skip, collision already found closer
        }
        if (collides == true) {
            if (leaf == true) {
                if (d < minDistance) {
                    minDistance = d;
                    b = (Block *)octree_iterator_get_element(oi);
                    // nodeSize = octree_iterator_get_current_node_size(oi);
                    octree_iterator_get_current_position(oi, &_x, &_y, &_z);
                }
            }
        }

        octree_iterator_next(oi, collides == false && leaf == false, &leaf);
    }

    octree_iterator_free(oi);
    oi = NULL;

    if (b == NULL) {
        ray_destroy(localRay);

        return false;
    }

    if (worldDistance != NULL || localImpact != NULL) {
        float3 _localImpact;
        ray_impact_point(localRay, minDistance, &_localImpact);
        if (localImpact != NULL) {
            *localImpact = _localImpact;
        }

        if (worldDistance != NULL) {
            float3 worldImpact;
            transform_utils_position_ltw(t, &_localImpact, &worldImpact);
            float3_op_substract(&worldImpact, worldRay->origin);
            *worldDistance = float3_length(&worldImpact);
        }
    }

    if (block != NULL) {
        *block = b;
    }

    if (x != NULL) {
        *x = _x;
    }

    if (y != NULL) {
        *y = _y;
    }

    if (z != NULL) {
        *z = _z;
    }

    ray_destroy(localRay);

    return true;
}

bool shape_point_overlap(const Shape *s, const float3 *world) {
    if (s->octree == NULL) {
        cclog_error("shape_point_overlap can't be used if octree is NULL.");
        return false;
    }

    Transform *t = shape_get_pivot_transform(s); // octree coordinates use model origin
    float3 model;
    transform_utils_position_wtl(t, world, &model);

    void *element = NULL;

    octree_get_element_or_empty_value(s->octree,
                                      (size_t)model.x,
                                      (size_t)model.y,
                                      (size_t)model.z,
                                      &element,
                                      NULL);

    if (element != NULL) {
        return true; // collides!
    }

    return false;
}

bool shape_box_overlap(const Shape *s, const Box *worldBox, float3 *firstOverlap) {
    if (s->octree == NULL) {
        cclog_error("shape_box_overlap can't be used if octree is NULL.");
        return false;
    }

    Box tmpBox;
    bool leaf = false, collides;

    float3 scale;
    shape_get_lossy_scale(s, &scale);
    const float3 *modelOrigin = shape_get_model_origin(s);

    OctreeIterator *oi = octree_iterator_new(s->octree);
    while (octree_iterator_is_done(oi) == false) {
        octree_iterator_get_node_box(oi, &tmpBox);
        box_to_aabox_no_rot(&tmpBox, &tmpBox, modelOrigin, &float3_zero, &scale, false);

        collides = box_collide(&tmpBox, worldBox);
        if (leaf && collides) {
            if (firstOverlap != NULL) {
                float3_copy(firstOverlap, &tmpBox.min);
            }
            octree_iterator_free(oi);
            return true;
        }

        octree_iterator_next(oi, collides == false && leaf == false, &leaf);
    }
    octree_iterator_free(oi);

    return false;
}

MapStringFloat3Iterator *shape_get_poi_iterator(const Shape *s) {
    return map_string_float3_iterator_new(s->POIs);
}

void shape_set_point_of_interest(Shape *s, const char *key, const float3 *f3) {
    // value is going to be freed when removed from the map
    map_string_float3_set_key_value(s->POIs, key, float3_new_copy(f3));
}

const float3 *shape_get_point_of_interest(const Shape *s, const char *key) {
    return map_string_float3_value_for_key(s->POIs, key);
}

MapStringFloat3Iterator *shape_get_point_rotation_iterator(const Shape *s) {
    return map_string_float3_iterator_new(s->pois_rotation);
}

void shape_set_point_rotation(Shape *s, const char *key, const float3 *f3) {
    // copying f3 because it's going to be freed when removed from the map
    map_string_float3_set_key_value(s->pois_rotation, key, float3_new_copy(f3));
}

const float3 *shape_get_point_rotation(const Shape *s, const char *key) {
    return map_string_float3_value_for_key(s->pois_rotation, key);
}

void shape_debug_points_of_interest(const Shape *s) {
    map_string_float3_debug(s->POIs);
}

void shape_remove_point(Shape *s, const char *key) {
    map_string_float3_remove_key(s->POIs, key);
    map_string_float3_remove_key(s->pois_rotation, key);
}

// MARK: - Baked lighting -

void shape_clear_baked_lighting(Shape *s) {
    if (_lighting_is_enabled(s) == false) {
#if SHAPE_LIGHTING_DEBUG
        cclog_debug("🔥 shape_clear_baked_lighting: baked lighting disabled");
#endif
        return;
    }

    if (s->lightingData == NULL) {
#if SHAPE_LIGHTING_DEBUG
        cclog_error("🔥 shape_clear_baked_lighting: shape doesn't have lighting data");
#endif
        return;
    }

    size_t lightingSize = s->maxWidth * s->maxHeight * s->maxDepth * sizeof(VERTEX_LIGHT_STRUCT_T);
    memset(s->lightingData, 0, lightingSize);
}

void shape_compute_baked_lighting(Shape *s, bool overwrite) {
    if (_lighting_is_enabled(s) == false) {
#if SHAPE_LIGHTING_DEBUG
        cclog_debug("🔥 shape_compute_baked_lighting: baked lighting disabled");
#endif
        return;
    }

    if (shape_has_baked_lighting_data(s)) {
        if (overwrite == false) {
#if SHAPE_LIGHTING_DEBUG
            cclog_error("shape_compute_baked_lighting: shape lighting already computed");
#endif
            return;
        }
    }

    size_t lightingSize = s->maxWidth * s->maxHeight * s->maxDepth * sizeof(VERTEX_LIGHT_STRUCT_T);
    if (s->lightingData == NULL) {
        s->lightingData = (VERTEX_LIGHT_STRUCT_T *)malloc(lightingSize);
    }
    memset(s->lightingData, 0, lightingSize);

    LightNodeQueue *q = light_node_queue_new();
    int3 i3;

    // Sunlight sources: all blocks on x & z, one block above map limit & beyond the sides
    i3.y = (int)s->maxHeight;
    for (SHAPE_COORDS_INT_T x = -1; x <= s->maxWidth; ++x) {
        for (SHAPE_COORDS_INT_T z = -1; z <= s->maxDepth; ++z) {
            i3.x = x;
            i3.z = z;
            light_node_queue_push(q, &i3);
        }
    }

    // Block sources: need to loop over the whole model to discover all emissive blocks
    Block *b;
    for (SHAPE_COORDS_INT_T x = 0; x < s->maxWidth; ++x) {
        for (SHAPE_COORDS_INT_T y = 0; y < s->maxHeight; ++y) {
            for (SHAPE_COORDS_INT_T z = 0; z < s->maxDepth; ++z) {
                b = shape_get_block(s, x, y, z, false);
                if (color_palette_is_emissive(s->palette, b->colorIndex)) {
                    i3.x = x;
                    i3.y = y;
                    i3.z = z;
                    light_node_queue_push(q, &i3);
                }
            }
        }
    }

    // Then we run the regular light propagation algorithm
    _light_propagate(s, NULL, NULL, q, -1, s->maxHeight, -1);

    light_node_queue_free(q);

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("Shape light computed");
#endif
}

bool shape_uses_baked_lighting(const Shape *s) {
    return s->usesLighting;
}

bool shape_has_baked_lighting_data(Shape *s) {
    return s->lightingData != NULL;
}

const VERTEX_LIGHT_STRUCT_T *shape_get_lighting_data(const Shape *s) {
    return s->lightingData;
}

void shape_set_lighting_data(Shape *s, VERTEX_LIGHT_STRUCT_T *d) {
    s->lightingData = d;
}

VERTEX_LIGHT_STRUCT_T shape_get_light_without_checking(const Shape *s, int x, int y, int z) {
    return s->lightingData[x * s->maxHeight * s->maxDepth + y * s->maxDepth + z];
}

void shape_set_light(Shape *s, int x, int y, int z, VERTEX_LIGHT_STRUCT_T light) {
    if (x >= 0 && x < s->maxWidth && y >= 0 && y < s->maxHeight && z >= 0 && z < s->maxDepth) {
        s->lightingData[x * s->maxHeight * s->maxDepth + y * s->maxDepth + z] = light;
    }
}

VERTEX_LIGHT_STRUCT_T shape_get_light_or_default(Shape *s, int x, int y, int z, bool isDefault) {
    if (isDefault || s->lightingData == NULL || shape_is_within_fixed_bounds(s, x, y, z) == false) {
        VERTEX_LIGHT_STRUCT_T light;
        DEFAULT_LIGHT(light)
        return light;
    } else {
        return shape_get_light_without_checking(s, x, y, z);
    }
}

void shape_compute_baked_lighting_removed_block(Shape *s,
                                                const int x,
                                                const int y,
                                                const int z,
                                                SHAPE_COLOR_INDEX_INT_T blockID) {
    if (s == NULL) {
        return;
    }

    if (_lighting_is_enabled(s) == false) {
#if SHAPE_LIGHTING_DEBUG
        cclog_debug("🔥 shape_compute_baked_lighting_removed_block: baked lighting disabled");
#endif
        return;
    }

    if (s->lightingData == NULL) {
        cclog_error(
            "🔥 shape_compute_baked_lighting_removed_block: shape doesn't have lighting data");
        return;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️☀️☀️ compute light for removed block (%d, %d, %d)", x, y, z);
#endif

    int3 i3;
    LightNodeQueue *lightQueue = light_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    int3 min, max;
    min.x = max.x = x;
    min.y = max.y = y;
    min.z = max.z = z;

    // get existing values
    VERTEX_LIGHT_STRUCT_T existingLight = shape_get_light_without_checking(s, x, y, z);

    // if self is emissive, start light removal
    if (existingLight.red > 0 || existingLight.green > 0 || existingLight.blue > 0) {
        LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

        i3.x = x;
        i3.y = y;
        i3.z = z;
        light_removal_node_queue_push(lightRemovalQueue, &i3, existingLight, 15, blockID);

        // run light removal
        _light_removal(s, &min, &max, lightRemovalQueue, lightQueue);

        light_removal_node_queue_free(lightRemovalQueue);
    }

    // add all neighbors to light propagation queue
    {
        // x + 1
        i3.x = x + 1;
        i3.y = y;
        i3.z = z;
        light_node_queue_push(lightQueue, &i3);

        // x - 1
        i3.x = x - 1;
        i3.y = y;
        i3.z = z;
        light_node_queue_push(lightQueue, &i3);

        // y + 1
        i3.x = x;
        i3.y = y + 1;
        i3.z = z;
        light_node_queue_push(lightQueue, &i3);

        // y - 1
        i3.x = x;
        i3.y = y - 1;
        i3.z = z;
        light_node_queue_push(lightQueue, &i3);

        // z + 1
        i3.x = x;
        i3.y = y;
        i3.z = z + 1;
        light_node_queue_push(lightQueue, &i3);

        // z - 1
        i3.x = x;
        i3.y = y;
        i3.z = z - 1;
        light_node_queue_push(lightQueue, &i3);
    }

    // self light values are now 0
    VERTEX_LIGHT_STRUCT_T zero;
    ZERO_LIGHT(zero)
    shape_set_light(s, x, y, z, zero);

    // Then we run the regular light propagation algorithm
    _light_propagate(s, &min, &max, lightQueue, x, y, z);

    light_node_queue_free(lightQueue);
}

void shape_compute_baked_lighting_added_block(Shape *s,
                                              const int x,
                                              const int y,
                                              const int z,
                                              SHAPE_COLOR_INDEX_INT_T blockID) {

    if (s == NULL) {
        return;
    }

    if (_lighting_is_enabled(s) == false) {
#if SHAPE_LIGHTING_DEBUG
        cclog_debug("🔥 shape_compute_baked_lighting_added_block: baked lighting disabled");
#endif
        return;
    }

    if (s->lightingData == NULL) {
        cclog_error("🔥 shape_compute_baked_lighting_added_block: shape doesn't have lighting data");
        return;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️☀️☀️ compute light for added block (%d, %d, %d)", x, y, z);
#endif

    int3 i3;
    LightNodeQueue *lightQueue = light_node_queue_new();
    LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    int3 min, max;
    min.x = max.x = x;
    min.y = max.y = y;
    min.z = max.z = z;

    i3.x = x;
    i3.y = y;
    i3.z = z;

    // get existing and new light values
    VERTEX_LIGHT_STRUCT_T existingLight = shape_get_light_without_checking(s, x, y, z);
    VERTEX_LIGHT_STRUCT_T newLight = color_palette_get_emissive_color_as_light(s->palette, blockID);

    // if emissive, add it to the light propagation queue & store original emission of the block
    // note: we do this since palette may have been changed when running light removal at a later
    // point
    if (newLight.red > 0 || newLight.green > 0 || newLight.blue > 0) {
        light_node_queue_push(lightQueue, &i3);
        shape_set_light(s, x, y, z, newLight);
    }

    // start light removal from current position as an air block w/ existingLight
    light_removal_node_queue_push(lightRemovalQueue, &i3, existingLight, 15, 255);

    // check in the vicinity for any emissive block that would be affected by the added block
    Block *block = NULL;
    VERTEX_LIGHT_STRUCT_T light;
    for (int xo = -1; xo <= 1; xo++) {
        for (int yo = -1; yo <= 1; yo++) {
            for (int zo = -1; zo <= 1; zo++) {
                if (xo == 0 && yo == 0 && zo == 0) {
                    continue;
                }

                i3.x = x + xo;
                i3.y = y + yo;
                i3.z = z + zo;

                block = shape_get_block(s, i3.x, i3.y, i3.z, false);
                if (block != NULL && color_palette_is_emissive(s->palette, block->colorIndex)) {
                    light = color_palette_get_emissive_color_as_light(s->palette,
                                                                      block->colorIndex);

                    light_removal_node_queue_push(lightRemovalQueue,
                                                  &i3,
                                                  light,
                                                  15,
                                                  block->colorIndex);
                }
            }
        }
    }

    // run light removal
    _light_removal(s, &min, &max, lightRemovalQueue, lightQueue);

    light_removal_node_queue_free(lightRemovalQueue);

    // Then we run the regular light propagation algorithm
    _light_propagate(s, &min, &max, lightQueue, x, y, z);

    light_node_queue_free(lightQueue);
}

void shape_compute_baked_lighting_replaced_block(Shape *s,
                                                 SHAPE_COORDS_INT_T x,
                                                 SHAPE_COORDS_INT_T y,
                                                 SHAPE_COORDS_INT_T z,
                                                 SHAPE_COLOR_INDEX_INT_T blockID,
                                                 bool applyOffset) {
    if (s == NULL) {
        return;
    }

    if (applyOffset) {
        shape_block_lua_to_internal(s, &x, &y, &z);
    }

    if (_lighting_is_enabled(s) == false) {
#if SHAPE_LIGHTING_DEBUG
        cclog_debug("🔥 shape_computeLightForReplacedBlockCoords: baked lighting disabled");
#endif
        return;
    }

    if (s->lightingData == NULL) {
        cclog_error(
            "🔥 shape_compute_baked_lighting_replaced_block: shape doesn't have lighting data");
        return;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️☀️☀️ compute light for replaced block (%d, %d, %d)", x, y, z);
#endif

    // get existing and new light values
    VERTEX_LIGHT_STRUCT_T existingLight = shape_get_light_without_checking(s, x, y, z);
    VERTEX_LIGHT_STRUCT_T newLight = color_palette_get_emissive_color_as_light(s->palette, blockID);

    // early exit if emission values did not change
    if (existingLight.red == newLight.red && existingLight.green == newLight.green &&
        existingLight.blue == newLight.blue) {
        return;
    }

    int3 i3;
    LightNodeQueue *lightQueue = light_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    int3 min, max;
    min.x = max.x = x;
    min.y = max.y = y;
    min.z = max.z = z;

    i3.x = x;
    i3.y = y;
    i3.z = z;

    // if replaced light was emissive, start light removal
    if (existingLight.red > 0 || existingLight.green > 0 || existingLight.blue > 0) {
        LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

        light_removal_node_queue_push(lightRemovalQueue, &i3, existingLight, 15, blockID);

        // run light removal
        _light_removal(s, &min, &max, lightRemovalQueue, lightQueue);

        light_removal_node_queue_free(lightRemovalQueue);
    }

    // if new light is emissive, add it to the light propagation queue & store original emission of
    // the block note: we do this since palette may have been changed when running light removal at
    // a later point
    if (newLight.red > 0 || newLight.green > 0 || newLight.blue > 0) {
        light_node_queue_push(lightQueue, &i3);
        shape_set_light(s, x, y, z, newLight);
    } else {
        // self light values are now 0
        VERTEX_LIGHT_STRUCT_T zero;
        ZERO_LIGHT(zero)
        shape_set_light(s, x, y, z, zero);
    }

    // Then we run the regular light propagation algorithm
    _light_propagate(s, &min, &max, lightQueue, x, y, z);

    light_node_queue_free(lightQueue);
}

// MARK: -

bool shape_is_lua_mutable(Shape *s) {
    if (s == NULL) {
        return false;
    }
    return s->isMutable;
}

void shape_set_lua_mutable(Shape *s, const bool value) {
    if (s == NULL) {
        return;
    }
    s->isMutable = value;
}

// MARK: - History -

void shape_history_setEnabled(Shape *s, const bool enable) {
    if (s == NULL) {
        return;
    }
    if (enable == s->historyEnabled) {
        return;
    }

    if (enable == true) {
        // enable history
        if (s->history != NULL) {
            return;
        }
        s->history = history_new();
    } else {
        // disable history
        if (s->history == NULL) {
            return;
        }
        history_free(s->history);
        s->history = NULL;
    }
    s->historyEnabled = enable;
}

bool shape_history_getEnabled(Shape *s) {
    if (s == NULL) {
        return false;
    }
    return s->historyEnabled;
}

void shape_history_setKeepTransactionPending(Shape *s, const bool b) {
    if (s == NULL) {
        return;
    }
    s->historyKeepingTransactionPending = b;
}

bool shape_history_getKeepTransactionPending(Shape *s) {
    if (s == NULL) {
        return false;
    }
    return s->historyKeepingTransactionPending;
}

bool shape_history_canUndo(const Shape *const s) {
    if (s == NULL) {
        return false;
    }
    if (s->history == NULL) {
        return false;
    }
    return s->pendingTransaction != NULL || history_can_undo(s->history);
}

bool shape_history_canRedo(const Shape *const s) {
    if (s == NULL) {
        return false;
    }
    if (s->history == NULL) {
        return false;
    }
    return history_can_redo(s->history);
}

void shape_history_undo(Shape *const s) {
    if (s == NULL) {
        return;
    }
    if (s->history == NULL) {
        return;
    }
    if (s->pendingTransaction != NULL) {
        transaction_free(s->pendingTransaction);
        s->pendingTransaction = NULL;
    } else {
        Transaction *tr = history_getTransactionToUndo(s->history);
        if (tr != NULL) {
            transaction_resetIndex3DIterator(tr);
            _shape_undo_transaction(s, tr);
        }
    }
}

void shape_history_redo(Shape *const s) {
    if (s == NULL) {
        return;
    }
    if (s->history == NULL) {
        return;
    }
    Transaction *tr = history_getTransactionToRedo(s->history);
    if (tr != NULL) {
        transaction_resetIndex3DIterator(tr);
        _shape_apply_transaction(s, tr);
    }
}

//

void shape_enableAnimations(Shape *const s) {
    if (s == NULL) {
        return;
    }
    if (s->transform == NULL) {
        return;
    }
    transform_setAnimationsEnabled(s->transform, true);
}

void shape_disableAnimations(Shape *const s) {
    if (s == NULL) {
        return;
    }
    if (s->transform == NULL) {
        return;
    }
    transform_setAnimationsEnabled(s->transform, false);
}

bool shape_getIgnoreAnimations(Shape *const s) {
    if (s == NULL) {
        return false;
    }
    if (s->transform == NULL) {
        return false;
    }
    return transform_getAnimationsEnabled(s->transform) == false;
}

// --------------------------------------------------
//
// MARK: - static functions -
//
// --------------------------------------------------

///
static bool _shape_add_block(Shape *shape,
                             SHAPE_COORDS_INT_T x,
                             SHAPE_COORDS_INT_T y,
                             SHAPE_COORDS_INT_T z,
                             Block **added_or_existing_block) {

    if (added_or_existing_block != NULL) {
        *added_or_existing_block = NULL;
    }

    // make sure block is added within fixed boundaries
    if (_has_fixed_size(shape) && _is_out_of_fixed_size(shape, x, y, z)) {
        cclog_error("⚠️ trying to add block outside shape's fixed boundaries| %p %d %d %d",
                    shape,
                    x,
                    y,
                    z);
        cclog_error("shape fixed size: %d | %d %d %d",
                    _has_fixed_size(shape),
                    shape->maxWidth,
                    shape->maxHeight,
                    shape->maxDepth);
        return false;
    }

    // TODO: chunks should not be required when using an octree
    //    // If blocks are stored in an octree
    //    if (shape->octree != NULL) {
    //        // -------------------------
    //        // USING OCTREE
    //        // -------------------------
    //
    //        Block *block = (Block*)octree_get_element(shape->octree, x, y, z);
    //
    //        // there's already a block, we can't add one
    //        if (block != NULL) {
    //            if (added_or_existing_block != NULL) {
    //                *added_or_existing_block = block;
    //            }
    //            return false;
    //        }
    //
    //        block = block_new(); // NOTE: we could always use the same block to avoid allocations,
    //        or support NULL for octree_set_element shape->nbBlocks++;
    //        octree_set_element(shape->octree, (void*)block, x, y, z);
    //
    //        // octree_set_element makes a copy, it's ok to free this one now.
    //        block_free(block);
    //
    //        printf("shape_add_block not fully implemented for octrees");
    //        return false;
    //    }

    // -------------------------
    // USING CHUNKS
    // -------------------------

    // declaring variables here instead of using pool because
    // of multi thread access issues.
    int3 block_ldfPos;
    Chunk *chunk = NULL;
    bool chunkAdded = false;
    bool blockAdded = _add_block_in_chunks(shape->chunks,
                                           NULL,
                                           x,
                                           y,
                                           z,
                                           &block_ldfPos,
                                           &chunkAdded,
                                           &chunk,
                                           added_or_existing_block);

    if (chunkAdded) {
        shape->nbChunks++;
    }

    if (blockAdded) {
        shape->nbBlocks++;
        shape_chunk_needs_display(shape, chunk);
        shape_chunk_inform_neighbors_about_change(shape, chunk, &block_ldfPos);

        shape_expand_box(shape, x, y, z);
    }

    return blockAdded;
}

///
static ShapeId getValidShapeId() {
    ShapeId resultId = 0;
    if (availableShapeIds == NULL || filo_list_uint16_pop(availableShapeIds, &resultId) == false) {
        resultId = nextShapeId;
        nextShapeId += 1;
    }
    // printf("🌟🔴 getValidShapeId: %d\n", resultId);
    return resultId;
}

///
static void recycleShapeId(const ShapeId shapeId) {
    // if list is nil, then initialize it
    if (availableShapeIds == NULL) {
        availableShapeIds = filo_list_uint16_new();
    }
    filo_list_uint16_push(availableShapeIds, shapeId);
}

/// adds a shape to the shape index
static bool _storeShapeInIndex(Shape *s) {
    // cclog_trace(">>> store shape in index: %p", s);
    if (_shapesIndex == NULL) {
        // if index is nil, then initialize it and store the shape pointer in it
        _shapesIndexLength = 1;
        _shapesIndex = (Shape **)malloc(sizeof(Shape *) * _shapesIndexLength);
        _shapesIndex[0] = s;
        // cclog_trace(">>> length %d", _shapesIndexLength);
        return true;
    } else {
        // shape index already exists, we insert the shape if it is not a duplicate
        bool found = false;
        for (uint32_t i = 0; i < _shapesIndexLength; i++) {
            if (_shapesIndex[i] == s) {
                found = true;
            }
        }
        if (found == false) {
            Shape **newPtr = (Shape **)realloc(_shapesIndex,
                                               sizeof(Shape *) * (_shapesIndexLength + 1));
            if (newPtr == NULL) {
                // realloc failed, we simple don't add the shape in the index
                cclog_error(">>> realloc failed");
                return false;
            }
            _shapesIndex = newPtr;
            _shapesIndexLength += 1;
            _shapesIndex[_shapesIndexLength - 1] = s;
            // cclog_trace("%s %d", ">>> length", _shapesIndexLength);
            return true;
        }
    }
    return false;
}

/// removes a shape from the shape index and returns whether the operation succeeded
static bool _removeShapeFromIndex(const Shape *s) {
    // cclog_trace(">>> remove shape %p", s);
    for (uint32_t i = 0; i < _shapesIndexLength; i++) {
        if (_shapesIndex[i] == s) {
            _shapesIndex[i] = _shapesIndex[_shapesIndexLength - 1];
            _shapesIndex[_shapesIndexLength - 1] = NULL;
            _shapesIndexLength -= 1;
            if (_shapesIndexLength == 0) {
                free(_shapesIndex);
                _shapesIndex = NULL;
                // cclog_trace(">>> new size after remove %d", _shapesIndexLength);
                return true;
            }
            Shape **newPtr = (Shape **)realloc(_shapesIndex, sizeof(Shape *) * _shapesIndexLength);
            if (newPtr == NULL) {
                cclog_error("realloc failed");
                return false;
            }
            _shapesIndex = newPtr;
            // cclog_trace(">>> new size after remove: %d", _shapesIndexLength);
            return true;
        }
    }
    return false;
}

// MARK: - private functions -

bool _add_block_in_chunks(Index3D *chunks,
                          Block *newBlock,
                          const SHAPE_COORDS_INT_T x,
                          const SHAPE_COORDS_INT_T y,
                          const SHAPE_COORDS_INT_T z,
                          int3 *block_ldfPos_out,
                          bool *chunkAdded,
                          Chunk **added_or_existing_chunk,
                          Block **added_or_existing_block) {

    // declaring variables here instead of using pool because
    // of multi thread access issues.
    int3 chunk_ldfPos;
    // position within chunk
    int3 block_ldfPos;

    // see if there's a chunk ready for that block (ldf: left-down-front)
    int3_set(&chunk_ldfPos, x >> CHUNK_WIDTH_SQRT, y >> CHUNK_HEIGHT_SQRT, z >> CHUNK_DEPTH_SQRT);

    Chunk *chunk = (Chunk *)index3d_get(chunks, chunk_ldfPos.x, chunk_ldfPos.y, chunk_ldfPos.z);

    // insert new chunk if needed
    if (chunk == NULL) {
        // it's necessary to store chunk position, as a chunk should be able
        // to generate its face vertices without external context
        chunk = chunk_new(chunk_ldfPos.x * CHUNK_WIDTH,
                          chunk_ldfPos.y * CHUNK_HEIGHT,
                          chunk_ldfPos.z * CHUNK_DEPTH);
        index3d_insert(chunks, chunk, chunk_ldfPos.x, chunk_ldfPos.y, chunk_ldfPos.z, NULL);

        // printf("insert chunk at: %d, %d, %d\n", chunk_ldfPos->x, chunk_ldfPos->y,
        // chunk_ldfPos->z);

        // TODO: optimize index search:
        // - look for equal x positions once -> 9, 8, 9
        // - look for equal y positions within x nodes -> 3, 3, 3; 3, 2, 3; 3, 3, 3
        chunk_move_in_neighborhood(
            chunk,
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z + 1), // topLeftBack
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z + 1), // topBack
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z + 1), // topRightBack
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z), // topLeft
            (Chunk *)index3d_get(chunks, chunk_ldfPos.x, chunk_ldfPos.y + 1, chunk_ldfPos.z), // top
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z), // topRight
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z - 1), // topLeftFront
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z - 1), // topFront
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y + 1,
                                 chunk_ldfPos.z - 1), // topRightFront
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z + 1), // bottomLeftBack
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z + 1), // bottomBack
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z + 1), // bottomRightBack
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z), // bottomLeft
            (Chunk *)
                index3d_get(chunks, chunk_ldfPos.x, chunk_ldfPos.y - 1, chunk_ldfPos.z), // bottom
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z), // bottomRight
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z - 1), // bottomLeftFront
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z - 1), // bottomFront
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y - 1,
                                 chunk_ldfPos.z - 1), // bottomRightFront
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y,
                                 chunk_ldfPos.z + 1), // LeftBack
            (Chunk *)
                index3d_get(chunks, chunk_ldfPos.x, chunk_ldfPos.y, chunk_ldfPos.z + 1), // Back
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y,
                                 chunk_ldfPos.z + 1), // RightBack
            (Chunk *)
                index3d_get(chunks, chunk_ldfPos.x - 1, chunk_ldfPos.y, chunk_ldfPos.z), // Left
            (Chunk *)
                index3d_get(chunks, chunk_ldfPos.x + 1, chunk_ldfPos.y, chunk_ldfPos.z), // Right
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x - 1,
                                 chunk_ldfPos.y,
                                 chunk_ldfPos.z - 1), // LeftFront
            (Chunk *)
                index3d_get(chunks, chunk_ldfPos.x, chunk_ldfPos.y, chunk_ldfPos.z - 1), // Front
            (Chunk *)index3d_get(chunks,
                                 chunk_ldfPos.x + 1,
                                 chunk_ldfPos.y,
                                 chunk_ldfPos.z - 1) // RightFront
        );

        *chunkAdded = true;
    } else {
        *chunkAdded = false;
    }

    if (added_or_existing_chunk != NULL) {
        *added_or_existing_chunk = chunk;
    }

    int3_set(&block_ldfPos,
             x & CHUNK_WIDTH_MINUS_ONE,
             y & CHUNK_HEIGHT_MINUS_ONE,
             z & CHUNK_DEPTH_MINUS_ONE);

    if (block_ldfPos_out != NULL) {
        int3_set(block_ldfPos_out, block_ldfPos.x, block_ldfPos.y, block_ldfPos.z);
    }

    Block *block = chunk_get_block(chunk, block_ldfPos.x, block_ldfPos.y, block_ldfPos.z);

    // there's already a block, we can't add one
    if (block != NULL) {
        if (added_or_existing_block != NULL) {
            *added_or_existing_block = block;
        }
        return false;
    }

    block = newBlock != NULL ? newBlock : block_new();
    chunk_addBlock(chunk,
                   block,
                   block_ldfPos.x,
                   block_ldfPos.y,
                   block_ldfPos.z); // returns whether the operation succeeded

    if (added_or_existing_block != NULL) {
        *added_or_existing_block = block;
    }

    return true;
}

bool _has_fixed_size(const Shape *s) {
    return s->maxWidth > 0;
}

bool _is_out_of_fixed_size(const Shape *s,
                           const SHAPE_COORDS_INT_T x,
                           const SHAPE_COORDS_INT_T y,
                           const SHAPE_COORDS_INT_T z) {
    // note: with fixed size, origin is always 0,0,0
    return x < 0 || y < 0 || z < 0 || x >= s->maxWidth || y >= s->maxHeight || z >= s->maxDepth;
}

Octree *_new_octree(Shape *s,
                    const SHAPE_COORDS_INT_T w,
                    const SHAPE_COORDS_INT_T h,
                    const SHAPE_COORDS_INT_T d) {
    // enforcing power of 2 for the octree
    uint16_t size = maximum(maximum(w, h), d);
    unsigned long upPow2Size = upper_power_of_two(size);

    Block *air = block_new_air();

    // octree stores block color indices
    Octree *o = NULL;
    switch (upPow2Size) {
        case 1:
            o = octree_new_with_default_element(octree_1x1x1, air, sizeof(Block));
            break;
        case 2:
            o = octree_new_with_default_element(octree_2x2x2, air, sizeof(Block));
            break;
        case 4:
            o = octree_new_with_default_element(octree_4x4x4, air, sizeof(Block));
            break;
        case 8:
            o = octree_new_with_default_element(octree_8x8x8, air, sizeof(Block));
            break;
        case 16:
            o = octree_new_with_default_element(octree_16x16x16, air, sizeof(Block));
            break;
        case 32:
            o = octree_new_with_default_element(octree_32x32x32, air, sizeof(Block));
            break;
        case 64:
            o = octree_new_with_default_element(octree_64x64x64, air, sizeof(Block));
            break;
        case 128:
            o = octree_new_with_default_element(octree_128x128x128, air, sizeof(Block));
            break;
        case 256:
            o = octree_new_with_default_element(octree_256x256x256, air, sizeof(Block));
            break;
        case 512:
            o = octree_new_with_default_element(octree_512x512x512, air, sizeof(Block));
            break;
        case 1024:
            o = octree_new_with_default_element(octree_1024x1024x1024, air, sizeof(Block));
            break;
        default:
            cclog_error("🔥 shape is too big to use an octree.");
            break;
    }

    block_free((Block *)air);

    return o;
}

// flag used in shape_add_vertex_buffer
void _set_vb_allocation_flag_one_frame(Shape *s) {
    // shape VB chain was just initialized this frame, and will now be 1+ frame old
    // opaque VB chain
    if (s->vbAllocationFlag_opaque <= 1) {
        s->vbAllocationFlag_opaque = 2;
    }
    // transparent VB chain
    if (s->vbAllocationFlag_transparent <= 1) {
        s->vbAllocationFlag_transparent = 2;
    }
}

bool _lighting_is_enabled(Shape *s) {
    return s->usesLighting && _has_fixed_size(s);
}

void _lighting_set_dirty(Shape *s, int3 *bbMin, int3 *bbMax, int x, int y, int z) {
    if (vertex_buffer_get_lighting_enabled()) {
        int3_op_min(bbMin, x, y, z);
        int3_op_max(bbMax, x, y, z);
    }
}

void _lighting_postprocess_dirty(Shape *s, int3 *bbMin, int3 *bbMax) {
    if (vertex_buffer_get_lighting_enabled()) {
        int3 chunkMin = *bbMin, chunkMax = *bbMax;

        // account for vertex lighting smoothing, values need to be updated on adjacent vertices
        int3_op_substract_int(&chunkMin, 1);
        int3_op_add_int(&chunkMax, 1);

        // find corresponding chunks and set dirty
        int3_op_div_ints(&chunkMin, CHUNK_WIDTH, CHUNK_HEIGHT, CHUNK_DEPTH);
        int3_op_div_ints(&chunkMax, CHUNK_WIDTH, CHUNK_HEIGHT, CHUNK_DEPTH);

        Chunk *chunk;
        for (int x = chunkMin.x; x <= chunkMax.x; x++) {
            for (int y = chunkMin.y; y <= chunkMax.y; y++) {
                for (int z = chunkMin.z; z <= chunkMax.z; z++) {
                    chunk = (Chunk *)index3d_get(s->chunks, x, y, z);
                    if (chunk != NULL) {
                        shape_chunk_needs_display(s, chunk);
                    }
                }
            }
        }
    }
}

void _light_removal_processNeighbor(Shape *s,
                                    int3 *bbMin,
                                    int3 *bbMax,
                                    VERTEX_LIGHT_STRUCT_T light,
                                    uint8_t srgb,
                                    bool equals,
                                    int3 *neighborPos,
                                    Block *neighbor,
                                    LightNodeQueue *lightQueue,
                                    LightRemovalNodeQueue *lightRemovalQueue) {

    // air and transparent blocks can be reset & further light removal
    if (neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK ||
        color_palette_is_transparent(s->palette, neighbor->colorIndex)) {
        VERTEX_LIGHT_STRUCT_T neighborLight = shape_get_light_without_checking(s,
                                                                               neighborPos->x,
                                                                               neighborPos->y,
                                                                               neighborPos->z);

        // 1) any neighbor's individual light channel is selected for reset if:
        // - its value is non-zero and less than the current node
        // - its flag in srgb is set to 1, meaning removal for that channel is not complete
        // then:
        // - set its value to 0 and add the neighbor to the light removal queue
        // - pass srgb flag to 0 for any light channel that was not reset, in order to stop light
        // removal Notes: (1) RGB values (emission) removal is inclusive to work with homogeneous
        // self-lighting (2) only first degree neighbors need to include their own RGB values, to
        // avoid over-extension of light removal
        bool resetS = neighborLight.ambient > 0 && neighborLight.ambient < light.ambient &&
                      (srgb & (uint8_t)8);
        bool resetR = neighborLight.red > 0 && (srgb & (uint8_t)4);
        bool resetG = neighborLight.green > 0 && (srgb & (uint8_t)2);
        bool resetB = neighborLight.blue > 0 && (srgb & (uint8_t)1);

        if (equals) {
            resetR = resetR && neighborLight.red <= light.red;
            resetG = resetG && neighborLight.green <= light.green;
            resetB = resetB && neighborLight.blue <= light.blue;
        } else {
            resetR = resetR && neighborLight.red < light.red;
            resetG = resetG && neighborLight.green < light.green;
            resetB = resetB && neighborLight.blue < light.blue;
        }

        if (resetS || resetR || resetG || resetB) {
            VERTEX_LIGHT_STRUCT_T insertLight = neighborLight;
            uint8_t insertSRGB = 0;

            // individually reset light values
            if (resetS) {
                neighborLight.ambient = 0;
                insertSRGB |= (uint8_t)8;
            }
            if (resetR) {
                neighborLight.red = 0;
                insertSRGB |= (uint8_t)4;
            }
            if (resetG) {
                neighborLight.green = 0;
                insertSRGB |= (uint8_t)2;
            }
            if (resetB) {
                neighborLight.blue = 0;
                insertSRGB |= (uint8_t)1;
            }
            shape_set_light(s, neighborPos->x, neighborPos->y, neighborPos->z, neighborLight);
            _lighting_set_dirty(s, bbMin, bbMax, neighborPos->x, neighborPos->y, neighborPos->z);

            // enqueue neighbor for removal
            light_removal_node_queue_push(lightRemovalQueue,
                                          neighborPos,
                                          insertLight,
                                          insertSRGB,
                                          255);
        }
        // 2) concurrently, if any of the neighbor's light channel still being removed, is higher
        // (but non-zero) than current node, then add the neighbor in the light propagation queue
        // ie. this means we have removed obsolete light values in the vicinity and this neighbor
        // can be used as a source to complete light propagation along with any new light sources
        bool propagateS = neighborLight.ambient != 0 && neighborLight.ambient >= light.ambient &&
                          (srgb & (uint8_t)8);
        bool propagateR = neighborLight.red != 0 && (srgb & (uint8_t)4);
        bool propagateG = neighborLight.green != 0 && (srgb & (uint8_t)2);
        bool propagateB = neighborLight.blue != 0 && (srgb & (uint8_t)1);

        if (equals) {
            propagateR = propagateR && neighborLight.red > light.red;
            propagateG = propagateG && neighborLight.green > light.green;
            propagateB = propagateB && neighborLight.blue > light.blue;
        } else {
            propagateR = propagateR && neighborLight.red >= light.red;
            propagateG = propagateG && neighborLight.green >= light.green;
            propagateB = propagateB && neighborLight.blue >= light.blue;
        }

        if (propagateS || propagateR || propagateG || propagateB) {
            light_node_queue_push(lightQueue, neighborPos);
        }
    }
    // emissive blocks, if in the vicinity of light removal, may be re-enqueued as well
    else if (color_palette_is_emissive(s->palette, neighbor->colorIndex)) {
        light_node_queue_push(lightQueue, neighborPos);
    }
}

void _light_enqueue_source(int3 *pos,
                           Shape *shape,
                           VERTEX_LIGHT_STRUCT_T source,
                           LightNodeQueue *lightQueue) {
    VERTEX_LIGHT_STRUCT_T current = shape_get_light_or_default(shape,
                                                               pos->x,
                                                               pos->y,
                                                               pos->z,
                                                               false);
    const bool s = current.ambient < source.ambient;
    const bool r = current.red < source.red;
    const bool g = current.green < source.green;
    const bool b = current.blue < source.blue;
    if (s || r || g || b) {
        // individually update light and emission value
        if (s) {
            current.ambient = source.ambient;
        }
        if (r) {
            current.red = source.red;
        }
        if (g) {
            current.green = source.green;
        }
        if (b) {
            current.blue = source.blue;
        }
        shape_set_light(shape, pos->x, pos->y, pos->z, current);

        // enqueue as a new light source if any value was higher
        if (lightQueue != NULL) {
            light_node_queue_push(lightQueue, pos);
        }
    }
}

void _light_block_propagate(Shape *s,
                            int3 *bbMin,
                            int3 *bbMax,
                            VERTEX_LIGHT_STRUCT_T current,
                            int3 *neighborPos,
                            Block *neighbor,
                            bool air,
                            bool transparent,
                            LightNodeQueue *lightQueue,
                            uint8_t stepS,
                            uint8_t stepRGB) {

    // if neighbor non-opaque, propagate sunlight and emission values individually & enqueue if
    // needed
    if (air || transparent) {
        // if transparent, first reduce incoming light values
        if (transparent) {
            float a = (float)color_palette_get_color(s->palette, neighbor->colorIndex)->a / 255.0f;
#if TRANSPARENCY_ABSORPTION_FUNC == 1
            a = easings_quadratic_in(a);
#elif TRANSPARENCY_ABSORPTION_FUNC == 2
            a = easings_cubic_in(a);
#elif TRANSPARENCY_ABSORPTION_FUNC == 3
            a = easings_exponential_in(a);
#elif TRANSPARENCY_ABSORPTION_FUNC == 4
            a = easings_circular_in(a);
#endif

#if TRANSPARENCY_ABSORPTION_MAX_STEP
            float absorbRGB = 1.0f - fmaxf(a - (float)stepRGB / 15.0f, 0.0f);
            float absorbS = 1.0f - fmaxf(a - (float)stepS / 15.0f, 0.0f);
#else
            float absorbRGB = 1.0f - a;
            float absorbS = 1.0f - a;
#endif
            current.red = (uint8_t)((float)current.red * absorbRGB);
            current.green = (uint8_t)((float)current.green * absorbRGB);
            current.blue = (uint8_t)((float)current.blue * absorbRGB);
            current.ambient = (uint8_t)((float)current.ambient * absorbS);
        }

        VERTEX_LIGHT_STRUCT_T neighborLight = shape_get_light_or_default(s,
                                                                         neighborPos->x,
                                                                         neighborPos->y,
                                                                         neighborPos->z,
                                                                         false);
        const bool propagateS = neighborLight.ambient < current.ambient - stepS;
        const bool propagateR = neighborLight.red < current.red - stepRGB;
        const bool propagateG = neighborLight.green < current.green - stepRGB;
        const bool propagateB = neighborLight.blue < current.blue - stepRGB;
        if (propagateS || propagateR || propagateG || propagateB) {
            if (propagateS) {
                neighborLight.ambient = current.ambient - stepS;
            }
            if (propagateR) {
                neighborLight.red = current.red - stepRGB;
            }
            if (propagateG) {
                neighborLight.green = current.green - stepRGB;
            }
            if (propagateB) {
                neighborLight.blue = current.blue - stepRGB;
            }
            shape_set_light(s, neighborPos->x, neighborPos->y, neighborPos->z, neighborLight);

            light_node_queue_push(lightQueue, neighborPos);
            _lighting_set_dirty(s, bbMin, bbMax, neighborPos->x, neighborPos->y, neighborPos->z);
        }
    }
    // if neighbor emissive, enqueue & store original emission of the block (relevant if first
    // propagation)
    else if (color_palette_is_emissive(s->palette, neighbor->colorIndex)) {
        shape_set_light(
            s,
            neighborPos->x,
            neighborPos->y,
            neighborPos->z,
            color_palette_get_emissive_color_as_light(s->palette, neighbor->colorIndex));
        light_node_queue_push(lightQueue, neighborPos);
    }
}

void _light_propagate(Shape *s,
                      int3 *bbMin,
                      int3 *bbMax,
                      LightNodeQueue *lightQueue,
                      const int srcX,
                      const int srcY,
                      const int srcZ) {

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light propagation started...");
#endif

    // changed values bounding box initialized at source position or using given bounding box
    int3 *min = bbMin;
    int3 *max = bbMax;
    if (min == NULL) {
        min = int3_new(srcX, srcY, srcZ);
    }
    if (max == NULL) {
        max = int3_new(srcX, srcY, srcZ);
    }

    // set source block dirty
    _lighting_set_dirty(s, min, max, srcX, srcY, srcZ);

    int3 i3, insertPos;
    Block *current = NULL, *neighbor = NULL;
    VERTEX_LIGHT_STRUCT_T currentLight;
    bool isCurrentAir, isCurrentOpen, isCurrentTransparent, isNeighborAir, isNeighborTransparent;
    LightNode *n = light_node_queue_pop(lightQueue);
    uint32_t iCount = 0;
    while (n != NULL) {
        light_node_get_coords(n, &i3);

        // get current light
        if (_is_out_of_fixed_size(s, i3.x, i3.y, i3.z)) {
            DEFAULT_LIGHT(currentLight)
            isCurrentAir = true;
            isCurrentTransparent = false;
        } else {
            current = shape_get_block(s, i3.x, i3.y, i3.z, false);
            if (current == NULL) {
                cclog_error("🔥 no element found at index");
                light_node_queue_recycle(n);
                n = light_node_queue_pop(lightQueue);
                continue;
            }

            currentLight = shape_get_light_without_checking(s, i3.x, i3.y, i3.z);
            isCurrentAir = current->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isCurrentTransparent = color_palette_is_transparent(s->palette, current->colorIndex);
        }
        isCurrentOpen = false; // is current node open ie. at least one neighbor is non-opaque

        // propagate sunlight top-down from above the map and on the sides
        // note: test this first and individually, because the octree has a POT size ie. most likely
        // higher than fixed width & depth and will return an air block by default to stop
        // propagation
        if (i3.y > 0 && i3.y <= s->maxHeight &&
            (i3.x == -1 || i3.z == -1 || i3.x == s->maxWidth || i3.z == s->maxDepth)) {
            insertPos.x = i3.x;
            insertPos.y = i3.y - 1;
            insertPos.z = i3.z;
            light_node_queue_push(lightQueue, &insertPos);
        }

        // for each non-opaque neighbor: flag current node as open & propagate light if current
        // non-opaque for each emissive neighbor: add to light queue if current non-opaque y - 1
        neighbor = shape_get_block(s, i3.x, i3.y - 1, i3.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = i3.x;
                insertPos.y = i3.y - 1;
                insertPos.z = i3.z;

                // sunlight propagates infinitely vertically (step = 0)
                _light_block_propagate(s,
                                       min,
                                       max,
                                       currentLight,
                                       &insertPos,
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       0,
                                       EMISSION_PROPAGATION_STEP);
            }
        }

        // y + 1
        neighbor = shape_get_block(s, i3.x, i3.y + 1, i3.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = i3.x;
                insertPos.y = i3.y + 1;
                insertPos.z = i3.z;

                _light_block_propagate(s,
                                       min,
                                       max,
                                       currentLight,
                                       &insertPos,
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP);
            }
        }

        // x + 1
        neighbor = shape_get_block(s, i3.x + 1, i3.y, i3.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = i3.x + 1;
                insertPos.y = i3.y;
                insertPos.z = i3.z;

                _light_block_propagate(s,
                                       min,
                                       max,
                                       currentLight,
                                       &insertPos,
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP);
            }
        }

        // x - 1
        neighbor = shape_get_block(s, i3.x - 1, i3.y, i3.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = i3.x - 1;
                insertPos.y = i3.y;
                insertPos.z = i3.z;

                _light_block_propagate(s,
                                       min,
                                       max,
                                       currentLight,
                                       &insertPos,
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP);
            }
        }

        // z + 1
        neighbor = shape_get_block(s, i3.x, i3.y, i3.z + 1, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = i3.x;
                insertPos.y = i3.y;
                insertPos.z = i3.z + 1;

                _light_block_propagate(s,
                                       min,
                                       max,
                                       currentLight,
                                       &insertPos,
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP);
            }
        }

        // z - 1
        neighbor = shape_get_block(s, i3.x, i3.y, i3.z - 1, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = i3.x;
                insertPos.y = i3.y;
                insertPos.z = i3.z - 1;

                _light_block_propagate(s,
                                       min,
                                       max,
                                       currentLight,
                                       &insertPos,
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP);
            }
        }

        // current node is a solid block with at least one face open
        if (isCurrentAir == false && isCurrentOpen) {
            currentLight = color_palette_get_emissive_color_as_light(s->palette,
                                                                     current->colorIndex);

            if (currentLight.red == 0 && currentLight.green == 0 && currentLight.blue == 0) {
                light_node_queue_recycle(n);
                n = light_node_queue_pop(lightQueue);
                continue;
            }
            // here: emissive block in need of (re)propagation

            /// Homogeneous self-lighting
            // emissive cubes assign their initial RGB values to all surrounding air blocks (up to
            // 3x3x3-1=26) instead of the 6 that would occur on first propagation iteration, for
            // homogeneous self-lighting this is equivalent to simulating the first iteration
            // manually, to alter the way it initially spreads
            for (int xo = -1; xo <= 1; xo++) {
                for (int yo = -1; yo <= 1; yo++) {
                    for (int zo = -1; zo <= 1; zo++) {
                        insertPos.x = i3.x + xo;
                        insertPos.y = i3.y + yo;
                        insertPos.z = i3.z + zo;

                        if (shape_is_within_fixed_bounds(s,
                                                         insertPos.x,
                                                         insertPos.y,
                                                         insertPos.z)) {
                            neighbor = shape_get_block(s,
                                                       insertPos.x,
                                                       insertPos.y,
                                                       insertPos.z,
                                                       false);
                            if (block_is_opaque(neighbor, s->palette) == false) {
                                _light_enqueue_source(&insertPos, s, currentLight, lightQueue);
                            }
                        }
                    }
                }
            }
        }

        light_node_queue_recycle(n);
        n = light_node_queue_pop(lightQueue);
        iCount++;
    }

    _lighting_postprocess_dirty(s, min, max);

    if (bbMin == NULL) {
        int3_free(min);
    }
    if (bbMax == NULL) {
        int3_free(max);
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light propagation done with %d iterations", iCount);
#endif
}

void _light_removal(Shape *s,
                    int3 *bbMin,
                    int3 *bbMax,
                    LightRemovalNodeQueue *lightRemovalQueue,
                    LightNodeQueue *lightQueue) {

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light removal started...");
#endif

    VERTEX_LIGHT_STRUCT_T light;
    uint8_t srgb;
    SHAPE_COLOR_INDEX_INT_T blockID;
    Block *neighbor = NULL;

    int3 i3, insertPos;
    LightRemovalNode *rn = light_removal_node_queue_pop(lightRemovalQueue);
    uint32_t iCount = 0;
    while (rn != NULL) {
        // get coords and light value of the light removal node (rn)
        light_removal_node_get_coords(rn, &i3);
        light_removal_node_get_light(rn, &light);
        srgb = light_removal_node_get_srgb(rn);
        blockID = light_removal_node_get_block_id(rn);

        // check that the current block is inside the shape bounds
        if (shape_is_within_fixed_bounds(s, i3.x, i3.y, i3.z)) {

            // if air or transparent block, proceed with light removal
            if (blockID == SHAPE_COLOR_INDEX_AIR_BLOCK ||
                color_palette_is_transparent(s->palette, blockID)) {
                // x + 1
                neighbor = shape_get_block(s, i3.x + 1, i3.y, i3.z, false);
                if (neighbor != NULL) {
                    insertPos.x = i3.x + 1;
                    insertPos.y = i3.y;
                    insertPos.z = i3.z;

                    _light_removal_processNeighbor(s,
                                                   bbMin,
                                                   bbMax,
                                                   light,
                                                   srgb,
                                                   false,
                                                   &insertPos,
                                                   neighbor,
                                                   lightQueue,
                                                   lightRemovalQueue);
                }
                // x - 1
                neighbor = shape_get_block(s, i3.x - 1, i3.y, i3.z, false);
                if (neighbor != NULL) {
                    insertPos.x = i3.x - 1;
                    insertPos.y = i3.y;
                    insertPos.z = i3.z;

                    _light_removal_processNeighbor(s,
                                                   bbMin,
                                                   bbMax,
                                                   light,
                                                   srgb,
                                                   false,
                                                   &insertPos,
                                                   neighbor,
                                                   lightQueue,
                                                   lightRemovalQueue);
                }
                // y + 1
                neighbor = shape_get_block(s, i3.x, i3.y + 1, i3.z, false);
                if (neighbor != NULL) {
                    insertPos.x = i3.x;
                    insertPos.y = i3.y + 1;
                    insertPos.z = i3.z;

                    _light_removal_processNeighbor(s,
                                                   bbMin,
                                                   bbMax,
                                                   light,
                                                   srgb,
                                                   false,
                                                   &insertPos,
                                                   neighbor,
                                                   lightQueue,
                                                   lightRemovalQueue);
                }
                // y - 1
                neighbor = shape_get_block(s, i3.x, i3.y - 1, i3.z, false);
                if (neighbor != NULL) {
                    insertPos.x = i3.x;
                    insertPos.y = i3.y - 1;
                    insertPos.z = i3.z;

                    _light_removal_processNeighbor(s,
                                                   bbMin,
                                                   bbMax,
                                                   light,
                                                   srgb,
                                                   false,
                                                   &insertPos,
                                                   neighbor,
                                                   lightQueue,
                                                   lightRemovalQueue);
                }
                // z + 1
                neighbor = shape_get_block(s, i3.x, i3.y, i3.z + 1, false);
                if (neighbor != NULL) {
                    insertPos.x = i3.x;
                    insertPos.y = i3.y;
                    insertPos.z = i3.z + 1;

                    _light_removal_processNeighbor(s,
                                                   bbMin,
                                                   bbMax,
                                                   light,
                                                   srgb,
                                                   false,
                                                   &insertPos,
                                                   neighbor,
                                                   lightQueue,
                                                   lightRemovalQueue);
                }
                // z - 1
                neighbor = shape_get_block(s, i3.x, i3.y, i3.z - 1, false);
                if (neighbor != NULL) {
                    insertPos.x = i3.x;
                    insertPos.y = i3.y;
                    insertPos.z = i3.z - 1;

                    _light_removal_processNeighbor(s,
                                                   bbMin,
                                                   bbMax,
                                                   light,
                                                   srgb,
                                                   false,
                                                   &insertPos,
                                                   neighbor,
                                                   lightQueue,
                                                   lightRemovalQueue);
                }
            }
            // if emissive block
            // to account for homogeneous self-lighting as well during emissive block removal,
            // process all surrounding emissive block's neighbors instead of the regular 6
            else if (color_palette_is_emissive(s->palette, blockID)) {
                for (int xo = -1; xo <= 1; xo++) {
                    for (int yo = -1; yo <= 1; yo++) {
                        for (int zo = -1; zo <= 1; zo++) {
                            if (xo == 0 && yo == 0 && zo == 0) {
                                continue;
                            }

                            insertPos.x = i3.x + xo;
                            insertPos.y = i3.y + yo;
                            insertPos.z = i3.z + zo;

                            neighbor = shape_get_block(s,
                                                       insertPos.x,
                                                       insertPos.y,
                                                       insertPos.z,
                                                       false);
                            if (neighbor != NULL) {
                                // only first-degree neighbors remove the emissive block's own RGB
                                // values (passing equals=true)
                                _light_removal_processNeighbor(s,
                                                               bbMin,
                                                               bbMax,
                                                               light,
                                                               15,
                                                               true,
                                                               &insertPos,
                                                               neighbor,
                                                               lightQueue,
                                                               lightRemovalQueue);
                            }
                        }
                    }
                }
            }
        }

        light_removal_node_queue_recycle(rn);
        rn = light_removal_node_queue_pop(lightRemovalQueue);
        iCount++;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light removal done with %d iterations", iCount);
#endif
}

void _light_realloc(Shape *s,
                    const SHAPE_SIZE_INT_T dx,
                    const SHAPE_SIZE_INT_T dy,
                    const SHAPE_SIZE_INT_T dz,
                    const SHAPE_SIZE_INT_T offsetX,
                    const SHAPE_SIZE_INT_T offsetY,
                    const SHAPE_SIZE_INT_T offsetZ) {

    // skip if this shape doesn't use light, or if it is not computed yet
    if (shape_uses_baked_lighting(s) == false || s->lightingData == NULL)
        return;

    // - keep existing data and apply offset,
    // - set reminder lighting data to 0, the newly added block should trigger a light propagation
    // in that new space
    // TODO: only if it's a light block ; need to manually start light propagation otherwise

    const size_t lightingSize = s->maxWidth * s->maxHeight * s->maxDepth *
                                sizeof(VERTEX_LIGHT_STRUCT_T);
    VERTEX_LIGHT_STRUCT_T *lightingData = (VERTEX_LIGHT_STRUCT_T *)malloc(lightingSize);
    const SHAPE_SIZE_INT_T srcWidth = s->maxWidth - dx;
    const SHAPE_SIZE_INT_T srcHeight = s->maxHeight - dy;
    const SHAPE_SIZE_INT_T srcDepth = s->maxDepth - dz;
    const SHAPE_SIZE_INT_T srcSlicePitch = srcHeight * srcDepth;
    const SHAPE_SIZE_INT_T dstSlicePitch = s->maxHeight * s->maxDepth;

    SHAPE_SIZE_INT_T ox, oy;
    for (SHAPE_SIZE_INT_T xx = 0; xx < s->maxWidth; ++xx) {
        for (SHAPE_SIZE_INT_T yy = 0; yy < s->maxHeight; ++yy) {
            ox = xx + offsetX;
            oy = yy + offsetY;

            if (xx < srcWidth && yy < srcHeight) {
                // set offseted data to 0
                if (offsetZ > 0) {
                    memset(lightingData + ox * dstSlicePitch + oy * s->maxDepth, 0, offsetZ);
                }

                // copy existing row data
                memcpy(lightingData + ox * dstSlicePitch + oy * s->maxDepth + offsetZ,
                       s->lightingData + xx * srcSlicePitch + yy * srcDepth,
                       srcDepth);

                // set reminder to 0
                if (dz > offsetZ) {
                    memset(lightingData + ox * dstSlicePitch + oy * s->maxDepth + offsetZ +
                               srcDepth,
                           0,
                           dz - offsetZ);
                }
            } else {
                // set new row to 0
                memset(lightingData + xx * dstSlicePitch + yy * s->maxDepth, 0, s->maxDepth);
            }
        }
    }

    free(s->lightingData);
    s->lightingData = lightingData;

#if SHAPE_LIGHTING_DEBUG
    cclog_debug(
        "☀️☀️☀️lighting data reallocated w/ delta (%d, %d, %d) offset (%d, %d, %d)",
        dx,
        dy,
        dz,
        offsetX,
        offsetY,
        offsetZ);
#endif
}

void _shape_check_all_vb_fragmented(Shape *s, VertexBuffer *first) {
    VertexBuffer *vb = first;
    while (vb != NULL) {
        if (vertex_buffer_is_fragmented(vb) && !vertex_buffer_is_enlisted(vb)) {
            doubly_linked_list_push_first(s->fragmentedVBs, vb);
            vertex_buffer_set_enlisted(vb, true);
        }
        vb = vertex_buffer_get_next(vb);
    }
}

void _shape_fill_draw_slices(VertexBuffer *vb) {
    while (vb != NULL) {
        vertex_buffer_fill_draw_slices(vb);
        // vertex_buffer_log_draw_slices(vb);
        vb = vertex_buffer_get_next(vb);
    }
}

bool _shape_apply_transaction(Shape *const sh, Transaction *tr) {
    vx_assert(sh != NULL);
    vx_assert(tr != NULL);
    if (sh == NULL) {
        return false;
    }
    if (tr == NULL) {
        return false;
    }

    // resize shape before applying transaction changes
    if (transaction_getMustConsiderNewBounds(tr)) {
        SHAPE_COORDS_INT_T minX, minY, minZ, maxX, maxY, maxZ;
        transaction_getNewBounds(tr, &minX, &minY, &minZ, &maxX, &maxY, &maxZ);
        shape_make_space(sh, minX, minY, minZ, maxX, maxY, maxZ, true /*apply offset*/);
    }

    // Returned iterator remains under transaction responsability
    // Do not free it!
    Index3DIterator *it = transaction_getIndex3DIterator(tr);
    if (it == NULL) {
        return false;
    }

    // loop on all the BlockChanges
    SHAPE_COLOR_INDEX_INT_T before, after;
    SHAPE_COORDS_INT_T x, y, z;
    bool shapeShrinkNeeded = false;

    while (index3d_iterator_pointer(it) != NULL) {
        BlockChange *bc = (BlockChange *)index3d_iterator_pointer(it);

        blockChange_getXYZ(bc, &x, &y, &z);

        // /!\ important note: transactions use an index3d therefore when several transactions
        // happen on the same block, they are amended into 1 unique transaction. This can be
        // an issue since transactions can be applied from a line-by-line refresh in Lua
        // (eg. shape.Width), meaning part of an amended transaction could've been applied
        // already. As a result, we'll always use the CURRENT block
        const Block *b = shape_get_block_immediate(sh, x, y, z, true);
        before = b != NULL ? b->colorIndex : SHAPE_COLOR_INDEX_AIR_BLOCK;
        blockChange_set_previous_color(bc, before);

        after = blockChange_getBlock(bc)->colorIndex;

        // [air>block] = add block
        if (before == SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_add_block_with_color(sh, after, x, y, z, false, true, true, false);
        }
        // [block>air] = remove block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after == SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_remove_block(sh, x, y, z, NULL, true, true, false);
            shapeShrinkNeeded = true;
        }
        // [block>block] = paint block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK &&
                 before != after) {
            shape_paint_block(sh, after, x, y, z, NULL, NULL, true, true);
        }

        index3d_iterator_next(it);
    }

    if (shapeShrinkNeeded == true) {
        shape_shrink_box(sh);
    }

    return true;
}

bool _shape_undo_transaction(Shape *const sh, Transaction *tr) {
    vx_assert(sh != NULL);
    vx_assert(tr != NULL);
    if (sh == NULL) {
        return false;
    }
    if (tr == NULL) {
        return false;
    }

    // No need to resize the shape down

    // Returned iterator remains under transaction responsability
    // Do not free it!
    Index3DIterator *it = transaction_getIndex3DIterator(tr);
    if (it == NULL) {
        return false;
    }

    SHAPE_COLOR_INDEX_INT_T before, after;
    SHAPE_COORDS_INT_T x, y, z;
    bool shapeShrinkNeeded = false;

    // loop on all the BlockChanges and revert them
    while (index3d_iterator_pointer(it) != NULL) {
        BlockChange *bc = (BlockChange *)index3d_iterator_pointer(it);

        blockChange_getXYZ(bc, &x, &y, &z);

        const Block *b = shape_get_block_immediate(sh, x, y, z, true);
        before = b != NULL ? b->colorIndex : SHAPE_COLOR_INDEX_AIR_BLOCK;

        after = blockChange_get_previous_color(bc);

        // [air>block] = add block
        if (before == SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_add_block_with_color(sh, after, x, y, z, false, true, true, false);
        }
        // [block>air] = remove block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after == SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_remove_block(sh, x, y, z, NULL, true, true, false);
            shapeShrinkNeeded = true;
        }
        // [block>block] = paint block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_paint_block(sh, after, x, y, z, NULL, NULL, true, true);
        }

        index3d_iterator_next(it);
    }

    if (shapeShrinkNeeded == true) {
        shape_shrink_box(sh);
    }

    return true;
}

void _shape_clear_cached_world_aabb(Shape *s) {
    if (s->worldAABB != NULL) {
        box_free(s->worldAABB);
        s->worldAABB = NULL;
    }
}
