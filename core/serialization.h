// -------------------------------------------------------------
//  Cubzh Core
//  serialization.h
//  Created by Gaetan de Villele on September 10, 2017.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// C
#include <stdbool.h>
#include <stdio.h>

// Cubzh Core
#include "asset.h"
#include "colors.h"
#include "shape.h"
#include "stream.h"

#define MAGIC_BYTES "CUBZH!"
#define MAGIC_BYTES_SIZE 6

// Cubzh used to be called "Particubes", and these used to be the magic bytes.
// We need to keep this temporarily, to read legacy files.
// The app then always saves with the most recent format, thus new magic bytes.
#define MAGIC_BYTES_LEGACY "PARTICUBES!"
#define MAGIC_BYTES_SIZE_LEGACY 11

#define SERIALIZATION_FILE_FORMAT_VERSION_SIZE sizeof(uint32_t)
#define SERIALIZATION_PREVIEW_BYTE_COUNT_SIZE sizeof(uint32_t)

// =============================================================================
// Cubzh file format (.3zh)
// =============================================================================
//
// 11 bytes |  char[6] | cubzh magic bytes
//  4 bytes |   uint32 | file format version
//
//  4 bytes |   uint32 | preview byte count
//  n bytes |  char[n] | preview png bytes
//
//  1 byte  |    uint8 | color encoding format ID
//  1 byte  |    uint8 | color palette row count // TODO: REMOVE
//  1 byte  |    uint8 | color palette column count // TODO: REMOVE
//  1 byte  |    uint8 | color count (max 255)
//  n bytes |  char[n] | colors bytes
//  1 byte  |    uint8 | index of default cube color // TODO: REMOVE
//  1 byte  |    uint8 | index of default background color // TODO: REMOVE
//  1 byte  |    uint8 | index of current cube color // TODO: REMOVE
//  1 byte  |    uint8 | index of current background color // TODO: REMOVE
//
//  2 bytes |   uint16 | world width (X)
//  2 bytes |   uint16 | world height (Y)
//  2 bytes |   uint16 | world depth (Z)
//  n bytes | uint8[n] | cubes (palette indexes)
//
//  4 bytes |  float32 | camera target position (X) // TODO: REMOVE
//  4 bytes |  float32 | camera target position (Y) // TODO: REMOVE
//  4 bytes |  float32 | camera target position (Z) // TODO: REMOVE
//  4 bytes |  float32 | camera distance from target // TODO: REMOVE
//  4 bytes |  float32 | camera rotation (left/right) // TODO: REMOVE
//  4 bytes |  float32 | camera rotation (up/dowm) // TODO: REMOVE
//  4 bytes |  float32 | camera rotation (roll) // TODO: REMOVE
//
// ================= Added in v2 =================
//
//  1 byte  |    uint8 | light enabled (0 or 1)
//  1 byte  |    uint8 | light locked to creation (0 or 1)
//  4 bytes |  float32 | light rotation (X)
//  4 bytes |  float32 | light rotation (Y)
//

//
typedef uint8_t PCColorEncodingFormat;

//
static const PCColorEncodingFormat defaultColorEncoding = 1; // PCColorType1 4 x uint8_t (rgba)
// future color encoding formats
// ...

/// Returns 0 on success, 1 otherwise.
/// This function doesn't close the file descriptor, you probably want to close
/// it in the calling context, when an error occurs.
uint8_t readMagicBytes(Stream *s);
uint8_t readMagicBytesLegacy(Stream *s);

Shape *serialization_load_shape(Stream *s,
                                const char *fullname,
                                ColorAtlas *colorAtlas,
                                LoadShapeSettings *shapeSettings,
                                const bool allowLegacy);

Shape *assets_get_root_shape(DoublyLinkedList *list, bool remove);

/// Load assets (shapes) from Stream and return it as a list
/// - Parameters:
///   - s: the input stream
///   - fullname: the fullname of the item represented by the stream (optional)
///   - filterMask: ...
///   - colorAtlas: ...
///   - shapeSettings: ...
///   - allowLegacy: if true, .pcubes files will be supported as well
DoublyLinkedList *serialization_load_assets(Stream *s,
                                            const char *fullname,
                                            AssetType filterMask,
                                            ColorAtlas *colorAtlas,
                                            const LoadShapeSettings *const settings,
                                            const bool allowLegacy);
void serialization_assets_free_func(void *ptr);

/// serialize a shape w/ its palette
bool serialization_save_shape(Shape *shape,
                              const void *imageData,
                              const uint32_t imageDataSize,
                              FILE *fd); // file opened with "wb" flag (closed within function)

/// serialize a shape in a newly created memory buffer
bool serialization_save_shape_as_buffer(Shape *shape,
                                        ColorPalette *artistPalette,
                                        const void *previewData,
                                        const uint32_t previewDataSize,
                                        void **outBuffer,
                                        uint32_t *outBufferSize);

/// get preview data from save file path (caller must free *imageData)
/// returns true on success, false otherwise
bool get_preview_data(const char *filepath, void **imageData, uint32_t *size);

/// convenience function to release preview data allocated in get_preview_data
void free_preview_data(void **imageData);

/// updates preview data in given file
// returns true on success, false otherwise
bool update_preview_data(const void *imageData, uint32_t imageDataSize, const char *filepath);

/// duplicate world at given source path to destination
// returns true on success, false otherwise
bool duplicate_world(const char *src, const char *dst);

// --------------------------------------------------
// MARK: - Memory buffer writing -
// --------------------------------------------------

/// Arguments
/// - cursor (optional) will be incremented if not NULL
void serialization_utils_writeCString(void *dest,
                                      const char *src,
                                      const size_t n,
                                      uint32_t *cursor);

///
void serialization_utils_writeUint8(void *dest, const uint8_t src, uint32_t *cursor);

///
void serialization_utils_writeUint16(void *dest, const uint16_t src, uint32_t *cursor);

///
void serialization_utils_writeUint32(void *dest, const uint32_t src, uint32_t *cursor);

// MARK: - Baked files -

bool serialization_save_baked_file(const Shape *s, uint64_t hash, FILE *fd);   // does not close fd
bool serialization_load_baked_file(Shape *s, uint64_t expectedHash, FILE *fd); // does not close fd

#ifdef __cplusplus
} // extern "C"
#endif
