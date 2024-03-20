// -------------------------------------------------------------
//  Cubzh Core
//  chunk.c
//  Created by Adrien Duermael on July 18, 2015.
// -------------------------------------------------------------

#include "chunk.h"

#include <stdlib.h>
#include <string.h>

#include "cclog.h"
#include "vertextbuffer.h"
#include "zlib.h"

#define CHUNK_NEIGHBORS_COUNT 26

static VERTEX_LIGHT_STRUCT_T *defaultLight = NULL;

// chunk structure definition
struct _Chunk {
    // 26 possible chunk neighbors used for fast access
    // when updating chunk data/vertices
    Chunk *neighbors[CHUNK_NEIGHBORS_COUNT]; /* 8 bytes */
    // octree partitioning this chunk's blocks
    Octree *octree; /* 8 bytes */
    // NULL if chunk does not use lighting
    VERTEX_LIGHT_STRUCT_T *lightingData; /* 8 bytes */
    // reference to shape chunks rtree leaf node, used for removal
    void *rtreeLeaf; /* 8 bytes */
    // first opaque/transparent bma reserved for that chunk, this can be chained across several
    // buffers
    VertexBufferMemArea *vbma_opaque;      /* 8 bytes */
    VertexBufferMemArea *ibma_opaque;      /* 8 bytes */
    VertexBufferMemArea *vbma_transparent; /* 8 bytes */
    VertexBufferMemArea *ibma_transparent; /* 8 bytes */
    // number of blocks in that chunk
    int nbBlocks; /* 4 bytes */
    // position of chunk in shape's model
    SHAPE_COORDS_INT3_T origin; /* 3 x 2 bytes */
    // model axis-aligned bounding box (bbMax - 1 is the max block)
    CHUNK_COORDS_INT3_T bbMin, bbMax; /* 6 x 1 byte */
    // whether vertices need to be refreshed
    bool dirty; /* 1 byte */

    char pad[7];
};

// MARK: private functions prototypes

Octree *_chunk_new_octree(void);
void _chunk_flush_buffers(Chunk *c);

void _chunk_hello_neighbor(Chunk *newcomer,
                           Neighbor newcomerLocation,
                           Chunk *neighbor,
                           Neighbor neighborLocation);
void _chunk_good_bye_neighbor(Chunk *chunk, Neighbor location);

/// used to gather vertex lighting values & properties in chunk_write_vertices
void _vertex_light_get(Chunk *chunk,
                       Block *block,
                       const ColorPalette *palette,
                       CHUNK_COORDS_INT3_T coords,
                       VERTEX_LIGHT_STRUCT_T *vlight,
                       bool *aoCaster,
                       bool *lightCaster);
/// used for smooth lighting in chunk_write_vertices
void _vertex_light_smoothing(VERTEX_LIGHT_STRUCT_T *base,
                             bool add1,
                             bool add2,
                             bool add3,
                             VERTEX_LIGHT_STRUCT_T vlight1,
                             VERTEX_LIGHT_STRUCT_T vlight2,
                             VERTEX_LIGHT_STRUCT_T vlight3);

bool _chunk_is_bounding_box_empty(const Chunk *chunk);
void _chunk_update_bounding_box(Chunk *chunk,
                                const CHUNK_COORDS_INT3_T coords,
                                const bool addOrRemove);

// MARK: public functions

void chunk_alloc_default_light(void) {
    if (defaultLight == NULL) {
        const size_t lightingSize = (size_t)CHUNK_SIZE_CUBE * (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
        defaultLight = malloc(lightingSize);
        for (size_t i = 0; i < CHUNK_SIZE_CUBE; ++i) {
            DEFAULT_LIGHT(defaultLight[i])
        }
    }
}

Chunk *chunk_new(const SHAPE_COORDS_INT3_T origin) {
    Chunk *chunk = (Chunk *)malloc(sizeof(Chunk));
    if (chunk == NULL) {
        return NULL;
    }
    chunk->octree = _chunk_new_octree();
    chunk->lightingData = NULL;
    chunk->rtreeLeaf = NULL;
    chunk->dirty = false;
    chunk->origin = origin;
    chunk->bbMin = (CHUNK_COORDS_INT3_T){0, 0, 0};
    chunk->bbMax = (CHUNK_COORDS_INT3_T){0, 0, 0};
    chunk->nbBlocks = 0;

    for (int i = 0; i < CHUNK_NEIGHBORS_COUNT; i++) {
        chunk->neighbors[i] = NULL;
    }

    chunk->vbma_opaque = NULL;
    chunk->ibma_opaque = NULL;
    chunk->vbma_transparent = NULL;
    chunk->ibma_transparent = NULL;

    return chunk;
}

Chunk *chunk_new_copy(const Chunk *c) {
    Chunk *copy = (Chunk *)malloc(sizeof(Chunk));
    if (copy == NULL) {
        return NULL;
    }
    copy->octree = octree_new_copy(c->octree);
    if (c->lightingData != NULL) {
        const size_t lightingSize = (size_t)CHUNK_SIZE_SQR * (size_t)CHUNK_SIZE *
                                    (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
        copy->lightingData = malloc(lightingSize);
        memcpy(copy->lightingData, c->lightingData, lightingSize);
    } else {
        copy->lightingData = NULL;
    }
    copy->rtreeLeaf = NULL;
    copy->dirty = false;
    copy->origin = c->origin;
    copy->bbMin = c->bbMin;
    copy->bbMax = c->bbMax;
    copy->nbBlocks = c->nbBlocks;

    for (int i = 0; i < CHUNK_NEIGHBORS_COUNT; i++) {
        copy->neighbors[i] = NULL;
    }

    copy->vbma_opaque = NULL;
    copy->ibma_opaque = NULL;
    copy->vbma_transparent = NULL;
    copy->ibma_transparent = NULL;

    return copy;
}

void chunk_free(Chunk *chunk, bool updateNeighbors) {
    if (updateNeighbors) {
        chunk_leave_neighborhood(chunk);
    }

    octree_free(chunk->octree);
    if (chunk->lightingData != NULL) {
        free(chunk->lightingData);
    }

    _chunk_flush_buffers(chunk);

    free(chunk);
}

void chunk_free_func(void *c) {
    chunk_free((Chunk *)c, false);
}

void chunk_set_dirty(Chunk *chunk, bool b) {
    chunk->dirty = b;
}

bool chunk_is_dirty(const Chunk *chunk) {
    return chunk->dirty;
}

SHAPE_COORDS_INT3_T chunk_get_origin(const Chunk *chunk) {
    return chunk->origin;
}

int chunk_get_nb_blocks(const Chunk *chunk) {
    return chunk->nbBlocks;
}

Octree *chunk_get_octree(const Chunk *c) {
    return c->octree;
}

void chunk_set_rtree_leaf(Chunk *c, void *ptr) {
    c->rtreeLeaf = ptr;
}

void *chunk_get_rtree_leaf(const Chunk *c) {
    return c->rtreeLeaf;
}

uint64_t chunk_get_hash(const Chunk *c, uint64_t crc) {
    const uint64_t originHash = crc32((uLong)crc,
                                      (const Bytef *)&c->origin,
                                      (uInt)sizeof(SHAPE_COORDS_INT3_T));
    return octree_get_hash(c->octree, originHash);
}

void chunk_set_light(Chunk *c,
                     const CHUNK_COORDS_INT3_T coords,
                     const VERTEX_LIGHT_STRUCT_T light,
                     const bool initEmpty) {

    if (c == NULL || coords.x < 0 || coords.x >= CHUNK_SIZE || coords.y < 0 ||
        coords.y >= CHUNK_SIZE || coords.z < 0 || coords.z >= CHUNK_SIZE) {
        return;
    }

    if (c->lightingData == NULL) {
        chunk_reset_lighting_data(c, initEmpty);
    }

    c->lightingData[coords.x * CHUNK_SIZE_SQR + coords.y * CHUNK_SIZE + coords.z] = light;
}

VERTEX_LIGHT_STRUCT_T chunk_get_light_without_checking(const Chunk *c, CHUNK_COORDS_INT3_T coords) {
    if (c == NULL || c->lightingData == NULL) {
        VERTEX_LIGHT_STRUCT_T light;
        DEFAULT_LIGHT(light)
        return light;
    } else {
        return c->lightingData[coords.x * CHUNK_SIZE_SQR + coords.y * CHUNK_SIZE + coords.z];
    }
}

VERTEX_LIGHT_STRUCT_T chunk_get_light_or_default(Chunk *c,
                                                 CHUNK_COORDS_INT3_T coords,
                                                 bool isDefault) {
    if (isDefault || coords.x < 0 || coords.x >= CHUNK_SIZE || coords.y < 0 ||
        coords.y >= CHUNK_SIZE || coords.z < 0 || coords.z >= CHUNK_SIZE) {
        VERTEX_LIGHT_STRUCT_T light;
        DEFAULT_LIGHT(light)
        return light;
    } else {
        return chunk_get_light_without_checking(c, coords);
    }
}

void chunk_clear_lighting_data(Chunk *c) {
    if (c->lightingData != NULL) {
        free(c->lightingData);
        c->lightingData = NULL;
    }
}

void chunk_reset_lighting_data(Chunk *c, const bool emptyOrDefault) {
    const size_t lightingSize = (size_t)CHUNK_SIZE_CUBE * (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
    if (c->lightingData == NULL) {
        c->lightingData = malloc(lightingSize);
    }
    if (emptyOrDefault) {
        memset(c->lightingData, 0, lightingSize);
    } else {
        vx_assert(defaultLight != NULL);
        memcpy(c->lightingData, defaultLight, lightingSize);
    }
}

void chunk_set_lighting_data(Chunk *c, VERTEX_LIGHT_STRUCT_T *data) {
    if (c->lightingData != NULL) {
        free(c->lightingData);
    }
    c->lightingData = data;
}

VERTEX_LIGHT_STRUCT_T *chunk_get_lighting_data(Chunk *c) {
    return c->lightingData;
}

bool chunk_add_block(Chunk *chunk,
                     const Block block,
                     const CHUNK_COORDS_INT_T x,
                     const CHUNK_COORDS_INT_T y,
                     const CHUNK_COORDS_INT_T z) {

    if (block_is_solid(&block) == false) {
        return false;
    }

    Block *b = (Block *)
        octree_get_element_without_checking(chunk->octree, (size_t)x, (size_t)y, (size_t)z);
    if (block_is_solid(b)) {
        return false;
    } else {
        octree_set_element(chunk->octree, &block, (size_t)x, (size_t)y, (size_t)z);
        chunk->nbBlocks++;
        _chunk_update_bounding_box(chunk, (CHUNK_COORDS_INT3_T){x, y, z}, true);
        return true;
    }
}

bool chunk_remove_block(Chunk *chunk,
                        const CHUNK_COORDS_INT_T x,
                        const CHUNK_COORDS_INT_T y,
                        const CHUNK_COORDS_INT_T z,
                        SHAPE_COLOR_INDEX_INT_T *prevColorIndex) {

    Block *b = (Block *)
        octree_get_element_without_checking(chunk->octree, (size_t)x, (size_t)y, (size_t)z);
    if (block_is_solid(b)) {
        if (prevColorIndex != NULL) {
            *prevColorIndex = block_get_color_index(b);
        }
        block_set_color_index(b, SHAPE_COLOR_INDEX_AIR_BLOCK);
        octree_remove_element(chunk->octree, (size_t)x, (size_t)y, (size_t)z, NULL);
        chunk->nbBlocks--;
        _chunk_update_bounding_box(chunk, (CHUNK_COORDS_INT3_T){x, y, z}, false);
        return true;
    } else {
        return false;
    }
}

bool chunk_paint_block(Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z,
                       const SHAPE_COLOR_INDEX_INT_T colorIndex,
                       SHAPE_COLOR_INDEX_INT_T *prevColorIndex) {

    Block *b = (Block *)
        octree_get_element_without_checking(chunk->octree, (size_t)x, (size_t)y, (size_t)z);
    if (block_is_solid(b)) {
        if (prevColorIndex != NULL) {
            *prevColorIndex = block_get_color_index(b);
        }
        block_set_color_index(b, colorIndex);
        return true;
    } else {
        return false;
    }
}

Block *chunk_get_block(const Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z) {
    if (chunk == NULL) {
        return NULL;
    }

    if (x < 0 || x > CHUNK_SIZE_MINUS_ONE)
        return NULL;
    if (y < 0 || y > CHUNK_SIZE_MINUS_ONE)
        return NULL;
    if (z < 0 || z > CHUNK_SIZE_MINUS_ONE)
        return NULL;

    return (
        Block *)octree_get_element_without_checking(chunk->octree, (size_t)x, (size_t)y, (size_t)z);
}

Block *chunk_get_block_2(const Chunk *chunk, CHUNK_COORDS_INT3_T coords) {
    return chunk_get_block(chunk, coords.x, coords.y, coords.z);
}

Block *chunk_get_block_including_neighbors(Chunk *chunk,
                                           const CHUNK_COORDS_INT_T x,
                                           const CHUNK_COORDS_INT_T y,
                                           const CHUNK_COORDS_INT_T z,
                                           Chunk **out_chunk,
                                           CHUNK_COORDS_INT3_T *out_coords) {
    if (chunk == NULL) {
        *out_chunk = NULL;
        *out_coords = (CHUNK_COORDS_INT3_T){x, y, z};
        return NULL;
    }

    Chunk *_chunk;
    CHUNK_COORDS_INT3_T _coords;
    if (y > CHUNK_SIZE_MINUS_ONE) { // Top (9 cases)
        if (x < 0) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // TopLeftBack
                _chunk = chunk->neighbors[NX_Y_Z];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y - CHUNK_SIZE, z - CHUNK_SIZE};
            } else if (z < 0) { // TopLeftFront
                _chunk = chunk->neighbors[NX_Y_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y - CHUNK_SIZE, z + CHUNK_SIZE};
            } else { // TopLeft
                _chunk = chunk->neighbors[NX_Y];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y - CHUNK_SIZE, z};
            }
        } else if (x > CHUNK_SIZE_MINUS_ONE) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // TopRightBack
                _chunk = chunk->neighbors[X_Y_Z];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y - CHUNK_SIZE, z - CHUNK_SIZE};
            } else if (z < 0) { // TopRightFront
                _chunk = chunk->neighbors[X_Y_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y - CHUNK_SIZE, z + CHUNK_SIZE};
            } else { // TopRight
                _chunk = chunk->neighbors[X_Y];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y - CHUNK_SIZE, z};
            }
        } else {
            if (z > CHUNK_SIZE_MINUS_ONE) { // TopBack
                _chunk = chunk->neighbors[Y_Z];
                _coords = (CHUNK_COORDS_INT3_T){x, y - CHUNK_SIZE, z - CHUNK_SIZE};
            } else if (z < 0) { // TopFront
                _chunk = chunk->neighbors[Y_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x, y - CHUNK_SIZE, z + CHUNK_SIZE};
            } else { // Top
                _chunk = chunk->neighbors[Y];
                _coords = (CHUNK_COORDS_INT3_T){x, y - CHUNK_SIZE, z};
            }
        }
    } else if (y < 0) { // Bottom (9 cases)
        if (x < 0) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // BottomLeftBack
                _chunk = chunk->neighbors[NX_NY_Z];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y + CHUNK_SIZE, z - CHUNK_SIZE};
            } else if (z < 0) { // BottomLeftFront
                _chunk = chunk->neighbors[NX_NY_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y + CHUNK_SIZE, z + CHUNK_SIZE};
            } else { // BottomLeft
                _chunk = chunk->neighbors[NX_NY];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y + CHUNK_SIZE, z};
            }
        } else if (x > CHUNK_SIZE_MINUS_ONE) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // BottomRightBack
                _chunk = chunk->neighbors[X_NY_Z];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y + CHUNK_SIZE, z - CHUNK_SIZE};
            } else if (z < 0) { // BottomRightFront
                _chunk = chunk->neighbors[X_NY_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y + CHUNK_SIZE, z + CHUNK_SIZE};
            } else { // BottomRight
                _chunk = chunk->neighbors[X_NY];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y + CHUNK_SIZE, z};
            }
        } else {
            if (z > CHUNK_SIZE_MINUS_ONE) { // BottomBack
                _chunk = chunk->neighbors[NY_Z];
                _coords = (CHUNK_COORDS_INT3_T){x, y + CHUNK_SIZE, z - CHUNK_SIZE};
            } else if (z < 0) { // BottomFront
                _chunk = chunk->neighbors[NY_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x, y + CHUNK_SIZE, z + CHUNK_SIZE};
            } else { // Bottom
                _chunk = chunk->neighbors[NY];
                _coords = (CHUNK_COORDS_INT3_T){x, y + CHUNK_SIZE, z};
            }
        }
    } else { // 8 cases (y is within chunk)
        if (x < 0) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // LeftBack
                _chunk = chunk->neighbors[NX_Z];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y, z - CHUNK_SIZE};
            } else if (z < 0) { // LeftFront
                _chunk = chunk->neighbors[NX_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y, z + CHUNK_SIZE};
            } else { // NX
                _chunk = chunk->neighbors[NX];
                _coords = (CHUNK_COORDS_INT3_T){x + CHUNK_SIZE, y, z};
            }
        } else if (x > CHUNK_SIZE_MINUS_ONE) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // RightBack
                _chunk = chunk->neighbors[X_Z];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y, z - CHUNK_SIZE};
            } else if (z < 0) { // RightFront
                _chunk = chunk->neighbors[X_NZ];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y, z + CHUNK_SIZE};
            } else { // Right
                _chunk = chunk->neighbors[X];
                _coords = (CHUNK_COORDS_INT3_T){x - CHUNK_SIZE, y, z};
            }
        } else {
            if (z > CHUNK_SIZE_MINUS_ONE) { // Back
                _chunk = chunk->neighbors[Z];
                _coords = (CHUNK_COORDS_INT3_T){x, y, z - CHUNK_SIZE};
            } else if (z < 0) { // Front
                _chunk = chunk->neighbors[NZ];
                _coords = (CHUNK_COORDS_INT3_T){x, y, z + CHUNK_SIZE};
            } else {
                _chunk = chunk;
                _coords = (CHUNK_COORDS_INT3_T){x, y, z};
            }
        }
    }

    if (out_chunk != NULL) {
        *out_chunk = _chunk;
    }
    if (out_coords != NULL) {
        *out_coords = _coords;
    }
    if (_chunk == NULL) {
        return NULL;
    } else {
        return (Block *)octree_get_element_without_checking(_chunk->octree,
                                                            (size_t)_coords.x,
                                                            (size_t)_coords.y,
                                                            (size_t)_coords.z);
    }
}

