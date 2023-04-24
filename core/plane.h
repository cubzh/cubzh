// -------------------------------------------------------------
//  Cubzh Core
//  plane.h
//  Created by Arthur Cormerais on April 24, 2023.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "float3.h"

typedef struct _Plane Plane;

Plane *plane_new(float x, float y, float z, float d);
Plane *plane_new2(const float3 *n, float d);
Plane *plane_new_from_vectors(const float3 *v1, const float3 *v2, float d);
Plane *plane_new_from_point(const float3 *p, float nx, float ny, float nz);
Plane *plane_new_from_point2(const float3 *p, const float3 *n);
void plane_free(Plane *pl);

float plane_point_distance(const Plane *pl, const float3 *p);
int plane_intersect_point(const Plane *pl, const float3 *p);
int plane_intersect_sphere(const Plane *pl, const float3 *c, float r);

#ifdef __cplusplus
} // extern "C"
#endif
