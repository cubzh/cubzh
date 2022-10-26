#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>

#include "color_atlas.h"
#include "colors.h"
#include "config.h"
#include "weakptr.h"

typedef struct PaletteEntry {
    RGBAColor color;
    uint32_t blocksCount;
    ATLAS_COLOR_INDEX_INT_T atlasIndex;
    SHAPE_COORDS_INT_T orderedIndex;
    bool emissive;
} PaletteEntry;

/// A color palette is tied to a shape,
/// - maps shape color index to RGBA color, emissive, and atlas color index
/// - maximum SHAPE_COLOR_INDEX_MAX_COUNT colors
/// - currently color atlas is maintained at every palette change TODO: move to end-of-frame if
/// needed
/// - adding a new color will check first if it exists and insert if new
typedef struct ColorPalette {
    Weakptr *refAtlas;
    PaletteEntry *entries;

    // Mapping user-friendly ordered indices to entry indices
    SHAPE_COLOR_INDEX_INT_T *orderedIndices;

    // Pool of available entry indices below count
    FifoList *availableIndices;

    // Reverse mapping for quick search
    HashUInt32Int *colorToIdx;

    // Number of colors up to max entry index currently used (possibly includes unused entries)
    uint8_t count;

    // Number of colors in user-friendly order
    uint8_t orderedCount;

    // Is true if any alpha or emission values changed since last clear
    bool lighting_dirty;

    // If true, any new color may use shared color atlas slots
    bool sharedColors;

    char pad[4];
    
    Weakptr *wptr;
} ColorPalette;

ColorPalette *color_palette_new(ColorAtlas *atlas, bool allowShared);
ColorPalette *color_palette_new_from_data(ColorAtlas *atlas,
                                          uint8_t count,
                                          const RGBAColor *colors,
                                          const bool *emissive,
                                          bool allowShared);
ColorPalette *color_palette_new_copy(const ColorPalette *src);
void color_palette_free(ColorPalette *p);

uint8_t color_palette_get_count(const ColorPalette *p);
ColorAtlas *color_palette_get_atlas(const ColorPalette *p);
void color_palette_set_shared(ColorPalette *p, bool toggle);
bool color_palette_is_shared(const ColorPalette *p);
bool color_palette_find(const ColorPalette *p, RGBAColor color, SHAPE_COLOR_INDEX_INT_T *entryOut);
/// @return false for a new color that could NOT be added to palette because it is full,
///  true otherwise (whether the color is new and was added or the color exists already)
bool color_palette_check_and_add_color(ColorPalette *p,
                                       RGBAColor color,
                                       SHAPE_COLOR_INDEX_INT_T *entryOut);
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
bool color_palette_remove_unused_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
uint32_t color_palette_get_color_use_count(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
void color_palette_set_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, RGBAColor color);
RGBAColor *color_palette_get_color(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
void color_palette_set_emissive(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, bool toggle);
bool color_palette_is_emissive(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
bool color_palette_is_transparent(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry);
bool color_palette_is_lighting_dirty(const ColorPalette *p);
void color_palette_clear_lighting_dirty(ColorPalette *p);
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