SHAPE_COORDS_INT3_T chunk_get_block_coords_in_shape(const Chunk *chunk,
                                                    const CHUNK_COORDS_INT_T x,
                                                    const CHUNK_COORDS_INT_T y,
                                                    const CHUNK_COORDS_INT_T z) {
    return (SHAPE_COORDS_INT3_T){(SHAPE_COORDS_INT_T)x + chunk->origin.x,
                                 (SHAPE_COORDS_INT_T)y + chunk->origin.y,
                                 (SHAPE_COORDS_INT_T)z + chunk->origin.z};
}

SHAPE_COORDS_INT3_T chunk_utils_get_coords(const SHAPE_COORDS_INT3_T coords_in_shape) {
#if CHUNK_SIZE_IS_PERFECT_SQRT
    return (SHAPE_COORDS_INT3_T){(SHAPE_COORDS_INT_T)(coords_in_shape.x >> CHUNK_SIZE_SQRT),
                                 (SHAPE_COORDS_INT_T)(coords_in_shape.y >> CHUNK_SIZE_SQRT),
                                 (SHAPE_COORDS_INT_T)(coords_in_shape.z >> CHUNK_SIZE_SQRT)};
#else
    return (SHAPE_COORDS_INT3_T){
        (SHAPE_COORDS_INT_T)(coords_in_shape.x / CHUNK_SIZE - (coords_in_shape.x < 0 ? 1 : 0)),
        (SHAPE_COORDS_INT_T)(coords_in_shape.y / CHUNK_SIZE - (coords_in_shape.y < 0 ? 1 : 0)),
        (SHAPE_COORDS_INT_T)(coords_in_shape.z / CHUNK_SIZE - (coords_in_shape.z < 0 ? 1 : 0))};
#endif
}

CHUNK_COORDS_INT3_T chunk_utils_get_coords_in_chunk(const SHAPE_COORDS_INT3_T coords_in_shape) {
#if CHUNK_SIZE_IS_PERFECT_SQRT
    return (CHUNK_COORDS_INT3_T){(CHUNK_COORDS_INT_T)(coords_in_shape.x & CHUNK_SIZE_MINUS_ONE),
                                 (CHUNK_COORDS_INT_T)(coords_in_shape.y & CHUNK_SIZE_MINUS_ONE),
                                 (CHUNK_COORDS_INT_T)(coords_in_shape.z & CHUNK_SIZE_MINUS_ONE)};
#else
    return (CHUNK_COORDS_INT3_T){(CHUNK_COORDS_INT_T)(coords_in_shape.x % CHUNK_SIZE +
                                                      (coords_in_shape.x < 0 ? CHUNK_SIZE : 0)),
                                 (CHUNK_COORDS_INT_T)(coords_in_shape.y % CHUNK_SIZE +
                                                      (coords_in_shape.y < 0 ? CHUNK_SIZE : 0)),
                                 (CHUNK_COORDS_INT_T)(coords_in_shape.z % CHUNK_SIZE +
                                                      (coords_in_shape.z < 0 ? CHUNK_SIZE : 0))};
#endif
}

void chunk_get_bounding_box(const Chunk *chunk, float3 *min, float3 *max) {
    if (min != NULL) {
        min->x = (float)chunk->bbMin.x;
        min->y = (float)chunk->bbMin.y;
        min->z = (float)chunk->bbMin.z;
    }
    if (max != NULL) {
        max->x = (float)chunk->bbMax.x;
        max->y = (float)chunk->bbMax.y;
        max->z = (float)chunk->bbMax.z;
    }
}

void chunk_get_bounding_box_2(const Chunk *chunk,
                              CHUNK_COORDS_INT3_T *min,
                              CHUNK_COORDS_INT3_T *max) {
    if (min != NULL) {
        *min = chunk->bbMin;
    }
    if (max != NULL) {
        *max = chunk->bbMax;
    }
}

// MARK: - Neighbors -

Chunk *chunk_get_neighbor(const Chunk *chunk, Neighbor location) {
    return chunk->neighbors[location];
}

