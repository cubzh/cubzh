// -------------------------------------------------------------
//  Cubzh Core
//  magicavoxel.c
//  Created by Gaetan de Villele on June 06, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "color_atlas.h"

typedef struct _Shape Shape;
typedef struct _Stream Stream;

///
enum serialization_vox_error {
    no_error = 0,
    cant_open_file = 1,
    invalid_format = 2,
    pack_chunk_found = 3,
    unknown_chunk = 4
};

/// Saves Shape in .vox format (Magicavoxel)
/// Returns true on success
bool serialization_vox_save(Shape *src, FILE *const out);

/// Saves several shapes as one .vox.
/// Automatically combines Shape colors to obtain .vox's palette.
bool serialization_vox_save_shapes(Shape **shapes, const size_t nbShapes, FILE *const out);

/// converts raw data from src to a Shape
/// @param s not freed by this function
enum serialization_vox_error serialization_vox_load(Stream *s,
                                                    Shape **out,
                                                    const bool isMutable,
                                                    ColorAtlas *colorAtlas);

#ifdef __cplusplus
} // extern "C"
#endif
