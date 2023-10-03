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
#endif

// takes the 4 low bits of a and casts into uint8_t
#define TO_UINT4(a) (uint8_t)((a)&0x0F)

struct _Shape {
    Weakptr *wptr;

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

    // TODO: remove
    Octree *octree; // 8 bytes

    // NULL if shape does not use lighting
    VERTEX_LIGHT_STRUCT_T *lightingData;

    // buffers storing faces data used for rendering
    VertexBuffer *firstVB_opaque, *firstVB_transparent;
    VertexBuffer *lastVB_opaque, *lastVB_transparent;

    // Chunks are indexed by coordinates, and partitioned in a r-tree for physics queries
    Index3D *chunks;
    FifoList *dirtyChunks;
    Rtree *rtree;

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

    // octree resize offset, default zero until a resize occurs, is used to convert internal to Lua
    // coords in order to maintain consistent coordinates in a play session
    // /!\ nowhere in Cubzh Core should this be used, it should be used when
    // input/outputting values to Lua
    int3 offset; // 3 * 4 bytes

    // shape allocated size, going below 0 or past this limit requires a shape resize
    SHAPE_SIZE_INT_T maxWidth, maxHeight, maxDepth; // 3 * 2 bytes

    uint16_t layers; // 2 bytes

    // internal flag used for variable-size VB allocation, see shape_add_vertex_buffer
    uint8_t vbAllocationFlag_opaque;      // 1 byte
    uint8_t vbAllocationFlag_transparent; // 1 byte

    ShapeDrawMode drawMode; // 1 byte

    // Whether transparent inner faces between 2 blocks of a different color should be drawn
    bool innerTransparentFaces; // 1 byte

    bool shadow;  // 1 byte
    bool isUnlit; // 1 byte

    bool isMutable;                        // 1 byte
    bool historyEnabled;                   // 1 byte
    bool historyKeepingTransactionPending; // 1 byte

    // no automatic refresh, no model changes until unlocked
    bool isBakeLocked; // 1 byte

    char pad[2];
};

// MARK: - private functions prototypes -

void _shape_chunk_enqueue_refresh(Shape *shape, Chunk *c);
void _shape_chunk_check_neighbors_dirty(Shape *shape, const Chunk *chunk, const int3 *block_pos);
static bool _shape_add_block(Shape *shape,
                             const Block block,
                             SHAPE_COORDS_INT_T x,
                             SHAPE_COORDS_INT_T y,
                             SHAPE_COORDS_INT_T z);
static bool _shape_add_block_in_chunks(Shape *shape,
                                       const Block block,
                                       const SHAPE_COORDS_INT_T x,
                                       const SHAPE_COORDS_INT_T y,
                                       const SHAPE_COORDS_INT_T z,
                                       int3 *block_coords_out,
                                       bool *chunkAdded,
                                       Chunk **added_or_existing_chunk,
                                       Block **added_or_existing_block);

bool _has_allocated_size(const Shape *s);
bool _is_out_of_allocated_size(const Shape *s,
                               const SHAPE_COORDS_INT_T x,
                               const SHAPE_COORDS_INT_T y,
                               const SHAPE_COORDS_INT_T z);
bool _is_out_of_maximum_shape_size(const SHAPE_COORDS_INT_T x,
                                   const SHAPE_COORDS_INT_T y,
                                   const SHAPE_COORDS_INT_T z);
Octree *_new_octree(const SHAPE_COORDS_INT_T w,
                    const SHAPE_COORDS_INT_T h,
                    const SHAPE_COORDS_INT_T d);
void _set_vb_allocation_flag_one_frame(Shape *s);

/// internal functions used to flag the relevant data when lighting has changed
void _lighting_set_dirty(SHAPE_COORDS_INT3_T *bbMin,
                         SHAPE_COORDS_INT3_T *bbMax,
                         SHAPE_COORDS_INT_T x,
                         SHAPE_COORDS_INT_T y,
                         SHAPE_COORDS_INT_T z);
void _lighting_postprocess_dirty(Shape *s, SHAPE_COORDS_INT3_T *bbMin, SHAPE_COORDS_INT3_T *bbMax);

//// internal functions used to compute and update light propagation (sun & emission)
/// check a neighbor air block for light removal upon adding a block
void _light_removal_processNeighbor(Shape *s,
                                    SHAPE_COORDS_INT3_T *bbMin,
                                    SHAPE_COORDS_INT3_T *bbMax,
                                    VERTEX_LIGHT_STRUCT_T light,
                                    uint8_t srgb,
                                    bool equals,
                                    SHAPE_COORDS_INT3_T *neighborPos,
                                    const Block *neighbor,
                                    LightNodeQueue *lightQueue,
                                    LightRemovalNodeQueue *lightRemovalQueue);
/// insert light values and if necessary (lightQueue != NULL) add it to the light propagation queue
void _light_set_and_enqueue_source(SHAPE_COORDS_INT3_T *pos,
                                   Shape *shape,
                                   VERTEX_LIGHT_STRUCT_T source,
                                   LightNodeQueue *lightQueue);
void _light_enqueue_ambient_and_block_sources(Shape *s,
                                              LightNodeQueue *q,
                                              SHAPE_COORDS_INT3_T from,
                                              SHAPE_COORDS_INT3_T to,
                                              bool enqueueAir);
/// propagate light values at a given block
void _light_block_propagate(Shape *s,
                            SHAPE_COORDS_INT3_T *bbMin,
                            SHAPE_COORDS_INT3_T *bbMax,
                            VERTEX_LIGHT_STRUCT_T current,
                            SHAPE_COORDS_INT3_T *neighborPos,
                            const Block *neighbor,
                            bool air,
                            bool transparent,
                            LightNodeQueue *lightQueue,
                            uint8_t stepS,
                            uint8_t stepRGB);
/// light propagation algorithm
void _light_propagate(Shape *s,
                      SHAPE_COORDS_INT3_T *bbMin,
                      SHAPE_COORDS_INT3_T *bbMax,
                      LightNodeQueue *lightQueue,
                      SHAPE_COORDS_INT_T srcX,
                      SHAPE_COORDS_INT_T srcY,
                      SHAPE_COORDS_INT_T srcZ);