void chunk_move_in_neighborhood(Index3D *chunks, Chunk *chunk, SHAPE_COORDS_INT3_T coords) {
    void **batchedNode_X = NULL, **batchedNode_Y = NULL;

    // Batch Index3D search for all neighbors on the right (x+1)
    Chunk *x = NULL, *x_y = NULL, *x_y_z = NULL, *x_y_nz = NULL, *x_ny = NULL, *x_ny_z = NULL,
          *x_ny_nz = NULL, *x_z = NULL, *x_nz = NULL;

    index3d_batch_get_reset(chunks, &batchedNode_X);
    if (index3d_batch_get_advance(coords.x + 1, &batchedNode_X)) {
        // y batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y, &batchedNode_Y)) {
            x = index3d_batch_get(coords.z, batchedNode_Y);
            x_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            x_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }

        // y+1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y + 1, &batchedNode_Y)) {
            x_y = index3d_batch_get(coords.z, batchedNode_Y);
            x_y_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            x_y_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }

        // y-1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y - 1, &batchedNode_Y)) {
            x_ny = index3d_batch_get(coords.z, batchedNode_Y);
            x_ny_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            x_ny_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }
    }

    _chunk_hello_neighbor(chunk, NX, x, X);
    _chunk_hello_neighbor(chunk, NX_NZ, x_z, X_Z);
    _chunk_hello_neighbor(chunk, NX_Z, x_nz, X_NZ);

    _chunk_hello_neighbor(chunk, NX_NY, x_y, X_Y);
    _chunk_hello_neighbor(chunk, NX_NY_NZ, x_y_z, X_Y_Z);
    _chunk_hello_neighbor(chunk, NX_NY_Z, x_y_nz, X_Y_NZ);

    _chunk_hello_neighbor(chunk, NX_Y, x_ny, X_NY);
    _chunk_hello_neighbor(chunk, NX_Y_NZ, x_ny_z, X_NY_Z);
    _chunk_hello_neighbor(chunk, NX_Y_Z, x_ny_nz, X_NY_NZ);

    // Batch Index3D search for all neighbors on the left (x-1)
    Chunk *nx = NULL, *nx_y = NULL, *nx_y_z = NULL, *nx_y_nz = NULL, *nx_ny = NULL, *nx_ny_z = NULL,
          *nx_ny_nz = NULL, *nx_z = NULL, *nx_nz = NULL;

    index3d_batch_get_reset(chunks, &batchedNode_X);
    if (index3d_batch_get_advance(coords.x - 1, &batchedNode_X)) {
        // y batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y, &batchedNode_Y)) {
            nx = index3d_batch_get(coords.z, batchedNode_Y);
            nx_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            nx_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }

        // y+1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y + 1, &batchedNode_Y)) {
            nx_y = index3d_batch_get(coords.z, batchedNode_Y);
            nx_y_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            nx_y_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }

        // y-1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y - 1, &batchedNode_Y)) {
            nx_ny = index3d_batch_get(coords.z, batchedNode_Y);
            nx_ny_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            nx_ny_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }
    }

    _chunk_hello_neighbor(chunk, X, nx, NX);
    _chunk_hello_neighbor(chunk, X_NZ, nx_z, NX_Z);
    _chunk_hello_neighbor(chunk, X_Z, nx_nz, NX_NZ);

    _chunk_hello_neighbor(chunk, X_NY, nx_y, NX_Y);
    _chunk_hello_neighbor(chunk, X_NY_NZ, nx_y_z, NX_Y_Z);
    _chunk_hello_neighbor(chunk, X_NY_Z, nx_y_nz, NX_Y_NZ);

    _chunk_hello_neighbor(chunk, X_Y, nx_ny, NX_NY);
    _chunk_hello_neighbor(chunk, X_Y_NZ, nx_ny_z, NX_NY_Z);
    _chunk_hello_neighbor(chunk, X_Y_Z, nx_ny_nz, NX_NY_NZ);

    // Batch Index3D search for remaining neighbors (same x)
    Chunk *y = NULL, *y_z = NULL, *y_nz = NULL, *ny = NULL, *ny_z = NULL, *ny_nz = NULL, *z = NULL,
          *nz = NULL;

    index3d_batch_get_reset(chunks, &batchedNode_X);
    if (index3d_batch_get_advance(coords.x, &batchedNode_X)) {
        // y batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y, &batchedNode_Y)) {
            z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }

        // y+1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y + 1, &batchedNode_Y)) {
            y = index3d_batch_get(coords.z, batchedNode_Y);
            y_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            y_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }

        // y-1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(coords.y - 1, &batchedNode_Y)) {
            ny = index3d_batch_get(coords.z, batchedNode_Y);
            ny_z = index3d_batch_get(coords.z + 1, batchedNode_Y);
            ny_nz = index3d_batch_get(coords.z - 1, batchedNode_Y);
        }
    }

    _chunk_hello_neighbor(chunk, NZ, z, Z);
    _chunk_hello_neighbor(chunk, Z, nz, NZ);

    _chunk_hello_neighbor(chunk, NY, y, Y);
    _chunk_hello_neighbor(chunk, NY_NZ, y_z, Y_Z);
    _chunk_hello_neighbor(chunk, NY_Z, y_nz, Y_NZ);

    _chunk_hello_neighbor(chunk, Y, ny, NY);
    _chunk_hello_neighbor(chunk, Y_NZ, ny_z, NY_Z);
    _chunk_hello_neighbor(chunk, Y_Z, ny_nz, NY_NZ);
}

void chunk_leave_neighborhood(Chunk *chunk) {
    if (chunk == NULL)
        return;

    _chunk_good_bye_neighbor(chunk->neighbors[X], NX);
    _chunk_good_bye_neighbor(chunk->neighbors[X_Y], NX_NY);
    _chunk_good_bye_neighbor(chunk->neighbors[X_Y_Z], NX_NY_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[X_Y_NZ], NX_NY_Z);
    _chunk_good_bye_neighbor(chunk->neighbors[X_NY], NX_Y);
    _chunk_good_bye_neighbor(chunk->neighbors[X_NY_Z], NX_Y_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[X_NY_NZ], NX_Y_Z);
    _chunk_good_bye_neighbor(chunk->neighbors[X_Z], NX_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[X_NZ], NX_Z);

    _chunk_good_bye_neighbor(chunk->neighbors[NX], X);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_Y], X_NY);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_Y_Z], X_NY_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_Y_NZ], X_NY_Z);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_NY], X_Y);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_NY_Z], X_Y_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_NY_NZ], X_Y_Z);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_Z], X_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[NX_NZ], X_Z);

    _chunk_good_bye_neighbor(chunk->neighbors[Y], NY);
    _chunk_good_bye_neighbor(chunk->neighbors[Y_Z], NY_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[Y_NZ], NY_Z);

    _chunk_good_bye_neighbor(chunk->neighbors[NY], Y);
    _chunk_good_bye_neighbor(chunk->neighbors[NY_Z], Y_NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[NY_NZ], Y_Z);

    _chunk_good_bye_neighbor(chunk->neighbors[Z], NZ);
    _chunk_good_bye_neighbor(chunk->neighbors[NZ], Z);

    for (int i = 0; i < CHUNK_NEIGHBORS_COUNT; i++) {
        chunk->neighbors[i] = NULL;
    }
}

// MARK: - Buffers -

void *chunk_get_vbma(const Chunk *chunk, bool transparent) {
    return transparent ? chunk->vbma_transparent : chunk->vbma_opaque;
}

void *chunk_get_ibma(const Chunk *chunk, bool transparent) {
    return transparent ? chunk->ibma_transparent : chunk->ibma_opaque;
}

void chunk_set_vbma(Chunk *chunk, void *vbma, bool transparent) {
    if (transparent) {
        chunk->vbma_transparent = (VertexBufferMemArea *)vbma;
    } else {
        chunk->vbma_opaque = (VertexBufferMemArea *)vbma;
    }
}

void chunk_set_ibma(Chunk *chunk, void *ibma, bool transparent) {
    if (transparent) {
        chunk->ibma_transparent = (VertexBufferMemArea *)ibma;
    } else {
        chunk->ibma_opaque = (VertexBufferMemArea *)ibma;
    }
}

