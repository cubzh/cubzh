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
#include "config.h"
#include "easings.h"
#include "history.h"
#include "rigidBody.h"
#include "scene.h"
#include "transaction.h"
#include "utils.h"

#ifdef DEBUG
#define SHAPE_LIGHTING_DEBUG false
#define SHAPE_REFRESH_ALL_BUFFERS_FREE false
#else
#define SHAPE_LIGHTING_DEBUG false
#define SHAPE_REFRESH_ALL_BUFFERS_FREE false
#endif

// takes the 4 low bits of a and casts into uint8_t
#define TO_UINT4(a) (uint8_t)((a) & 0x0F)

#define SHAPE_RENDERING_FLAG_NONE 0
// whether or not to draw transparent inner faces between 2 blocks of a different color
#define SHAPE_RENDERING_FLAG_INNER_TRANSPARENT_FACES 1
#define SHAPE_RENDERING_FLAG_SHADOW 2
#define SHAPE_RENDERING_FLAG_UNLIT 4
// whether or not this shape uses baked vertex lighting
#define SHAPE_RENDERING_FLAG_BAKED_LIGHTING 8
// no automatic refresh, no model changes until unlocked
#define SHAPE_RENDERING_FLAG_BAKE_LOCKED 16

#define SHAPE_LUA_FLAG_NONE 0
#define SHAPE_LUA_FLAG_MUTABLE 1
#define SHAPE_LUA_FLAG_HISTORY 2
#define SHAPE_LUA_FLAG_HISTORY_KEEP_PENDING 4

struct _Shape {
    Weakptr *wptr;

    // list of colors used by the shape model, mapped onto color atlas indices
    ColorPalette *palette;

    // points of interest
    MapStringFloat3 *POIs;          // 8 bytes
    MapStringFloat3 *pois_rotation; // 8 bytes

    Transform *transform;
    Transform *pivot;

    // cached world axis-aligned bounding box, may be NULL if no cache
    Box *worldAABB;

    // buffers storing vertex data used for rendering, latest buffer is inserted after first
    VertexBuffer *firstVB_opaque, *firstVB_transparent, *firstIB_opaque, *firstIB_transparent;

    // Chunks are indexed by coordinates, and partitioned in a r-tree for physics queries
    Index3D *chunks;
    FifoList *dirtyChunks;
    Rtree *rtree;

    DoublyLinkedList *fragmentedBuffers;

    // block adds/removes/paints history
    History *history;

    // Current shape transaction, to be applied at end of frame (lua coords)
    Transaction *pendingTransaction;

    // name of the original item <username>.<itemname>, used for baked files
    char *fullname;

    size_t nbChunks;
    size_t nbBlocks;

    // model axis-aligned bounding box (bbMax - 1 is the max block)
    SHAPE_COORDS_INT3_T bbMin, bbMax; /* 6 x 2 bytes */

    uint16_t layers; // 2 bytes

    // internal flag used for variable-size VB allocation, see shape_add_buffer
    uint8_t vbAllocationFlag_opaque;      // 1 byte
    uint8_t vbAllocationFlag_transparent; // 1 byte

    ShapeDrawMode drawMode; // 1 byte

    uint8_t renderingFlags; // 1 byte
    uint8_t luaFlags;       // 1 byte

    char pad[1];
};

// MARK: - private functions prototypes -

static void _shape_toggle_rendering_flag(Shape *s, const uint8_t flag, const bool toggle);
static bool _shape_get_rendering_flag(const Shape *s, const uint8_t flag);
static void _shape_toggle_lua_flag(Shape *s, const uint8_t flag, const bool toggle);
static bool _shape_get_lua_flag(const Shape *s, const uint8_t flag);

void _shape_chunk_enqueue_refresh(Shape *shape, Chunk *c);
void _shape_chunk_check_neighbors_dirty(Shape *shape,
                                        const Chunk *chunk,
                                        CHUNK_COORDS_INT3_T block_pos);
static bool _shape_add_block_in_chunks(Shape *shape,
                                       const Block block,
                                       const SHAPE_COORDS_INT_T x,
                                       const SHAPE_COORDS_INT_T y,
                                       const SHAPE_COORDS_INT_T z,
                                       CHUNK_COORDS_INT3_T *block_coords,
                                       bool *chunkAdded,
                                       Chunk **added_or_existing_chunk,
                                       Block **added_or_existing_block);

void _set_vb_allocation_flag_one_frame(Shape *s);

/// internal functions used to flag the relevant data when lighting has changed
void _lighting_set_dirty(SHAPE_COORDS_INT3_T *bbMin,
                         SHAPE_COORDS_INT3_T *bbMax,
                         SHAPE_COORDS_INT3_T coords);
void _lighting_postprocess_dirty(Shape *s, SHAPE_COORDS_INT3_T *bbMin, SHAPE_COORDS_INT3_T *bbMax);

//// internal functions used to compute and update light propagation (sun & emission)
/// check a neighbor air block for light removal upon adding a block
void _light_removal_process_neighbor(Shape *s,
                                     Chunk *c,
                                     SHAPE_COORDS_INT3_T *bbMin,
                                     SHAPE_COORDS_INT3_T *bbMax,
                                     VERTEX_LIGHT_STRUCT_T light,
                                     uint8_t srgb,
                                     bool equals,
                                     CHUNK_COORDS_INT3_T coords_in_chunk,
                                     SHAPE_COORDS_INT3_T coords_in_shape,
                                     const Block *neighbor,
                                     LightNodeQueue *lightQueue,
                                     LightRemovalNodeQueue *lightRemovalQueue);
/// insert light values and if necessary (lightQueue != NULL) add it to the light propagation queue
void _light_set_and_enqueue_source(Shape *shape,
                                   Chunk *c,
                                   CHUNK_COORDS_INT3_T coords_in_chunk,
                                   SHAPE_COORDS_INT3_T coords_in_shape,
                                   VERTEX_LIGHT_STRUCT_T source,
                                   LightNodeQueue *lightQueue,
                                   bool initEmpty);
void _light_enqueue_ambient_and_block_sources(Shape *s,
                                              LightNodeQueue *q,
                                              SHAPE_COORDS_INT3_T min,
                                              SHAPE_COORDS_INT3_T max,
                                              bool enqueueAir);
/// propagate light values at a given block
void _light_block_propagate(Shape *s,
                            Chunk *c,
                            SHAPE_COORDS_INT3_T *bbMin,
                            SHAPE_COORDS_INT3_T *bbMax,
                            VERTEX_LIGHT_STRUCT_T current,
                            CHUNK_COORDS_INT3_T coords_in_chunk,
                            SHAPE_COORDS_INT3_T coords_in_shape,
                            const Block *neighbor,
                            bool air,
                            bool transparent,
                            LightNodeQueue *lightQueue,
                            uint8_t stepS,
                            uint8_t stepRGB,
                            bool initEmpty);
/// light propagation algorithm
void _light_propagate(Shape *s,
                      SHAPE_COORDS_INT3_T *bbMin,
                      SHAPE_COORDS_INT3_T *bbMax,
                      LightNodeQueue *lightQueue,
                      SHAPE_COORDS_INT_T srcX,
                      SHAPE_COORDS_INT_T srcY,
                      SHAPE_COORDS_INT_T srcZ,
                      bool initWithEmptyLight);
/// light removal also enqueues back any light source that needs recomputing
void _light_removal(Shape *s,
                    SHAPE_COORDS_INT3_T *bbMin,
                    SHAPE_COORDS_INT3_T *bbMax,
                    LightRemovalNodeQueue *lightRemovalQueue,
                    LightNodeQueue *lightQueue);
void _light_removal_all(Shape *s, SHAPE_COORDS_INT3_T *min, SHAPE_COORDS_INT3_T *max);
void _shape_check_all_vb_fragmented(Shape *s, VertexBuffer *first);
void _shape_flush_all_vb(Shape *s);
void _shape_fill_draw_slices(VertexBuffer *vb);
VertexBuffer *_shape_get_latest_buffer(const Shape *s,
                                       const bool transparent,
                                       const bool isVertexAttributes);

bool _shape_apply_transaction(Shape *const sh, Transaction *tr);
bool _shape_undo_transaction(Shape *const sh, Transaction *tr);

void _shape_clear_cached_world_aabb(Shape *s);

bool _shape_compute_size_and_origin(const Shape *shape,
                                    SHAPE_SIZE_INT_T *size_x,
                                    SHAPE_SIZE_INT_T *size_y,
                                    SHAPE_SIZE_INT_T *size_z,
                                    SHAPE_COORDS_INT_T *origin_x,
                                    SHAPE_COORDS_INT_T *origin_y,
                                    SHAPE_COORDS_INT_T *origin_z);

bool _shape_is_bounding_box_empty(const Shape *shape);

// --------------------------------------------------
//
// MARK: - public functions -
//
// --------------------------------------------------
//

void _shape_void_free(void *s) {
    shape_free((Shape *)s);
}

Shape *shape_make(void) {
    Shape *s = (Shape *)malloc(sizeof(Shape));

    s->wptr = NULL;
    s->palette = NULL;

    s->POIs = map_string_float3_new();
    s->pois_rotation = map_string_float3_new();

    s->worldAABB = NULL;

    s->transform = transform_make_with_ptr(ShapeTransform, s, _shape_void_free);
    s->pivot = NULL;

    s->chunks = index3d_new();
    s->dirtyChunks = NULL;
    s->rtree = rtree_new(RTREE_NODE_MIN_CAPACITY, RTREE_NODE_MAX_CAPACITY);

    // vertex/index buffers will be created on demand during refresh
    s->firstVB_opaque = NULL;
    s->firstIB_opaque = NULL;
    s->firstVB_transparent = NULL;
    s->firstIB_transparent = NULL;
    s->vbAllocationFlag_opaque = 0;
    s->vbAllocationFlag_transparent = 0;

    s->history = NULL;
    s->fullname = NULL;
    s->pendingTransaction = NULL;
    s->nbChunks = 0;
    s->nbBlocks = 0;
    s->bbMin = coords3_zero;
    s->bbMax = coords3_zero;
    s->fragmentedBuffers = doubly_linked_list_new();

    s->drawMode = SHAPE_DRAWMODE_DEFAULT;
    s->renderingFlags = SHAPE_RENDERING_FLAG_INNER_TRANSPARENT_FACES;
    s->layers = 1; // CAMERA_LAYERS_DEFAULT

    s->luaFlags = SHAPE_LUA_FLAG_NONE;

    return s;
}

Shape *shape_make_2(const bool isMutable) {
    Shape *s = shape_make();
    _shape_toggle_lua_flag(s, SHAPE_LUA_FLAG_MUTABLE, isMutable);
    return s;
}

Shape *shape_make_copy(Shape *const origin) {
    // apply transactions of the origin if needed
    shape_apply_current_transaction(origin, true);

    Shape *const s = shape_make();
    s->palette = color_palette_new_copy(origin->palette);

    // copy each point of interest
    MapStringFloat3Iterator *it = NULL;
    float3 *f3 = NULL;
    const char *key = NULL;

    it = map_string_float3_iterator_new(origin->POIs);
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
    it = NULL;

    s->bbMin = origin->bbMin;
    s->bbMax = origin->bbMax;

    s->drawMode = origin->drawMode;
    s->renderingFlags = origin->renderingFlags;
    s->layers = origin->layers;

    s->luaFlags = origin->luaFlags;

    // copy chunks data
    Index3DIterator *chunks_it = index3d_iterator_new(origin->chunks);
    Chunk *chunk, *chunkCopy;
    while (index3d_iterator_pointer(chunks_it) != NULL) {
        chunk = index3d_iterator_pointer(chunks_it);
        chunkCopy = chunk_new_copy(chunk);

        const SHAPE_COORDS_INT3_T chunkOrigin = chunk_get_origin(chunk);
        const SHAPE_COORDS_INT3_T chunkCoords = chunk_utils_get_coords(chunkOrigin);

        // index new chunk & link w/ chunks neighbors
        index3d_insert(s->chunks, chunkCopy, chunkCoords.x, chunkCoords.y, chunkCoords.z, NULL);
        chunk_move_in_neighborhood(s->chunks, chunkCopy, chunkCoords);

        // partition new chunk in shape space
        Box chunkBox = {{(float)chunkOrigin.x, (float)chunkOrigin.y, (float)chunkOrigin.z},
                        {(float)(chunkOrigin.x + CHUNK_SIZE),
                         (float)(chunkOrigin.y + CHUNK_SIZE),
                         (float)(chunkOrigin.z + CHUNK_SIZE)}};
        chunk_set_rtree_leaf(chunkCopy,
                             rtree_create_and_insert(s->rtree, &chunkBox, 1, 1, chunkCopy));

        // enqueue new shape buffers
        _shape_chunk_enqueue_refresh(s, chunkCopy);

        index3d_iterator_next(chunks_it);
    }
    index3d_iterator_free(chunks_it);

    if (origin->fullname != NULL) {
        s->fullname = string_new_copy(origin->fullname);
    }

    if (origin->pivot != NULL) {
        const float3 pivot = shape_get_pivot(origin);
        shape_set_pivot(s, pivot.x, pivot.y, pivot.z);
    }

    // copy transform parameters
    Transform *const originTr = shape_get_root_transform(origin);
    Transform *const t = shape_get_root_transform(s);
    {
        const char *name = transform_get_name(originTr);
        if (name != NULL) {
            transform_set_name(t, name);
        }

        transform_ensure_rigidbody_copy(t, originTr);

        transform_set_hidden_branch(t, transform_is_hidden_branch(originTr));
        transform_set_hidden_self(t, transform_is_hidden_self(originTr));

        transform_set_local_scale_vec(t, transform_get_local_scale(originTr));
        transform_set_local_position_vec(t, transform_get_local_position(originTr));
        transform_set_local_rotation(t, transform_get_local_rotation(originTr));

        // Note: do not parent automatically
    }

    return s;
}

void shape_flush(Shape *shape) {
    if (shape != NULL) {

        index3d_flush(shape->chunks, chunk_free_func);

        map_string_float3_free(shape->POIs);
        shape->POIs = map_string_float3_new();

        map_string_float3_free(shape->pois_rotation);
        shape->pois_rotation = map_string_float3_new();

        shape->bbMin = coords3_zero;
        shape->bbMax = coords3_zero;

        RigidBody *rb = shape_get_rigidbody(shape);
        if (rb != NULL) {
            rigidbody_reset(rb);
        }

        // free all buffers
        vertex_buffer_free_all(shape->firstVB_opaque);
        shape->firstVB_opaque = NULL;
        vertex_buffer_free_all(shape->firstIB_opaque);
        shape->firstIB_opaque = NULL;
        vertex_buffer_free_all(shape->firstVB_transparent);
        shape->firstVB_transparent = NULL;
        vertex_buffer_free_all(shape->firstIB_transparent);
        shape->firstIB_transparent = NULL;
        shape->vbAllocationFlag_opaque = 0;
        shape->vbAllocationFlag_transparent = 0;

        if (shape->dirtyChunks != NULL) {
            fifo_list_free(shape->dirtyChunks, NULL);
            shape->dirtyChunks = NULL;
        }

        // no need to flush fragmentedBuffers,
        // vertex_buffer_free_all has been called previously
        doubly_linked_list_free(shape->fragmentedBuffers);

        shape->nbChunks = 0;
        shape->nbBlocks = 0;
        shape->fragmentedBuffers = doubly_linked_list_new();
    }
}

bool shape_retain(Shape *const shape) {
    if (shape == NULL)
        return false;
    return transform_retain(shape->transform);
}

void shape_release(Shape *const shape) {
    if (shape == NULL) {
        return;
    }
    transform_release(shape->transform);
}

