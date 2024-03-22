// -------------------------------------------------------------
//  Cubzh Core
//  serialization.c
//  Created by Gaetan de Villele on September 10, 2017.
// -------------------------------------------------------------

#include "serialization.h"

#include <stdlib.h>
#include <string.h>

#include "cclog.h"
#include "serialization_v5.h"
#include "serialization_v6.h"
#include "stream.h"
#include "transform.h"
#include "zlib.h"

// Returns 0 on success, 1 otherwise.
// This function doesn't close the file descriptor, you probably want to close
// it in the calling context, when an error occurs.
uint8_t readMagicBytes(Stream *s) {
    char current = 0;
    for (int i = 0; i < MAGIC_BYTES_SIZE; i++) {
        if (stream_read(s, &current, sizeof(char), 1) == false) {
            cclog_error("failed to read magic byte");
            return 1; // error
        }
        if (current != MAGIC_BYTES[i]) {
            cclog_error("incorrect magic bytes");
            return 1; // error
        }
    }
    return 0; // ok
}

uint8_t readMagicBytesLegacy(Stream *s) {
    char current = 0;
    for (int i = 0; i < MAGIC_BYTES_SIZE_LEGACY; i++) {
        if (stream_read(s, &current, sizeof(char), 1) == false) {
            cclog_error("failed to read magic byte");
            return 1; // error
        }
        if (current != MAGIC_BYTES_LEGACY[i]) {
            cclog_error("incorrect magic bytes");
            return 1; // error
        }
    }
    return 0; // ok
}

Shape *assets_get_root_shape(DoublyLinkedList *list, bool remove) {
    DoublyLinkedListNode *n = doubly_linked_list_first(list);
    while (n != NULL) {
        Asset *r = (Asset *)doubly_linked_list_node_pointer(n);
        if (r->type == AssetType_Shape) {
            Shape *s = (Shape *)r->ptr;
            if (transform_get_parent(shape_get_root_transform(s)) == NULL) {
                if (remove) {
                    free(r);
                    doubly_linked_list_delete_node(list, n);
                }
                return s;
            }
        }
        n = doubly_linked_list_node_next(n);
    }
    return NULL;
}

/// This does free the Stream
Shape *serialization_load_shape(Stream *s,
                                const char *fullname,
                                ColorAtlas *colorAtlas,
                                LoadShapeSettings *shapeSettings,
                                const bool allowLegacy) {
    DoublyLinkedList *assets = serialization_load_assets(s,
                                                         fullname,
                                                         AssetType_Shape,
                                                         colorAtlas,
                                                         shapeSettings,
                                                         allowLegacy);
    // s is NULL if it could not be loaded
    if (assets == NULL) {
        return NULL;
    }
    Shape *shape = assets_get_root_shape(assets, true);

    // do not keep ownership on sub-objects + free unused palette
    doubly_linked_list_flush(assets, serialization_assets_free_func);
    doubly_linked_list_free(assets);

    return shape;
}

