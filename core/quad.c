// -------------------------------------------------------------
//  Cubzh Core
//  quad.c
//  Created by Arthur Cormerais on May 3, 2023.
// -------------------------------------------------------------

#include "quad.h"

#include <stdlib.h>
#include <string.h>

#include "zlib.h"

#define QUAD_FLAG_NONE 0
#define QUAD_FLAG_DOUBLESIDED 1
#define QUAD_FLAG_SHADOW 2
#define QUAD_FLAG_UNLIT 4
#define QUAD_FLAG_MASK 8
#define QUAD_FLAG_ALPHA 16
#define QUAD_FLAG_VCOLOR 32
#define QUAD_FLAG_9SLICE 64

struct _Quad {
    Transform *transform;
    uint32_t *rgba;
    void *data;
    uint32_t size;          /* 4 bytes */
    float width, height;    /* 2x4 bytes */
    float anchorX, anchorY; /* 2x4 bytes */
    float tilingU, tilingV; /* 2x4 bytes */
    float offsetU, offsetV; /* 2x4 bytes */
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
    q->layers = 1; // CAMERA_LAYERS_DEFAULT
    q->flags = QUAD_FLAG_DOUBLESIDED;
    q->sortOrder = 0;

    q->rgba = (uint32_t *)malloc(sizeof(uint32_t));
    *q->rgba = 0xffffffff;

    return q;
}

void quad_release(Quad *q) {
    transform_release(q->transform);
}

void quad_free(Quad *q) {
    if (q->data != NULL) {
        free(q->data);
    }
    free(q->rgba);
    free(q);
}

Transform *quad_get_transform(const Quad *q) {
    return q->transform;
}

void quad_copy_data(Quad *q, const void *data, uint32_t size) {
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
}

void *quad_get_data(const Quad *q) {
    return q->data;
}

uint32_t quad_get_data_size(const Quad *q) {
    return q->size;
}

uint32_t quad_get_data_hash(const Quad *q) {
    return (uint32_t)crc32(0, q->data, (uInt)q->size);
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
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->tilingU = value;
    }
}

float quad_get_tiling_u(const Quad *q) {
    return q->tilingU;
}

void quad_set_tiling_v(Quad *q, float value) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->tilingV = value;
    }
}

float quad_get_tiling_v(const Quad *q) {
    return q->tilingV;
}

void quad_set_offset_u(Quad *q, float value) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->offsetU = value;
    }
}

float quad_get_offset_u(const Quad *q) {
    return q->offsetU;
}

void quad_set_offset_v(Quad *q, float value) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->offsetV = value;
    }
}

float quad_get_offset_v(const Quad *q) {
    return q->offsetV;
}

void quad_set_color(Quad *q, uint32_t color) {
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR)) {
        q->rgba[0] = q->rgba[1] = q->rgba[2] = q->rgba[3] = color;
    } else {
        *q->rgba = color;
    }
}

uint32_t quad_get_color(const Quad *q) {
    return *q->rgba;
}

void quad_set_vertex_color(Quad *q, uint32_t c, uint8_t idx) {
    if (idx > 3) {
        return;
    }
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR) == false) {
        const uint32_t color = *q->rgba;
        free(q->rgba);
        q->rgba = (uint32_t *)malloc(4 * sizeof(uint32_t));
        for (uint8_t i = 0; i < 3; ++i) {
            q->rgba[i] = color;
        }
        _quad_toggle_flag(q, QUAD_FLAG_VCOLOR, true);
    }
    q->rgba[idx] = c;
}

uint32_t quad_get_vertex_color(const Quad *q, uint8_t idx) {
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR) == false) {
        return q->rgba[0];
    } else {
        return idx <= 3 ? q->rgba[idx] : 0x00000000;
    }
}

bool quad_uses_vertex_colors(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_VCOLOR);
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

void quad_set_alpha(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_ALPHA, toggle);
}

bool quad_uses_alpha(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_ALPHA);
}

void quad_set_sort_order(Quad *q, uint8_t value) {
    q->sortOrder = value;
}

uint8_t quad_get_sort_order(const Quad *q) {
    return q->sortOrder;
}

void quad_set_9slice(Quad *q, bool toggle) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false && toggle) {
        q->tilingU = q->tilingV = 0.5f;
        q->offsetU = 1.0f;
    }
    _quad_toggle_flag(q, QUAD_FLAG_9SLICE, toggle);
}

bool quad_uses_9slice(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_9SLICE);
}

void quad_set_9slice_uv(Quad *q, float u, float v) {
    q->tilingU = u;
    q->tilingV = v;
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->offsetU = 1.0f;
    }
    _quad_toggle_flag(q, QUAD_FLAG_9SLICE, true);
}

float quad_get_9slice_u(const Quad *q) {
    return q->tilingU;
}

float quad_get_9slice_v(const Quad *q) {
    return q->tilingV;
}

void quad_set_9slice_scale(Quad *q, float value) {
    q->offsetU = value;
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->tilingU = q->tilingV = 0.5f;
    }
    _quad_toggle_flag(q, QUAD_FLAG_9SLICE, true);
}

float quad_get_9slice_scale(const Quad *q) {
    return q->offsetU;
}

// MARK: - Utils -

float quad_utils_get_diagonal(const Quad *q) {
    return sqrtf(q->width * q->width + q->height * q->height);
}

bool quad_utils_get_visibility(const Quad *q, bool *isOpaque) {
    const bool transparentTex = q->size > 0 && _quad_get_flag(q, QUAD_FLAG_ALPHA);
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR)) {
        const uint16_t alpha = (uint16_t)(q->rgba[0] >> 24) + (uint16_t)(q->rgba[1] >> 24) +
                               (uint16_t)(q->rgba[2] >> 24) + (uint16_t)(q->rgba[3] >> 24);
        *isOpaque = transparentTex == false && alpha == 1020;
        return alpha > 0;
    } else {
        const uint8_t alpha = (uint8_t)(*q->rgba >> 24);
        *isOpaque = transparentTex == false && alpha == 255;
        return alpha > 0;
    }
}