void shape_free(Shape *const shape) {
    if (shape == NULL) {
        return;
    }

    weakptr_invalidate(shape->wptr);

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

    if (shape->worldAABB != NULL) {
        box_free(shape->worldAABB);
        shape->worldAABB = NULL;
    }

    if (shape->pivot != NULL) {
        transform_release(shape->pivot); // created in shape_set_pivot
        shape->pivot = NULL;
    }

    index3d_flush(shape->chunks, chunk_free_func);
    index3d_free(shape->chunks);

    if (shape->dirtyChunks != NULL) {
        fifo_list_free(shape->dirtyChunks, NULL);
    }

    rtree_free(shape->rtree);

    // free all buffers
    vertex_buffer_free_all(shape->firstVB_opaque);
    vertex_buffer_free_all(shape->firstIB_opaque);
    vertex_buffer_free_all(shape->firstVB_transparent);
    vertex_buffer_free_all(shape->firstIB_transparent);

    // no need to flush fragmentedBuffers,
    // vertex_buffer_free_all has been called previously
    doubly_linked_list_free(shape->fragmentedBuffers);
    shape->fragmentedBuffers = NULL;

    // free history
    history_free(shape->history);
    shape->history = NULL;

    // free current transaction
    transaction_free(shape->pendingTransaction);
    shape->pendingTransaction = NULL;

    if (shape->fullname != NULL) {
        free(shape->fullname);
    }

    free(shape);
}

Weakptr *shape_get_weakptr(Shape *const s) {
    if (s->wptr == NULL) {
        s->wptr = weakptr_new(s);
    }
    return s->wptr;
}

Weakptr *shape_get_and_retain_weakptr(Shape *const s) {
    if (s->wptr == NULL) {
        s->wptr = weakptr_new(s);
    }
    if (weakptr_retain(s->wptr)) {
        return s->wptr;
    } else { // this can only happen if weakptr ref count is at max
        return NULL;
    }
}

uint16_t shape_get_id(const Shape *shape) {
    return transform_get_id(shape->transform);
}

// offset is always applied in this function
bool shape_add_block_as_transaction(Shape *const shape,
                                    Scene *scene,
                                    const SHAPE_COLOR_INDEX_INT_T colorIndex,
                                    const SHAPE_COORDS_INT_T x,
                                    const SHAPE_COORDS_INT_T y,
                                    const SHAPE_COORDS_INT_T z) {
    vx_assert(shape != NULL);

    // a new block cannot be added if there is an existing block at those coords
    const Block *existingBlock = shape_get_block(shape, x, y, z);

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

    if (transaction_addBlock(shape->pendingTransaction, x, y, z, colorIndex)) {
        // register awake box if using per-block collisions
        if (rigidbody_uses_per_block_collisions(transform_get_rigidbody(shape->transform))) {
            scene_register_awake_block_box(scene, shape, x, y, z);
        }
        return true;
    } else {
        return false;
    }
}

bool shape_remove_block_as_transaction(Shape *const shape,
                                       Scene *scene,
                                       const SHAPE_COORDS_INT_T x,
                                       const SHAPE_COORDS_INT_T y,
                                       const SHAPE_COORDS_INT_T z) {
    vx_assert(shape != NULL);

    // check whether a block already exists at the given coordinates
    const Block *existingBlock = shape_get_block(shape, x, y, z);

    if (block_is_solid(existingBlock) == false) {
        return false; // no block here
    }

    if (shape->pendingTransaction == NULL) {
        shape->pendingTransaction = transaction_new();
        if (shape->history != NULL) {
            history_discardTransactionsMoreRecentThanCursor(shape->history);
        }
    }

    transaction_removeBlock(shape->pendingTransaction, x, y, z);

    // register awake box is using per-block collisions
    if (rigidbody_uses_per_block_collisions(transform_get_rigidbody(shape->transform))) {
        scene_register_awake_block_box(scene, shape, x, y, z);
    }

    return true; // block is considered removed
}

bool shape_paint_block_as_transaction(Shape *const shape,
                                      const SHAPE_COLOR_INDEX_INT_T newColorIndex,
                                      const SHAPE_COORDS_INT_T x,
                                      const SHAPE_COORDS_INT_T y,
                                      const SHAPE_COORDS_INT_T z) {
    vx_assert(shape != NULL);

    // check whether a block already exists at the given coordinates
    const Block *existingBlock = shape_get_block(shape, x, y, z);

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

    transaction_replaceBlock(shape->pendingTransaction, x, y, z, newColorIndex);

    return true; // block is considered replaced
}