DoublyLinkedList *serialization_load_assets(Stream *s,
                                            const char *fullname,
                                            AssetType filterMask,
                                            ColorAtlas *colorAtlas,
                                            const LoadShapeSettings *const shapeSettings,
                                            const bool allowLegacy) {
    if (s == NULL) {
        cclog_error("can't load asset from NULL Stream");
        return NULL; // error
    }

    // read magic bytes
    if (readMagicBytes(s) != 0) {
        if (allowLegacy) {
            stream_set_cursor_position(s, 0);
            if (readMagicBytesLegacy(s) != 0) {
                stream_free(s);
                return NULL;
            }
        } else {
            stream_free(s);
            return NULL;
        }
    }

    // read file format
    uint32_t fileFormatVersion = 0;
    if (stream_read_uint32(s, &fileFormatVersion) == false) {
        cclog_error("failed to read file format version");
        stream_free(s);
        return NULL;
    }

    DoublyLinkedList *list = NULL;

    switch (fileFormatVersion) {
        case 5: {
            list = doubly_linked_list_new();
            Shape *shape = serialization_v5_load_shape(s, shapeSettings, colorAtlas);
            Asset *asset = malloc(sizeof(Asset));
            if (asset == NULL) {
                stream_free(s);
                return NULL;
            }
            asset->ptr = shape;
            asset->type = AssetType_Shape;
            doubly_linked_list_push_last(list, asset);
            break;
        }
        case 6: {
            list = serialization_load_assets_v6(s, colorAtlas, filterMask, shapeSettings);
            break;
        }
        default: {
            cclog_error("file format version not supported: %d", fileFormatVersion);
            break;
        }
    }

    stream_free(s);
    s = NULL;

    if (list != NULL && doubly_linked_list_node_count(list) == 0) {
        doubly_linked_list_free(list);
        list = NULL;
        cclog_error("[serialization_load_assets] no resources found");
    }

    // set fullname if containing a root shape
    Shape *shape = assets_get_root_shape(list, false);
    if (shape != NULL) {
        shape_set_fullname(shape, fullname);
    }

    return list;
}

void serialization_assets_free_func(void *ptr) {
    Asset *a = (Asset *)ptr;
    switch (a->type) {
        case AssetType_Shape:
            shape_release((Shape *)a->ptr);
            break;
        case AssetType_Object:
            transform_release((Transform *)a->ptr);
            break;
        case AssetType_Palette:
            color_palette_release((ColorPalette *)a->ptr);
            break;
        default:
            break;
    }
    free(a);
}

bool serialization_save_shape(Shape *shape,
                              const void *imageData,
                              const uint32_t imageDataSize,
                              FILE *fd) {

    if (shape == NULL) {
        cclog_error("shape pointer is NULL");
        fclose(fd);
        return false;
    }

    if (fd == NULL) {
        cclog_error("file descriptor is NULL");
        fclose(fd);
        return false;
    }

    if (fwrite(MAGIC_BYTES, sizeof(char), MAGIC_BYTES_SIZE, fd) != MAGIC_BYTES_SIZE) {
        cclog_error("failed to write magic bytes");
        fclose(fd);
        return false;
    }

    const bool success = serialization_v6_save_shape(shape, imageData, imageDataSize, fd);

    fclose(fd);
    return success;
}

/// serialize a shape in a newly created memory buffer
/// Arguments:
/// - shape (mandatory)
/// - palette (optional)
/// - imageData (optional)
bool serialization_save_shape_as_buffer(Shape *shape,
                                        ColorPalette *artistPalette,
                                        const void *previewData,
                                        const uint32_t previewDataSize,
                                        void **outBuffer,
                                        uint32_t *outBufferSize) {

    return serialization_v6_save_shape_as_buffer(shape,
                                                 artistPalette,
                                                 previewData,
                                                 previewDataSize,
                                                 outBuffer,
                                                 outBufferSize);
}

// =============================================================================
// Previews
// =============================================================================

void free_preview_data(void **imageData) {
    free(*imageData);
}

///
bool get_preview_data(const char *filepath, void **imageData, uint32_t *size) {
    // open file for reading
    FILE *fd = fopen(filepath, "rb");
    if (fd == NULL) {
        // NOTE: this error may be intended
        // cclog_info("ERROR: get_preview_data: opening file");
        return false;
    }

    Stream *s = stream_new_file_read(fd);

    // read magic bytes
    if (readMagicBytes(s) != 0) {
        cclog_error("failed to read magic bytes (%s)", filepath);
        stream_free(s); // closes underlying file
        return false;
    }

    // read file format
    uint32_t fileFormatVersion = 0;
    if (stream_read_uint32(s, &fileFormatVersion) == false) {
        cclog_error("failed to read file format version (%s)", filepath);
        stream_free(s); // closes underlying file
        return false;
    }

    bool success = false;

    switch (fileFormatVersion) {
        case 5:
            success = serialization_v5_get_preview_data(s, imageData, size);
            break;
        case 6:
            // cclog_info("get preview data v6 for file : %s", filepath);
            success = serialization_v6_get_preview_data(s, imageData, size);
            break;
        default:
            cclog_error("file format version not supported (%s)", filepath);
            break;
    }

    stream_free(s); // closes underlying file
    return success;
}

