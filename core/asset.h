//
//  asset.h
//  Particubes
//
//  Created by Corentin Cailleaud on 25/10/2022.
//

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    AssetType_Unknown = 0,
    AssetType_Shape = 1,
    AssetType_Palette = 2,
    AssetType_Object = 4,
    AssetType_Any = 7, // update AssetType_Any when adding a new value
} AssetType; // mask

typedef struct _Asset {
    AssetType type;
    void      *ptr;
} Asset;

#ifdef __cplusplus
} // extern "C"
#endif
