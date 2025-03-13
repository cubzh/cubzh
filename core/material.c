// -------------------------------------------------------------
//  Cubzh Core
//  material.c
//  Created by Arthur Cormerais on February 3, 2025.
// -------------------------------------------------------------

#include "material.h"

#include <stdlib.h>
#include <string.h>

#include "utils.h"
#include "texture.h"

#define MATERIAL_FLAG_NONE 0
#define MATERIAL_FLAG_OPAQUE 1
#define MATERIAL_FLAG_DOUBLESIDED 2
#define MATERIAL_FLAG_UNLIT 4

struct _Material {
    Texture* textures[MaterialTexture_Count];
    uint32_t albedo;        /* 4 bytes */
    uint32_t emissive;      /* 4 bytes */
    float metallic;         /* 4 bytes */
    float roughness;        /* 4 bytes */
    float alphaCutout;      /* 4 bytes */
    uint16_t refCount;      /* 2 bytes */
    uint8_t flags;          /* 1 byte */
};

static void _material_toggle_flag(Material *m, const uint8_t flag, const bool toggle) {
    if (toggle) {
        m->flags |= flag;
    } else {
        m->flags &= ~flag;
    }
}

static bool _material_get_flag(const Material *m, const uint8_t flag) {
    return (m->flags & flag) != 0;
}

Material* material_new(void) {
    Material* m = (Material*)malloc(sizeof(Material));
    m->albedo = 0xFFFFFFFF;
    m->emissive = 0x00000000;
    m->metallic = 0.0f;
    m->roughness = 0.0f;
    m->alphaCutout = 0.5f;
    m->refCount = 1;
    m->flags = MATERIAL_FLAG_OPAQUE;
    memset(m->textures, 0, MaterialTexture_Count * sizeof(Texture*));
    return m;
}

void material_free(Material* m) {
    for (int i = 0; i < MaterialTexture_Count; ++i) {
        if (m->textures[i] != NULL) {
            texture_release(m->textures[i]);
        }
    }
    free(m);
}

bool material_retain(Material* m) {
    if (m->refCount < UINT16_MAX) {
        ++(m->refCount);
        return true;
    }
    cclog_error("Material: maximum refCount reached!");
    return false;
}

void material_release(Material* m) {
    if (--(m->refCount) == 0) {
        material_free(m);
    }
}

void material_set_albedo(Material* m, const uint32_t rgba) {
    m->albedo = rgba;
}

uint32_t material_get_albedo(const Material* m) {
    return m->albedo;
}

void material_set_metallic(Material* m, const float value) {
    m->metallic = value;
}

float material_get_metallic(const Material* m) {
    return m->metallic;
}

void material_set_roughness(Material* m, const float value) {
    m->roughness = value;
}

float material_get_roughness(const Material* m) {
    return m->roughness;
}

void material_set_emissive(Material* m, const uint32_t rgb) {
    m->emissive = rgb & 0x00FFFFFF; // force alpha to 0 (unused, make packing easier)
}

uint32_t material_get_emissive(const Material* m) {
    return m->emissive;
}

void material_set_alpha_cutout(Material* m, const float value) {
    m->alphaCutout = value;
}

float material_get_alpha_cutout(const Material* m) {
    return m->alphaCutout;
}

void material_set_opaque(Material* m, const bool value) {
    _material_toggle_flag(m, MATERIAL_FLAG_OPAQUE, value);
}

bool material_is_opaque(const Material* m) {
    return _material_get_flag(m, MATERIAL_FLAG_OPAQUE);
}

void material_set_double_sided(Material* m, const bool value) {
    _material_toggle_flag(m, MATERIAL_FLAG_DOUBLESIDED, value);
}

bool material_is_double_sided(const Material* m) {
    return _material_get_flag(m, MATERIAL_FLAG_DOUBLESIDED);
}

void material_set_unlit(Material* m, const bool value) {
    _material_toggle_flag(m, MATERIAL_FLAG_UNLIT, value);
}

bool material_is_unlit(const Material* m) {
    return _material_get_flag(m, MATERIAL_FLAG_UNLIT);
}

void material_set_texture(Material* m, MaterialTexture slot, Texture* texture) {
    if (m->textures[slot] != NULL) {
        texture_release(m->textures[slot]);
    }
    m->textures[slot] = texture;
    if (texture != NULL) {
        texture_retain(texture);
    }
}

Texture* material_get_texture(const Material* m, MaterialTexture slot) {
    return m->textures[slot];
}

void material_set_filtering(Material* m, const bool value) {
    for (uint8_t i = 0; i < MaterialTexture_Count; ++i) {
        if (m->textures[i] != NULL && texture_get_type(m->textures[i]) != TextureType_Normal) {
            texture_set_filtering(m->textures[i], value);
        }
    }
}

bool material_has_filtering(const Material* m) {
    for (uint8_t i = 0; i < MaterialTexture_Count; ++i) {
        if (m->textures[i] != NULL && texture_has_filtering(m->textures[i])) {
            return true;
        }
    }
    return false;
}