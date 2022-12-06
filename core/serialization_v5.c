// -------------------------------------------------------------
//  Cubzh Core
//  serialization_v5.c
//  Created by Adrien Duermael on July 25, 2019.
// -------------------------------------------------------------

#include "serialization_v5.h"

#include <stdlib.h>
#include <string.h>

#include "cclog.h"
#include "map_string_float3.h"
#include "serialization.h"
#include "stream.h"
#include "transform.h"

#define P3S_COMPRESSION_ALGO_NONE 0
//#define P3S_COMPRESSION_ALGO_ZIP 1

#define P3S_CHUNK_ID_NONE 0 // not used as a chunk ID
#define P3S_CHUNK_ID_PREVIEW 1
#define P3S_CHUNK_ID_PALETTE 2
// #define P3S_CHUNK_ID_SELECTED_COLOR 3
// #define P3S_CHUNK_ID_SELECTED_BACKGROUND_COLOR 4
#define P3S_CHUNK_ID_SHAPE 5
#define P3S_CHUNK_ID_SHAPE_SIZE 6 // size of the shape (boundaries)
#define P3S_CHUNK_ID_SHAPE_BLOCKS 7
#define P3S_CHUNK_ID_SHAPE_POINT 8
// #define P3S_CHUNK_ID_CAMERA 9
// #define P3S_CHUNK_ID_DIRECTIONAL_LIGHT 10
// #define P3S_CHUNK_ID_SOURCE_METADATA 11
// #define P3S_CHUNK_ID_SHAPE_NAME 12
// #define P3S_CHUNK_ID_GENERAL_RENDERING_OPTIONS 13
#define P3S_CHUNK_ID_SHAPE_BAKED_LIGHTING 14
#define P3S_CHUNK_ID_MAX 15 // not used as a chunk ID, but used to check if chunk ID is known or not

// private functions
// all chunk_v5_read_* functions return number of bytes read.
// If 0 is returned, it means the file is corrupted, it can't be read.

// chunk_v5_read_palette allocates a new PaletteType1 if palette != NULL
uint32_t chunk_v5_read_palette(Stream *s, ColorAtlas *colorAtlas, ColorPalette **palette);
uint32_t chunk_v5_read_selected_color(Stream *s, uint8_t *color);
uint32_t chunk_v5_read_selected_background_color(Stream *s, uint8_t *color);

// chunk_v5_read_shape allocates a new Shape if shape != NULL
uint32_t chunk_v5_read_shape(Stream *s,
                             Shape **shape,
                             const LoadShapeSettings *const shapeSettings,
                             ColorAtlas *colorAtlas,
                             ColorPalette *serializedPalette);

uint32_t chunk_v5_read_shape_size(Stream *s, uint16_t *width, uint16_t *height, uint16_t *depth);
uint32_t chunk_v5_read_shape_baked_light(Stream *s, VERTEX_LIGHT_STRUCT_T **data);
uint32_t chunk_v5_read_general_rendering_options(Stream *s,
                                                 bool *globalIllumination,
                                                 bool *directionalLight,
                                                 bool *ambientOcclusion);
uint32_t chunk_v5_read_preview_image(Stream *s, void **imageData, uint32_t *size);
uint32_t chunk_v5_read_shape_point(Stream *s, MapStringFloat3 *m);

uint8_t chunk_v5_read_identifier(Stream *s) {
    uint8_t i;

    if (stream_read_uint8(s, &i) == false) {
        return P3S_CHUNK_ID_NONE;
    }

    if (i > P3S_CHUNK_ID_NONE && i < P3S_CHUNK_ID_MAX) {
        return i;
    }

    return P3S_CHUNK_ID_NONE;
}

uint32_t chunk_v5_read_size(Stream *s) {
    uint32_t i;
    // a chunk should never have a size of 0, so we can return 0 if the
    // value can't be read.
    if (stream_read_uint32(s, &i) == false) {
        return 0;
    }
    return i;
}

// returns number of skipped bytes
uint32_t chunk_v5_skip(Stream *s) {
    uint32_t chunkSize = chunk_v5_read_size(s);
    uint32_t skippedBytes = 4;

    if (stream_skip(s, chunkSize) == false) {
        return 0;
    }
    skippedBytes += chunkSize;
    return skippedBytes;
}