void shape_apply_current_transaction(Shape *const shape, bool keepPending) {
    vx_assert(shape != NULL);
    if (shape->pendingTransaction == NULL ||
        _shape_get_rendering_flag(shape, SHAPE_RENDERING_FLAG_BAKE_LOCKED)) {
        return; // no transaction to apply
    }

    const bool done = _shape_apply_transaction(shape, shape->pendingTransaction);
    if (done == false) {
        transaction_free(shape->pendingTransaction);
        shape->pendingTransaction = NULL;
        return;
    }

    keepPending = keepPending || (_shape_get_lua_flag(shape, SHAPE_LUA_FLAG_HISTORY) &&
                                  _shape_get_lua_flag(shape, SHAPE_LUA_FLAG_HISTORY_KEEP_PENDING));

    if (keepPending == false) {
        if (_shape_get_lua_flag(shape, SHAPE_LUA_FLAG_HISTORY) && shape->history != NULL) {
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

bool shape_add_block(Shape *shape,
                     SHAPE_COLOR_INDEX_INT_T colorIndex,
                     const SHAPE_COORDS_INT_T x,
                     const SHAPE_COORDS_INT_T y,
                     const SHAPE_COORDS_INT_T z,
                     bool useDefaultColor) {

    if (shape == NULL) {
        return false;
    }

    // if caller wants to express colorIndex as a default color, we translate it here
    if (useDefaultColor) {
        color_palette_check_and_add_default_color_2021(shape->palette, colorIndex, &colorIndex);
    }

    Block block = (Block){colorIndex};
    CHUNK_COORDS_INT3_T block_coords;
    Chunk *chunk = NULL;
    bool chunkAdded = false;
    bool blockAdded = _shape_add_block_in_chunks(shape,
                                                 block,
                                                 x,
                                                 y,
                                                 z,
                                                 &block_coords,
                                                 &chunkAdded,
                                                 &chunk,
                                                 NULL);

    if (chunkAdded) {
        shape->nbChunks++;
    }

    if (blockAdded) {
        shape->nbBlocks++;
        _shape_chunk_enqueue_refresh(shape, chunk);
        _shape_chunk_check_neighbors_dirty(shape, chunk, block_coords);

        shape_expand_box(shape, (SHAPE_COORDS_INT3_T){x, y, z});

        color_palette_increment_color(shape->palette, colorIndex);

        if (_shape_get_rendering_flag(shape, SHAPE_RENDERING_FLAG_BAKED_LIGHTING)) {
            shape_compute_baked_lighting_added_block(shape,
                                                     chunk,
                                                     (SHAPE_COORDS_INT3_T){x, y, z},
                                                     block_coords,
                                                     colorIndex);
        }
    }

    return blockAdded;
}

bool shape_remove_block(Shape *shape,
                        const SHAPE_COORDS_INT_T x,
                        const SHAPE_COORDS_INT_T y,
                        const SHAPE_COORDS_INT_T z) {

    if (shape == NULL) {
        return false;
    }

    bool removed = false;

    Chunk *chunk;
    CHUNK_COORDS_INT3_T coords_in_chunk;
    SHAPE_COORDS_INT3_T coords_in_shape = (SHAPE_COORDS_INT3_T){x, y, z};
    shape_get_chunk_and_coordinates(shape, coords_in_shape, &chunk, NULL, &coords_in_chunk);

    if (chunk != NULL) {
        SHAPE_COLOR_INDEX_INT_T prevColor;
        removed = chunk_remove_block(chunk,
                                     coords_in_chunk.x,
                                     coords_in_chunk.y,
                                     coords_in_chunk.z,
                                     &prevColor);

        if (removed) {
            shape->nbBlocks--;
            _shape_chunk_check_neighbors_dirty(shape, chunk, coords_in_chunk);
            _shape_chunk_enqueue_refresh(shape, chunk);

            if (_shape_get_rendering_flag(shape, SHAPE_RENDERING_FLAG_BAKED_LIGHTING)) {
                shape_compute_baked_lighting_removed_block(shape,
                                                           chunk,
                                                           coords_in_shape,
                                                           coords_in_chunk,
                                                           prevColor);
            }

            color_palette_decrement_color(shape->palette, prevColor);
        }

        // if chunk is now empty, do not destroy it right now and wait until shape_refresh_vertices:
        // 1) in case we reuse this chunk in the meantime
        // 2) to make sure vb count is always in sync with its data
    }

    return removed;
}

bool shape_paint_block(Shape *shape,
                       const SHAPE_COLOR_INDEX_INT_T colorIndex,
                       const SHAPE_COORDS_INT_T x,
                       const SHAPE_COORDS_INT_T y,
                       const SHAPE_COORDS_INT_T z) {

    if (shape == NULL) {
        return false;
    }

    bool painted = false;

    Chunk *chunk;
    CHUNK_COORDS_INT3_T coords_in_chunk;
    SHAPE_COORDS_INT3_T coords_in_shape = (SHAPE_COORDS_INT3_T){x, y, z};
    shape_get_chunk_and_coordinates(shape, coords_in_shape, &chunk, NULL, &coords_in_chunk);

    if (chunk != NULL) {
        SHAPE_COLOR_INDEX_INT_T prevColor;
        painted = chunk_paint_block(chunk,
                                    coords_in_chunk.x,
                                    coords_in_chunk.y,
                                    coords_in_chunk.z,
                                    colorIndex,
                                    &prevColor);
        if (painted) {
            color_palette_decrement_color(shape->palette, prevColor);
            color_palette_increment_color(shape->palette, colorIndex);

            _shape_chunk_enqueue_refresh(shape, chunk);

            if (_shape_get_rendering_flag(shape, SHAPE_RENDERING_FLAG_BAKED_LIGHTING)) {
                shape_compute_baked_lighting_replaced_block(shape,
                                                            chunk,
                                                            coords_in_shape,
                                                            coords_in_chunk,
                                                            colorIndex);
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

const Block *shape_get_block(const Shape *const shape,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z) {
    const Block *b = NULL;

    // look for the block in the current transaction
    if (shape->pendingTransaction != NULL) {
        b = transaction_getCurrentBlockAt(shape->pendingTransaction, x, y, z);
    }

    // transaction doesn't contain a block state for those coords,
    // let's check in the shape blocks
    if (b == NULL) {
        b = shape_get_block_immediate(shape, x, y, z);
    }

    return b;
}

Block *shape_get_block_immediate(const Shape *const shape,
                                 const SHAPE_COORDS_INT_T x,
                                 const SHAPE_COORDS_INT_T y,
                                 const SHAPE_COORDS_INT_T z) {

    Chunk *chunk;
    CHUNK_COORDS_INT3_T coords_in_chunk;
    shape_get_chunk_and_coordinates(shape,
                                    (SHAPE_COORDS_INT3_T){x, y, z},
                                    &chunk,
                                    NULL,
                                    &coords_in_chunk);

    if (chunk != NULL) {
        return chunk_get_block(chunk, coords_in_chunk.x, coords_in_chunk.y, coords_in_chunk.z);
    }

    return NULL;
}

void shape_get_bounding_box_size(const Shape *shape, int3 *size) {
    if (size == NULL)
        return;
    size->x = (int)(shape->bbMax.x - shape->bbMin.x);
    size->y = (int)(shape->bbMax.y - shape->bbMin.y);
    size->z = (int)(shape->bbMax.z - shape->bbMin.z);
}

SHAPE_SIZE_INT3_T shape_get_allocated_size(const Shape *shape) {
    return (SHAPE_SIZE_INT3_T){(SHAPE_SIZE_INT_T)shape->bbMax.x,
                               (SHAPE_SIZE_INT_T)shape->bbMax.y,
                               (SHAPE_SIZE_INT_T)shape->bbMax.z};
}

bool shape_is_within_bounding_box(const Shape *shape, const SHAPE_COORDS_INT3_T coords) {
    return coords.x >= shape->bbMin.x && coords.x < shape->bbMax.x && coords.y >= shape->bbMin.y &&
           coords.y < shape->bbMax.y && coords.z >= shape->bbMin.z && coords.z < shape->bbMax.z;
}

void shape_box_to_aabox(const Shape *s, const Box *box, Box *aabox, bool isCollider) {
    if (s == NULL || box == NULL || aabox == NULL)
        return;

    const float3 *offset = s->pivot != NULL ? transform_get_local_position(s->pivot) : &float3_zero;

    if (isCollider) {
        if (rigidbody_is_dynamic(shape_get_rigidbody(s))) {
            transform_utils_box_to_dynamic_collider(s->transform,
                                                    box,
                                                    aabox,
                                                    offset,
                                                    PHYSICS_SQUARIFY_DYNAMIC_COLLIDER ? MinSquarify
                                                                                      : NoSquarify);
        } else {
            transform_utils_box_to_static_collider(s->transform, box, aabox, offset, NoSquarify);
        }
    } else {
        transform_utils_box_to_aabb(s->transform, box, aabox, offset, NoSquarify);
    }
}

Box shape_get_model_aabb(const Shape *shape) {
    Box box = {(float3){(float)shape->bbMin.x, (float)shape->bbMin.y, (float)shape->bbMin.z},
               (float3){(float)shape->bbMax.x, (float)shape->bbMax.y, (float)shape->bbMax.z}};
    return box;
}

void shape_get_model_aabb_2(const Shape *s,
                            SHAPE_COORDS_INT3_T *bbMin,
                            SHAPE_COORDS_INT3_T *bbMax) {
    if (bbMin != NULL) {
        bbMin->x = s->bbMin.x;
        bbMin->y = s->bbMin.y;
        bbMin->z = s->bbMin.z;
    }
    if (bbMax != NULL) {
        bbMax->x = s->bbMax.x;
        bbMax->y = s->bbMax.y;
        bbMax->z = s->bbMax.z;
    }
}

void shape_get_local_aabb(const Shape *s, Box *box) {
    if (s == NULL || box == NULL)
        return;

    *box = shape_get_model_aabb(s);

    const Box model = shape_get_model_aabb(s);
    const float3 *offset = s->pivot != NULL ? transform_get_local_position(s->pivot) : &float3_zero;
    transform_refresh(s->transform, false, true); // refresh mtx for intra-frame calculations
    box_to_aabox2(&model, box, transform_get_mtx(s->transform), offset, false);
}

bool shape_get_world_aabb(Shape *s, Box *box) {
    if (s->worldAABB == NULL || transform_is_any_dirty(s->transform)) {
        const Box model = shape_get_model_aabb(s);
        shape_box_to_aabox(s, &model, box, false);
        if (s->worldAABB == NULL) {
            s->worldAABB = box_new_copy(box);
        } else {
            box_copy(s->worldAABB, box);
        }
        transform_reset_any_dirty(s->transform);
        return true;
    } else {
        box_copy(box, s->worldAABB);
        return false;
    }
}

void shape_reset_box(Shape *shape) {
    if (shape == NULL) {
        cclog_error("[shape_reset_box] shape arg is NULL. Abort.");
        return;
    }
    SHAPE_SIZE_INT_T size_x, size_y, size_z;
    SHAPE_COORDS_INT_T origin_x, origin_y, origin_z;
    _shape_compute_size_and_origin(shape,
                                   &size_x,
                                   &size_y,
                                   &size_z,
                                   &origin_x,
                                   &origin_y,
                                   &origin_z);

    shape->bbMin = (SHAPE_COORDS_INT3_T){origin_x, origin_y, origin_z};
    shape->bbMax = (SHAPE_COORDS_INT3_T){origin_x + (SHAPE_COORDS_INT_T)size_x,
                                         origin_y + (SHAPE_COORDS_INT_T)size_y,
                                         origin_z + (SHAPE_COORDS_INT_T)size_z};

    shape_fit_collider_to_bounding_box(shape);
    _shape_clear_cached_world_aabb(shape);
}

void shape_shrink_box(Shape *shape, const SHAPE_COORDS_INT3_T coords) {
    if (shape->nbBlocks == 0) {
        shape->bbMin = shape->bbMax = coords3_zero;
        return;
    }

    const SHAPE_COORDS_INT3_T chunkMin = chunk_utils_get_coords(shape->bbMin);
    const SHAPE_COORDS_INT3_T chunkMax = chunk_utils_get_coords(shape->bbMax);

    // for each BB side the removed block was in, gather the new boundary from chunks BB
    if (coords.x == shape->bbMax.x - 1) {
        Chunk *c;
        CHUNK_COORDS_INT3_T bbMax;
        CHUNK_COORDS_INT_T max;
        bool isEmpty = true, unchanged = false;
        for (SHAPE_COORDS_INT_T x = chunkMax.x; isEmpty && x >= chunkMin.x; --x) {
            max = 0;
            for (SHAPE_COORDS_INT_T z = chunkMin.z; z <= chunkMax.z; ++z) {
                for (SHAPE_COORDS_INT_T y = chunkMin.y; y <= chunkMax.y; ++y) {
                    c = index3d_get(shape->chunks, x, y, z);
                    if (c != NULL && chunk_get_nb_blocks(c) > 0) {
                        isEmpty = false;
                        chunk_get_bounding_box_2(c, NULL, &bbMax);
                        max = maximum(max, bbMax.x);

                        if (x == chunkMax.x && x * CHUNK_SIZE + bbMax.x == shape->bbMax.x) {
                            unchanged = true;
                            break; // no change, early stop
                        }
                    }
                }
                if (unchanged) {
                    break;
                }
            }
            if (isEmpty == false && unchanged == false) {
                shape->bbMax.x = x * CHUNK_SIZE + max;
            }
        }
    } else if (coords.x == shape->bbMin.x) {
        Chunk *c;
        CHUNK_COORDS_INT3_T bbMin;
        CHUNK_COORDS_INT_T min;
        bool isEmpty = true, unchanged = false;
        for (SHAPE_COORDS_INT_T x = chunkMin.x; isEmpty && x <= chunkMax.x; ++x) {
            min = CHUNK_SIZE;
            for (SHAPE_COORDS_INT_T z = chunkMin.z; z <= chunkMax.z; ++z) {
                for (SHAPE_COORDS_INT_T y = chunkMin.y; y <= chunkMax.y; ++y) {
                    c = index3d_get(shape->chunks, x, y, z);
                    if (c != NULL && chunk_get_nb_blocks(c) > 0) {
                        isEmpty = false;
                        chunk_get_bounding_box_2(c, &bbMin, NULL);
                        min = minimum(min, bbMin.x);

                        if (x == chunkMin.x && x * CHUNK_SIZE + bbMin.x == shape->bbMin.x) {
                            unchanged = true; // no change, early stop
                            break;
                        }
                    }
                }
                if (unchanged) {
                    break;
                }
            }
            if (isEmpty == false && unchanged == false) {
                shape->bbMin.x = x * CHUNK_SIZE + min;
            }
        }
    }
    if (coords.y == shape->bbMax.y - 1) {
        Chunk *c;
        CHUNK_COORDS_INT3_T bbMax;
        CHUNK_COORDS_INT_T max;
        bool isEmpty = true, unchanged = false;
        for (SHAPE_COORDS_INT_T y = chunkMax.y; isEmpty && y >= chunkMin.y; --y) {
            max = 0;
            for (SHAPE_COORDS_INT_T z = chunkMin.z; z <= chunkMax.z; ++z) {
                for (SHAPE_COORDS_INT_T x = chunkMin.x; x <= chunkMax.x; ++x) {
                    c = index3d_get(shape->chunks, x, y, z);
                    if (c != NULL && chunk_get_nb_blocks(c) > 0) {
                        isEmpty = false;
                        chunk_get_bounding_box_2(c, NULL, &bbMax);
                        max = maximum(max, bbMax.y);

                        if (y == chunkMax.y && y * CHUNK_SIZE + bbMax.y == shape->bbMax.y) {
                            unchanged = true; // no change, early stop
                            break;
                        }
                    }
                }
                if (unchanged) {
                    break;
                }
            }
            if (isEmpty == false && unchanged == false) {
                shape->bbMax.y = y * CHUNK_SIZE + max;
            }
        }
    } else if (coords.y == shape->bbMin.y) {
        Chunk *c;
        CHUNK_COORDS_INT3_T bbMin;
        CHUNK_COORDS_INT_T min;
        bool isEmpty = true, unchanged = false;
        for (SHAPE_COORDS_INT_T y = chunkMin.y; isEmpty && y <= chunkMax.y; ++y) {
            min = CHUNK_SIZE;
            for (SHAPE_COORDS_INT_T z = chunkMin.z; z <= chunkMax.z; ++z) {
                for (SHAPE_COORDS_INT_T x = chunkMin.x; x <= chunkMax.x; ++x) {
                    c = index3d_get(shape->chunks, x, y, z);
                    if (c != NULL && chunk_get_nb_blocks(c) > 0) {
                        isEmpty = false;
                        chunk_get_bounding_box_2(c, &bbMin, NULL);
                        min = minimum(min, bbMin.y);

                        if (y == chunkMin.y && y * CHUNK_SIZE + bbMin.y == shape->bbMin.y) {
                            unchanged = true; // no change, early stop
                            break;
                        }
                    }
                }
                if (unchanged) {
                    break;
                }
            }
            if (isEmpty == false && unchanged == false) {
                shape->bbMin.y = y * CHUNK_SIZE + min;
            }
        }
    }
    if (coords.z == shape->bbMax.z - 1) {
        Chunk *c;
        CHUNK_COORDS_INT3_T bbMax;
        CHUNK_COORDS_INT_T max;
        bool isEmpty = true, unchanged = false;
        for (SHAPE_COORDS_INT_T z = chunkMax.z; isEmpty && z >= chunkMin.z; --z) {
            max = 0;
            for (SHAPE_COORDS_INT_T x = chunkMin.x; x <= chunkMax.x; ++x) {
                for (SHAPE_COORDS_INT_T y = chunkMin.y; y <= chunkMax.y; ++y) {
                    c = index3d_get(shape->chunks, x, y, z);
                    if (c != NULL && chunk_get_nb_blocks(c) > 0) {
                        isEmpty = false;
                        chunk_get_bounding_box_2(c, NULL, &bbMax);
                        max = maximum(max, bbMax.z);

                        if (z == chunkMax.z && z * CHUNK_SIZE + bbMax.z == shape->bbMax.z) {
                            unchanged = true; // no change, early stop
                            break;
                        }
                    }
                }
                if (unchanged) {
                    break;
                }
            }
            if (isEmpty == false && unchanged == false) {
                shape->bbMax.z = z * CHUNK_SIZE + max;
            }
        }
    } else if (coords.z == shape->bbMin.z) {
        Chunk *c;
        CHUNK_COORDS_INT3_T bbMin;
        CHUNK_COORDS_INT_T min;
        bool isEmpty = true, unchanged = false;
        for (SHAPE_COORDS_INT_T z = chunkMin.z; isEmpty && z <= chunkMax.z; ++z) {
            min = CHUNK_SIZE;
            for (SHAPE_COORDS_INT_T x = chunkMin.x; x <= chunkMax.x; ++x) {
                for (SHAPE_COORDS_INT_T y = chunkMin.y; y <= chunkMax.y; ++y) {
                    c = index3d_get(shape->chunks, x, y, z);
                    if (c != NULL && chunk_get_nb_blocks(c) > 0) {
                        isEmpty = false;
                        chunk_get_bounding_box_2(c, &bbMin, NULL);
                        min = minimum(min, bbMin.z);

                        if (z == chunkMin.z && z * CHUNK_SIZE + bbMin.z == shape->bbMin.z) {
                            unchanged = true; // no change, early stop
                            break;
                        }
                    }
                }
                if (unchanged) {
                    break;
                }
            }
            if (isEmpty == false && unchanged == false) {
                shape->bbMin.z = z * CHUNK_SIZE + min;
            }
        }
    }

    shape_fit_collider_to_bounding_box(shape);
    _shape_clear_cached_world_aabb(shape);
}

void shape_expand_box(Shape *shape, const SHAPE_COORDS_INT3_T coords) {
    if (_shape_is_bounding_box_empty(shape)) {
        shape->bbMin = coords;
        shape->bbMax = (SHAPE_COORDS_INT3_T){coords.x + 1, coords.y + 1, coords.z + 1};
    } else {
        shape->bbMin.x = minimum(shape->bbMin.x, coords.x);
        shape->bbMin.y = minimum(shape->bbMin.y, coords.y);
        shape->bbMin.z = minimum(shape->bbMin.z, coords.z);
        shape->bbMax.x = maximum(shape->bbMax.x, coords.x + 1);
        shape->bbMax.y = maximum(shape->bbMax.y, coords.y + 1);
        shape->bbMax.z = maximum(shape->bbMax.z, coords.z + 1);
    }

    shape_fit_collider_to_bounding_box(shape);
    _shape_clear_cached_world_aabb(shape);
}

size_t shape_get_nb_blocks(const Shape *shape) {
    return shape->nbBlocks;
}

void shape_set_model_locked(Shape *s, bool toggle) {
    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKE_LOCKED, toggle);
}

bool shape_is_model_locked(Shape *s) {
    return _shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKE_LOCKED);
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

void shape_set_color_palette_atlas(Shape *s, ColorAtlas *ca) {
    if (s->palette == NULL) {
        return;
    }
    color_palette_set_atlas(s->palette, ca);
}

// MARK: - Transform -

void shape_set_pivot(Shape *s, const float x, const float y, const float z) {
    if (s == NULL) {
        return;
    }

    const bool isZero = float_isZero(x, EPSILON_ZERO) && float_isZero(y, EPSILON_ZERO) &&
                        float_isZero(z, EPSILON_ZERO);

    if (s->pivot == NULL) {
        // avoid unnecessary pivot
        if (isZero) {
            return;
        } else {
            // add a pivot internal transform, managed by shape
            s->pivot = transform_make_with_ptr(HierarchyTransform, s, NULL);
            transform_set_parent(s->pivot, s->transform, false);
        }
    } else if (isZero) {
        // remove unnecessary pivot
        transform_release(s->pivot);
        s->pivot = NULL;
        return;
    }

    transform_set_local_position(s->pivot, -x, -y, -z);
}

float3 shape_get_pivot(const Shape *s) {
    if (s == NULL || s->pivot == NULL)
        return float3_zero;

    const float3 *p = transform_get_local_position(s->pivot);
    float3 np = {-p->x, -p->y, -p->z};
    return np;
}

void shape_reset_pivot_to_center(Shape *s) {
    if (s == NULL)
        return;

    shape_set_pivot(s,
                    (float)s->bbMin.x + (float)(s->bbMax.x - s->bbMin.x) * 0.5f,
                    (float)s->bbMin.y + (float)(s->bbMax.y - s->bbMin.y) * 0.5f,
                    (float)s->bbMin.z + (float)(s->bbMax.z - s->bbMin.z) * 0.5f);
}

float3 shape_block_to_local(const Shape *s, const float x, const float y, const float z) {
    if (s == NULL)
        return float3_zero;

    const float3 pivot = shape_get_pivot(s);
    float3 local = {x - pivot.x, y - pivot.y, z - pivot.z};
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

    float3 pivot = shape_get_pivot(s);
    float3 block = {x + pivot.x, y + pivot.y, z + pivot.z};
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

const Matrix4x4 *shape_get_model_matrix(const Shape *s) {
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
    }
}

uint32_t shape_count_shape_descendants(const Shape *s) {
    uint32_t nbDescendants = 0;

    DoublyLinkedListNode *n = shape_get_transform_children_iterator(s);
    Transform *childTransform = NULL;
    Shape *child = NULL;
    while (n != NULL) {
        childTransform = (Transform *)(doubly_linked_list_node_pointer(n));

        child = transform_utils_get_shape(childTransform);
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

// MARK: - Chunks & buffers -

Index3D *shape_get_chunks(const Shape *shape) {
    return shape->chunks;
}

size_t shape_get_nb_chunks(const Shape *shape) {
    return shape->nbChunks;
}

void shape_get_chunk_and_coordinates(const Shape *shape,
                                     const SHAPE_COORDS_INT3_T coords_in_shape,
                                     Chunk **chunk,
                                     SHAPE_COORDS_INT3_T *chunk_coords,
                                     CHUNK_COORDS_INT3_T *coords_in_chunk) {

    const SHAPE_COORDS_INT3_T _chunk_coords = chunk_utils_get_coords(coords_in_shape);

    if (chunk_coords != NULL) {
        *chunk_coords = _chunk_coords;
    }
    if (coords_in_chunk != NULL) {
        *coords_in_chunk = chunk_utils_get_coords_in_chunk(coords_in_shape);
    }

    if (chunk != NULL) {
        *chunk = (Chunk *)
            index3d_get(shape->chunks, _chunk_coords.x, _chunk_coords.y, _chunk_coords.z);
    }
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

// Creates a new empty vertex buffer for the shape
// - enabling lighting buffer if it uses lighting
// - enabling transparency if requested
// after calling that function shape's lastVB_* will be empty
//
// The buffer capacity is an estimation that should on average reduce occupancy waste,
// 1) for a shape that was never drawn:
// - a) if it's the first buffer, it should ideally fit the entire shape at once (estimation)
// - b) if more space is required, subsequent buffers are scaled using SHAPE_BUFFER_INIT_SCALE_RATE
// this makes it possible to fit a worst-case scenario "cheese" map even if we know it practically
// won't happen
// 2) for a shape that has been drawn before:
// - a) first buffer should be of a minimal size to fit a few runtime structural changes
// (estimation)
// - b) subsequent buffers are scaled using SHAPE_BUFFER_RUNTIME_SCALE_RATE
// this approach should fit a game that by design do not result in a lot of structural changes,
// in just one buffer ; and should accommodate a game which by design requires a lot of structural
// changes, in just a handful of buffers down the chain
VertexBuffer *shape_add_buffer(Shape *shape, bool transparency, bool isVertexAttributes) {
    uint32_t capacity;

    if (isVertexAttributes) {
        // estimate new VB capacity
        uint8_t *flag = transparency ? &shape->vbAllocationFlag_transparent
                                     : &shape->vbAllocationFlag_opaque;
        switch (*flag) {
            // uninitialized or last buffer capacity was capped (1a)
            case 0: {
                int3 size;
                shape_get_bounding_box_size(shape, &size);

                // estimation based on number of faces of each chunks' cube surface area
                size_t shell = 6 * CHUNK_SIZE_SQR * 2 * shape->nbChunks;
                capacity = (uint32_t)(ceilf(
                    (float)shell * SHAPE_BUFFER_INITIAL_FACTOR *
                    (transparency ? SHAPE_BUFFER_TRANSPARENT_FACTOR : 1.0f)));

                // if this shape is exceptionally big and caps max VB count, next VB should be
                // created at full capacity as well
                if (capacity < SHAPE_BUFFER_MAX_COUNT) {
                    *flag = 1;
                }
                capacity = CLAMP(capacity, SHAPE_BUFFER_MIN_COUNT, SHAPE_BUFFER_MAX_COUNT);
                break;
            }
                // initialized within this frame and last buffer capacity was uncapped (1b)
            case 1: {
                size_t prev = vertex_buffer_get_max_count(
                    _shape_get_latest_buffer(shape, transparency, isVertexAttributes));

                // restart buffer series when minimum capacity has been reached already (if
                // downscaling buffers)
                if (prev == SHAPE_BUFFER_MIN_COUNT) {
                    *flag = 0;
                    return shape_add_buffer(shape, transparency, isVertexAttributes);
                }

                capacity = CLAMP((uint32_t)(ceilf((float)prev * SHAPE_BUFFER_INIT_SCALE_RATE)),
                                 SHAPE_BUFFER_MIN_COUNT,
                                 SHAPE_BUFFER_MAX_COUNT);
                break;
            }
                // initialized for more than a frame, first structural change (2a)
            case 2: {
                capacity = SHAPE_BUFFER_RUNTIME_COUNT;
                *flag = 3;
                break;
            }
                // initialized for more than a frame, subsequent structural change (2b)
            case 3: {
                uint32_t prev = vertex_buffer_get_max_count(
                    _shape_get_latest_buffer(shape, transparency, isVertexAttributes));
                capacity = CLAMP((uint32_t)(ceilf((float)prev * SHAPE_BUFFER_RUNTIME_SCALE_RATE)),
                                 SHAPE_BUFFER_MIN_COUNT,
                                 SHAPE_BUFFER_MAX_COUNT);
                break;
            }
            default: {
                capacity = SHAPE_BUFFER_MAX_COUNT;
                break;
            }
        }
    } else {
        // IB capacity is based off of last VB capacity
        vx_assert(transparency && shape->firstVB_transparent != NULL ||
                  transparency == false && shape->firstVB_opaque != NULL);

        uint32_t prev = vertex_buffer_get_max_count(
            _shape_get_latest_buffer(shape, transparency, true));
        capacity = prev / DRAWBUFFER_VERTICES_PER_FACE * DRAWBUFFER_INDICES_PER_FACE * 4; // TODO
    }

    // create and add a new buffer to the appropriate chain
    // Note: buffer order in chain does not matter, but we keep the same first buffer ptr for
    // convenience
    VertexBuffer *vb = vertex_buffer_new_with_max_count(capacity, transparency, isVertexAttributes);
    if (isVertexAttributes) {
        if (transparency) {
            if (shape->firstVB_transparent != NULL) {
                vertex_buffer_insert_after(vb, shape->firstVB_transparent);
            } else {
                shape->firstVB_transparent = vb;
            }
        } else {
            if (shape->firstVB_opaque != NULL) {
                vertex_buffer_insert_after(vb, shape->firstVB_opaque);
            } else {
                shape->firstVB_opaque = vb;
            }
        }
    } else {
        if (transparency) {
            if (shape->firstIB_transparent != NULL) {
                vertex_buffer_insert_after(vb, shape->firstIB_transparent);
            } else {
                shape->firstIB_transparent = vb;
            }
        } else {
            if (shape->firstIB_opaque != NULL) {
                vertex_buffer_insert_after(vb, shape->firstIB_opaque);
            } else {
                shape->firstIB_opaque = vb;
            }
        }
    }
    return vb;
}

void shape_refresh_vertices(Shape *shape) {
    if (_shape_get_rendering_flag(shape, SHAPE_RENDERING_FLAG_BAKE_LOCKED)) {
        _shape_fill_draw_slices(shape->firstVB_opaque);
        _shape_fill_draw_slices(shape->firstIB_opaque);
        _shape_fill_draw_slices(shape->firstVB_transparent);
        _shape_fill_draw_slices(shape->firstIB_transparent);
        return;
    }

    Chunk *c = shape->dirtyChunks != NULL ? fifo_list_pop(shape->dirtyChunks) : NULL;
    if (c == NULL) {
        return;
    }
    while (c != NULL) {
        // Note: chunk should never be NULL
        // Note: no need to check chunk_is_dirty, it has to be true

        // if the chunk has been emptied, we can remove it from shape index and destroy it
        // Note: this will create gaps in all the vb used for this chunk ie. make them fragmented
        if (chunk_get_nb_blocks(c) == 0) {
            const SHAPE_COORDS_INT3_T chunkOrigin = chunk_get_origin(c);
            SHAPE_COORDS_INT3_T chunk_coords = chunk_utils_get_coords(chunkOrigin);
            index3d_remove(shape->chunks,
                           (int)chunk_coords.x,
                           (int)chunk_coords.y,
                           (int)chunk_coords.z,
                           NULL);
            rtree_remove(shape->rtree, chunk_get_rtree_leaf(c), true);
            chunk_free(c, true);
            c = NULL;

            shape->nbChunks--;
        }
        // else chunk has data that needs updating
        else {
            chunk_write_vertices(shape, c);
        }

        if (c != NULL) {
            chunk_set_dirty(c, false);
        }

        c = fifo_list_pop(shape->dirtyChunks);
    }

    // DEFRAGMENTATION

    // check all IBs used by this shape, to see if they have to be defragmented
    _shape_check_all_vb_fragmented(shape, shape->firstIB_opaque);
    _shape_check_all_vb_fragmented(shape, shape->firstIB_transparent);

    VertexBuffer *fragmented = (VertexBuffer *)doubly_linked_list_pop_first(
        shape->fragmentedBuffers);
    while (fragmented != NULL) {
        vertex_buffer_fill_gaps(fragmented, false);

        fragmented = (VertexBuffer *)doubly_linked_list_pop_first(shape->fragmentedBuffers);
    }

    // VBs are never defragmented, vertex data can have gaps to be re-used later, just merge gaps
    _shape_check_all_vb_fragmented(shape, shape->firstVB_opaque);
    _shape_check_all_vb_fragmented(shape, shape->firstVB_transparent);

    fragmented = (VertexBuffer *)doubly_linked_list_pop_first(shape->fragmentedBuffers);
    while (fragmented != NULL) {
        vertex_buffer_fill_gaps(fragmented, true);

        fragmented = (VertexBuffer *)doubly_linked_list_pop_first(shape->fragmentedBuffers);
    }

    // fill draw slices after defragmentation
    _shape_fill_draw_slices(shape->firstVB_opaque);
    _shape_fill_draw_slices(shape->firstIB_opaque);
    _shape_fill_draw_slices(shape->firstVB_transparent);
    _shape_fill_draw_slices(shape->firstIB_transparent);

    _set_vb_allocation_flag_one_frame(shape);
}

void shape_refresh_all_vertices(Shape *s) {
#if SHAPE_REFRESH_ALL_BUFFERS_FREE
    // free all buffers
    vertex_buffer_free_all(s->firstVB_opaque);
    s->firstVB_opaque = NULL;
    vertex_buffer_free_all(s->firstIB_opaque);
    s->firstIB_opaque = NULL;
    vertex_buffer_free_all(s->firstVB_transparent);
    s->firstVB_transparent = NULL;
    vertex_buffer_free_all(s->firstIB_transparent);
    s->firstIB_transparent = NULL;
    s->vbAllocationFlag_opaque = 0;
    s->vbAllocationFlag_transparent = 0;
#endif

    // refresh all chunks
    Index3DIterator *it = index3d_iterator_new(s->chunks);
    Chunk *chunk;
    while (index3d_iterator_pointer(it) != NULL) {
        chunk = index3d_iterator_pointer(it);

#if SHAPE_REFRESH_ALL_BUFFERS_FREE
        chunk_set_vbma(chunk, NULL, false);
        chunk_set_vbma(chunk, NULL, true);
        chunk_set_ibma(chunk, NULL, false);
        chunk_set_ibma(chunk, NULL, true);
#endif

        chunk_write_vertices(s, chunk);
        chunk_set_dirty(chunk, false);

        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    // refresh draw slices after full refresh
    _shape_fill_draw_slices(s->firstVB_opaque);
    _shape_fill_draw_slices(s->firstIB_opaque);
    _shape_fill_draw_slices(s->firstVB_transparent);
    _shape_fill_draw_slices(s->firstIB_transparent);

    // flush dirty list
    if (s->dirtyChunks != NULL) {
        fifo_list_free(s->dirtyChunks, NULL);
        s->dirtyChunks = NULL;
    }
}

VertexBuffer *shape_get_first_vertex_buffer(const Shape *shape, bool transparent) {
    return transparent ? shape->firstVB_transparent : shape->firstVB_opaque;
}

VertexBuffer *shape_get_first_index_buffer(const Shape *shape, bool transparent) {
    return transparent ? shape->firstIB_transparent : shape->firstIB_opaque;
}

// MARK: - Physics -

Rtree *shape_get_rtree(const Shape *shape) {
    vx_assert(shape != NULL);
    return shape->rtree;
}

RigidBody *shape_get_rigidbody(const Shape *s) {
    vx_assert(s != NULL);
    return transform_get_rigidbody(s->transform);
}

bool shape_ensure_rigidbody(Shape *s, uint16_t groups, uint16_t collidesWith, RigidBody **out) {
    vx_assert(s != NULL);

    bool isNew = transform_ensure_rigidbody(s->transform,
                                            RigidbodyMode_Static,
                                            groups,
                                            collidesWith,
                                            out);
    if (isNew) {
        shape_fit_collider_to_bounding_box(s);
    }
    return isNew;
}

void shape_fit_collider_to_bounding_box(const Shape *s) {
    vx_assert(s != NULL);
    RigidBody *rb = shape_get_rigidbody(s);
    if (rb == NULL || rigidbody_is_collider_custom_set(rb))
        return;
    const Box aabb = shape_get_model_aabb(s);
    rigidbody_set_collider(rb, &aabb, false);
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
    shape_box_to_aabox(s, rigidbody_get_collider(rb), box, true);
}

typedef struct {
    Chunk *chunk;
    void *castData;
    float distance;
} _ChunkEntry;

void _chunk_entry_free_ray_func(void *ptr) {
    _ChunkEntry *ce = (_ChunkEntry *)ptr;
    ray_free((Ray *)ce->castData);
    free(ce);
}

void _chunk_entry_free_box_func(void *ptr) {
    _ChunkEntry *ce = (_ChunkEntry *)ptr;
    box_free((Box *)ce->castData);
    free(ce);
}

void _chunk_entry_insert(DoublyLinkedList *chunks, Chunk *c, void *castData, float d) {
    _ChunkEntry *newCe = (_ChunkEntry *)malloc(sizeof(_ChunkEntry));
    newCe->chunk = c;
    newCe->castData = castData;
    newCe->distance = d;

    // insert by order of increasing distance
    if (doubly_linked_list_first(chunks) == NULL) {
        doubly_linked_list_push_last(chunks, newCe);
    } else {
        bool inserted = false;
        DoublyLinkedListNode *n = doubly_linked_list_first(chunks);
        _ChunkEntry *ce;
        while (n != NULL && inserted == false) {
            ce = (_ChunkEntry *)doubly_linked_list_node_pointer(n);
            if (ce->distance > newCe->distance) {
                doubly_linked_list_insert_node_previous(chunks, n, newCe);
                inserted = true;
            }
            n = doubly_linked_list_node_next(n);
        }
        if (inserted == false) {
            doubly_linked_list_push_last(chunks, newCe);
        }
    }
}

float shape_box_cast(const Shape *s,
                     const Box *modelBox,
                     const float3 *modelVector,
                     const float3 *epsilon,
                     const bool withReplacement,
                     float3 *normal,
                     float3 *extraReplacement,
                     Block **block,
                     SHAPE_COORDS_INT3_T *blockCoords) {

    if (normal != NULL) {
        float3_set_one(normal);
    }

    if (extraReplacement != NULL) {
        float3_set_zero(extraReplacement);
    }

    float minSwept = 1.0f;
    const float maxDist = float3_length(modelVector);
    const float3 unit = {modelVector->x / maxDist,
                         modelVector->y / maxDist,
                         modelVector->z / maxDist};

    // select overlapped chunks
    DoublyLinkedList *chunksQuery = doubly_linked_list_new();
    if (rtree_query_cast_all_box(s->rtree, modelBox, &unit, maxDist, 0, 1, NULL, chunksQuery) > 0) {
        // sort query results by distance
        doubly_linked_list_sort_ascending(chunksQuery, rtree_utils_result_sort_func);

        Box broadPhaseBox, tmpBox;
        box_set_broadphase_box(modelBox, modelVector, &broadPhaseBox);

        // examine query results in order, return first hit block
        DoublyLinkedListNode *n = doubly_linked_list_first(chunksQuery);
        RtreeCastResult *rtreeHit;
        OctreeIterator *oi;
        Chunk *c;
        bool didHit = false, leaf;
        float3 tmpNormal, tmpReplacement;
        float swept = 1.0f, lastRtreeDist = FLT_MAX;
        while (n != NULL) {
            rtreeHit = (RtreeCastResult *)doubly_linked_list_node_pointer(n);
            c = (Chunk *)rtree_node_get_leaf_ptr(rtreeHit->rtreeLeaf);

            // make sure to examine all hits w/ similar distances before stopping
            if (didHit &&
                float_isEqual(rtreeHit->distance, lastRtreeDist, EPSILON_COLLISION) == false) {
                break;
            }
            lastRtreeDist = rtreeHit->distance;

            const SHAPE_COORDS_INT3_T chunkOrigin = chunk_get_origin(c);
            leaf = false;
#if PHYSICS_EXTRA_REPLACEMENTS
            float blockedX = false, blockedY = false, blockedZ = false;
#endif

            oi = octree_iterator_new(chunk_get_octree(c));
            while (octree_iterator_is_done(oi) == false) {
                octree_iterator_get_node_box(oi, &tmpBox);

                // chunk octree box in model space
                tmpBox.min.x += chunkOrigin.x;
                tmpBox.min.y += chunkOrigin.y;
                tmpBox.min.z += chunkOrigin.z;
                tmpBox.max.x += chunkOrigin.x;
                tmpBox.max.y += chunkOrigin.y;
                tmpBox.max.z += chunkOrigin.z;

                const bool collides = box_collide(&tmpBox, &broadPhaseBox);
                if (leaf && collides) {
                    swept = box_swept(modelBox,
                                      modelVector,
                                      &tmpBox,
                                      epsilon,
                                      withReplacement,
                                      &tmpNormal,
                                      &tmpReplacement);
                    if (swept < minSwept) {
                        minSwept = swept;
                        didHit = true;
                        if (normal != NULL) {
                            *normal = tmpNormal;
                        }
                        if (block != NULL) {
                            *block = (Block *)octree_iterator_get_element(oi);
                        }
                        if (blockCoords != NULL) {
                            uint16_t x, y, z;
                            octree_iterator_get_current_position(oi, &x, &y, &z);
                            blockCoords->x = (SHAPE_COORDS_INT_T)x;
                            blockCoords->y = (SHAPE_COORDS_INT_T)y;
                            blockCoords->z = (SHAPE_COORDS_INT_T)z;
                        }
                    }
#if PHYSICS_EXTRA_REPLACEMENTS
                    if (extraReplacement != NULL) {
                        if (tmpReplacement.x != 0.0f && blockedX == false) {
                            // previous replacement is positive and new replacement is positive &
                            // bigger
                            if (extraReplacement->x >= 0.0f &&
                                tmpReplacement.x > extraReplacement->x) {
                                extraReplacement->x = tmpReplacement.x;
                            }
                            // previous replacement is negative and new replacement is negative &
                            // bigger
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
                            if (extraReplacement->y >= 0.0f &&
                                tmpReplacement.y > extraReplacement->y) {
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
                            if (extraReplacement->z >= 0.0f &&
                                tmpReplacement.z > extraReplacement->z) {
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

                octree_iterator_next(oi, collides == false && leaf == false, &leaf);
            }
            octree_iterator_free(oi);

            if (didHit && blockCoords != NULL) {
                // chunk block coordinates in model space
                blockCoords->x += chunkOrigin.x;
                blockCoords->y += chunkOrigin.y;
                blockCoords->z += chunkOrigin.z;
            }

            n = doubly_linked_list_node_next(n);
        }
    }
    doubly_linked_list_flush(chunksQuery, free);
    doubly_linked_list_free(chunksQuery);

    return minSwept;
}

bool shape_ray_cast(const Shape *s,
                    const Ray *worldRay,
                    float *worldDistance,
                    float3 *localImpact,
                    Block **block,
                    SHAPE_COORDS_INT3_T *coords) {

    if (s == NULL || worldRay == NULL) {
        return false;
    }

    // we want a ray in model space to intersect with block coordinates
    Transform *t = shape_get_pivot_transform(s);
    Ray *modelRay = ray_world_to_local(worldRay, t);

    // select traversed chunks
    DoublyLinkedList *chunksQuery = doubly_linked_list_new();
    if (rtree_query_cast_all_ray(s->rtree, modelRay, 0, 1, NULL, chunksQuery) > 0) {
        // sort query results by distance
        doubly_linked_list_sort_ascending(chunksQuery, rtree_utils_result_sort_func);

        // examine query results in order, return first hit block
        DoublyLinkedListNode *n = doubly_linked_list_first(chunksQuery);
        RtreeCastResult *rtreeHit;
        OctreeIterator *oi;
        Chunk *c;
        bool didHit = false, leaf;
        Block *hitBlock = NULL;
        float minDistance = FLT_MAX, lastRtreeDist = FLT_MAX;
        uint16_t x = 0, y = 0, z = 0;
        Box tmpBox;
        float d;
        while (n != NULL) {
            rtreeHit = (RtreeCastResult *)doubly_linked_list_node_pointer(n);
            c = (Chunk *)rtree_node_get_leaf_ptr(rtreeHit->rtreeLeaf);

            // make sure to examine all hits w/ similar distances before stopping
            if (didHit &&
                float_isEqual(rtreeHit->distance, lastRtreeDist, EPSILON_COLLISION) == false) {
                break;
            }
            lastRtreeDist = rtreeHit->distance;

            const SHAPE_COORDS_INT3_T chunkOrigin = chunk_get_origin(c);
            leaf = false;

            oi = octree_iterator_new(chunk_get_octree(c));
            while (octree_iterator_is_done(oi) == false) {
                octree_iterator_get_node_box(oi, &tmpBox);

                // chunk octree box in model space
                tmpBox.min.x += chunkOrigin.x;
                tmpBox.min.y += chunkOrigin.y;
                tmpBox.min.z += chunkOrigin.z;
                tmpBox.max.x += chunkOrigin.x;
                tmpBox.max.y += chunkOrigin.y;
                tmpBox.max.z += chunkOrigin.z;

                const bool collides = ray_intersect_with_box(modelRay,
                                                             &tmpBox.min,
                                                             &tmpBox.max,
                                                             &d) &&
                                      d < minDistance;
                if (leaf && collides) {
                    didHit = true;
                    minDistance = d;
                    hitBlock = (Block *)octree_iterator_get_element(oi);
                    octree_iterator_get_current_position(oi, &x, &y, &z);
                }

                octree_iterator_next(oi, collides == false && leaf == false, &leaf);
            }
            octree_iterator_free(oi);

            if (didHit) {
                // chunk block coordinates in model space
                x += chunkOrigin.x;
                y += chunkOrigin.y;
                z += chunkOrigin.z;
            }

            n = doubly_linked_list_node_next(n);
        }

        if (hitBlock == NULL) {
            ray_free(modelRay);
            doubly_linked_list_flush(chunksQuery, free);
            doubly_linked_list_free(chunksQuery);
            return false;
        }

        if (worldDistance != NULL || localImpact != NULL) {
            float3 _localImpact;
            ray_impact_point(modelRay, minDistance, &_localImpact);
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
            *block = hitBlock;
        }

        if (coords != NULL) {
            coords->x = (SHAPE_COORDS_INT_T)x;
            coords->y = (SHAPE_COORDS_INT_T)y;
            coords->z = (SHAPE_COORDS_INT_T)z;
        }

        ray_free(modelRay);
        doubly_linked_list_flush(chunksQuery, free);
        doubly_linked_list_free(chunksQuery);
        return true;
    }

    ray_free(modelRay);
    doubly_linked_list_flush(chunksQuery, free);
    doubly_linked_list_free(chunksQuery);

    return false;
}

bool shape_point_overlap(const Shape *s, const float3 *world) {
    Transform *t = shape_get_pivot_transform(s); // octree coordinates use model origin
    float3 model;
    transform_utils_position_wtl(t, world, &model);

    Chunk *c;
    const SHAPE_COORDS_INT3_T coords_in_shape = (SHAPE_COORDS_INT3_T){(SHAPE_COORDS_INT_T)model.x,
                                                                      (SHAPE_COORDS_INT_T)model.y,
                                                                      (SHAPE_COORDS_INT_T)model.z};
    CHUNK_COORDS_INT3_T coords_in_chunk;
    shape_get_chunk_and_coordinates(s, coords_in_shape, &c, NULL, &coords_in_chunk);

    if (c != NULL) {
        Block *b = (Block *)octree_get_element_without_checking(chunk_get_octree(c),
                                                                (size_t)coords_in_chunk.x,
                                                                (size_t)coords_in_chunk.y,
                                                                (size_t)coords_in_chunk.z);

        return block_is_solid(b);
    }

    return false;
}

bool shape_box_overlap(const Shape *s, const Box *modelBox, Box *out) {
    if (s == NULL || modelBox == NULL) {
        return false;
    }

    // select overlapped chunks
    FifoList *chunksQuery = fifo_list_new();
    bool didHit = false;
    if (rtree_query_overlap_box(s->rtree, modelBox, 0, 1, NULL, chunksQuery, EPSILON_COLLISION) >
        0) {

        // examine query results, stop at first overlap
        RtreeNode *hit = fifo_list_pop(chunksQuery);
        OctreeIterator *oi;
        bool leaf;
        Chunk *c;
        Box tmpBox;
        while (hit != NULL && didHit == false) {
            c = (Chunk *)rtree_node_get_leaf_ptr(hit);

            const SHAPE_COORDS_INT3_T chunkOrigin = chunk_get_origin(c);
            leaf = false;

            oi = octree_iterator_new(chunk_get_octree(c));
            while (octree_iterator_is_done(oi) == false) {
                octree_iterator_get_node_box(oi, &tmpBox);

                // chunk octree box in model space
                tmpBox.min.x += chunkOrigin.x;
                tmpBox.min.y += chunkOrigin.y;
                tmpBox.min.z += chunkOrigin.z;
                tmpBox.max.x += chunkOrigin.x;
                tmpBox.max.y += chunkOrigin.y;
                tmpBox.max.z += chunkOrigin.z;

                const bool collides = box_collide(modelBox, &tmpBox);
                if (leaf && collides) {
                    didHit = true;
                    if (out != NULL) {
                        *out = tmpBox;
                    }
                    break;
                }

                octree_iterator_next(oi, collides == false && leaf == false, &leaf);
            }
            octree_iterator_free(oi);

            hit = fifo_list_pop(chunksQuery);
        }
    }
    fifo_list_free(chunksQuery, NULL);

    return didHit;
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

void shape_set_inner_transparent_faces(Shape *s, const bool toggle) {
    if (s == NULL) {
        return;
    }
    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_INNER_TRANSPARENT_FACES, toggle);
}

bool shape_draw_inner_transparent_faces(const Shape *s) {
    if (s == NULL) {
        return false;
    }
    return _shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_INNER_TRANSPARENT_FACES);
}

void shape_set_shadow(Shape *s, const bool toggle) {
    if (s == NULL) {
        return;
    }
    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_SHADOW, toggle);
}

bool shape_has_shadow(const Shape *s) {
    if (s == NULL) {
        return false;
    }
    return _shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_SHADOW);
}

void shape_set_unlit(Shape *s, const bool value) {
    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_UNLIT, value);
}

bool shape_is_unlit(const Shape *s) {
    return _shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_UNLIT);
}

void shape_set_layers(Shape *s, const uint16_t value) {
    s->layers = value;
}

uint16_t shape_get_layers(const Shape *s) {
    return s->layers;
}

// MARK: - POI -

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

void shape_compute_baked_lighting(Shape *s) {
    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING, true);

    LightNodeQueue *q = light_node_queue_new();
    SHAPE_COORDS_INT3_T min, max;

    _light_removal_all(s, &min, &max);
    _light_enqueue_ambient_and_block_sources(s, q, min, max, false);
    _light_propagate(s, &min, &max, q, min.x - 1, max.y, min.z - 1, true);

    light_node_queue_free(q);

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("Shape light computed");
#endif
}

void shape_toggle_baked_lighting(Shape *s, const bool toggle) {
    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING, toggle);
}

bool shape_uses_baked_lighting(const Shape *s) {
    return _shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING);
}

VERTEX_LIGHT_STRUCT_T *shape_create_lighting_data_blob(const Shape *s, void **inout) {
    VERTEX_LIGHT_STRUCT_T *blob;
    if (inout == NULL) {
        const size_t blobSize = (size_t)(s->bbMax.x - s->bbMin.x) *
                                (size_t)(s->bbMax.y - s->bbMin.y) *
                                (size_t)(s->bbMax.z - s->bbMin.z) *
                                (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
        blob = (VERTEX_LIGHT_STRUCT_T *)malloc(blobSize);
        if (blob == NULL) {
            return NULL;
        }
    } else {
        blob = *inout;
    }

    VERTEX_LIGHT_STRUCT_T *cursor = blob;
    for (SHAPE_COORDS_INT_T x = s->bbMin.x; x < s->bbMax.x; x++) {
        for (SHAPE_COORDS_INT_T y = s->bbMin.y; y < s->bbMax.y; y++) {
            for (SHAPE_COORDS_INT_T z = s->bbMin.z; z < s->bbMax.z; z++) {
                *cursor = shape_get_light_or_default(s, x, y, z);
                cursor = cursor + 1;
            }
        }
    }
    if (inout != NULL) {
        *inout = cursor;
    }

    return blob;
}

void shape_set_lighting_data_from_blob(Shape *s,
                                       VERTEX_LIGHT_STRUCT_T *blob,
                                       SHAPE_COORDS_INT3_T min,
                                       SHAPE_COORDS_INT3_T max) {

    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING, true);

    Chunk *chunk;
    CHUNK_COORDS_INT3_T coords_in_chunk;
    VERTEX_LIGHT_STRUCT_T *cursor = blob;
    for (SHAPE_COORDS_INT_T x = s->bbMin.x; x < s->bbMax.x; x++) {
        for (SHAPE_COORDS_INT_T y = s->bbMin.y; y < s->bbMax.y; y++) {
            for (SHAPE_COORDS_INT_T z = s->bbMin.z; z < s->bbMax.z; z++) {
                shape_get_chunk_and_coordinates(s,
                                                (SHAPE_COORDS_INT3_T){x, y, z},
                                                &chunk,
                                                NULL,
                                                &coords_in_chunk);
                if (chunk != NULL) {
                    chunk_set_light(chunk, coords_in_chunk, *cursor, false);
                }
                cursor = cursor + 1;
            }
        }
    }

    free(blob);
}

void shape_clear_baked_lighing(Shape *s) {
    Index3DIterator *it = index3d_iterator_new(s->chunks);
    Chunk *c;
    while (index3d_iterator_pointer(it) != NULL) {
        c = index3d_iterator_pointer(it);

        chunk_clear_lighting_data(c);
        _shape_chunk_enqueue_refresh(s, c);

        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    _shape_toggle_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING, false);
}

VERTEX_LIGHT_STRUCT_T shape_get_light_or_default(const Shape *s,
                                                 SHAPE_COORDS_INT_T x,
                                                 SHAPE_COORDS_INT_T y,
                                                 SHAPE_COORDS_INT_T z) {
    if (shape_uses_baked_lighting(s)) {
        Chunk *chunk;
        CHUNK_COORDS_INT3_T coords_in_chunk;
        shape_get_chunk_and_coordinates(s,
                                        (SHAPE_COORDS_INT3_T){x, y, z},
                                        &chunk,
                                        NULL,
                                        &coords_in_chunk);
        const Block *b = chunk_get_block_2(chunk, coords_in_chunk);
        return chunk_get_light_or_default(chunk,
                                          coords_in_chunk,
                                          chunk == NULL || block_is_solid(b));
    } else {
        VERTEX_LIGHT_STRUCT_T light;
        DEFAULT_LIGHT(light)
        return light;
    }
}

void shape_compute_baked_lighting_removed_block(Shape *s,
                                                Chunk *c,
                                                SHAPE_COORDS_INT3_T coords_in_shape,
                                                CHUNK_COORDS_INT3_T coords_in_chunk,
                                                SHAPE_COLOR_INDEX_INT_T blockID) {
    if (s == NULL || c == NULL) {
        return;
    }

    if (_shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING) == false) {
        return;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️☀️☀️ compute light for removed block (%d, %d, %d)",
                coords_in_shape.x,
                coords_in_shape.y,
                coords_in_shape.z);
#endif

    LightNodeQueue *lightQueue = light_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    SHAPE_COORDS_INT3_T min, max;
    min.x = max.x = coords_in_shape.x;
    min.y = max.y = coords_in_shape.y;
    min.z = max.z = coords_in_shape.z;

    // get existing values
    VERTEX_LIGHT_STRUCT_T existingLight = chunk_get_light_without_checking(c, coords_in_chunk);

    // if self is emissive, start light removal
    if (existingLight.red > 0 || existingLight.green > 0 || existingLight.blue > 0) {
        LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

        light_removal_node_queue_push(lightRemovalQueue,
                                      c,
                                      coords_in_shape,
                                      existingLight,
                                      15,
                                      blockID);

        // run light removal
        _light_removal(s, &min, &max, lightRemovalQueue, lightQueue);

        light_removal_node_queue_free(lightRemovalQueue);
    }

    // add all neighbors to light propagation queue
    {
        SHAPE_COORDS_INT3_T insertCoords;
        Chunk *insertChunk;

        // x + 1
        insertCoords = (SHAPE_COORDS_INT3_T){coords_in_shape.x + 1,
                                             coords_in_shape.y,
                                             coords_in_shape.z};
        shape_get_chunk_and_coordinates(s, insertCoords, &insertChunk, NULL, NULL);
        light_node_queue_push(lightQueue, insertChunk, insertCoords);

        // x - 1
        insertCoords = (SHAPE_COORDS_INT3_T){coords_in_shape.x - 1,
                                             coords_in_shape.y,
                                             coords_in_shape.z};
        shape_get_chunk_and_coordinates(s, insertCoords, &insertChunk, NULL, NULL);
        light_node_queue_push(lightQueue, insertChunk, insertCoords);

        // y + 1
        insertCoords = (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                             coords_in_shape.y + 1,
                                             coords_in_shape.z};
        shape_get_chunk_and_coordinates(s, insertCoords, &insertChunk, NULL, NULL);
        light_node_queue_push(lightQueue, insertChunk, insertCoords);

        // y - 1
        insertCoords = (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                             coords_in_shape.y - 1,
                                             coords_in_shape.z};
        shape_get_chunk_and_coordinates(s, insertCoords, &insertChunk, NULL, NULL);
        light_node_queue_push(lightQueue, insertChunk, insertCoords);

        // z + 1
        insertCoords = (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                             coords_in_shape.y,
                                             coords_in_shape.z + 1};
        shape_get_chunk_and_coordinates(s, insertCoords, &insertChunk, NULL, NULL);
        light_node_queue_push(lightQueue, insertChunk, insertCoords);

        // z - 1
        insertCoords = (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                             coords_in_shape.y,
                                             coords_in_shape.z - 1};
        shape_get_chunk_and_coordinates(s, insertCoords, &insertChunk, NULL, NULL);
        light_node_queue_push(lightQueue, insertChunk, insertCoords);
    }

    // self light values are now 0
    VERTEX_LIGHT_STRUCT_T zero;
    ZERO_LIGHT(zero)
    chunk_set_light(c, coords_in_chunk, zero, false);

    // Then we run the regular light propagation algorithm
    _light_propagate(s,
                     &min,
                     &max,
                     lightQueue,
                     coords_in_shape.x,
                     coords_in_shape.y,
                     coords_in_shape.z,
                     false);

    light_node_queue_free(lightQueue);
}

void shape_compute_baked_lighting_added_block(Shape *s,
                                              Chunk *c,
                                              SHAPE_COORDS_INT3_T coords_in_shape,
                                              CHUNK_COORDS_INT3_T coords_in_chunk,
                                              SHAPE_COLOR_INDEX_INT_T blockID) {

    if (s == NULL || c == NULL) {
        return;
    }

    if (_shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING) == false) {
        return;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️☀️☀️ compute light for added block (%d, %d, %d)",
                coords_in_shape.x,
                coords_in_shape.y,
                coords_in_shape.z);
#endif

    LightNodeQueue *lightQueue = light_node_queue_new();
    LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    SHAPE_COORDS_INT3_T min, max;
    min.x = max.x = coords_in_shape.x;
    min.y = max.y = coords_in_shape.y;
    min.z = max.z = coords_in_shape.z;

    // get existing and new light values
    VERTEX_LIGHT_STRUCT_T existingLight = chunk_get_light_without_checking(c, coords_in_chunk);
    VERTEX_LIGHT_STRUCT_T newLight = color_palette_get_emissive_color_as_light(s->palette, blockID);

    // if emissive, add it to the light propagation queue & store original emission of the block
    // note: we do this since palette may have been changed when running light removal at a later
    // point
    if (newLight.red > 0 || newLight.green > 0 || newLight.blue > 0) {
        light_node_queue_push(lightQueue, c, coords_in_shape);
        chunk_set_light(c, coords_in_chunk, newLight, false);
    }

    // start light removal from current position as an air block w/ existingLight
    light_removal_node_queue_push(lightRemovalQueue, c, coords_in_shape, existingLight, 15, 255);

    // check in the vicinity for any emissive block that would be affected by the added block
    const Block *block = NULL;
    VERTEX_LIGHT_STRUCT_T light;
    Chunk *insertChunk;
    for (CHUNK_COORDS_INT_T xo = -1; xo <= 1; ++xo) {
        for (CHUNK_COORDS_INT_T yo = -1; yo <= 1; ++yo) {
            for (CHUNK_COORDS_INT_T zo = -1; zo <= 1; ++zo) {
                if (xo == 0 && yo == 0 && zo == 0) {
                    continue;
                }

                block = chunk_get_block_including_neighbors(c,
                                                            coords_in_chunk.x + xo,
                                                            coords_in_chunk.y + yo,
                                                            coords_in_chunk.z + zo,
                                                            &insertChunk,
                                                            NULL);
                if (block != NULL && color_palette_is_emissive(s->palette, block->colorIndex)) {
                    light = color_palette_get_emissive_color_as_light(s->palette,
                                                                      block->colorIndex);

                    light_removal_node_queue_push(lightRemovalQueue,
                                                  insertChunk,
                                                  (SHAPE_COORDS_INT3_T){coords_in_shape.x + xo,
                                                                        coords_in_shape.y + yo,
                                                                        coords_in_shape.z + zo},
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
    _light_propagate(s,
                     &min,
                     &max,
                     lightQueue,
                     coords_in_shape.x,
                     coords_in_shape.y,
                     coords_in_shape.z,
                     false);

    light_node_queue_free(lightQueue);
}

void shape_compute_baked_lighting_replaced_block(Shape *s,
                                                 Chunk *c,
                                                 SHAPE_COORDS_INT3_T coords_in_shape,
                                                 CHUNK_COORDS_INT3_T coords_in_chunk,
                                                 SHAPE_COLOR_INDEX_INT_T blockID) {
    if (s == NULL || c == NULL) {
        return;
    }

    if (_shape_get_rendering_flag(s, SHAPE_RENDERING_FLAG_BAKED_LIGHTING) == false) {
        return;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️☀️☀️ compute light for replaced block (%d, %d, %d)",
                coords_in_shape.x,
                coords_in_shape.y,
                coords_in_shape.z);
#endif

    // get existing and new light values
    VERTEX_LIGHT_STRUCT_T existingLight = chunk_get_light_without_checking(c, coords_in_chunk);
    VERTEX_LIGHT_STRUCT_T newLight = color_palette_get_emissive_color_as_light(s->palette, blockID);

    // early exit if emission values did not change
    if (existingLight.red == newLight.red && existingLight.green == newLight.green &&
        existingLight.blue == newLight.blue) {
        return;
    }

    LightNodeQueue *lightQueue = light_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    SHAPE_COORDS_INT3_T min, max;
    min.x = max.x = coords_in_shape.x;
    min.y = max.y = coords_in_shape.y;
    min.z = max.z = coords_in_shape.z;

    // if replaced light was emissive, start light removal
    if (existingLight.red > 0 || existingLight.green > 0 || existingLight.blue > 0) {
        LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

        light_removal_node_queue_push(lightRemovalQueue,
                                      c,
                                      coords_in_shape,
                                      existingLight,
                                      15,
                                      blockID);

        // run light removal
        _light_removal(s, &min, &max, lightRemovalQueue, lightQueue);

        light_removal_node_queue_free(lightRemovalQueue);
    }

    // if new light is emissive, add it to the light propagation queue & store original emission of
    // the block note: we do this since palette may have been changed when running light removal at
    // a later point
    if (newLight.red > 0 || newLight.green > 0 || newLight.blue > 0) {
        light_node_queue_push(lightQueue, c, coords_in_shape);
        chunk_set_light(c, coords_in_chunk, newLight, false);
    } else {
        // self light values are now 0
        VERTEX_LIGHT_STRUCT_T zero;
        ZERO_LIGHT(zero)
        chunk_set_light(c, coords_in_chunk, zero, false);
    }

    // Then we run the regular light propagation algorithm
    _light_propagate(s,
                     &min,
                     &max,
                     lightQueue,
                     coords_in_shape.x,
                     coords_in_shape.y,
                     coords_in_shape.z,
                     false);

    light_node_queue_free(lightQueue);
}

uint64_t shape_get_baked_lighting_hash(const Shape *s) {
    if (s == NULL || s->palette == NULL) {
        return 0;
    }

    // combine palette hash with chunks hash
    uint64_t hash = (uint64_t)color_palette_get_lighting_hash(s->palette);
    Index3DIterator *it = index3d_iterator_new(s->chunks);
    Chunk *c;
    while (index3d_iterator_pointer(it) != NULL) {
        c = index3d_iterator_pointer(it);
        hash = chunk_get_hash(c, hash);
        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    return hash;
}

// MARK: - History -

void shape_history_setEnabled(Shape *s, const bool enable) {
    if (s == NULL) {
        return;
    }
    if (enable == _shape_get_lua_flag(s, SHAPE_LUA_FLAG_HISTORY)) {
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
    _shape_toggle_lua_flag(s, SHAPE_LUA_FLAG_HISTORY, enable);
}

bool shape_history_getEnabled(Shape *s) {
    if (s == NULL) {
        return false;
    }
    return _shape_get_lua_flag(s, SHAPE_LUA_FLAG_HISTORY);
}

void shape_history_setKeepTransactionPending(Shape *s, const bool b) {
    if (s == NULL) {
        return;
    }
    _shape_toggle_lua_flag(s, SHAPE_LUA_FLAG_HISTORY_KEEP_PENDING, b);
}

bool shape_history_getKeepTransactionPending(Shape *s) {
    if (s == NULL) {
        return false;
    }
    return _shape_get_lua_flag(s, SHAPE_LUA_FLAG_HISTORY_KEEP_PENDING);
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
        Transaction *const tr = history_getTransactionToUndo(s->history);
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

// MARK: - Lua flags -

bool shape_is_lua_mutable(const Shape *s) {
    if (s == NULL) {
        return false;
    }
    return _shape_get_lua_flag(s, SHAPE_LUA_FLAG_MUTABLE);
}

void shape_set_lua_mutable(Shape *s, const bool value) {
    if (s == NULL) {
        return;
    }
    _shape_toggle_lua_flag(s, SHAPE_LUA_FLAG_MUTABLE, value);
}

void shape_enableAnimations(Shape *const s) {
    if (s == NULL) {
        return;
    }
    if (s->transform == NULL) {
        return;
    }
    transform_set_animations_enabled(s->transform, true);
}

void shape_disableAnimations(Shape *const s) {
    if (s == NULL) {
        return;
    }
    if (s->transform == NULL) {
        return;
    }
    transform_set_animations_enabled(s->transform, false);
}

bool shape_getIgnoreAnimations(Shape *const s) {
    if (s == NULL) {
        return false;
    }
    if (s->transform == NULL) {
        return false;
    }
    return transform_is_animations_enabled(s->transform) == false;
}

// MARK: - private functions -

static void _shape_toggle_rendering_flag(Shape *s, const uint8_t flag, const bool toggle) {
    if (toggle) {
        s->renderingFlags |= flag;
    } else {
        s->renderingFlags &= ~flag;
    }
}

static bool _shape_get_rendering_flag(const Shape *s, const uint8_t flag) {
    return (s->renderingFlags & flag) != 0;
}

static void _shape_toggle_lua_flag(Shape *s, const uint8_t flag, const bool toggle) {
    if (toggle) {
        s->luaFlags |= flag;
    } else {
        s->luaFlags &= ~flag;
    }
}

static bool _shape_get_lua_flag(const Shape *s, const uint8_t flag) {
    return (s->luaFlags & flag) != 0;
}

void _shape_chunk_enqueue_refresh(Shape *shape, Chunk *c) {
    if (c == NULL)
        return;
    if (chunk_is_dirty(c) == false) {
        if (shape->dirtyChunks == NULL) {
            shape->dirtyChunks = fifo_list_new();
        }
        fifo_list_push(shape->dirtyChunks, c);
        chunk_set_dirty(c, true);
    }
}

void _shape_chunk_check_neighbors_dirty(Shape *shape,
                                        const Chunk *chunk,
                                        CHUNK_COORDS_INT3_T block_pos) {
    // Only neighbors sharing faces need to have their mesh set dirty
    // Not refreshing diagonal chunks will only affect AO on that corner, not essential
    // TODO: enable diagonal refresh once chunks slice refresh is implemented

    if (block_pos.x == 0) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, NX));
    } else if (block_pos.x == CHUNK_SIZE_MINUS_ONE) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, X));
    }

    if (block_pos.y == 0) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, NY));
    } else if (block_pos.y == CHUNK_SIZE_MINUS_ONE) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, Y));
    }

    if (block_pos.z == 0) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, NZ));
    } else if (block_pos.z == CHUNK_SIZE_MINUS_ONE) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, Z));
    }
}

