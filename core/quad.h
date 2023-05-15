// -------------------------------------------------------------
//  Cubzh Core
//  quad.h
//  Created by Arthur Cormerais on May 3, 2023.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "float3.h"
#include "transform.h"

typedef struct _Quad Quad;

Quad *quad_new(void);
void quad_free(Quad *q); // called in transform_release, does not free transform

Transform *quad_get_transform(const Quad *q);
void quad_set_width(Quad *q, float value);
float quad_get_width(const Quad *q);
void quad_set_height(Quad *q, float value);
float quad_get_height(const Quad *q);
void quad_set_anchor_x(Quad *q, float value);
float quad_get_anchor_x(const Quad *q);
void quad_set_anchor_y(Quad *q, float value);
float quad_get_anchor_y(const Quad *q);
void quad_set_color(Quad *q, uint32_t color);
uint32_t quad_get_color(const Quad *q);
void quad_set_layers(Quad *q, uint8_t value);
uint8_t quad_get_layers(const Quad *q);
void quad_set_doublesided(Quad *q, bool toggle);
bool quad_is_doublesided(const Quad *q);
void quad_set_shadow(Quad *q, bool toggle);
bool quad_has_shadow(const Quad *q);
void quad_set_unlit(Quad *q, bool value);
bool quad_is_unlit(const Quad *q);

// MARK: - Utils -

float quad_utils_get_diagonal(const Quad *q);

#ifdef __cplusplus
} // extern "C"
#endif
