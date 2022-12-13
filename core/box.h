// -------------------------------------------------------------
//  Cubzh Core
//  box.h
//  Created by Adrien Duermael on June 5, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "config.h"
#include "float3.h"
#include "int3.h"
#include "quaternion.h"

// A box represents a simple box with 2 vectors for min and max corners
typedef struct {
    float3 min;
    float3 max;
} Box;

static const Box box_zero = {{0.0f, 0.0f, 0.0f}, {0.0f, 0.0f, 0.0f}};
static const Box box_one = {{0.0f, 0.0f, 0.0f}, {1.0f, 1.0f, 1.0f}};

Box *box_new(void);

Box *box_new_2(const float minX,
               const float minY,
               const float minZ,
               const float maxX,
               const float maxY,
               const float maxZ);

Box *box_new_copy(const Box *src);

void box_free(Box *b);

void box_set_bottom_center_position(Box *b, const float3 *position);

void box_get_center(const Box *b, float3 *center);

void box_copy(Box *dest, const Box *src);

// Returns true when 2 boxes collide, equivalent to box_collide_epsilon(b1, b2, -EPSILON_COLLISION)
bool box_collide(const Box *b1, const Box *b2);

bool box_collide_epsilon(const Box *b1, const Box *b2, const float epsilon);

// Returns true if box contains point
bool box_contains(const Box *b, const float3 *f3);

bool box_contains_epsilon(const Box *b, const float3 *f3, float epsilon);

void box_set_broadphase_box(const Box *b, const float3 *v, Box *bpBox);

// Returns a value between 0 and 1 that indicates the point of collision along the trajectory
// of movingBox w/ a given speed against staticBox
// If returned value == 1, it means no collision
// If returned value == 0, it means both boxes were already in contact
// Returned value can be negative for replacements, if parameter 'withReplacement' is true
float box_swept(const Box *movingBox,
                const float3 *dv,
                const Box *staticBox,
                const bool withReplacement,
                float3 *normal,
                float3 *extraReplacement,
                const float epsilon);

void box_get_size_int(const Box *b, int3 *i3);

void box_get_size_float(const Box *b, float3 *f3);

bool box_is_empty(const Box *b);

typedef enum {
    NoSquarify,
    MinSquarify,
    MaxSquarify
} SquarifyType;

void box_squarify(Box *b, SquarifyType squarify);

void box_to_aabox_no_rot(const Box *b,
                         Box *aab,
                         const float3 *translation,
                         const float3 *offset,
                         const float3 *scale,
                         SquarifyType squarify);

void box_to_aabox(const Box *b,
                  Box *aab,
                  const float3 *translation,
                  const float3 *offset,
                  Quaternion *rotation,
                  const float3 *scale,
                  SquarifyType squarify);

void box_to_aabox2(const Box *b,
                   Box *aab,
                   const Matrix4x4 *mtx,
                   const float3 *offset,
                   SquarifyType squarify);

void box_op_merge(const Box *b1, const Box *b2, Box *result);

float box_get_volume(const Box *b);

#ifdef __cplusplus
} // extern "C"
#endif
