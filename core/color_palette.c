// -------------------------------------------------------------
//  Cubzh Core
//  color_palette.c
//  Created by Arthur Cormerais on August 11, 2022.
// -------------------------------------------------------------

#include "color_palette.h"

#include <string.h>

#include "cclog.h"
#include "utils.h"

// MARK: - Private functions -

void _color_palette_unmap_entry_and_remap_duplicate(ColorPalette *p,
                                                    SHAPE_COLOR_INDEX_INT_T entry) {
    uint32_t rgba = color_to_uint32(&p->entries[entry].color);
    if (hash_uint32_get(p->colorToIdx, rgba, NULL)) {
        // this entry was the one used for mapping index, unmap it
        hash_uint32_delete(p->colorToIdx, rgba);

        // remap first duplicate if any
        RGBAColor color;
        for (SHAPE_COLOR_INDEX_INT_T i = 0; i < p->orderedCount; ++i) {
            if (i != entry) {
                color = p->entries[p->orderedIndices != NULL ? p->orderedIndices[i] : i].color;
                if (colors_are_equal(&color, &p->entries[entry].color)) {
                    SHAPE_COLOR_INDEX_INT_T *value = (SHAPE_COLOR_INDEX_INT_T*) malloc(sizeof(SHAPE_COLOR_INDEX_INT_T));
                    *value = i;
                    hash_uint32_set(p->colorToIdx, color_to_uint32(&color), value);
                    break;
                }
            }
        }
    }
}

// MARK: -

ColorPalette *color_palette_new(ColorAtlas *atlas) {
    ColorPalette *p = (ColorPalette *)malloc(sizeof(ColorPalette));
    if (p == NULL) {
        return NULL;
    }
    p->refAtlas = atlas != NULL ? color_atlas_get_and_retain_weakptr(atlas) : NULL;
    p->entries = (PaletteEntry *)malloc(sizeof(PaletteEntry) * SHAPE_COLOR_INDEX_MAX_COUNT);
    p->orderedIndices = NULL;
    p->availableIndices = NULL;
    p->colorToIdx = hash_uint32_new(free);
    p->count = 0;
    p->orderedCount = 0;
    p->lighting_dirty = false;
    p->wptr = NULL;
    return p;
}

ColorPalette *color_palette_new_from_data(ColorAtlas *atlas,
                                          uint8_t count,
                                          const RGBAColor *colors,
                                          const bool *emissive) {
    // Shape runtime palettes have a definite number of colors, but we allow loading palettes of any
    // capacity eg. default palette or legacy palette
    const uint8_t size = maximum(count, SHAPE_COLOR_INDEX_MAX_COUNT);

    ColorPalette *p = (ColorPalette *)malloc(sizeof(ColorPalette));
    p->refAtlas = atlas != NULL ? color_atlas_get_and_retain_weakptr(atlas) : NULL;
    p->entries = (PaletteEntry *)malloc(sizeof(PaletteEntry) * size);
    p->orderedIndices = NULL;
    p->availableIndices = NULL;
    p->colorToIdx = hash_uint32_new(free);
    p->count = count;
    p->orderedCount = count;
    p->lighting_dirty = false;
    p->wptr = NULL;

    SHAPE_COLOR_INDEX_INT_T *value;
    for (SHAPE_COLOR_INDEX_INT_T i = 0; i < count; ++i) {
        p->entries[i].color = colors[i];
        p->entries[i].blocksCount = 0;
        p->entries[i].atlasIndex = ATLAS_COLOR_INDEX_ERROR;
        p->entries[i].orderedIndex = i;
        if (emissive != NULL) {
            p->entries[i].emissive = emissive[i];
        }
        value = (SHAPE_COLOR_INDEX_INT_T*)malloc(sizeof(SHAPE_COLOR_INDEX_INT_T));
        *value = i;
        hash_uint32_set(p->colorToIdx, color_to_uint32(&(colors[i])), value);
    }
    for (SHAPE_COLOR_INDEX_INT_T i = count; i < SHAPE_COLOR_INDEX_MAX_COUNT; ++i) {
        p->entries[i].color = (RGBAColor){0, 0, 0, 0};
        p->entries[i].blocksCount = 0;
        p->entries[i].atlasIndex = ATLAS_COLOR_INDEX_ERROR;
        p->entries[i].orderedIndex = i;
        if (emissive != NULL) {
            p->entries[i].emissive = false;
        }
    }

    return p;
}

ColorPalette *color_palette_new_copy(const ColorPalette *src) {
    ColorPalette *dst = color_palette_new(weakptr_get(src->refAtlas));
    color_palette_copy(dst, src);
    return dst;
}