/// get preview data from save file path (caller must free *imageData)
bool serialization_v5_get_preview_data(Stream *s, void **imageData, uint32_t *size) {

    uint8_t compressionAlgo = P3S_COMPRESSION_ALGO_NONE;
    if (stream_read_uint8(s, &compressionAlgo) == false) {
        cclog_error("failed to read compression algo");
        return false;
    }

    if (compressionAlgo != P3S_COMPRESSION_ALGO_NONE) {
        cclog_error("compression algo not supported");
        return false;
    }

    uint32_t compressedSize = 0;
    uint32_t uncompressedSize = 0;

    if (stream_read_uint32(s, &compressedSize) == false) {
        cclog_error("failed to read compressed size");
        return false;
    }

    if (stream_read_uint32(s, &uncompressedSize) == false) {
        cclog_error("failed to read uncompression size");
        return false;
    }

    if (compressionAlgo == P3S_COMPRESSION_ALGO_NONE && compressedSize != uncompressedSize) {
        cclog_error("compressedSize should be equal to uncompressedSize without compression");
        return false;
    }

    // READ ALL CHUNKS UNTIL PREVIEW IMAGE IS FOUND

    uint32_t totalSizeRead = 0;
    uint32_t sizeRead = 0;

    uint8_t chunkID;

    while (totalSizeRead < compressedSize) {
        chunkID = chunk_v5_read_identifier(s);
        totalSizeRead += 1; // size of chunk id

        switch (chunkID) {
            case P3S_CHUNK_ID_NONE:
                cclog_error("wrong chunk id found");
                return false;
            case P3S_CHUNK_ID_PREVIEW:
                sizeRead = chunk_v5_read_preview_image(s, imageData, size);
                if (sizeRead == 0) {
                    cclog_error("error while reading preview image");
                    return false;
                }
                return true;
            default:
                // chunks we don't need to read
                totalSizeRead += chunk_v5_skip(s);
                break;
        }
    }
    return false;
}

///
Shape *serialization_v5_load_shape(Stream *s,
                                   const LoadShapeSettings *const shapeSettings,
                                   ColorAtlas *colorAtlas) {

    uint8_t compressionAlgo = P3S_COMPRESSION_ALGO_NONE;
    if (stream_read_uint8(s, &compressionAlgo) == false) {
        cclog_error("failed to read compression algo");
        return NULL;
    }

    if (compressionAlgo != P3S_COMPRESSION_ALGO_NONE) {
        cclog_error("compression algo not supported");
        return NULL;
    }

    uint32_t compressedSize = 0;
    uint32_t uncompressedSize = 0;

    if (stream_read_uint32(s, &compressedSize) == false) {
        cclog_error("failed to read compressed size");
        return NULL;
    }

    if (stream_read_uint32(s, &uncompressedSize) == false) {
        cclog_error("failed to read uncompression size");
        return NULL;
    }

    if (compressionAlgo == P3S_COMPRESSION_ALGO_NONE && compressedSize != uncompressedSize) {
        cclog_error("compressedSize should be equal to uncompressedSize without compression");
        return NULL;
    }

    // READ ALL CHUNKS UNTIL DONE

    Shape *shape = NULL;

    ColorPalette *serializedPalette = NULL;

    uint32_t totalSizeRead = 0;
    uint32_t sizeRead = 0;

    uint8_t chunkID;

    bool error = false;

    while (totalSizeRead < compressedSize && error == false) {
        chunkID = chunk_v5_read_identifier(s);
        totalSizeRead += 1; // size of chunk id

        switch (chunkID) {
            case P3S_CHUNK_ID_NONE: {
                cclog_error("wrong chunk id found");
                error = true;
                break;
            }
            case P3S_CHUNK_ID_PALETTE: {

                sizeRead = chunk_v5_read_palette(s, colorAtlas, &serializedPalette);

                if (sizeRead == 0) {
                    cclog_error("error while reading palette");
                    error = true;
                    break;
                }

                totalSizeRead += sizeRead;
                break;
            }
            case P3S_CHUNK_ID_SHAPE: {
                sizeRead = chunk_v5_read_shape(s,
                                               &shape,
                                               shapeSettings,
                                               colorAtlas,
                                               serializedPalette);

                if (sizeRead == 0) {
                    cclog_error("error while reading shape");
                    error = true;
                    break;
                }
                // shrink box once all blocks were added to update box origin
                shape_shrink_box(shape);

                totalSizeRead += sizeRead;

                break;
            }
            default: {
                // chunks we don't need to read
                totalSizeRead += chunk_v5_skip(s);
                break;
            }
        }
    }

    if (error) {
        if (shape != NULL) {
            cclog_error("error reading shape, but shape isn't NULL");
        }
    }

    return shape;
}

