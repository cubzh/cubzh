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

static int nbNeighbors = 26;

// chunk structure definition
struct _Chunk {
    // 26 possible chunk neighbors
    // it's a little heavy to store that many pointers...
    // but it means not having to look for all 26 neighbors
    // when updating chunk data/vertices
    Chunk *neighbors[26]; /* 8 bytes */
    // position of chunk in world's grid
    int3 *pos; /* 8 bytes */
    // 3d grid containing blocks contained in chunk
    Block *blocks[CHUNK_WIDTH][CHUNK_DEPTH][CHUNK_HEIGHT]; /* 8 bytes */
    // first opaque/transparent vbma reserved for that chunk, this can be chained across several vb
    VertexBufferMemArea *vbma_opaque;      /* 8 bytes */
    VertexBufferMemArea *vbma_transparent; /* 8 bytes */
    // number of blocks in that chunk
    int nbBlocks; /* 4 bytes */
    // wether vertices need to be displayed or not
    bool needsDisplay; /* 1 byte */

    // padding
    char pad[3];
};

// MARK: private functions prototypes

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

void chunk_set_needs_display(Chunk *chunk, bool b) {
    chunk->needsDisplay = b;
}

Chunk *chunk_new(const SHAPE_COORDS_INT_T x,
                 const SHAPE_COORDS_INT_T y,
                 const SHAPE_COORDS_INT_T z) {

    Chunk *chunk = (Chunk *)malloc(sizeof(Chunk));
    if (chunk == NULL) {
        return NULL;
    }
    chunk->pos = int3_new(x, y, z);
    chunk->needsDisplay = false;
    chunk->nbBlocks = 0;

    for (int xi = 0; xi < CHUNK_WIDTH; xi++) {
        for (int zi = 0; zi < CHUNK_DEPTH; zi++) {
            for (int yi = 0; yi < CHUNK_HEIGHT; yi++) {
                chunk->blocks[xi][zi][yi] = NULL;
            }
        }
    }

    for (int i = 0; i < nbNeighbors; i++) {
        chunk->neighbors[i] = NULL;
    }

    chunk->vbma_opaque = NULL;
    chunk->vbma_transparent = NULL;

    return chunk;
}

void _chunk_hello_neighbor(Chunk *newcomer,
                           enum Neighbor newcomerLocation,
                           Chunk *neighbor,
                           enum Neighbor neighborLocation) {
    if (neighbor == NULL)
        return;

    newcomer->neighbors[neighborLocation] = neighbor;
    neighbor->neighbors[newcomerLocation] = newcomer;
}

Chunk *chunk_get_neighbor(const Chunk *chunk, enum Neighbor location) {
    return chunk->neighbors[location];
}

// register as new neighbor in the grid
// where chunk is inserted
void chunk_move_in_neighborhood(Chunk *chunk,
                                Chunk *topLeftBack,
                                Chunk *topBack,
                                Chunk *topRightBack, // top
                                Chunk *topLeft,
                                Chunk *top,
                                Chunk *topRight,
                                Chunk *topLeftFront,
                                Chunk *topFront,
                                Chunk *topRightFront,
                                Chunk *bottomLeftBack,
                                Chunk *bottomBack,
                                Chunk *bottomRightBack, // bottom
                                Chunk *bottomLeft,
                                Chunk *bottom,
                                Chunk *bottomRight,
                                Chunk *bottomLeftFront,
                                Chunk *bottomFront,
                                Chunk *bottomRightFront,
                                Chunk *leftBack,
                                Chunk *back,
                                Chunk *rightBack, // middle
                                Chunk *left,
                                /* self */ Chunk *right,
                                Chunk *leftFront,
                                Chunk *front,
                                Chunk *rightFront) {
    if (chunk == NULL)
        return;

    // top
    _chunk_hello_neighbor(chunk, BottomRightFront, topLeftBack, TopLeftBack);
    _chunk_hello_neighbor(chunk, BottomFront, topBack, TopBack);
    _chunk_hello_neighbor(chunk, BottomLeftFront, topRightBack, TopRightBack);

    _chunk_hello_neighbor(chunk, BottomRight, topLeft, TopLeft);
    _chunk_hello_neighbor(chunk, Bottom, top, Top);
    _chunk_hello_neighbor(chunk, BottomLeft, topRight, TopRight);

    _chunk_hello_neighbor(chunk, BottomRightBack, topLeftFront, TopLeftFront);
    _chunk_hello_neighbor(chunk, BottomBack, topFront, TopFront);
    _chunk_hello_neighbor(chunk, BottomLeftBack, topRightFront, TopRightFront);

    // bottom
    _chunk_hello_neighbor(chunk, TopRightFront, bottomLeftBack, BottomLeftBack);
    _chunk_hello_neighbor(chunk, TopFront, bottomBack, BottomBack);
    _chunk_hello_neighbor(chunk, TopLeftFront, bottomRightBack, BottomRightBack);

    _chunk_hello_neighbor(chunk, TopRight, bottomLeft, BottomLeft);
    _chunk_hello_neighbor(chunk, Top, bottom, Bottom);
    _chunk_hello_neighbor(chunk, TopLeft, bottomRight, BottomRight);

    _chunk_hello_neighbor(chunk, TopRightBack, bottomLeftFront, BottomLeftFront);
    _chunk_hello_neighbor(chunk, TopBack, bottomFront, BottomFront);
    _chunk_hello_neighbor(chunk, TopLeftBack, bottomRightFront, BottomRightFront);

    // middle
    _chunk_hello_neighbor(chunk, RightFront, leftBack, LeftBack);
    _chunk_hello_neighbor(chunk, Front, back, Back);
    _chunk_hello_neighbor(chunk, LeftFront, rightBack, RightBack);

    _chunk_hello_neighbor(chunk, Right, left, Left);
    /* self */
    _chunk_hello_neighbor(chunk, Left, right, Right);

    _chunk_hello_neighbor(chunk, RightBack, leftFront, LeftFront);
    _chunk_hello_neighbor(chunk, Back, front, Front);
    _chunk_hello_neighbor(chunk, LeftBack, rightFront, RightFront);
}