bool _shape_add_block_in_chunks(Shape *shape,
                                const Block block,
                                const SHAPE_COORDS_INT_T x,
                                const SHAPE_COORDS_INT_T y,
                                const SHAPE_COORDS_INT_T z,
                                CHUNK_COORDS_INT3_T *block_coords,
                                bool *chunkAdded,
                                Chunk **added_or_existing_chunk,
                                Block **added_or_existing_block) {

    // see if there's a chunk ready for that block
    const SHAPE_COORDS_INT3_T chunk_coords = chunk_utils_get_coords((SHAPE_COORDS_INT3_T){x, y, z});
    Chunk *chunk = (Chunk *)
        index3d_get(shape->chunks, chunk_coords.x, chunk_coords.y, chunk_coords.z);

    // insert new chunk if needed
    if (chunk == NULL) {
        SHAPE_COORDS_INT3_T chunkOrigin = {(SHAPE_COORDS_INT_T)chunk_coords.x * CHUNK_SIZE,
                                           (SHAPE_COORDS_INT_T)chunk_coords.y * CHUNK_SIZE,
                                           (SHAPE_COORDS_INT_T)chunk_coords.z * CHUNK_SIZE};
        chunk = chunk_new(chunkOrigin);

        index3d_insert(shape->chunks, chunk, chunk_coords.x, chunk_coords.y, chunk_coords.z, NULL);
        chunk_move_in_neighborhood(shape->chunks, chunk, chunk_coords);

        Box chunkBox = {{(float)chunkOrigin.x, (float)chunkOrigin.y, (float)chunkOrigin.z},
                        {(float)(chunkOrigin.x + CHUNK_SIZE),
                         (float)(chunkOrigin.y + CHUNK_SIZE),
                         (float)(chunkOrigin.z + CHUNK_SIZE)}};
        chunk_set_rtree_leaf(chunk, rtree_create_and_insert(shape->rtree, &chunkBox, 1, 1, chunk));

        *chunkAdded = true;
    } else {
        *chunkAdded = false;
    }

    if (added_or_existing_chunk != NULL) {
        *added_or_existing_chunk = chunk;
    }

    CHUNK_COORDS_INT3_T coords_in_chunk = chunk_utils_get_coords_in_chunk(
        (SHAPE_COORDS_INT3_T){x, y, z});

    if (block_coords != NULL) {
        *block_coords = coords_in_chunk;
    }

    bool added = chunk_add_block(chunk,
                                 block,
                                 coords_in_chunk.x,
                                 coords_in_chunk.y,
                                 coords_in_chunk.z);

    if (added_or_existing_block != NULL) {
        *added_or_existing_block = chunk_get_block_2(chunk, coords_in_chunk);
    }

    return added;
}

