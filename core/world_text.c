// -------------------------------------------------------------
//  Cubzh
//  world_text.c
//  Created by Arthur Cormerais on September 27, 2022.
// -------------------------------------------------------------

#include "world_text.h"

#include <string.h>

#include "vxconfig.h"
#include "utils.h"

#define WORLDTEXT_NONE 0
#define WORLDTEXT_GEOMETRY 1 // text geometry is dirty
#define WORLDTEXT_COLOR 2 // text color is dirty
#define WORLDTEXT_ALIGNMENT 4 // text alignment is dirty
#define WORLDTEXT_SLANT 8 // text slant is dirty

#define WORLDTEXT_OPTION_NONE 0
#define WORLDTEXT_OPTION_TAIL 1 // optional tail under the background frame
#define WORLDTEXT_OPTION_UNLIT 2
#define WORLDTEXT_OPTION_POINTS 4 // cached size stored as points
#define WORLDTEXT_OPTION_DOUBLESIDED 8
#define WORLDTEXT_OPTION_ALIGNMENT 48 // text alignment (3 values, 2 bits)
#define WORLDTEXT_OPTION_ALIGNMENT_BITSHIFT 4

typedef struct {
    uint32_t outlineColor; /* 4 bytes */
    uint8_t outlineWeight; /* 1 byte */
} WorldTextDrawmodes;

// Text metrics are camera-dependant, i.e. interpreted as pixels if filmed in orthographic view (or
// if using TextType_Screen, which creates an ortho view behind the scene), or interpreted as
// world units if filmed in perspective.
//
// Text's width/height are cached to whatever unit was requested, and cache will reset if requesting
// a different unit
struct _WorldText {
    Transform *transform; /* 8 bytes */
    Weakptr *wptr; /* 8 bytes */
    char *text; /* 8 bytes */
    WorldTextDrawmodes *drawmodes; /* 8 bytes */

    // Normalized anchor
    float anchorX, anchorY; /* 2x4 bytes */

    // Enable and set text & background color, disable by setting alpha to 0 (default)
    uint32_t color, bgColor; /* 2x4 bytes */

    // Read-only raw dimensions, computed on-demand and cached
    float width, height; /* 2x4 bytes */

    // Enable multi-line break, disabled at 0 by default
    float maxWidth; /* 4 bytes */

    // Culled beyond max distance w/ built-in fade-out at the end
    float maxDistance; /* 4 bytes */

    // Text padding over background
    float padding; /* 4 bytes */

    // Font size, scaling from native font size
    float fontSize; /* 4 bytes */

    // ID used for rendering
    uint32_t id; /* 4 bytes */

    uint16_t layers; /* 2 bytes */

    // Options mask
    uint8_t options; /* 1 byte */

    // Formatting options, normalized floats packed as uint8
    uint8_t weight; /* 1 byte */
    uint8_t slant; /* 1 byte */

    uint8_t type; /* 1 byte */
    uint8_t fontIdx; /* 1 byte */
    uint8_t dirty; /* 1 byte */

    uint8_t sortOrder; /* 1 byte */

    char pad[3];
};

void _world_text_toggle_option(WorldText *wt, uint8_t option, bool toggle) {
    if (toggle) {
        wt->options |= option;
    } else {
        wt->options &= ~option;
    }
}

bool _world_text_get_option(const WorldText *wt, uint8_t option) {
    return option == (wt->options & option);
}

void _world_text_set_dirty(WorldText *wt, uint8_t flag) {
    wt->dirty |= flag;
}

void _world_text_reset_dirty(WorldText *wt, uint8_t flag) {
    wt->dirty &= ~flag;
}

bool _world_text_get_dirty(const WorldText *wt, uint8_t flag) {
    return flag == (wt->dirty & flag);
}

void _world_text_void_free(void *o) {
    WorldText *wt = (WorldText*)o;
    vx_assert(wt != NULL);
    weakptr_invalidate(wt->wptr);
    // free fields
    free(wt->text);
    // free struct
    free(wt);
}

