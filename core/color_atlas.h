// -------------------------------------------------------------
//  Cubzh Core
//  color_atlas.h
//  Created by Mina Pecheux on July 19, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

#include "colors.h"
#include "fifo_list.h"
#include "float3.h"
#include "hash_uint32.h"
#include "weakptr.h"

#if DEBUG
#define DEBUG_MARK_OPERATIONS false
#else
#define DEBUG_MARK_OPERATIONS false
#endif

typedef struct ColorPalette ColorPalette;

/// Flat array representation of the data mounted into a color atlas renderer-side,
/// - even row numbers contain original colors
/// - odd row numbers contain complementary colors
///
/// The maximum number of colors is therefore: atlas size * atlas size / 2
typedef struct ColorAtlas {
    Weakptr *wptr;
    RGBAColor *colors;
    RGBAColor *complementaryColors;
    FifoList *availableIndices; // pool of available indices below count
    uint32_t count;
    uint32_t size; // atlas dimension
    ATLAS_COLOR_INDEX_INT_T dirty_slice_min, dirty_slice_max;
} ColorAtlas;

ColorAtlas *color_atlas_new(void);
void color_atlas_free(ColorAtlas *a);
Weakptr *color_atlas_get_weakptr(ColorAtlas *a);
Weakptr *color_atlas_get_and_retain_weakptr(ColorAtlas *a);

ATLAS_COLOR_INDEX_INT_T color_atlas_check_and_add_color(ColorAtlas *a, RGBAColor color);
void color_atlas_remove_color(ColorAtlas *a, ATLAS_COLOR_INDEX_INT_T index);
void color_atlas_remove_palette(ColorAtlas *a, const ColorPalette *p);
void color_atlas_set_color(ColorAtlas *a, ATLAS_COLOR_INDEX_INT_T index, RGBAColor color);
RGBAColor *color_atlas_get_color(const ColorAtlas *a, ATLAS_COLOR_INDEX_INT_T index);
void color_atlas_flush_slice(ColorAtlas *a);
void color_atlas_force_dirty_slice(ColorAtlas *a);

#ifdef __cplusplus
} // extern "C"
#endif
