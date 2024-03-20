// -------------------------------------------------------------
//  Cubzh Core
//  magicavoxel.c
//  Created by Gaetan de Villele on June 06, 2022.
// -------------------------------------------------------------

#include "magicavoxel.h"

#include <string.h>

#include "cclog.h"
#include "colors.h"
#include "config.h"
#include "hash_uint32.h"
#include "serialization.h"
#include "shape.h"
#include "stream.h"

#define VOX_MAGIC_BYTES "VOX "
#define VOX_MAGIC_BYTES_SIZE 4

#define MAIN_CHUNK_HEADER "MAIN"
#define CHUNK_HEADER_SIZE 4
#define CHUNK_HEADER_SIZE_PLUS_ONE 5

#define VOX_MAX_NB_COLORS 256 // there are always 256 colors in a .vox

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

bool _writeVoxChunkHeader(const char *name,
                          const uint32_t contentSize,
                          const uint32_t childrenSize,
                          FILE *const out) {

    if (strlen(name) != CHUNK_HEADER_SIZE) {
        cclog_error("chunk name (%s) should be 4 chars", name);
        return false;
    }

    // chunk name
    if (fwrite(name, sizeof(char), CHUNK_HEADER_SIZE, out) != 4) {
        cclog_error("failed to write \'%s\'", name);
        return false;
    }

    // content size
    if (fwrite(&contentSize, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write %s constent size", name);
        return false;
    }

    // children size
    if (fwrite(&childrenSize, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write %s children size", name);
        return false;
    }

    return true;
}

bool _writeDictEntry(const char *key, const char *value, FILE *const out) {

    uint32_t keyLen = (uint32_t)strlen(key);
    uint32_t valueLen = (uint32_t)strlen(value);

    if (fwrite(&keyLen, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write DICT key len");
        return false;
    }

    if (fwrite(key, sizeof(char), keyLen, out) != keyLen) {
        cclog_error("failed to write DICT key");
        return false;
    }

    if (fwrite(&valueLen, sizeof(uint32_t), 1, out) != 1) {
        cclog_error("failed to write DICT value len");
        return false;
    }

    if (fwrite(value, sizeof(char), valueLen, out) != valueLen) {
        cclog_error("failed to write DICT value");
        return false;
    }

    return true;
}

bool serialization_save_vox(Shape *src, FILE *const out) {
    Shape **shapes = (Shape **)malloc(sizeof(Shape *));
    if (shapes == NULL) {
        return false;
    }
    shapes[0] = src;

    bool success = serialization_shapes_to_vox(shapes, 1, out);
    free(shapes);

    return success;
}

bool serialization_shapes_to_vox(Shape **shapes, const size_t nbShapes, FILE *const out) {
    SHAPE_SIZE_INT3_T shape_size;

    if (out == NULL) {
        cclog_error("file pointer is NULL");
        return false;
    }

    // validate arguments
    if (shapes == NULL) {
        cclog_error("shapes pointer is NULL");
        return false;
    }

    if (nbShapes < 1) {
        cclog_error("number of shapes should be at least 1");
        return false;
    }

    for (unsigned int i = 0; i < nbShapes; ++i) {
        if (shapes[i] == NULL) {
            cclog_error("at least of the given shapes is NULL");
            return false;
        }
        shape_size = shape_get_allocated_size(shapes[i]);
        if (shape_size.x > 256 || shape_size.y > 256 || shape_size.z > 256) {
            cclog_error("shape is too big, can't export for magicavoxel");
            return false;
        }
    }

    // combine palettes
    // All Shapes are supposed to share
    // the same ColorAtlas, getting it from first shape:

    ColorAtlas *colorAtlas = color_palette_get_atlas(shape_get_palette(shapes[0]));
    ColorPalette *combinedPalette = color_palette_new(colorAtlas);

    HashUInt32 **paletteConversionMaps = (HashUInt32 **)malloc(sizeof(HashUInt32 *) *
                                                               nbShapes);

    uint32_t colorAsUint32;
    SHAPE_COLOR_INDEX_INT_T *mapValue;
    ColorPalette *palette;
    HashUInt32 *paletteConversionMap;

    for (unsigned int i = 0; i < nbShapes; ++i) {
        paletteConversionMaps[i] = hash_uint32_new(free);
        palette = shape_get_palette(shapes[i]);
        uint8_t count = color_palette_get_count(palette);
        for (SHAPE_COLOR_INDEX_INT_T c = 0; c < count; ++c) {
            if (color_palette_get_color_use_count(palette, c) == 0) {
                continue; // skip unused colors
            }
            RGBAColor *color = color_palette_get_color(palette, c);
            if (color == NULL) {
                continue; // skip NULL colors
            }
            //
            SHAPE_COLOR_INDEX_INT_T index = 0; // color set at index

            // NOTE: Palettes in Cubzh can contain up to 128 colors
            // while .vox palette (shared by all models) contains up to 255 colors
            // Currently, some colors are lost if the total amount of colors in combined shapes is
            // over 128.
            // TODO: Use 2 palettes to support up to 255 colors? Or a palette with a higher limit.
            // TODO: Find closest color
            color_palette_check_and_add_color(combinedPalette, *color, &index, false);

            colorAsUint32 = color_to_uint32(color);
            mapValue = (SHAPE_COLOR_INDEX_INT_T*)malloc(sizeof(SHAPE_COLOR_INDEX_INT_T));
            *mapValue = index;
            hash_uint32_set(paletteConversionMaps[i], colorAsUint32, mapValue);
        }
    }

#define _shapes_to_vox_error(msg)                                                                  \
    cclog_error(msg);                                                                              \
    color_palette_free(combinedPalette);                                                           \
    for (unsigned int i = 0; i < nbShapes; ++i) {                                                  \
        hash_uint32_free(paletteConversionMaps[i]);                                            \
    }                                                                                              \
    free(paletteConversionMaps);                                                                   \
    return false;

    // write 'VOX '
    if (fwrite("VOX ", sizeof(char), 4, out) != 4) {
        _shapes_to_vox_error("failed to write \'VOX \'")
    }

    // version number
    uint32_t format = 150;
    if (fwrite(&format, sizeof(uint32_t), 1, out) != 1) {
        _shapes_to_vox_error("failed to write file format");
    }

    // MAIN chunk
    if (fwrite("MAIN", sizeof(char), 4, out) != 4) {
        _shapes_to_vox_error("failed to write \'MAIN\'");
    }

    // size of MAIN chunk content: 0 (actual content is in children)
    uint32_t zero = 0;
    if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
        _shapes_to_vox_error("failed to write MAIN size");
    }

    // remembering position to set value when done writing children
    long mainChunkChildrenSize = ftell(out);
    if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
        _shapes_to_vox_error("failed to write MAIN children size");
    }

    uint32_t _nbShapes = (uint32_t)nbShapes;
    uint32_t size_bytes = 12;
    uint32_t rgba_bytes = 256 * 4;

    // uint32_t total_xyzi_bytes = 0; // warning : this variable is never read
    // for (int i = 0; i < nbShapes; ++i) {
    // size_t nb_blocks = shape_get_nb_blocks(shapes[i]); // warning : this variable is never read
    // total_xyzi_bytes += 4 + 4 * (uint32_t)(nb_blocks);
    // }

    uint32_t nTRN_bytes = 28; // transform chunk, for one frame
    uint32_t nGRP_bytes = 12 + 4 * _nbShapes;
    uint32_t nSHP_bytes = 12 + 8 * 1; // one model per nSHP

    // SIZE & XYZI chunk couples for each shape
    for (unsigned int i = 0; i < nbShapes; ++i) {

        const Shape *src = shapes[i];
        palette = shape_get_palette(src);
        paletteConversionMap = paletteConversionMaps[i];

        shape_size = shape_get_allocated_size(src);

        _writeVoxChunkHeader("SIZE", size_bytes, 0, out);

        // x
        uint32_t x = (uint32_t)shape_size.x;
        if (fwrite(&x, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write SIZE x")
        }

        // y
        uint32_t y = (uint32_t)shape_size.z;
        if (fwrite(&y, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write SIZE y")
        }

        // z
        uint32_t z = (uint32_t)shape_size.y;
        if (fwrite(&z, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write SIZE x")
        }

        size_t nb_blocks = shape_get_nb_blocks(src);
        uint32_t xyzi_bytes = 4 + 4 * (uint32_t)(nb_blocks);

        _writeVoxChunkHeader("XYZI", xyzi_bytes, 0, out);

        // XYZI: nb voxels
        uint32_t n = (uint32_t)nb_blocks;
        if (fwrite(&n, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write XYZI nb voxels")
        }

        // loop over blocks

        Chunk *chunk = NULL;
        SHAPE_COORDS_INT3_T coords_in_shape;
        CHUNK_COORDS_INT3_T coords_in_chunk;
        Block *b = NULL;
        int colorIndexInCombinedPalette;
        void *mapValue;
        RGBAColor *color;

        for (int k = 0; k < shape_size.z; k++) {
            for (int j = 0; j < shape_size.y; j++) {
                for (int i = 0; i < shape_size.x; i++) {
                    b = NULL;

                    coords_in_shape = (SHAPE_COORDS_INT3_T){(SHAPE_COORDS_INT_T)i,
                                                            (SHAPE_COORDS_INT_T)j,
                                                            (SHAPE_COORDS_INT_T)k};
                    shape_get_chunk_and_coordinates(src,
                                                    coords_in_shape,
                                                    &chunk,
                                                    NULL,
                                                    &coords_in_chunk);
                    if (chunk != NULL) {
                        b = chunk_get_block_2(chunk, coords_in_chunk);
                    }

                    if (block_is_solid(b)) {
                        SHAPE_COLOR_INDEX_INT_T bci = block_get_color_index(b);
                        color = color_palette_get_color(palette, bci);
                        if (hash_uint32_get(paletteConversionMap,
                                            color_to_uint32(color),
                                            &mapValue)) {
                            colorIndexInCombinedPalette = *((SHAPE_COLOR_INDEX_INT_T*)mapValue);
                        } else {
                            colorIndexInCombinedPalette = 0;
                        }

                        // ⚠️ y -> z, z -> y
                        uint8_t x = (uint8_t)coords_in_shape.x;
                        uint8_t y = (uint8_t)coords_in_shape.z;
                        uint8_t z = (uint8_t)coords_in_shape.y;
                        uint8_t c = (uint8_t)colorIndexInCombinedPalette + 1;

                        // printf("block : %d, %d, %d - color: %d\n", x, y, z, c);

                        if (fwrite(&x, sizeof(uint8_t), 1, out) != 1) {
                            _shapes_to_vox_error("failed to write x size")
                        }

                        if (fwrite(&y, sizeof(uint8_t), 1, out) != 1) {
                            _shapes_to_vox_error("failed to write y size")
                        }

                        if (fwrite(&z, sizeof(uint8_t), 1, out) != 1) {
                            _shapes_to_vox_error("failed to write z size")
                        }

                        if (fwrite(&c, sizeof(uint8_t), 1, out) != 1) {
                            _shapes_to_vox_error("failed to write c size")
                        }
                    }
                }
            }
        }
    }

    // Transforms / Groups / Shapes

    /*
        T
        |
        G
       / \
      T   T
      |   |
      S   S
    */

    uint32_t topLevelTransformNodeID = 0;
    uint32_t topLevelGroupNodeID = 1;
    // T node ID for shape: shapeNumber + 1 (shapeNumber starting at 1)
    // S node ID for shape: nbShapes + shapeNumber + 1 (shapeNumber starting at 1)

    uint32_t one = 1;
    uint32_t minusOne = (uint32_t)-1;

    // top level transform
    {
        _writeVoxChunkHeader("nTRN", nTRN_bytes, 0, out);

        if (fwrite(&topLevelTransformNodeID, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nTRN node id")
        }

        if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nTRN DICT")
        }

        if (fwrite(&topLevelGroupNodeID, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nTRN child node id")
        }

        if (fwrite(&minusOne, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nTRN reserved id")
        }

        if (fwrite(&minusOne, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nTRN layer id")
        }

        if (fwrite(&one, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nTRN number of frames")
        }

        if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nTRN frame DICT")
        }
    }

    // top level group
    {
        _writeVoxChunkHeader("nGRP", nGRP_bytes, 0, out);

        if (fwrite(&topLevelGroupNodeID, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nGRP node id")
        }

        if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nGRP frame DICT")
        }

        if (fwrite(&_nbShapes, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write nGRP number of children")
        }

        // child ids
        uint32_t child_node_id = 1;
        for (unsigned int i = 0; i < nbShapes; ++i) {
            ++child_node_id;
            if (fwrite(&child_node_id, sizeof(uint32_t), 1, out) != 1) {
                _shapes_to_vox_error("failed to write nGRP child id")
            }
        }
    }

    // one transform per model
    {
        uint32_t node_id = 1;
        int xOffset = 0;

        for (unsigned int i = 0; i < nbShapes; ++i) {
            ++node_id;

            int3 size = {0, 0, 0};
            shape_get_bounding_box_size(shapes[i], &size);
            char *translationStr = (char *)malloc(255 * sizeof(char));
            if (translationStr == NULL) {
                _shapes_to_vox_error("failed to allocate translationStr");
            }
            int written = snprintf(translationStr,
                                   255,
                                   "%d %d %d",
                                   -(size.x / 2 + size.x % 2 + xOffset),
                                   size.z / 2,
                                   size.y / 2);

            xOffset += size.x + 2;

            if ((written >= 0 && written < 255) == false) {
                free(translationStr);
                _shapes_to_vox_error("failed to stringify model translation")
            }

            uint32_t contentSize = nTRN_bytes;
            // consider size occupied by translation
            uint32_t _tSize = sizeof(uint32_t) + 2 + sizeof(uint32_t) +
                              (uint32_t)strlen(translationStr);
            contentSize += _tSize;

            _writeVoxChunkHeader("nTRN", contentSize, 0, out);

            if (fwrite(&node_id, sizeof(uint32_t), 1, out) != 1) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN node id")
            }

            if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN DICT")
            }

            uint32_t child_node_id = node_id + _nbShapes;

            // child node id
            if (fwrite(&child_node_id, sizeof(uint32_t), 1, out) != 1) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN child node id")
            }

            // reserved id (always -1?)
            if (fwrite(&minusOne, sizeof(uint32_t), 1, out) != 1) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN reserved id")
            }

            // layer
            if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN layer id")
            }

            // number of frames
            if (fwrite(&one, sizeof(uint32_t), 1, out) != 1) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN number of frames")
            }

            // DICT for each frame
            if (fwrite(&one, sizeof(uint32_t), 1, out) != 1) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN frame DICT")
            }

            if (_writeDictEntry("_t", translationStr, out) == false) {
                free(translationStr);
                _shapes_to_vox_error("failed to write nTRN DICT entry")
            }
            free(translationStr);
        }
    }

    // models
    {
        uint32_t node_id = 1 + _nbShapes;
        uint32_t model_id = 0;

        for (unsigned int i = 0; i < nbShapes; ++i) {
            ++node_id;

            _writeVoxChunkHeader("nSHP", nSHP_bytes, 0, out);

            if (fwrite(&node_id, sizeof(uint32_t), 1, out) != 1) {
                _shapes_to_vox_error("failed to write nSHP node id")
            }

            if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
                _shapes_to_vox_error("failed to write nSHP DICT")
            }

            if (fwrite(&one, sizeof(uint32_t), 1, out) != 1) {
                _shapes_to_vox_error("failed to write nSHP number of models")
            }

            if (fwrite(&model_id, sizeof(uint32_t), 1, out) != 1) {
                _shapes_to_vox_error("failed to write nSHP model id")
            }

            if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
                _shapes_to_vox_error("failed to write nSHP model DICT")
            }

            ++model_id;
        }
    }

    // RGBA chunk
    {
        if (fwrite("RGBA", sizeof(char), 4, out) != 4) {
            _shapes_to_vox_error("failed to write \'RGBA\'")
        }

        // size of RGBA chunk
        if (fwrite(&rgba_bytes, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write RGBA size")
        }

        // size of RGBA children
        if (fwrite(&zero, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("failed to write RGBA children size")
        }

        uint8_t zero = 0;

        // const ColorPalette *palette = shape_get_palette(shapes[0]);
        const ColorPalette *palette = combinedPalette;
        uint16_t nbColors = palette->count;

        RGBAColor *color = NULL;

        for (int i = 0; i < 256; i++) {
            if (i < nbColors) {
                color = color_palette_get_color(palette, (SHAPE_COLOR_INDEX_INT_T)i);
                // r
                if (fwrite(&color->r, sizeof(uint8_t), 1, out) != 1) {
                    _shapes_to_vox_error("failed to write r")
                }
                // g
                if (fwrite(&color->g, sizeof(uint8_t), 1, out) != 1) {
                    _shapes_to_vox_error("failed to write g")
                }
                // b
                if (fwrite(&color->b, sizeof(uint8_t), 1, out) != 1) {
                    _shapes_to_vox_error("failed to write b")
                }
                // a
                if (fwrite(&color->a, sizeof(uint8_t), 1, out) != 1) {
                    _shapes_to_vox_error("failed to write a")
                }
            } else {
                for (int j = 0; j < 4; j++) {
                    if (fwrite(&zero, sizeof(uint8_t), 1, out) != 1) {
                        _shapes_to_vox_error("failed to write empty color")
                    }
                }
            }
        }
    }

    // Write MAIN children size
    {
        uint32_t mainChildrenSize = (uint32_t)(ftell(out) - mainChunkChildrenSize -
                                               (long)sizeof(uint32_t));
        long currentPosition = ftell(out);
        fseek(out, mainChunkChildrenSize, SEEK_SET);
        if (fwrite(&mainChildrenSize, sizeof(uint32_t), 1, out) != 1) {
            _shapes_to_vox_error("could not write MAIN chunk children size")
        }
        fseek(out, currentPosition, SEEK_SET); // back to current position
    }

    color_palette_free(combinedPalette);
    for (unsigned int i = 0; i < nbShapes; ++i) {
        hash_uint32_free(paletteConversionMaps[i]);
    }
    free(paletteConversionMaps);

    return true;
}

enum serialization_magicavoxel_error serialization_vox_to_shape(Stream *s,
                                                                Shape **out,
                                                                const bool isMutable,
                                                                ColorAtlas *colorAtlas) {

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
    RGBAColor *colors = malloc(sizeof(RGBAColor) * VOX_MAX_NB_COLORS);
    if (colors == NULL) {
        return unknown_chunk;
    }
    for (int i = 0; i < VOX_MAX_NB_COLORS; ++i) {
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

            if (current_chunk_content_bytes > 256 * 4 || current_chunk_content_bytes % 4 != 0) {
                cclog_error("invalid RGBA chunk format");
                err = invalid_format;
                break;
            }

            int nbColors = minimum(current_chunk_content_bytes / 4, VOX_MAX_NB_COLORS);

            for (int i = 0; i < nbColors; i++) {

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
    *out = shape_make_2(isMutable);
    shape_set_palette(*out, color_palette_new(colorAtlas));

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
        if (color_palette_check_and_add_color(palette, colors[colorIdx], &colorIdx, false) ==
            false) {
            colorIdx = 0;
        }

        shape_add_block(*out,
                        colorIdx,
                        (SHAPE_COORDS_INT_T)x,
                        (SHAPE_COORDS_INT_T)y,
                        (SHAPE_COORDS_INT_T)z,
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