WorldText *world_text_new(void) {
    WorldText *wt = (WorldText*)malloc(sizeof(WorldText));

    wt->transform = transform_make_with_ptr(WorldTextTransform, wt, &_world_text_void_free);
    wt->wptr = NULL;
    wt->text = NULL;
    wt->drawmodes = NULL;
    wt->anchorX = WORLDTEXT_DEFAULT_TEXT_ANCHOR_X;
    wt->anchorY = WORLDTEXT_DEFAULT_TEXT_ANCHOR_Y;
    wt->color = WORLDTEXT_DEFAULT_COLOR;
    wt->bgColor = WORLDTEXT_DEFAULT_BG_COLOR;
    wt->width = 0.0f;
    wt->height = 0.0f;
    wt->maxWidth = 0.0f;
    wt->maxDistance = WORLDTEXT_DEFAULT_MAX_DIST;
    wt->padding = WORLDTEXT_DEFAULT_WORLD_PADDING;
    wt->fontSize = WORLDTEXT_DEFAULT_WORLD_FONT_SIZE;
    wt->id = WORLDTEXT_ID_NONE;
    wt->layers = CAMERA_LAYERS_DEFAULT;
    wt->options = WORLDTEXT_OPTION_NONE;
    wt->type = TextType_World;
    wt->fontIdx = 0;
    wt->dirty = WORLDTEXT_COLOR;
    wt->sortOrder = 0;

    world_text_set_weight(wt, WORLDTEXT_DEFAULT_FONT_WEIGHT_REGULAR);
    world_text_set_slant(wt, WORLDTEXT_DEFAULT_FONT_SLANT_REGULAR);

    return wt;
}

void world_text_release(WorldText *wt) {
    transform_release(wt->transform);
}

Transform *world_text_get_transform(const WorldText *wt) {
    return wt->transform;
}

Weakptr *world_text_get_weakptr(WorldText *wt) {
    if (wt->wptr == NULL) {
        wt->wptr = weakptr_new(wt);
    }
    return wt->wptr;
}

Weakptr *world_text_get_and_retain_weakptr(WorldText *wt) {
    if (wt->wptr == NULL) {
        wt->wptr = weakptr_new(wt);
    }
    if (weakptr_retain(wt->wptr)) {
        return wt->wptr;
    } else { // this can only happen if weakptr ref count is at max
        return NULL;
    }
}

void world_text_set_text(WorldText *wt, const char *text) {
    if (wt->text != NULL) {
        free(wt->text);
    }
    wt->text = string_new_copy(text);
    _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
}

const char *world_text_get_text(const WorldText *wt) {
    return wt->text;
}

bool world_text_is_empty(const WorldText *wt) {
    return wt->text == NULL || strlen(wt->text) == 0;
}

void world_text_toggle_drawmodes(WorldText *wt, bool toggle) {
    if (toggle && wt->drawmodes == NULL) {
        wt->drawmodes = (WorldTextDrawmodes*)malloc(sizeof(WorldTextDrawmodes));
        wt->drawmodes->outlineColor = WORLDTEXT_DEFAULT_OUTLINE_COLOR;
        wt->drawmodes->outlineWeight = 0;
    } else if (toggle == false && wt->drawmodes != NULL) {
        free(wt->drawmodes);
        wt->drawmodes = NULL;
    }
}

bool world_text_uses_drawmodes(const WorldText *wt) {
    return wt->drawmodes != NULL;
}