// --------------------------------------------------
// MARK: - Memory buffer writing -
// --------------------------------------------------

void serialization_utils_writeCString(void *dest,
                                      const char *src,
                                      const size_t n,
                                      uint32_t *cursor) {
    RETURN_IF_NULL(dest);
    RETURN_IF_NULL(src);
    memcpy(dest, src, n);
    if (cursor != NULL) {
        *cursor += (uint32_t)n;
    }
    return;
}

void serialization_utils_writeUint8(void *dest, const uint8_t src, uint32_t *cursor) {
    RETURN_IF_NULL(dest);
    memcpy(dest, (const void *)(&src), sizeof(uint8_t));
    if (cursor != NULL) {
        *cursor += sizeof(uint8_t);
    }
}

void serialization_utils_writeUint16(void *dest, const uint16_t src, uint32_t *cursor) {
    RETURN_IF_NULL(dest);
    memcpy(dest, (const void *)(&src), sizeof(uint16_t));
    if (cursor != NULL) {
        *cursor += sizeof(uint16_t);
    }
}

void serialization_utils_writeUint32(void *dest, const uint32_t src, uint32_t *cursor) {
    RETURN_IF_NULL(dest);
    memcpy(dest, (const void *)(&src), sizeof(uint32_t));
    if (cursor != NULL) {
        *cursor += sizeof(uint32_t);
    }
}

// MARK: - Baked files -