// removes relation with given neighbor
// given its location
void _chunk_good_bye_neighbor(Chunk *chunk, enum Neighbor location) {
    if (chunk == NULL)
        return;
    chunk->neighbors[location] = NULL;
}

// removes relations with all neighbors
void chunk_leave_neighborhood(Chunk *chunk) {
    if (chunk == NULL)
        return;

    // top
    _chunk_good_bye_neighbor(chunk->neighbors[TopLeftBack], BottomRightFront);
    _chunk_good_bye_neighbor(chunk->neighbors[TopBack], BottomFront);
    _chunk_good_bye_neighbor(chunk->neighbors[TopRightBack], BottomLeftFront);
    _chunk_good_bye_neighbor(chunk->neighbors[TopRight], BottomLeft);
    _chunk_good_bye_neighbor(chunk->neighbors[TopRightFront], BottomLeftBack);
    _chunk_good_bye_neighbor(chunk->neighbors[TopFront], BottomBack);
    _chunk_good_bye_neighbor(chunk->neighbors[TopLeftFront], BottomRightBack);
    _chunk_good_bye_neighbor(chunk->neighbors[TopLeft], BottomRight);
    _chunk_good_bye_neighbor(chunk->neighbors[Top], Bottom);

    // middle
    _chunk_good_bye_neighbor(chunk->neighbors[LeftBack], RightFront);
    _chunk_good_bye_neighbor(chunk->neighbors[Back], Front);
    _chunk_good_bye_neighbor(chunk->neighbors[RightBack], LeftFront);
    _chunk_good_bye_neighbor(chunk->neighbors[Right], Left);
    _chunk_good_bye_neighbor(chunk->neighbors[RightFront], LeftBack);
    _chunk_good_bye_neighbor(chunk->neighbors[Front], Back);
    _chunk_good_bye_neighbor(chunk->neighbors[LeftFront], RightBack);
    _chunk_good_bye_neighbor(chunk->neighbors[Left], Right);

    // bottom
    _chunk_good_bye_neighbor(chunk->neighbors[BottomLeftBack], TopRightFront);
    _chunk_good_bye_neighbor(chunk->neighbors[BottomBack], TopFront);
    _chunk_good_bye_neighbor(chunk->neighbors[BottomRightBack], TopLeftFront);
    _chunk_good_bye_neighbor(chunk->neighbors[BottomRight], TopLeft);
    _chunk_good_bye_neighbor(chunk->neighbors[BottomRightFront], TopLeftBack);
    _chunk_good_bye_neighbor(chunk->neighbors[BottomFront], TopBack);
    _chunk_good_bye_neighbor(chunk->neighbors[BottomLeftFront], TopRightBack);
    _chunk_good_bye_neighbor(chunk->neighbors[BottomLeft], TopRight);
    _chunk_good_bye_neighbor(chunk->neighbors[Bottom], Top);

    for (int i = 0; i < nbNeighbors; i++) {
        chunk->neighbors[i] = NULL;
    }
}

void chunk_destroy(Chunk *chunk) {
    // saying good bye to neighbors
    chunk_leave_neighborhood(chunk);

    if (chunk->vbma_opaque != NULL) {
        vertex_buffer_mem_area_flush(chunk->vbma_opaque);
    }
    chunk->vbma_opaque = NULL;

    if (chunk->vbma_transparent != NULL) {
        vertex_buffer_mem_area_flush(chunk->vbma_transparent);
    }
    chunk->vbma_transparent = NULL;

    // free blocks
    Block *b;
    for (CHUNK_COORDS_INT_T x = 0; x < CHUNK_WIDTH; x++) {
        for (CHUNK_COORDS_INT_T z = 0; z < CHUNK_DEPTH; z++) {
            for (CHUNK_COORDS_INT_T y = 0; y < CHUNK_HEIGHT; y++) {
                b = chunk_get_block(chunk, x, y, z);
                block_free(b);
            }
        }
    }

    int3_free(chunk->pos);

    free(chunk);
}

