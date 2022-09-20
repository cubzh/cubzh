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
enum serialization_magicavoxel_error {
    no_error = 0,
    cant_open_file = 1,
    invalid_format = 2,
    pack_chunk_found = 3,
    unknown_chunk = 4
};

/// Saves Shape in .vox format (Magicavoxel)
/// Returns true on success
bool serialization_save_vox(const Shape *const src, FILE *const out);

/// converts raw data from src to a Shape
enum serialization_magicavoxel_error serialization_vox_to_shape(Stream *s,
                                                                Shape **out,
                                                                const bool isMutable,
                                                                ColorAtlas *colorAtlas,
                                                                bool sharedColors);

#ifdef __cplusplus
} // extern "C"
#endif
