// -------------------------------------------------------------
//  Cubzh Core
//  block.c
//  Created by Adrien Duermael on July 19, 2015.
// -------------------------------------------------------------

#include "block.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "config.h"
#include "filo_list_int3.h"
#include "shape.h"

Block *block_new(void) {
    return block_new_with_color(0);
}

Block *block_new_air(void) {
    return block_new_with_color(SHAPE_COLOR_INDEX_AIR_BLOCK);
}

Block *block_new_with_color(const SHAPE_COLOR_INDEX_INT_T colorIndex) {
    Block *b = (Block *)malloc(sizeof(Block));
    if (b != NULL) {
        b->colorIndex = colorIndex;
    }
    return b;
}

Block *block_new_copy(const Block *block) {
    if (block == NULL) {
        return NULL;
    }
    Block *newBlock = (Block *)malloc(sizeof(Block));
    if (newBlock != NULL) {
        newBlock->colorIndex = block->colorIndex;
    }
    return newBlock;
}

void block_free(Block *b) {
    free(b);
}

void block_set_color_index(Block *block, const SHAPE_COLOR_INDEX_INT_T colorIndex) {
    if (block == NULL) {
        return;
    }
    block->colorIndex = colorIndex;
}

SHAPE_COLOR_INDEX_INT_T block_get_color_index(const Block *block) {
    return block->colorIndex;
}

bool block_is_solid(const Block *const block) {
    return block != NULL && block->colorIndex != SHAPE_COLOR_INDEX_AIR_BLOCK;
}

bool block_is_opaque(const Block *block, const ColorPalette *palette) {
    return block_is_solid(block) &&
           color_palette_is_transparent(palette, block->colorIndex) == false;
}

bool block_is_transparent(Block *block, const ColorPalette *palette) {
    return block_is_solid(block) && color_palette_is_transparent(palette, block->colorIndex);
}

void block_is_ao_and_light_caster(Block *block,
                                  const ColorPalette *palette,
                                  bool *ao,
                                  bool *light) {
#if ENABLE_TRANSPARENCY_AO_CASTER
    *ao = block_is_solid(block);
    *light = ((*ao) == false);
#else
    *ao = block_is_opaque(block, palette);
    *light = (block_is_solid(block) == false);
#endif
}

void block_is_any(Block *block,
                  const ColorPalette *palette,
                  bool *solid,
                  bool *opaque,
                  bool *transparent,
                  bool *aoCaster,
                  bool *lightCaster) {
    bool s = (block != NULL && block->colorIndex != SHAPE_COLOR_INDEX_AIR_BLOCK);
    bool t = (block != NULL && color_palette_is_transparent(palette, block->colorIndex));
    bool o = (s && t == false);

    if (solid != NULL) {
        *solid = s;
    }
    if (transparent != NULL) {
        *transparent = t;
    }
    if (opaque != NULL) {
        *opaque = o;
    }

    if (aoCaster != NULL && lightCaster != NULL) {
#if ENABLE_TRANSPARENCY_AO_CASTER
        *aoCaster = s;
        *light = (s == false);
#else
        *aoCaster = o;
        *lightCaster = (s == false);
#endif
    }
}

// FullBlock definition

struct _AwareBlock {
    Block *block;
    // global position within the shape
    int3 *shapePos;
    // position within the chunl
    int3 *chunkPos;
    // this is the empty block location that touches the touchedFace
    int3 *shapeTargetPos;

    FACE_INDEX_INT_T touchedFace;

    char pad[7];
};

void aware_block_update_world_target(AwareBlock *aBlock) {

    if (aBlock->touchedFace < FACE_SIZE && aBlock->shapePos != NULL) {

        if (aBlock->shapeTargetPos == NULL) {
            aBlock->shapeTargetPos = int3_new_copy(aBlock->shapePos);
        } else {
            int3_copy(aBlock->shapeTargetPos, aBlock->shapePos);
        }

        int3 *i3 = int3_new(0, 0, 0);

        switch (aBlock->touchedFace) {

            case FACE_RIGHT_CTC:
                int3_set(i3, 1, 0, 0);
                break;
            case FACE_LEFT_CTC:
                int3_set(i3, -1, 0, 0);
                break;

            case FACE_TOP_CTC:
                int3_set(i3, 0, 1, 0);
                break;
            case FACE_DOWN_CTC:
                int3_set(i3, 0, -1, 0);
                break;

            case FACE_BACK_CTC:
                int3_set(i3, 0, 0, -1);
                break;
            case FACE_FRONT_CTC:
                int3_set(i3, 0, 0, 1);
                break;

            default:
                free(i3);
                free(aBlock->shapeTargetPos);
                aBlock->shapeTargetPos = NULL;
                return;
        }

        int3_op_add(aBlock->shapeTargetPos, i3);
        free(i3);
    } else {
        int3_free(aBlock->shapeTargetPos);
        aBlock->shapeTargetPos = NULL;
    }
}