void color_palette_free(ColorPalette *p) {
    if (p == NULL) {
        return;
    }
    ColorAtlas *a = (ColorAtlas *)weakptr_get(p->refAtlas);
    if (a != NULL) {
        color_atlas_remove_palette(a, p);
    }
    weakptr_release(p->refAtlas);
    free(p->entries);
    if (p->orderedIndices != NULL) {
        free(p->orderedIndices);
    }
    if (p->availableIndices != NULL) {
        fifo_list_free(p->availableIndices, free);
    }
    hash_uint32_free(p->colorToIdx);
    weakptr_invalidate(p->wptr);
    free(p);
}

uint8_t color_palette_get_count(const ColorPalette *p) {
    return p->count;
}

void color_palette_set_atlas(ColorPalette *p, ColorAtlas *atlas) {
    if (p->refAtlas != NULL) {
        cclog_warning(" ️⚠️ color_palette_set_atlas: replacing existing atlas will affect "
                      "loaded shapes");

        ColorAtlas *a = (ColorAtlas *)weakptr_get(p->refAtlas);
        if (a != NULL) {
            color_atlas_remove_palette(a, p);
        }
        weakptr_release(p->refAtlas);
    }
    p->refAtlas = color_atlas_get_and_retain_weakptr(atlas);

    for (SHAPE_COLOR_INDEX_INT_T i = 0; i < p->count; ++i) {
        p->entries[i].atlasIndex = color_atlas_check_and_add_color(atlas, p->entries[i].color);
    }
}

ColorAtlas *color_palette_get_atlas(const ColorPalette *p) {
    return weakptr_get(p->refAtlas);
}

bool color_palette_find(const ColorPalette *p, RGBAColor color, SHAPE_COLOR_INDEX_INT_T *entryOut) {
    void *idx;
    if (hash_uint32_get(p->colorToIdx, color_to_uint32(&color), &idx)) {
        if (entryOut != NULL) {
            *entryOut = *((SHAPE_COLOR_INDEX_INT_T*)idx);
        }
        return true;
    } else {
        if (entryOut != NULL) {
            *entryOut = SHAPE_COLOR_INDEX_AIR_BLOCK;
        }
        return false;
    }
}

bool color_palette_check_and_add_color(ColorPalette *p,
                                       RGBAColor color,
                                       SHAPE_COLOR_INDEX_INT_T *entryOut,
                                       bool allowDuplicates) {
    SHAPE_COLOR_INDEX_INT_T idx;
    if (allowDuplicates == false && color_palette_find(p, color, &idx)) {
        if (entryOut != NULL) {
            *entryOut = (SHAPE_COLOR_INDEX_INT_T)idx;
        }
        return true; // color exists already and can be used
    }

    if (p->orderedCount >= SHAPE_COLOR_INDEX_MAX_COUNT) {
        if (entryOut != NULL) {
            *entryOut = SHAPE_COLOR_INDEX_AIR_BLOCK;
        }
        return false; // new color cannot be added and should not be used
    }

    void *pop = p->availableIndices != NULL ? fifo_list_pop(p->availableIndices) : NULL;
    if (pop != NULL) {
        idx = *((SHAPE_COLOR_INDEX_INT_T *)pop);
        free(pop);
    } else {
        idx = p->count++;
    }

    if (entryOut != NULL) {
        *entryOut = idx;
    }

    p->entries[idx].color = color;
    p->entries[idx].blocksCount = 0;
    p->entries[idx].atlasIndex = ATLAS_COLOR_INDEX_ERROR;
    p->entries[idx].orderedIndex = p->orderedCount;
    p->entries[idx].emissive = false;

    // for duplicates, keep latest color index
    SHAPE_COLOR_INDEX_INT_T *value = (SHAPE_COLOR_INDEX_INT_T*)malloc(sizeof(SHAPE_COLOR_INDEX_INT_T));
    *value = idx;
    hash_uint32_set(p->colorToIdx, color_to_uint32(&color), value);

    if (p->orderedIndices != NULL) {
        p->orderedIndices[p->orderedCount] = idx;
    }
    p->orderedCount++;

    return true; // new color added
}

bool color_palette_check_and_add_default_color_2021(ColorPalette *p,
                                                    SHAPE_COLOR_INDEX_INT_T defaultIdx,
                                                    SHAPE_COLOR_INDEX_INT_T *entryOut) {
    RGBAColor *color = color_palette_get_color(
        color_palette_get_default_2021(weakptr_get(p->refAtlas)),
        defaultIdx);
    if (color == NULL) {
        if (entryOut != NULL) {
            *entryOut = SHAPE_COLOR_INDEX_AIR_BLOCK;
        }
        return false; // color not found and should not be used
    }
    return color_palette_check_and_add_color(p, *color, entryOut, false);
}