void chunk_write_vertices(Shape *shape, Chunk *chunk) {
    // recycle buffer mem areas used by this chunk, as gaps
    _chunk_flush_buffers(chunk);

    HashUInt32 *vertexMap = hash_uint32_new(free);

    ColorPalette *palette = shape_get_palette(shape);

    VertexBufferMemAreaWriter *vbmaw_opaque = vertex_buffer_mem_area_writer_new(shape,
                                                                                chunk,
                                                                                chunk->vbma_opaque,
                                                                                false);
    VertexBufferMemAreaWriter *ibmaw_opaque = vertex_buffer_mem_area_writer_new(shape,
                                                                                chunk,
                                                                                chunk->ibma_opaque,
                                                                                false);
#if ENABLE_TRANSPARENCY
    VertexBufferMemAreaWriter *vbmaw_transparent = vertex_buffer_mem_area_writer_new(
        shape,
        chunk,
        chunk->vbma_transparent,
        true);
    VertexBufferMemAreaWriter *ibmaw_transparent = vertex_buffer_mem_area_writer_new(
        shape,
        chunk,
        chunk->ibma_transparent,
        true);
#else
    VertexBufferMemAreaWriter *vbmaw_transparent = vbmaw_opaque;
#endif

    Block *b;
    CHUNK_COORDS_INT3_T coords_in_chunk;
    SHAPE_COORDS_INT3_T coords_in_shape;
    SHAPE_COLOR_INDEX_INT_T shapeColorIdx;
    ATLAS_COLOR_INDEX_INT_T atlasColorIdx;

    // vertex lighting (baked)
    const bool vLighting = shape_uses_baked_lighting(shape);
    VERTEX_LIGHT_STRUCT_T vlight1, vlight2, vlight3, vlight4;

    FACE_AMBIENT_OCCLUSION_STRUCT_T ao;

    // neighbors block information
    typedef struct {
        Block *block;
        Chunk *chunk;
        CHUNK_COORDS_INT3_T coords;
        VERTEX_LIGHT_STRUCT_T vlight;
    } NeighborBlock;
    NeighborBlock neighbors[26];

    // faces are only rendered
    // - if self opaque, when neighbor is not opaque
    // - if self transparent, when neighbor is not solid (null or air block)
    bool renderLeft, renderRight, renderFront, renderBack, renderTop, renderBottom;
    // flags caching result of block_is_ao_and_light_caster
    // - normally, only opaque blocks (non-null, non-air, non-transparent) are AO casters
    // - if enabled, all solid blocks (non-null, non-air, opaque or transparent) are AO casters
    // - only non-solid blocks (null or air) are light casters
    // this property is what allow us to let light go through & be absorbed by transparent blocks,
    // without dimming the light values sampled for vertices adjacent to the transparent block
    bool ao_topLeftBack, ao_topBack, ao_topRightBack, ao_topLeft, ao_topRight, ao_topLeftFront,
        ao_topFront, ao_topRightFront, ao_leftBack, ao_rightBack, ao_leftFront, ao_rightFront,
        ao_bottomLeftBack, ao_bottomBack, ao_bottomRightBack, ao_bottomLeft, ao_bottomRight,
        ao_bottomLeftFront, ao_bottomFront, ao_bottomRightFront;
    bool light_topLeftBack, light_topBack, light_topRightBack, light_topLeft, light_topRight,
        light_topLeftFront, light_topFront, light_topRightFront, light_leftBack, light_rightBack,
        light_leftFront, light_rightFront, light_bottomLeftBack, light_bottomBack,
        light_bottomRightBack, light_bottomLeft, light_bottomRight, light_bottomLeftFront,
        light_bottomFront, light_bottomRightFront;
    // should self be rendered with transparency
    bool selfTransparent;

    for (CHUNK_COORDS_INT_T x = 0; x < CHUNK_SIZE; ++x) {
        for (CHUNK_COORDS_INT_T z = 0; z < CHUNK_SIZE; ++z) {
            for (CHUNK_COORDS_INT_T y = 0; y < CHUNK_SIZE; ++y) {
                b = chunk_get_block(chunk, x, y, z);
                if (block_is_solid(b)) {

                    shapeColorIdx = block_get_color_index(b);
                    atlasColorIdx = color_palette_get_atlas_index(palette, shapeColorIdx);
                    selfTransparent = color_palette_is_transparent(palette, shapeColorIdx);

                    coords_in_chunk = (CHUNK_COORDS_INT3_T){ x, y, z };
                    coords_in_shape = chunk_get_block_coords_in_shape(chunk, x, y, z);

                    // get axis-aligned neighbouring blocks
                    neighbors[NX].block = chunk_get_block_including_neighbors(
                        chunk,
                        x - 1,
                        y,
                        z,
                        &neighbors[NX].chunk,
                        &neighbors[NX].coords);
                    neighbors[X].block = chunk_get_block_including_neighbors(chunk,
                                                                             x + 1,
                                                                             y,
                                                                             z,
                                                                             &neighbors[X].chunk,
                                                                             &neighbors[X].coords);
                    neighbors[NZ].block = chunk_get_block_including_neighbors(
                        chunk,
                        x,
                        y,
                        z - 1,
                        &neighbors[NZ].chunk,
                        &neighbors[NZ].coords);
                    neighbors[Z].block = chunk_get_block_including_neighbors(chunk,
                                                                             x,
                                                                             y,
                                                                             z + 1,
                                                                             &neighbors[Z].chunk,
                                                                             &neighbors[Z].coords);
                    neighbors[Y].block = chunk_get_block_including_neighbors(chunk,
                                                                             x,
                                                                             y + 1,
                                                                             z,
                                                                             &neighbors[Y].chunk,
                                                                             &neighbors[Y].coords);
                    neighbors[NY].block = chunk_get_block_including_neighbors(
                        chunk,
                        x,
                        y - 1,
                        z,
                        &neighbors[NY].chunk,
                        &neighbors[NY].coords);

                    // get their opacity properties
                    bool solid_left, opaque_left, transparent_left, solid_right, opaque_right,
                        transparent_right, solid_front, opaque_front, transparent_front, solid_back,
                        opaque_back, transparent_back, solid_top, opaque_top, transparent_top,
                        solid_bottom, opaque_bottom, transparent_bottom;

                    block_is_any(neighbors[NX].block,
                                 palette,
                                 &solid_left,
                                 &opaque_left,
                                 &transparent_left,
                                 NULL,
                                 NULL);
                    block_is_any(neighbors[X].block,
                                 palette,
                                 &solid_right,
                                 &opaque_right,
                                 &transparent_right,
                                 NULL,
                                 NULL);
                    block_is_any(neighbors[NZ].block,
                                 palette,
                                 &solid_front,
                                 &opaque_front,
                                 &transparent_front,
                                 NULL,
                                 NULL);
                    block_is_any(neighbors[Z].block,
                                 palette,
                                 &solid_back,
                                 &opaque_back,
                                 &transparent_back,
                                 NULL,
                                 NULL);
                    block_is_any(neighbors[Y].block,
                                 palette,
                                 &solid_top,
                                 &opaque_top,
                                 &transparent_top,
                                 NULL,
                                 NULL);
                    block_is_any(neighbors[NY].block,
                                 palette,
                                 &solid_bottom,
                                 &opaque_bottom,
                                 &transparent_bottom,
                                 NULL,
                                 NULL);

                    // get their vertex light values
                    if (vLighting) {
                        neighbors[NX].vlight = chunk_get_light_or_default(
                            neighbors[NX].chunk,
                            neighbors[NX].coords,
                            neighbors[NX].block == NULL || opaque_left);
                        neighbors[X].vlight = chunk_get_light_or_default(
                            neighbors[X].chunk,
                            neighbors[X].coords,
                            neighbors[X].block == NULL || opaque_right);
                        neighbors[NZ].vlight = chunk_get_light_or_default(
                            neighbors[NZ].chunk,
                            neighbors[NZ].coords,
                            neighbors[NZ].block == NULL || opaque_front);
                        neighbors[Z].vlight = chunk_get_light_or_default(
                            neighbors[Z].chunk,
                            neighbors[Z].coords,
                            neighbors[Z].block == NULL || opaque_back);
                        neighbors[Y].vlight = chunk_get_light_or_default(
                            neighbors[Y].chunk,
                            neighbors[Y].coords,
                            neighbors[Y].block == NULL || opaque_top);
                        neighbors[NY].vlight = chunk_get_light_or_default(
                            neighbors[NY].chunk,
                            neighbors[NY].coords,
                            neighbors[NY].block == NULL || opaque_bottom);
                    }

                    // check which faces should be rendered
                    // transparent: if neighbor is non-solid or, if enabled, transparent with a
                    // different color
                    if (selfTransparent) {
                        if (shape_draw_inner_transparent_faces(shape)) {
                            renderLeft = (solid_left == false) ||
                                         (transparent_left &&
                                          b->colorIndex != neighbors[NX].block->colorIndex);
                            renderRight = (solid_right == false) ||
                                          (transparent_right &&
                                           b->colorIndex != neighbors[X].block->colorIndex);
                            renderFront = (solid_front == false) ||
                                          (transparent_front &&
                                           b->colorIndex != neighbors[NZ].block->colorIndex);
                            renderBack = (solid_back == false) ||
                                         (transparent_back &&
                                          b->colorIndex != neighbors[Z].block->colorIndex);
                            renderTop = (solid_top == false) ||
                                        (transparent_top &&
                                         b->colorIndex != neighbors[Y].block->colorIndex);
                            renderBottom = (solid_bottom == false) ||
                                           (transparent_bottom &&
                                            b->colorIndex != neighbors[NY].block->colorIndex);
                        } else {
                            renderLeft = (solid_left == false);
                            renderRight = (solid_right == false);
                            renderFront = (solid_front == false);
                            renderBack = (solid_back == false);
                            renderTop = (solid_top == false);
                            renderBottom = (solid_bottom == false);
                        }
                    }
                    // opaque: if neighbor is non-opaque
                    else {
                        renderLeft = (opaque_left == false);
                        renderRight = (opaque_right == false);
                        renderFront = (opaque_front == false);
                        renderBack = (opaque_back == false);
                        renderTop = (opaque_top == false);
                        renderBottom = (opaque_bottom == false);
                    }

                    if (renderLeft) {
                        ao.ao1 = 0;
                        ao.ao2 = 0;
                        ao.ao3 = 0;
                        ao.ao4 = 0;

                        // get 8 neighbors that can impact ambient occlusion and vertex lighting
                        neighbors[NX_Y_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y + 1,
                            z + 1,
                            &neighbors[NX_Y_Z].chunk,
                            &neighbors[NX_Y_Z].coords);
                        neighbors[NX_Y].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y + 1,
                            z,
                            &neighbors[NX_Y].chunk,
                            &neighbors[NX_Y].coords);
                        neighbors[NX_Y_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y + 1,
                            z - 1,
                            &neighbors[NX_Y_NZ].chunk,
                            &neighbors[NX_Y_NZ].coords);

                        neighbors[NX_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y,
                            z + 1,
                            &neighbors[NX_Z].chunk,
                            &neighbors[NX_Z].coords);
                        neighbors[NX_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y,
                            z - 1,
                            &neighbors[NX_NZ].chunk,
                            &neighbors[NX_NZ].coords);

                        neighbors[NX_NY_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y - 1,
                            z + 1,
                            &neighbors[NX_NY_Z].chunk,
                            &neighbors[NX_NY_Z].coords);
                        neighbors[NX_NY].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y - 1,
                            z,
                            &neighbors[NX_NY].chunk,
                            &neighbors[NX_NY].coords);
                        neighbors[NX_NY_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x - 1,
                            y - 1,
                            z - 1,
                            &neighbors[NX_NY_NZ].chunk,
                            &neighbors[NX_NY_NZ].coords);

                        // get their light values & properties
                        _vertex_light_get(neighbors[NX_Y_Z].chunk,
                                          neighbors[NX_Y_Z].block,
                                          palette,
                                          neighbors[NX_Y_Z].coords,
                                          &neighbors[NX_Y_Z].vlight,
                                          &ao_topLeftBack,
                                          &light_topLeftBack);
                        _vertex_light_get(neighbors[NX_Y].chunk,
                                          neighbors[NX_Y].block,
                                          palette,
                                          neighbors[NX_Y].coords,
                                          &neighbors[NX_Y].vlight,
                                          &ao_topLeft,
                                          &light_topLeft);
                        _vertex_light_get(neighbors[NX_Y_NZ].chunk,
                                          neighbors[NX_Y_NZ].block,
                                          palette,
                                          neighbors[NX_Y_NZ].coords,
                                          &neighbors[NX_Y_NZ].vlight,
                                          &ao_topLeftFront,
                                          &light_topLeftFront);

                        _vertex_light_get(neighbors[NX_Z].chunk,
                                          neighbors[NX_Z].block,
                                          palette,
                                          neighbors[NX_Z].coords,
                                          &neighbors[NX_Z].vlight,
                                          &ao_leftBack,
                                          &light_leftBack);
                        _vertex_light_get(neighbors[NX_NZ].chunk,
                                          neighbors[NX_NZ].block,
                                          palette,
                                          neighbors[NX_NZ].coords,
                                          &neighbors[NX_NZ].vlight,
                                          &ao_leftFront,
                                          &light_leftFront);

                        _vertex_light_get(neighbors[NX_NY_Z].chunk,
                                          neighbors[NX_NY_Z].block,
                                          palette,
                                          neighbors[NX_NY_Z].coords,
                                          &neighbors[NX_NY_Z].vlight,
                                          &ao_bottomLeftBack,
                                          &light_bottomLeftBack);
                        _vertex_light_get(neighbors[NX_NY].chunk,
                                          neighbors[NX_NY].block,
                                          palette,
                                          neighbors[NX_NY].coords,
                                          &neighbors[NX_NY].vlight,
                                          &ao_bottomLeft,
                                          &light_bottomLeft);
                        _vertex_light_get(neighbors[NX_NY_NZ].chunk,
                                          neighbors[NX_NY_NZ].block,
                                          palette,
                                          neighbors[NX_NY_NZ].coords,
                                          &neighbors[NX_NY_NZ].vlight,
                                          &ao_bottomLeftFront,
                                          &light_bottomLeftFront);

                        // first corner
                        if (ao_bottomLeft && ao_leftFront) {
                            ao.ao1 = 3;
                        } else if (ao_bottomLeftFront && (ao_bottomLeft || ao_leftFront)) {
                            ao.ao1 = 2;
                        } else if (ao_bottomLeftFront || ao_bottomLeft || ao_leftFront) {
                            ao.ao1 = 1;
                        }
                        vlight1 = neighbors[NX].vlight;
                        if (vLighting && (light_bottomLeft || light_leftFront)) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_bottomLeftFront,
                                                    light_bottomLeft,
                                                    light_leftFront,
                                                    neighbors[NX_NY_NZ].vlight,
                                                    neighbors[NX_NY].vlight,
                                                    neighbors[NX_NZ].vlight);
                        }

                        // second corner
                        if (ao_leftFront && ao_topLeft) {
                            ao.ao2 = 3;
                        } else if (ao_topLeftFront && (ao_leftFront || ao_topLeft)) {
                            ao.ao2 = 2;
                        } else if (ao_topLeftFront || ao_leftFront || ao_topLeft) {
                            ao.ao2 = 1;
                        }
                        vlight2 = neighbors[NX].vlight;
                        if (vLighting && (light_leftFront || light_topLeft)) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_topLeftFront,
                                                    light_leftFront,
                                                    light_topLeft,
                                                    neighbors[NX_Y_NZ].vlight,
                                                    neighbors[NX_NZ].vlight,
                                                    neighbors[NX_Y].vlight);
                        }

                        // third corner
                        if (ao_topLeft && ao_leftBack) {
                            ao.ao3 = 3;
                        } else if (ao_topLeftBack && (ao_topLeft || ao_leftBack)) {
                            ao.ao3 = 2;
                        } else if (ao_topLeftBack || ao_topLeft || ao_leftBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = neighbors[NX].vlight;
                        if (vLighting && (light_topLeft || light_leftBack)) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_topLeftBack,
                                                    light_topLeft,
                                                    light_leftBack,
                                                    neighbors[NX_Y_Z].vlight,
                                                    neighbors[NX_Y].vlight,
                                                    neighbors[NX_Z].vlight);
                        }

                        // 4th corner
                        if (ao_leftBack && ao_bottomLeft) {
                            ao.ao4 = 3;
                        } else if (ao_bottomLeftBack && (ao_leftBack || ao_bottomLeft)) {
                            ao.ao4 = 2;
                        } else if (ao_bottomLeftBack || ao_leftBack || ao_bottomLeft) {
                            ao.ao4 = 1;
                        }
                        vlight4 = neighbors[NX].vlight;
                        if (vLighting && (light_leftBack || light_bottomLeft)) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_bottomLeftBack,
                                                    light_leftBack,
                                                    light_bottomLeft,
                                                    neighbors[NX_NY_Z].vlight,
                                                    neighbors[NX_Z].vlight,
                                                    neighbors[NX_NY].vlight);
                        }

                        vertex_buffer_mem_area_writer_write(
                            selfTransparent ? vbmaw_transparent : vbmaw_opaque,
                            selfTransparent ? ibmaw_transparent : ibmaw_opaque,
                            vertexMap,
                            coords_in_chunk,
                            coords_in_shape,
                            shapeColorIdx,
                            atlasColorIdx,
                            FACE_LEFT,
                            ao,
                            vLighting,
                            vlight1,
                            vlight2,
                            vlight3,
                            vlight4);
                    }

                    if (renderRight) {
                        ao.ao1 = 0;
                        ao.ao2 = 0;
                        ao.ao3 = 0;
                        ao.ao4 = 0;

                        // get 8 neighbors that can impact ambient occlusion and vertex lighting
                        neighbors[X_Y_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y + 1,
                            z + 1,
                            &neighbors[X_Y_Z].chunk,
                            &neighbors[X_Y_Z].coords);
                        neighbors[X_Y].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y + 1,
                            z,
                            &neighbors[X_Y].chunk,
                            &neighbors[X_Y].coords);
                        neighbors[X_Y_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y + 1,
                            z - 1,
                            &neighbors[X_Y_NZ].chunk,
                            &neighbors[X_Y_NZ].coords);

                        neighbors[X_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y,
                            z + 1,
                            &neighbors[X_Z].chunk,
                            &neighbors[X_Z].coords);
                        neighbors[X_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y,
                            z - 1,
                            &neighbors[X_NZ].chunk,
                            &neighbors[X_NZ].coords);

                        neighbors[X_NY_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y - 1,
                            z + 1,
                            &neighbors[X_NY_Z].chunk,
                            &neighbors[X_NY_Z].coords);
                        neighbors[X_NY].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y - 1,
                            z,
                            &neighbors[X_NY].chunk,
                            &neighbors[X_NY].coords);
                        neighbors[X_NY_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x + 1,
                            y - 1,
                            z - 1,
                            &neighbors[X_NY_NZ].chunk,
                            &neighbors[X_NY_NZ].coords);

                        // get their light values & properties
                        _vertex_light_get(neighbors[X_Y_Z].chunk,
                                          neighbors[X_Y_Z].block,
                                          palette,
                                          neighbors[X_Y_Z].coords,
                                          &neighbors[X_Y_Z].vlight,
                                          &ao_topRightBack,
                                          &light_topRightBack);
                        _vertex_light_get(neighbors[X_Y].chunk,
                                          neighbors[X_Y].block,
                                          palette,
                                          neighbors[X_Y].coords,
                                          &neighbors[X_Y].vlight,
                                          &ao_topRight,
                                          &light_topRight);
                        _vertex_light_get(neighbors[X_Y_NZ].chunk,
                                          neighbors[X_Y_NZ].block,
                                          palette,
                                          neighbors[X_Y_NZ].coords,
                                          &neighbors[X_Y_NZ].vlight,
                                          &ao_topRightFront,
                                          &light_topRightFront);

                        _vertex_light_get(neighbors[X_Z].chunk,
                                          neighbors[X_Z].block,
                                          palette,
                                          neighbors[X_Z].coords,
                                          &neighbors[X_Z].vlight,
                                          &ao_rightBack,
                                          &light_rightBack);
                        _vertex_light_get(neighbors[X_NZ].chunk,
                                          neighbors[X_NZ].block,
                                          palette,
                                          neighbors[X_NZ].coords,
                                          &neighbors[X_NZ].vlight,
                                          &ao_rightFront,
                                          &light_rightFront);

                        _vertex_light_get(neighbors[X_NY_Z].chunk,
                                          neighbors[X_NY_Z].block,
                                          palette,
                                          neighbors[X_NY_Z].coords,
                                          &neighbors[X_NY_Z].vlight,
                                          &ao_bottomRightBack,
                                          &light_bottomRightBack);
                        _vertex_light_get(neighbors[X_NY].chunk,
                                          neighbors[X_NY].block,
                                          palette,
                                          neighbors[X_NY].coords,
                                          &neighbors[X_NY].vlight,
                                          &ao_bottomRight,
                                          &light_bottomRight);
                        _vertex_light_get(neighbors[X_NY_NZ].chunk,
                                          neighbors[X_NY_NZ].block,
                                          palette,
                                          neighbors[X_NY_NZ].coords,
                                          &neighbors[X_NY_NZ].vlight,
                                          &ao_bottomRightFront,
                                          &light_bottomRightFront);

                        // first corner (topRightFront)
                        if (ao_topRight && ao_rightFront) {
                            ao.ao1 = 3;
                        } else if (ao_topRightFront && (ao_topRight || ao_rightFront)) {
                            ao.ao1 = 2;
                        } else if (ao_topRightFront || ao_topRight || ao_rightFront) {
                            ao.ao1 = 1;
                        }
                        vlight1 = neighbors[X].vlight;
                        if (vLighting && (light_topRight || light_rightFront)) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_topRightFront,
                                                    light_topRight,
                                                    light_rightFront,
                                                    neighbors[X_Y_NZ].vlight,
                                                    neighbors[X_Y].vlight,
                                                    neighbors[X_NZ].vlight);
                        }

                        // second corner (bottomRightFront)
                        if (ao_bottomRight && ao_rightFront) {
                            ao.ao2 = 3;
                        } else if (ao_bottomRightFront && (ao_bottomRight || ao_rightFront)) {
                            ao.ao2 = 2;
                        } else if (ao_bottomRightFront || ao_bottomRight || ao_rightFront) {
                            ao.ao2 = 1;
                        }
                        vlight2 = neighbors[X].vlight;
                        if (vLighting && (light_bottomRight || light_rightFront)) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_bottomRightFront,
                                                    light_bottomRight,
                                                    light_rightFront,
                                                    neighbors[X_NY_NZ].vlight,
                                                    neighbors[X_NY].vlight,
                                                    neighbors[X_NZ].vlight);
                        }

                        // third corner (bottomRightback)
                        if (ao_bottomRight && ao_rightBack) {
                            ao.ao3 = 3;
                        } else if (ao_bottomRightBack && (ao_bottomRight || ao_rightBack)) {
                            ao.ao3 = 2;
                        } else if (ao_bottomRightBack || ao_bottomRight || ao_rightBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = neighbors[X].vlight;
                        if (vLighting && (light_bottomRight || light_rightBack)) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_bottomRightBack,
                                                    light_bottomRight,
                                                    light_rightBack,
                                                    neighbors[X_NY_Z].vlight,
                                                    neighbors[X_NY].vlight,
                                                    neighbors[X_Z].vlight);
                        }

                        // 4th corner (topRightBack)
                        if (ao_topRight && ao_rightBack) {
                            ao.ao4 = 3;
                        } else if (ao_topRightBack && (ao_topRight || ao_rightBack)) {
                            ao.ao4 = 2;
                        } else if (ao_topRightBack || ao_topRight || ao_rightBack) {
                            ao.ao4 = 1;
                        }
                        vlight4 = neighbors[X].vlight;
                        if (vLighting && (light_topRight || light_rightBack)) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_topRightBack,
                                                    light_topRight,
                                                    light_rightBack,
                                                    neighbors[X_Y_Z].vlight,
                                                    neighbors[X_Y].vlight,
                                                    neighbors[X_Z].vlight);
                        }

                        vertex_buffer_mem_area_writer_write(
                            selfTransparent ? vbmaw_transparent : vbmaw_opaque,
                            selfTransparent ? ibmaw_transparent : ibmaw_opaque,
                            vertexMap,
                            coords_in_chunk,
                            coords_in_shape,
                            shapeColorIdx,
                            atlasColorIdx,
                            FACE_RIGHT,
                            ao,
                            vLighting,
                            vlight1,
                            vlight2,
                            vlight3,
                            vlight4);
                    }

                    if (renderFront) {
                        ao.ao1 = 0;
                        ao.ao2 = 0;
                        ao.ao3 = 0;
                        ao.ao4 = 0;

                        // get 8 neighbors that can impact ambient occlusion and vertex lighting
                        // left/right blocks may have been retrieved already
                        if (renderRight == false) {
                            neighbors[X_Y_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y + 1,
                                z - 1,
                                &neighbors[X_Y_NZ].chunk,
                                &neighbors[X_Y_NZ].coords);
                            neighbors[X_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y,
                                z - 1,
                                &neighbors[X_NZ].chunk,
                                &neighbors[X_NZ].coords);
                            neighbors[X_NY_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y - 1,
                                z - 1,
                                &neighbors[X_NY_NZ].chunk,
                                &neighbors[X_NY_NZ].coords);
                        }

                        if (renderLeft == false) {
                            neighbors[NX_Y_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y + 1,
                                z - 1,
                                &neighbors[NX_Y_NZ].chunk,
                                &neighbors[NX_Y_NZ].coords);
                            neighbors[NX_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y,
                                z - 1,
                                &neighbors[NX_NZ].chunk,
                                &neighbors[NX_NZ].coords);
                            neighbors[NX_NY_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y - 1,
                                z - 1,
                                &neighbors[NX_NY_NZ].chunk,
                                &neighbors[NX_NY_NZ].coords);
                        }

                        neighbors[Y_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x,
                            y + 1,
                            z - 1,
                            &neighbors[Y_NZ].chunk,
                            &neighbors[Y_NZ].coords);
                        neighbors[NY_NZ].block = chunk_get_block_including_neighbors(
                            chunk,
                            x,
                            y - 1,
                            z - 1,
                            &neighbors[NY_NZ].chunk,
                            &neighbors[NY_NZ].coords);

                        // get their light values & properties
                        if (renderRight == false) {
                            _vertex_light_get(neighbors[X_Y_NZ].chunk,
                                              neighbors[X_Y_NZ].block,
                                              palette,
                                              neighbors[X_Y_NZ].coords,
                                              &neighbors[X_Y_NZ].vlight,
                                              &ao_topRightFront,
                                              &light_topRightFront);
                            _vertex_light_get(neighbors[X_NZ].chunk,
                                              neighbors[X_NZ].block,
                                              palette,
                                              neighbors[X_NZ].coords,
                                              &neighbors[X_NZ].vlight,
                                              &ao_rightFront,
                                              &light_rightFront);
                            _vertex_light_get(neighbors[X_NY_NZ].chunk,
                                              neighbors[X_NY_NZ].block,
                                              palette,
                                              neighbors[X_NY_NZ].coords,
                                              &neighbors[X_NY_NZ].vlight,
                                              &ao_bottomRightFront,
                                              &light_bottomRightFront);
                        }
                        if (renderLeft == false) {
                            _vertex_light_get(neighbors[NX_Y_NZ].chunk,
                                              neighbors[NX_Y_NZ].block,
                                              palette,
                                              neighbors[NX_Y_NZ].coords,
                                              &neighbors[NX_Y_NZ].vlight,
                                              &ao_topLeftFront,
                                              &light_topLeftFront);
                            _vertex_light_get(neighbors[NX_NZ].chunk,
                                              neighbors[NX_NZ].block,
                                              palette,
                                              neighbors[NX_NZ].coords,
                                              &neighbors[NX_NZ].vlight,
                                              &ao_leftFront,
                                              &light_leftFront);
                            _vertex_light_get(neighbors[NX_NY_NZ].chunk,
                                              neighbors[NX_NY_NZ].block,
                                              palette,
                                              neighbors[NX_NY_NZ].coords,
                                              &neighbors[NX_NY_NZ].vlight,
                                              &ao_bottomLeftFront,
                                              &light_bottomLeftFront);
                        }
                        _vertex_light_get(neighbors[Y_NZ].chunk,
                                          neighbors[Y_NZ].block,
                                          palette,
                                          neighbors[Y_NZ].coords,
                                          &neighbors[Y_NZ].vlight,
                                          &ao_topFront,
                                          &light_topFront);
                        _vertex_light_get(neighbors[NY_NZ].chunk,
                                          neighbors[NY_NZ].block,
                                          palette,
                                          neighbors[NY_NZ].coords,
                                          &neighbors[NY_NZ].vlight,
                                          &ao_bottomFront,
                                          &light_bottomFront);

                        // first corner (topLeftFront)
                        if (ao_topFront && ao_leftFront) {
                            ao.ao1 = 3;
                        } else if (ao_topLeftFront && (ao_topFront || ao_leftFront)) {
                            ao.ao1 = 2;
                        } else if (ao_topLeftFront || ao_topFront || ao_leftFront) {
                            ao.ao1 = 1;
                        }
                        vlight1 = neighbors[NZ].vlight;
                        if (vLighting && (light_topFront || light_leftFront)) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_topLeftFront,
                                                    light_topFront,
                                                    light_leftFront,
                                                    neighbors[NX_Y_NZ].vlight,
                                                    neighbors[Y_NZ].vlight,
                                                    neighbors[NX_NZ].vlight);
                        }

                        // second corner (bottomLeftFront)
                        if (ao_bottomFront && ao_leftFront) {
                            ao.ao2 = 3;
                        } else if (ao_bottomLeftFront && (ao_bottomFront || ao_leftFront)) {
                            ao.ao2 = 2;
                        } else if (ao_bottomLeftFront || ao_bottomFront || ao_leftFront) {
                            ao.ao2 = 1;
                        }
                        vlight2 = neighbors[NZ].vlight;
                        if (vLighting && (light_bottomFront || light_leftFront)) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_bottomLeftFront,
                                                    light_bottomFront,
                                                    light_leftFront,
                                                    neighbors[NX_NY_NZ].vlight,
                                                    neighbors[NY_NZ].vlight,
                                                    neighbors[NX_NZ].vlight);
                        }

                        // third corner (bottomRightFront)
                        if (ao_bottomFront && ao_rightFront) {
                            ao.ao3 = 3;
                        } else if (ao_bottomRightFront && (ao_bottomFront || ao_rightFront)) {
                            ao.ao3 = 2;
                        } else if (ao_bottomRightFront || ao_bottomFront || ao_rightFront) {
                            ao.ao3 = 1;
                        }
                        vlight3 = neighbors[NZ].vlight;
                        if (vLighting && (light_bottomFront || light_rightFront)) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_bottomRightFront,
                                                    light_bottomFront,
                                                    light_rightFront,
                                                    neighbors[X_NY_NZ].vlight,
                                                    neighbors[NY_NZ].vlight,
                                                    neighbors[X_NZ].vlight);
                        }

                        // 4th corner (topRightFront)
                        if (ao_topFront && ao_rightFront) {
                            ao.ao4 = 3;
                        } else if (ao_topRightFront && (ao_topFront || ao_rightFront)) {
                            ao.ao4 = 2;
                        } else if (ao_topRightFront || ao_topFront || ao_rightFront) {
                            ao.ao4 = 1;
                        }
                        vlight4 = neighbors[NZ].vlight;
                        if (vLighting && (light_topFront || light_rightFront)) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_topRightFront,
                                                    light_topFront,
                                                    light_rightFront,
                                                    neighbors[X_Y_NZ].vlight,
                                                    neighbors[Y_NZ].vlight,
                                                    neighbors[X_NZ].vlight);
                        }

                        vertex_buffer_mem_area_writer_write(
                            selfTransparent ? vbmaw_transparent : vbmaw_opaque,
                            selfTransparent ? ibmaw_transparent : ibmaw_opaque,
                            vertexMap,
                            coords_in_chunk,
                            coords_in_shape,
                            shapeColorIdx,
                            atlasColorIdx,
                            FACE_BACK,
                            ao,
                            vLighting,
                            vlight1,
                            vlight2,
                            vlight3,
                            vlight4);
                    }

                    if (renderBack) {
                        ao.ao1 = 0;
                        ao.ao2 = 0;
                        ao.ao3 = 0;
                        ao.ao4 = 0;

                        // get 8 neighbors that can impact ambient occlusion and vertex lighting
                        // left/right blocks may have been retrieved already
                        if (renderRight == false) {
                            neighbors[X_Y_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y + 1,
                                z + 1,
                                &neighbors[X_Y_Z].chunk,
                                &neighbors[X_Y_Z].coords);
                            neighbors[X_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y,
                                z + 1,
                                &neighbors[X_Z].chunk,
                                &neighbors[X_Z].coords);
                            neighbors[X_NY_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y - 1,
                                z + 1,
                                &neighbors[X_NY_Z].chunk,
                                &neighbors[X_NY_Z].coords);
                        }

                        if (renderLeft == false) {
                            neighbors[NX_Y_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y + 1,
                                z + 1,
                                &neighbors[NX_Y_Z].chunk,
                                &neighbors[NX_Y_Z].coords);
                            neighbors[NX_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y,
                                z + 1,
                                &neighbors[NX_Z].chunk,
                                &neighbors[NX_Z].coords);
                            neighbors[NX_NY_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y - 1,
                                z + 1,
                                &neighbors[NX_NY_Z].chunk,
                                &neighbors[NX_NY_Z].coords);
                        }

                        neighbors[Y_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x,
                            y + 1,
                            z + 1,
                            &neighbors[Y_Z].chunk,
                            &neighbors[Y_Z].coords);
                        neighbors[NY_Z].block = chunk_get_block_including_neighbors(
                            chunk,
                            x,
                            y - 1,
                            z + 1,
                            &neighbors[NY_Z].chunk,
                            &neighbors[NY_Z].coords);

                        // get their light values & properties
                        if (renderRight == false) {
                            _vertex_light_get(neighbors[X_Y_Z].chunk,
                                              neighbors[X_Y_Z].block,
                                              palette,
                                              neighbors[X_Y_Z].coords,
                                              &neighbors[X_Y_Z].vlight,
                                              &ao_topRightBack,
                                              &light_topRightBack);
                            _vertex_light_get(neighbors[X_Z].chunk,
                                              neighbors[X_Z].block,
                                              palette,
                                              neighbors[X_Z].coords,
                                              &neighbors[X_Z].vlight,
                                              &ao_rightBack,
                                              &light_rightBack);
                            _vertex_light_get(neighbors[X_NY_Z].chunk,
                                              neighbors[X_NY_Z].block,
                                              palette,
                                              neighbors[X_NY_Z].coords,
                                              &neighbors[X_NY_Z].vlight,
                                              &ao_bottomRightBack,
                                              &light_bottomRightBack);
                        }
                        if (renderLeft == false) {
                            _vertex_light_get(neighbors[NX_Y_Z].chunk,
                                              neighbors[NX_Y_Z].block,
                                              palette,
                                              neighbors[NX_Y_Z].coords,
                                              &neighbors[NX_Y_Z].vlight,
                                              &ao_topLeftBack,
                                              &light_topLeftBack);
                            _vertex_light_get(neighbors[NX_Z].chunk,
                                              neighbors[NX_Z].block,
                                              palette,
                                              neighbors[NX_Z].coords,
                                              &neighbors[NX_Z].vlight,
                                              &ao_leftBack,
                                              &light_leftBack);
                            _vertex_light_get(neighbors[NX_NY_Z].chunk,
                                              neighbors[NX_NY_Z].block,
                                              palette,
                                              neighbors[NX_NY_Z].coords,
                                              &neighbors[NX_NY_Z].vlight,
                                              &ao_bottomLeftBack,
                                              &light_bottomLeftBack);
                        }
                        _vertex_light_get(neighbors[Y_Z].chunk,
                                          neighbors[Y_Z].block,
                                          palette,
                                          neighbors[Y_Z].coords,
                                          &neighbors[Y_Z].vlight,
                                          &ao_topBack,
                                          &light_topBack);
                        _vertex_light_get(neighbors[NY_Z].chunk,
                                          neighbors[NY_Z].block,
                                          palette,
                                          neighbors[NY_Z].coords,
                                          &neighbors[NY_Z].vlight,
                                          &ao_bottomBack,
                                          &light_bottomBack);

                        // first corner (bottomLeftBack)
                        if (ao_bottomBack && ao_leftBack) {
                            ao.ao1 = 3;
                        } else if (ao_bottomLeftBack && (ao_bottomBack || ao_leftBack)) {
                            ao.ao1 = 2;
                        } else if (ao_bottomLeftBack || ao_bottomBack || ao_leftBack) {
                            ao.ao1 = 1;
                        }
                        vlight1 = neighbors[Z].vlight;
                        if (vLighting && (light_bottomBack || light_leftBack)) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_bottomLeftBack,
                                                    light_bottomBack,
                                                    light_leftBack,
                                                    neighbors[NX_NY_Z].vlight,
                                                    neighbors[NY_Z].vlight,
                                                    neighbors[NX_Z].vlight);
                        }

                        // second corner (topLeftBack)
                        if (ao_topBack && ao_leftBack) {
                            ao.ao2 = 3;
                        } else if (ao_topLeftBack && (ao_topBack || ao_leftBack)) {
                            ao.ao2 = 2;
                        } else if (ao_topLeftBack || ao_topBack || ao_leftBack) {
                            ao.ao2 = 1;
                        }
                        vlight2 = neighbors[Z].vlight;
                        if (vLighting && (light_topBack || light_leftBack)) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_topLeftBack,
                                                    light_topBack,
                                                    light_leftBack,
                                                    neighbors[NX_Y_Z].vlight,
                                                    neighbors[Y_Z].vlight,
                                                    neighbors[NX_Z].vlight);
                        }

                        // third corner (topRightBack)
                        if (ao_topBack && ao_rightBack) {
                            ao.ao3 = 3;
                        } else if (ao_topRightBack && (ao_topBack || ao_rightBack)) {
                            ao.ao3 = 2;
                        } else if (ao_topRightBack || ao_topBack || ao_rightBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = neighbors[Z].vlight;
                        if (vLighting && (light_topBack || light_rightBack)) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_topRightBack,
                                                    light_topBack,
                                                    light_rightBack,
                                                    neighbors[X_Y_Z].vlight,
                                                    neighbors[Y_Z].vlight,
                                                    neighbors[X_Z].vlight);
                        }

                        // 4th corner (bottomRightBack)
                        if (ao_bottomBack && ao_rightBack) {
                            ao.ao4 = 3;
                        } else if (ao_bottomRightBack && (ao_bottomBack || ao_rightBack)) {
                            ao.ao4 = 2;
                        } else if (ao_bottomRightBack || ao_bottomBack || ao_rightBack) {
                            ao.ao4 = 1;
                        }
                        vlight4 = neighbors[Z].vlight;
                        if (vLighting && (light_bottomBack || light_rightBack)) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_bottomRightBack,
                                                    light_bottomBack,
                                                    light_rightBack,
                                                    neighbors[X_NY_Z].vlight,
                                                    neighbors[NY_Z].vlight,
                                                    neighbors[X_Z].vlight);
                        }

                        vertex_buffer_mem_area_writer_write(
                            selfTransparent ? vbmaw_transparent : vbmaw_opaque,
                            selfTransparent ? ibmaw_transparent : ibmaw_opaque,
                            vertexMap,
                            coords_in_chunk,
                            coords_in_shape,
                            shapeColorIdx,
                            atlasColorIdx,
                            FACE_FRONT,
                            ao,
                            vLighting,
                            vlight1,
                            vlight2,
                            vlight3,
                            vlight4);
                    }

                    if (renderTop) {
                        ao.ao1 = 0;
                        ao.ao2 = 0;
                        ao.ao3 = 0;
                        ao.ao4 = 0;

                        // get 8 neighbors that can impact ambient occlusion and vertex lighting
                        // left/right/back/front blocks may have been retrieved already
                        if (renderLeft == false) {
                            neighbors[NX_Y_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y + 1,
                                z + 1,
                                &neighbors[NX_Y_Z].chunk,
                                &neighbors[NX_Y_Z].coords);
                            neighbors[NX_Y].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y + 1,
                                z,
                                &neighbors[NX_Y].chunk,
                                &neighbors[NX_Y].coords);
                            neighbors[NX_Y_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y + 1,
                                z - 1,
                                &neighbors[NX_Y_NZ].chunk,
                                &neighbors[NX_Y_NZ].coords);
                        }

                        if (renderRight == false) {
                            neighbors[X_Y_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y + 1,
                                z + 1,
                                &neighbors[X_Y_Z].chunk,
                                &neighbors[X_Y_Z].coords);
                            neighbors[X_Y].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y + 1,
                                z,
                                &neighbors[X_Y].chunk,
                                &neighbors[X_Y].coords);
                            neighbors[X_Y_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y + 1,
                                z - 1,
                                &neighbors[X_Y_NZ].chunk,
                                &neighbors[X_Y_NZ].coords);
                        }

                        if (renderBack == false) {
                            neighbors[Y_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x,
                                y + 1,
                                z + 1,
                                &neighbors[Y_Z].chunk,
                                &neighbors[Y_Z].coords);
                        }

                        if (renderFront == false) {
                            neighbors[Y_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x,
                                y + 1,
                                z - 1,
                                &neighbors[Y_NZ].chunk,
                                &neighbors[Y_NZ].coords);
                        }

                        // get their light values & properties
                        if (renderLeft == false) {
                            _vertex_light_get(neighbors[NX_Y_Z].chunk,
                                              neighbors[NX_Y_Z].block,
                                              palette,
                                              neighbors[NX_Y_Z].coords,
                                              &neighbors[NX_Y_Z].vlight,
                                              &ao_topLeftBack,
                                              &light_topLeftBack);
                            _vertex_light_get(neighbors[NX_Y].chunk,
                                              neighbors[NX_Y].block,
                                              palette,
                                              neighbors[NX_Y].coords,
                                              &neighbors[NX_Y].vlight,
                                              &ao_topLeft,
                                              &light_topLeft);
                            _vertex_light_get(neighbors[NX_Y_NZ].chunk,
                                              neighbors[NX_Y_NZ].block,
                                              palette,
                                              neighbors[NX_Y_NZ].coords,
                                              &neighbors[NX_Y_NZ].vlight,
                                              &ao_topLeftFront,
                                              &light_topLeftFront);
                        }
                        if (renderRight == false) {
                            _vertex_light_get(neighbors[X_Y_Z].chunk,
                                              neighbors[X_Y_Z].block,
                                              palette,
                                              neighbors[X_Y_Z].coords,
                                              &neighbors[X_Y_Z].vlight,
                                              &ao_topRightBack,
                                              &light_topRightBack);
                            _vertex_light_get(neighbors[X_Y].chunk,
                                              neighbors[X_Y].block,
                                              palette,
                                              neighbors[X_Y].coords,
                                              &neighbors[X_Y].vlight,
                                              &ao_topRight,
                                              &light_topRight);
                            _vertex_light_get(neighbors[X_Y_NZ].chunk,
                                              neighbors[X_Y_NZ].block,
                                              palette,
                                              neighbors[X_Y_NZ].coords,
                                              &neighbors[X_Y_NZ].vlight,
                                              &ao_topRightFront,
                                              &light_topRightFront);
                        }
                        if (renderBack == false) {
                            _vertex_light_get(neighbors[Y_Z].chunk,
                                              neighbors[Y_Z].block,
                                              palette,
                                              neighbors[Y_Z].coords,
                                              &neighbors[Y_Z].vlight,
                                              &ao_topBack,
                                              &light_topBack);
                        }
                        if (renderFront == false) {
                            _vertex_light_get(neighbors[Y_NZ].chunk,
                                              neighbors[Y_NZ].block,
                                              palette,
                                              neighbors[Y_NZ].coords,
                                              &neighbors[Y_NZ].vlight,
                                              &ao_topFront,
                                              &light_topFront);
                        }

                        // first corner (topRightFront)
                        if (ao_topRight && ao_topFront) {
                            ao.ao1 = 3;
                        } else if (ao_topRightFront && (ao_topRight || ao_topFront)) {
                            ao.ao1 = 2;
                        } else if (ao_topRightFront || ao_topRight || ao_topFront) {
                            ao.ao1 = 1;
                        }
                        vlight1 = neighbors[Y].vlight;
                        if (vLighting && (light_topRight || light_topFront)) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_topRightFront,
                                                    light_topRight,
                                                    light_topFront,
                                                    neighbors[X_Y_NZ].vlight,
                                                    neighbors[X_Y].vlight,
                                                    neighbors[Y_NZ].vlight);
                        }

                        // second corner (topRightBack)
                        if (ao_topRight && ao_topBack) {
                            ao.ao2 = 3;
                        } else if (ao_topRightBack && (ao_topRight || ao_topBack)) {
                            ao.ao2 = 2;
                        } else if (ao_topRightBack || ao_topRight || ao_topBack) {
                            ao.ao2 = 1;
                        }
                        vlight2 = neighbors[Y].vlight;
                        if (vLighting && (light_topRight || light_topBack)) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_topRightBack,
                                                    light_topRight,
                                                    light_topBack,
                                                    neighbors[X_Y_Z].vlight,
                                                    neighbors[X_Y].vlight,
                                                    neighbors[Y_Z].vlight);
                        }

                        // third corner (topLeftBack)
                        if (ao_topLeft && ao_topBack) {
                            ao.ao3 = 3;
                        } else if (ao_topLeftBack && (ao_topLeft || ao_topBack)) {
                            ao.ao3 = 2;
                        } else if (ao_topLeftBack || ao_topLeft || ao_topBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = neighbors[Y].vlight;
                        if (vLighting && (light_topLeft || light_topBack)) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_topLeftBack,
                                                    light_topLeft,
                                                    light_topBack,
                                                    neighbors[NX_Y_Z].vlight,
                                                    neighbors[NX_Y].vlight,
                                                    neighbors[Y_Z].vlight);
                        }

                        // 4th corner (topLeftFront)
                        if (ao_topLeft && ao_topFront) {
                            ao.ao4 = 3;
                        } else if (ao_topLeftFront && (ao_topLeft || ao_topFront)) {
                            ao.ao4 = 2;
                        } else if (ao_topLeftFront || ao_topLeft || ao_topFront) {
                            ao.ao4 = 1;
                        }
                        vlight4 = neighbors[Y].vlight;
                        if (vLighting && (light_topLeft || light_topFront)) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_topLeftFront,
                                                    light_topLeft,
                                                    light_topFront,
                                                    neighbors[NX_Y_NZ].vlight,
                                                    neighbors[NX_Y].vlight,
                                                    neighbors[Y_NZ].vlight);
                        }

                        vertex_buffer_mem_area_writer_write(
                            selfTransparent ? vbmaw_transparent : vbmaw_opaque,
                            selfTransparent ? ibmaw_transparent : ibmaw_opaque,
                            vertexMap,
                            coords_in_chunk,
                            coords_in_shape,
                            shapeColorIdx,
                            atlasColorIdx,
                            FACE_TOP,
                            ao,
                            vLighting,
                            vlight1,
                            vlight2,
                            vlight3,
                            vlight4);
                    }

                    if (renderBottom) {
                        ao.ao1 = 0;
                        ao.ao2 = 0;
                        ao.ao3 = 0;
                        ao.ao4 = 0;

                        // get 8 neighbors that can impact ambient occlusion and vertex lighting
                        // left/right/back/front blocks may have been retrieved already
                        if (renderLeft == false) {
                            neighbors[NX_NY_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y - 1,
                                z + 1,
                                &neighbors[NX_NY_Z].chunk,
                                &neighbors[NX_NY_Z].coords);
                            neighbors[NX_NY].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y - 1,
                                z,
                                &neighbors[NX_NY].chunk,
                                &neighbors[NX_NY].coords);
                            neighbors[NX_NY_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x - 1,
                                y - 1,
                                z - 1,
                                &neighbors[NX_NY_NZ].chunk,
                                &neighbors[NX_NY_NZ].coords);
                        }

                        if (renderRight == false) {
                            neighbors[X_NY_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y - 1,
                                z + 1,
                                &neighbors[X_NY_Z].chunk,
                                &neighbors[X_NY_Z].coords);
                            neighbors[X_NY].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y - 1,
                                z,
                                &neighbors[X_NY].chunk,
                                &neighbors[X_NY].coords);
                            neighbors[X_NY_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x + 1,
                                y - 1,
                                z - 1,
                                &neighbors[X_NY_NZ].chunk,
                                &neighbors[X_NY_NZ].coords);
                        }

                        if (renderBack == false) {
                            neighbors[NY_Z].block = chunk_get_block_including_neighbors(
                                chunk,
                                x,
                                y - 1,
                                z + 1,
                                &neighbors[NY_Z].chunk,
                                &neighbors[NY_Z].coords);
                        }

                        if (renderFront == false) {
                            neighbors[NY_NZ].block = chunk_get_block_including_neighbors(
                                chunk,
                                x,
                                y - 1,
                                z - 1,
                                &neighbors[NY_NZ].chunk,
                                &neighbors[NY_NZ].coords);
                        }

                        // get their light values & properties
                        if (renderLeft == false) {
                            _vertex_light_get(neighbors[NX_NY_Z].chunk,
                                              neighbors[NX_NY_Z].block,
                                              palette,
                                              neighbors[NX_NY_Z].coords,
                                              &neighbors[NX_NY_Z].vlight,
                                              &ao_bottomLeftBack,
                                              &light_bottomLeftBack);
                            _vertex_light_get(neighbors[NX_NY].chunk,
                                              neighbors[NX_NY].block,
                                              palette,
                                              neighbors[NX_NY].coords,
                                              &neighbors[NX_NY].vlight,
                                              &ao_bottomLeft,
                                              &light_bottomLeft);
                            _vertex_light_get(neighbors[NX_NY_NZ].chunk,
                                              neighbors[NX_NY_NZ].block,
                                              palette,
                                              neighbors[NX_NY_NZ].coords,
                                              &neighbors[NX_NY_NZ].vlight,
                                              &ao_bottomLeftFront,
                                              &light_bottomLeftFront);
                        }
                        if (renderRight == false) {
                            _vertex_light_get(neighbors[X_NY_Z].chunk,
                                              neighbors[X_NY_Z].block,
                                              palette,
                                              neighbors[X_NY_Z].coords,
                                              &neighbors[X_NY_Z].vlight,
                                              &ao_bottomRightBack,
                                              &light_bottomRightBack);
                            _vertex_light_get(neighbors[X_NY].chunk,
                                              neighbors[X_NY].block,
                                              palette,
                                              neighbors[X_NY].coords,
                                              &neighbors[X_NY].vlight,
                                              &ao_bottomRight,
                                              &light_bottomRight);
                            _vertex_light_get(neighbors[X_NY_NZ].chunk,
                                              neighbors[X_NY_NZ].block,
                                              palette,
                                              neighbors[X_NY_NZ].coords,
                                              &neighbors[X_NY_NZ].vlight,
                                              &ao_bottomRightFront,
                                              &light_bottomRightFront);
                        }
                        if (renderBack == false) {
                            _vertex_light_get(neighbors[NY_Z].chunk,
                                              neighbors[NY_Z].block,
                                              palette,
                                              neighbors[NY_Z].coords,
                                              &neighbors[NY_Z].vlight,
                                              &ao_bottomBack,
                                              &light_bottomBack);
                        }
                        if (renderFront == false) {
                            _vertex_light_get(neighbors[NY_NZ].chunk,
                                              neighbors[NY_NZ].block,
                                              palette,
                                              neighbors[NY_NZ].coords,
                                              &neighbors[NY_NZ].vlight,
                                              &ao_bottomFront,
                                              &light_bottomFront);
                        }

                        // first corner (bottomLeftFront)
                        if (ao_bottomLeft && ao_bottomFront) {
                            ao.ao1 = 3;
                        } else if (ao_bottomLeftFront && (ao_bottomLeft || ao_bottomFront)) {
                            ao.ao1 = 2;
                        } else if (ao_bottomLeftFront || ao_bottomLeft || ao_bottomFront) {
                            ao.ao1 = 1;
                        }
                        vlight1 = neighbors[NY].vlight;
                        if (vLighting && (light_bottomLeft || light_bottomFront)) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_bottomLeftFront,
                                                    light_bottomLeft,
                                                    light_bottomFront,
                                                    neighbors[NX_NY_NZ].vlight,
                                                    neighbors[NX_NY].vlight,
                                                    neighbors[NY_NZ].vlight);
                        }

                        // second corner (bottomLeftBack)
                        if (ao_bottomLeft && ao_bottomBack) {
                            ao.ao2 = 3;
                        } else if (ao_bottomLeftBack && (ao_bottomLeft || ao_bottomBack)) {
                            ao.ao2 = 2;
                        } else if (ao_bottomLeftBack || ao_bottomLeft || ao_bottomBack) {
                            ao.ao2 = 1;
                        }
                        vlight2 = neighbors[NY].vlight;
                        if (vLighting && (light_bottomLeft || light_bottomBack)) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_bottomLeftBack,
                                                    light_bottomLeft,
                                                    light_bottomBack,
                                                    neighbors[NX_NY_Z].vlight,
                                                    neighbors[NX_NY].vlight,
                                                    neighbors[NY_Z].vlight);
                        }

                        // second corner (bottomRightBack)
                        if (ao_bottomRight && ao_bottomBack) {
                            ao.ao3 = 3;
                        } else if (ao_bottomRightBack && (ao_bottomRight || ao_bottomBack)) {
                            ao.ao3 = 2;
                        } else if (ao_bottomRightBack || ao_bottomRight || ao_bottomBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = neighbors[NY].vlight;
                        if (vLighting && (light_bottomRight || light_bottomBack)) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_bottomRightBack,
                                                    light_bottomRight,
                                                    light_bottomBack,
                                                    neighbors[X_NY_Z].vlight,
                                                    neighbors[X_NY].vlight,
                                                    neighbors[NY_Z].vlight);
                        }

                        // second corner (bottomRightFront)
                        if (ao_bottomRight && ao_bottomFront) {
                            ao.ao4 = 3;
                        } else if (ao_bottomRightFront && (ao_bottomRight || ao_bottomFront)) {
                            ao.ao4 = 2;
                        } else if (ao_bottomRightFront || ao_bottomRight || ao_bottomFront) {
                            ao.ao4 = 1;
                        }
                        vlight4 = neighbors[NY].vlight;
                        if (vLighting && (light_bottomRight || light_bottomFront)) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_bottomRightFront,
                                                    light_bottomRight,
                                                    light_bottomFront,
                                                    neighbors[X_NY_NZ].vlight,
                                                    neighbors[X_NY].vlight,
                                                    neighbors[NY_NZ].vlight);
                        }

                        vertex_buffer_mem_area_writer_write(
                            selfTransparent ? vbmaw_transparent : vbmaw_opaque,
                            selfTransparent ? ibmaw_transparent : ibmaw_opaque,
                            vertexMap,
                            coords_in_chunk,
                            coords_in_shape,
                            shapeColorIdx,
                            atlasColorIdx,
                            FACE_DOWN,
                            ao,
                            vLighting,
                            vlight1,
                            vlight2,
                            vlight3,
                            vlight4);
                    }
                }
            }
        }
    }

    hash_uint32_free(vertexMap);

    vertex_buffer_mem_area_writer_done(vbmaw_opaque, false);
    vertex_buffer_mem_area_writer_free(vbmaw_opaque);
    vertex_buffer_mem_area_writer_done(ibmaw_opaque, false);
    vertex_buffer_mem_area_writer_free(ibmaw_opaque);
