// -------------------------------------------------------------
//  Cubzh Core
//  color_palette.c
//  Created by Arthur Cormerais on August 11, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>

#include "color_atlas.h"
#include "colors.h"
#include "config.h"
#include "weakptr.h"

#define DEBUG_PALETTE_RUN_TESTS false

typedef struct PaletteEntry {
    RGBAColor color;
    uint32_t blocksCount;
    ATLAS_COLOR_INDEX_INT_T atlasIndex;
    SHAPE_COLOR_INDEX_INT_T orderedIndex;
    bool emissive;
} PaletteEntry;

/// A color palette is tied to a shape,
/// - maps shape color index to RGBA color, emissive, and atlas color index
/// - maximum SHAPE_COLOR_INDEX_MAX_COUNT colors
/// - currently color atlas is maintained at every palette change
/// - adding a new color can be done either,
///     by checking first if it exists and insert if new (allowDuplicates=false)
///     by inserting a new color even if it is a duplicate (allowDuplicates=true)
typedef struct ColorPalette {
    Weakptr *refAtlas;
    PaletteEntry *entries;

    // Mapping user-friendly ordered indices to entry indices
    SHAPE_COLOR_INDEX_INT_T *orderedIndices;

    // Pool of available entry indices below count
    FifoList *availableIndices;

    // Reverse mapping for quick search
    HashUInt32 *colorToIdx;

    Weakptr *wptr;

    // Number of colors up to max entry index currently used (possibly includes unused entries)
    uint8_t count;

    // Number of colors in user-friendly order
    uint8_t orderedCount;

    // Is true if any alpha or emission values changed since last clear
    bool lighting_dirty;

    char pad[5];

} ColorPalette;

ColorPalette *color_palette_new(ColorAtlas *atlas);
ColorPalette *color_palette_new_from_data(ColorAtlas *atlas,
                                          uint8_t count,
                                          const RGBAColor *colors,
                                          const bool *emissive);
ColorPalette *color_palette_new_copy(const ColorPalette *src);
void color_palette_free(ColorPalette *p);

void color_palette_set_atlas(ColorPalette *p, ColorAtlas *atlas);

uint8_t color_palette_get_count(const ColorPalette *p);
ColorAtlas *color_palette_get_atlas(const ColorPalette *p);
bool color_palette_find(const ColorPalette *p, RGBAColor color, SHAPE_COLOR_INDEX_INT_T *entryOut);
/// @return false for a new color that could NOT be added to palette because it is full,
///  true otherwise (whether the color is new and was added or the color exists already)
bool color_palette_check_and_add_color(ColorPalette *p,
                                       RGBAColor color,
                                       SHAPE_COLOR_INDEX_INT_T *entryOut,
                                       bool allowDuplicates);
/// @return false for a new color that could NOT be added to palette because it is full,
/// true otherwise. Always add color even if already in the palette.
bool color_palette_check_and_add_default_color_2021(ColorPalette *p,
                                                    SHAPE_COLOR_INDEX_INT_T defaultIdx,
                                                    SHAPE_COLOR_INDEX_INT_T *entryOut);
bool color_palette_check_and_add_default_color_pico8p(ColorPalette *p,
                                                      SHAPE_COLOR_INDEX_INT_T defaultIdx,
                                                      SHAPE_COLOR_INDEX_INT_T *entryOut);
void color_palette_increment_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
void color_palette_decrement_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
bool color_palette_remove_unused_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, bool remap);
void color_palette_remove_all_unused_colors(ColorPalette *p, bool remap);
uint32_t color_palette_get_color_use_count(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
void color_palette_set_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, RGBAColor color);
RGBAColor *color_palette_get_color(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
void color_palette_set_emissive(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, bool toggle);
bool color_palette_is_emissive(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
bool color_palette_is_transparent(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
bool color_palette_get_shape_index(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T *entryOut);
ATLAS_COLOR_INDEX_INT_T color_palette_get_atlas_index(const ColorPalette *p,
                                                      SHAPE_COLOR_INDEX_INT_T entry);
VERTEX_LIGHT_STRUCT_T color_palette_get_emissive_color_as_light(const ColorPalette *p,
                                                                SHAPE_COLOR_INDEX_INT_T entry);
void color_palette_copy(ColorPalette *dst, const ColorPalette *src);
/// @param outMapping serialization mapping for index ordering
/// @return array of colors, must be freed by caller
RGBAColor *color_palette_get_colors_as_array(const ColorPalette *p,
                                             bool **emissive,
                                             SHAPE_COLOR_INDEX_INT_T **outMapping);
Weakptr *color_palette_get_weakptr(ColorPalette *p);
Weakptr *color_palette_get_and_retain_weakptr(ColorPalette *p);

// MARK: - Baked lighting -

bool color_palette_is_lighting_dirty(const ColorPalette *p);
void color_palette_clear_lighting_dirty(ColorPalette *p);
uint32_t color_palette_get_lighting_hash(const ColorPalette *p);
bool debug_color_palette_test_hash(ColorPalette **p1Out, ColorPalette **p2Out);

// MARK: - Default palettes -

RGBAColor *color_palette_get_default_colors_2021(ColorAtlas *atlas);
ColorPalette *color_palette_get_default_2021(ColorAtlas *atlas);
RGBAColor *color_palette_get_default_colors_pico8p(ColorAtlas *atlas);
ColorPalette *color_palette_get_default_pico8p(ColorAtlas *atlas);

// MARK: - User-friendly ordering -
// All palette functions expect and return entry array indices, use these functions to convert
// to and from user-friendly ordered indices eg. when interfacing w/ Lua

uint8_t color_palette_get_ordered_count(const ColorPalette *p);
SHAPE_COLOR_INDEX_INT_T color_palette_entry_idx_to_ordered_idx(const ColorPalette *p,
                                                               SHAPE_COLOR_INDEX_INT_T entry);
SHAPE_COLOR_INDEX_INT_T color_palette_ordered_idx_to_entry_idx(const ColorPalette *p,
                                                               SHAPE_COLOR_INDEX_INT_T ordered);
bool color_palette_needs_ordering(const ColorPalette *p);

#ifdef __cplusplus
} // extern "C"
#endif
