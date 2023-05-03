// -------------------------------------------------------------
//  Cubzh Core
//  plane.c
//  Created by Arthur Cormerais on April 24, 2023.
// -------------------------------------------------------------

#include "plane.h"

#include <stdlib.h>

struct _Plane {
    float3 normal;
    float distance;
};

Plane *plane_new(float x, float y, float z, float d) {
    Plane *pl = (Plane *)malloc(sizeof(Plane));
    pl->normal = (float3){x, y, z};
    pl->distance = d;
    return pl;
}

Plane *plane_new2(const float3 *n, float d) {
    Plane *pl = (Plane *)malloc(sizeof(Plane));
    pl->normal = *n;
    pl->distance = d;
    return pl;
}

Plane *plane_new_from_vectors(const float3 *v1, const float3 *v2, float d) {
    Plane *pl = (Plane *)malloc(sizeof(Plane));
    pl->normal = float3_cross_product3(v1, v2);
    float3_normalize(&pl->normal);
    pl->distance = d;
    return pl;
}

Plane *plane_new_from_point(const float3 *p, float nx, float ny, float nz) {
    Plane *pl = (Plane *)malloc(sizeof(Plane));
    pl->normal = (float3){nx, ny, nz};
    pl->distance = float3_dot_product(p, &pl->normal);
    return pl;
}

Plane *plane_new_from_point2(const float3 *p, const float3 *n) {
    Plane *pl = (Plane *)malloc(sizeof(Plane));
    pl->normal = *n;
    pl->distance = float3_dot_product(p, n);
    return pl;
}

void plane_free(Plane *pl) {
    free(pl);
}

float plane_point_distance(const Plane *pl, const float3 *p) {
    return float3_dot_product(p, &pl->normal) - pl->distance;
}

int plane_intersect_point(const Plane *pl, const float3 *p) {
    const float d = plane_point_distance(pl, p);
    return d > 0 ? 1 : d < 0 ? -1 : 0;
}

int plane_intersect_sphere(const Plane *pl, const float3 *c, float r) {
    const float d = plane_point_distance(pl, c);
    return d > r ? 1 : d < -r ? -1 : 0;
}
