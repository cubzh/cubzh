// -------------------------------------------------------------
//  Cubzh Core
//  light.c
//  Created by Arthur Cormerais on May 11, 2022.
// -------------------------------------------------------------

#include "light.h"

#include "transform.h"

struct _Light {
    Transform *transform;
    float3 *color;
    float range; /* 4 bytes */
    float hardness; /* 4 bytes */
    float angle; /* 4 bytes */
    float intensity; /* 4 bytes */
    uint16_t layers; /* 2 bytes */
    uint8_t type; /* 1 byte */
    uint8_t priority; /* 1 byte */
    bool enabled; /* 1 byte */
    bool shadow; /* 1 byte */

    char pad[2];
};

void _light_void_free(void *o) {
    Light *l = (Light*)o;
    light_free(l);
}

Light *light_new(void) {
    Light *l = (Light *)malloc(sizeof(Light));

    l->transform = transform_make_with_ptr(LightTransform, l, &_light_void_free);
    l->color = float3_new_one();
    l->type = LightType_Point;
    l->range = LIGHT_DEFAULT_RANGE;
    l->hardness = LIGHT_DEFAULT_HARDNESS;
    l->angle = LIGHT_DEFAULT_ANGLE;
    l->intensity = -1.0f;
    l->priority = LIGHT_DEFAULT_PRIORITY;
    l->layers = CAMERA_LAYERS_DEFAULT;
    l->enabled = true;
    l->shadow = false;

    return l;
}

Light *light_new_point(const float radius, const float hardness, const uint8_t priority) {
    Light *l = light_new();

    l->type = LightType_Point;
    l->range = radius;
    l->hardness = hardness;
    l->priority = priority;

    return l;
}

Light *light_new_spot(const float range,
                      const float angle,
                      const float hardness,
                      const uint8_t priority) {
    Light *l = light_new();

    l->type = LightType_Spot;
    l->range = range;
    l->hardness = hardness;
    l->angle = angle;
    l->priority = priority;

    return l;
}

Light *light_new_directional(const uint8_t priority) {
    Light *l = light_new();

    l->type = LightType_Directional;
    l->priority = priority;
    l->enabled = true;

    return l;
}

void light_release(Light *l) {
    transform_release(l->transform);
}

void light_free(Light *l) {
    float3_free(l->color);
    free(l);
}

Transform *light_get_transform(const Light *l) {
    return l->transform;
}

void light_set_color(Light *l, const float r, const float g, const float b) {
    float3_set(l->color, r, g, b);
}

float3 *light_get_color(const Light *l) {
    return l->color;
}

void light_set_type(Light *l, LightType type) {
    l->type = (uint8_t)type;
}

LightType light_get_type(const Light *l) {
    return l->type;
}

void light_set_range(Light *l, const float area) {
    l->range = area;
}

float light_get_range(const Light *l) {
    return l->range;
}

void light_set_hardness(Light *l, const float hardness) {
    l->hardness = hardness;
}

float light_get_hardness(const Light *l) {
    return l->hardness;
}

void light_set_angle(Light *l, const float angle) {
    l->angle = angle;
}

float light_get_angle(const Light *l) {
    return l->angle;
}

void light_set_intensity(Light *l, float value) {
    l->intensity = value;
}

float light_get_intensity(const Light *l) {
    return l->intensity;
}

void light_set_priority(Light *l, const uint8_t priority) {
    l->priority = priority;
}

uint8_t light_get_priority(const Light *l) {
    return l->priority;
}

void light_set_layers(Light *l, const uint16_t value) {
    l->layers = value;
}

uint16_t light_get_layers(const Light *l) {
    return l->layers;
}

void light_set_enabled(Light *l, const bool enabled) {
    l->enabled = enabled;
}

bool light_is_enabled(const Light *l) {
    return l->enabled;
}

void light_set_shadow_caster(Light *l, const bool enabled) {
    l->shadow = enabled;
}

bool light_is_shadow_caster(const Light *l) {
    return l->shadow;
}