bool serialization_save_baked_file(const Shape *s, uint64_t hash, FILE *fd) {
    if (shape_uses_baked_lighting(s) == false) {
        return false;
    }

    // write baked file version
    uint32_t version = 2;
    if (fwrite(&version, sizeof(uint32_t), 1, fd) != 1) {
        cclog_error("baked file: failed to write version");
        return false;
    }

    // write shape hash
    if (fwrite(&hash, sizeof(uint64_t), 1, fd) != 1) {
        cclog_error("baked file: failed to write palette hash");
        return false;
    }

    // write number of chunks
    const uint32_t nbChunks = (uint32_t)shape_get_nb_chunks(s);
    if (fwrite(&nbChunks, sizeof(uint32_t), 1, fd) != 1) {
        cclog_error("baked file: failed to write number of chunks");
        return false;
    }

    // write chunks
    Chunk *chunk;
    Index3DIterator *it = index3d_iterator_new(shape_get_chunks(s));
    while (index3d_iterator_pointer(it) != NULL) {
        chunk = index3d_iterator_pointer(it);

        // write chunk coordinates
        const SHAPE_COORDS_INT3_T origin = chunk_get_origin(chunk);
        const SHAPE_COORDS_INT3_T coords = chunk_utils_get_coords(origin);
        if (fwrite(&coords, sizeof(SHAPE_COORDS_INT3_T), 1, fd) != 1) {
            cclog_error("baked file: failed to write chunk coordinates");
            return false;
        }

        // compress lighting data
        const size_t size = (size_t)CHUNK_SIZE_CUBE * (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
        uLong compressedSize = compressBound(size);
        const void *uncompressedData = chunk_get_lighting_data(chunk);
        void *compressedData = malloc(compressedSize);
        if (compress(compressedData, &compressedSize, uncompressedData, size) != Z_OK) {
            cclog_error("baked file: failed to compress lighting data");
            free(compressedData);
            return false;
        }

        // write lighting data compressed size
        if (fwrite(&compressedSize, sizeof(uint32_t), 1, fd) != 1) {
            cclog_error("baked file: failed to write lighting data compressed size");
            free(compressedData);
            return false;
        }

        // write compressed lighting data
        if (fwrite(compressedData, compressedSize, 1, fd) != 1) {
            cclog_error("baked file: failed to write compressed lighting data");
            free(compressedData);
            return false;
        }

        free(compressedData);

        index3d_iterator_next(it);
    }
    index3d_iterator_free(it);

    return true;
}

bool serialization_load_baked_file(Shape *s, uint64_t expectedHash, FILE *fd) {
    // read baked file version
    uint32_t version;
    if (fread(&version, sizeof(uint32_t), 1, fd) != 1) {
        cclog_error("baked file: failed to read version");
        return false;
    }

    switch (version) {
        case 1: {
            return false; // remove old files
        }
        case 2: {
            // read shape hash
            uint64_t hash;
            if (fread(&hash, sizeof(uint64_t), 1, fd) != 1) {
                cclog_error("baked file (v2): failed to read palette hash");
                return false;
            }

            // match with shape's current hash
            if (hash != expectedHash) {
                cclog_info("baked file (v2): mismatched palette hash, skip");
                return false;
            }

            // read number of chunks
            uint32_t nbChunks;
            if (fread(&nbChunks, sizeof(uint32_t), 1, fd) != 1) {
                cclog_error("baked file (v2): failed to read number of chunks");
                return false;
            }

            // match with shape's current chunks
            if (nbChunks != shape_get_nb_chunks(s)) {
                cclog_info("baked file (v2): mismatched number of chunks, skip");
                return false;
            }

            // read chunks
            Chunk *chunk;
            Index3D *chunks = shape_get_chunks(s);
            const size_t size = (size_t)CHUNK_SIZE_CUBE * (size_t)sizeof(VERTEX_LIGHT_STRUCT_T);
            for (uint32_t i = 0; i < nbChunks; ++i) {
                // read chunk coordinates
                SHAPE_COORDS_INT3_T coords;
                if (fread(&coords, sizeof(SHAPE_COORDS_INT3_T), 1, fd) != 1) {
                    cclog_error("baked file (v2): failed to read chunk coordinates");
                    return false;
                }

                // read lighting data compressed size
                uint32_t compressedSize;
                if (fread(&compressedSize, sizeof(uint32_t), 1, fd) != 1) {
                    cclog_error("baked file (v2): failed to read lighting data compressed size");
                    return false;
                }

                chunk = (Chunk *)index3d_get(chunks, coords.x, coords.y, coords.z);
                if (chunk == NULL) {
                    fseek(fd, compressedSize, SEEK_CUR);
                    continue;
                }

                // read compressed lighting data
                void *compressedData = malloc(compressedSize);
                if (fread(compressedData, compressedSize, 1, fd) != 1) {
                    cclog_error("baked file (v2): failed to read compressed lighting data");
                    free(compressedData);
                    return false;
                }

                // uncompress lighting data
                uLong resultSize = size;
                void *uncompressedData = malloc(size);
                if (uncompressedData == NULL) {
                    cclog_error(
                        "baked file (v2): failed to uncompress lighting data (memory alloc)");
                    free(compressedData);
                    return false;
                }

                if (uncompress(uncompressedData, &resultSize, compressedData, compressedSize) !=
                    Z_OK) {
                    cclog_error("baked file (v2): failed to uncompress lighting data");
                    free(uncompressedData);
                    free(compressedData);
                    return false;
                }
                free(compressedData);
                compressedData = NULL;

                // sanity check
                if (resultSize != size) {
                    cclog_info("baked file (v2): mismatched lighting data uncompressed size, skip");
                    free(uncompressedData);
                    return false;
                }

                chunk_set_lighting_data(chunk, (VERTEX_LIGHT_STRUCT_T *)uncompressedData);
            }

            return true;
        }
        default: {
            cclog_error("baked file: unsupported version");
            return false;
        }
    }
}
