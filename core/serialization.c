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
#include "transform.h"
#include "stream.h"

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

Shape *resources_get_root_shape(DoublyLinkedList *list) {
    Shape *shape = NULL;
    DoublyLinkedListNode *node = doubly_linked_list_first(list);
    while (node != NULL) {
        Resource *r = (Resource *) doubly_linked_list_node_pointer(node);
        if (r->type == TypeShape) {
            Shape *s = (Shape *) r->ptr;
            if (transform_get_parent(shape_get_root_transform(s)) == NULL) {
                shape = s;
                break;
            }
        }
        node = doubly_linked_list_node_next(node);
        if (node == doubly_linked_list_first(list)) {
            node = NULL;
        }
    }
    return shape;
}

/// This does free the Stream
Shape *serialization_load_shape(Stream *s,
                                const char *fullname,
                                ColorAtlas* colorAtlas,
                                LoadShapeSettings *shapeSettings,
                                const bool allowLegacy) {
    DoublyLinkedList *shapes = serialization_load_resources(s, fullname, TypeShape, colorAtlas, shapeSettings);
    // s is NULL if it could not be loaded
    if (shapes == NULL) {
        return NULL;
    }
    Shape *shape = resources_get_root_shape(shapes);
    doubly_linked_list_free(shapes);
    return shape;
}

DoublyLinkedList *serialization_load_resources(Stream *s,
                                               const char *fullname,
                                               enum ResourceType filterMask,
                                               ColorAtlas* colorAtlas,
                                               LoadShapeSettings *shapeSettings) {
    if (s == NULL) {
        cclog_error("can't load asset from NULL Stream");
        return NULL; // error
    }

    // read magic bytes
    if (readMagicBytes(s) != 0) {
        cclog_error("failed to read magic bytes");
        stream_free(s);
        return NULL;
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
            Resource *resource = malloc(sizeof(Resource));
            resource->ptr = shape;
            resource->type = TypeShape;
            DoublyLinkedListNode *node = doubly_linked_list_node_new(resource);
            doubly_linked_list_push_last(list, node);
            break;
        }
        case 6: {
            list = serialization_load_resources_v6(s, colorAtlas, filterMask, shapeSettings);
            break;
        }
        default: {
            cclog_error("file format version not supported: %d", fileFormatVersion);
            break;
        }
    }

    stream_free(s);

    // shrink box once all blocks were added to update box origin
    if (doubly_linked_list_node_count(list) == 0) {
        doubly_linked_list_free(list);
        list = NULL;
        cclog_error("[serialization_load_resources] no resources found");
    }
    
    // set fullname if containing a root shape
    Shape *shape = resources_get_root_shape(list);
    if (shape != NULL) {
        shape_set_fullname(shape, fullname);
    } else {
        cclog_error("[serialization_load_shape] shape is NULL");
    }

    return list;
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
// Memory buffer writing
// --------------------------------------------------

void serialization_utils_writeCString(void *dest,
                                      const char *src,
                                      const size_t n,
                                      uint32_t *cursor) {
    RETURN_IF_NULL(dest);
    RETURN_IF_NULL(src);
    memcpy(dest, src, n);
    if (cursor != NULL) {
        *cursor += n;
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