bool color_palette_check_and_add_default_color_pico8p(ColorPalette *p,
                                                      SHAPE_COLOR_INDEX_INT_T defaultIdx,
                                                      SHAPE_COLOR_INDEX_INT_T *entryOut) {
    RGBAColor *color = color_palette_get_color(
        color_palette_get_default_pico8p(weakptr_get(p->refAtlas)),
        defaultIdx);
    if (color == NULL) {
        if (entryOut != NULL) {
            *entryOut = SHAPE_COLOR_INDEX_AIR_BLOCK;
        }
        return false; // color not found and should not be used
    }
    return color_palette_check_and_add_color(p, *color, entryOut, false);
}

void color_palette_increment_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry >= p->count) {
        return;
    }

    // color is now in use
    ColorAtlas *a = (ColorAtlas *)weakptr_get(p->refAtlas);
    if (a != NULL && p->entries[entry].blocksCount == 0) {
        if (p->entries[entry].atlasIndex == ATLAS_COLOR_INDEX_ERROR) {
            p->entries[entry].atlasIndex = color_atlas_check_and_add_color(a,
                                                                           p->entries[entry].color);
        }
    }
    p->entries[entry].blocksCount++;
}

void color_palette_decrement_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry >= p->count) {
        return;
    }

    if (p->entries[entry].blocksCount > 0) {
        p->entries[entry].blocksCount--;

        // color becomes unused
        ColorAtlas *a = (ColorAtlas *)weakptr_get(p->refAtlas);
        if (a != NULL && p->entries[entry].blocksCount == 0) {
            color_atlas_remove_color(a, p->entries[entry].atlasIndex);
            p->entries[entry].atlasIndex = ATLAS_COLOR_INDEX_ERROR;
        }
    }
}

bool color_palette_remove_unused_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, bool remap) {
    if (entry >= p->count || p->entries[entry].blocksCount != 0) {
        return false;
    }

    // initialize these only once a color is removed
    if (p->orderedIndices == NULL) {
        p->orderedIndices = (uint8_t *)malloc(maximum(p->count, SHAPE_COLOR_INDEX_MAX_COUNT));
        for (uint8_t i = 0; i < p->orderedCount; ++i) {
            p->orderedIndices[i] = i;
        }
    }
    if (p->availableIndices == NULL) {
        p->availableIndices = fifo_list_new();
    }

    // entry becomes available
    SHAPE_COLOR_INDEX_INT_T *push = malloc(sizeof(SHAPE_COLOR_INDEX_INT_T));
    *push = entry;
    fifo_list_push(p->availableIndices, push);

    // remove from ordered indices mapping (by offseting array from removed orderedIndex)
    p->orderedCount--;
    for (SHAPE_COLOR_INDEX_INT_T i = p->entries[entry].orderedIndex; i < p->orderedCount; ++i) {
        p->orderedIndices[i] = p->orderedIndices[i + 1];
        p->entries[p->orderedIndices[i]].orderedIndex = i;
    }
    p->entries[entry].orderedIndex = SHAPE_COLOR_INDEX_MAX_COUNT;

    if (remap) {
        _color_palette_unmap_entry_and_remap_duplicate(p, entry);
    }

    return true;
}

void color_palette_remove_all_unused_colors(ColorPalette *p, bool remap) {
    for (uint8_t i = 0; i < p->count; ++i) {
        if (p->entries[i].orderedIndex < SHAPE_COLOR_INDEX_MAX_COUNT &&
            p->entries[i].blocksCount == 0) {
            color_palette_remove_unused_color(p, i, remap);
        }
    }
}

uint32_t color_palette_get_color_use_count(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry >= p->count) {
        return 0;
    }
    return p->entries[entry].blocksCount;
}

void color_palette_set_color(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, RGBAColor color) {
    if (entry >= p->count) {
        return;
    }

    if (colors_are_equal(&p->entries[entry].color, &color)) {
        return;
    }

    // baked lighting becomes dirty if,
    // (1) the color is emissive,
    // (2) going from opaque to transparent or transparent to opaque color,
    // (3) both are transparent but different alpha
    if (p->entries[entry].emissive) { // (1)
        p->lighting_dirty = true;
    } else {
        const bool prevOpaque = color_is_opaque(&p->entries[entry].color);
        const bool newOpaque = color_is_opaque(&color);
        if (prevOpaque != newOpaque // (2)
            || (prevOpaque == false && newOpaque == false &&
                p->entries[entry].color.a != color.a)) { // (3)
            p->lighting_dirty = true;
        }
    }

    ColorAtlas *a = (ColorAtlas *)weakptr_get(p->refAtlas);

    _color_palette_unmap_entry_and_remap_duplicate(p, entry);
    p->entries[entry].color = color;
    if (a != NULL && p->entries[entry].atlasIndex != ATLAS_COLOR_INDEX_ERROR) {
        color_atlas_set_color(a, p->entries[entry].atlasIndex, color);
    }
    SHAPE_COLOR_INDEX_INT_T *value = (SHAPE_COLOR_INDEX_INT_T*)malloc(sizeof(SHAPE_COLOR_INDEX_INT_T));
    *value = entry;
    hash_uint32_set(p->colorToIdx, color_to_uint32(&color), value);
}