#if ENABLE_TRANSPARENCY
    vertex_buffer_mem_area_writer_done(vbmaw_transparent, false);
    vertex_buffer_mem_area_writer_free(vbmaw_transparent);
    vertex_buffer_mem_area_writer_done(ibmaw_transparent, false);
    vertex_buffer_mem_area_writer_free(ibmaw_transparent);
#endif
}

// MARK: private functions

Octree *_chunk_new_octree(void) {
    unsigned long upPow2Size = upper_power_of_two(CHUNK_SIZE);
    Block *defaultBlock = block_new_air();

    Octree *o = NULL;
    switch (upPow2Size) {
        case 1:
            o = octree_new_with_default_element(octree_1x1x1, defaultBlock, sizeof(Block));
            break;
        case 2:
            o = octree_new_with_default_element(octree_2x2x2, defaultBlock, sizeof(Block));
            break;
        case 4:
            o = octree_new_with_default_element(octree_4x4x4, defaultBlock, sizeof(Block));
            break;
        case 8:
            o = octree_new_with_default_element(octree_8x8x8, defaultBlock, sizeof(Block));
            break;
        case 16:
            o = octree_new_with_default_element(octree_16x16x16, defaultBlock, sizeof(Block));
            break;
        case 32:
            o = octree_new_with_default_element(octree_32x32x32, defaultBlock, sizeof(Block));
            break;
        case 64:
            o = octree_new_with_default_element(octree_64x64x64, defaultBlock, sizeof(Block));
            break;
        case 128:
            o = octree_new_with_default_element(octree_128x128x128, defaultBlock, sizeof(Block));
            break;
        case 256:
            o = octree_new_with_default_element(octree_256x256x256, defaultBlock, sizeof(Block));
            break;
        case 512:
            o = octree_new_with_default_element(octree_512x512x512, defaultBlock, sizeof(Block));
            break;
        case 1024:
            o = octree_new_with_default_element(octree_1024x1024x1024, defaultBlock, sizeof(Block));
            break;
        default:
            cclog_error("🔥 chunk is too big to use an octree.");
            break;
    }

    block_free(defaultBlock);

    return o;
}