// ------------------------------
// CHUNK READERS
// ------------------------------

uint32_t chunk_v5_read_palette(Stream *s, ColorAtlas *colorAtlas, ColorPalette **palette) {

    uint32_t chunkSize = chunk_v5_read_size(s);

    // read color encoding format
    uint8_t colorEncodingFormat = 0;
    if (stream_read_uint8(s, &colorEncodingFormat) == false) {
        cclog_error("failed to read color encoding format.");
        return 0;
    }

    // check color encoding format is supported
    if (colorEncodingFormat != defaultColorEncoding) {
        cclog_error("color encoding format is not supported (%u).", colorEncodingFormat);
        return 0;
    }

    // read color row count
    uint8_t colorPaletteRowCount = 0;
    if (stream_read_uint8(s, &colorPaletteRowCount) == false) {
        cclog_error("failed to read color palette row count.");
        return 0;
    }

    // read color column count
    uint8_t colorPaletteColumnCount = 0;
    if (stream_read_uint8(s, &colorPaletteColumnCount) == false) {
        cclog_error("failed to read color palette column count.");
        return 0;
    }

    // read color count
    uint16_t paletteColorCount = 0;
    if (stream_read_uint16(s, &paletteColorCount) == false) {
        cclog_error("failed to read color count.");
        return 0;
    }

    // check color count
    if (paletteColorCount != (colorPaletteRowCount * colorPaletteColumnCount)) {
        cclog_error("palette color count doesn't match rows * columns.");
        return 0;
    }

    // read color bytes
    RGBAColor *colors = (RGBAColor *)malloc(sizeof(RGBAColor) * paletteColorCount);
    if (stream_read(s, colors, sizeof(RGBAColor), paletteColorCount) == false) {
        cclog_error("failed to read color bytes.");
        free(colors);
        return 0;
    }

    // read default cube color (just for checks)
    uint8_t discarded;
    if (stream_read_uint8(s, &discarded) == false) {
        cclog_error("failed to read default cube color.");
        free(colors);
        return 0;
    }

    // read default background color
    if (stream_read_uint8(s, &discarded) == false) {
        cclog_error("failed to read default background color");
        free(colors);
        return 0;
    }

    *palette = color_palette_new_from_data(colorAtlas,
                                           minimum(paletteColorCount, UINT8_MAX),
                                           colors,
                                           NULL);

    free(colors);

    return 4 + chunkSize;
}

uint32_t chunk_v5_read_selected_color(Stream *s, uint8_t *color) {
    uint32_t chunkSize = chunk_v5_read_size(s);
    if (chunkSize != 1) {
        cclog_error("incorrect selected color chunk");
        return 0;
    }

    if (stream_read_uint8(s, color) == false) {
        cclog_error("selected color can't be read");
        return 0;
    }

    return 4 + chunkSize;
}

uint32_t chunk_v5_read_selected_background_color(Stream *s, uint8_t *color) {
    uint32_t chunkSize = chunk_v5_read_size(s);
    if (chunkSize != 1) {
        cclog_error("incorrect selected background color chunk");
        return 0;
    }

    if (stream_read_uint8(s, color) == false) {
        cclog_error("selected background color can't be read");
        return 0;
    }

    return 4 + chunkSize;
}

uint32_t chunk_read_shape_process_blocks(Stream *s,
                                         Shape *shape,
                                         const uint16_t w,
                                         const uint16_t h,
                                         const uint16_t d,
                                         bool useDefaultPalette) {

    uint32_t chunkSize = chunk_v5_read_size(s);
    uint32_t cubeCount = (uint32_t)w * (uint32_t)h * (uint32_t)d;
    uint32_t expectedSize = cubeCount * sizeof(uint8_t);

    if (chunkSize != expectedSize) {
        cclog_error("wrong size for shape blocks chunk, expected %u, found %u.",
                    expectedSize,
                    chunkSize);
        return 0;
    }

    uint32_t c;
    SHAPE_COLOR_INDEX_INT_T colorIndex;
    uint16_t block_z_pos;
    uint16_t block_y_pos;
    uint16_t block_x_pos;

    for (uint32_t i = 0; i < cubeCount; i++) {
        if (stream_read_uint8(s, &colorIndex) == false) {
            cclog_error("failed to read cube");
            return 0;
        }
        if (colorIndex == SHAPE_COLOR_INDEX_AIR_BLOCK) { // no cube
            continue;
        }
        c = i;
        block_z_pos = c / (w * h);
        c -= (block_z_pos * (w * h));
        block_y_pos = c / w;
        c -= (block_y_pos * w);
        block_x_pos = c;

        shape_add_block_with_color(shape,
                                   colorIndex,
                                   block_x_pos,
                                   block_y_pos,
                                   block_z_pos,
                                   false, // resize if needed
                                   false, // apply offset
                                   false,
                                   useDefaultPalette);
    }
    color_palette_clear_lighting_dirty(shape_get_palette(shape));

    return chunkSize + 4;
}