// flag used in shape_add_buffer
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

void _lighting_set_dirty(SHAPE_COORDS_INT3_T *bbMin,
                         SHAPE_COORDS_INT3_T *bbMax,
                         SHAPE_COORDS_INT3_T coords) {
    if (vertex_buffer_get_lighting_enabled()) {
        bbMin->x = minimum(bbMin->x, coords.x);
        bbMin->y = minimum(bbMin->y, coords.y);
        bbMin->z = minimum(bbMin->z, coords.z);
        bbMax->x = maximum(bbMax->x, coords.x);
        bbMax->y = maximum(bbMax->y, coords.y);
        bbMax->z = maximum(bbMax->z, coords.z);
    }
}

void _lighting_postprocess_dirty(Shape *s, SHAPE_COORDS_INT3_T *bbMin, SHAPE_COORDS_INT3_T *bbMax) {
    if (vertex_buffer_get_lighting_enabled()) {
        // account for vertex lighting smoothing, values need to be updated on adjacent vertices
        SHAPE_COORDS_INT3_T chunkMin = chunk_utils_get_coords(
            (SHAPE_COORDS_INT3_T){bbMin->x - 1, bbMin->y - 1, bbMin->z - 1});
        SHAPE_COORDS_INT3_T chunkMax = chunk_utils_get_coords(
            (SHAPE_COORDS_INT3_T){bbMax->x + 1, bbMax->y + 1, bbMax->z + 1});

        Chunk *chunk;
        for (SHAPE_COORDS_INT_T x = chunkMin.x; x <= chunkMax.x; ++x) {
            for (SHAPE_COORDS_INT_T y = chunkMin.y; y <= chunkMax.y; ++y) {
                for (SHAPE_COORDS_INT_T z = chunkMin.z; z <= chunkMax.z; ++z) {
                    chunk = (Chunk *)index3d_get(s->chunks, x, y, z);
                    if (chunk != NULL) {
                        _shape_chunk_enqueue_refresh(s, chunk);
                    }
                }
            }
        }
    }
}