bool chunk_addBlock(Chunk *chunk,
                    Block *block,
                    const CHUNK_COORDS_INT_T x,
                    const CHUNK_COORDS_INT_T y,
                    const CHUNK_COORDS_INT_T z) {
    if (block == NULL) {
        return false;
    }
    if (chunk->blocks[x][z][y] != NULL) {
        // if chunk already contains a block at the given coordinates,
        // do nothing and return false
        return false;
    }
    chunk->blocks[x][z][y] = block;
    chunk->nbBlocks += 1;
    return true;
}

bool chunk_removeBlock(Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z) {
    Block *block = chunk->blocks[x][z][y];
    if (block != NULL) {
        free(block);
        chunk->blocks[x][z][y] = NULL;
        chunk->nbBlocks -= 1;
        return true;
    }
    return false;
}

bool chunk_paint_block(Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z,
                       const SHAPE_COLOR_INDEX_INT_T colorIndex) {
    Block *block = chunk->blocks[x][z][y];
    if (block != NULL) {
        block_set_color_index(block, colorIndex);
        return true;
    }
    return false;
}

// returns block positioned within chunk
// looking for a block outside will return NULL
Block *chunk_get_block(const Chunk *chunk,
                       const CHUNK_COORDS_INT_T x,
                       const CHUNK_COORDS_INT_T y,
                       const CHUNK_COORDS_INT_T z) {
    if (chunk == NULL) {
        return NULL;
    }

    if (x < 0 || x > CHUNK_WIDTH - 1)
        return NULL;
    if (y < 0 || y > CHUNK_HEIGHT - 1)
        return NULL;
    if (z < 0 || z > CHUNK_DEPTH - 1)
        return NULL;

    return chunk->blocks[x][z][y];
}