uint32_t chunk_v5_read_shape(Stream *s,
                             Shape **shape,
                             const LoadShapeSettings *const shapeSettings,
                             ColorAtlas *colorAtlas,
                             ColorPalette *serializedPalette) {

    uint32_t shapeChunkSize = chunk_v5_read_size(s);

    // no need to read if shape return parameter is NULL
    if (shape == NULL || shapeSettings == NULL) {
        stream_skip(s, shapeChunkSize);
        return 4 + shapeChunkSize;
    }

    if (*shape != NULL) {
        shape_release(*shape);
        *shape = NULL;
    }

    // read child chunks
    uint32_t totalSizeRead = 0;
    uint32_t sizeRead = 0, lightingDataSizeRead = 0;

    uint8_t chunkID;

    bool shapeSizeRead = false;
    uint16_t width = 0;
    uint16_t height = 0;
    uint16_t depth = 0;

    long shapeBlocksPosition = 0;

    MapStringFloat3 *pois = map_string_float3_new();
    VERTEX_LIGHT_STRUCT_T *lightingData = NULL;

    // if there is no serialized palette, shape octree was serialized using default palette
    const bool useDefaultPalette = serializedPalette == NULL;

    while (totalSizeRead < shapeChunkSize) {
        chunkID = chunk_v5_read_identifier(s);
        totalSizeRead += 1; // size of chunk id

        switch (chunkID) {
            case P3S_CHUNK_ID_NONE: {
                cclog_error("wrong shape chunk id found");
                if (lightingData != NULL) {
                    free(lightingData);
                }
                map_string_float3_free(pois);
                return 0;
            }
            case P3S_CHUNK_ID_SHAPE_SIZE: {
                sizeRead = chunk_v5_read_shape_size(s, &width, &height, &depth);
                if (sizeRead == 0) {
                    cclog_error("error while reading shape size");
                    if (lightingData != NULL) {
                        free(lightingData);
                    }
                    map_string_float3_free(pois);
                    return 0;
                }

                totalSizeRead += sizeRead;
                shapeSizeRead = true;

                // size is known, now is a good time to create the shape
                if (shapeSettings->octree) {
                    *shape = shape_make_with_octree(width,
                                                    height,
                                                    depth,
                                                    shapeSettings->lighting,
                                                    shapeSettings->isMutable,
                                                    shapeSettings->limitSize == false);
                } else if (shapeSettings->limitSize) {
                    *shape = shape_make_with_fixed_size(width,
                                                        height,
                                                        depth,
                                                        shapeSettings->lighting,
                                                        shapeSettings->isMutable);
                } else {
                    *shape = shape_make();
                }
                if (serializedPalette != NULL) {
                    shape_set_palette(*shape, serializedPalette);
                } else {
                    shape_set_palette(*shape, color_palette_new(colorAtlas));
                }

                // this means blocks have been found before the size.
                // it's now possible to process them!
                if (shapeBlocksPosition != 0) {
                    long currentPosition = stream_get_cursor_position(s);
                    stream_set_cursor_position(s, shapeBlocksPosition);

                    sizeRead = chunk_read_shape_process_blocks(s,
                                                               *shape,
                                                               width,
                                                               height,
                                                               depth,
                                                               useDefaultPalette);
                    if (sizeRead == 0) {
                        cclog_error("error while reading shape blocks");
                        if (lightingData != NULL) {
                            free(lightingData);
                        }
                        map_string_float3_free(pois);
                        return 0;
                    }
                    stream_set_cursor_position(s, currentPosition);
                }
                break;
            }
            case P3S_CHUNK_ID_SHAPE_BLOCKS: {
                // Size is required to read blocks, but maybe the size
                // information is placed after in the file.
                // Storing blocks position to process them later.
                if (shapeSizeRead == false) {
                    shapeBlocksPosition = stream_get_cursor_position(s);
                    break;
                }

                sizeRead = chunk_read_shape_process_blocks(s,
                                                           *shape,
                                                           width,
                                                           height,
                                                           depth,
                                                           useDefaultPalette);
                if (sizeRead == 0) {
                    cclog_error("error while reading shape blocks");
                    if (lightingData != NULL) {
                        free(lightingData);
                    }
                    map_string_float3_free(pois);
                    return 0;
                }

                totalSizeRead += sizeRead;

                break;
            }
            case P3S_CHUNK_ID_SHAPE_POINT: {
                // cclog_trace("    FOUND SHAPE POINT");
                sizeRead = chunk_v5_read_shape_point(s, pois);
                if (sizeRead == 0) {
                    cclog_error("error while reading shape POI");
                    if (lightingData != NULL) {
                        free(lightingData);
                    }
                    map_string_float3_free(pois);
                    return 0;
                }
                totalSizeRead += sizeRead;
                break;
            }
#if GLOBAL_LIGHTING_BAKE_READ_ENABLED
            case P3S_CHUNK_ID_SHAPE_BAKED_LIGHTING: {
                lightingDataSizeRead = chunk_v5_read_shape_baked_light(s, &lightingData);
                if (sizeRead == 0) {
                    cclog_error("error while reading shape baked lighting");
                    if (lightingData != NULL) {
                        free(lightingData);
                    }
                    map_string_float3_free(pois);
                    return 0;
                }
                totalSizeRead += lightingDataSizeRead;
                break;
            }
#endif
            default: {
                // chunks we don't need to read
                totalSizeRead += chunk_v5_skip(s);
                break;
            }
        }
    }

    if (*shape == NULL) {
        cclog_error("error while reading shape : no shape were created");
        if (lightingData != NULL) {
            free(lightingData);
        }
        map_string_float3_free(pois);
        return 0;
    }

    // set shape POIs
    MapStringFloat3Iterator *it = map_string_float3_iterator_new(pois);
    float3 f3;
    while (map_string_float3_iterator_is_done(it) == false) {
        float3 *value = map_string_float3_iterator_current_value(it);
        float3_copy(&f3, value);
        shape_set_point_of_interest(*shape, map_string_float3_iterator_current_key(it), &f3);
        map_string_float3_iterator_next(it);
    }
    map_string_float3_iterator_free(it);
    map_string_float3_free(pois);

    // set shape lighting data
    if (shape_uses_baked_lighting(*shape)) {
        if (lightingData == NULL) {
            cclog_warning("shape uses lighting but no baked lighting found");
        } else if (shapeSettings->octree == false && shapeSettings->limitSize == false) {
            cclog_warning("shape uses lighting but does not have a fixed size");
            free(lightingData);
        } else if ((lightingDataSizeRead - 4) !=
                   width * height * depth * sizeof(VERTEX_LIGHT_STRUCT_T)) {
            cclog_warning("shape uses lighting but does not match lighting data size");
            free(lightingData);
        } else {
            shape_set_lighting_data(*shape, lightingData);
        }
    } else if (lightingData != NULL) {
        cclog_warning("shape baked lighting data discarded");
        free(lightingData);
    }

    return 4 + shapeChunkSize;
}