void _chunk_flush_buffers(Chunk *c) {
    if (c->vbma_opaque != NULL) {
        vertex_buffer_mem_area_flush(c->vbma_opaque);
    }
    c->vbma_opaque = NULL;

    if (c->ibma_opaque != NULL) {
        vertex_buffer_mem_area_flush(c->ibma_opaque);
    }
    c->ibma_opaque = NULL;

    if (c->vbma_transparent != NULL) {
        vertex_buffer_mem_area_flush(c->vbma_transparent);
    }
    c->vbma_transparent = NULL;

    if (c->ibma_transparent != NULL) {
        vertex_buffer_mem_area_flush(c->ibma_transparent);
    }
    c->ibma_transparent = NULL;
}

void _chunk_hello_neighbor(Chunk *newcomer,
                           Neighbor newcomerLocation,
                           Chunk *neighbor,
                           Neighbor neighborLocation) {
    if (neighbor == NULL)
        return;

    newcomer->neighbors[neighborLocation] = neighbor;
    neighbor->neighbors[newcomerLocation] = newcomer;
}

void _chunk_good_bye_neighbor(Chunk *chunk, Neighbor location) {
    if (chunk == NULL)
        return;
    chunk->neighbors[location] = NULL;
}

void _vertex_light_get(Chunk *chunk,
                       Block *block,
                       const ColorPalette *palette,
                       CHUNK_COORDS_INT3_T coords,
                       VERTEX_LIGHT_STRUCT_T *vlight,
                       bool *aoCaster,
                       bool *lightCaster) {

    bool opaque;
    block_is_any(block, palette, NULL, &opaque, NULL, aoCaster, lightCaster);
    *vlight = chunk_get_light_or_default(chunk, coords, block == NULL || opaque);
}