RGBAColor *color_palette_get_color(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry >= p->count) {
        return NULL;
    }
    return &p->entries[entry].color;
}

void color_palette_set_emissive(ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry, bool toggle) {
    if (entry >= p->count) {
        return;
    }
    if (p->entries[entry].emissive != toggle) {
        p->entries[entry].emissive = toggle;
        p->lighting_dirty = true;
    }
}

bool color_palette_is_emissive(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry >= p->count) {
        return false;
    }
    return p->entries[entry].emissive;
}

bool color_palette_is_transparent(const ColorPalette *p, SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry >= p->count) {
        return false;
    }
    return p->entries[entry].color.a < 255;
}

ATLAS_COLOR_INDEX_INT_T color_palette_get_atlas_index(const ColorPalette *p,
                                                      SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry == SHAPE_COLOR_INDEX_AIR_BLOCK || entry >= p->count) {
        return ATLAS_COLOR_INDEX_ERROR;
    }
    return p->entries[entry].atlasIndex;
}

VERTEX_LIGHT_STRUCT_T color_palette_get_emissive_color_as_light(const ColorPalette *p,
                                                                SHAPE_COLOR_INDEX_INT_T entry) {
    VERTEX_LIGHT_STRUCT_T l;
    ZERO_LIGHT(l)

    if (entry >= p->count) {
        return l;
    }

    if (p->entries[entry].emissive) {
        RGBAColor *c = &p->entries[entry].color;
        uint8_t temp = c->r >> 4;
        l.red = (uint8_t)(temp & 0x0F);
        temp = c->g >> 4;
        l.green = (uint8_t)(temp & 0x0F);
        temp = c->b >> 4;
        l.blue = (uint8_t)(temp & 0x0F);
    }

    return l;
}

void color_palette_copy(ColorPalette *dst, const ColorPalette *src) {
    dst->count = src->count;
    dst->orderedCount = src->orderedCount;

    // copy entries
    const uint8_t size = maximum(src->count, SHAPE_COLOR_INDEX_MAX_COUNT);
    memcpy(dst->entries, src->entries, sizeof(PaletteEntry) * size);

    // copy transient indices states
    if (src->orderedIndices != NULL) {
        dst->orderedIndices = (SHAPE_COLOR_INDEX_INT_T *)malloc(sizeof(SHAPE_COLOR_INDEX_INT_T) *
                                                                size);
        memcpy(dst->orderedIndices, src->orderedIndices, size);
    }
    if (src->availableIndices != NULL) {
        dst->availableIndices = fifo_list_new_copy(src->availableIndices);
    }

    // populate hashmap + increment usage count w/ atlas
    ColorAtlas *a = (ColorAtlas *)weakptr_get(src->refAtlas);
    SHAPE_COLOR_INDEX_INT_T *value;
    for (int i = 0; i < dst->count; ++i) {
        value = (SHAPE_COLOR_INDEX_INT_T*) malloc(sizeof(SHAPE_COLOR_INDEX_INT_T));
        *value = i;
        hash_uint32_set(dst->colorToIdx, color_to_uint32(&(dst->entries[i].color)), value);
        if (dst->entries[i].blocksCount > 0 && a != NULL) {
            dst->entries[i].atlasIndex = color_atlas_check_and_add_color(a, dst->entries[i].color);
        }
    }
}

