// -------------------------------------------------------------
//  Cubzh Core
//  ray.h
//  Created by Adrien Duermael on April 24, 2016.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "box.h"
#include "config.h"
#include "float3.h"
#include "int3.h"

typedef struct Ray {
    float3 *origin;
    float3 *dir;
    float3 *invdir;
} Ray;

typedef struct _Transform Transform;

Ray *ray_new(const float3 *origin, const float3 *dir);
Ray *ray_new_copy(const Ray *src);
void ray_free(Ray *ray);
void ray_copy(Ray *dst, const Ray *src);

// ray_intersect_with_box returns if given ray intersects with box
// identified by ldf and rtb corners.
// ldf: left-down-front
// rtb: right-top-back
// distance can be NULL
bool ray_intersect_with_box(const Ray *ray, const float3 *ldf, const float3 *rtb, float *distance);

void ray_impact_point(const Ray *ray, const float impactDistance, float3 *f3);

/// /!\ Assumption in this function: impact & ldf are points in the same space as the block, so that
/// we don't need to compute everything eg. we know the planes normal in a 1-block, no need to use
/// cross products to get them
/// @returns block face touched by impact point
FACE_INDEX_INT_T ray_impacted_block_face(const float3 *impact, const float3 *ldf);

Ray *ray_world_to_local(const Ray *ray, Transform *t);

#ifdef __cplusplus
} // extern "C"
#endif
