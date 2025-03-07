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
#include "serialization_vox.h"
#include "serialization_gltf.h"
#include "stream.h"
#include "transform.h"
#include "camera.h"
#include "light.h"
#include "zlib.h"

// MARK: - Generic load -

#define MAGIC_GLTF 0x46546C67
#define MAGIC_VOX 0x564F5820

DataFormat serialization_load_data(const void *buffer, const size_t size, const ASSET_MASK_T filter,
                                   const ShapeSettings *shapeSettings, void **out) {
    vx_assert_d(*out == NULL);

    Stream *stream = stream_new_buffer_read(buffer, size);

    // external formats
    {
        uint32_t magic;
        if (stream_read_uint32(stream, &magic) == false) {
            cclog_error("failed to read magic byte");
            stream_free(stream);
            return DataFormat_Unsupported;
        }

        if (magic == MAGIC_VOX) {
            const DataFormat format = serialization_vox_load(stream, (Shape **)out, shapeSettings->isMutable, NULL) != no_error ?
                                      DataFormat_VOX : DataFormat_Error;
            stream_free(stream);
            return format;
        } else if (magic == MAGIC_GLTF) {
            const DataFormat format = serialization_gltf_load(buffer, size, filter, (DoublyLinkedList **)out) ?
                                      DataFormat_GLTF : DataFormat_Error;
            stream_free(stream);
            return format;
        }
    }

    // 3ZH and PCUBES
    if (readMagicBytes(stream, true)) {
        if (serialization_load_assets(stream, NULL, filter, NULL, shapeSettings, true, (DoublyLinkedList **)out)) { // frees stream
            return DataFormat_3ZH;
        } else {
            return DataFormat_Error;
        }
    }

    return DataFormat_Unsupported;
}

//MARK: - 3ZH files -

bool _readMagicBytes(Stream *s, uint8_t size, const char *magic) {
    char current = 0;
    for (int i = 0; i < size; i++) {
        if (stream_read(s, &current, sizeof(char), 1) == false) {
            cclog_error("failed to read magic byte");
            return false;
        }
        if (current != magic[i]) {
            cclog_error("incorrect magic bytes");
            return false;
        }
    }
    return true;
}

bool readMagicBytes(Stream *s, bool allowLegacy) {
    if (_readMagicBytes(s, MAGIC_BYTES_SIZE, MAGIC_BYTES)) {
        return true;
    }
    if (allowLegacy) {
        stream_set_cursor_position(s, 0);
        return _readMagicBytes(s, MAGIC_BYTES_SIZE_LEGACY, MAGIC_BYTES_LEGACY);
    }
    return false;
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
                                ShapeSettings *shapeSettings,
                                const bool allowLegacy) {
    DoublyLinkedList *assets = NULL;
    if (serialization_load_assets(s,
                                  fullname,
                                  AssetType_Shape,
                                  colorAtlas,
                                  shapeSettings,
                                  allowLegacy,
                                  &assets)) {
        Shape *shape = assets_get_root_shape(assets, true);

        // do not keep ownership on sub-objects + free unused palette
        doubly_linked_list_flush(assets, serialization_assets_free_func);
        doubly_linked_list_free(assets);

        return shape;
    }

    return NULL;
}

bool serialization_load_assets(Stream *stream,
                               const char *fullname,
                               ASSET_MASK_T filter,
                               ColorAtlas *colorAtlas,
                               const ShapeSettings *const shapeSettings,
                               const bool allowLegacy,
                               DoublyLinkedList **out) {
    vx_assert_d(*out == NULL);

    if (stream == NULL) {
        cclog_error("can't load asset from NULL Stream");
        return false;
    }

    // read magic bytes
    if (readMagicBytes(stream, allowLegacy) == false) {
        goto return_error;
    }

    // read file format
    uint32_t fileFormatVersion = 0;
    if (stream_read_uint32(stream, &fileFormatVersion) == false) {
        cclog_error("failed to read file format version");
        goto return_error;
    }

    switch (fileFormatVersion) {
        case 5: {
            if ((filter & AssetType_Shape) != 0) {
                *out = doubly_linked_list_new();
                Shape *shape = serialization_v5_load_shape(stream, shapeSettings, colorAtlas);
                Asset *asset = malloc(sizeof(Asset));
                if (asset == NULL) {
                    goto return_error;
                }
                asset->ptr = shape;
                asset->type = AssetType_Shape;
                doubly_linked_list_push_last(*out, asset);
            }
            break;
        }
        case 6: {
            *out = serialization_load_assets_v6(stream, colorAtlas, filter, shapeSettings);
            break;
        }
        default: {
            cclog_error("file format version not supported: %d", fileFormatVersion);
            goto return_error;
        }
    }

    if (*out != NULL && doubly_linked_list_node_count(*out) == 0) {
        doubly_linked_list_free(*out);
        *out = NULL;
        cclog_error("[serialization_load_assets] no resources found");
        goto return_error;
    }

    // set fullname if containing a root shape
    Shape *shape = assets_get_root_shape(*out, false);
    if (shape != NULL) {
        shape_set_fullname(shape, fullname);
    }

    goto return_success;

    return_error:
    stream_free(stream);
    return false;

    return_success:
    stream_free(stream);
    return true;
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
        case AssetType_Camera:
            camera_release((Camera *)a->ptr);
            break;
        case AssetType_Light:
            light_release((Light *)a->ptr);
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
    if (readMagicBytes(s, true) == false) {
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