RGBAColor *color_palette_get_colors_as_array(const ColorPalette *p,
                                             bool **emissive,
                                             SHAPE_COLOR_INDEX_INT_T **outMapping) {
    RGBAColor *colors = (RGBAColor *)malloc(sizeof(RGBAColor) * p->count);
    if (emissive != NULL) {
        *emissive = (bool *)malloc(sizeof(bool) * p->count);
    }
    if (outMapping == NULL || p->orderedIndices == NULL) {
        // No mapping requested or needed
        for (int i = 0; i < p->count; ++i) {
            colors[i] = p->entries[i].color;
            if (emissive != NULL) {
                (*emissive)[i] = p->entries[i].emissive;
            }
        }
    } else {
        // Copy inverse index mapping to be used when serializing
        *outMapping = (SHAPE_COLOR_INDEX_INT_T *)malloc(sizeof(SHAPE_COLOR_INDEX_INT_T) * p->count);
        memset(*outMapping, SHAPE_COLOR_INDEX_AIR_BLOCK, p->count);
        for (uint8_t i = 0; i < p->orderedCount; ++i) {
            (*outMapping)[p->orderedIndices[i]] = i;
        }

        // Apply order to color & emissive arrays
        for (uint8_t i = 0; i < p->orderedCount; ++i) {
            colors[i] = p->entries[p->orderedIndices[i]].color;
            if (emissive != NULL) {
                (*emissive)[i] = p->entries[p->orderedIndices[i]].emissive;
            }
        }
    }
    return colors;
}

bool color_palette_needs_ordering(const ColorPalette *p) {
    return p->orderedIndices != NULL;
}

Weakptr *color_palette_get_weakptr(ColorPalette *p) {
    if (p->wptr == NULL) {
        p->wptr = weakptr_new(p);
    }
    return p->wptr;
}

Weakptr *color_palette_get_and_retain_weakptr(ColorPalette *p) {
    if (p->wptr == NULL) {
        p->wptr = weakptr_new(p);
    }
    if (weakptr_retain(p->wptr)) {
        return p->wptr;
    } else { // this can only happen if weakptr ref count is at max
        return NULL;
    }
}

// MARK: - Baked lighting -

bool color_palette_is_lighting_dirty(const ColorPalette *p) {
    return p->lighting_dirty;
}

void color_palette_clear_lighting_dirty(ColorPalette *p) {
    p->lighting_dirty = false;
}

uint32_t color_palette_get_lighting_hash(const ColorPalette *p) {
    // hash should only include colors affecting lighting (emissive and/or transparent)
    // note: this hash passes consecutive batches of ~100000 calls to debug_color_palette_test_hash
    uint32_t hash = p->count * PRIME_NUMBERS130[0];
    for (int i = 0; i < p->count; ++i) {
        if (p->entries[i].emissive || p->entries[i].color.a < 255) {
            hash += color_to_uint32(&p->entries[i].color) * PRIME_NUMBERS130[i + 1];
        }
    }
    return hash;
}

bool debug_color_palette_test_hash(ColorPalette **p1Out, ColorPalette **p2Out) {
    srand((uint32_t)rand());

    // generate 2 random palettes
    ColorPalette *p1 = color_palette_new(NULL);
    ColorPalette *p2 = color_palette_new(NULL);
    SHAPE_COLOR_INDEX_INT_T idx;
    RGBAColor color1, color2;
    bool allEqual = true;
    for (int i = 0; i < SHAPE_COLOR_INDEX_MAX_COUNT; ++i) {
        color1 = (RGBAColor){(uint8_t)(frand() * 255.0f),
                             (uint8_t)(frand() * 255.0f),
                             (uint8_t)(frand() * 255.0f),
                             (uint8_t)(frand() * 255.0f)};
        color2 = (RGBAColor){(uint8_t)(frand() * 255.0f),
                             (uint8_t)(frand() * 255.0f),
                             (uint8_t)(frand() * 255.0f),
                             (uint8_t)(frand() * 255.0f)};

        color_palette_check_and_add_color(p1, color1, &idx, true);
        color_palette_set_emissive(p1, idx, frand() > 0.5f);

        color_palette_check_and_add_color(p2, color2, &idx, true);
        color_palette_set_emissive(p2, idx, frand() > 0.5f);

        allEqual &= colors_are_equal(&color1, &color2);
    }

    // compare their hash
    const uint32_t hash1 = color_palette_get_lighting_hash(p1);
    const uint32_t hash2 = color_palette_get_lighting_hash(p2);

    if (p1Out != NULL) {
        *p1Out = p1;
    }
    if (p2Out != NULL) {
        *p2Out = p2;
    }

    return (allEqual && hash1 == hash2) || (allEqual == false && hash1 != hash2);
}

// MARK: - Default palettes -

void _color_palette_default_add_color(RGBAColor *colors,
                                      SHAPE_COLOR_INDEX_INT_T *index,
                                      RGBAColor color) {
    colors[*index] = color;
    vx_assert(*index >= 0 && *index < 255);
    *index += 1;

    color.a = 191;
    colors[*index] = color;
    vx_assert(*index >= 0 && *index < 255);
    *index += 1;

    color.a = 128;
    colors[*index] = color;
    vx_assert(*index >= 0 && *index < 255);
    *index += 1;
}

