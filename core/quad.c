// -------------------------------------------------------------
//  Cubzh Core
//  quad.c
//  Created by Arthur Cormerais on May 3, 2023.
// -------------------------------------------------------------

#include "quad.h"

#include <stdlib.h>

struct _Quad {
    Transform *transform;
    float width, height;    /* 2x4 bytes */
    float anchorX, anchorY; /* 2x4 bytes */
    uint32_t abgr;          /* 4 bytes */
    uint8_t layers;         /* 1 byte */
    bool doublesided;       /* 1 byte */
    bool shadow;            /* 1 byte */
    bool isUnlit;           /* 1 byte */

    // char pad[1];
};

void _quad_void_free(void *o) {
    Quad *q = (Quad *)o;
    quad_free(q);
}

Quad *quad_new(void) {
    Quad *q = (Quad *)malloc(sizeof(Quad));
    q->transform = transform_make_with_ptr(QuadTransform, q, 0, &_quad_void_free);
    q->width = 1.0f;
    q->height = 1.0f;
    q->anchorX = 0.0f;
    q->anchorY = 0.0f;
    q->abgr = 0xff000000;
    q->layers = 1; // CAMERA_LAYERS_0
    q->doublesided = true;
    q->shadow = false;
    q->isUnlit = false;
    return q;
}

void quad_free(Quad *q) {
    free(q);
}

Transform *quad_get_transform(const Quad *q) {
    return q->transform;
}

void quad_set_width(Quad *q, float value) {
    q->width = value;
}

float quad_get_width(const Quad *q) {
    return q->width;
}

void quad_set_height(Quad *q, float value) {
    q->height = value;
}

float quad_get_height(const Quad *q) {
    return q->height;
}

void quad_set_anchor_x(Quad *q, float value) {
    q->anchorX = value;
}

float quad_get_anchor_x(const Quad *q) {
    return q->anchorX;
}

void quad_set_anchor_y(Quad *q, float value) {
    q->anchorY = value;
}

float quad_get_anchor_y(const Quad *q) {
    return q->anchorY;
}

void quad_set_color(Quad *q, uint32_t color) {
    q->abgr = color;
}

uint32_t quad_get_color(const Quad *q) {
    return q->abgr;
}

void quad_set_layers(Quad *q, uint8_t value) {
    q->layers = value;
}

uint8_t quad_get_layers(const Quad *q) {
    return q->layers;
}

void quad_set_doublesided(Quad *q, bool toggle) {
    q->doublesided = toggle;
}

bool quad_is_doublesided(const Quad *q) {
    return q->doublesided;
}

void quad_set_shadow(Quad *q, bool toggle) {
    q->shadow = toggle;
}

bool quad_has_shadow(const Quad *q) {
    return q->shadow;
}

void quad_set_unlit(Quad *q, bool value) {
    q->isUnlit = value;
}

bool quad_is_unlit(const Quad *q) {
    return q->isUnlit;
}

// MARK: - Utils -

float quad_utils_get_diagonal(const Quad *q) {
    return sqrtf(q->width * q->width + q->height * q->height);
}
