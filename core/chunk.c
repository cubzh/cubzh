// -------------------------------------------------------------
//  Cubzh Core
//  chunk.c
//  Created by Adrien Duermael on July 18, 2015.
// -------------------------------------------------------------

#include "chunk.h"

#include <stdlib.h>
#include <string.h>

#include "cclog.h"
#include "index3d.h"
#include "vertextbuffer.h"

#define CHUNK_NEIGHBORS_COUNT 26

// chunk structure definition
struct _Chunk {
    // 26 possible chunk neighbors used for fast access
    // when updating chunk data/vertices
    Chunk *neighbors[CHUNK_NEIGHBORS_COUNT]; /* 8 bytes */
    // octree partitioning this chunk's blocks
    Octree *octree; /* 8 bytes */
    // reference to shape chunks rtree leaf node, used for removal
    void *rtreeLeaf; /* 8 bytes */
    // first opaque/transparent vbma reserved for that chunk, this can be chained across several vb
    VertexBufferMemArea *vbma_opaque;      /* 8 bytes */
    VertexBufferMemArea *vbma_transparent; /* 8 bytes */
    // number of blocks in that chunk
    int nbBlocks; /* 4 bytes */
    // position of chunk in shape's model
    SHAPE_COORDS_INT3_T origin; /* 3 * 2 bytes */
    // wether vertices need to be refreshed
    bool dirty; /* 1 byte */

    // padding
    char pad[5];
};

// MARK: private functions prototypes

Octree *_chunk_new_octree(void);

void _chunk_hello_neighbor(Chunk *newcomer,
                           Neighbor newcomerLocation,
                           Chunk *neighbor,
                           Neighbor neighborLocation);
void _chunk_good_bye_neighbor(Chunk *chunk, Neighbor location);
Block *_chunk_get_block_including_neighbors(const Chunk *chunk,
                                            const CHUNK_COORDS_INT_T x,
                                            const CHUNK_COORDS_INT_T y,
                                            const CHUNK_COORDS_INT_T z);

