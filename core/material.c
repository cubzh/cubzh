// -------------------------------------------------------------
//  Cubzh Core
//  material.c
//  Created by Arthur Cormerais on February 3, 2025.
// -------------------------------------------------------------

#include "material.h"

#include <stdlib.h>
#include <string.h>

#include "utils.h"

#define MATERIAL_FLAG_NONE 0
#define MATERIAL_FLAG_OPAQUE 1
#define MATERIAL_FLAG_DOUBLESIDED 2
#define MATERIAL_FLAG_UNLIT 4

struct _Material {
    uint32_t diffuse;       /* 4 bytes */
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
    m->diffuse = 0xFFFFFFFF;
    m->emissive = 0x00000000;
    m->metallic = 0.0f;
    m->roughness = 0.0f;
    m->alphaCutout = 0.5f;
    m->refCount = 1;
    m->flags = MATERIAL_FLAG_OPAQUE;
    return m;
}

void material_free(Material* m) {
    free(m);
}

bool material_retain(const Material* m) {
    Material* mat = (Material*)m;
    if (mat->refCount < UINT16_MAX) {
        ++(mat->refCount);
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

void material_set_diffuse(Material* m, const uint32_t rgba) {
    m->diffuse = rgba;
}

uint32_t material_get_diffuse(const Material* m) {
    return m->diffuse;
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