void _vertex_light_smoothing(VERTEX_LIGHT_STRUCT_T *base,
                             bool add1,
                             bool add2,
                             bool add3,
                             VERTEX_LIGHT_STRUCT_T vlight1,
                             VERTEX_LIGHT_STRUCT_T vlight2,
                             VERTEX_LIGHT_STRUCT_T vlight3) {

#if GLOBAL_LIGHTING_SMOOTHING_ENABLED
    VERTEX_LIGHT_STRUCT_T light;
    uint8_t count = 1;
    uint8_t ambient = base->ambient;
    uint8_t red = base->red;
    uint8_t green = base->green;
    uint8_t blue = base->blue;

    if (add1) {
        light = vlight1;
#if VERTEX_LIGHT_SMOOTHING == 1
        ambient = minimum(ambient, light.ambient);
#elif VERTEX_LIGHT_SMOOTHING == 2
        ambient = maximum(ambient, light.ambient);
#else
        ambient += light.ambient;
#endif
        red += light.red;
        green += light.green;
        blue += light.blue;
        count++;
    }
    if (add2) {
        light = vlight2;
#if VERTEX_LIGHT_SMOOTHING == 1
        ambient = minimum(ambient, light.ambient);
#elif VERTEX_LIGHT_SMOOTHING == 2
        ambient = maximum(ambient, light.ambient);
#else
        ambient += light.ambient;
#endif
        red += light.red;
        green += light.green;
        blue += light.blue;
        count++;
    }
    if (add3) {
        light = vlight3;
#if VERTEX_LIGHT_SMOOTHING == 1
        ambient = minimum(ambient, light.ambient);
#elif VERTEX_LIGHT_SMOOTHING == 2
        ambient = maximum(ambient, light.ambient);
#else
        ambient += light.ambient;
#endif
        red += light.red;
        green += light.green;
        blue += light.blue;
        count++;
    }

#if VERTEX_LIGHT_SMOOTHING == 1
    // 0x0F takes into account the 4 least significant bits
    base->ambient = (uint8_t)(ambient & 0x0F);
#elif VERTEX_LIGHT_SMOOTHING == 2
    base->ambient = (uint8_t)(ambient & 0x0F);
#else
    base->ambient = (uint8_t)((ambient / count) & 0x0F);
#endif
    base->red = (uint8_t)((red / count) & 0x0F);
    base->green = (uint8_t)((green / count) & 0x0F);
    base->blue = (uint8_t)((blue / count) & 0x0F);

#endif /* GLOBAL_LIGHTING_SMOOTHING_ENABLED */
}

