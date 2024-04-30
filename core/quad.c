// -------------------------------------------------------------
//  Cubzh Core
//  quad.c
//  Created by Arthur Cormerais on May 3, 2023.
// -------------------------------------------------------------

#include "quad.h"

#include <stdlib.h>
#include <string.h>

#define QUAD_FLAG_NONE 0
#define QUAD_FLAG_DOUBLESIDED 1
#define QUAD_FLAG_SHADOW 2
#define QUAD_FLAG_UNLIT 4
#define QUAD_FLAG_DATA_DIRTY 8
#define QUAD_FLAG_MASK 16

struct _Quad {
    Transform *transform;
    void *data;
    size_t size;            /* 8 bytes */
    float width, height;    /* 2x4 bytes */
    float anchorX, anchorY; /* 2x4 bytes */
    float tilingU, tilingV; /* 2x4 bytes */
    float offsetU, offsetV; /* 2x4 bytes */
    uint32_t abgr;          /* 4 bytes */
    uint16_t layers;        /* 2 bytes */
    uint8_t flags;          /* 1 byte */
    uint8_t sortOrder;      /* 1 byte */

    // no padding
};

void _quad_toggle_flag(Quad *q, uint8_t flag, bool toggle) {
    if (toggle) {
        q->flags |= flag;
    } else {
        q->flags &= ~flag;
    }
}

bool _quad_get_flag(const Quad *q, uint8_t flag) {
    return (q->flags & flag) != 0;
}

void _quad_void_free(void *o) {
    Quad *q = (Quad *)o;
    quad_free(q);
}

Quad *quad_new(void) {
    Quad *q = (Quad *)malloc(sizeof(Quad));
    q->transform = transform_make_with_ptr(QuadTransform, q, &_quad_void_free);
    q->data = NULL;
    q->size = 0;
    q->width = 1.0f;
    q->height = 1.0f;
    q->anchorX = 0.0f;
    q->anchorY = 0.0f;
    q->tilingU = 1.0f;
    q->tilingV = 1.0f;
    q->offsetU = 0.0f;
    q->offsetV = 0.0f;
    q->abgr = 0xffffffff;
    q->layers = 1; // CAMERA_LAYERS_DEFAULT
    q->flags = QUAD_FLAG_DOUBLESIDED;
    q->sortOrder = 0;
    return q;
}

void quad_release(Quad *q) {
    transform_release(q->transform);
}

void quad_free(Quad *q) {
    if (q->data != NULL) {
        free(q->data);
    }
    free(q);
}

Transform *quad_get_transform(const Quad *q) {
    return q->transform;
}

void quad_copy_data(Quad *q, const void *data, size_t size) {
    if (q->data != NULL) {
        free(q->data);
    }
    if (data != NULL && size > 0) {
        q->data = malloc(size);
        memcpy(q->data, data, size);
        q->size = size;
    } else {
        q->data = NULL;
        q->size = 0;
    }
    _quad_toggle_flag(q, QUAD_FLAG_DATA_DIRTY, true);
}

void *quad_get_data(const Quad *q) {
    return q->data;
}

size_t quad_get_data_size(const Quad *q) {
    return q->size;
}

void quad_reset_data_dirty(Quad *q) {
    _quad_toggle_flag(q, QUAD_FLAG_DATA_DIRTY, false);
}

bool quad_is_data_dirty(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_DATA_DIRTY);
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

void quad_set_tiling_u(Quad *q, float value) {
    q->tilingU = value;
}

float quad_get_tiling_u(const Quad *q) {
    return q->tilingU;
}

void quad_set_tiling_v(Quad *q, float value) {
    q->tilingV = value;
}

float quad_get_tiling_v(const Quad *q) {
    return q->tilingV;
}

void quad_set_offset_u(Quad *q, float value) {
    q->offsetU = value;
}

float quad_get_offset_u(const Quad *q) {
    return q->offsetU;
}

void quad_set_offset_v(Quad *q, float value) {
    q->offsetV = value;
}

float quad_get_offset_v(const Quad *q) {
    return q->offsetV;
}

void quad_set_color(Quad *q, uint32_t color) {
    q->abgr = color;
}

uint32_t quad_get_color(const Quad *q) {
    return q->abgr;
}

void quad_set_layers(Quad *q, uint16_t value) {
    q->layers = value;
}

uint16_t quad_get_layers(const Quad *q) {
    return q->layers;
}

void quad_set_doublesided(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_DOUBLESIDED, toggle);
}

bool quad_is_doublesided(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_DOUBLESIDED);
}

void quad_set_shadow(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_SHADOW, toggle);
}

bool quad_has_shadow(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_SHADOW);
}

void quad_set_unlit(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_UNLIT, toggle);
}

bool quad_is_unlit(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_UNLIT);
}

void quad_set_mask(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_MASK, toggle);
}

bool quad_is_mask(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_MASK);
}

void quad_set_sort_order(Quad *q, uint8_t value) {
    q->sortOrder = value;
}

uint8_t quad_get_sort_order(const Quad *q) {
    return q->sortOrder;
}

// MARK: - Utils -

float quad_utils_get_diagonal(const Quad *q) {
    return sqrtf(q->width * q->width + q->height * q->height);
}