void world_text_set_anchor_x(WorldText *wt, float x) {
    if (float_isEqual(wt->anchorX, x, EPSILON_ZERO) == false) {
        wt->anchorX = x;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_get_anchor_x(const WorldText *wt) {
    return wt->anchorX;
}

void world_text_set_anchor_y(WorldText *wt, float y) {
    if (float_isEqual(wt->anchorY, y, EPSILON_ZERO) == false) {
        wt->anchorY = y;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_get_anchor_y(const WorldText *wt) {
    return wt->anchorY;
}

void world_text_set_color(WorldText *wt, uint32_t color) {
    if (wt->color != color) {
        wt->color = color;
        _world_text_set_dirty(wt, WORLDTEXT_COLOR);
    }
}

uint32_t world_text_get_color(const WorldText *wt) {
    return wt->color;
}

void world_text_set_background_color(WorldText *wt, uint32_t color) {
    if (wt->bgColor != color) {
        wt->bgColor = color;
        _world_text_set_dirty(wt, WORLDTEXT_COLOR);
    }
}

uint32_t world_text_get_background_color(const WorldText *wt) {
    return wt->bgColor;
}

void world_text_set_max_distance(WorldText *wt, float value) {
    if (float_isEqual(wt->maxDistance, value, EPSILON_ZERO) == false) {
        wt->maxDistance = value;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_get_max_distance(const WorldText *wt) {
    return wt->maxDistance;
}

void world_text_set_cached_size(WorldText *wt, float width, float height, bool points) {
    wt->width = width;
    wt->height = height;
    _world_text_toggle_option(wt, WORLDTEXT_OPTION_POINTS, points);
}

float world_text_get_width(const WorldText *wt) {
    return wt->width;
}

float world_text_get_height(const WorldText *wt) {
    return wt->height;
}

void world_text_set_max_width(WorldText *wt, float value) {
    if (float_isEqual(wt->maxWidth, value, EPSILON_ZERO) == false) {
        wt->maxWidth = value;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_get_max_width(const WorldText *wt) {
    return wt->maxWidth;
}

void world_text_set_padding(WorldText *wt, float value) {
    if (float_isEqual(wt->padding, value, EPSILON_ZERO) == false) {
        wt->padding = value;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_get_padding(const WorldText *wt) {
    return wt->padding;
}

void world_text_set_font_size(WorldText *wt, float value) {
    if (float_isEqual(wt->fontSize, value, EPSILON_ZERO) == false) {
        wt->fontSize = value;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_get_font_size(const WorldText *wt) {
    return wt->fontSize;
}

void world_text_set_id(WorldText *wt, uint32_t value) {
    wt->id = value;
}

uint32_t world_text_get_id(const WorldText *wt) {
    return wt->id;
}

void world_text_set_tail(WorldText *wt, bool toggle) {
    if (_world_text_get_option(wt, WORLDTEXT_OPTION_TAIL) != toggle) {
        _world_text_toggle_option(wt, WORLDTEXT_OPTION_TAIL, toggle);
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

bool world_text_get_tail(const WorldText *wt) {
    return _world_text_get_option(wt, WORLDTEXT_OPTION_TAIL);
}

void world_text_set_unlit(WorldText *wt, bool toggle) {
    _world_text_toggle_option(wt, WORLDTEXT_OPTION_UNLIT, toggle);
}

bool world_text_is_unlit(const WorldText *wt) {
    return _world_text_get_option(wt, WORLDTEXT_OPTION_UNLIT);
}

void world_text_set_type(WorldText *wt, TextType value) {
    if (wt->type != value) {
        wt->type = value;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

TextType world_text_get_type(const WorldText *wt) {
    return wt->type;
}

uint8_t world_text_get_font_index(const WorldText *wt) {
    return wt->fontIdx;
}

void world_text_set_font_index(WorldText *wt, uint8_t value) {
    if (wt->fontIdx != value) {
        wt->fontIdx = value;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

void world_text_set_layers(WorldText *wt, uint16_t value) {
    wt->layers = value;
}

uint16_t world_text_get_layers(const WorldText *wt) {
    return wt->layers;
}

void world_text_set_geometry_dirty(WorldText *wt, bool toggle) {
    if (toggle) {
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    } else {
        _world_text_reset_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

bool world_text_is_geometry_dirty(const WorldText *wt) {
    return _world_text_get_dirty(wt, WORLDTEXT_GEOMETRY);
}

bool world_text_is_cached_size_points(const WorldText *wt) {
    return _world_text_get_option(wt, WORLDTEXT_OPTION_POINTS);
}

void world_text_set_color_dirty(WorldText *wt, bool toggle) {
    if (toggle) {
        _world_text_set_dirty(wt, WORLDTEXT_COLOR);
    } else {
        _world_text_reset_dirty(wt, WORLDTEXT_COLOR);
    }
}

bool world_text_is_color_dirty(const WorldText *wt) {
    return _world_text_get_dirty(wt, WORLDTEXT_COLOR);
}

void world_text_set_sort_order(WorldText *wt, uint8_t value) {
    wt->sortOrder = value;
}

uint8_t world_text_get_sort_order(const WorldText *wt) {
    return wt->sortOrder;
}

void world_text_set_doublesided(WorldText *wt, bool toggle) {
    _world_text_toggle_option(wt, WORLDTEXT_OPTION_DOUBLESIDED, toggle);
}

bool world_text_is_doublesided(const WorldText *wt) {
    return _world_text_get_option(wt, WORLDTEXT_OPTION_DOUBLESIDED);
}

void world_text_set_alignment(WorldText *wt, TextAlignment value) {
    wt->options &= ~WORLDTEXT_OPTION_ALIGNMENT;
    wt->options |= (uint8_t)value << WORLDTEXT_OPTION_ALIGNMENT_BITSHIFT;
    _world_text_set_dirty(wt, WORLDTEXT_ALIGNMENT);
}

TextAlignment world_text_get_alignment(const WorldText *wt) {
    return (TextAlignment)((wt->options & WORLDTEXT_OPTION_ALIGNMENT) >> WORLDTEXT_OPTION_ALIGNMENT_BITSHIFT);
}

void world_text_set_alignment_dirty(WorldText *wt, bool toggle) {
    if (toggle) {
        _world_text_set_dirty(wt, WORLDTEXT_ALIGNMENT);
    } else {
        _world_text_reset_dirty(wt, WORLDTEXT_ALIGNMENT);
    }
}

bool world_text_is_alignment_dirty(const WorldText *wt) {
    return _world_text_get_dirty(wt, WORLDTEXT_ALIGNMENT);
}

void world_text_set_weight(WorldText *wt, float value) {
    const uint8_t packed = CLAMP01F(value) * 255;
    if (wt->weight != packed) {
        wt->weight = packed;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_get_weight(const WorldText *wt) {
    return wt->weight / 255.0f;
}

void world_text_set_slant(WorldText *wt, float value) {
    wt->slant = CLAMP01F(value) * 255;
    _world_text_set_dirty(wt, WORLDTEXT_SLANT);
}

float world_text_get_slant(const WorldText *wt) {
    return wt->slant / 255.0f;
}

void world_text_set_slant_dirty(WorldText *wt, bool toggle) {
    if (toggle) {
        _world_text_set_dirty(wt, WORLDTEXT_SLANT);
    } else {
        _world_text_reset_dirty(wt, WORLDTEXT_SLANT);
    }
}

bool world_text_is_slant_dirty(const WorldText *wt) {
    return _world_text_get_dirty(wt, WORLDTEXT_SLANT);
}

void world_text_drawmode_set_outline_weight(WorldText *wt, float value) {
    if (wt->drawmodes == NULL && float_isZero(value, EPSILON_ZERO) == false) {
        world_text_toggle_drawmodes(wt, true);
    }
    const uint8_t packed = CLAMP01F(value) * 255;
    if (wt->drawmodes->outlineWeight != packed) {
        wt->drawmodes->outlineWeight = packed;
        _world_text_set_dirty(wt, WORLDTEXT_GEOMETRY);
    }
}

float world_text_drawmode_get_outline_weight(const WorldText *wt) {
    return wt->drawmodes != NULL ? wt->drawmodes->outlineWeight / 255.0f : 0.0f;
}

void world_text_drawmode_set_outline_color(WorldText *wt, uint32_t value) {
    if (wt->drawmodes == NULL) {
        world_text_toggle_drawmodes(wt, true);
    }
    wt->drawmodes->outlineColor = value;
}

uint32_t world_text_drawmode_get_outline_color(const WorldText *wt) {
    return wt->drawmodes != NULL ? wt->drawmodes->outlineColor : 0;
}