RGBAColor *_color_palette_create_default_colors_2021(uint8_t *count) {
    SHAPE_COLOR_INDEX_INT_T index = 0;
    RGBAColor *colors = (RGBAColor *)malloc(sizeof(RGBAColor) * 252);

    // first color - (purple)
    _color_palette_default_add_color(colors, &index, (RGBAColor){61, 0, 85, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){136, 0, 252, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){173, 49, 255, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){182, 122, 233, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){201, 162, 255, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){202, 186, 224, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){237, 215, 255, 255});

    // second color - (pink)
    _color_palette_default_add_color(colors, &index, (RGBAColor){107, 0, 68, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){178, 0, 113, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 0, 120, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 12, 236, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 105, 243, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 157, 219, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){248, 203, 231, 255});

    // third color - (red)
    _color_palette_default_add_color(colors, &index, (RGBAColor){70, 5, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){98, 32, 27, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){184, 13, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 18, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 95, 83, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 117, 156, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 175, 198, 255});

    // fourth color - (orange)
    _color_palette_default_add_color(colors, &index, (RGBAColor){97, 39, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){127, 65, 50, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){188, 75, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){253, 110, 14, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){251, 145, 31, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){253, 174, 78, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 192, 129, 255});

    // fifth color - (yellow)
    _color_palette_default_add_color(colors, &index, (RGBAColor){120, 90, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){186, 158, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 191, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 224, 58, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 221, 120, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 251, 166, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 253, 211, 255});

    // sixth color - (apple green)
    _color_palette_default_add_color(colors, &index, (RGBAColor){30, 61, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){59, 117, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){96, 214, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){132, 255, 32, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){179, 255, 97, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){209, 255, 160, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){233, 255, 189, 255});

    // seventh color - (green)
    _color_palette_default_add_color(colors, &index, (RGBAColor){13, 48, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){2, 83, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){20, 160, 17, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){6, 238, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){106, 255, 133, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){152, 218, 151, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){190, 245, 200, 255});

    // eighth color - (blue/green)
    _color_palette_default_add_color(colors, &index, (RGBAColor){34, 67, 57, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){60, 137, 90, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){11, 159, 115, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){4, 229, 162, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){132, 255, 226, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){146, 229, 207, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){186, 255, 239, 255});

    // ninth color - (blue)
    _color_palette_default_add_color(colors, &index, (RGBAColor){5, 44, 56, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){0, 81, 123, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){17, 139, 174, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){0, 198, 255, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){76, 215, 255, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){130, 196, 215, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){164, 250, 255, 255});

    // tenth color - (sea blue)
    _color_palette_default_add_color(colors, &index, (RGBAColor){0, 23, 71, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){0, 47, 142, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){0, 81, 173, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){0, 120, 255, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){42, 143, 255, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){158, 189, 255, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){211, 223, 255, 255});

    // eleventh color - (grays)
    _color_palette_default_add_color(colors, &index, (RGBAColor){0, 0, 0, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){43, 43, 43, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){84, 84, 84, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){128, 128, 128, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){168, 168, 168, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){212, 212, 212, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 255, 255, 255});

    // twelfth color - (skin)
    _color_palette_default_add_color(colors, &index, (RGBAColor){86, 51, 23, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){129, 88, 54, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){234, 159, 98, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){230, 198, 170, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 220, 191, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 240, 197, 255});
    _color_palette_default_add_color(colors, &index, (RGBAColor){255, 247, 237, 255});

    *count = index;
    return colors;
}