void _light_removal_process_neighbor(Shape *s,
                                     Chunk *c,
                                     SHAPE_COORDS_INT3_T *bbMin,
                                     SHAPE_COORDS_INT3_T *bbMax,
                                     VERTEX_LIGHT_STRUCT_T light,
                                     uint8_t srgb,
                                     bool equals,
                                     CHUNK_COORDS_INT3_T coords_in_chunk,
                                     SHAPE_COORDS_INT3_T coords_in_shape,
                                     const Block *neighbor,
                                     LightNodeQueue *lightQueue,
                                     LightRemovalNodeQueue *lightRemovalQueue) {

    // air and transparent blocks can be reset & further light removal
    if (neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK ||
        color_palette_is_transparent(s->palette, neighbor->colorIndex)) {
        VERTEX_LIGHT_STRUCT_T neighborLight = chunk_get_light_without_checking(c, coords_in_chunk);

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
            chunk_set_light(c, coords_in_chunk, neighborLight, false);
            _lighting_set_dirty(bbMin, bbMax, coords_in_shape);

            // enqueue neighbor for removal
            light_removal_node_queue_push(lightRemovalQueue,
                                          c,
                                          coords_in_shape,
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
            light_node_queue_push(lightQueue, c, coords_in_shape);
        }
    }
    // emissive blocks, if in the vicinity of light removal, may be re-enqueued as well
    else if (color_palette_is_emissive(s->palette, neighbor->colorIndex)) {
        light_node_queue_push(lightQueue, c, coords_in_shape);
    }
}

void _light_set_and_enqueue_source(Shape *shape,
                                   Chunk *c,
                                   CHUNK_COORDS_INT3_T coords_in_chunk,
                                   SHAPE_COORDS_INT3_T coords_in_shape,
                                   VERTEX_LIGHT_STRUCT_T source,
                                   LightNodeQueue *lightQueue,
                                   bool initEmpty) {
    VERTEX_LIGHT_STRUCT_T current = chunk_get_light_without_checking(c, coords_in_chunk);
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
        chunk_set_light(c, coords_in_chunk, current, initEmpty);

        // enqueue as a new light source if any value was higher
        if (lightQueue != NULL) {
            light_node_queue_push(lightQueue, c, coords_in_shape);
        }
    }
}

