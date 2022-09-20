// -------------------------------------------------------------
//  Cubzh Core
//  magicavoxel.c
//  Created by Gaetan de Villele on June 06, 2022.
// -------------------------------------------------------------

#include "magicavoxel.h"

#include <string.h>

#include "cclog.h"
#include "colors.h"
#include "serialization.h"
#include "shape.h"
#include "stream.h"

#define VOX_MAGIC_BYTES "VOX "
#define VOX_MAGIC_BYTES_SIZE 4

#define MAIN_CHUNK_HEADER "MAIN"
#define CHUNK_HEADER_SIZE 4
#define CHUNK_HEADER_SIZE_PLUS_ONE 5

#define VOX_NB_COLORS 256 // there are always 256 colors in a .vox

bool _readExpectedBytes(Stream *s, const char *bytes, size_t size) {
    char current = 0;
    for (size_t i = 0; i < size; ++i) {
        if (stream_read(s, &current, sizeof(char), 1) == false) {
            cclog_error("failed to read magic byte");
            return false;
        }
        if (current != bytes[i]) {
            cclog_error("incorrect magic bytes");
            return false;
        }
    }
    return true;
}

bool serialization_save_vox(const Shape *const src, FILE *const out) {
    int3 shape_size;
    SHAPE_COORDS_INT_T origin_x = 0;
    SHAPE_COORDS_INT_T origin_y = 0;
    SHAPE_COORDS_INT_T origin_z = 0;

    // validate arguments
    if (src == NULL) {
        cclog_error("shape pointer is NULL");
        return false;
    }

    if (out == NULL) {
        cclog_error("file pointer is NULL");
        return false;
    }

    shape_get_fixed_size(src, &shape_size);

    // shift is used to compensate negative origin != (0,0,0)
    // .vox does not support negative coordinates
    // and I believe the first block is always at (0,0,0)
    SHAPE_COORDS_INT_T shift_x = -origin_x;
    SHAPE_COORDS_INT_T shift_y = -origin_y;
    SHAPE_COORDS_INT_T shift_z = -origin_z;

    if (shape_size.x > 256 || shape_size.y > 256 || shape_size.z > 256) {
        cclog_error("💾 shape is too big, can't export for magicavoxel");
        return false;
    }

    // write 'VOX '
    if (fwrite("VOX ", sizeof(char), 4, out) != 4) {
        cclog_error("failed to write \'VOX \'");
        return false;
    }

    // version number
    uint32_t format = 150;
    if (fwrite(&format, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write file format");
        return false;
    }

    // MAIN chunk
    if (fwrite("MAIN", sizeof(char), 4, out) != 4) {
        cclog_error("failed to write \'MAIN\'");
        return false;
    }

    // size of MAIN chunk content: 0 (actual content is in children)
    uint32_t zero_bytes = 0;
    if (fwrite(&zero_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write MAIN size");
        return false;
    }

    // size of children
    // - CHUNK HEADER: 4 + 4 + 4 = 12
    // - SIZE: 12 + 12 = 24
    // - XYZI: 12 + 4 + 4 x nb_blocks
    // - RGBA depends on palette

    size_t nb_blocks = shape_get_nb_blocks(src);

    uint32_t chunk_header_bytes = 12;
    uint32_t size_bytes = 12;
    uint32_t xyzi_bytes = 4 + 4 * (uint32_t)(nb_blocks);
    uint32_t rgba_bytes = 256 * 4;

    uint32_t children_bytes = chunk_header_bytes + size_bytes + chunk_header_bytes + xyzi_bytes +
                              chunk_header_bytes + rgba_bytes;

    if (fwrite(&children_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write MAIN children size");
        return false;
    }

    // no PACK chunk

    // SIZE chunk
    if (fwrite("SIZE", sizeof(char), 4, out) != 4) {
        cclog_error("failed to write \'MAIN\'");
        return false;
    }

    // size of SIZE chunk
    if (fwrite(&size_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write MAIN size");
        return false;
    }

    // size of SIZE children
    if (fwrite(&zero_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write MAIN size");
        return false;
    }

    // blocks

    // x
    uint32_t x = (uint32_t)shape_size.x;
    if (fwrite(&x, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write SIZE x");
        return false;
    }

    // y
    uint32_t y = (uint32_t)shape_size.z;
    if (fwrite(&y, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write SIZE y");
        return false;
    }

    // z
    uint32_t z = (uint32_t)shape_size.y;
    if (fwrite(&z, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write SIZE x");
        return false;
    }

    // XYZI chunk
    if (fwrite("XYZI", sizeof(char), 4, out) != 4) {
        cclog_error("failed to write 'XYZI'");
        return false;
    }

    // size of XYZI chunk
    if (fwrite(&xyzi_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write XYZI size");
        return false;
    }

    // size of XYZI children
    if (fwrite(&zero_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write XYZI children size");
        return false;
    }

    // XYZI: nb voxels
    uint32_t n = (uint32_t)nb_blocks;
    if (fwrite(&n, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write XYZI nb voxels");
        return false;
    }

    // loop over blocks

    Chunk *chunk = NULL;
    int3 *shapePos = int3_new(0, 0, 0);
    int3 *posInChunk = int3_new(0, 0, 0);
    Block *b = NULL;

    for (int k = 0; k < shape_size.z; k++) {
        for (int j = 0; j < shape_size.y; j++) {
            for (int i = 0; i < shape_size.x; i++) {
                b = NULL;

                int3_set(shapePos, (i + origin_x), (j + origin_y), (k + origin_z));

                shape_get_chunk_and_position_within(src, shapePos, &chunk, NULL, posInChunk);
                if (chunk != NULL) {
                    b = chunk_get_block_2(chunk, posInChunk);
                }

                if (b == NULL) {
                    // no block, don't do anything
                } else {
                    uint16_t bci = block_get_color_index(b);

                    // ⚠️ y -> z, z -> y
                    uint8_t x = (uint8_t)shapePos->x + shift_x;
                    uint8_t y = (uint8_t)shapePos->z + shift_z;
                    uint8_t z = (uint8_t)shapePos->y + shift_y;
                    uint8_t c = (uint8_t)bci + 1;

                    // printf("block : %d, %d, %d - color: %d\n", x, y, z, c);

                    if (fwrite(&x, sizeof(uint8_t), 1, out) != 1) {
                        cclog_error("failed to write x size");
                        return false;
                    }

                    if (fwrite(&y, sizeof(uint8_t), 1, out) != 1) {
                        cclog_error("failed to write y size");
                        return false;
                    }

                    if (fwrite(&z, sizeof(uint8_t), 1, out) != 1) {
                        cclog_error("failed to write z size");
                        return false;
                    }

                    if (fwrite(&c, sizeof(uint8_t), 1, out) != 1) {
                        cclog_error("failed to write c size");
                        return false;
                    }
                }
            }
        }
    }

    // RGBA chunk

    // RGBA chunk
    if (fwrite("RGBA", sizeof(char), 4, out) != 4) {
        cclog_error("failed to write \'RGBA\'");
        return false;
    }

    // size of RGBA chunk
    if (fwrite(&rgba_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write RGBA size");
        return false;
    }

    // size of RGBA children
    if (fwrite(&zero_bytes, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write RGBA children size");
        return false;
    }

    uint8_t zero = 0;

    const ColorPalette *palette = shape_get_palette(src);
    uint16_t nbColors = palette->count;

    RGBAColor *color = NULL;

    for (int i = 0; i < 256; i++) {
        if (i < nbColors) {
            color = color_palette_get_color(palette, i);
            // r
            if (fwrite(&color->r, sizeof(uint8_t), 1, out) != 1) {
                cclog_error("failed to write r");
                return false;
            }
            // g
            if (fwrite(&color->g, sizeof(uint8_t), 1, out) != 1) {
                cclog_error("failed to write g");
                return false;
            }
            // b
            if (fwrite(&color->b, sizeof(uint8_t), 1, out) != 1) {
                cclog_error("failed to write b");
                return false;
            }
            // a
            if (fwrite(&color->a, sizeof(uint8_t), 1, out) != 1) {
                cclog_error("failed to write a");
                return false;
            }
        } else {
            for (int j = 0; j < 4; j++) {
                if (fwrite(&zero, sizeof(uint8_t), 1, out) != 1) {
                    cclog_error("failed to write empty color");
                    return false;
                }
            }
        }
    }

    return true;
}

enum serialization_magicavoxel_error serialization_vox_to_shape(Stream *s,
                                                                Shape **out,
                                                                const bool isMutable,
                                                                ColorAtlas *colorAtlas,
                                                                bool sharedColors) {

    vx_assert(s != NULL);
    vx_assert(out != NULL);
    vx_assert(*out == NULL);

    // read magic bytes
    if (_readExpectedBytes(s, VOX_MAGIC_BYTES, VOX_MAGIC_BYTES_SIZE) == false) {
        return invalid_format;
    }

    // read file format
    uint32_t fileFormatVersion = 0;
    if (stream_read_uint32(s, &fileFormatVersion) == false) {
        cclog_error("failed to read file format");
        return invalid_format;
    }

    // read MAIN chunk
    if (_readExpectedBytes(s, MAIN_CHUNK_HEADER, CHUNK_HEADER_SIZE) == false) {
        cclog_error("MAIN chunk not found");
        return invalid_format;
    }

    // read main chunk info

    uint32_t main_chunk_content_bytes = 0;
    if (stream_read_uint32(s, &main_chunk_content_bytes) == false) {
        cclog_error("failed to read main chunk content bytes");
        return invalid_format;
    }

    uint32_t main_chunk_children_content_bytes = 0;
    if (stream_read_uint32(s, &main_chunk_children_content_bytes) == false) {
        cclog_error("failed to read main chunk children content bytes");
        return invalid_format;
    }

    // MAIN chunk shouldn't store data directly, it's only there to
    // reference children.
    if (main_chunk_content_bytes > 0) {
        cclog_error("MAIN chunk content size > 0");
        return invalid_format;
    }

    // It really looks like a .vox file

    *out = NULL;

    // read chunks

    char chunkName[CHUNK_HEADER_SIZE_PLUS_ONE]; // chunkNameSize
    chunkName[CHUNK_HEADER_SIZE] = '\0';        // null termination char

    uint32_t current_chunk_content_bytes;
    uint32_t current_chunk_children_content_bytes;
    uint32_t sizeX = 0;
    uint32_t sizeY = 0;
    uint32_t sizeZ = 0;

    enum serialization_magicavoxel_error err = no_error;

    size_t blocksPosition = 0;
    RGBAColor *colors = malloc(sizeof(RGBAColor) * VOX_NB_COLORS);
    for (int i = 0; i < VOX_NB_COLORS; ++i) {
        colors[i].r = 0;
        colors[i].g = 0;
        colors[i].b = 0;
        colors[i].a = 0;
    }

    while (stream_reached_the_end(s) == false) {

        if (stream_read(s, chunkName, CHUNK_HEADER_SIZE, 1) == false) {
            cclog_error("could not read chunk name", chunkName);
            err = invalid_format;
            break;
        }

        if (stream_read_uint32(s, &current_chunk_content_bytes) == false) {
            cclog_error("could not read chunk content bytes (%s)", chunkName);
            err = invalid_format;
            break;
        }

        if (stream_read_uint32(s, &current_chunk_children_content_bytes) == false) {
            cclog_error("could not read chunk children content bytes (%s)", chunkName);
            err = invalid_format;
            break;
        }

        // PACK
        if (strcmp(chunkName, "PACK") == 0) {

            uint32_t nbModels = 0;
            if (stream_read_uint32(s, &nbModels) == false) {
                cclog_error("could not read number of models");
                err = invalid_format;
                break;
            }

            if (nbModels > 1) {
                cclog_error("PACK with more than 1 model not supported");
                err = pack_chunk_found;
                break;
            }
        }
        // SIZE
        else if (strcmp(chunkName, "SIZE") == 0) {
            // ⚠️ y -> z, z -> y
            if (stream_read_uint32(s, &sizeX) == false) {
                cclog_error("could not read sizeX");
                err = invalid_format;
                break;
            }

            if (stream_read_uint32(s, &sizeZ) == false) {
                cclog_error("could not read sizeZ");
                err = invalid_format;
                break;
            }

            if (stream_read_uint32(s, &sizeY) == false) {
                cclog_error("could not read sizeY");
                err = invalid_format;
                break;
            }
        }
        // XYZI
        else if (strcmp(chunkName, "XYZI") == 0) {
            // Found blocks, but palette not loaded, keeping for later

            blocksPosition = stream_get_cursor_position(s);

            uint32_t nbVoxels;
            if (stream_read_uint32(s, &nbVoxels) == false) {
                cclog_error("could not read nbVoxels");
                shape_release(*out);
                return invalid_format;
            }

            stream_skip(s, 4 * nbVoxels);
        }

        // RGBA (palette)
        else if (strcmp(chunkName, "RGBA") == 0) {

            if (current_chunk_content_bytes != 256 * 4) {
                cclog_error("invalid RGBA chunk format");
                err = invalid_format;
                break;
            }

            for (int i = 0; i < VOX_NB_COLORS; i++) {

                if (stream_read_uint8(s, &(colors[i].r)) == false) {
                    cclog_error("could not read r");
                    err = invalid_format;
                    break;
                }

                if (stream_read_uint8(s, &(colors[i].g)) == false) {
                    cclog_error("could not read g");
                    err = invalid_format;
                    break;
                }

                if (stream_read_uint8(s, &(colors[i].b)) == false) {
                    cclog_error("could not read b");
                    err = invalid_format;
                    break;
                }

                if (stream_read_uint8(s, &(colors[i].a)) == false) {
                    cclog_error("could not read a");
                    err = invalid_format;
                    break;
                }
            }
        }
        // UNSUPPORTED CHUNK
        else {
            // chunk not saved, skipping
            stream_skip(s, current_chunk_content_bytes + current_chunk_children_content_bytes);
        }
    }

    if (err != no_error || sizeX == 0 || sizeY == 0 || sizeZ == 0 || blocksPosition == 0) {
        free(colors);
        if (err == no_error) {
            return invalid_format;
        }
        return err;
    }

    // create Shape
    *out = shape_make_with_octree(sizeX, sizeY, sizeZ, false, isMutable, true);
    shape_set_palette(*out, color_palette_new(colorAtlas, sharedColors));

    stream_set_cursor_position(s, blocksPosition);

    uint32_t nbVoxels;
    uint8_t x, y, z;
    SHAPE_COLOR_INDEX_INT_T color_index;

    if (stream_read_uint32(s, &nbVoxels) == false) {
        cclog_error("could not read nbVoxels");
        shape_release(*out);
        free(colors);
        return invalid_format;
    }

    ColorPalette *palette = shape_get_palette(*out);
    for (uint32_t i = 0; i < nbVoxels; i++) {

        // ⚠️ y -> z, z -> y
        if (stream_read_uint8(s, &x) == false) {
            cclog_error("could not read x");
            err = invalid_format;
            break;
        }

        if (stream_read_uint8(s, &z) == false) {
            cclog_error("could not read z");
            err = invalid_format;
            break;
        }

        if (stream_read_uint8(s, &y) == false) {
            cclog_error("could not read y");
            err = invalid_format;
            break;
        }

        if (stream_read_uint8(s, &color_index) == false) {
            cclog_error("could not read color_index");
            err = invalid_format;
            break;
        }

        // MV block indexes start at 1, while palette indexes start at 0.
        // We have to shift the color index.
        // It's also done when exporting .vox (+1 instead of -1)
        SHAPE_COLOR_INDEX_INT_T colorIdx = color_index - 1;

        // translate & shrink to a shape palette w/ only used colors
        if (color_palette_check_and_add_color(palette, colors[colorIdx], &colorIdx) == false) {
            colorIdx = 0;
        }

        shape_add_block_with_color(*out,
                                   colorIdx,
                                   (SHAPE_COORDS_INT_T)x,
                                   (SHAPE_COORDS_INT_T)y,
                                   (SHAPE_COORDS_INT_T)z,
                                   false,
                                   false,
                                   false,
                                   false);
    }
    color_palette_clear_lighting_dirty(palette);

    if (err != no_error) {
        shape_release(*out);
        free(colors);
        return err;
    }

    return no_error;
}