/// used to gather vertex lighting values & properties in chunk_write_vertices
void _vertex_light_get(Shape *transformWithShape,
                       Block *block,
                       const ColorPalette *palette,
                       SHAPE_COORDS_INT_T x,
                       SHAPE_COORDS_INT_T y,
                       SHAPE_COORDS_INT_T z,
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

// MARK: public functions

Chunk *chunk_new(const SHAPE_COORDS_INT_T x,
                 const SHAPE_COORDS_INT_T y,
                 const SHAPE_COORDS_INT_T z) {

    Chunk *chunk = (Chunk *)malloc(sizeof(Chunk));
    if (chunk == NULL) {
        return NULL;
    }
    chunk->octree = _chunk_new_octree();
    chunk->rtreeLeaf = NULL;
    chunk->dirty = false;
    chunk->origin = (SHAPE_COORDS_INT3_T){x, y, z};
    chunk->nbBlocks = 0;

    for (int i = 0; i < CHUNK_NEIGHBORS_COUNT; i++) {
        chunk->neighbors[i] = NULL;
    }

    chunk->vbma_opaque = NULL;
    chunk->vbma_transparent = NULL;

    return chunk;
}

void chunk_free(Chunk *chunk, bool updateNeighbors) {
    if (updateNeighbors) {
        chunk_leave_neighborhood(chunk);
    }

    octree_free(chunk->octree);

    if (chunk->vbma_opaque != NULL) {
        vertex_buffer_mem_area_flush(chunk->vbma_opaque);
    }
    chunk->vbma_opaque = NULL;

    if (chunk->vbma_transparent != NULL) {
        vertex_buffer_mem_area_flush(chunk->vbma_transparent);
    }
    chunk->vbma_transparent = NULL;

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
    return octree_get_hash(c->octree, crc);
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

    Block *b = (Block *)
        octree_get_element_without_checking(chunk->octree, (size_t)x, (size_t)y, (size_t)z);
    return block_is_solid(b) ? b : NULL;
}

Block *chunk_get_block_2(const Chunk *chunk, CHUNK_COORDS_INT3_T coords) {
    return chunk_get_block(chunk, coords.x, coords.y, coords.z);
}

void chunk_get_block_pos(const Chunk *chunk,
                         const CHUNK_COORDS_INT_T x,
                         const CHUNK_COORDS_INT_T y,
                         const CHUNK_COORDS_INT_T z,
                         SHAPE_COORDS_INT3_T *pos) {
    pos->x = x + chunk->origin.x;
    pos->y = y + chunk->origin.y;
    pos->z = z + chunk->origin.z;
}

void chunk_get_bounding_box(const Chunk *chunk, float3 *min, float3 *max) {
    SHAPE_COORDS_INT3_T min_coords = {CHUNK_SIZE_MINUS_ONE,
                                      CHUNK_SIZE_MINUS_ONE,
                                      CHUNK_SIZE_MINUS_ONE};
    SHAPE_COORDS_INT3_T max_coords = {0, 0, 0};

    Block *b;
    bool at_least_one_block = false;

    for (uint8_t x = 0; x < CHUNK_SIZE; ++x) {
        for (uint8_t z = 0; z < CHUNK_SIZE; ++z) {
            for (uint8_t y = 0; y < CHUNK_SIZE; ++y) {
                b = (Block *)octree_get_element_without_checking(chunk->octree,
                                                                 (size_t)x,
                                                                 (size_t)y,
                                                                 (size_t)z);
                if (block_is_solid(b)) {
                    at_least_one_block = true;
                    min_coords.x = minimum(min_coords.x, x);
                    min_coords.y = minimum(min_coords.y, y);
                    min_coords.z = minimum(min_coords.z, z);
                    max_coords.x = maximum(max_coords.x, x);
                    max_coords.y = maximum(max_coords.y, y);
                    max_coords.z = maximum(max_coords.z, z);
                }
            }
        }
    }

    // no block: all values should be set to 0
    if (at_least_one_block == false) {
        cclog_warning("chunk_get_bounding_box called on empty chunk");
        min_coords.x = 0;
        min_coords.y = 0;
        min_coords.z = 0;
    } else {
        // otherwise, max values should be incremented
        max_coords.x += 1;
        max_coords.y += 1;
        max_coords.z += 1;
    }

    min->x = (float)min_coords.x;
    min->y = (float)min_coords.y;
    min->z = (float)min_coords.z;
    max->x = (float)max_coords.x;
    max->y = (float)max_coords.y;
    max->z = (float)max_coords.z;
}

// MARK: - Neighbors -

Chunk *chunk_get_neighbor(const Chunk *chunk, Neighbor location) {
    return chunk->neighbors[location];
}

void chunk_move_in_neighborhood(Index3D *chunks, Chunk *chunk, const int3 *chunk_coords) {
    void **batchedNode_X = NULL, **batchedNode_Y = NULL;

    // Batch Index3D search for all neighbors on the right (x+1)
    Chunk *x = NULL, *x_y = NULL, *x_y_z = NULL, *x_y_nz = NULL, *x_ny = NULL, *x_ny_z = NULL,
          *x_ny_nz = NULL, *x_z = NULL, *x_nz = NULL;

    index3d_batch_get_reset(chunks, &batchedNode_X);
    if (index3d_batch_get_advance(chunk_coords->x + 1, &batchedNode_X)) {
        // y batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y, &batchedNode_Y)) {
            x = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            x_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            x_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
        }

        // y+1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y + 1, &batchedNode_Y)) {
            x_y = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            x_y_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            x_y_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
        }

        // y-1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y - 1, &batchedNode_Y)) {
            x_ny = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            x_ny_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            x_ny_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
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
    if (index3d_batch_get_advance(chunk_coords->x - 1, &batchedNode_X)) {
        // y batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y, &batchedNode_Y)) {
            nx = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            nx_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            nx_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
        }

        // y+1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y + 1, &batchedNode_Y)) {
            nx_y = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            nx_y_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            nx_y_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
        }

        // y-1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y - 1, &batchedNode_Y)) {
            nx_ny = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            nx_ny_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            nx_ny_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
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
    if (index3d_batch_get_advance(chunk_coords->x, &batchedNode_X)) {
        // y batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y, &batchedNode_Y)) {
            z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
        }

        // y+1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y + 1, &batchedNode_Y)) {
            y = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            y_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            y_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
        }

        // y-1 batch
        batchedNode_Y = batchedNode_X;
        if (index3d_batch_get_advance(chunk_coords->y - 1, &batchedNode_Y)) {
            ny = index3d_batch_get(chunk_coords->z, batchedNode_Y);
            ny_z = index3d_batch_get(chunk_coords->z + 1, batchedNode_Y);
            ny_nz = index3d_batch_get(chunk_coords->z - 1, batchedNode_Y);
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

void chunk_set_vbma(Chunk *chunk, void *vbma, bool transparent) {
    if (transparent) {
        chunk->vbma_transparent = (VertexBufferMemArea *)vbma;
    } else {
        chunk->vbma_opaque = (VertexBufferMemArea *)vbma;
    }
}

void chunk_write_vertices(Shape *shape, Chunk *chunk) {
    ColorPalette *palette = shape_get_palette(shape);

    VertexBufferMemAreaWriter *opaqueWriter = vertex_buffer_mem_area_writer_new(shape,
                                                                                chunk,
                                                                                chunk->vbma_opaque,
                                                                                false);
#if ENABLE_TRANSPARENCY
    VertexBufferMemAreaWriter *transparentWriter = vertex_buffer_mem_area_writer_new(
        shape,
        chunk,
        chunk->vbma_transparent,
        true);
#else
    VertexBufferMemAreaWriter *transparentWriter = opaqueWriter;
#endif

    static Block *b;
    static SHAPE_COORDS_INT3_T pos; // block local position in shape
    static SHAPE_COLOR_INDEX_INT_T shapeColorIdx;
    static ATLAS_COLOR_INDEX_INT_T atlasColorIdx;

    // vertex lighting ie. smooth lighting
    VERTEX_LIGHT_STRUCT_T vlight1, vlight2, vlight3, vlight4;

    static FACE_AMBIENT_OCCLUSION_STRUCT_T ao;

    // block neighbors
    static Block *topLeftBack, *topBack, *topRightBack, // top
        *topLeft, *top, *topRight, *topLeftFront, *topFront, *topRightFront, *leftBack, *back,
        *rightBack, // middle
        *left, /* self, */ *right, *leftFront, *front, *rightFront, *bottomLeftBack, *bottomBack,
        *bottomRightBack, // bottom
        *bottomLeft, *bottom, *bottomRight, *bottomLeftFront, *bottomFront, *bottomRightFront;

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
    static bool ao_topLeftBack, ao_topBack, ao_topRightBack, ao_topLeft, ao_topRight,
        ao_topLeftFront, ao_topFront, ao_topRightFront, ao_leftBack, ao_rightBack, ao_leftFront,
        ao_rightFront, ao_bottomLeftBack, ao_bottomBack, ao_bottomRightBack, ao_bottomLeft,
        ao_bottomRight, ao_bottomLeftFront, ao_bottomFront, ao_bottomRightFront;
    static bool light_topLeftBack, light_topBack, light_topRightBack, light_topLeft, light_topRight,
        light_topLeftFront, light_topFront, light_topRightFront, light_leftBack, light_rightBack,
        light_leftFront, light_rightFront, light_bottomLeftBack, light_bottomBack,
        light_bottomRightBack, light_bottomLeft, light_bottomRight, light_bottomLeftFront,
        light_bottomFront, light_bottomRightFront;
    // cache the vertex light values
    static VERTEX_LIGHT_STRUCT_T vlight_left, vlight_right, vlight_front, vlight_back, vlight_top,
        vlight_bottom, vlight_topLeftBack, vlight_topBack, vlight_topRightBack, vlight_topLeft,
        vlight_topRight, vlight_topLeftFront, vlight_topFront, vlight_topRightFront,
        vlight_leftBack, vlight_rightBack, vlight_leftFront, vlight_rightFront,
        vlight_bottomLeftBack, vlight_bottomBack, vlight_bottomRightBack, vlight_bottomLeft,
        vlight_bottomRight, vlight_bottomLeftFront, vlight_bottomFront, vlight_bottomRightFront;
    // should self be rendered with transparency
    bool selfTransparent;

    size_t posX = 0, posY = 0, posZ = 0;

    for (CHUNK_COORDS_INT_T x = 0; x < CHUNK_SIZE; x++) {
        for (CHUNK_COORDS_INT_T z = 0; z < CHUNK_SIZE; z++) {
            for (CHUNK_COORDS_INT_T y = 0; y < CHUNK_SIZE; y++) {
                b = chunk_get_block(chunk, x, y, z);
                if (block_is_solid(b)) {

                    shapeColorIdx = block_get_color_index(b);
                    atlasColorIdx = color_palette_get_atlas_index(palette, shapeColorIdx);
                    selfTransparent = color_palette_is_transparent(palette, shapeColorIdx);

                    chunk_get_block_pos(chunk, x, y, z, &pos);
                    posX = (size_t)pos.x;
                    posY = (size_t)pos.y;
                    posZ = (size_t)pos.z;

                    // get axis-aligned neighbouring blocks
                    left = _chunk_get_block_including_neighbors(chunk, x - 1, y, z);
                    right = _chunk_get_block_including_neighbors(chunk, x + 1, y, z);
                    front = _chunk_get_block_including_neighbors(chunk, x, y, z - 1);
                    back = _chunk_get_block_including_neighbors(chunk, x, y, z + 1);
                    top = _chunk_get_block_including_neighbors(chunk, x, y + 1, z);
                    bottom = _chunk_get_block_including_neighbors(chunk, x, y - 1, z);

                    // get their opacity properties
                    bool solid_left, opaque_left, transparent_left, solid_right, opaque_right,
                        transparent_right, solid_front, opaque_front, transparent_front, solid_back,
                        opaque_back, transparent_back, solid_top, opaque_top, transparent_top,
                        solid_bottom, opaque_bottom, transparent_bottom;

                    block_is_any(left,
                                 palette,
                                 &solid_left,
                                 &opaque_left,
                                 &transparent_left,
                                 NULL,
                                 NULL);
                    block_is_any(right,
                                 palette,
                                 &solid_right,
                                 &opaque_right,
                                 &transparent_right,
                                 NULL,
                                 NULL);
                    block_is_any(front,
                                 palette,
                                 &solid_front,
                                 &opaque_front,
                                 &transparent_front,
                                 NULL,
                                 NULL);
                    block_is_any(back,
                                 palette,
                                 &solid_back,
                                 &opaque_back,
                                 &transparent_back,
                                 NULL,
                                 NULL);
                    block_is_any(top,
                                 palette,
                                 &solid_top,
                                 &opaque_top,
                                 &transparent_top,
                                 NULL,
                                 NULL);
                    block_is_any(bottom,
                                 palette,
                                 &solid_bottom,
                                 &opaque_bottom,
                                 &transparent_bottom,
                                 NULL,
                                 NULL);

                    // get their vertex light values
                    vlight_left = shape_get_light_or_default(shape,
                                                             pos.x - 1,
                                                             pos.y,
                                                             pos.z,
                                                             left == NULL || opaque_left);
                    vlight_right = shape_get_light_or_default(shape,
                                                              pos.x + 1,
                                                              pos.y,
                                                              pos.z,
                                                              right == NULL || opaque_right);
                    vlight_front = shape_get_light_or_default(shape,
                                                              pos.x,
                                                              pos.y,
                                                              pos.z - 1,
                                                              front == NULL || opaque_front);
                    vlight_back = shape_get_light_or_default(shape,
                                                             pos.x,
                                                             pos.y,
                                                             pos.z + 1,
                                                             back == NULL || opaque_back);
                    vlight_top = shape_get_light_or_default(shape,
                                                            pos.x,
                                                            pos.y + 1,
                                                            pos.z,
                                                            top == NULL || opaque_top);
                    vlight_bottom = shape_get_light_or_default(shape,
                                                               pos.x,
                                                               pos.y - 1,
                                                               pos.z,
                                                               bottom == NULL || opaque_bottom);

                    // check which faces should be rendered
                    // transparent: if neighbor is non-solid or, if enabled, transparent with a
                    // different color
                    if (selfTransparent) {
                        if (shape_draw_inner_transparent_faces(shape)) {
                            renderLeft = (solid_left == false) ||
                                         (transparent_left && b->colorIndex != left->colorIndex);
                            renderRight = (solid_right == false) ||
                                          (transparent_right && b->colorIndex != right->colorIndex);
                            renderFront = (solid_front == false) ||
                                          (transparent_front && b->colorIndex != front->colorIndex);
                            renderBack = (solid_back == false) ||
                                         (transparent_back && b->colorIndex != back->colorIndex);
                            renderTop = (solid_top == false) ||
                                        (transparent_top && b->colorIndex != top->colorIndex);
                            renderBottom = (solid_bottom == false) ||
                                           (transparent_bottom &&
                                            b->colorIndex != bottom->colorIndex);
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
                        topLeftBack = _chunk_get_block_including_neighbors(chunk,
                                                                           x - 1,
                                                                           y + 1,
                                                                           z + 1);
                        topLeft = _chunk_get_block_including_neighbors(chunk, x - 1, y + 1, z);
                        topLeftFront = _chunk_get_block_including_neighbors(chunk,
                                                                            x - 1,
                                                                            y + 1,
                                                                            z - 1);

                        leftBack = _chunk_get_block_including_neighbors(chunk, x - 1, y, z + 1);
                        leftFront = _chunk_get_block_including_neighbors(chunk, x - 1, y, z - 1);

                        bottomLeftBack = _chunk_get_block_including_neighbors(chunk,
                                                                              x - 1,
                                                                              y - 1,
                                                                              z + 1);
                        bottomLeft = _chunk_get_block_including_neighbors(chunk, x - 1, y - 1, z);
                        bottomLeftFront = _chunk_get_block_including_neighbors(chunk,
                                                                               x - 1,
                                                                               y - 1,
                                                                               z - 1);

                        // get their light values & properties
                        _vertex_light_get(shape,
                                          topLeftBack,
                                          palette,
                                          pos.x - 1,
                                          pos.y + 1,
                                          pos.z + 1,
                                          &vlight_topLeftBack,
                                          &ao_topLeftBack,
                                          &light_topLeftBack);
                        _vertex_light_get(shape,
                                          topLeft,
                                          palette,
                                          pos.x - 1,
                                          pos.y + 1,
                                          pos.z,
                                          &vlight_topLeft,
                                          &ao_topLeft,
                                          &light_topLeft);
                        _vertex_light_get(shape,
                                          topLeftFront,
                                          palette,
                                          pos.x - 1,
                                          pos.y + 1,
                                          pos.z - 1,
                                          &vlight_topLeftFront,
                                          &ao_topLeftFront,
                                          &light_topLeftFront);

                        _vertex_light_get(shape,
                                          leftBack,
                                          palette,
                                          pos.x - 1,
                                          pos.y,
                                          pos.z + 1,
                                          &vlight_leftBack,
                                          &ao_leftBack,
                                          &light_leftBack);
                        _vertex_light_get(shape,
                                          leftFront,
                                          palette,
                                          pos.x - 1,
                                          pos.y,
                                          pos.z - 1,
                                          &vlight_leftFront,
                                          &ao_leftFront,
                                          &light_leftFront);

                        _vertex_light_get(shape,
                                          bottomLeftBack,
                                          palette,
                                          pos.x - 1,
                                          pos.y - 1,
                                          pos.z + 1,
                                          &vlight_bottomLeftBack,
                                          &ao_bottomLeftBack,
                                          &light_bottomLeftBack);
                        _vertex_light_get(shape,
                                          bottomLeft,
                                          palette,
                                          pos.x - 1,
                                          pos.y - 1,
                                          pos.z,
                                          &vlight_bottomLeft,
                                          &ao_bottomLeft,
                                          &light_bottomLeft);
                        _vertex_light_get(shape,
                                          bottomLeftFront,
                                          palette,
                                          pos.x - 1,
                                          pos.y - 1,
                                          pos.z - 1,
                                          &vlight_bottomLeftFront,
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
                        vlight1 = vlight_left;
                        if (light_bottomLeft || light_leftFront) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_bottomLeftFront,
                                                    light_bottomLeft,
                                                    light_leftFront,
                                                    vlight_bottomLeftFront,
                                                    vlight_bottomLeft,
                                                    vlight_leftFront);
                        }

                        // second corner
                        if (ao_leftFront && ao_topLeft) {
                            ao.ao2 = 3;
                        } else if (ao_topLeftFront && (ao_leftFront || ao_topLeft)) {
                            ao.ao2 = 2;
                        } else if (ao_topLeftFront || ao_leftFront || ao_topLeft) {
                            ao.ao2 = 1;
                        }
                        vlight2 = vlight_left;
                        if (light_leftFront || light_topLeft) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_topLeftFront,
                                                    light_leftFront,
                                                    light_topLeft,
                                                    vlight_topLeftFront,
                                                    vlight_leftFront,
                                                    vlight_topLeft);
                        }

                        // third corner
                        if (ao_topLeft && ao_leftBack) {
                            ao.ao3 = 3;
                        } else if (ao_topLeftBack && (ao_topLeft || ao_leftBack)) {
                            ao.ao3 = 2;
                        } else if (ao_topLeftBack || ao_topLeft || ao_leftBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = vlight_left;
                        if (light_topLeft || light_leftBack) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_topLeftBack,
                                                    light_topLeft,
                                                    light_leftBack,
                                                    vlight_topLeftBack,
                                                    vlight_topLeft,
                                                    vlight_leftBack);
                        }

                        // 4th corner
                        if (ao_leftBack && ao_bottomLeft) {
                            ao.ao4 = 3;
                        } else if (ao_bottomLeftBack && (ao_leftBack || ao_bottomLeft)) {
                            ao.ao4 = 2;
                        } else if (ao_bottomLeftBack || ao_leftBack || ao_bottomLeft) {
                            ao.ao4 = 1;
                        }
                        vlight4 = vlight_left;
                        if (light_leftBack || light_bottomLeft) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_bottomLeftBack,
                                                    light_leftBack,
                                                    light_bottomLeft,
                                                    vlight_bottomLeftBack,
                                                    vlight_leftBack,
                                                    vlight_bottomLeft);
                        }

                        vertex_buffer_mem_area_writer_write(selfTransparent ? transparentWriter
                                                                            : opaqueWriter,
                                                            (float)posX,
                                                            (float)posY + 0.5f,
                                                            (float)posZ + 0.5f,
                                                            atlasColorIdx,
                                                            FACE_LEFT,
                                                            ao,
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
                        topRightBack = _chunk_get_block_including_neighbors(chunk,
                                                                            x + 1,
                                                                            y + 1,
                                                                            z + 1);
                        topRight = _chunk_get_block_including_neighbors(chunk, x + 1, y + 1, z);
                        topRightFront = _chunk_get_block_including_neighbors(chunk,
                                                                             x + 1,
                                                                             y + 1,
                                                                             z - 1);

                        rightBack = _chunk_get_block_including_neighbors(chunk, x + 1, y, z + 1);
                        rightFront = _chunk_get_block_including_neighbors(chunk, x + 1, y, z - 1);

                        bottomRightBack = _chunk_get_block_including_neighbors(chunk,
                                                                               x + 1,
                                                                               y - 1,
                                                                               z + 1);
                        bottomRight = _chunk_get_block_including_neighbors(chunk, x + 1, y - 1, z);
                        bottomRightFront = _chunk_get_block_including_neighbors(chunk,
                                                                                x + 1,
                                                                                y - 1,
                                                                                z - 1);

                        // get their light values & properties
                        _vertex_light_get(shape,
                                          topRightBack,
                                          palette,
                                          pos.x + 1,
                                          pos.y + 1,
                                          pos.z + 1,
                                          &vlight_topRightBack,
                                          &ao_topRightBack,
                                          &light_topRightBack);
                        _vertex_light_get(shape,
                                          topRight,
                                          palette,
                                          pos.x + 1,
                                          pos.y + 1,
                                          pos.z,
                                          &vlight_topRight,
                                          &ao_topRight,
                                          &light_topRight);
                        _vertex_light_get(shape,
                                          topRightFront,
                                          palette,
                                          pos.x + 1,
                                          pos.y + 1,
                                          pos.z - 1,
                                          &vlight_topRightFront,
                                          &ao_topRightFront,
                                          &light_topRightFront);

                        _vertex_light_get(shape,
                                          rightBack,
                                          palette,
                                          pos.x + 1,
                                          pos.y,
                                          pos.z + 1,
                                          &vlight_rightBack,
                                          &ao_rightBack,
                                          &light_rightBack);
                        _vertex_light_get(shape,
                                          rightFront,
                                          palette,
                                          pos.x + 1,
                                          pos.y,
                                          pos.z - 1,
                                          &vlight_rightFront,
                                          &ao_rightFront,
                                          &light_rightFront);

                        _vertex_light_get(shape,
                                          bottomRightBack,
                                          palette,
                                          pos.x + 1,
                                          pos.y - 1,
                                          pos.z + 1,
                                          &vlight_bottomRightBack,
                                          &ao_bottomRightBack,
                                          &light_bottomRightBack);
                        _vertex_light_get(shape,
                                          bottomRight,
                                          palette,
                                          pos.x + 1,
                                          pos.y - 1,
                                          pos.z,
                                          &vlight_bottomRight,
                                          &ao_bottomRight,
                                          &light_bottomRight);
                        _vertex_light_get(shape,
                                          bottomRightFront,
                                          palette,
                                          pos.x + 1,
                                          pos.y - 1,
                                          pos.z - 1,
                                          &vlight_bottomRightFront,
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
                        vlight1 = vlight_right;
                        if (light_topRight || light_rightFront) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_topRightFront,
                                                    light_topRight,
                                                    light_rightFront,
                                                    vlight_topRightFront,
                                                    vlight_topRight,
                                                    vlight_rightFront);
                        }

                        // second corner (bottomRightFront)
                        if (ao_bottomRight && ao_rightFront) {
                            ao.ao2 = 3;
                        } else if (ao_bottomRightFront && (ao_bottomRight || ao_rightFront)) {
                            ao.ao2 = 2;
                        } else if (ao_bottomRightFront || ao_bottomRight || ao_rightFront) {
                            ao.ao2 = 1;
                        }
                        vlight2 = vlight_right;
                        if (light_bottomRight || light_rightFront) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_bottomRightFront,
                                                    light_bottomRight,
                                                    light_rightFront,
                                                    vlight_bottomRightFront,
                                                    vlight_bottomRight,
                                                    vlight_rightFront);
                        }

                        // third corner (bottomRightback)
                        if (ao_bottomRight && ao_rightBack) {
                            ao.ao3 = 3;
                        } else if (ao_bottomRightBack && (ao_bottomRight || ao_rightBack)) {
                            ao.ao3 = 2;
                        } else if (ao_bottomRightBack || ao_bottomRight || ao_rightBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = vlight_right;
                        if (light_bottomRight || light_rightBack) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_bottomRightBack,
                                                    light_bottomRight,
                                                    light_rightBack,
                                                    vlight_bottomRightBack,
                                                    vlight_bottomRight,
                                                    vlight_rightBack);
                        }

                        // 4th corner (topRightBack)
                        if (ao_topRight && ao_rightBack) {
                            ao.ao4 = 3;
                        } else if (ao_topRightBack && (ao_topRight || ao_rightBack)) {
                            ao.ao4 = 2;
                        } else if (ao_topRightBack || ao_topRight || ao_rightBack) {
                            ao.ao4 = 1;
                        }
                        vlight4 = vlight_right;
                        if (light_topRight || light_rightBack) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_topRightBack,
                                                    light_topRight,
                                                    light_rightBack,
                                                    vlight_topRightBack,
                                                    vlight_topRight,
                                                    vlight_rightBack);
                        }

                        vertex_buffer_mem_area_writer_write(selfTransparent ? transparentWriter
                                                                            : opaqueWriter,
                                                            (float)posX + 1.0f,
                                                            (float)posY + 0.5f,
                                                            (float)posZ + 0.5f,
                                                            atlasColorIdx,
                                                            FACE_RIGHT,
                                                            ao,
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
                            topRightFront = _chunk_get_block_including_neighbors(chunk,
                                                                                 x + 1,
                                                                                 y + 1,
                                                                                 z - 1);
                            rightFront = _chunk_get_block_including_neighbors(chunk,
                                                                              x + 1,
                                                                              y,
                                                                              z - 1);
                            bottomRightFront = _chunk_get_block_including_neighbors(chunk,
                                                                                    x + 1,
                                                                                    y - 1,
                                                                                    z - 1);
                        }

                        if (renderLeft == false) {
                            topLeftFront = _chunk_get_block_including_neighbors(chunk,
                                                                                x - 1,
                                                                                y + 1,
                                                                                z - 1);
                            leftFront = _chunk_get_block_including_neighbors(chunk,
                                                                             x - 1,
                                                                             y,
                                                                             z - 1);
                            bottomLeftFront = _chunk_get_block_including_neighbors(chunk,
                                                                                   x - 1,
                                                                                   y - 1,
                                                                                   z - 1);
                        }

                        topFront = _chunk_get_block_including_neighbors(chunk, x, y + 1, z - 1);
                        bottomFront = _chunk_get_block_including_neighbors(chunk, x, y - 1, z - 1);

                        // get their light values & properties
                        if (renderRight == false) {
                            _vertex_light_get(shape,
                                              topRightFront,
                                              palette,
                                              pos.x + 1,
                                              pos.y + 1,
                                              pos.z - 1,
                                              &vlight_topRightFront,
                                              &ao_topRightFront,
                                              &light_topRightFront);
                            _vertex_light_get(shape,
                                              rightFront,
                                              palette,
                                              pos.x + 1,
                                              pos.y,
                                              pos.z - 1,
                                              &vlight_rightFront,
                                              &ao_rightFront,
                                              &light_rightFront);
                            _vertex_light_get(shape,
                                              bottomRightFront,
                                              palette,
                                              pos.x + 1,
                                              pos.y - 1,
                                              pos.z - 1,
                                              &vlight_bottomRightFront,
                                              &ao_bottomRightFront,
                                              &light_bottomRightFront);
                        }
                        if (renderLeft == false) {
                            _vertex_light_get(shape,
                                              topLeftFront,
                                              palette,
                                              pos.x - 1,
                                              pos.y + 1,
                                              pos.z - 1,
                                              &vlight_topLeftFront,
                                              &ao_topLeftFront,
                                              &light_topLeftFront);
                            _vertex_light_get(shape,
                                              leftFront,
                                              palette,
                                              pos.x - 1,
                                              pos.y,
                                              pos.z - 1,
                                              &vlight_leftFront,
                                              &ao_leftFront,
                                              &light_leftFront);
                            _vertex_light_get(shape,
                                              bottomLeftFront,
                                              palette,
                                              pos.x - 1,
                                              pos.y - 1,
                                              pos.z - 1,
                                              &vlight_bottomLeftFront,
                                              &ao_bottomLeftFront,
                                              &light_bottomLeftFront);
                        }
                        _vertex_light_get(shape,
                                          topFront,
                                          palette,
                                          pos.x,
                                          pos.y + 1,
                                          pos.z - 1,
                                          &vlight_topFront,
                                          &ao_topFront,
                                          &light_topFront);
                        _vertex_light_get(shape,
                                          bottomFront,
                                          palette,
                                          pos.x,
                                          pos.y - 1,
                                          pos.z - 1,
                                          &vlight_bottomFront,
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
                        vlight1 = vlight_front;
                        if (light_topFront || light_leftFront) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_topLeftFront,
                                                    light_topFront,
                                                    light_leftFront,
                                                    vlight_topLeftFront,
                                                    vlight_topFront,
                                                    vlight_leftFront);
                        }

                        // second corner (bottomLeftFront)
                        if (ao_bottomFront && ao_leftFront) {
                            ao.ao2 = 3;
                        } else if (ao_bottomLeftFront && (ao_bottomFront || ao_leftFront)) {
                            ao.ao2 = 2;
                        } else if (ao_bottomLeftFront || ao_bottomFront || ao_leftFront) {
                            ao.ao2 = 1;
                        }
                        vlight2 = vlight_front;
                        if (light_bottomFront || light_leftFront) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_bottomLeftFront,
                                                    light_bottomFront,
                                                    light_leftFront,
                                                    vlight_bottomLeftFront,
                                                    vlight_bottomFront,
                                                    vlight_leftFront);
                        }

                        // third corner (bottomRightFront)
                        if (ao_bottomFront && ao_rightFront) {
                            ao.ao3 = 3;
                        } else if (ao_bottomRightFront && (ao_bottomFront || ao_rightFront)) {
                            ao.ao3 = 2;
                        } else if (ao_bottomRightFront || ao_bottomFront || ao_rightFront) {
                            ao.ao3 = 1;
                        }
                        vlight3 = vlight_front;
                        if (light_bottomFront || light_rightFront) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_bottomRightFront,
                                                    light_bottomFront,
                                                    light_rightFront,
                                                    vlight_bottomRightFront,
                                                    vlight_bottomFront,
                                                    vlight_rightFront);
                        }

                        // 4th corner (topRightFront)
                        if (ao_topFront && ao_rightFront) {
                            ao.ao4 = 3;
                        } else if (ao_topRightFront && (ao_topFront || ao_rightFront)) {
                            ao.ao4 = 2;
                        } else if (ao_topRightFront || ao_topFront || ao_rightFront) {
                            ao.ao4 = 1;
                        }
                        vlight4 = vlight_front;
                        if (light_topFront || light_rightFront) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_topRightFront,
                                                    light_topFront,
                                                    light_rightFront,
                                                    vlight_topRightFront,
                                                    vlight_topFront,
                                                    vlight_rightFront);
                        }

                        vertex_buffer_mem_area_writer_write(selfTransparent ? transparentWriter
                                                                            : opaqueWriter,
                                                            (float)posX + 0.5f,
                                                            (float)posY + 0.5f,
                                                            (float)posZ,
                                                            atlasColorIdx,
                                                            FACE_BACK,
                                                            ao,
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
                            topRightBack = _chunk_get_block_including_neighbors(chunk,
                                                                                x + 1,
                                                                                y + 1,
                                                                                z + 1);
                            rightBack = _chunk_get_block_including_neighbors(chunk,
                                                                             x + 1,
                                                                             y,
                                                                             z + 1);
                            bottomRightBack = _chunk_get_block_including_neighbors(chunk,
                                                                                   x + 1,
                                                                                   y - 1,
                                                                                   z + 1);
                        }

                        if (renderLeft == false) {
                            topLeftBack = _chunk_get_block_including_neighbors(chunk,
                                                                               x - 1,
                                                                               y + 1,
                                                                               z + 1);
                            leftBack = _chunk_get_block_including_neighbors(chunk, x - 1, y, z + 1);
                            bottomLeftBack = _chunk_get_block_including_neighbors(chunk,
                                                                                  x - 1,
                                                                                  y - 1,
                                                                                  z + 1);
                        }

                        topBack = _chunk_get_block_including_neighbors(chunk, x, y + 1, z + 1);
                        bottomBack = _chunk_get_block_including_neighbors(chunk, x, y - 1, z + 1);

                        // get their light values & properties
                        if (renderRight == false) {
                            _vertex_light_get(shape,
                                              topRightBack,
                                              palette,
                                              pos.x + 1,
                                              pos.y + 1,
                                              pos.z + 1,
                                              &vlight_topRightBack,
                                              &ao_topRightBack,
                                              &light_topRightBack);
                            _vertex_light_get(shape,
                                              rightBack,
                                              palette,
                                              pos.x + 1,
                                              pos.y,
                                              pos.z + 1,
                                              &vlight_rightBack,
                                              &ao_rightBack,
                                              &light_rightBack);
                            _vertex_light_get(shape,
                                              bottomRightBack,
                                              palette,
                                              pos.x + 1,
                                              pos.y - 1,
                                              pos.z + 1,
                                              &vlight_bottomRightBack,
                                              &ao_bottomRightBack,
                                              &light_bottomRightBack);
                        }
                        if (renderLeft == false) {
                            _vertex_light_get(shape,
                                              topLeftBack,
                                              palette,
                                              pos.x - 1,
                                              pos.y + 1,
                                              pos.z + 1,
                                              &vlight_topLeftBack,
                                              &ao_topLeftBack,
                                              &light_topLeftBack);
                            _vertex_light_get(shape,
                                              leftBack,
                                              palette,
                                              pos.x - 1,
                                              pos.y,
                                              pos.z + 1,
                                              &vlight_leftBack,
                                              &ao_leftBack,
                                              &light_leftBack);
                            _vertex_light_get(shape,
                                              bottomLeftBack,
                                              palette,
                                              pos.x - 1,
                                              pos.y - 1,
                                              pos.z + 1,
                                              &vlight_bottomLeftBack,
                                              &ao_bottomLeftBack,
                                              &light_bottomLeftBack);
                        }
                        _vertex_light_get(shape,
                                          topBack,
                                          palette,
                                          pos.x,
                                          pos.y + 1,
                                          pos.z + 1,
                                          &vlight_topBack,
                                          &ao_topBack,
                                          &light_topBack);
                        _vertex_light_get(shape,
                                          bottomBack,
                                          palette,
                                          pos.x,
                                          pos.y - 1,
                                          pos.z + 1,
                                          &vlight_bottomBack,
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
                        vlight1 = vlight_back;
                        if (light_bottomBack || light_leftBack) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_bottomLeftBack,
                                                    light_bottomBack,
                                                    light_leftBack,
                                                    vlight_bottomLeftBack,
                                                    vlight_bottomBack,
                                                    vlight_leftBack);
                        }

                        // second corner (topLeftBack)
                        if (ao_topBack && ao_leftBack) {
                            ao.ao2 = 3;
                        } else if (ao_topLeftBack && (ao_topBack || ao_leftBack)) {
                            ao.ao2 = 2;
                        } else if (ao_topLeftBack || ao_topBack || ao_leftBack) {
                            ao.ao2 = 1;
                        }
                        vlight2 = vlight_back;
                        if (light_topBack || light_leftBack) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_topLeftBack,
                                                    light_topBack,
                                                    light_leftBack,
                                                    vlight_topLeftBack,
                                                    vlight_topBack,
                                                    vlight_leftBack);
                        }

                        // third corner (topRightBack)
                        if (ao_topBack && ao_rightBack) {
                            ao.ao3 = 3;
                        } else if (ao_topRightBack && (ao_topBack || ao_rightBack)) {
                            ao.ao3 = 2;
                        } else if (ao_topRightBack || ao_topBack || ao_rightBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = vlight_back;
                        if (light_topBack || light_rightBack) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_topRightBack,
                                                    light_topBack,
                                                    light_rightBack,
                                                    vlight_topRightBack,
                                                    vlight_topBack,
                                                    vlight_rightBack);
                        }

                        // 4th corner (bottomRightBack)
                        if (ao_bottomBack && ao_rightBack) {
                            ao.ao4 = 3;
                        } else if (ao_bottomRightBack && (ao_bottomBack || ao_rightBack)) {
                            ao.ao4 = 2;
                        } else if (ao_bottomRightBack || ao_bottomBack || ao_rightBack) {
                            ao.ao4 = 1;
                        }
                        vlight4 = vlight_back;
                        if (light_bottomBack || light_rightBack) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_bottomRightBack,
                                                    light_bottomBack,
                                                    light_rightBack,
                                                    vlight_bottomRightBack,
                                                    vlight_bottomBack,
                                                    vlight_rightBack);
                        }

                        vertex_buffer_mem_area_writer_write(selfTransparent ? transparentWriter
                                                                            : opaqueWriter,
                                                            (float)posX + 0.5f,
                                                            (float)posY + 0.5f,
                                                            (float)posZ + 1.0f,
                                                            atlasColorIdx,
                                                            FACE_FRONT,
                                                            ao,
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
                            topLeftBack = _chunk_get_block_including_neighbors(chunk,
                                                                               x - 1,
                                                                               y + 1,
                                                                               z + 1);
                            topLeft = _chunk_get_block_including_neighbors(chunk, x - 1, y + 1, z);
                            topLeftFront = _chunk_get_block_including_neighbors(chunk,
                                                                                x - 1,
                                                                                y + 1,
                                                                                z - 1);
                        }

                        if (renderRight == false) {
                            topRightBack = _chunk_get_block_including_neighbors(chunk,
                                                                                x + 1,
                                                                                y + 1,
                                                                                z + 1);
                            topRight = _chunk_get_block_including_neighbors(chunk, x + 1, y + 1, z);
                            topRightFront = _chunk_get_block_including_neighbors(chunk,
                                                                                 x + 1,
                                                                                 y + 1,
                                                                                 z - 1);
                        }

                        if (renderBack == false) {
                            topBack = _chunk_get_block_including_neighbors(chunk, x, y + 1, z + 1);
                        }

                        if (renderFront == false) {
                            topFront = _chunk_get_block_including_neighbors(chunk, x, y + 1, z - 1);
                        }

                        // get their light values & properties
                        if (renderLeft == false) {
                            _vertex_light_get(shape,
                                              topLeftBack,
                                              palette,
                                              pos.x - 1,
                                              pos.y + 1,
                                              pos.z + 1,
                                              &vlight_topLeftBack,
                                              &ao_topLeftBack,
                                              &light_topLeftBack);
                            _vertex_light_get(shape,
                                              topLeft,
                                              palette,
                                              pos.x - 1,
                                              pos.y + 1,
                                              pos.z,
                                              &vlight_topLeft,
                                              &ao_topLeft,
                                              &light_topLeft);
                            _vertex_light_get(shape,
                                              topLeftFront,
                                              palette,
                                              pos.x - 1,
                                              pos.y + 1,
                                              pos.z - 1,
                                              &vlight_topLeftFront,
                                              &ao_topLeftFront,
                                              &light_topLeftFront);
                        }
                        if (renderRight == false) {
                            _vertex_light_get(shape,
                                              topRightBack,
                                              palette,
                                              pos.x + 1,
                                              pos.y + 1,
                                              pos.z + 1,
                                              &vlight_topRightBack,
                                              &ao_topRightBack,
                                              &light_topRightBack);
                            _vertex_light_get(shape,
                                              topRight,
                                              palette,
                                              pos.x + 1,
                                              pos.y + 1,
                                              pos.z,
                                              &vlight_topRight,
                                              &ao_topRight,
                                              &light_topRight);
                            _vertex_light_get(shape,
                                              topRightFront,
                                              palette,
                                              pos.x + 1,
                                              pos.y + 1,
                                              pos.z - 1,
                                              &vlight_topRightFront,
                                              &ao_topRightFront,
                                              &light_topRightFront);
                        }
                        if (renderBack == false) {
                            _vertex_light_get(shape,
                                              topBack,
                                              palette,
                                              pos.x,
                                              pos.y + 1,
                                              pos.z + 1,
                                              &vlight_topBack,
                                              &ao_topBack,
                                              &light_topBack);
                        }
                        if (renderFront == false) {
                            _vertex_light_get(shape,
                                              topFront,
                                              palette,
                                              pos.x,
                                              pos.y + 1,
                                              pos.z - 1,
                                              &vlight_topFront,
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
                        vlight1 = vlight_top;
                        if (light_topRight || light_topFront) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_topRightFront,
                                                    light_topRight,
                                                    light_topFront,
                                                    vlight_topRightFront,
                                                    vlight_topRight,
                                                    vlight_topFront);
                        }

                        // second corner (topRightBack)
                        if (ao_topRight && ao_topBack) {
                            ao.ao2 = 3;
                        } else if (ao_topRightBack && (ao_topRight || ao_topBack)) {
                            ao.ao2 = 2;
                        } else if (ao_topRightBack || ao_topRight || ao_topBack) {
                            ao.ao2 = 1;
                        }
                        vlight2 = vlight_top;
                        if (light_topRight || light_topBack) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_topRightBack,
                                                    light_topRight,
                                                    light_topBack,
                                                    vlight_topRightBack,
                                                    vlight_topRight,
                                                    vlight_topBack);
                        }

                        // third corner (topLeftBack)
                        if (ao_topLeft && ao_topBack) {
                            ao.ao3 = 3;
                        } else if (ao_topLeftBack && (ao_topLeft || ao_topBack)) {
                            ao.ao3 = 2;
                        } else if (ao_topLeftBack || ao_topLeft || ao_topBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = vlight_top;
                        if (light_topLeft || light_topBack) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_topLeftBack,
                                                    light_topLeft,
                                                    light_topBack,
                                                    vlight_topLeftBack,
                                                    vlight_topLeft,
                                                    vlight_topBack);
                        }

                        // 4th corner (topLeftFront)
                        if (ao_topLeft && ao_topFront) {
                            ao.ao4 = 3;
                        } else if (ao_topLeftFront && (ao_topLeft || ao_topFront)) {
                            ao.ao4 = 2;
                        } else if (ao_topLeftFront || ao_topLeft || ao_topFront) {
                            ao.ao4 = 1;
                        }
                        vlight4 = vlight_top;
                        if (light_topLeft || light_topFront) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_topLeftFront,
                                                    light_topLeft,
                                                    light_topFront,
                                                    vlight_topLeftFront,
                                                    vlight_topLeft,
                                                    vlight_topFront);
                        }

                        vertex_buffer_mem_area_writer_write(selfTransparent ? transparentWriter
                                                                            : opaqueWriter,
                                                            (float)posX + 0.5f,
                                                            (float)posY + 1.0f,
                                                            (float)posZ + 0.5f,
                                                            atlasColorIdx,
                                                            FACE_TOP,
                                                            ao,
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
                            bottomLeftBack = _chunk_get_block_including_neighbors(chunk,
                                                                                  x - 1,
                                                                                  y - 1,
                                                                                  z + 1);
                            bottomLeft = _chunk_get_block_including_neighbors(chunk,
                                                                              x - 1,
                                                                              y - 1,
                                                                              z);
                            bottomLeftFront = _chunk_get_block_including_neighbors(chunk,
                                                                                   x - 1,
                                                                                   y - 1,
                                                                                   z - 1);
                        }

                        if (renderRight == false) {
                            bottomRightBack = _chunk_get_block_including_neighbors(chunk,
                                                                                   x + 1,
                                                                                   y - 1,
                                                                                   z + 1);
                            bottomRight = _chunk_get_block_including_neighbors(chunk,
                                                                               x + 1,
                                                                               y - 1,
                                                                               z);
                            bottomRightFront = _chunk_get_block_including_neighbors(chunk,
                                                                                    x + 1,
                                                                                    y - 1,
                                                                                    z - 1);
                        }

                        if (renderBack == false) {
                            bottomBack = _chunk_get_block_including_neighbors(chunk,
                                                                              x,
                                                                              y - 1,
                                                                              z + 1);
                        }

                        if (renderFront == false) {
                            bottomFront = _chunk_get_block_including_neighbors(chunk,
                                                                               x,
                                                                               y - 1,
                                                                               z - 1);
                        }

                        // get their light values & properties
                        if (renderLeft == false) {
                            _vertex_light_get(shape,
                                              bottomLeftBack,
                                              palette,
                                              pos.x - 1,
                                              pos.y - 1,
                                              pos.z + 1,
                                              &vlight_bottomLeftBack,
                                              &ao_bottomLeftBack,
                                              &light_bottomLeftBack);
                            _vertex_light_get(shape,
                                              bottomLeft,
                                              palette,
                                              pos.x - 1,
                                              pos.y - 1,
                                              pos.z,
                                              &vlight_bottomLeft,
                                              &ao_bottomLeft,
                                              &light_bottomLeft);
                            _vertex_light_get(shape,
                                              bottomLeftFront,
                                              palette,
                                              pos.x - 1,
                                              pos.y - 1,
                                              pos.z - 1,
                                              &vlight_bottomLeftFront,
                                              &ao_bottomLeftFront,
                                              &light_bottomLeftFront);
                        }
                        if (renderRight == false) {
                            _vertex_light_get(shape,
                                              bottomRightBack,
                                              palette,
                                              pos.x + 1,
                                              pos.y - 1,
                                              pos.z + 1,
                                              &vlight_bottomRightBack,
                                              &ao_bottomRightBack,
                                              &light_bottomRightBack);
                            _vertex_light_get(shape,
                                              bottomRight,
                                              palette,
                                              pos.x + 1,
                                              pos.y - 1,
                                              pos.z,
                                              &vlight_bottomRight,
                                              &ao_bottomRight,
                                              &light_bottomRight);
                            _vertex_light_get(shape,
                                              bottomRightFront,
                                              palette,
                                              pos.x + 1,
                                              pos.y - 1,
                                              pos.z - 1,
                                              &vlight_bottomRightFront,
                                              &ao_bottomRightFront,
                                              &light_bottomRightFront);
                        }
                        if (renderBack == false) {
                            _vertex_light_get(shape,
                                              bottomBack,
                                              palette,
                                              pos.x,
                                              pos.y - 1,
                                              pos.z + 1,
                                              &vlight_bottomBack,
                                              &ao_bottomBack,
                                              &light_bottomBack);
                        }
                        if (renderFront == false) {
                            _vertex_light_get(shape,
                                              bottomFront,
                                              palette,
                                              pos.x,
                                              pos.y - 1,
                                              pos.z - 1,
                                              &vlight_bottomFront,
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
                        vlight1 = vlight_bottom;
                        if (light_bottomLeft || light_bottomFront) {
                            _vertex_light_smoothing(&vlight1,
                                                    light_bottomLeftFront,
                                                    light_bottomLeft,
                                                    light_bottomFront,
                                                    vlight_bottomLeftFront,
                                                    vlight_bottomLeft,
                                                    vlight_bottomFront);
                        }

                        // second corner (bottomLeftBack)
                        if (ao_bottomLeft && ao_bottomBack) {
                            ao.ao2 = 3;
                        } else if (ao_bottomLeftBack && (ao_bottomLeft || ao_bottomBack)) {
                            ao.ao2 = 2;
                        } else if (ao_bottomLeftBack || ao_bottomLeft || ao_bottomBack) {
                            ao.ao2 = 1;
                        }
                        vlight2 = vlight_bottom;
                        if (light_bottomLeft || light_bottomBack) {
                            _vertex_light_smoothing(&vlight2,
                                                    light_bottomLeftBack,
                                                    light_bottomLeft,
                                                    light_bottomBack,
                                                    vlight_bottomLeftBack,
                                                    vlight_bottomLeft,
                                                    vlight_bottomBack);
                        }

                        // second corner (bottomRightBack)
                        if (ao_bottomRight && ao_bottomBack) {
                            ao.ao3 = 3;
                        } else if (ao_bottomRightBack && (ao_bottomRight || ao_bottomBack)) {
                            ao.ao3 = 2;
                        } else if (ao_bottomRightBack || ao_bottomRight || ao_bottomBack) {
                            ao.ao3 = 1;
                        }
                        vlight3 = vlight_bottom;
                        if (light_bottomRight || light_bottomBack) {
                            _vertex_light_smoothing(&vlight3,
                                                    light_bottomRightBack,
                                                    light_bottomRight,
                                                    light_bottomBack,
                                                    vlight_bottomRightBack,
                                                    vlight_bottomRight,
                                                    vlight_bottomBack);
                        }

                        // second corner (bottomRightFront)
                        if (ao_bottomRight && ao_bottomFront) {
                            ao.ao4 = 3;
                        } else if (ao_bottomRightFront && (ao_bottomRight || ao_bottomFront)) {
                            ao.ao4 = 2;
                        } else if (ao_bottomRightFront || ao_bottomRight || ao_bottomFront) {
                            ao.ao4 = 1;
                        }
                        vlight4 = vlight_bottom;
                        if (light_bottomRight || light_bottomFront) {
                            _vertex_light_smoothing(&vlight4,
                                                    light_bottomRightFront,
                                                    light_bottomRight,
                                                    light_bottomFront,
                                                    vlight_bottomRightFront,
                                                    vlight_bottomRight,
                                                    vlight_bottomFront);
                        }

                        vertex_buffer_mem_area_writer_write(selfTransparent ? transparentWriter
                                                                            : opaqueWriter,
                                                            (float)posX + 0.5f,
                                                            (float)posY,
                                                            (float)posZ + 0.5f,
                                                            atlasColorIdx,
                                                            FACE_DOWN,
                                                            ao,
                                                            vlight1,
                                                            vlight2,
                                                            vlight3,
                                                            vlight4);
                    }
                }
            }
        }
    }

    vertex_buffer_mem_area_writer_done(opaqueWriter);
    vertex_buffer_mem_area_writer_free(opaqueWriter);
