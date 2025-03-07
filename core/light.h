// -------------------------------------------------------------
//  Cubzh Core
//  light.h
//  Created by Arthur Cormerais on May 11, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include "transform.h"

typedef struct _Light Light;

#define LIGHT_DEFAULT_PRIORITY 255
#define LIGHT_DEFAULT_RANGE 30.0f
#define LIGHT_DEFAULT_HARDNESS 0.5f
#define LIGHT_DEFAULT_ANGLE 0.7f

typedef enum {
    LightType_Point,
    LightType_Spot,
    LightType_Directional
} LightType;

Light *light_new(void);
Light *light_new_point(const float radius, const float hardness, const uint8_t priority);
Light *light_new_spot(const float range,
                      const float angle,
                      const float hardness,
                      const uint8_t priority);
Light *light_new_directional(const uint8_t priority);
void light_release(Light *l); // releases transform
void light_free(Light *l);    // called in transform_release, does not free transform

Transform *light_get_transform(const Light *l);
void light_set_color(Light *l, const float r, const float g, const float b);
float3 *light_get_color(const Light *l);
void light_set_type(Light *l, LightType type);
LightType light_get_type(const Light *l);
void light_set_range(Light *l, const float area);
float light_get_range(const Light *l);
void light_set_hardness(Light *l, const float hardness);
float light_get_hardness(const Light *l);
void light_set_angle(Light *l, const float angle);
float light_get_angle(const Light *l);
void light_set_intensity(Light *l, float value);
float light_get_intensity(const Light *l);
void light_set_priority(Light *l, const uint8_t priority);
uint8_t light_get_priority(const Light *l);
void light_set_layers(Light *l, const uint16_t value);
uint16_t light_get_layers(const Light *l);
void light_set_enabled(Light *l, const bool enabled);
bool light_is_enabled(const Light *l);
void light_set_shadow_caster(Light *l, const bool enabled);
bool light_is_shadow_caster(const Light *l);

#ifdef __cplusplus
} // extern "C"
#endif