void _light_enqueue_ambient_and_block_sources(Shape *s,
                                              LightNodeQueue *q,
                                              SHAPE_COORDS_INT3_T min,
                                              SHAPE_COORDS_INT3_T max,
                                              bool enqueueAir) {
    // Ambient sources: blocks along plane (x,z) from above the volume
    SHAPE_COORDS_INT3_T coords_in_shape = {0, max.y, 0};
    for (SHAPE_COORDS_INT_T x = min.x - 1; x <= max.x; ++x) {
        for (SHAPE_COORDS_INT_T z = min.z - 1; z <= max.z; ++z) {
            coords_in_shape.x = x;
            coords_in_shape.z = z;
            light_node_queue_push(q, NULL, coords_in_shape);
        }
    }

    // Block sources: enqueue all emissive blocks in the given area
    const Block *b;
    SHAPE_COORDS_INT3_T chunkFrom = chunk_utils_get_coords(
        (SHAPE_COORDS_INT3_T){min.x - 1, min.y - 1, min.z - 1});
    SHAPE_COORDS_INT3_T chunkTo = chunk_utils_get_coords(
        (SHAPE_COORDS_INT3_T){max.x, max.y, max.z});

    Chunk *chunk;
    for (SHAPE_COORDS_INT_T x = chunkFrom.x; x <= chunkTo.x; ++x) {
        for (SHAPE_COORDS_INT_T y = chunkFrom.y; y <= chunkTo.y; ++y) {
            for (SHAPE_COORDS_INT_T z = chunkFrom.z; z <= chunkTo.z; ++z) {
                chunk = (Chunk *)index3d_get(s->chunks, x, y, z);
                if (chunk == NULL) {
                    continue;
                }

                // split iteration into two parts to get chunk only once
                for (CHUNK_COORDS_INT_T cx = 0; cx < CHUNK_SIZE; ++cx) {
                    for (CHUNK_COORDS_INT_T cy = 0; cy < CHUNK_SIZE; ++cy) {
                        for (CHUNK_COORDS_INT_T cz = 0; cz < CHUNK_SIZE; ++cz) {
                            coords_in_shape = (SHAPE_COORDS_INT3_T){x * CHUNK_SIZE + cx,
                                                                    y * CHUNK_SIZE + cy,
                                                                    z * CHUNK_SIZE + cz};
                            if (coords_in_shape.x < min.x || coords_in_shape.x > max.x ||
                                coords_in_shape.y < min.y || coords_in_shape.y > max.y ||
                                coords_in_shape.z < min.z || coords_in_shape.z > max.z) {
                                continue;
                            }

                            b = chunk_get_block(chunk, cx, cy, cz);
                            if (b != NULL && color_palette_is_emissive(s->palette, b->colorIndex)) {
                                light_node_queue_push(q, chunk, coords_in_shape);
                            } else if (block_is_solid(b) == false && enqueueAir) {
                                const VERTEX_LIGHT_STRUCT_T
                                    light = chunk_get_light_without_checking(
                                        chunk,
                                        (CHUNK_COORDS_INT3_T){cx, cy, cz});
                                if (light.blue > 0 || light.green > 0 || light.red > 0) {
                                    light_node_queue_push(q, chunk, coords_in_shape);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

void _light_block_propagate(Shape *s,
                            Chunk *c,
                            SHAPE_COORDS_INT3_T *bbMin,
                            SHAPE_COORDS_INT3_T *bbMax,
                            VERTEX_LIGHT_STRUCT_T current,
                            CHUNK_COORDS_INT3_T coords_in_chunk,
                            SHAPE_COORDS_INT3_T coords_in_shape,
                            const Block *neighbor,
                            bool air,
                            bool transparent,
                            LightNodeQueue *lightQueue,
                            uint8_t stepS,
                            uint8_t stepRGB,
                            bool initEmpty) {

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
            current.red = TO_UINT4((uint8_t)((float)current.red * absorbRGB));
            current.green = TO_UINT4((uint8_t)((float)current.green * absorbRGB));
            current.blue = TO_UINT4((uint8_t)((float)current.blue * absorbRGB));
            current.ambient = TO_UINT4((uint8_t)((float)current.ambient * absorbS));
        }

        VERTEX_LIGHT_STRUCT_T neighborLight = chunk_get_light_without_checking(c, coords_in_chunk);
        const bool propagateS = neighborLight.ambient < current.ambient - stepS;
        const bool propagateR = neighborLight.red < current.red - stepRGB;
        const bool propagateG = neighborLight.green < current.green - stepRGB;
        const bool propagateB = neighborLight.blue < current.blue - stepRGB;
        if (propagateS || propagateR || propagateG || propagateB) {
            if (propagateS) {
                neighborLight.ambient = TO_UINT4(current.ambient - stepS);
            }
            if (propagateR) {
                neighborLight.red = TO_UINT4(current.red - stepRGB);
            }
            if (propagateG) {
                neighborLight.green = TO_UINT4(current.green - stepRGB);
            }
            if (propagateB) {
                neighborLight.blue = TO_UINT4(current.blue - stepRGB);
            }
            chunk_set_light(c, coords_in_chunk, neighborLight, initEmpty);

            light_node_queue_push(lightQueue, c, coords_in_shape);
            _lighting_set_dirty(bbMin, bbMax, coords_in_shape);
        }
    }
    // if neighbor emissive, enqueue & store original emission of the block (relevant if first
    // propagation)
    else if (color_palette_is_emissive(s->palette, neighbor->colorIndex)) {
        chunk_set_light(c,
                        coords_in_chunk,
                        color_palette_get_emissive_color_as_light(s->palette, neighbor->colorIndex),
                        initEmpty);
        light_node_queue_push(lightQueue, c, coords_in_shape);
    }
}

void _light_propagate(Shape *s,
                      SHAPE_COORDS_INT3_T *bbMin,
                      SHAPE_COORDS_INT3_T *bbMax,
                      LightNodeQueue *lightQueue,
                      SHAPE_COORDS_INT_T srcX,
                      SHAPE_COORDS_INT_T srcY,
                      SHAPE_COORDS_INT_T srcZ,
                      bool initWithEmptyLight) {

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light propagation started...");
    int iCount = 0;
#endif

    // changed values bounding box
    SHAPE_COORDS_INT3_T min = *bbMin;
    SHAPE_COORDS_INT3_T max = *bbMax;

    // set source block dirty
    _lighting_set_dirty(&min, &max, (SHAPE_COORDS_INT3_T){srcX, srcY, srcZ});

    Chunk *chunk, *insertChunk;
    CHUNK_COORDS_INT3_T coords_in_chunk, cc;
    SHAPE_COORDS_INT3_T coords_in_shape, cs;
    const Block *current = NULL;
    const Block *neighbor = NULL;
    VERTEX_LIGHT_STRUCT_T currentLight;
    bool isCurrentAir, isCurrentOpen, isCurrentTransparent, isNeighborAir, isNeighborTransparent;
    LightNode *n = light_node_queue_pop(lightQueue);
    while (n != NULL) {
        coords_in_shape = light_node_get_coords(n);
        chunk = light_node_get_chunk(n);

        coords_in_chunk = chunk_utils_get_coords_in_chunk(coords_in_shape);

        current = chunk_get_block(chunk, coords_in_chunk.x, coords_in_chunk.y, coords_in_chunk.z);

        // get current light
        if (current == NULL) {
            DEFAULT_LIGHT(currentLight)
            isCurrentAir = true;
            isCurrentTransparent = false;
        } else {
            currentLight = chunk_get_light_without_checking(chunk, coords_in_chunk);
            isCurrentAir = current->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isCurrentTransparent = color_palette_is_transparent(s->palette, current->colorIndex);
        }
        isCurrentOpen = false; // is current node open ie. at least one neighbor is non-opaque

        // for each non-opaque neighbor: flag current node as open & propagate light if current
        // non-opaque
        // for each emissive neighbor: add to light queue if current non-opaque
        // y - 1
        cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x, coords_in_chunk.y - 1, coords_in_chunk.z};
        cs = (SHAPE_COORDS_INT3_T){coords_in_shape.x, coords_in_shape.y - 1, coords_in_shape.z};
        if (chunk != NULL) {
            neighbor = chunk_get_block_including_neighbors(chunk,
                                                           cc.x,
                                                           cc.y,
                                                           cc.z,
                                                           &insertChunk,
                                                           &cc);
        } else {
            shape_get_chunk_and_coordinates(s, cs, &insertChunk, NULL, &cc);
            neighbor = chunk_get_block_2(insertChunk, cc);
        }
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                // sunlight propagates infinitely vertically (step = 0)
                _light_block_propagate(s,
                                       insertChunk,
                                       &min,
                                       &max,
                                       currentLight,
                                       cc,
                                       (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                             coords_in_shape.y - 1,
                                                             coords_in_shape.z},
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       0,
                                       EMISSION_PROPAGATION_STEP,
                                       initWithEmptyLight);
            }
        }
        // propagate sunlight top-down from above the volume, through empty chunks, and on the sides
        else if (cs.y >= min.y && cs.y < max.y && cs.x >= min.x - 1 && cs.z >= min.z - 1 &&
                 cs.x <= max.x && cs.z <= max.z) {

            chunk_set_light(insertChunk, cc, currentLight, initWithEmptyLight);
            light_node_queue_push(lightQueue, insertChunk, cs);
            _lighting_set_dirty(&min, &max, coords_in_shape);
        }

        // y + 1
        cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x, coords_in_chunk.y + 1, coords_in_chunk.z};
        if (chunk != NULL) {
            neighbor = chunk_get_block_including_neighbors(chunk,
                                                           cc.x,
                                                           cc.y,
                                                           cc.z,
                                                           &insertChunk,
                                                           &cc);
        } else {
            cs = (SHAPE_COORDS_INT3_T){coords_in_shape.x, coords_in_shape.y + 1, coords_in_shape.z};
            shape_get_chunk_and_coordinates(s, cs, &insertChunk, NULL, &cc);
            neighbor = chunk_get_block_2(insertChunk, cc);
        }
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                _light_block_propagate(s,
                                       insertChunk,
                                       &min,
                                       &max,
                                       currentLight,
                                       cc,
                                       (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                             coords_in_shape.y + 1,
                                                             coords_in_shape.z},
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP,
                                       initWithEmptyLight);
            }
        }

        // x + 1
        cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x + 1, coords_in_chunk.y, coords_in_chunk.z};
        if (chunk != NULL) {
            neighbor = chunk_get_block_including_neighbors(chunk,
                                                           cc.x,
                                                           cc.y,
                                                           cc.z,
                                                           &insertChunk,
                                                           &cc);
        } else {
            cs = (SHAPE_COORDS_INT3_T){coords_in_shape.x + 1, coords_in_shape.y, coords_in_shape.z};
            shape_get_chunk_and_coordinates(s, cs, &insertChunk, NULL, &cc);
            neighbor = chunk_get_block_2(insertChunk, cc);
        }
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                _light_block_propagate(s,
                                       insertChunk,
                                       &min,
                                       &max,
                                       currentLight,
                                       cc,
                                       (SHAPE_COORDS_INT3_T){coords_in_shape.x + 1,
                                                             coords_in_shape.y,
                                                             coords_in_shape.z},
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP,
                                       initWithEmptyLight);
            }
        }

        // x - 1
        cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x - 1, coords_in_chunk.y, coords_in_chunk.z};
        if (chunk != NULL) {
            neighbor = chunk_get_block_including_neighbors(chunk,
                                                           cc.x,
                                                           cc.y,
                                                           cc.z,
                                                           &insertChunk,
                                                           &cc);
        } else {
            cs = (SHAPE_COORDS_INT3_T){coords_in_shape.x - 1, coords_in_shape.y, coords_in_shape.z};
            shape_get_chunk_and_coordinates(s, cs, &insertChunk, NULL, &cc);
            neighbor = chunk_get_block_2(insertChunk, cc);
        }
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                _light_block_propagate(s,
                                       insertChunk,
                                       &min,
                                       &max,
                                       currentLight,
                                       cc,
                                       (SHAPE_COORDS_INT3_T){coords_in_shape.x - 1,
                                                             coords_in_shape.y,
                                                             coords_in_shape.z},
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP,
                                       initWithEmptyLight);
            }
        }

        // z + 1
        cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x, coords_in_chunk.y, coords_in_chunk.z + 1};
        if (chunk != NULL) {
            neighbor = chunk_get_block_including_neighbors(chunk,
                                                           cc.x,
                                                           cc.y,
                                                           cc.z,
                                                           &insertChunk,
                                                           &cc);
        } else {
            cs = (SHAPE_COORDS_INT3_T){coords_in_shape.x, coords_in_shape.y, coords_in_shape.z + 1};
            shape_get_chunk_and_coordinates(s, cs, &insertChunk, NULL, &cc);
            neighbor = chunk_get_block_2(insertChunk, cc);
        }
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                _light_block_propagate(s,
                                       insertChunk,
                                       &min,
                                       &max,
                                       currentLight,
                                       cc,
                                       (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                             coords_in_shape.y,
                                                             coords_in_shape.z + 1},
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP,
                                       initWithEmptyLight);
            }
        }

        // z - 1
        cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x, coords_in_chunk.y, coords_in_chunk.z - 1};
        if (chunk != NULL) {
            neighbor = chunk_get_block_including_neighbors(chunk,
                                                           cc.x,
                                                           cc.y,
                                                           cc.z,
                                                           &insertChunk,
                                                           &cc);
        } else {
            cs = (SHAPE_COORDS_INT3_T){coords_in_shape.x, coords_in_shape.y, coords_in_shape.z - 1};
            shape_get_chunk_and_coordinates(s, cs, &insertChunk, NULL, &cc);
            neighbor = chunk_get_block_2(insertChunk, cc);
        }
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                _light_block_propagate(s,
                                       insertChunk,
                                       &min,
                                       &max,
                                       currentLight,
                                       cc,
                                       (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                             coords_in_shape.y,
                                                             coords_in_shape.z - 1},
                                       neighbor,
                                       isNeighborAir,
                                       isNeighborTransparent,
                                       lightQueue,
                                       SUNLIGHT_PROPAGATION_STEP,
                                       EMISSION_PROPAGATION_STEP,
                                       initWithEmptyLight);
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
            for (CHUNK_COORDS_INT_T xo = -1; xo <= 1; xo++) {
                for (CHUNK_COORDS_INT_T yo = -1; yo <= 1; yo++) {
                    for (CHUNK_COORDS_INT_T zo = -1; zo <= 1; zo++) {
                        cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x + xo,
                                                   coords_in_chunk.y + yo,
                                                   coords_in_chunk.z + zo};

                        neighbor = chunk_get_block_including_neighbors(chunk,
                                                                       cc.x,
                                                                       cc.y,
                                                                       cc.z,
                                                                       &insertChunk,
                                                                       &cc);
                        if (neighbor != NULL && block_is_opaque(neighbor, s->palette) == false) {
                            _light_set_and_enqueue_source(
                                s,
                                insertChunk,
                                cc,
                                (SHAPE_COORDS_INT3_T){coords_in_shape.x + xo,
                                                      coords_in_shape.y + yo,
                                                      coords_in_shape.z + zo},
                                currentLight,
                                lightQueue,
                                initWithEmptyLight);
                        }
                    }
                }
            }
        }

#if SHAPE_LIGHTING_DEBUG
        iCount++;
#endif

        light_node_queue_recycle(n);
        n = light_node_queue_pop(lightQueue);
    }

    _lighting_postprocess_dirty(s, &min, &max);

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light propagation done with %d iterations", iCount);
#endif
}

