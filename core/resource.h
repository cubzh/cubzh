//
//  resource.h
//  Particubes
//
//  Created by Corentin Cailleaud on 25/10/2022.
//

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum ResourceType { // mask
    TypeUnknown = 0,
    TypeShape = 1,
    TypePalette = 2,
    TypeAll = 3, // update TypeAll when adding a new value
};

typedef struct _Resource {
    enum ResourceType type;
    void              *ptr;
} Resource;

#ifdef __cplusplus
} // extern "C"
#endif