/// light removal also enqueues back any light source that needs recomputing
void _light_removal(Shape *s,
                    SHAPE_COORDS_INT3_T *bbMin,
                    SHAPE_COORDS_INT3_T *bbMax,
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
void _shape_flush_all_vb(Shape *s);
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
Shape *shape_make(void) {
    Shape *s = (Shape *)malloc(sizeof(Shape));

    int3_set(&s->offset, 0, 0, 0);

    s->wptr = NULL;
    s->palette = NULL;

    s->POIs = map_string_float3_new();
    s->pois_rotation = map_string_float3_new();

    s->box = box_new();
    s->worldAABB = NULL;

    s->octree = NULL;

    s->transform = transform_make_with_ptr(ShapeTransform, s, 0, NULL);
    s->pivot = NULL;

    s->lightingData = NULL;

    s->chunks = index3d_new();
    s->dirtyChunks = NULL;
    s->rtree = rtree_new(RTREE_NODE_MIN_CAPACITY, RTREE_NODE_MAX_CAPACITY);

    // vertex buffers will be created on demand during refresh
    s->firstVB_opaque = NULL;
    s->lastVB_opaque = NULL;
    s->firstVB_transparent = NULL;
    s->lastVB_transparent = NULL;
    s->vbAllocationFlag_opaque = 0;
    s->vbAllocationFlag_transparent = 0;

    s->history = NULL;
    s->fullname = NULL;
    s->pendingTransaction = NULL;
    s->nbChunks = 0;
    s->nbBlocks = 0;
    s->fragmentedVBs = doubly_linked_list_new();

    s->maxWidth = 0;
    s->maxHeight = 0;
    s->maxDepth = 0;

    s->drawMode = SHAPE_DRAWMODE_DEFAULT;
    s->innerTransparentFaces = true;
    s->shadow = true;
    s->isUnlit = false;
    s->layers = 1; // CAMERA_LAYERS_DEFAULT

    s->isMutable = false;

    s->historyEnabled = false;
    s->historyKeepingTransactionPending = false;

    s->isBakeLocked = false;

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

    s->drawMode = origin->drawMode;
    s->innerTransparentFaces = origin->innerTransparentFaces;
    s->isUnlit = origin->isUnlit;
    s->layers = origin->layers;
    s->isMutable = origin->isMutable;

    if (origin->octree != NULL) {
        s->octree = _new_octree((SHAPE_COORDS_INT_T)origin->maxWidth,
                                (SHAPE_COORDS_INT_T)origin->maxHeight,
                                (SHAPE_COORDS_INT_T)origin->maxDepth);

        s->maxWidth = origin->maxWidth;
        s->maxHeight = origin->maxHeight;
        s->maxDepth = origin->maxDepth;
    }

    const Block *b = NULL;
    for (SHAPE_COORDS_INT_T x = 0; x <= origin->maxWidth; x += 1) {
        for (SHAPE_COORDS_INT_T y = 0; y <= origin->maxHeight; y += 1) {
            for (SHAPE_COORDS_INT_T z = 0; z <= origin->maxDepth; z += 1) {
                b = shape_get_block(origin, x, y, z, false);
                if (b != NULL && b->colorIndex != SHAPE_COLOR_INDEX_AIR_BLOCK) {
                    shape_add_block_with_color(s, b->colorIndex, x, y, z, false, false, false);
                }
            }
        }
    }

    if (origin->lightingData != NULL) {
        const size_t lightingSize = (size_t)s->maxWidth * (size_t)s->maxHeight *
                                    (size_t)s->maxDepth * (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
        s->lightingData = (VERTEX_LIGHT_STRUCT_T *)malloc(lightingSize);
        if (s->lightingData == NULL) {
            return NULL;
        }
        memcpy(s->lightingData, origin->lightingData, lightingSize);
    }

    if (origin->fullname != NULL) {
        s->fullname = string_new_copy(origin->fullname);
    }

    Transform *t = shape_get_root_transform(origin);
    const char *name = transform_get_name(t);
    if (name != NULL) {
        transform_set_name(shape_get_root_transform(s), name);
    }

    return s;
}

Shape *shape_make_with_size(const uint16_t width,
                            const uint16_t height,
                            const uint16_t depth,
                            const bool isMutable) {

    Shape *s = shape_make();

    s->maxWidth = width;
    s->maxHeight = height;
    s->maxDepth = depth;

    s->isMutable = isMutable;

    return s;
}

Shape *shape_make_with_octree(const SHAPE_SIZE_INT_T width,
                              const SHAPE_SIZE_INT_T height,
                              const SHAPE_SIZE_INT_T depth,
                              const bool isMutable) {

    if (_is_out_of_maximum_shape_size((SHAPE_COORDS_INT_T)width,
                                      (SHAPE_COORDS_INT_T)height,
                                      (SHAPE_COORDS_INT_T)depth)) {
        return NULL;
    }

    Shape *s = shape_make();

    s->octree = _new_octree((SHAPE_COORDS_INT_T)width,
                            (SHAPE_COORDS_INT_T)height,
                            (SHAPE_COORDS_INT_T)depth);
    s->maxWidth = width;
    s->maxHeight = height;
    s->maxDepth = depth;

    s->isMutable = isMutable;

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
// won't happen
// 2) for a shape that has been drawn before:
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
            int3 size;
            shape_get_bounding_box_size(shape, &size);

            // estimation based on maximum of shape shell vs. shape volume block-occupancy
            size_t shell = (size_t)(minimum(size.z, 2) * size.x * size.y +
                                    minimum(size.y, 2) * size.x * maximum(size.z - 2, 0) +
                                    minimum(size.x, 2) * maximum(size.z - 2, 0) *
                                        maximum(size.y - 2, 0));
            float volume = (float)(size.x * size.y * size.z) * VERTEX_BUFFER_VOLUME_OCCUPANCY;
            if (shell >= (size_t)volume) {
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

            capacity = CLAMP((size_t)(ceilf((float)prev * VERTEX_BUFFER_INIT_SCALE_RATE)),
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
            capacity = CLAMP((size_t)(ceilf((float)prev * VERTEX_BUFFER_RUNTIME_SCALE_RATE)),
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
    size_t texSize = (size_t)(ceilf(sqrtf((float)capacity)));
#if VERTEX_BUFFER_TEX_UPPER_POT
    texSize = upper_power_of_two(texSize);
#endif
    capacity = texSize * texSize;

    // create and add new VB to the appropriate chain
    const bool lighting = vertex_buffer_get_lighting_enabled() && shape->lightingData != NULL;
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

void shape_flush(Shape *shape) {
    if (shape != NULL) {

        index3d_flush(shape->chunks, chunk_free_func);

        map_string_float3_free(shape->POIs);
        shape->POIs = map_string_float3_new();

        map_string_float3_free(shape->pois_rotation);
        shape->pois_rotation = map_string_float3_new();

        if (_has_allocated_size(shape)) {
            if (shape->octree != NULL) {
                octree_flush(shape->octree);
            }
            if (shape->lightingData != NULL) {
                const size_t lightingSize = (size_t)shape->maxWidth * (size_t)shape->maxHeight *
                                            (size_t)shape->maxDepth *
                                            (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
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
        shape->vbAllocationFlag_opaque = 0;
        shape->vbAllocationFlag_transparent = 0;

        if (shape->dirtyChunks != NULL) {
            fifo_list_free(shape->dirtyChunks, NULL);
            shape->dirtyChunks = NULL;
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

    index3d_flush(shape->chunks, chunk_free_func);
    index3d_free(shape->chunks);

    if (shape->dirtyChunks != NULL) {
        fifo_list_free(shape->dirtyChunks, NULL);
    }

    rtree_free(shape->rtree);

    // free all vertex buffers
    vertex_buffer_free_all(shape->firstVB_opaque);
    vertex_buffer_free_all(shape->firstVB_transparent);

    // no need to flush fragmentedVBs,
    // vertex_buffer_free_all has been called previously
    doubly_linked_list_free(shape->fragmentedVBs);
    shape->fragmentedVBs = NULL;

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

Weakptr *shape_get_weakptr(Shape *s) {
    if (s->wptr == NULL) {
        s->wptr = weakptr_new(s);
    }
    return s->wptr;
}

Weakptr *shape_get_and_retain_weakptr(Shape *s) {
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
bool shape_add_block_from_lua(Shape *const shape,
                              Scene *scene,
                              const SHAPE_COLOR_INDEX_INT_T colorIndex,
                              const SHAPE_COORDS_INT_T luaX,
                              const SHAPE_COORDS_INT_T luaY,
                              const SHAPE_COORDS_INT_T luaZ) {
    vx_assert(shape != NULL);

    // a new block cannot be added if their is an existing block at those coords
    const Block *existingBlock = shape_get_block(shape, luaX, luaY, luaZ, true);

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
        // register awake box if using per-block collisions
        if (rigidbody_uses_per_block_collisions(transform_get_rigidbody(shape->transform))) {
            SHAPE_COORDS_INT_T x = luaX, y = luaY, z = luaZ;
            shape_block_lua_to_internal(shape, &x, &y, &z);
            scene_register_awake_block_box(scene, shape, x, y, z);
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
        return false; // no block here
    }

    if (shape->pendingTransaction == NULL) {
        shape->pendingTransaction = transaction_new();
        if (shape->history != NULL) {
            history_discardTransactionsMoreRecentThanCursor(shape->history);
        }
    }

    transaction_removeBlock(shape->pendingTransaction, luaX, luaY, luaZ);

    // register awake box is using per-block collisions
    if (rigidbody_uses_per_block_collisions(transform_get_rigidbody(shape->transform))) {
        SHAPE_COORDS_INT_T x = luaX, y = luaY, z = luaZ;
        shape_block_lua_to_internal(shape, &x, &y, &z);
        scene_register_awake_block_box(scene, shape, x, y, z);
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
                                bool useDefaultColor) {

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

    // if caller wants to express colorIndex as a default color, we translate it here
    if (useDefaultColor) {
        color_palette_check_and_add_default_color_2021(shape->palette, colorIndex, &colorIndex);
    }

    Block block = (Block){colorIndex};
    const bool added = _shape_add_block(shape, block, x, y, z);

    if (added) {
        color_palette_increment_color(shape->palette, colorIndex);

        if (shape->octree != NULL) {
            octree_set_element(shape->octree, (void *)&block, (size_t)x, (size_t)y, (size_t)z);
        }

        if (shape->lightingData != NULL) {
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
                        const bool shrinkBox) {

    if (shape == NULL) {
        return false;
    }

    if (applyOffset) {
        shape_block_lua_to_internal(shape, &x, &y, &z);
    }

    // make sure block removed is within fixed boundaries
    if (_has_allocated_size(shape) && _is_out_of_allocated_size(shape, x, y, z)) {
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
        Block *block = chunk_get_block(chunk,
                                       (CHUNK_COORDS_INT_T)posInChunk.x,
                                       (CHUNK_COORDS_INT_T)posInChunk.y,
                                       (CHUNK_COORDS_INT_T)posInChunk.z);
        if (block == NULL) {
            return false;
        }

        SHAPE_COLOR_INDEX_INT_T colorIdx = block->colorIndex;
        if (blockBefore != NULL) {
            *blockBefore = block_new_copy(block);
        }
        removed = chunk_remove_block(chunk,
                                     (CHUNK_COORDS_INT_T)posInChunk.x,
                                     (CHUNK_COORDS_INT_T)posInChunk.y,
                                     (CHUNK_COORDS_INT_T)posInChunk.z);

        if (removed) {
            shape->nbBlocks--;
            _shape_chunk_check_neighbors_dirty(shape, chunk, &posInChunk);
            _shape_chunk_enqueue_refresh(shape, chunk);

            // note: box.min inclusive, box.max exclusive
            const bool shouldUpdateBB = x <= (SHAPE_COORDS_INT_T)shape->box->min.x ||
                                        x >= (SHAPE_COORDS_INT_T)shape->box->max.x - 1 ||
                                        y <= (SHAPE_COORDS_INT_T)shape->box->min.y ||
                                        y >= (SHAPE_COORDS_INT_T)shape->box->max.y - 1 ||
                                        z <= (SHAPE_COORDS_INT_T)shape->box->min.z ||
                                        z >= (SHAPE_COORDS_INT_T)shape->box->max.z - 1;

            if (shouldUpdateBB && shrinkBox) {
                shape_shrink_box(shape, true);
            }
            if (shape->octree != NULL) {
                Block *air = block_new_air();
                octree_remove_element(shape->octree, (size_t)x, (size_t)y, (size_t)z, air);
                block_free(air);
            }

            if (shape->lightingData != NULL) {
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
                       const bool applyOffset) {

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
        Block *block = chunk_get_block(chunk,
                                       (CHUNK_COORDS_INT_T)posInChunk.x,
                                       (CHUNK_COORDS_INT_T)posInChunk.y,
                                       (CHUNK_COORDS_INT_T)posInChunk.z);
        if (block == NULL) {
            return false;
        }

        const uint8_t prevColor = block->colorIndex;
        if (blockBefore != NULL) {
            *blockBefore = block_new_copy(block);
        }

        color_palette_decrement_color(shape->palette, prevColor);

        color_palette_increment_color(shape->palette, colorIndex);

        painted = chunk_paint_block(chunk,
                                    (CHUNK_COORDS_INT_T)posInChunk.x,
                                    (CHUNK_COORDS_INT_T)posInChunk.y,
                                    (CHUNK_COORDS_INT_T)posInChunk.z,
                                    colorIndex);
        if (blockAfter != NULL) {
            *blockAfter = block_new_copy(block);
        }
        if (painted) {
            _shape_chunk_enqueue_refresh(shape, chunk);

            // Note: block in chunk index and block in octree are 2 different copies
            if (shape->octree != NULL) {
                octree_set_element(shape->octree,
                                   (const void *)(&colorIndex),
                                   (size_t)x,
                                   (size_t)y,
                                   (size_t)z);
            }

            if (shape->lightingData != NULL) {
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

const Block *shape_get_block(const Shape *const shape,
                             SHAPE_COORDS_INT_T x,
                             SHAPE_COORDS_INT_T y,
                             SHAPE_COORDS_INT_T z,
                             const bool luaCoords) {
    const Block *b = NULL;

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
    if (shape_is_within_allocated_bounds(shape, x, y, z)) {
        static int3 globalPos;
        static int3 posInChunk;

        int3_set(&globalPos, x, y, z);

        static Chunk *chunk;

        shape_get_chunk_and_position_within(shape, &globalPos, &chunk, NULL, &posInChunk);

        // found chunk?
        if (chunk != NULL) {
            b = chunk_get_block(chunk,
                                (CHUNK_COORDS_INT_T)posInChunk.x,
                                (CHUNK_COORDS_INT_T)posInChunk.y,
                                (CHUNK_COORDS_INT_T)posInChunk.z);
        }
    }
    return b;
}

void shape_get_bounding_box_size(const Shape *shape, int3 *size) {
    if (size == NULL)
        return;
    box_get_size_int(shape->box, size);
}

void shape_get_allocated_size(const Shape *shape, int3 *size) {
    if (size == NULL)
        return;
    if (_has_allocated_size(shape)) {
        size->x = shape->maxWidth;
        size->y = shape->maxHeight;
        size->z = shape->maxDepth;
    } else {
        shape_get_bounding_box_size(shape, size);
    }
}

bool shape_is_within_allocated_bounds(const Shape *shape,
                                      const SHAPE_COORDS_INT_T x,
                                      const SHAPE_COORDS_INT_T y,
                                      const SHAPE_COORDS_INT_T z) {
    return x >= 0 && x < shape->maxWidth && y >= 0 && y < shape->maxHeight && z >= 0 &&
           z < shape->maxDepth;
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

const Box *shape_get_model_aabb(const Shape *shape) {
    return shape->box;
}

void shape_get_local_aabb(const Shape *s, Box *box) {
    if (s == NULL || box == NULL)
        return;

    const float3 *offset = s->pivot != NULL ? transform_get_local_position(s->pivot) : &float3_zero;
    transform_refresh(s->transform, false, true); // refresh mtx for intra-frame calculations
    box_to_aabox2(s->box, box, transform_get_mtx(s->transform), offset, false);
}

void shape_get_world_aabb(Shape *s, Box *box) {
    if (s->worldAABB == NULL || transform_is_any_dirty(s->transform)) {
        shape_box_to_aabox(s, s->box, box, false);
        if (s->worldAABB == NULL) {
            s->worldAABB = box_new_copy(box);
        } else {
            box_copy(s->worldAABB, box);
        }
        transform_reset_any_dirty(s->transform);
    } else {
        box_copy(box, s->worldAABB);
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
                s_min.y = minimum(s_min.y, c_s_min.x);
                s_min.z = minimum(s_min.z, c_s_min.x);
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

void shape_shrink_box(Shape *shape, bool forceColliderResize) {
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

    // fit collider only if not already set in deserialization
    const RigidBody *rb = shape_get_rigidbody(shape);
    if (rb == NULL) {
        return;
    }
    const Box *collider = rigidbody_get_collider(rb);
    if (forceColliderResize || (float3_isZero(&collider->min, EPSILON_ZERO) &&
                                float3_isZero(&collider->max, EPSILON_ZERO))) {
        shape_fit_collider_to_bounding_box(shape);
    }
}

void shape_expand_box(Shape *shape,
                      const SHAPE_COORDS_INT_T x,
                      const SHAPE_COORDS_INT_T y,
                      const SHAPE_COORDS_INT_T z) {
    const float xf = (const float)x;
    const float yf = (const float)y;
    const float zf = (const float)z;

    if (box_is_empty(shape->box)) {
        float3_set(&shape->box->min, xf, yf, zf);
        float3_set(&shape->box->max, xf + 1.0f, yf + 1.0f, zf + 1.0f);
    } else {
        if (xf < shape->box->min.x) {
            shape->box->min.x = xf;
        }
        if (yf < shape->box->min.y) {
            shape->box->min.y = yf;
        }
        if (zf < shape->box->min.z) {
            shape->box->min.z = zf;
        }
        if (xf >= shape->box->max.x) {
            shape->box->max.x = xf + 1.0f;
        }
        if (yf >= shape->box->max.y) {
            shape->box->max.y = yf + 1.0f;
        }
        if (zf >= shape->box->max.z) {
            shape->box->max.z = zf + 1.0f;
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

    if (shape->octree == NULL) {
        cclog_warning("shape_make_space not implemented for shape with no octree yet.");
        return;
    }

    // no need to make space if there is no fixed/allocated size (no octree nor lighting)
    if (_has_allocated_size(shape) == false) {
        cclog_warning(
            "⚠️ shape_make_space: not needed if shape has no fixed size (no octree nor "
            "lighting)");
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

    // If required min/max are within allocated bounds, then extra space is not needed.
    if (shape_is_within_allocated_bounds(shape, requiredMinX, requiredMinY, requiredMinZ) &&
        shape_is_within_allocated_bounds(shape, requiredMaxX, requiredMaxY, requiredMaxZ)) {
        return;
    }

    // cclog_info("📏 RESIZE IS NEEDED");

    // current shape's bounding box limits

    // NOTE: the bounding box origin can't be below {0,0,0}
    // But shape->offset can be used to represent blocks with negative coordinates
    int3 min, max;
    int3_set(&min,
             (int32_t)shape->box->min.x,
             (int32_t)shape->box->min.y,
             (int32_t)shape->box->min.z);
    int3_set(&max,
             (int32_t)shape->box->max.x,
             (int32_t)shape->box->max.y,
             (int32_t)shape->box->max.z);

    // cclog_trace("📏 CURRENT BOUNDING BOX: (%d,%d,%d) -> (%d,%d,%d)",
    //       min.x, min.y, min.z, max.x, max.y, max.z);

    // additional space required
    int3 spaceRequiredMin = int3_zero;
    int3 spaceRequiredMax = int3_zero;

    const bool isEmpty = shape->nbBlocks == 0;
    if (isEmpty) {
        // /!\ special case on an empty shape,
        // we will set its origin to newly added blocks, to avoid allocating huge
        // octrees when setting first block at arbitrary coordinates

        // let's have the initial model start at requested min
        spaceRequiredMin.x = 0;
        spaceRequiredMin.y = 0;
        spaceRequiredMin.z = 0;

        // and expand on the positive side
        spaceRequiredMax.x = requiredMaxX + 1 - requiredMinX;
        spaceRequiredMax.y = requiredMaxY + 1 - requiredMinY;
        spaceRequiredMax.z = requiredMaxZ + 1 - requiredMinZ;
    } else {
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
    }

    int3 boundingBoxSize;
    shape_get_bounding_box_size(shape, &boundingBoxSize);

    vx_assert(spaceRequiredMax.x >= 0);
    vx_assert(spaceRequiredMax.y >= 0);
    vx_assert(spaceRequiredMax.z >= 0);

    SHAPE_COORDS_INT3_T requiredSize = {
        (SHAPE_COORDS_INT_T)(boundingBoxSize.x + abs(spaceRequiredMin.x) + spaceRequiredMax.x),
        (SHAPE_COORDS_INT_T)(boundingBoxSize.y + abs(spaceRequiredMin.y) + spaceRequiredMax.y),
        (SHAPE_COORDS_INT_T)(boundingBoxSize.z + abs(spaceRequiredMin.z) + spaceRequiredMax.z)};

    if (_is_out_of_maximum_shape_size(requiredSize.x, requiredSize.y, requiredSize.z)) {
        return;
    }

    // cclog_info("📏 REQUIRED SIZE: (%d,%d,%d)",
    //       requiredSize.x, requiredSize.y, requiredSize.z);
    // cclog_info("📏 SPACE REQUIRED: min(%d, %d, %d) max(%d, %d, %d)",
    //       spaceRequiredMin.x, spaceRequiredMin.y, spaceRequiredMin.z,
    //       spaceRequiredMax.x, spaceRequiredMax.y, spaceRequiredMax.z);

    Octree *octree = NULL;
    Index3D *chunks = NULL;

    // largest dimension (among x, y, z)
    const size_t requiredSizeMax = (size_t)(maximum(maximum(requiredSize.x, requiredSize.y),
                                                    requiredSize.z));
    size_t octree_size = octree_get_dimension(shape->octree);

    int3 delta = int3_zero;

    if (requiredSizeMax > octree_size) {

        // cclog_info("📏 OCTREE NOT BIG ENOUGH");
        octree = _new_octree(requiredSize.x, requiredSize.y, requiredSize.z);
        vx_assert(octree != NULL); // shouldn't happen, here within octree max
        chunks = index3d_new();

        // newly allocated octree size
        octree_size = octree_get_dimension(octree);

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
        // bounding box, if not we'll need to offset model

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
            // octree is big enough, but there's no room around the bounding box:
            // model needs to be moved to make space for new blocks

            // cclog_info("📏 NO ROOM AROUND BOUNDING BOX");
            // cclog_info("📏 DELTA: (%d, %d, %d)", delta.x, delta.y, delta.z);

            // TODO: could it be more optimized to move blocks inside octree?
            SHAPE_COORDS_INT_T size = (SHAPE_COORDS_INT_T)octree_size;
            octree = _new_octree(size, size, size);
            vx_assert(octree != NULL); // shouldn't happen, here within octree max
            chunks = index3d_new();

        } else {
            // octree is big enough AND there's enough room around the bounding box:
            // nothing to do other than updating shape size & offset

            // cclog_info("📏 THERE'S ROOM AROUND THE BOUNDING BOX");
            // cclog_info("📏 SPACE REQUIRED: (%d, %d, %d) / (%d, %d, %d)",
            //       spaceRequiredMin.x, spaceRequiredMin.y, spaceRequiredMin.z,
            //       spaceRequiredMax.x, spaceRequiredMax.y, spaceRequiredMax.z);
        }
    }

    // from here, there may or may not be newly allocated octree/chunks to fill,
    // but we'll always apply offset to pivot, BB, etc.

    // /!\ special case: empty shape arbitrary model origin (see comment at the start of function)
    if (isEmpty) {
        delta.x -= requiredMinX;
        delta.y -= requiredMinY;
        delta.z -= requiredMinZ;
    }

    // added space
    const uint16_t ax = (const uint16_t)(abs(spaceRequiredMin.x) + spaceRequiredMax.x);
    const uint16_t ay = (const uint16_t)(abs(spaceRequiredMin.y) + spaceRequiredMax.y);
    const uint16_t az = (const uint16_t)(abs(spaceRequiredMin.z) + spaceRequiredMax.z);

    // update allocated size, adding blocks < 0 or > this size will require another resize
    if (ax > 0)
        shape->maxWidth += ax;
    if (ay > 0)
        shape->maxHeight += ay;
    if (az > 0)
        shape->maxDepth += az;

    // empty current dirty chunks list, if any
    if (shape->dirtyChunks != NULL) {
        fifo_list_free(shape->dirtyChunks, NULL);
        shape->dirtyChunks = NULL;
    }

    if (chunks != NULL) {
        // copy with offsets to blocks position
        const Block *block = NULL;
        SHAPE_COORDS_INT_T ox, oy, oz;
        Chunk *chunk = NULL;
        bool chunkAdded = false;

        for (SHAPE_SIZE_INT_T xx = (SHAPE_SIZE_INT_T)min.x; xx < max.x; ++xx) {
            for (SHAPE_SIZE_INT_T yy = (SHAPE_SIZE_INT_T)min.y; yy < max.y; ++yy) {
                for (SHAPE_SIZE_INT_T zz = (SHAPE_SIZE_INT_T)min.z; zz < max.z; ++zz) {

                    block = shape_get_block(shape,
                                            (SHAPE_COORDS_INT_T)xx,
                                            (SHAPE_COORDS_INT_T)yy,
                                            (SHAPE_COORDS_INT_T)zz,
                                            false);

                    if (block_is_solid(block)) {
                        // get offseted position
                        ox = (SHAPE_COORDS_INT_T)(xx + delta.x);
                        oy = (SHAPE_COORDS_INT_T)(yy + delta.y);
                        oz = (SHAPE_COORDS_INT_T)(zz + delta.z);

                        // check if it is within new bounds
                        vx_assert(ox >= 0 && oy >= 0 && oz >= 0 && ox < shape->maxWidth &&
                                  oy < shape->maxHeight && oz < shape->maxDepth);

                        vx_assert(octree != NULL);

                        octree_set_element(octree,
                                           (const void *)block,
                                           (size_t)ox,
                                           (size_t)oy,
                                           (size_t)oz);
                        _shape_add_block_in_chunks(shape,
                                                   *block,
                                                   ox,
                                                   oy,
                                                   oz,
                                                   NULL,
                                                   &chunkAdded,
                                                   &chunk,
                                                   NULL);

                        // flag this chunk as dirty (needs display)
                        if (chunkAdded) {
                            _shape_chunk_enqueue_refresh(shape, chunk);
                        }
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

    if (octree != NULL) {
        octree_free(shape->octree);
        shape->octree = octree;
    }
    if (chunks != NULL) {
        index3d_flush(shape->chunks, chunk_free_func);
        index3d_free(shape->chunks);

        shape->chunks = chunks;
    }

    // update offset
    int3_op_add(&shape->offset, &delta);

    // offset lighting data
    _light_realloc(shape,
                   ax,
                   ay,
                   az,
                   (SHAPE_SIZE_INT_T)delta.x,
                   (SHAPE_SIZE_INT_T)delta.y,
                   (SHAPE_SIZE_INT_T)delta.z);
}

size_t shape_get_nb_blocks(const Shape *shape) {
    return shape->nbBlocks;
}

const Octree *shape_get_octree(const Shape *shape) {
    return shape->octree;
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

void shape_set_color_palette_atlas(Shape *s, ColorAtlas *ca) {
    if (s->palette == NULL) {
        return;
    }
    color_palette_set_atlas(s->palette, ca);
}

// MARK: - Transform -

void shape_set_pivot(Shape *s, const float x, const float y, const float z, bool removeOffset) {
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
            s->pivot = transform_make_with_ptr(HierarchyTransform, s, 0, NULL);
            transform_set_parent(s->pivot, s->transform, false);
        }
    } else if (isZero) {
        // remove unnecessary pivot
        transform_release(s->pivot);
        s->pivot = NULL;
        return;
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
                    s->box->min.x + (float)size.x * 0.5f,
                    s->box->min.y + (float)size.y * 0.5f,
                    s->box->min.z + (float)size.z * 0.5f,
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

    *x += (SHAPE_COORDS_INT_T)s->offset.x;
    *y += (SHAPE_COORDS_INT_T)s->offset.y;
    *z += (SHAPE_COORDS_INT_T)s->offset.z;
}

void shape_block_internal_to_lua(const Shape *s,
                                 SHAPE_COORDS_INT_T *x,
                                 SHAPE_COORDS_INT_T *y,
                                 SHAPE_COORDS_INT_T *z) {
    if (s == NULL || x == NULL || y == NULL || z == NULL)
        return;

    *x -= (SHAPE_COORDS_INT_T)s->offset.x;
    *y -= (SHAPE_COORDS_INT_T)s->offset.y;
    *z -= (SHAPE_COORDS_INT_T)s->offset.z;
}

void shape_block_lua_to_internal_float(const Shape *s, float *x, float *y, float *z) {
    if (s == NULL || x == NULL || y == NULL || z == NULL)
        return;

    *x += (float)s->offset.x;
    *y += (float)s->offset.y;
    *z += (float)s->offset.z;
}

void shape_block_internal_to_lua_float(const Shape *s, float *x, float *y, float *z) {
    if (s == NULL || x == NULL || y == NULL || z == NULL)
        return;

    *x -= (float)s->offset.x;
    *y -= (float)s->offset.y;
    *z -= (float)s->offset.z;
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

void shape_get_chunk_and_position_within(const Shape *shape,
                                         const int3 *pos,
                                         Chunk **chunk,
                                         int3 *chunk_pos,
                                         int3 *pos_in_chunk) {
    static int3 chunk_ldfPos;

    int3_set(&chunk_ldfPos,
             pos->x >> CHUNK_SIZE_SQRT,
             pos->y >> CHUNK_SIZE_SQRT,
             pos->z >> CHUNK_SIZE_SQRT);

    if (chunk_pos != NULL) {
        chunk_pos->x = chunk_ldfPos.x;
        chunk_pos->y = chunk_ldfPos.y;
        chunk_pos->z = chunk_ldfPos.z;
    }

    if (pos_in_chunk != NULL) {
        pos_in_chunk->x = pos->x & CHUNK_SIZE_MINUS_ONE;
        pos_in_chunk->y = pos->y & CHUNK_SIZE_MINUS_ONE;
        pos_in_chunk->z = pos->z & CHUNK_SIZE_MINUS_ONE;
    }

    *chunk = (Chunk *)index3d_get(shape->chunks, chunk_ldfPos.x, chunk_ldfPos.y, chunk_ldfPos.z);
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

void shape_refresh_vertices(Shape *shape) {
    if (shape->isBakeLocked) {
        _shape_fill_draw_slices(shape->firstVB_opaque);
        _shape_fill_draw_slices(shape->firstVB_transparent);
        return;
    }

    Chunk *c = shape->dirtyChunks != NULL ? fifo_list_pop(shape->dirtyChunks) : NULL;
    while (c != NULL) {
        // Note: chunk should never be NULL
        // Note: no need to check chunk_is_dirty, it has to be true

        // if the chunk has been emptied, we can remove it from shape index and destroy it
        // Note: this will create gaps in all the vb used for this chunk ie. make them fragmented
        if (chunk_get_nb_blocks(c) == 0) {
            const SHAPE_COORDS_INT3_T chunkOrigin = chunk_get_origin(c);
            int3 chunk_coords = {chunkOrigin.x >> CHUNK_SIZE_SQRT,
                                 chunkOrigin.y >> CHUNK_SIZE_SQRT,
                                 chunkOrigin.z >> CHUNK_SIZE_SQRT};
            index3d_remove(shape->chunks, chunk_coords.x, chunk_coords.y, chunk_coords.z, NULL);
            rtree_remove(shape->rtree, chunk_get_rtree_leaf(c), false);
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
    Chunk *chunk;
    while (index3d_iterator_pointer(it) != NULL) {
        chunk = index3d_iterator_pointer(it);

        chunk_write_vertices(s, chunk);
        chunk_set_dirty(chunk, false);

        index3d_iterator_next(it);
    }

    // refresh draw slices after full refresh
    _shape_fill_draw_slices(s->firstVB_opaque);
    _shape_fill_draw_slices(s->firstVB_transparent);

    // flush dirty list
    if (s->dirtyChunks != NULL) {
        fifo_list_free(s->dirtyChunks, NULL);
        s->dirtyChunks = NULL;
    }
}

VertexBuffer *shape_get_first_vertex_buffer(const Shape *shape, bool transparent) {
    return transparent ? shape->firstVB_transparent : shape->firstVB_opaque;
}

// MARK: - Physics -

RigidBody *shape_get_rigidbody(const Shape *s) {
    vx_assert(s != NULL);
    vx_assert(s->transform != NULL);
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
        bool collides = false, leaf;
        float3 tmpNormal, tmpReplacement;
        float swept = 1.0f;
        while (n != NULL && collides == false) {
            rtreeHit = (RtreeCastResult *)doubly_linked_list_node_pointer(n);
            c = (Chunk *)rtree_node_get_leaf_ptr(rtreeHit->rtreeLeaf);

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

                collides = box_collide(&tmpBox, &broadPhaseBox);
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

            if (collides && blockCoords != NULL) {
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
        bool collides = false, leaf;
        Block *hitBlock = NULL;
        float minDistance = FLT_MAX;
        uint16_t x, y, z;
        Box tmpBox;
        float d;
        while (n != NULL && collides == false) {
            rtreeHit = (RtreeCastResult *)doubly_linked_list_node_pointer(n);
            c = (Chunk *)rtree_node_get_leaf_ptr(rtreeHit->rtreeLeaf);

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

                collides = ray_intersect_with_box(modelRay, &tmpBox.min, &tmpBox.max, &d) &&
                           d < minDistance;
                if (leaf && collides) {
                    minDistance = d;
                    hitBlock = (Block *)octree_iterator_get_element(oi);
                    octree_iterator_get_current_position(oi, &x, &y, &z);
                }

                octree_iterator_next(oi, collides == false && leaf == false, &leaf);
            }
            octree_iterator_free(oi);

            if (collides) {
                // chunk block coordinates in model space
                x += chunkOrigin.x;
                y += chunkOrigin.y;
                z += chunkOrigin.z;
            }

            n = doubly_linked_list_node_next(n);
        }

        if (hitBlock == NULL) {
            ray_free(modelRay);
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
        return true;
    }
    doubly_linked_list_flush(chunksQuery, free);
    doubly_linked_list_free(chunksQuery);

    return false;
}

bool shape_point_overlap(const Shape *s, const float3 *world) {
    Transform *t = shape_get_pivot_transform(s); // octree coordinates use model origin
    float3 model;
    transform_utils_position_wtl(t, world, &model);

    int3 chunk_coords = {
        (int)model.x / CHUNK_SIZE,
        (int)model.y / CHUNK_SIZE,
        (int)model.z / CHUNK_SIZE,
    };

    Chunk *c = index3d_get(s->chunks, chunk_coords.x, chunk_coords.y, chunk_coords.z);
    if (c != NULL) {
        Block *b = (Block *)octree_get_element_without_checking(chunk_get_octree(c),
                                                                (size_t)model.x,
                                                                (size_t)model.y,
                                                                (size_t)model.z);

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
    if (rtree_query_overlap_box(s->rtree, modelBox, 0, 1, chunksQuery, EPSILON_COLLISION) > 0) {

        // examine query results, stop at first overlap
        RtreeNode *hit = fifo_list_pop(chunksQuery);
        OctreeIterator *oi;
        bool collides = false;
        bool leaf;
        Chunk *c;
        Box tmpBox;
        while (hit != NULL && collides == false) {
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

                collides = box_collide(modelBox, &tmpBox);
                if (leaf && collides) {
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
    fifo_list_free(chunksQuery, free);

    return false;
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
    s->innerTransparentFaces = toggle;
}

bool shape_draw_inner_transparent_faces(const Shape *s) {
    if (s == NULL) {
        return false;
    }
    return s->innerTransparentFaces;
}

void shape_set_shadow(Shape *s, const bool toggle) {
    if (s == NULL) {
        return;
    }
    s->shadow = toggle;
}

bool shape_has_shadow(const Shape *s) {
    if (s == NULL) {
        return false;
    }
    return s->shadow;
}

void shape_set_unlit(Shape *s, const bool value) {
    s->isUnlit = value;
}

bool shape_is_unlit(const Shape *s) {
    return s->isUnlit;
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

void shape_compute_baked_lighting(Shape *s, bool overwrite) {
    if (_has_allocated_size(s) == false) {
#if SHAPE_LIGHTING_DEBUG
        cclog_debug("🔥 shape_compute_baked_lighting: no allocated size");
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

    const size_t lightingSize = (size_t)s->maxWidth * (size_t)s->maxHeight * (size_t)s->maxDepth *
                                (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
    if (s->lightingData == NULL) {
        s->lightingData = (VERTEX_LIGHT_STRUCT_T *)malloc(lightingSize);
        _shape_flush_all_vb(s); // let VBs be realloc w/ lighting buffers
    }
    memset(s->lightingData, 0, lightingSize);

    LightNodeQueue *q = light_node_queue_new();

    const SHAPE_COORDS_INT3_T to = {(SHAPE_COORDS_INT_T)s->maxWidth,
                                    (SHAPE_COORDS_INT_T)s->maxHeight,
                                    (SHAPE_COORDS_INT_T)s->maxDepth};
    _light_enqueue_ambient_and_block_sources(s, q, coords3_zero, to, false);

    _light_propagate(s, NULL, NULL, q, -1, (SHAPE_COORDS_INT_T)s->maxHeight, -1);

    light_node_queue_free(q);

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("Shape light computed");
#endif
}

bool shape_has_baked_lighting_data(const Shape *s) {
    return s->lightingData != NULL;
}

const VERTEX_LIGHT_STRUCT_T *shape_get_lighting_data(const Shape *s) {
    return s->lightingData;
}

void shape_set_lighting_data(Shape *s, VERTEX_LIGHT_STRUCT_T *d) {
    if (s->lightingData != NULL) {
        free(s->lightingData);
        if (d == NULL) {
            _shape_flush_all_vb(s); // let VBs be realloc w/o lighting buffers
        }
    } else if (d != NULL) {
        _shape_flush_all_vb(s); // let VBs be realloc w/ lighting buffers
    }
    s->lightingData = d;
}

VERTEX_LIGHT_STRUCT_T shape_get_light_without_checking(const Shape *s,
                                                       SHAPE_COORDS_INT_T x,
                                                       SHAPE_COORDS_INT_T y,
                                                       SHAPE_COORDS_INT_T z) {
    return s->lightingData[x * s->maxHeight * s->maxDepth + y * s->maxDepth + z];
}

void shape_set_light(Shape *s,
                     SHAPE_COORDS_INT_T x,
                     SHAPE_COORDS_INT_T y,
                     SHAPE_COORDS_INT_T z,
                     VERTEX_LIGHT_STRUCT_T light) {
    if (x >= 0 && x < s->maxWidth && y >= 0 && y < s->maxHeight && z >= 0 && z < s->maxDepth) {
        s->lightingData[x * s->maxHeight * s->maxDepth + y * s->maxDepth + z] = light;
    }
}

VERTEX_LIGHT_STRUCT_T shape_get_light_or_default(Shape *s,
                                                 SHAPE_COORDS_INT_T x,
                                                 SHAPE_COORDS_INT_T y,
                                                 SHAPE_COORDS_INT_T z,
                                                 bool isDefault) {
    if (isDefault || s->lightingData == NULL ||
        shape_is_within_allocated_bounds(s, x, y, z) == false) {
        VERTEX_LIGHT_STRUCT_T light;
        DEFAULT_LIGHT(light)
        return light;
    } else {
        return shape_get_light_without_checking(s, x, y, z);
    }
}

void shape_compute_baked_lighting_removed_block(Shape *s,
                                                SHAPE_COORDS_INT_T x,
                                                SHAPE_COORDS_INT_T y,
                                                SHAPE_COORDS_INT_T z,
                                                SHAPE_COLOR_INDEX_INT_T blockID) {
    if (s == NULL) {
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

    SHAPE_COORDS_INT3_T coords;
    LightNodeQueue *lightQueue = light_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    SHAPE_COORDS_INT3_T min, max;
    min.x = max.x = x;
    min.y = max.y = y;
    min.z = max.z = z;

    // get existing values
    VERTEX_LIGHT_STRUCT_T existingLight = shape_get_light_without_checking(s, x, y, z);

    // if self is emissive, start light removal
    if (existingLight.red > 0 || existingLight.green > 0 || existingLight.blue > 0) {
        LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

        coords.x = x;
        coords.y = y;
        coords.z = z;
        light_removal_node_queue_push(lightRemovalQueue, &coords, existingLight, 15, blockID);

        // run light removal
        _light_removal(s, &min, &max, lightRemovalQueue, lightQueue);

        light_removal_node_queue_free(lightRemovalQueue);
    }

    // add all neighbors to light propagation queue
    {
        // x + 1
        coords.x = x + 1;
        coords.y = y;
        coords.z = z;
        light_node_queue_push(lightQueue, &coords);

        // x - 1
        coords.x = x - 1;
        coords.y = y;
        coords.z = z;
        light_node_queue_push(lightQueue, &coords);

        // y + 1
        coords.x = x;
        coords.y = y + 1;
        coords.z = z;
        light_node_queue_push(lightQueue, &coords);

        // y - 1
        coords.x = x;
        coords.y = y - 1;
        coords.z = z;
        light_node_queue_push(lightQueue, &coords);

        // z + 1
        coords.x = x;
        coords.y = y;
        coords.z = z + 1;
        light_node_queue_push(lightQueue, &coords);

        // z - 1
        coords.x = x;
        coords.y = y;
        coords.z = z - 1;
        light_node_queue_push(lightQueue, &coords);
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
                                              SHAPE_COORDS_INT_T x,
                                              SHAPE_COORDS_INT_T y,
                                              SHAPE_COORDS_INT_T z,
                                              SHAPE_COLOR_INDEX_INT_T blockID) {

    if (s == NULL) {
        return;
    }

    if (s->lightingData == NULL) {
        cclog_error("🔥 shape_compute_baked_lighting_added_block: shape doesn't have lighting data");
        return;
    }

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️☀️☀️ compute light for added block (%d, %d, %d)", x, y, z);
#endif

    SHAPE_COORDS_INT3_T coords;
    LightNodeQueue *lightQueue = light_node_queue_new();
    LightRemovalNodeQueue *lightRemovalQueue = light_removal_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    SHAPE_COORDS_INT3_T min, max;
    min.x = max.x = x;
    min.y = max.y = y;
    min.z = max.z = z;

    coords.x = x;
    coords.y = y;
    coords.z = z;

    // get existing and new light values
    VERTEX_LIGHT_STRUCT_T existingLight = shape_get_light_without_checking(s, x, y, z);
    VERTEX_LIGHT_STRUCT_T newLight = color_palette_get_emissive_color_as_light(s->palette, blockID);

    // if emissive, add it to the light propagation queue & store original emission of the block
    // note: we do this since palette may have been changed when running light removal at a later
    // point
    if (newLight.red > 0 || newLight.green > 0 || newLight.blue > 0) {
        light_node_queue_push(lightQueue, &coords);
        shape_set_light(s, x, y, z, newLight);
    }

    // start light removal from current position as an air block w/ existingLight
    light_removal_node_queue_push(lightRemovalQueue, &coords, existingLight, 15, 255);

    // check in the vicinity for any emissive block that would be affected by the added block
    const Block *block = NULL;
    VERTEX_LIGHT_STRUCT_T light;
    for (SHAPE_COORDS_INT_T xo = -1; xo <= 1; xo++) {
        for (SHAPE_COORDS_INT_T yo = -1; yo <= 1; yo++) {
            for (SHAPE_COORDS_INT_T zo = -1; zo <= 1; zo++) {
                if (xo == 0 && yo == 0 && zo == 0) {
                    continue;
                }

                coords.x = x + xo;
                coords.y = y + yo;
                coords.z = z + zo;

                block = shape_get_block(s, coords.x, coords.y, coords.z, false);
                if (block != NULL && color_palette_is_emissive(s->palette, block->colorIndex)) {
                    light = color_palette_get_emissive_color_as_light(s->palette,
                                                                      block->colorIndex);

                    light_removal_node_queue_push(lightRemovalQueue,
                                                  &coords,
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

    SHAPE_COORDS_INT3_T i3;
    LightNodeQueue *lightQueue = light_node_queue_new();

    // changed values bounding box need to include both removed and added lights
    SHAPE_COORDS_INT3_T min, max;
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

uint64_t shape_get_baked_lighting_hash(const Shape *s) {
    if (s == NULL || s->octree == NULL || s->palette == NULL) {
        return 0;
    }
    return octree_get_hash(s->octree, (uint64_t)color_palette_get_lighting_hash(s->palette));
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

// MARK: - Lua flags -

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

// MARK: - private functions -

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

void _shape_chunk_check_neighbors_dirty(Shape *shape, const Chunk *chunk, const int3 *block_pos) {
    // Only neighbors sharing faces need to have their mesh set dirty
    // Not refreshing diagonal chunks will only affect AO on that corner, not essential
    // TODO: enable diagonal refresh once chunks slice refresh is implemented

    if (block_pos->x == 0) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, NX));
    } else if (block_pos->x == CHUNK_SIZE_MINUS_ONE) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, X));
    }

    if (block_pos->y == 0) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, NY));
    } else if (block_pos->y == CHUNK_SIZE_MINUS_ONE) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, Y));
    }

    if (block_pos->z == 0) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, NZ));
    } else if (block_pos->z == CHUNK_SIZE_MINUS_ONE) {
        _shape_chunk_enqueue_refresh(shape, chunk_get_neighbor(chunk, Z));
    }
}

static bool _shape_add_block(Shape *shape,
                             const Block block,
                             SHAPE_COORDS_INT_T x,
                             SHAPE_COORDS_INT_T y,
                             SHAPE_COORDS_INT_T z) {

    if (_is_out_of_maximum_shape_size(x, y, z)) {
        return false;
    }

    // make sure block is added within fixed boundaries
    if (_has_allocated_size(shape) && _is_out_of_allocated_size(shape, x, y, z)) {
        cclog_error("⚠️ trying to add block outside shape's allocated boundaries| %p %d %d %d",
                    shape,
                    x,
                    y,
                    z);
        cclog_error("shape allocated size: %d | %d %d %d",
                    _has_allocated_size(shape),
                    shape->maxWidth,
                    shape->maxHeight,
                    shape->maxDepth);
        return false;
    }

    int3 block_coords;
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
        _shape_chunk_check_neighbors_dirty(shape, chunk, &block_coords);

        shape_expand_box(shape, x, y, z);
    }

    return blockAdded;
}

bool _shape_add_block_in_chunks(Shape *shape,
                                const Block block,
                                const SHAPE_COORDS_INT_T x,
                                const SHAPE_COORDS_INT_T y,
                                const SHAPE_COORDS_INT_T z,
                                int3 *block_coords_out,
                                bool *chunkAdded,
                                Chunk **added_or_existing_chunk,
                                Block **added_or_existing_block) {

    int3 chunk_coords;
    int3 block_coords;

    // see if there's a chunk ready for that block
    int3_set(&chunk_coords, x >> CHUNK_SIZE_SQRT, y >> CHUNK_SIZE_SQRT, z >> CHUNK_SIZE_SQRT);
    Chunk *chunk = (Chunk *)
        index3d_get(shape->chunks, chunk_coords.x, chunk_coords.y, chunk_coords.z);

    // insert new chunk if needed
    if (chunk == NULL) {
        SHAPE_COORDS_INT3_T chunkOrigin = {(SHAPE_COORDS_INT_T)chunk_coords.x * CHUNK_SIZE,
                                           (SHAPE_COORDS_INT_T)chunk_coords.y * CHUNK_SIZE,
                                           (SHAPE_COORDS_INT_T)chunk_coords.z * CHUNK_SIZE};
        chunk = chunk_new(chunkOrigin.x, chunkOrigin.y, chunkOrigin.z);

        index3d_insert(shape->chunks, chunk, chunk_coords.x, chunk_coords.y, chunk_coords.z, NULL);
        chunk_move_in_neighborhood(shape->chunks, chunk, &chunk_coords);

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

    int3_set(&block_coords,
             x & CHUNK_SIZE_MINUS_ONE,
             y & CHUNK_SIZE_MINUS_ONE,
             z & CHUNK_SIZE_MINUS_ONE);

    if (block_coords_out != NULL) {
        int3_set(block_coords_out, block_coords.x, block_coords.y, block_coords.z);
    }

    bool added = chunk_add_block(chunk,
                                 block,
                                 (CHUNK_COORDS_INT_T)block_coords.x,
                                 (CHUNK_COORDS_INT_T)block_coords.y,
                                 (CHUNK_COORDS_INT_T)block_coords.z);

    if (added_or_existing_block != NULL) {
        *added_or_existing_block = chunk_get_block_2(chunk, &block_coords);
    }

    return added;
}

bool _has_allocated_size(const Shape *s) {
    return s->maxWidth > 0;
}

bool _is_out_of_allocated_size(const Shape *s,
                               const SHAPE_COORDS_INT_T x,
                               const SHAPE_COORDS_INT_T y,
                               const SHAPE_COORDS_INT_T z) {
    return x < 0 || y < 0 || z < 0 || x >= s->maxWidth || y >= s->maxHeight || z >= s->maxDepth;
}

bool _is_out_of_maximum_shape_size(const SHAPE_COORDS_INT_T x,
                                   const SHAPE_COORDS_INT_T y,
                                   const SHAPE_COORDS_INT_T z) {
    return x < 0 || y < 0 || z < 0 || x >= SHAPE_OCTREE_MAX || y >= SHAPE_OCTREE_MAX ||
           z >= SHAPE_OCTREE_MAX;
}

Octree *_new_octree(const SHAPE_COORDS_INT_T w,
                    const SHAPE_COORDS_INT_T h,
                    const SHAPE_COORDS_INT_T d) {
    // enforcing power of 2 for the octree
    uint16_t size = (uint16_t)(maximum(maximum(w, h), d));
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

    block_free(air);

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

void _lighting_set_dirty(SHAPE_COORDS_INT3_T *bbMin,
                         SHAPE_COORDS_INT3_T *bbMax,
                         SHAPE_COORDS_INT_T x,
                         SHAPE_COORDS_INT_T y,
                         SHAPE_COORDS_INT_T z) {
    if (vertex_buffer_get_lighting_enabled()) {
        bbMin->x = minimum(bbMin->x, x);
        bbMin->y = minimum(bbMin->y, y);
        bbMin->z = minimum(bbMin->z, z);
        bbMax->x = maximum(bbMax->x, x);
        bbMax->y = maximum(bbMax->y, y);
        bbMax->z = maximum(bbMax->z, z);
    }
}

void _lighting_postprocess_dirty(Shape *s, SHAPE_COORDS_INT3_T *bbMin, SHAPE_COORDS_INT3_T *bbMax) {
    if (vertex_buffer_get_lighting_enabled()) {
        SHAPE_COORDS_INT3_T chunkMin = *bbMin, chunkMax = *bbMax;

        // account for vertex lighting smoothing, values need to be updated on adjacent vertices
        chunkMin.x -= 1;
        chunkMin.y -= 1;
        chunkMin.z -= 1;
        chunkMax.x += 1;
        chunkMax.y += 1;
        chunkMax.z += 1;

        // find corresponding chunks and set dirty
        chunkMin.x /= CHUNK_SIZE;
        chunkMax.x /= CHUNK_SIZE;
        chunkMin.y /= CHUNK_SIZE;
        chunkMax.y /= CHUNK_SIZE;
        chunkMin.z /= CHUNK_SIZE;
        chunkMax.z /= CHUNK_SIZE;

        Chunk *chunk;
        for (int x = chunkMin.x; x <= chunkMax.x; x++) {
            for (int y = chunkMin.y; y <= chunkMax.y; y++) {
                for (int z = chunkMin.z; z <= chunkMax.z; z++) {
                    chunk = (Chunk *)index3d_get(s->chunks, x, y, z);
                    if (chunk != NULL) {
                        _shape_chunk_enqueue_refresh(s, chunk);
                    }
                }
            }
        }
    }
}

void _light_removal_processNeighbor(Shape *s,
                                    SHAPE_COORDS_INT3_T *bbMin,
                                    SHAPE_COORDS_INT3_T *bbMax,
                                    VERTEX_LIGHT_STRUCT_T light,
                                    uint8_t srgb,
                                    bool equals,
                                    SHAPE_COORDS_INT3_T *neighborPos,
                                    const Block *neighbor,
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
            _lighting_set_dirty(bbMin, bbMax, neighborPos->x, neighborPos->y, neighborPos->z);

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

void _light_set_and_enqueue_source(SHAPE_COORDS_INT3_T *pos,
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

void _light_enqueue_ambient_and_block_sources(Shape *s,
                                              LightNodeQueue *q,
                                              SHAPE_COORDS_INT3_T from,
                                              SHAPE_COORDS_INT3_T to,
                                              bool enqueueAir) {
    // Ambient sources: blocks along plane (x,z) from top of the map
    SHAPE_COORDS_INT3_T pos = {0, (SHAPE_COORDS_INT_T)s->maxHeight, 0};
    for (SHAPE_COORDS_INT_T x = from.x - 1; x <= to.x; ++x) {
        for (SHAPE_COORDS_INT_T z = from.z - 1; z <= to.z; ++z) {
            pos.x = x;
            pos.z = z;
            light_node_queue_push(q, &pos);
        }
    }

    // Block sources: enqueue all emissive blocks (and air if requested) around the given area
    const Block *b;
    for (SHAPE_COORDS_INT_T x = from.x - 1; x <= to.x; ++x) {
        for (SHAPE_COORDS_INT_T y = from.y - 1; y <= to.y; ++y) {
            for (SHAPE_COORDS_INT_T z = from.z - 1; z <= to.z; ++z) {
                b = shape_get_block(s, x, y, z, false);
                if (b != NULL) {
                    if (color_palette_is_emissive(s->palette, b->colorIndex)) {
                        pos.x = x;
                        pos.y = y;
                        pos.z = z;
                        light_node_queue_push(q, &pos);
                    } else if (block_is_solid(b) == false && enqueueAir) {
                        const VERTEX_LIGHT_STRUCT_T light = shape_get_light_without_checking(s,
                                                                                             x,
                                                                                             y,
                                                                                             z);
                        if (light.blue > 0 || light.green > 0 || light.red > 0) {
                            pos.x = x;
                            pos.y = y;
                            pos.z = z;
                            light_node_queue_push(q, &pos);
                        }
                    }
                }
            }
        }
    }
}

void _light_block_propagate(Shape *s,
                            SHAPE_COORDS_INT3_T *bbMin,
                            SHAPE_COORDS_INT3_T *bbMax,
                            VERTEX_LIGHT_STRUCT_T current,
                            SHAPE_COORDS_INT3_T *neighborPos,
                            const Block *neighbor,
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
            current.red = TO_UINT4((uint8_t)((float)current.red * absorbRGB));
            current.green = TO_UINT4((uint8_t)((float)current.green * absorbRGB));
            current.blue = TO_UINT4((uint8_t)((float)current.blue * absorbRGB));
            current.ambient = TO_UINT4((uint8_t)((float)current.ambient * absorbS));
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
            shape_set_light(s, neighborPos->x, neighborPos->y, neighborPos->z, neighborLight);

            light_node_queue_push(lightQueue, neighborPos);
            _lighting_set_dirty(bbMin, bbMax, neighborPos->x, neighborPos->y, neighborPos->z);
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
                      SHAPE_COORDS_INT3_T *bbMin,
                      SHAPE_COORDS_INT3_T *bbMax,
                      LightNodeQueue *lightQueue,
                      SHAPE_COORDS_INT_T srcX,
                      SHAPE_COORDS_INT_T srcY,
                      SHAPE_COORDS_INT_T srcZ) {

#if SHAPE_LIGHTING_DEBUG
    cclog_debug("☀️ light propagation started...");
#endif

    // changed values bounding box initialized at source position or using given bounding box
    SHAPE_COORDS_INT3_T min, max;
    if (bbMin == NULL) {
        min = (SHAPE_COORDS_INT3_T){srcX, srcY, srcZ};
    } else {
        min = *bbMin;
    }
    if (bbMax == NULL) {
        max = (SHAPE_COORDS_INT3_T){srcX, srcY, srcZ};
    } else {
        max = *bbMax;
    }

    // set source block dirty
    _lighting_set_dirty(&min, &max, srcX, srcY, srcZ);

    SHAPE_COORDS_INT3_T pos, insertPos;
    const Block *current = NULL;
    const Block *neighbor = NULL;
    VERTEX_LIGHT_STRUCT_T currentLight;
    bool isCurrentAir, isCurrentOpen, isCurrentTransparent, isNeighborAir, isNeighborTransparent;
    LightNode *n = light_node_queue_pop(lightQueue);
    while (n != NULL) {
        light_node_get_coords(n, &pos);

        // get current light
        if (_is_out_of_allocated_size(s, pos.x, pos.y, pos.z)) {
            DEFAULT_LIGHT(currentLight)
            isCurrentAir = true;
            isCurrentTransparent = false;
        } else {
            current = shape_get_block(s, pos.x, pos.y, pos.z, false);
            if (current == NULL) {
                cclog_error("🔥 no element found at index");
                light_node_queue_recycle(n);
                n = light_node_queue_pop(lightQueue);
                continue;
            }

            currentLight = shape_get_light_without_checking(s, pos.x, pos.y, pos.z);
            isCurrentAir = current->colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK;
            isCurrentTransparent = color_palette_is_transparent(s->palette, current->colorIndex);
        }
        isCurrentOpen = false; // is current node open ie. at least one neighbor is non-opaque

        // propagate sunlight top-down from above the map and on the sides
        // note: test this first and individually, because the octree has a POT size ie. most likely
        // higher than fixed width & depth and will return an air block by default to stop
        // propagation
        if (pos.y > 0 && pos.y <= s->maxHeight &&
            (pos.x == -1 || pos.z == -1 || pos.x == s->maxWidth || pos.z == s->maxDepth)) {
            insertPos.x = pos.x;
            insertPos.y = pos.y - 1;
            insertPos.z = pos.z;
            light_node_queue_push(lightQueue, &insertPos);
        }

        // for each non-opaque neighbor: flag current node as open & propagate light if current
        // non-opaque
        // for each emissive neighbor: add to light queue if current non-opaque
        // y - 1
        neighbor = shape_get_block(s, pos.x, pos.y - 1, pos.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = pos.x;
                insertPos.y = pos.y - 1;
                insertPos.z = pos.z;

                // sunlight propagates infinitely vertically (step = 0)
                _light_block_propagate(s,
                                       &min,
                                       &max,
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
        neighbor = shape_get_block(s, pos.x, pos.y + 1, pos.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = pos.x;
                insertPos.y = pos.y + 1;
                insertPos.z = pos.z;

                _light_block_propagate(s,
                                       &min,
                                       &max,
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
        neighbor = shape_get_block(s, pos.x + 1, pos.y, pos.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = pos.x + 1;
                insertPos.y = pos.y;
                insertPos.z = pos.z;

                _light_block_propagate(s,
                                       &min,
                                       &max,
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
        neighbor = shape_get_block(s, pos.x - 1, pos.y, pos.z, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = pos.x - 1;
                insertPos.y = pos.y;
                insertPos.z = pos.z;

                _light_block_propagate(s,
                                       &min,
                                       &max,
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
        neighbor = shape_get_block(s, pos.x, pos.y, pos.z + 1, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = pos.x;
                insertPos.y = pos.y;
                insertPos.z = pos.z + 1;

                _light_block_propagate(s,
                                       &min,
                                       &max,
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
        neighbor = shape_get_block(s, pos.x, pos.y, pos.z - 1, false);
        if (neighbor != NULL) {
            isNeighborAir = neighbor->colorIndex == 255;
            isNeighborTransparent = color_palette_is_transparent(s->palette, neighbor->colorIndex);

            if (isNeighborAir || isNeighborTransparent) {
                isCurrentOpen = true;
            }

            if (isCurrentAir || isCurrentTransparent) {
                insertPos.x = pos.x;
                insertPos.y = pos.y;
                insertPos.z = pos.z - 1;

                _light_block_propagate(s,
                                       &min,
                                       &max,
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
            for (SHAPE_COORDS_INT_T xo = -1; xo <= 1; xo++) {
                for (SHAPE_COORDS_INT_T yo = -1; yo <= 1; yo++) {
                    for (SHAPE_COORDS_INT_T zo = -1; zo <= 1; zo++) {
                        insertPos.x = pos.x + xo;
                        insertPos.y = pos.y + yo;
                        insertPos.z = pos.z + zo;

                        if (shape_is_within_allocated_bounds(s,
                                                             insertPos.x,
                                                             insertPos.y,
                                                             insertPos.z)) {
                            neighbor = shape_get_block(s,
                                                       insertPos.x,
                                                       insertPos.y,
                                                       insertPos.z,
                                                       false);
                            if (block_is_opaque(neighbor, s->palette) == false) {
                                _light_set_and_enqueue_source(&insertPos,
                                                              s,
                                                              currentLight,
                                                              lightQueue);
                            }
                        }
                    }
                }
            }
        }

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
#endif

    VERTEX_LIGHT_STRUCT_T light;
    uint8_t srgb;
    SHAPE_COLOR_INDEX_INT_T blockID;
    const Block *neighbor = NULL;

    SHAPE_COORDS_INT3_T pos, insertPos;
    LightRemovalNode *rn = light_removal_node_queue_pop(lightRemovalQueue);
    while (rn != NULL) {
        // get coords and light value of the light removal node (rn)
        light_removal_node_get_coords(rn, &pos);
        light_removal_node_get_light(rn, &light);
        srgb = light_removal_node_get_srgb(rn);
        blockID = light_removal_node_get_block_id(rn);

        // check that the current block is inside the shape bounds
        if (shape_is_within_allocated_bounds(s, pos.x, pos.y, pos.z)) {

            // if air or transparent block, proceed with light removal
            if (blockID == SHAPE_COLOR_INDEX_AIR_BLOCK ||
                color_palette_is_transparent(s->palette, blockID)) {
                // x + 1
                neighbor = shape_get_block(s, pos.x + 1, pos.y, pos.z, false);
                if (neighbor != NULL) {
                    insertPos.x = pos.x + 1;
                    insertPos.y = pos.y;
                    insertPos.z = pos.z;

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
                neighbor = shape_get_block(s, pos.x - 1, pos.y, pos.z, false);
                if (neighbor != NULL) {
                    insertPos.x = pos.x - 1;
                    insertPos.y = pos.y;
                    insertPos.z = pos.z;

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
                neighbor = shape_get_block(s, pos.x, pos.y + 1, pos.z, false);
                if (neighbor != NULL) {
                    insertPos.x = pos.x;
                    insertPos.y = pos.y + 1;
                    insertPos.z = pos.z;

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
                neighbor = shape_get_block(s, pos.x, pos.y - 1, pos.z, false);
                if (neighbor != NULL) {
                    insertPos.x = pos.x;
                    insertPos.y = pos.y - 1;
                    insertPos.z = pos.z;

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
                neighbor = shape_get_block(s, pos.x, pos.y, pos.z + 1, false);
                if (neighbor != NULL) {
                    insertPos.x = pos.x;
                    insertPos.y = pos.y;
                    insertPos.z = pos.z + 1;

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
                neighbor = shape_get_block(s, pos.x, pos.y, pos.z - 1, false);
                if (neighbor != NULL) {
                    insertPos.x = pos.x;
                    insertPos.y = pos.y;
                    insertPos.z = pos.z - 1;

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
                for (SHAPE_COORDS_INT_T xo = -1; xo <= 1; ++xo) {
                    for (SHAPE_COORDS_INT_T yo = -1; yo <= 1; ++yo) {
                        for (SHAPE_COORDS_INT_T zo = -1; zo <= 1; ++zo) {
                            if (xo == 0 && yo == 0 && zo == 0) {
                                continue;
                            }

                            insertPos.x = pos.x + xo;
                            insertPos.y = pos.y + yo;
                            insertPos.z = pos.z + zo;

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

    // skip if this shape cannot use baked light, or if it is not computed yet
    if (_has_allocated_size(s) == false || s->lightingData == NULL)
        return;

    // - keep existing data, copy it and apply offset
    // - set newly allocated lighting data to 0
    // - propagate from ambient & light blocks sources located on each side where new space was
    // appended

    const size_t lightingSize = (size_t)s->maxWidth * (size_t)s->maxHeight * (size_t)s->maxDepth *
                                (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
    VERTEX_LIGHT_STRUCT_T *lightingData = (VERTEX_LIGHT_STRUCT_T *)malloc(lightingSize);
    if (lightingData == NULL) {
        return;
    }
    const SHAPE_SIZE_INT_T srcWidth = s->maxWidth - dx;
    const SHAPE_SIZE_INT_T srcHeight = s->maxHeight - dy;
    const SHAPE_SIZE_INT_T srcDepth = s->maxDepth - dz;
    const size_t srcSlicePitch = srcHeight * srcDepth;
    const size_t dstSlicePitch = s->maxHeight * s->maxDepth;

    const size_t offsetZSize = offsetZ * sizeof(VERTEX_LIGHT_STRUCT_T);
    const size_t srcDepthSize = srcDepth * sizeof(VERTEX_LIGHT_STRUCT_T);
    const size_t dstDepthSize = s->maxDepth * sizeof(VERTEX_LIGHT_STRUCT_T);
    const size_t reminderSize = (dz - offsetZ) * sizeof(VERTEX_LIGHT_STRUCT_T);

    // set to 0 empty slice of data at the beginning (from offsetX)
    if (offsetX > 0) {
        memset(lightingData, 0, offsetX * dstSlicePitch * sizeof(VERTEX_LIGHT_STRUCT_T));
    }

    SHAPE_SIZE_INT_T ox, oy;
    for (SHAPE_SIZE_INT_T xx = 0; xx < s->maxWidth; ++xx) {

        // set to 0 empty row of data at the beginning (from offsetY)
        if (offsetY > 0) {
            memset(lightingData + xx * dstSlicePitch,
                   0,
                   offsetY * s->maxDepth * sizeof(VERTEX_LIGHT_STRUCT_T));
        }

        for (SHAPE_SIZE_INT_T yy = 0; yy < s->maxHeight; ++yy) {
            ox = xx + offsetX;
            oy = yy + offsetY;

            if (xx < srcWidth && yy < srcHeight) {
                // set to 0 empty data at the beginning (from offsetZ)
                if (offsetZ > 0) {
                    memset(lightingData + ox * dstSlicePitch + oy * s->maxDepth, 0, offsetZSize);
                }

                // copy existing row data
                memcpy(lightingData + ox * dstSlicePitch + oy * s->maxDepth + offsetZ,
                       s->lightingData + xx * srcSlicePitch + yy * srcDepth,
                       srcDepthSize);

                // set reminder to 0
                if (dz > offsetZ) {
                    memset(lightingData + ox * dstSlicePitch + oy * s->maxDepth + offsetZ +
                               srcDepth,
                           0,
                           reminderSize);
                }
            } else {
                // set new row to 0
                memset(lightingData + xx * dstSlicePitch + yy * s->maxDepth, 0, dstDepthSize);
            }
        }
    }

    free(s->lightingData);
    s->lightingData = lightingData;

    LightNodeQueue *q = light_node_queue_new();

    // enqueue ambient & light block & air sources within range, on each side w/ newly empty data
    if (offsetX > 0) {
        const SHAPE_COORDS_INT3_T to = {(SHAPE_COORDS_INT_T)offsetX,
                                        (SHAPE_COORDS_INT_T)s->maxHeight,
                                        (SHAPE_COORDS_INT_T)s->maxDepth};
        _light_enqueue_ambient_and_block_sources(s, q, coords3_zero, to, true);
    }
    if (offsetY > 0) {
        const SHAPE_COORDS_INT3_T to = {(SHAPE_COORDS_INT_T)s->maxWidth,
                                        (SHAPE_COORDS_INT_T)offsetY,
                                        (SHAPE_COORDS_INT_T)s->maxDepth};
        _light_enqueue_ambient_and_block_sources(s, q, coords3_zero, to, true);
    }
    if (offsetZ > 0) {
        const SHAPE_COORDS_INT3_T to = {(SHAPE_COORDS_INT_T)s->maxWidth,
                                        (SHAPE_COORDS_INT_T)s->maxHeight,
                                        (SHAPE_COORDS_INT_T)offsetZ};
        _light_enqueue_ambient_and_block_sources(s, q, coords3_zero, to, true);
    }
    const SHAPE_COORDS_INT3_T max = {(SHAPE_COORDS_INT_T)s->maxWidth,
                                     (SHAPE_COORDS_INT_T)s->maxHeight,
                                     (SHAPE_COORDS_INT_T)s->maxDepth};
    // note: dx and not reminder (dx - offsetX), to include empty data previously inside model then
    // offseted
    if (dx > 0) {
        const SHAPE_COORDS_INT3_T from = {(SHAPE_COORDS_INT_T)(s->maxWidth - dx), 0, 0};
        _light_enqueue_ambient_and_block_sources(s, q, from, max, true);
    }
    if (dy > 0) {
        const SHAPE_COORDS_INT3_T from = {0, (SHAPE_COORDS_INT_T)(s->maxHeight - dy), 0};
        _light_enqueue_ambient_and_block_sources(s, q, from, max, true);
    }
    if (dz > 0) {
        const SHAPE_COORDS_INT3_T from = {0, 0, (SHAPE_COORDS_INT_T)(s->maxDepth - dz)};
        _light_enqueue_ambient_and_block_sources(s, q, from, max, true);
    }

    _light_propagate(s, NULL, NULL, q, -1, (SHAPE_COORDS_INT_T)s->maxHeight, -1);

    light_node_queue_free(q);

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

void _shape_flush_all_vb(Shape *s) {
    // unbind all chunks from current vertex buffers and set them dirty
    Index3DIterator *it = index3d_iterator_new(s->chunks);
    Chunk *c;
    while (index3d_iterator_pointer(it) != NULL) {
        c = index3d_iterator_pointer(it);

        chunk_set_vbma(c, NULL, false);
        chunk_set_vbma(c, NULL, true);
        _shape_chunk_enqueue_refresh(s, c);

        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    // free all vertex buffers
    vertex_buffer_free_all(s->firstVB_opaque);
    s->firstVB_opaque = NULL;
    s->lastVB_opaque = NULL;
    vertex_buffer_free_all(s->firstVB_transparent);
    s->firstVB_transparent = NULL;
    s->lastVB_transparent = NULL;
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
        b = shape_get_block_immediate(sh, x, y, z, true);
        before = b != NULL ? b->colorIndex : SHAPE_COLOR_INDEX_AIR_BLOCK;
        blockChange_set_previous_color(bc, before);

        after = blockChange_getBlock(bc)->colorIndex;

        // [air>block] = add block
        if (before == SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_add_block_with_color(sh, after, x, y, z, false, true, false);
        }
        // [block>air] = remove block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after == SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_remove_block(sh, x, y, z, NULL, true, false);
            shapeShrinkNeeded = true;
        }
        // [block>block] = paint block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK &&
                 before != after) {
            shape_paint_block(sh, after, x, y, z, NULL, NULL, true);
        }

        index3d_iterator_next(it);
    }

    if (shapeShrinkNeeded == true) {
        shape_shrink_box(sh, true);
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
    BlockChange *bc;
    const Block *b;
    while (index3d_iterator_pointer(it) != NULL) {
        bc = (BlockChange *)index3d_iterator_pointer(it);

        blockChange_getXYZ(bc, &x, &y, &z);

        b = shape_get_block_immediate(sh, x, y, z, true);
        before = b != NULL ? b->colorIndex : SHAPE_COLOR_INDEX_AIR_BLOCK;

        after = blockChange_get_previous_color(bc);

        // [air>block] = add block
        if (before == SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_add_block_with_color(sh, after, x, y, z, false, true, false);
        }
        // [block>air] = remove block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after == SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_remove_block(sh, x, y, z, NULL, true, false);
            shapeShrinkNeeded = true;
        }
        // [block>block] = paint block
        else if (before != SHAPE_COLOR_INDEX_AIR_BLOCK && after != SHAPE_COLOR_INDEX_AIR_BLOCK) {
            shape_paint_block(sh, after, x, y, z, NULL, NULL, true);
        }

        index3d_iterator_next(it);
    }

    if (shapeShrinkNeeded == true) {
        shape_shrink_box(sh, true);
    }

    return true;
}

void _shape_clear_cached_world_aabb(Shape *s) {
    if (s->worldAABB != NULL) {
        box_free(s->worldAABB);
        s->worldAABB = NULL;
    }
}
