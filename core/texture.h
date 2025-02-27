// -------------------------------------------------------------
//  Cubzh Core
//  texture.h
//  Created by Arthur Cormerais on February 25, 2025.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

#include "weakptr.h"

typedef enum {
    TextureType_None,
    TextureType_Albedo,
    TextureType_Normal,
    TextureType_Metallic,
    TextureType_Emissive
} TextureType;

typedef struct _Texture Texture;

Texture* texture_new_raw(const void* data, const size_t size, const TextureType type);
void texture_free(Texture* t);
bool texture_retain(Texture* t);
void texture_release(Texture* t);

void texture_set_parsed_data(Texture* t, const void* data, const size_t size, const uint32_t width, const uint32_t height);
const void* texture_get_data(const Texture* t);
uint32_t texture_get_data_size(const Texture* t);
bool texture_is_raw(const Texture* t);
uint32_t texture_get_width(const Texture* t);
uint32_t texture_get_height(const Texture* t);
TextureType texture_get_type(const Texture* t);
uint32_t texture_get_hash(const Texture* t);
Weakptr *texture_get_weakptr(Texture *t);
Weakptr *texture_get_and_retain_weakptr(Texture *t);

#ifdef __cplusplus
}
#endif 