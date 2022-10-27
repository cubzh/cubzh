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
    TypeMutableShape = 4, // if Shape and MutableShape are in the mask, return Shape
    TypeAll = 7, // update TypeAll when adding a new value
};

typedef struct _Resource {
    enum ResourceType type;
    void              *ptr;
} Resource;

#ifdef __cplusplus
} // extern "C"
#endif