bool _chunk_is_bounding_box_empty(const Chunk *chunk) {
    return chunk->bbMin.x == chunk->bbMax.x || chunk->bbMin.y == chunk->bbMax.y ||
           chunk->bbMin.z == chunk->bbMax.z;
}

void _chunk_update_bounding_box(Chunk *chunk,
                                const CHUNK_COORDS_INT3_T coords,
                                const bool addOrRemove) {
    if (addOrRemove) {
        if (_chunk_is_bounding_box_empty(chunk)) {
            chunk->bbMin = coords;
            chunk->bbMax = (CHUNK_COORDS_INT3_T){coords.x + 1, coords.y + 1, coords.z + 1};
        } else {
            chunk->bbMin.x = minimum(chunk->bbMin.x, coords.x);
            chunk->bbMin.y = minimum(chunk->bbMin.y, coords.y);
            chunk->bbMin.z = minimum(chunk->bbMin.z, coords.z);
            chunk->bbMax.x = maximum(chunk->bbMax.x, coords.x + 1);
            chunk->bbMax.y = maximum(chunk->bbMax.y, coords.y + 1);
            chunk->bbMax.z = maximum(chunk->bbMax.z, coords.z + 1);
        }
    } else if (_chunk_is_bounding_box_empty(chunk) == false) {
        // for each BB side the removed block was in, check if that side can be moved in
        if (coords.x == chunk->bbMax.x - 1) {
            Block *b;
            bool isEmpty = true;
            for (CHUNK_COORDS_INT_T x = chunk->bbMax.x - 1; isEmpty && x >= chunk->bbMin.x; --x) {
                for (CHUNK_COORDS_INT_T z = chunk->bbMin.z; z < chunk->bbMax.z; ++z) {
                    for (CHUNK_COORDS_INT_T y = chunk->bbMin.y; y < chunk->bbMax.y; ++y) {
                        b = (Block *)octree_get_element_without_checking(chunk->octree,
                                                                         (size_t)x,
                                                                         (size_t)y,
                                                                         (size_t)z);
                        if (block_is_solid(b)) {
                            isEmpty = false;
                            break;
                        }
                    }
                    if (isEmpty == false) {
                        break;
                    }
                }
                if (isEmpty) {
                    chunk->bbMax.x--;
                }
            }
        } else if (coords.x == chunk->bbMin.x) {
            Block *b;
            bool isEmpty = true;
            for (CHUNK_COORDS_INT_T x = chunk->bbMin.x; isEmpty && x < chunk->bbMax.x; ++x) {
                for (CHUNK_COORDS_INT_T z = chunk->bbMin.z; z < chunk->bbMax.z; ++z) {
                    for (CHUNK_COORDS_INT_T y = chunk->bbMin.y; y < chunk->bbMax.y; ++y) {
                        b = (Block *)octree_get_element_without_checking(chunk->octree,
                                                                         (size_t)x,
                                                                         (size_t)y,
                                                                         (size_t)z);
                        if (block_is_solid(b)) {
                            isEmpty = false;
                            break;
                        }
                    }
                    if (isEmpty == false) {
                        break;
                    }
                }
                if (isEmpty) {
                    chunk->bbMin.x++;
                }
            }
        }
        if (coords.y == chunk->bbMax.y - 1) {
            Block *b;
            bool isEmpty = true;
            for (CHUNK_COORDS_INT_T y = chunk->bbMax.y - 1; isEmpty && y >= chunk->bbMin.y; --y) {
                for (CHUNK_COORDS_INT_T z = chunk->bbMin.z; z < chunk->bbMax.z; ++z) {
                    for (CHUNK_COORDS_INT_T x = chunk->bbMin.x; x < chunk->bbMax.x; ++x) {
                        b = (Block *)octree_get_element_without_checking(chunk->octree,
                                                                         (size_t)x,
                                                                         (size_t)y,
                                                                         (size_t)z);
                        if (block_is_solid(b)) {
                            isEmpty = false;
                            break;
                        }
                    }
                    if (isEmpty == false) {
                        break;
                    }
                }
                if (isEmpty) {
                    chunk->bbMax.y--;
                }
            }
        } else if (coords.y == chunk->bbMin.y) {
            Block *b;
            bool isEmpty = true;
            for (CHUNK_COORDS_INT_T y = chunk->bbMin.y; isEmpty && y < chunk->bbMax.y; ++y) {
                for (CHUNK_COORDS_INT_T z = chunk->bbMin.z; z < chunk->bbMax.z; ++z) {
                    for (CHUNK_COORDS_INT_T x = chunk->bbMin.x; x < chunk->bbMax.x; ++x) {
                        b = (Block *)octree_get_element_without_checking(chunk->octree,
                                                                         (size_t)x,
                                                                         (size_t)y,
                                                                         (size_t)z);
                        if (block_is_solid(b)) {
                            isEmpty = false;
                            break;
                        }
                    }
                    if (isEmpty == false) {
                        break;
                    }
                }
                if (isEmpty) {
                    chunk->bbMin.y++;
                }
            }
        }
        if (coords.z == chunk->bbMax.z - 1) {
            Block *b;
            bool isEmpty = true;
            for (CHUNK_COORDS_INT_T z = chunk->bbMax.z - 1; isEmpty && z >= chunk->bbMin.z; --z) {
                for (CHUNK_COORDS_INT_T x = chunk->bbMin.x; x < chunk->bbMax.x; ++x) {
                    for (CHUNK_COORDS_INT_T y = chunk->bbMin.y; y < chunk->bbMax.y; ++y) {
                        b = (Block *)octree_get_element_without_checking(chunk->octree,
                                                                         (size_t)x,
                                                                         (size_t)y,
                                                                         (size_t)z);
                        if (block_is_solid(b)) {
                            isEmpty = false;
                            break;
                        }
                    }
                    if (isEmpty == false) {
                        break;
                    }
                }
                if (isEmpty) {
                    chunk->bbMax.z--;
                }
            }
        } else if (coords.z == chunk->bbMin.z) {
            Block *b;
            bool isEmpty = true;
            for (CHUNK_COORDS_INT_T z = chunk->bbMin.z; isEmpty && z < chunk->bbMax.z; ++z) {
                for (CHUNK_COORDS_INT_T x = chunk->bbMin.x; x < chunk->bbMax.x; ++x) {
                    for (CHUNK_COORDS_INT_T y = chunk->bbMin.y; y < chunk->bbMax.y; ++y) {
                        b = (Block *)octree_get_element_without_checking(chunk->octree,
                                                                         (size_t)x,
                                                                         (size_t)y,
                                                                         (size_t)z);
                        if (block_is_solid(b)) {
                            isEmpty = false;
                            break;
                        }
                    }
                    if (isEmpty == false) {
                        break;
                    }
                }
                if (isEmpty) {
                    chunk->bbMin.z++;
                }
            }
        }
    }
}
