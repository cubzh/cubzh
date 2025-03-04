// -------------------------------------------------------------
//  Cubzh Core
//  serialization_gltf.h
//  Created by Arthur Cormerais on December 30, 2024.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>
#include <stdbool.h>

#include "asset.h"
#include "doubly_linked_list.h"

typedef struct _Transform Transform;
typedef struct _Stream Stream;
typedef struct _ShapeSettings ShapeSettings;

/// @param buffer not freed by this function
/// @param filter only requested asset type will be allocated
/// @param out must be a NULL pointer
/// @returns true if successfully loaded, false if format error
bool serialization_gltf_load(const void *buffer, const size_t size, const ASSET_MASK_T filter, DoublyLinkedList **out);

#ifdef __cplusplus
} // extern "C"
#endif