uint32_t chunk_v5_read_shape_point(Stream *s, MapStringFloat3 *m) {
    uint32_t chunkSize = chunk_v5_read_size(s);

    uint8_t nameLen = 0;
    if (stream_read_uint8(s, &nameLen) == false) {
        cclog_error("failed to read shape POI's name length.");
        return 0;
    }

    char *name = (char *)malloc(nameLen + 1);
    if (stream_read_string(s, nameLen, name) == false) {
        cclog_error("failed to read shape POI's name.");
        free(name);
        return 0;
    }
    name[nameLen] = 0; // termination null char

    float3 *f3 = float3_new(0, 0, 0);

    if (stream_read_float32(s, &(f3->x)) == false) {
        cclog_error("failed to read shape POI.x");
        free(name);
        float3_free(f3);
        return 0;
    }

    if (stream_read_float32(s, &(f3->y)) == false) {
        cclog_error("failed to read shape POI.y");
        free(name);
        float3_free(f3);
        return 0;
    }

    if (stream_read_float32(s, &(f3->z)) == false) {
        cclog_error("failed to read shape POI.z");
        free(name);
        float3_free(f3);
        return 0;
    }

    map_string_float3_set_key_value(m, name, f3);
    free(name);

    return chunkSize + 4;
}

uint32_t chunk_v5_read_shape_size(Stream *s, uint16_t *width, uint16_t *height, uint16_t *depth) {
    uint32_t chunkSize = chunk_v5_read_size(s);
    if (chunkSize != 6) {
        cclog_error("wrong size for shape size chunk, expected 6, found %u.", chunkSize);
        return 0;
    }

    if (width != NULL) {
        if (stream_read_uint16(s, width) == false) {
            cclog_error("failed to read shape width.");
            return 0;
        }
    } else {
        stream_skip(s, 2);
    }

    if (height != NULL) {
        if (stream_read_uint16(s, height) == false) {
            cclog_error("failed to read shape height.");
            return 0;
        }
    } else {
        stream_skip(s, 2);
    }

    if (depth != NULL) {
        if (stream_read_uint16(s, depth) == false) {
            cclog_error("failed to read shape depth.");
            return 0;
        }
    } else {
        stream_skip(s, 2);
    }

    return chunkSize + 4;
}

