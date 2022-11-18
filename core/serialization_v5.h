// -------------------------------------------------------------
//  Cubzh Core
//  serialization_v5.h
//  Created by Adrien Duermael on July 25, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "color_atlas.h"
#include "colors.h"
#include "shape.h"

typedef struct _Transform Transform;
typedef struct _Stream Stream;

/// Load shape from file
/// Returns NULL if the shape can't be loaded
Shape *serialization_v5_load_shape(Stream *s,
                                   const LoadShapeSettings * const settings,
                                   ColorAtlas *colorAtlas);

/// get preview data from save file path (caller must free *imageData)
bool serialization_v5_get_preview_data(Stream *s, void **imageData, uint32_t *size);

#ifdef __cplusplus
} // extern "C"
#endif