RGBAColor *_color_palette_create_default_colors_pico8p(uint8_t *count) {
    RGBAColor *colors = (RGBAColor *)malloc(sizeof(RGBAColor) * 112);
    *count = 112;

    // first row
    colors[0] = (RGBAColor){0, 0, 0, 255};
    colors[1] = (RGBAColor){30, 44, 81, 255};
    colors[2] = (RGBAColor){125, 39, 83, 255};
    colors[3] = (RGBAColor){17, 132, 82, 255};
    colors[4] = (RGBAColor){169, 82, 58, 255};
    colors[5] = (RGBAColor){95, 86, 79, 255};
    colors[6] = (RGBAColor){194, 195, 199, 255};
    colors[7] = (RGBAColor){255, 241, 233, 255};
    colors[8] = (RGBAColor){251, 17, 80, 255};
    colors[9] = (RGBAColor){253, 162, 40, 255};
    colors[10] = (RGBAColor){254, 234, 65, 255};
    colors[11] = (RGBAColor){36, 226, 67, 255};
    colors[12] = (RGBAColor){52, 175, 252, 255};
    colors[13] = (RGBAColor){130, 119, 155, 255};
    colors[14] = (RGBAColor){253, 121, 169, 255};
    colors[15] = (RGBAColor){253, 204, 171, 255};

    // second row
    colors[16] = (RGBAColor){42, 42, 42, 255};
    colors[17] = (RGBAColor){48, 75, 118, 255};
    colors[18] = (RGBAColor){159, 14, 101, 255};
    colors[19] = (RGBAColor){2, 100, 62, 255};
    colors[20] = (RGBAColor){130, 45, 27, 255};
    colors[21] = (RGBAColor){114, 87, 66, 255};
    colors[22] = (RGBAColor){94, 74, 75, 255};
    colors[23] = (RGBAColor){153, 0, 39, 255};
    colors[24] = (RGBAColor){234, 0, 25, 255};
    colors[25] = (RGBAColor){255, 114, 0, 255};
    colors[26] = (RGBAColor){255, 210, 64, 255};
    colors[27] = (RGBAColor){28, 194, 61, 255};
    colors[28] = (RGBAColor){53, 136, 254, 255};
    colors[29] = (RGBAColor){117, 104, 131, 255};
    colors[30] = (RGBAColor){254, 92, 141, 255};
    colors[31] = (RGBAColor){255, 127, 126, 255};

    // third row
    colors[32] = (RGBAColor){84, 84, 84, 255};
    colors[33] = (RGBAColor){82, 0, 100, 255};
    colors[34] = (RGBAColor){114, 23, 128, 255};
    colors[35] = (RGBAColor){1, 81, 46, 255};
    colors[36] = (RGBAColor){86, 46, 23, 255};
    colors[37] = (RGBAColor){77, 65, 53, 255};
    colors[38] = (RGBAColor){71, 55, 58, 255};
    colors[39] = (RGBAColor){81, 28, 48, 255};
    colors[40] = (RGBAColor){184, 0, 39, 255};
    colors[41] = (RGBAColor){195, 75, 41, 255};
    colors[42] = (RGBAColor){214, 161, 67, 255};
    colors[43] = (RGBAColor){37, 154, 62, 255};
    colors[44] = (RGBAColor){52, 122, 181, 255};
    colors[45] = (RGBAColor){97, 77, 102, 255};
    colors[46] = (RGBAColor){255, 0, 118, 255};
    colors[47] = (RGBAColor){254, 78, 107, 255};

    // 4th row
    colors[48] = (RGBAColor){126, 126, 126, 255};
    colors[49] = (RGBAColor){30, 23, 41, 255};
    colors[50] = (RGBAColor){47, 38, 65, 255};
    colors[51] = (RGBAColor){69, 73, 100, 255};
    colors[52] = (RGBAColor){92, 108, 133, 255};
    colors[53] = (RGBAColor){154, 169, 188, 255};
    colors[54] = (RGBAColor){202, 210, 233, 255};
    colors[55] = (RGBAColor){237, 232, 255, 255};
    colors[56] = (RGBAColor){125, 0, 40, 255};
    colors[57] = (RGBAColor){132, 73, 44, 255};
    colors[58] = (RGBAColor){161, 122, 67, 255};
    colors[59] = (RGBAColor){3, 124, 48, 255};
    colors[60] = (RGBAColor){58, 93, 149, 255};
    colors[61] = (RGBAColor){187, 37, 162, 255};
    colors[62] = (RGBAColor){255, 165, 165, 255};
    colors[63] = (RGBAColor){254, 191, 199, 255};

    // 5th row
    colors[64] = (RGBAColor){168, 168, 168, 255};
    colors[65] = (RGBAColor){210, 210, 210, 255};
    colors[66] = (RGBAColor){255, 255, 255, 255};
    colors[67] = (RGBAColor){148, 69, 62, 255};
    colors[68] = (RGBAColor){186, 95, 66, 255};
    colors[69] = (RGBAColor){214, 130, 106, 255};
    colors[70] = (RGBAColor){254, 174, 137, 255};
    colors[71] = (RGBAColor){254, 223, 195, 255};
    colors[72] = (RGBAColor){255, 170, 87, 255};
    colors[73] = (RGBAColor){38, 178, 128, 255};
    colors[74] = (RGBAColor){29, 225, 136, 255};
    colors[75] = (RGBAColor){171, 247, 115, 255};
    colors[76] = (RGBAColor){130, 20, 212, 255};
    colors[77] = (RGBAColor){237, 0, 168, 255};
    colors[78] = (RGBAColor){209, 135, 255, 255};
    colors[79] = (RGBAColor){255, 140, 223, 255};

    // 6th row
    colors[80] = (RGBAColor){142, 105, 95, 255};
    colors[81] = (RGBAColor){169, 124, 127, 255};
    colors[82] = (RGBAColor){186, 147, 140, 255};
    colors[83] = (RGBAColor){206, 170, 156, 255};
    colors[84] = (RGBAColor){225, 200, 180, 255};
    colors[85] = (RGBAColor){245, 229, 216, 255};
    colors[86] = (RGBAColor){109, 89, 88, 255};
    colors[87] = (RGBAColor){125, 108, 101, 255};
    colors[88] = (RGBAColor){145, 131, 120, 255};
    colors[89] = (RGBAColor){166, 155, 136, 255};
    colors[90] = (RGBAColor){188, 180, 157, 255};
    colors[91] = (RGBAColor){217, 205, 193, 255};
    colors[92] = (RGBAColor){255, 232, 136, 255};
    colors[93] = (RGBAColor){113, 247, 178, 255};
    colors[94] = (RGBAColor){204, 255, 210, 255};
    colors[95] = (RGBAColor){154, 208, 255, 255};

    // 7th row - EMISSIVE
    colors[96] = (RGBAColor){255, 255, 255, 255};
    colors[97] = (RGBAColor){30, 44, 81, 255};
    colors[98] = (RGBAColor){125, 39, 83, 255};
    colors[99] = (RGBAColor){17, 132, 82, 255};
    colors[100] = (RGBAColor){169, 82, 58, 255};
    colors[101] = (RGBAColor){95, 86, 79, 255};
    colors[102] = (RGBAColor){194, 195, 199, 255};
    colors[103] = (RGBAColor){255, 241, 233, 255};
    colors[104] = (RGBAColor){251, 17, 80, 255};
    colors[105] = (RGBAColor){253, 162, 40, 255};
    colors[106] = (RGBAColor){254, 234, 65, 255};
    colors[107] = (RGBAColor){36, 226, 67, 255};
    colors[108] = (RGBAColor){52, 175, 252, 255};
    colors[109] = (RGBAColor){130, 119, 155, 255};
    colors[110] = (RGBAColor){253, 121, 169, 255};
    colors[111] = (RGBAColor){253, 204, 171, 255};

    return colors;
}

