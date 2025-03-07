// -------------------------------------------------------------
//  Cubzh
//  world_text.h
//  Created by Arthur Cormerais on September 27, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "transform.h"

typedef struct _WorldText WorldText;

#define WORLDTEXT_DEFAULT_COLOR 0xFF000000
#define WORLDTEXT_DEFAULT_BG_COLOR 0xFFFFFFFF
#define WORLDTEXT_DEFAULT_TEXT_ANCHOR_X 0.5f
#define WORLDTEXT_DEFAULT_TEXT_ANCHOR_Y 0.5f
#define WORLDTEXT_DEFAULT_MAX_DIST 350.0f
#define WORLDTEXT_DEFAULT_WORLD_PADDING 0.8f
#define WORLDTEXT_DEFAULT_WORLD_FONT_SIZE 2.2f
#define WORLDTEXT_DEFAULT_FONT_WEIGHT_REGULAR 0.5f
#define WORLDTEXT_DEFAULT_FONT_WEIGHT_BOLD 0.6f
#define WORLDTEXT_DEFAULT_FONT_WEIGHT_LIGHT 0.45f
#define WORLDTEXT_DEFAULT_FONT_SLANT_REGULAR 0.5f
#define WORLDTEXT_DEFAULT_FONT_SLANT_ITALIC 0.6f
#define WORLDTEXT_DEFAULT_OUTLINE_COLOR 0xFFFFFF00
#define WORLDTEXT_ID_NONE 0

typedef enum {
    TextType_World,
    TextType_Screen
} TextType;

typedef enum {
    TextAlignment_Left,
    TextAlignment_Center,
    TextAlignment_Right
} TextAlignment;

WorldText *world_text_new(void);
void world_text_release(WorldText *wt); // releases transform

Transform *world_text_get_transform(const WorldText *wt);
Weakptr *world_text_get_weakptr(WorldText *wt);
Weakptr *world_text_get_and_retain_weakptr(WorldText *wt);
void world_text_set_text(WorldText *wt, const char *text); // copies text
const char *world_text_get_text(const WorldText *wt);
bool world_text_is_empty(const WorldText *wt);
void world_text_toggle_drawmodes(WorldText *wt, bool toggle);
bool world_text_uses_drawmodes(const WorldText *wt);
void world_text_set_anchor_x(WorldText *wt, float x);
float world_text_get_anchor_x(const WorldText *wt);
void world_text_set_anchor_y(WorldText *wt, float y);
float world_text_get_anchor_y(const WorldText *wt);
void world_text_set_color(WorldText *wt, uint32_t color);
uint32_t world_text_get_color(const WorldText *wt);
void world_text_set_background_color(WorldText *wt, uint32_t color);
uint32_t world_text_get_background_color(const WorldText *wt);
void world_text_set_max_distance(WorldText *wt, float value);
float world_text_get_max_distance(const WorldText *wt);
void world_text_set_cached_size(WorldText *wt, float width, float height, bool points);
float world_text_get_width(const WorldText *wt);
float world_text_get_height(const WorldText *wt);
void world_text_set_max_width(WorldText *wt, float value);
float world_text_get_max_width(const WorldText *wt);
void world_text_set_padding(WorldText *wt, float value);
float world_text_get_padding(const WorldText *wt);
void world_text_set_font_size(WorldText *wt, float value);
float world_text_get_font_size(const WorldText *wt);
void world_text_set_id(WorldText *wt, uint32_t value);
uint32_t world_text_get_id(const WorldText *wt);
void world_text_set_tail(WorldText *wt, bool toggle);
bool world_text_get_tail(const WorldText *wt);
void world_text_set_unlit(WorldText *wt, bool toggle);
bool world_text_is_unlit(const WorldText *wt);
void world_text_set_type(WorldText *wt, TextType value);
TextType world_text_get_type(const WorldText *wt);
uint8_t world_text_get_font_index(const WorldText *wt);
void world_text_set_font_index(WorldText *wt, uint8_t value);
void world_text_set_layers(WorldText *wt, uint16_t value);
uint16_t world_text_get_layers(const WorldText *wt);
void world_text_set_geometry_dirty(WorldText *wt, bool toggle);
bool world_text_is_geometry_dirty(const WorldText *wt);
bool world_text_is_cached_size_points(const WorldText *wt);
void world_text_set_color_dirty(WorldText *wt, bool toggle);
bool world_text_is_color_dirty(const WorldText *wt);
void world_text_set_sort_order(WorldText *wt, uint8_t value);
uint8_t world_text_get_sort_order(const WorldText *wt);
void world_text_set_doublesided(WorldText *wt, bool toggle);
bool world_text_is_doublesided(const WorldText *wt);
void world_text_set_alignment(WorldText *wt, TextAlignment value);
TextAlignment world_text_get_alignment(const WorldText *wt);
void world_text_set_alignment_dirty(WorldText *wt, bool toggle);
bool world_text_is_alignment_dirty(const WorldText *wt);
void world_text_set_weight(WorldText *wt, float value);
float world_text_get_weight(const WorldText *wt);
void world_text_set_slant(WorldText *wt, float value);
float world_text_get_slant(const WorldText *wt);
void world_text_set_slant_dirty(WorldText *wt, bool toggle);
bool world_text_is_slant_dirty(const WorldText *wt);

void world_text_drawmode_set_outline_weight(WorldText *wt, float value);
float world_text_drawmode_get_outline_weight(const WorldText *wt);
void world_text_drawmode_set_outline_color(WorldText *wt, uint32_t value);
uint32_t world_text_drawmode_get_outline_color(const WorldText *wt);

#ifdef __cplusplus
} // extern "C"
#endif