// data is allocated here based on chunk size, should be freed by caller
uint32_t chunk_v5_read_shape_baked_light(Stream *s, VERTEX_LIGHT_STRUCT_T **data) {
    uint32_t chunkSize = chunk_v5_read_size(s);
    uint32_t dataCount = chunkSize / sizeof(VERTEX_LIGHT_STRUCT_T);
    if (dataCount == 0) {
        cclog_error("baked light data count cannot be 0");
        return 0;
    }

    *data = (VERTEX_LIGHT_STRUCT_T *)malloc(chunkSize);

    uint8_t v1, v2;
    for (int i = 0; i < (int)dataCount; i++) {
        if (stream_read_uint8(s, &v1) == false) {
            cclog_error("failed to read baked light data");
            return 0;
        }
        if (stream_read_uint8(s, &v2) == false) {
            cclog_error("failed to read baked light data");
            return 0;
        }

        (*data)[i].red = v1 / 16;
        (*data)[i].ambient = v1 - (*data)[i].red * 16;
        (*data)[i].blue = v2 / 16;
        (*data)[i].green = v2 - (*data)[i].blue * 16;
    }

    return chunkSize + 4;
}

uint32_t chunk_v5_read_general_rendering_options(Stream *s,
                                                 bool *globalIllumination,
                                                 bool *directionalLight,
                                                 bool *ambientOcclusion) {
    uint32_t chunkSize = chunk_v5_read_size(s);
    if (chunkSize != 3) {
        cclog_error("wrong size for general rendering options chunk, expected 3, found %u.",
                    chunkSize);
        return 0;
    }

    uint8_t b = 0;

    if (globalIllumination != NULL) {
        if (stream_read_uint8(s, &b) == false) {
            cclog_error("failed to read global illumination option.");
            return 0;
        }
        *globalIllumination = b == 1;
    } else {
        stream_skip(s, 1);
    }

    if (directionalLight != NULL) {
        if (stream_read_uint8(s, &b) == false) {
            cclog_error("failed to read directional light option.");
            return 0;
        }
        *directionalLight = b == 1;
    } else {
        stream_skip(s, 1);
    }

    if (ambientOcclusion != NULL) {
        if (stream_read_uint8(s, &b) == false) {
            cclog_error("failed to read ambient occlusion option.");
            return 0;
        }
        *ambientOcclusion = b == 1;
    } else {
        stream_skip(s, 1);
    }

    return chunkSize + 4;
}

//
uint32_t chunk_v5_read_preview_image(Stream *s, void **imageData, uint32_t *size) {
    uint32_t chunkSize = chunk_v5_read_size(s);
    if (chunkSize == 0) {
        cclog_error("can't read preview image chunk size (v5)");
        return 0;
    }

    // read preview data
    void *previewData = malloc(chunkSize);

    if (previewData == NULL) {
        cclog_error("failed to allocate preview data buffer");
        return 0;
    }

    if (stream_read(s, previewData, chunkSize, 1) == false) {
        cclog_error("failed to read preview data");
        free(previewData);
        return 0;
    }

    // success
    *size = chunkSize;
    *imageData = previewData;

    return chunkSize + 4;
}
