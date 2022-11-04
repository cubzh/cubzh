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

enum AssetType { // mask
    TypeUnknown = 0,
    TypeShape = 1,
    TypePalette = 2,
    TypeObject = 4,
    TypeAll = 7, // update TypeAll when adding a new value
};

typedef struct _Asset {
    enum AssetType type;
    void           *ptr;
} Asset;

#ifdef __cplusplus
} // extern "C"
#endif