void _light_removal(Shape *s,
                    SHAPE_COORDS_INT3_T *bbMin,
                    SHAPE_COORDS_INT3_T *bbMax,
                    LightRemovalNodeQueue *lightRemovalQueue,
                    LightNodeQueue *lightQueue) {

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light removal started...");
    int iCount = 0;
#endif

    VERTEX_LIGHT_STRUCT_T light;
    uint8_t srgb;
    SHAPE_COLOR_INDEX_INT_T blockID;
    const Block *neighbor = NULL;
    Chunk *chunk, *insertChunk;
    SHAPE_COORDS_INT3_T coords_in_shape;
    CHUNK_COORDS_INT3_T coords_in_chunk, cc;
    LightRemovalNode *rn = light_removal_node_queue_pop(lightRemovalQueue);
    while (rn != NULL) {
        coords_in_shape = light_removal_node_get_coords(rn);
        light = light_removal_node_get_light(rn);
        srgb = light_removal_node_get_srgb(rn);
        blockID = light_removal_node_get_block_id(rn);
        chunk = light_removal_node_get_chunk(rn);

        // check that the current block is inside the shape bounds
        if (shape_is_within_bounding_box(s, coords_in_shape)) {
            coords_in_chunk = chunk_utils_get_coords_in_chunk(coords_in_shape);

            // if air or transparent block, proceed with light removal
            if (blockID == SHAPE_COLOR_INDEX_AIR_BLOCK ||
                color_palette_is_transparent(s->palette, blockID)) {
                // x + 1
                cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x + 1,
                                           coords_in_chunk.y,
                                           coords_in_chunk.z};
                neighbor = chunk_get_block_including_neighbors(chunk,
                                                               cc.x,
                                                               cc.y,
                                                               cc.z,
                                                               &insertChunk,
                                                               &cc);
                if (neighbor != NULL) {
                    _light_removal_process_neighbor(s,
                                                    insertChunk,
                                                    bbMin,
                                                    bbMax,
                                                    light,
                                                    srgb,
                                                    false,
                                                    cc,
                                                    (SHAPE_COORDS_INT3_T){coords_in_shape.x + 1,
                                                                          coords_in_shape.y,
                                                                          coords_in_shape.z},
                                                    neighbor,
                                                    lightQueue,
                                                    lightRemovalQueue);
                }
                // x - 1
                cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x - 1,
                                           coords_in_chunk.y,
                                           coords_in_chunk.z};
                neighbor = chunk_get_block_including_neighbors(chunk,
                                                               cc.x,
                                                               cc.y,
                                                               cc.z,
                                                               &insertChunk,
                                                               &cc);
                if (neighbor != NULL) {
                    _light_removal_process_neighbor(s,
                                                    insertChunk,
                                                    bbMin,
                                                    bbMax,
                                                    light,
                                                    srgb,
                                                    false,
                                                    cc,
                                                    (SHAPE_COORDS_INT3_T){coords_in_shape.x - 1,
                                                                          coords_in_shape.y,
                                                                          coords_in_shape.z},
                                                    neighbor,
                                                    lightQueue,
                                                    lightRemovalQueue);
                }
                // y + 1
                cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x,
                                           coords_in_chunk.y + 1,
                                           coords_in_chunk.z};
                neighbor = chunk_get_block_including_neighbors(chunk,
                                                               cc.x,
                                                               cc.y,
                                                               cc.z,
                                                               &insertChunk,
                                                               &cc);
                if (neighbor != NULL) {
                    _light_removal_process_neighbor(s,
                                                    insertChunk,
                                                    bbMin,
                                                    bbMax,
                                                    light,
                                                    srgb,
                                                    false,
                                                    cc,
                                                    (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                                          coords_in_shape.y + 1,
                                                                          coords_in_shape.z},
                                                    neighbor,
                                                    lightQueue,
                                                    lightRemovalQueue);
                }
                // y - 1
                cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x,
                                           coords_in_chunk.y - 1,
                                           coords_in_chunk.z};
                neighbor = chunk_get_block_including_neighbors(chunk,
                                                               cc.x,
                                                               cc.y,
                                                               cc.z,
                                                               &insertChunk,
                                                               &cc);
                if (neighbor != NULL) {
                    _light_removal_process_neighbor(s,
                                                    insertChunk,
                                                    bbMin,
                                                    bbMax,
                                                    light,
                                                    srgb,
                                                    false,
                                                    cc,
                                                    (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                                          coords_in_shape.y - 1,
                                                                          coords_in_shape.z},
                                                    neighbor,
                                                    lightQueue,
                                                    lightRemovalQueue);
                }
                // z + 1
                cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x,
                                           coords_in_chunk.y,
                                           coords_in_chunk.z + 1};
                neighbor = chunk_get_block_including_neighbors(chunk,
                                                               cc.x,
                                                               cc.y,
                                                               cc.z,
                                                               &insertChunk,
                                                               &cc);
                if (neighbor != NULL) {
                    _light_removal_process_neighbor(s,
                                                    insertChunk,
                                                    bbMin,
                                                    bbMax,
                                                    light,
                                                    srgb,
                                                    false,
                                                    cc,
                                                    (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                                          coords_in_shape.y,
                                                                          coords_in_shape.z + 1},
                                                    neighbor,
                                                    lightQueue,
                                                    lightRemovalQueue);
                }
                // z - 1
                cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x,
                                           coords_in_chunk.y,
                                           coords_in_chunk.z - 1};
                neighbor = chunk_get_block_including_neighbors(chunk,
                                                               cc.x,
                                                               cc.y,
                                                               cc.z,
                                                               &insertChunk,
                                                               &cc);
                if (neighbor != NULL) {
                    _light_removal_process_neighbor(s,
                                                    insertChunk,
                                                    bbMin,
                                                    bbMax,
                                                    light,
                                                    srgb,
                                                    false,
                                                    cc,
                                                    (SHAPE_COORDS_INT3_T){coords_in_shape.x,
                                                                          coords_in_shape.y,
                                                                          coords_in_shape.z - 1},
                                                    neighbor,
                                                    lightQueue,
                                                    lightRemovalQueue);
                }
            }
            // if emissive block
            // to account for homogeneous self-lighting as well during emissive block removal,
            // process all surrounding emissive block's neighbors instead of the regular 6
            else if (color_palette_is_emissive(s->palette, blockID)) {
                for (SHAPE_COORDS_INT_T xo = -1; xo <= 1; ++xo) {
                    for (SHAPE_COORDS_INT_T yo = -1; yo <= 1; ++yo) {
                        for (SHAPE_COORDS_INT_T zo = -1; zo <= 1; ++zo) {
                            if (xo == 0 && yo == 0 && zo == 0) {
                                continue;
                            }

                            cc = (CHUNK_COORDS_INT3_T){coords_in_chunk.x + (CHUNK_COORDS_INT_T)xo,
                                                       coords_in_chunk.y + (CHUNK_COORDS_INT_T)yo,
                                                       coords_in_chunk.z + (CHUNK_COORDS_INT_T)zo};
                            neighbor = chunk_get_block_including_neighbors(chunk,
                                                                           cc.x,
                                                                           cc.y,
                                                                           cc.z,
                                                                           &insertChunk,
                                                                           &cc);
                            if (neighbor != NULL) {
                                // only first-degree neighbors remove the emissive block's own RGB
                                // values (passing equals=true)
                                _light_removal_process_neighbor(
                                    s,
                                    insertChunk,
                                    bbMin,
                                    bbMax,
                                    light,
                                    15,
                                    true,
                                    cc,
                                    (SHAPE_COORDS_INT3_T){coords_in_shape.x + xo,
                                                          coords_in_shape.y + yo,
                                                          coords_in_shape.z + zo},
                                    neighbor,
                                    lightQueue,
                                    lightRemovalQueue);
                            }
                        }
                    }
                }
            }
        }

#if SHAPE_LIGHTING_DEBUG
        iCount++;
#endif

        light_removal_node_queue_recycle(rn);
        rn = light_removal_node_queue_pop(lightRemovalQueue);
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light removal done with %d iterations", iCount);
#endif
}

void _light_removal_all(Shape *s, SHAPE_COORDS_INT3_T *min, SHAPE_COORDS_INT3_T *max) {
    Index3DIterator *it = index3d_iterator_new(s->chunks);
    Chunk *c;
    bool init = true;
    while (index3d_iterator_pointer(it) != NULL) {
        c = index3d_iterator_pointer(it);

        const SHAPE_COORDS_INT3_T origin = chunk_get_origin(c);
        if (init) {
            *min = origin;
            *max = (SHAPE_COORDS_INT3_T){origin.x + CHUNK_SIZE,
                                         origin.y + CHUNK_SIZE,
                                         origin.z + CHUNK_SIZE};
            init = false;
        } else {
            min->x = minimum(min->x, origin.x);
            min->y = minimum(min->y, origin.y);
            min->z = minimum(min->z, origin.z);
            max->x = maximum(max->x, origin.x + CHUNK_SIZE);
            max->y = maximum(max->y, origin.y + CHUNK_SIZE);
            max->z = maximum(max->z, origin.z + CHUNK_SIZE);
        }
        chunk_reset_lighting_data(c, true);

        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    if (init) {
        *min = *max = coords3_zero;
    }
}

void _shape_check_all_vb_fragmented(Shape *s, VertexBuffer *first) {
    VertexBuffer *vb = first;
    while (vb != NULL) {
        if (vertex_buffer_is_fragmented(vb)) {
            doubly_linked_list_push_first(s->fragmentedBuffers, vb);
        }
        vb = vertex_buffer_get_next(vb);
    }
}

void _shape_flush_all_vb(Shape *s) {
    // unbind all chunks from current vertex buffers and set them dirty
    Index3DIterator *it = index3d_iterator_new(s->chunks);
    Chunk *c;
    while (index3d_iterator_pointer(it) != NULL) {
        c = index3d_iterator_pointer(it);

        chunk_set_vbma(c, NULL, false);
        chunk_set_ibma(c, NULL, false);
        chunk_set_vbma(c, NULL, true);
        chunk_set_ibma(c, NULL, true);
        _shape_chunk_enqueue_refresh(s, c);

        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    // free all buffers
    vertex_buffer_free_all(s->firstVB_opaque);
    s->firstVB_opaque = NULL;
    vertex_buffer_free_all(s->firstIB_opaque);
    s->firstIB_opaque = NULL;
    vertex_buffer_free_all(s->firstVB_transparent);
    s->firstVB_transparent = NULL;
    vertex_buffer_free_all(s->firstIB_transparent);
    s->firstIB_transparent = NULL;
    s->vbAllocationFlag_opaque = 0;
    s->vbAllocationFlag_transparent = 0;
}

void _shape_fill_draw_slices(VertexBuffer *vb) {
    while (vb != NULL) {
        vertex_buffer_fill_draw_slices(vb);
        // vertex_buffer_log_draw_slices(vb);
        vb = vertex_buffer_get_next(vb);
    }
}

VertexBuffer *_shape_get_latest_buffer(const Shape *s,
                                       const bool transparent,
                                       const bool isVertexAttributes) {
    VertexBuffer *result = transparent
                               ? (isVertexAttributes ? s->firstVB_transparent
                                                     : s->firstIB_transparent)
                               : (isVertexAttributes ? s->firstVB_opaque : s->firstIB_opaque);
    if (result != NULL) {
        // latest added buffer is always inserted after the first buffer ptr
        return vertex_buffer_get_next(result) != NULL ? vertex_buffer_get_next(result) : result;
    } else {
        return result;
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

    // Returned iterator remains under transaction responsibility
    // Do not free it!
    Index3DIterator *it = transaction_getIndex3DIterator(tr);
    if (it == NULL) {
        return false;
    }

    // loop on all the BlockChanges
    uint32_t resetBoxNeeded = false;
    SHAPE_COLOR_INDEX_INT_T before, after;
    SHAPE_COORDS_INT_T x, y, z;
    BlockChange *bc;
    const Block *b;

    while (index3d_iterator_pointer(it) != NULL) {
        bc = (BlockChange *)index3d_iterator_pointer(it);

        blockChange_getXYZ(bc, &x, &y, &z);

        // /!\ important note: transactions use an index3d therefore when several transactions
        // happen on the same block, they are amended into 1 unique transaction. This can be
        // an issue since transactions can be applied from a line-by-line refresh in Lua
        // (eg. shape.Width), meaning part of an amended transaction could've been applied
        // already. As a result, we'll always use the CURRENT block
        b = shape_get_block_immediate(sh, x, y, z);
        before = b != NULL ? b->colorIndex : SHAPE_COLOR_INDEX_AIR_BLOCK;
        blockChange_set_previous_color(bc, before);

        after = blockChange_getBlock(bc)->colorIndex;

        // [air>block] = add block
        if (before == SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_add_block(sh, after, x, y, z, false);
        }
        // [block>air] = remove block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after == SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_remove_block(sh, x, y, z);
            if (index3d_iterator_pointer(it) == NULL) {
                // if block removal is the only transaction, use cheaper function
                shape_shrink_box(sh, (SHAPE_COORDS_INT3_T){x, y, z});
            } else {
                resetBoxNeeded = true;
            }
        }
        // [block>block] = paint block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK &&
                 before != after) {
            shape_paint_block(sh, after, x, y, z);
        }

        index3d_iterator_next(it);
    }

    if (resetBoxNeeded) {
        shape_reset_box(sh);
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

    // Returned iterator remains under transaction responsibility
    // Do not free it!
    Index3DIterator *it = transaction_getIndex3DIterator(tr);
    if (it == NULL) {
        return false;
    }

    // loop on all the BlockChanges and revert them
    bool resetBoxNeeded = false;
    SHAPE_COLOR_INDEX_INT_T before, after;
    SHAPE_COORDS_INT_T x, y, z;
    BlockChange *bc;
    const Block *b;

    while (index3d_iterator_pointer(it) != NULL) {
        bc = (BlockChange *)index3d_iterator_pointer(it);

        blockChange_getXYZ(bc, &x, &y, &z);

        b = shape_get_block_immediate(sh, x, y, z);
        before = b != NULL ? b->colorIndex : SHAPE_COLOR_INDEX_AIR_BLOCK;

        after = blockChange_get_previous_color(bc);

        // [air>block] = add block
        if (before == SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_add_block(sh, after, x, y, z, false);
        }
        // [block>air] = remove block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after == SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_remove_block(sh, x, y, z);
            if (index3d_iterator_pointer(it) == NULL) {
                // if block removal is the only transaction, use cheaper function
                shape_shrink_box(sh, (SHAPE_COORDS_INT3_T){x, y, z});
            } else {
                resetBoxNeeded = true;
            }
        }
        // [block>block] = paint block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_paint_block(sh, after, x, y, z);
        }

        index3d_iterator_next(it);
    }

    if (resetBoxNeeded == true) {
        shape_reset_box(sh);
    }

    return true;
}

void _shape_clear_cached_world_aabb(Shape *s) {
    if (s->worldAABB != NULL) {
        box_free(s->worldAABB);
        s->worldAABB = NULL;
    }
}

bool _shape_compute_size_and_origin(const Shape *shape,
                                    SHAPE_SIZE_INT_T *size_x,
                                    SHAPE_SIZE_INT_T *size_y,
                                    SHAPE_SIZE_INT_T *size_z,
                                    SHAPE_COORDS_INT_T *origin_x,
                                    SHAPE_COORDS_INT_T *origin_y,
                                    SHAPE_COORDS_INT_T *origin_z) {

    Index3DIterator *it = index3d_iterator_new(shape->chunks);
    if (index3d_iterator_pointer(it) == NULL) {
        *size_x = 0;
        *size_y = 0;
        *size_z = 0;
        *origin_x = 0;
        *origin_y = 0;
        *origin_z = 0;
        return false; // empty shape
    }

    SHAPE_COORDS_INT3_T s_min = coords3_zero, s_max = coords3_zero;
    float3 c_min, c_max;
    Chunk *c;
    bool firstChunk = true;
    while (index3d_iterator_pointer(it) != NULL) {
        c = (Chunk *)index3d_iterator_pointer(it);

        if (chunk_get_nb_blocks(c) > 0) {
            chunk_get_bounding_box(c, &c_min, &c_max);
            const SHAPE_COORDS_INT3_T chunkOrigin = chunk_get_origin(c);

            const SHAPE_COORDS_INT3_T c_s_min = {chunkOrigin.x + (SHAPE_COORDS_INT_T)c_min.x,
                                                 chunkOrigin.y + (SHAPE_COORDS_INT_T)c_min.y,
                                                 chunkOrigin.z + (SHAPE_COORDS_INT_T)c_min.z};
            const SHAPE_COORDS_INT3_T c_s_max = {chunkOrigin.x + (SHAPE_COORDS_INT_T)c_max.x,
                                                 chunkOrigin.y + (SHAPE_COORDS_INT_T)c_max.y,
                                                 chunkOrigin.z + (SHAPE_COORDS_INT_T)c_max.z};

            if (firstChunk) {
                s_min = c_s_min;
                s_max = c_s_max;
                firstChunk = false;
            } else {
                s_min.x = minimum(s_min.x, c_s_min.x);
                s_min.y = minimum(s_min.y, c_s_min.y);
                s_min.z = minimum(s_min.z, c_s_min.z);
                s_max.x = maximum(s_max.x, c_s_max.x);
                s_max.y = maximum(s_max.y, c_s_max.y);
                s_max.z = maximum(s_max.z, c_s_max.z);
            }
        }

        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    *size_x = (SHAPE_SIZE_INT_T)(s_max.x - s_min.x);
    *size_y = (SHAPE_SIZE_INT_T)(s_max.y - s_min.y);
    *size_z = (SHAPE_SIZE_INT_T)(s_max.z - s_min.z);

    *origin_x = s_min.x;
    *origin_y = s_min.y;
    *origin_z = s_min.z;

    return true; // non-empty shape
}

bool _shape_is_bounding_box_empty(const Shape *shape) {
    return shape->bbMin.x == shape->bbMax.x || shape->bbMin.y == shape->bbMax.y ||
           shape->bbMin.z == shape->bbMax.z;
}
