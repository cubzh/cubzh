// -------------------------------------------------------------
//  Cubzh Core
//  instancer.h
//  Created by Arthur Cormerais on December 13, 2023.
// -------------------------------------------------------------

// TODO: one bucket per shader/drawcall to support instancing things like PrivateDrawMode (once it becomes an official feature)
// TODO: hashmap<shape fullname, shape hash> to allow skipping loading entirely

// TODO:
//  - decouple transform <> shape/quad (no direct access to transform) ; everyone manipulates transforms
//  - going from shape ptr -> transform ptr not possible anymore for instanced shapes
//  - shape_is_instanced = transform NULL (no need for a flag)
//  - add shape hash as serialization sub-chunk (first to read)
//  - on deserialize,
//   (1) read shape hash, if none, deserialize full shape and compute hash
//   (2) instancer_check_and_get_shape to get shared shape ptr
//   (3) if ptr NULL, deserialize shape and instancer_register_shape
//   (4) create a transform and instancer_bind_transform
//  - instancer_unbind_transform if needs to break from instancing
//    -> creates a copy of model (shape, quad) and gives it transform ptr
//  - opt back in to instancing w/ instancer_bind_transform
//    -> frees own model ptr
//  - only base shape/quad shader supported, later, can add one bucket per shader (i.e. using PrivateDrawMode breaks instancing)
//  - anything that changes shape hash breaks instancing (changing palette or blocks)
//  - instancer map<shape hash, entry>
//  - instancer entry: transformsLtw[BATCH_SIZE] (packed as 3 floats)
//   -> optionally params array (eg. Quad color)
//   -> when one batch full, create another ; one drawcall per entry
//   -> need a slice mechanic originating from end-of-frame refresh

#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _Instancer Instancer;

typedef struct _Shape Shape;
typedef struct _Quad Quad;
typedef struct _Transform Transform;

Instancer instancer_new(void);
void instancer_free(Instancer *in);
Shape *instancer_check_and_get_shape(Instancer *in, uint64_t hash);
Quad *instancer_check_and_get_quad(Instancer *in);
void instancer_register_shape(Instancer *in, uint64_t hash, Shape *s);
void instancer_register_quad(Instancer *in, Quad *q);
void instancer_bind_transform(Instancer *in, Transform *t);
void instancer_unbind_transform(Instancer *in, Transform *t);

#ifdef __cplusplus
} // extern "C"
#endif