#if ENABLE_TRANSPARENCY
    vertex_buffer_mem_area_writer_done(transparentWriter);
    vertex_buffer_mem_area_writer_free(transparentWriter);
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

Block *_chunk_get_block_including_neighbors(const Chunk *chunk,
                                            const CHUNK_COORDS_INT_T x,
                                            const CHUNK_COORDS_INT_T y,
                                            const CHUNK_COORDS_INT_T z) {
    if (y > CHUNK_SIZE_MINUS_ONE) { // Top (9 cases)
        if (x < 0) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // TopLeftBack
                return chunk_get_block(chunk->neighbors[NX_Y_Z],
                                       x + CHUNK_SIZE,
                                       y - CHUNK_SIZE,
                                       z - CHUNK_SIZE);
            } else if (z < 0) { // TopLeftFront
                return chunk_get_block(chunk->neighbors[NX_Y_NZ],
                                       x + CHUNK_SIZE,
                                       y - CHUNK_SIZE,
                                       z + CHUNK_SIZE);
            } else { // TopLeft
                return chunk_get_block(chunk->neighbors[NX_Y], x + CHUNK_SIZE, y - CHUNK_SIZE, z);
            }
        } else if (x > CHUNK_SIZE_MINUS_ONE) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // TopRightBack
                return chunk_get_block(chunk->neighbors[X_Y_Z],
                                       x - CHUNK_SIZE,
                                       y - CHUNK_SIZE,
                                       z - CHUNK_SIZE);
            } else if (z < 0) { // TopRightFront
                return chunk_get_block(chunk->neighbors[X_Y_NZ],
                                       x - CHUNK_SIZE,
                                       y - CHUNK_SIZE,
                                       z + CHUNK_SIZE);
            } else { // TopRight
                return chunk_get_block(chunk->neighbors[X_Y], x - CHUNK_SIZE, y - CHUNK_SIZE, z);
            }
        } else {
            if (z > CHUNK_SIZE_MINUS_ONE) { // TopBack
                return chunk_get_block(chunk->neighbors[Y_Z], x, y - CHUNK_SIZE, z - CHUNK_SIZE);
            } else if (z < 0) { // TopFront
                return chunk_get_block(chunk->neighbors[Y_NZ], x, y - CHUNK_SIZE, z + CHUNK_SIZE);
            } else { // Top
                return chunk_get_block(chunk->neighbors[Y], x, y - CHUNK_SIZE, z);
            }
        }
    } else if (y < 0) { // Bottom (9 cases)
        if (x < 0) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // BottomLeftBack
                return chunk_get_block(chunk->neighbors[NX_NY_Z],
                                       x + CHUNK_SIZE,
                                       y + CHUNK_SIZE,
                                       z - CHUNK_SIZE);
            } else if (z < 0) { // BottomLeftFront
                return chunk_get_block(chunk->neighbors[NX_NY_NZ],
                                       x + CHUNK_SIZE,
                                       y + CHUNK_SIZE,
                                       z + CHUNK_SIZE);
            } else { // BottomLeft
                return chunk_get_block(chunk->neighbors[NX_NY], x + CHUNK_SIZE, y + CHUNK_SIZE, z);
            }
        } else if (x > CHUNK_SIZE_MINUS_ONE) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // BottomRightBack
                return chunk_get_block(chunk->neighbors[X_NY_Z],
                                       x - CHUNK_SIZE,
                                       y + CHUNK_SIZE,
                                       z - CHUNK_SIZE);
            } else if (z < 0) { // BottomRightFront
                return chunk_get_block(chunk->neighbors[X_NY_NZ],
                                       x - CHUNK_SIZE,
                                       y + CHUNK_SIZE,
                                       z + CHUNK_SIZE);
            } else { // BottomRight
                return chunk_get_block(chunk->neighbors[X_NY], x - CHUNK_SIZE, y + CHUNK_SIZE, z);
            }
        } else {
            if (z > CHUNK_SIZE_MINUS_ONE) { // BottomBack
                return chunk_get_block(chunk->neighbors[NY_Z], x, y + CHUNK_SIZE, z - CHUNK_SIZE);
            } else if (z < 0) { // BottomFront
                return chunk_get_block(chunk->neighbors[NY_NZ], x, y + CHUNK_SIZE, z + CHUNK_SIZE);
            } else { // Bottom
                return chunk_get_block(chunk->neighbors[NY], x, y + CHUNK_SIZE, z);
            }
        }
    } else { // 8 cases (y is within chunk)
        if (x < 0) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // LeftBack
                return chunk_get_block(chunk->neighbors[NX_Z], x + CHUNK_SIZE, y, z - CHUNK_SIZE);
            } else if (z < 0) { // LeftFront
                return chunk_get_block(chunk->neighbors[NX_NZ], x + CHUNK_SIZE, y, z + CHUNK_SIZE);
            } else { // NX
                return chunk_get_block(chunk->neighbors[NX], x + CHUNK_SIZE, y, z);
            }
        } else if (x > CHUNK_SIZE_MINUS_ONE) {
            if (z > CHUNK_SIZE_MINUS_ONE) { // RightBack
                return chunk_get_block(chunk->neighbors[X_Z], x - CHUNK_SIZE, y, z - CHUNK_SIZE);
            } else if (z < 0) { // RightFront
                return chunk_get_block(chunk->neighbors[X_NZ], x - CHUNK_SIZE, y, z + CHUNK_SIZE);
            } else { // Right
                return chunk_get_block(chunk->neighbors[X], x - CHUNK_SIZE, y, z);
            }
        } else {
            if (z > CHUNK_SIZE_MINUS_ONE) { // Back
                return chunk_get_block(chunk->neighbors[Z], x, y, z - CHUNK_SIZE);
            } else if (z < 0) { // Front
                return chunk_get_block(chunk->neighbors[NZ], x, y, z + CHUNK_SIZE);
            }
        }
    }

    // here: block is within chunk
    return chunk != NULL ? (Block *)octree_get_element_without_checking(chunk->octree,
                                                                        (size_t)x,
                                                                        (size_t)y,
                                                                        (size_t)z)
                         : NULL;
}

void _vertex_light_get(Shape *shape,
                       Block *block,
                       const ColorPalette *palette,
                       SHAPE_COORDS_INT_T x,
                       SHAPE_COORDS_INT_T y,
                       SHAPE_COORDS_INT_T z,
                       VERTEX_LIGHT_STRUCT_T *vlight,
                       bool *aoCaster,
                       bool *lightCaster) {

    bool opaque;
    block_is_any(block, palette, NULL, &opaque, NULL, aoCaster, lightCaster);
    *vlight = shape_get_light_or_default(shape, x, y, z, block == NULL || opaque);
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
