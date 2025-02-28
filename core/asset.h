// -------------------------------------------------------------
//  Cubzh Core
//  asset.h
//  Created by Corentin Cailleaud on October 25, 2022.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    AssetType_Unknown = 0,
    AssetType_Shape = 1,
    AssetType_Palette = 2,
    AssetType_Object = 4,
    AssetType_Camera = 8,
    AssetType_Light = 16,
    AssetType_Mesh = 32,

    // update when adding a new value
    AssetType_Any = 63,
    AssetType_AnyObject = 61,
} AssetType;
typedef uint8_t ASSET_MASK_T;

typedef struct _Asset {
    AssetType type;
    void *ptr;
} Asset;

#ifdef __cplusplus
} // extern "C"
#endif