AwareBlock *aware_block_new(const Block *block,
                            const int3 *shapePos,
                            const int3 *chunkPos,
                            FACE_INDEX_INT_T faceIndex) {

    AwareBlock *aBlock = (AwareBlock *)malloc(sizeof(AwareBlock));
    if (aBlock == NULL) {
        return NULL;
    }
    aBlock->block = block_new_copy(block);

    aBlock->shapePos = NULL;
    if (shapePos != NULL) {
        aBlock->shapePos = int3_new_copy(shapePos);
    }

    aBlock->chunkPos = NULL;
    if (chunkPos != NULL) {
        aBlock->chunkPos = int3_new_copy(chunkPos);
    }

    aBlock->touchedFace = faceIndex;
    aBlock->shapeTargetPos = NULL;

    aware_block_update_world_target(aBlock);

    return aBlock;
}

AwareBlock *aware_block_new_copy(const AwareBlock *aBlockSource) {

    if (aBlockSource == NULL) {
        return NULL;
    }

    AwareBlock *aBlock = (AwareBlock *)malloc(sizeof(AwareBlock));
    if (aBlock == NULL) {
        return NULL;
    }
    aBlock->block = block_new_copy(aBlockSource->block);

    aBlock->shapePos = NULL;
    if (aBlockSource->shapePos != NULL) {
        aBlock->shapePos = int3_new_copy(aBlockSource->shapePos);
    }

    aBlock->chunkPos = NULL;
    if (aBlockSource->chunkPos != NULL) {
        aBlock->chunkPos = int3_new_copy(aBlockSource->chunkPos);
    }

    aBlock->shapeTargetPos = NULL;
    if (aBlockSource->shapeTargetPos != NULL) {
        aBlock->shapeTargetPos = int3_new_copy(aBlockSource->shapeTargetPos);
    }

    aBlock->touchedFace = aBlockSource->touchedFace;
    return aBlock;
}

void aware_block_set_touched_face(AwareBlock *aBlock, FACE_INDEX_INT_T faceIndex) {
    aBlock->touchedFace = faceIndex;
    aware_block_update_world_target(aBlock);
}

Block *aware_block_get_block(AwareBlock *aBlock) {
    return aBlock->block;
}

SHAPE_COLOR_INDEX_INT_T aware_block_get_color_index(AwareBlock *aBlock) {
    return block_get_color_index(aware_block_get_block(aBlock));
}

int3 *aware_block_get_shape_pos(AwareBlock *aBlock) {
    return aBlock->shapePos;
}

int3 *aware_block_get_chunk_pos(AwareBlock *aBlock) {
    return aBlock->chunkPos;
}

int3 *aware_block_get_shape_target_pos(AwareBlock *aBlock) {
    return aBlock->shapeTargetPos;
}

void aware_block_free(AwareBlock *aBlock) {
    if (aBlock == NULL) {
        return;
    }
    block_free(aBlock->block);
    int3_free(aBlock->chunkPos);
    int3_free(aBlock->shapePos);
    int3_free(aBlock->shapeTargetPos);
    free(aBlock);
}

void aware_block_free_2(void *aBlockVoided) {
    if (aBlockVoided == NULL) {
        return;
    }
    AwareBlock *aBlock = (AwareBlock *)aBlockVoided;
    block_free(aBlock->block);
    int3_free(aBlock->chunkPos);
    int3_free(aBlock->shapePos);
    int3_free(aBlock->shapeTargetPos);
    free(aBlock);
}

bool block_equal(const Block *b1, const Block *b2) {
    if (b1 == NULL && b2 == NULL)
        return true;
    if (b1 == NULL)
        return false;
    else if (b2 == NULL)
        return false;
    return b1->colorIndex == b2->colorIndex;
}

bool block_getNeighbourBlockCoordinates(const SHAPE_COORDS_INT_T x,
                                        const SHAPE_COORDS_INT_T y,
                                        const SHAPE_COORDS_INT_T z,
                                        const int face,
                                        SHAPE_COORDS_INT_T *newX,
                                        SHAPE_COORDS_INT_T *newY,
                                        SHAPE_COORDS_INT_T *newZ) {

    vx_assert(newX != NULL || newY != NULL || newZ != NULL);
    vx_assert(face >= 0 && face < FACE_SIZE_CTC);

    SHAPE_COORDS_INT_T resultX = x;
    SHAPE_COORDS_INT_T resultY = y;
    SHAPE_COORDS_INT_T resultZ = z;

    switch (face) {
        case FACE_LEFT_CTC:
            if (x == SHAPE_COORDS_MIN) {
                return false;
            } else {
                resultX -= 1;
            }
            break;
        case FACE_RIGHT_CTC:
            if (x == SHAPE_COORDS_MAX) {
                return false;
            } else {
                resultX += 1;
            }
            break;
        case FACE_TOP_CTC:
            if (y == SHAPE_COORDS_MAX) {
                return false;
            } else {
                resultY += 1;
            }
            break;
        case FACE_DOWN_CTC:
            if (y == SHAPE_COORDS_MIN) {
                return false;
            } else {
                resultY -= 1;
            }
            break;
        case FACE_BACK_CTC:
            if (z == SHAPE_COORDS_MIN) {
                return false;
            } else {
                resultZ -= 1;
            }
            break;
        case FACE_FRONT_CTC:
            if (z == SHAPE_COORDS_MAX) {
                return false;
            } else {
                resultZ += 1;
            }
            break;
        default:
            return false;
    }

    if (newX != NULL)
        *newX = resultX;
    if (newY != NULL)
        *newY = resultY;
    if (newZ != NULL)
        *newZ = resultZ;

    return true;
}
