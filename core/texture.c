// -------------------------------------------------------------
//  Cubzh Core
//  texture.c
//  Created by Arthur Cormerais on February 25, 2025.
// -------------------------------------------------------------

#include "texture.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "cclog.h"

#define TEXTURE_FLAG_NONE 0
#define TEXTURE_FLAG_FILTERING 1
#define TEXTURE_FLAG_TYPE_SHIFT TEXTURE_FLAG_FILTERING
#define TEXTURE_FLAG_TYPE_MASK 6

//// If data isn't NULL and width/height are 0, the texture data must first be parsed
struct _Texture {
    void* data;
    Weakptr *wptr;
    uint32_t size;         /* 4 bytes */
    uint32_t width;        /* 4 bytes */
    uint32_t height;       /* 4 bytes */
    uint32_t hash;         /* 4 bytes */
    uint16_t refCount;     /* 2 bytes */
    uint8_t flags;         /* 1 byte */
    char pad[5];
};

static void _texture_toggle_flag(Texture *t, const uint8_t flag, const bool toggle) {
    if (toggle) {
        t->flags |= flag;
    } else {
        t->flags &= ~flag;
    }
}

static bool _texture_get_flag(const Texture *t, const uint8_t flag) {
    return (t->flags & flag) != 0;
}

Texture* texture_new_raw(const void* data, const uint32_t size, const TextureType type) {
    Texture* t = (Texture*)malloc(sizeof(Texture));
    if (t == NULL) {
        return NULL;
    }

    t->data = malloc(size);
    if (t->data == NULL) {
        free(t);
        return NULL;
    }
    memcpy(t->data, data, size);

    t->wptr = NULL;
    t->size = size;
    t->width = 0;
    t->height = 0;
    t->hash = (uint32_t)crc32(0, data, (uInt)size);
    t->refCount = 1;
    t->flags = (uint8_t)(type << TEXTURE_FLAG_TYPE_SHIFT);
    return t;
}

void texture_free(Texture* t) {
    if (t->data != NULL) {
        free(t->data);
    }
    weakptr_invalidate(t->wptr);
    free(t);
}

bool texture_retain(Texture* t) {
    if (t->refCount < UINT16_MAX) {
        ++(t->refCount);
        return true;
    }
    cclog_error("Texture: maximum refCount reached!");
    return false;
}

void texture_release(Texture* t) {
    if (--(t->refCount) == 0) {
        texture_free(t);
    }
}

void texture_set_parsed_data(Texture* t, const void* data, const uint32_t size, const uint32_t width, const uint32_t height) {
    if (t->data != NULL) {
        free(t->data);
    }
    
    t->data = malloc(size);
    if (t->data != NULL) {
        memcpy(t->data, data, size);
        t->size = size;
        t->width = width;
        t->height = height;
    } else {
        t->size = 0;
        t->width = 0;
        t->height = 0;
    }
}

const void* texture_get_data(const Texture* t) {
    return t->data;
}

uint32_t texture_get_data_size(const Texture* t) {
    return t->size;
}

bool texture_is_raw(const Texture* t) {
    return t->data != NULL && t->width == 0 && t->height == 0;
}

uint32_t texture_get_width(const Texture* t) {
    return t->width;
}

uint32_t texture_get_height(const Texture* t) {
    return t->height;
}

TextureType texture_get_type(const Texture* t) {
    return (TextureType)((t->flags & TEXTURE_FLAG_TYPE_MASK) >> TEXTURE_FLAG_TYPE_SHIFT);
}

uint32_t texture_get_data_hash(const Texture* t) {
    return t->hash;
}

uint32_t texture_get_rendering_hash(const Texture* t) {
    uint32_t hash = t->hash;
    if (_texture_get_flag(t, TEXTURE_FLAG_FILTERING)) {
        hash = (hash * 31) + 1;
    }
    return hash;
}

Weakptr *texture_get_weakptr(Texture *t) {
    if (t->wptr == NULL) {
        t->wptr = weakptr_new(t);
    }
    return t->wptr;
}

Weakptr *texture_get_and_retain_weakptr(Texture *t) {
    if (t->wptr == NULL) {
        t->wptr = weakptr_new(t);
    }
    if (weakptr_retain(t->wptr)) {
        return t->wptr;
    } else { // this can only happen if weakptr ref count is at max
        return NULL;
    }
}

void texture_set_filtering(Texture* t, bool value) {
    _texture_toggle_flag(t, TEXTURE_FLAG_FILTERING, value);
}

bool texture_has_filtering(const Texture* t) {
    return _texture_get_flag(t, TEXTURE_FLAG_FILTERING);
}