// returns block positioned within chunk
// and from neighbor chunks also if necessary
//!\\ can't look past direct neighbors
Block *chunk_get_block_including_neighbors(const Chunk *chunk,
                                           const CHUNK_COORDS_INT_T x,
                                           const CHUNK_COORDS_INT_T y,
                                           const CHUNK_COORDS_INT_T z) {
    if (y > CHUNK_HEIGHT - 1) { // Top (9 cases)
        if (x < 0) {
            if (z > CHUNK_DEPTH - 1) { // TopLeftBack
                return chunk_get_block(chunk->neighbors[TopLeftBack],
                                       x + CHUNK_WIDTH,
                                       y - CHUNK_HEIGHT,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // TopLeftFront
                return chunk_get_block(chunk->neighbors[TopLeftFront],
                                       x + CHUNK_WIDTH,
                                       y - CHUNK_HEIGHT,
                                       z + CHUNK_DEPTH);
            } else { // TopLeft
                return chunk_get_block(chunk->neighbors[TopLeft],
                                       x + CHUNK_WIDTH,
                                       y - CHUNK_HEIGHT,
                                       z);
            }
        } else if (x > CHUNK_WIDTH - 1) {
            if (z > CHUNK_DEPTH - 1) { // TopRightBack
                return chunk_get_block(chunk->neighbors[TopRightBack],
                                       x - CHUNK_WIDTH,
                                       y - CHUNK_HEIGHT,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // TopRightFront
                return chunk_get_block(chunk->neighbors[TopRightFront],
                                       x - CHUNK_WIDTH,
                                       y - CHUNK_HEIGHT,
                                       z + CHUNK_DEPTH);
            } else { // TopRight
                return chunk_get_block(chunk->neighbors[TopRight],
                                       x - CHUNK_WIDTH,
                                       y - CHUNK_HEIGHT,
                                       z);
            }
        } else {
            if (z > CHUNK_DEPTH - 1) { // TopBack
                return chunk_get_block(chunk->neighbors[TopBack],
                                       x,
                                       y - CHUNK_HEIGHT,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // TopFront
                return chunk_get_block(chunk->neighbors[TopFront],
                                       x,
                                       y - CHUNK_HEIGHT,
                                       z + CHUNK_DEPTH);
            } else { // Top
                return chunk_get_block(chunk->neighbors[Top], x, y - CHUNK_HEIGHT, z);
            }
        }
    } else if (y < 0) { // Bottom (9 cases)
        if (x < 0) {
            if (z > CHUNK_DEPTH - 1) { // BottomLeftBack
                return chunk_get_block(chunk->neighbors[BottomLeftBack],
                                       x + CHUNK_WIDTH,
                                       y + CHUNK_HEIGHT,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // BottomLeftFront
                return chunk_get_block(chunk->neighbors[BottomLeftFront],
                                       x + CHUNK_WIDTH,
                                       y + CHUNK_HEIGHT,
                                       z + CHUNK_DEPTH);
            } else { // BottomLeft
                return chunk_get_block(chunk->neighbors[BottomLeft],
                                       x + CHUNK_WIDTH,
                                       y + CHUNK_HEIGHT,
                                       z);
            }
        } else if (x > CHUNK_WIDTH - 1) {
            if (z > CHUNK_DEPTH - 1) { // BottomRightBack
                return chunk_get_block(chunk->neighbors[BottomRightBack],
                                       x - CHUNK_WIDTH,
                                       y + CHUNK_HEIGHT,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // BottomRightFront
                return chunk_get_block(chunk->neighbors[BottomRightFront],
                                       x - CHUNK_WIDTH,
                                       y + CHUNK_HEIGHT,
                                       z + CHUNK_DEPTH);
            } else { // BottomRight
                return chunk_get_block(chunk->neighbors[BottomRight],
                                       x - CHUNK_WIDTH,
                                       y + CHUNK_HEIGHT,
                                       z);
            }
        } else {
            if (z > CHUNK_DEPTH - 1) { // BottomBack
                return chunk_get_block(chunk->neighbors[BottomBack],
                                       x,
                                       y + CHUNK_HEIGHT,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // BottomFront
                return chunk_get_block(chunk->neighbors[BottomFront],
                                       x,
                                       y + CHUNK_HEIGHT,
                                       z + CHUNK_DEPTH);
            } else { // Bottom
                return chunk_get_block(chunk->neighbors[Bottom], x, y + CHUNK_HEIGHT, z);
            }
        }
    } else { // 8 cases (y is within chunk)
        if (x < 0) {
            if (z > CHUNK_DEPTH - 1) { // LeftBack
                return chunk_get_block(chunk->neighbors[LeftBack],
                                       x + CHUNK_WIDTH,
                                       y,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // LeftFront
                return chunk_get_block(chunk->neighbors[LeftFront],
                                       x + CHUNK_WIDTH,
                                       y,
                                       z + CHUNK_DEPTH);
            } else { // Left
                return chunk_get_block(chunk->neighbors[Left], x + CHUNK_WIDTH, y, z);
            }
        } else if (x > CHUNK_WIDTH - 1) {
            if (z > CHUNK_DEPTH - 1) { // RightBack
                return chunk_get_block(chunk->neighbors[RightBack],
                                       x - CHUNK_WIDTH,
                                       y,
                                       z - CHUNK_DEPTH);
            } else if (z < 0) { // RightFront
                return chunk_get_block(chunk->neighbors[RightFront],
                                       x - CHUNK_WIDTH,
                                       y,
                                       z + CHUNK_DEPTH);
            } else { // Right
                return chunk_get_block(chunk->neighbors[Right], x - CHUNK_WIDTH, y, z);
            }
        } else {
            if (z > CHUNK_DEPTH - 1) { // Back
                return chunk_get_block(chunk->neighbors[Back], x, y, z - CHUNK_DEPTH);
            } else if (z < 0) { // Front
                return chunk_get_block(chunk->neighbors[Front], x, y, z + CHUNK_DEPTH);
            }
        }
    }

    // looking for block within chunk
    return chunk_get_block(chunk, x, y, z);
}

Block *chunk_get_block_2(const Chunk *chunk, const int3 *pos) {
    return chunk_get_block(chunk,
                           (CHUNK_COORDS_INT_T)pos->x,
                           (CHUNK_COORDS_INT_T)pos->y,
                           (CHUNK_COORDS_INT_T)pos->z);
}

bool chunk_needs_display(const Chunk *chunk) {
    return chunk->needsDisplay;
}

const int3 *chunk_get_pos(const Chunk *chunk) {
    return chunk->pos;
}

void chunk_get_block_pos(const Chunk *chunk,
                         const CHUNK_COORDS_INT_T x,
                         const CHUNK_COORDS_INT_T y,
                         const CHUNK_COORDS_INT_T z,
                         SHAPE_COORDS_INT3_T *pos) {
    pos->x = x + (CHUNK_COORDS_INT_T)chunk->pos->x;
    pos->y = y + (CHUNK_COORDS_INT_T)chunk->pos->y;
    pos->z = z + (CHUNK_COORDS_INT_T)chunk->pos->z;
}

int chunk_get_nb_blocks(const Chunk *chunk) {
    return chunk->nbBlocks;
}

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
    const Octree *octree = shape_get_octree(shape);
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

    for (CHUNK_COORDS_INT_T x = 0; x < CHUNK_WIDTH; x++) {
        for (CHUNK_COORDS_INT_T z = 0; z < CHUNK_DEPTH; z++) {
            for (CHUNK_COORDS_INT_T y = 0; y < CHUNK_HEIGHT; y++) {
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
                    if (octree != NULL) {
                        left = (Block *)
                            octree_get_element_without_checking(octree, posX - 1, posY, posZ);
                        right = (Block *)
                            octree_get_element_without_checking(octree, posX + 1, posY, posZ);
                        front = (Block *)
                            octree_get_element_without_checking(octree, posX, posY, posZ - 1);
                        back = (Block *)
                            octree_get_element_without_checking(octree, posX, posY, posZ + 1);
                        top = (Block *)
                            octree_get_element_without_checking(octree, posX, posY + 1, posZ);
                        bottom = (Block *)
                            octree_get_element_without_checking(octree, posX, posY - 1, posZ);
                    } else {
                        left = chunk_get_block_including_neighbors(chunk, x - 1, y, z);
                        right = chunk_get_block_including_neighbors(chunk, x + 1, y, z);
                        front = chunk_get_block_including_neighbors(chunk, x, y, z - 1);
                        back = chunk_get_block_including_neighbors(chunk, x, y, z + 1);
                        top = chunk_get_block_including_neighbors(chunk, x, y + 1, z);
                        bottom = chunk_get_block_including_neighbors(chunk, x, y - 1, z);
                    }

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
#if ENABLE_TRANSPARENCY_INNER_FACES
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
                                       (transparent_bottom && b->colorIndex != bottom->colorIndex);
#else
                        renderLeft = (solid_left == false);
                        renderRight = (solid_right == false);
                        renderFront = (solid_front == false);
                        renderBack = (solid_back == false);
                        renderTop = (solid_top == false);
                        renderBottom = (solid_bottom == false);
#endif
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
                        if (octree != NULL) { // use octree to check neighbors if possible
                            topLeftBack = (Block *)octree_get_element_without_checking(octree,
                                                                                       posX - 1,
                                                                                       posY + 1,
                                                                                       posZ + 1);
                            topLeft = (Block *)octree_get_element_without_checking(octree,
                                                                                   posX - 1,
                                                                                   posY + 1,
                                                                                   posZ);
                            topLeftFront = (Block *)octree_get_element_without_checking(octree,
                                                                                        posX - 1,
                                                                                        posY + 1,
                                                                                        posZ - 1);

                            leftBack = (Block *)octree_get_element_without_checking(octree,
                                                                                    posX - 1,
                                                                                    posY,
                                                                                    posZ + 1);
                            leftFront = (Block *)octree_get_element_without_checking(octree,
                                                                                     posX - 1,
                                                                                     posY,
                                                                                     posZ - 1);

                            bottomLeftBack = (Block *)octree_get_element_without_checking(octree,
                                                                                          posX - 1,
                                                                                          posY - 1,
                                                                                          posZ + 1);
                            bottomLeft = (Block *)octree_get_element_without_checking(octree,
                                                                                      posX - 1,
                                                                                      posY - 1,
                                                                                      posZ);
                            bottomLeftFront = (Block *)octree_get_element_without_checking(octree,
                                                                                           posX - 1,
                                                                                           posY - 1,
                                                                                           posZ -
                                                                                               1);
                        } else {
                            topLeftBack = chunk_get_block_including_neighbors(chunk,
                                                                              x - 1,
                                                                              y + 1,
                                                                              z + 1);
                            topLeft = chunk_get_block_including_neighbors(chunk, x - 1, y + 1, z);
                            topLeftFront = chunk_get_block_including_neighbors(chunk,
                                                                               x - 1,
                                                                               y + 1,
                                                                               z - 1);

                            leftBack = chunk_get_block_including_neighbors(chunk, x - 1, y, z + 1);
                            leftFront = chunk_get_block_including_neighbors(chunk, x - 1, y, z - 1);

                            bottomLeftBack = chunk_get_block_including_neighbors(chunk,
                                                                                 x - 1,
                                                                                 y - 1,
                                                                                 z + 1);
                            bottomLeft = chunk_get_block_including_neighbors(chunk,
                                                                             x - 1,
                                                                             y - 1,
                                                                             z);
                            bottomLeftFront = chunk_get_block_including_neighbors(chunk,
                                                                                  x - 1,
                                                                                  y - 1,
                                                                                  z - 1);
                        }

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
                        if (octree != NULL) { // use octree to check neighbors if possible
                            topRightBack = (Block *)octree_get_element_without_checking(octree,
                                                                                        posX + 1,
                                                                                        posY + 1,
                                                                                        posZ + 1);
                            topRight = (Block *)octree_get_element_without_checking(octree,
                                                                                    posX + 1,
                                                                                    posY + 1,
                                                                                    posZ);
                            topRightFront = (Block *)octree_get_element_without_checking(octree,
                                                                                         posX + 1,
                                                                                         posY + 1,
                                                                                         posZ - 1);

                            rightBack = (Block *)octree_get_element_without_checking(octree,
                                                                                     posX + 1,
                                                                                     posY,
                                                                                     posZ + 1);
                            rightFront = (Block *)octree_get_element_without_checking(octree,
                                                                                      posX + 1,
                                                                                      posY,
                                                                                      posZ - 1);

                            bottomRightBack = (Block *)octree_get_element_without_checking(octree,
                                                                                           posX + 1,
                                                                                           posY - 1,
                                                                                           posZ +
                                                                                               1);
                            bottomRight = (Block *)octree_get_element_without_checking(octree,
                                                                                       posX + 1,
                                                                                       posY - 1,
                                                                                       posZ);
                            bottomRightFront = (Block *)octree_get_element_without_checking(
                                octree,
                                posX + 1,
                                posY - 1,
                                posZ - 1);
                        } else {
                            topRightBack = chunk_get_block_including_neighbors(chunk,
                                                                               x + 1,
                                                                               y + 1,
                                                                               z + 1);
                            topRight = chunk_get_block_including_neighbors(chunk, x + 1, y + 1, z);
                            topRightFront = chunk_get_block_including_neighbors(chunk,
                                                                                x + 1,
                                                                                y + 1,
                                                                                z - 1);

                            rightBack = chunk_get_block_including_neighbors(chunk, x + 1, y, z + 1);
                            rightFront = chunk_get_block_including_neighbors(chunk,
                                                                             x + 1,
                                                                             y,
                                                                             z - 1);

                            bottomRightBack = chunk_get_block_including_neighbors(chunk,
                                                                                  x + 1,
                                                                                  y - 1,
                                                                                  z + 1);
                            bottomRight = chunk_get_block_including_neighbors(chunk,
                                                                              x + 1,
                                                                              y - 1,
                                                                              z);
                            bottomRightFront = chunk_get_block_including_neighbors(chunk,
                                                                                   x + 1,
                                                                                   y - 1,
                                                                                   z - 1);
                        }

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
                        if (octree != NULL) { // use octree to check neighbors if possible
                            if (renderRight == false) {
                                topRightFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY + 1,
                                    posZ - 1);
                                rightFront = (Block *)octree_get_element_without_checking(octree,
                                                                                          posX + 1,
                                                                                          posY,
                                                                                          posZ - 1);
                                bottomRightFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY - 1,
                                    posZ - 1);
                            }

                            if (renderLeft == false) {
                                topLeftFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX - 1,
                                    posY + 1,
                                    posZ - 1);
                                leftFront = (Block *)octree_get_element_without_checking(octree,
                                                                                         posX - 1,
                                                                                         posY,
                                                                                         posZ - 1);
                                bottomLeftFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX - 1,
                                    posY - 1,
                                    posZ - 1);
                            }

                            topFront = (Block *)octree_get_element_without_checking(octree,
                                                                                    posX,
                                                                                    posY + 1,
                                                                                    posZ - 1);
                            bottomFront = (Block *)octree_get_element_without_checking(octree,
                                                                                       posX,
                                                                                       posY - 1,
                                                                                       posZ - 1);
                        } else {
                            if (renderRight == false) {
                                topRightFront = chunk_get_block_including_neighbors(chunk,
                                                                                    x + 1,
                                                                                    y + 1,
                                                                                    z - 1);
                                rightFront = chunk_get_block_including_neighbors(chunk,
                                                                                 x + 1,
                                                                                 y,
                                                                                 z - 1);
                                bottomRightFront = chunk_get_block_including_neighbors(chunk,
                                                                                       x + 1,
                                                                                       y - 1,
                                                                                       z - 1);
                            }

                            if (renderLeft == false) {
                                topLeftFront = chunk_get_block_including_neighbors(chunk,
                                                                                   x - 1,
                                                                                   y + 1,
                                                                                   z - 1);
                                leftFront = chunk_get_block_including_neighbors(chunk,
                                                                                x - 1,
                                                                                y,
                                                                                z - 1);
                                bottomLeftFront = chunk_get_block_including_neighbors(chunk,
                                                                                      x - 1,
                                                                                      y - 1,
                                                                                      z - 1);
                            }

                            topFront = chunk_get_block_including_neighbors(chunk, x, y + 1, z - 1);
                            bottomFront = chunk_get_block_including_neighbors(chunk,
                                                                              x,
                                                                              y - 1,
                                                                              z - 1);
                        }

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
                        if (octree != NULL) { // use octree to check neighbors if possible
                            if (renderRight == false) {
                                topRightBack = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY + 1,
                                    posZ + 1);
                                rightBack = (Block *)octree_get_element_without_checking(octree,
                                                                                         posX + 1,
                                                                                         posY,
                                                                                         posZ + 1);
                                bottomRightBack = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY - 1,
                                    posZ + 1);
                            }

                            if (renderLeft == false) {
                                topLeftBack = (Block *)octree_get_element_without_checking(octree,
                                                                                           posX - 1,
                                                                                           posY + 1,
                                                                                           posZ +
                                                                                               1);
                                leftBack = (Block *)octree_get_element_without_checking(octree,
                                                                                        posX - 1,
                                                                                        posY,
                                                                                        posZ + 1);
                                bottomLeftBack = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX - 1,
                                    posY - 1,
                                    posZ + 1);
                            }

                            topBack = (Block *)octree_get_element_without_checking(octree,
                                                                                   posX,
                                                                                   posY + 1,
                                                                                   posZ + 1);
                            bottomBack = (Block *)octree_get_element_without_checking(octree,
                                                                                      posX,
                                                                                      posY - 1,
                                                                                      posZ + 1);
                        } else {
                            if (renderRight == false) {
                                topRightBack = chunk_get_block_including_neighbors(chunk,
                                                                                   x + 1,
                                                                                   y + 1,
                                                                                   z + 1);
                                rightBack = chunk_get_block_including_neighbors(chunk,
                                                                                x + 1,
                                                                                y,
                                                                                z + 1);
                                bottomRightBack = chunk_get_block_including_neighbors(chunk,
                                                                                      x + 1,
                                                                                      y - 1,
                                                                                      z + 1);
                            }

                            if (renderLeft == false) {
                                topLeftBack = chunk_get_block_including_neighbors(chunk,
                                                                                  x - 1,
                                                                                  y + 1,
                                                                                  z + 1);
                                leftBack = chunk_get_block_including_neighbors(chunk,
                                                                               x - 1,
                                                                               y,
                                                                               z + 1);
                                bottomLeftBack = chunk_get_block_including_neighbors(chunk,
                                                                                     x - 1,
                                                                                     y - 1,
                                                                                     z + 1);
                            }

                            topBack = chunk_get_block_including_neighbors(chunk, x, y + 1, z + 1);
                            bottomBack = chunk_get_block_including_neighbors(chunk,
                                                                             x,
                                                                             y - 1,
                                                                             z + 1);
                        }

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
                        if (octree != NULL) { // use octree to check neighbors if possible
                            if (renderLeft == false) {
                                topLeftBack = (Block *)octree_get_element_without_checking(octree,
                                                                                           posX - 1,
                                                                                           posY + 1,
                                                                                           posZ +
                                                                                               1);
                                topLeft = (Block *)octree_get_element_without_checking(octree,
                                                                                       posX - 1,
                                                                                       posY + 1,
                                                                                       posZ);
                                topLeftFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX - 1,
                                    posY + 1,
                                    posZ - 1);
                            }

                            if (renderRight == false) {
                                topRightBack = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY + 1,
                                    posZ + 1);
                                topRight = (Block *)octree_get_element_without_checking(octree,
                                                                                        posX + 1,
                                                                                        posY + 1,
                                                                                        posZ);
                                topRightFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY + 1,
                                    posZ - 1);
                            }

                            if (renderBack == false) {
                                topBack = (Block *)octree_get_element_without_checking(octree,
                                                                                       posX,
                                                                                       posY + 1,
                                                                                       posZ + 1);
                            }

                            if (renderFront == false) {
                                topFront = (Block *)octree_get_element_without_checking(octree,
                                                                                        posX,
                                                                                        posY + 1,
                                                                                        posZ - 1);
                            }
                        } else {
                            if (renderLeft == false) {
                                topLeftBack = chunk_get_block_including_neighbors(chunk,
                                                                                  x - 1,
                                                                                  y + 1,
                                                                                  z + 1);
                                topLeft = chunk_get_block_including_neighbors(chunk,
                                                                              x - 1,
                                                                              y + 1,
                                                                              z);
                                topLeftFront = chunk_get_block_including_neighbors(chunk,
                                                                                   x - 1,
                                                                                   y + 1,
                                                                                   z - 1);
                            }

                            if (renderRight == false) {
                                topRightBack = chunk_get_block_including_neighbors(chunk,
                                                                                   x + 1,
                                                                                   y + 1,
                                                                                   z + 1);
                                topRight = chunk_get_block_including_neighbors(chunk,
                                                                               x + 1,
                                                                               y + 1,
                                                                               z);
                                topRightFront = chunk_get_block_including_neighbors(chunk,
                                                                                    x + 1,
                                                                                    y + 1,
                                                                                    z - 1);
                            }

                            if (renderBack == false) {
                                topBack = chunk_get_block_including_neighbors(chunk,
                                                                              x,
                                                                              y + 1,
                                                                              z + 1);
                            }

                            if (renderFront == false) {
                                topFront = chunk_get_block_including_neighbors(chunk,
                                                                               x,
                                                                               y + 1,
                                                                               z - 1);
                            }
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
                        if (octree != NULL) { // use octree to check neighbors if possible
                            if (renderLeft == false) {
                                bottomLeftBack = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX - 1,
                                    posY - 1,
                                    posZ + 1);
                                bottomLeft = (Block *)octree_get_element_without_checking(octree,
                                                                                          posX - 1,
                                                                                          posY - 1,
                                                                                          posZ);
                                bottomLeftFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX - 1,
                                    posY - 1,
                                    posZ - 1);
                            }

                            if (renderRight == false) {
                                bottomRightBack = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY - 1,
                                    posZ + 1);
                                bottomRight = (Block *)octree_get_element_without_checking(octree,
                                                                                           posX + 1,
                                                                                           posY - 1,
                                                                                           posZ);
                                bottomRightFront = (Block *)octree_get_element_without_checking(
                                    octree,
                                    posX + 1,
                                    posY - 1,
                                    posZ - 1);
                            }

                            if (renderBack == false) {
                                bottomBack = (Block *)octree_get_element_without_checking(octree,
                                                                                          posX,
                                                                                          posY - 1,
                                                                                          posZ + 1);
                            }

                            if (renderFront == false) {
                                bottomFront = (Block *)octree_get_element_without_checking(octree,
                                                                                           posX,
                                                                                           posY - 1,
                                                                                           posZ -
                                                                                               1);
                            }
                        } else {
                            if (renderLeft == false) {
                                bottomLeftBack = chunk_get_block_including_neighbors(chunk,
                                                                                     x - 1,
                                                                                     y - 1,
                                                                                     z + 1);
                                bottomLeft = chunk_get_block_including_neighbors(chunk,
                                                                                 x - 1,
                                                                                 y - 1,
                                                                                 z);
                                bottomLeftFront = chunk_get_block_including_neighbors(chunk,
                                                                                      x - 1,
                                                                                      y - 1,
                                                                                      z - 1);
                            }

                            if (renderRight == false) {
                                bottomRightBack = chunk_get_block_including_neighbors(chunk,
                                                                                      x + 1,
                                                                                      y - 1,
                                                                                      z + 1);
                                bottomRight = chunk_get_block_including_neighbors(chunk,
                                                                                  x + 1,
                                                                                  y - 1,
                                                                                  z);
                                bottomRightFront = chunk_get_block_including_neighbors(chunk,
                                                                                       x + 1,
                                                                                       y - 1,
                                                                                       z - 1);
                            }

                            if (renderBack == false) {
                                bottomBack = chunk_get_block_including_neighbors(chunk,
                                                                                 x,
                                                                                 y - 1,
                                                                                 z + 1);
                            }

                            if (renderFront == false) {
                                bottomFront = chunk_get_block_including_neighbors(chunk,
                                                                                  x,
                                                                                  y - 1,
                                                                                  z - 1);
                            }
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

void chunk_get_inner_bounds(const Chunk *chunk,
                            CHUNK_COORDS_INT_T *min_x,
                            CHUNK_COORDS_INT_T *max_x,
                            CHUNK_COORDS_INT_T *min_y,
                            CHUNK_COORDS_INT_T *max_y,
                            CHUNK_COORDS_INT_T *min_z,
                            CHUNK_COORDS_INT_T *max_z) {

    *min_x = CHUNK_WIDTH - 1;
    *min_y = CHUNK_HEIGHT - 1;
    *min_z = CHUNK_DEPTH - 1;
    *max_x = 0;
    *max_y = 0;
    *max_z = 0;

    Block *b;
    bool at_least_one_block = false;

    for (CHUNK_COORDS_INT_T x = 0; x < CHUNK_WIDTH; x++) {
        for (CHUNK_COORDS_INT_T z = 0; z < CHUNK_DEPTH; z++) {
            for (CHUNK_COORDS_INT_T y = 0; y < CHUNK_HEIGHT; y++) {
                b = chunk_get_block(chunk, x, y, z);
                if (b != NULL) {
                    at_least_one_block = true;
                    *min_x = x < *min_x ? x : *min_x;
                    *min_y = y < *min_y ? y : *min_y;
                    *min_z = z < *min_z ? z : *min_z;
                    *max_x = x > *max_x ? x : *max_x;
                    *max_y = y > *max_y ? y : *max_y;
                    *max_z = z > *max_z ? z : *max_z;
                }
            }
        }
    }

    // no block: all values should be set to 0
    if (at_least_one_block == false) {
        cclog_warning("chunk_get_inner_bounds called on empty chunk");
        *min_x = 0;
        *min_y = 0;
        *min_z = 0;
    } else {
        // otherwise, max values should be incremented
        *max_x += 1;
        *max_y += 1;
        *max_z += 1;
    }
}

// MARK: private functions

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