RGBAColor *color_palette_get_default_colors_2021(ColorAtlas *atlas) {
    static RGBAColor *colors = NULL;

    if (colors == NULL) {
        colors = color_palette_get_colors_as_array(color_palette_get_default_2021(atlas),
                                                   NULL,
                                                   NULL);
    }

    return colors;
}

ColorPalette *color_palette_get_default_2021(ColorAtlas *atlas) {
    static ColorPalette *palette = NULL;

    if (palette == NULL) {
        uint8_t count;
        RGBAColor *colors = _color_palette_create_default_colors_2021(&count);
        palette = color_palette_new_from_data(atlas, count, colors, NULL);
        free(colors);
    }

    return palette;
}

RGBAColor *color_palette_get_default_colors_pico8p(ColorAtlas *atlas) {
    static RGBAColor *colors = NULL;

    if (colors == NULL) {
        colors = color_palette_get_colors_as_array(color_palette_get_default_pico8p(atlas),
                                                   NULL,
                                                   NULL);
    }

    return colors;
}

ColorPalette *color_palette_get_default_pico8p(ColorAtlas *atlas) {
    static ColorPalette *palette = NULL;

    if (palette == NULL) {
        uint8_t count;
        RGBAColor *colors = _color_palette_create_default_colors_pico8p(&count);
        palette = color_palette_new_from_data(atlas, count, colors, NULL);
        free(colors);
    }

    return palette;
}

// MARK: - User-friendly ordering -

uint8_t color_palette_get_ordered_count(const ColorPalette *p) {
    return p->orderedCount;
}

SHAPE_COLOR_INDEX_INT_T color_palette_entry_idx_to_ordered_idx(const ColorPalette *p,
                                                               SHAPE_COLOR_INDEX_INT_T entry) {
    if (entry >= p->count) {
        return SHAPE_COLOR_INDEX_AIR_BLOCK;
    }
    return p->entries[entry].orderedIndex;
}

SHAPE_COLOR_INDEX_INT_T color_palette_ordered_idx_to_entry_idx(const ColorPalette *p,
                                                               SHAPE_COLOR_INDEX_INT_T ordered) {
    if (ordered >= p->orderedCount) {
        return SHAPE_COLOR_INDEX_AIR_BLOCK;
    } else if (p->orderedIndices == NULL) {
        return ordered;
    } else {
        return p->orderedIndices[ordered];
    }
}
