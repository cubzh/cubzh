// -------------------------------------------------------------
//  Cubzh Core
//  ray.c
//  Created by Adrien Duermael on April 24, 2016.
// -------------------------------------------------------------

#include "ray.h"

#include <math.h>
#include <stdlib.h>

#include "transform.h"
#include "utils.h"

enum DrivingAxis {
    XDrivingAxis = 0,
    YDrivingAxis = 1,
    ZDrivingAxis = 2
};

struct _BresenhamIterator {
    int3 start;
    int3 end;
    int3 last;
    int3 d;
    int3 s;
    int p1;
    int p2;
    enum DrivingAxis drivingAxis;
};

Ray *ray_new(const float3 *origin, const float3 *dir) {
    Ray *ray = (Ray *)malloc(sizeof(Ray));

    ray->origin = float3_new_copy(origin);

    // direction vector may have been provided unnormalized
    ray->dir = float3_new_copy(dir);
    float3_normalize(ray->dir);

    ray->invdir = float3_new(1.0f / ray->dir->x, 1.0f / ray->dir->y, 1.0f / ray->dir->z);

    return ray;
}

// frd 200218
#ifndef max
float max(float a, float b) {
    return a > b ? a : b;
}
#endif

// frd 200218
#ifndef min
float min(float a, float b) {
    return a < b ? a : b;
}
#endif

bool ray_intersect_with_box(const Ray *ray, const float3 *ldf, const float3 *rtb, float *distance) {

    // Rays w/ world unit vectors are fairly common and so ray->invdir is often infinity ;
    // so this calculation has a singularity if the dividend is zero (0 x infinity = nan)
    float t1 = float_isEqual(ldf->x, ray->origin->x, EPSILON_ZERO)
                   ? 0.0f
                   : (ldf->x - ray->origin->x) * ray->invdir->x;
    float t2 = float_isEqual(rtb->x, ray->origin->x, EPSILON_ZERO)
                   ? 0.0f
                   : (rtb->x - ray->origin->x) * ray->invdir->x;
    float t3 = float_isEqual(ldf->y, ray->origin->y, EPSILON_ZERO)
                   ? 0.0f
                   : (ldf->y - ray->origin->y) * ray->invdir->y;
    float t4 = float_isEqual(rtb->y, ray->origin->y, EPSILON_ZERO)
                   ? 0.0f
                   : (rtb->y - ray->origin->y) * ray->invdir->y;
    float t5 = float_isEqual(ldf->z, ray->origin->z, EPSILON_ZERO)
                   ? 0.0f
                   : (ldf->z - ray->origin->z) * ray->invdir->z;
    float t6 = float_isEqual(rtb->z, ray->origin->z, EPSILON_ZERO)
                   ? 0.0f
                   : (rtb->z - ray->origin->z) * ray->invdir->z;

    const float tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    const float tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6));

    if (tmax < 0)
        return false;
    if (tmin > tmax)
        return false;

    if (distance != NULL) {
        *distance = tmin;
    }

    return true;
}

// returns impact point using impact distance
void ray_impact_point(const Ray *ray, const float impactDistance, float3 *f3) {
    if (f3 == NULL) {
        return;
    }

    float3_set(f3,
               ray->origin->x + ray->dir->x * impactDistance,
               ray->origin->y + ray->dir->y * impactDistance,
               ray->origin->z + ray->dir->z * impactDistance);
}

bool _ray_impacted_face_check_plane(const float3 *normal, const float d, const float3 *point) {
    return normal->x * point->x + normal->y * point->y + normal->z * point->z + d > 0;
}

FACE_INDEX_INT_T ray_impacted_block_face(const float3 *impact, const float3 *ldf) {
#if PHYSICS_IMPACT_FACE_MODE == 0
    if (float_isEqual(impact->x, ldf->x, EPSILON_COLLISION))
        return FACE_LEFT;
    if (float_isEqual(impact->x, ldf->x + 1.0f, EPSILON_COLLISION))
        return FACE_RIGHT;
    if (float_isEqual(impact->z, ldf->z, EPSILON_COLLISION))
        return FACE_BACK;
    if (float_isEqual(impact->z, ldf->z + 1.0f, EPSILON_COLLISION))
        return FACE_FRONT;
    if (float_isEqual(impact->y, ldf->y, EPSILON_COLLISION))
        return FACE_DOWN;
    if (float_isEqual(impact->y, ldf->y + 1.0f, EPSILON_COLLISION))
        return FACE_TOP;

    return FACE_NONE;
#elif PHYSICS_IMPACT_FACE_MODE == 1
    // The idea here is to divide the space in 6 frustums from center of cube to each face,
    // then determine in which one the given point is, checking up to 4 planes

    const float3 center = {ldf->x + .5f, ldf->y + .5f, ldf->z + .5f};
    float3 _impact = *impact, n;
    float3_op_substract(&_impact, &center);

    // (1) check plane crossing center, ldf, and ltf which normal is (0.5, 0.0, -0.5)
    float3_set(&n, 0.5f, 0.0f, -0.5f);

    if (float3_dot_product(&n, &_impact) >
        0) { // could be FACE_BACK, FACE_RIGHT, or FACE_TOP/FACE_DOWN
        // (2) check plane crossing center, rdf, and rtf which normal is (0.5, 0.0, 0.5)
        float3_set(&n, 0.5f, 0.0f, 0.5f);

        if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_RIGHT, or FACE_TOP/FACE_DOWN
            // (3) check plane crossing center, rdf, and rdb which normal is (-0.5, -0.5, 0.0)
            float3_set(&n, -0.5f, -0.5f, 0.0f);

            if (float3_dot_product(&n, &_impact) > 0) {
                return FACE_DOWN;
            } else { // could be FACE_RIGHT or FACE_TOP
                // (4) check plane crossing center, rtf, and rtb which normal is (0.5, -0.5, 0.0)
                float3_set(&n, 0.5f, -0.5f, 0.0f);

                if (float3_dot_product(&n, &_impact) > 0) {
                    return FACE_RIGHT;
                } else {
                    return FACE_TOP;
                }
            }
        } else { // could be FACE_BACK, or FACE_TOP/FACE_DOWN
            // (3) check plane crossing center, ldf, and rdf which normal is (0.0, -0.5, 0.5)
            float3_set(&n, 0.0f, -0.5f, 0.5f);

            if (float3_dot_product(&n, &_impact) > 0) {
                return FACE_DOWN;
            } else { // could be FACE_BACK or FACE_TOP
                // (4) check plane crossing center, ltf, and rtf which normal is (0.0, -0.5, -0.5)
                float3_set(&n, 0.0f, -0.5f, -0.5f);

                if (float3_dot_product(&n, &_impact) > 0) {
                    return FACE_BACK;
                } else {
                    return FACE_TOP;
                }
            }
        }
    } else { // could be FACE_FRONT, FACE_LEFT, or FACE_TOP/FACE_DOWN
        // (2) check plane crossing center, ldb, and ltb which normal is (-0.5, 0.0, -0.5)
        float3_set(&n, -0.5f, 0.0f, -0.5f);

        if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_LEFT, or FACE_TOP/FACE_DOWN
            // (3) check plane crossing center, ldb, and ldf which normal is (0.5, -0.5, 0.0)
            float3_set(&n, 0.5f, -0.5f, 0.0f);

            if (float3_dot_product(&n, &_impact) > 0) {
                return FACE_DOWN;
            } else { // could be FACE_LEFT or FACE_TOP
                // (4) check plane crossing center, ltb, and ltf which normal is (-0.5, -0.5, 0.0)
                float3_set(&n, -0.5f, -0.5f, 0.0f);

                if (float3_dot_product(&n, &_impact) > 0) {
                    return FACE_LEFT;
                } else {
                    return FACE_TOP;
                }
            }
        } else { // could be FACE_FRONT, or FACE_TOP/FACE_DOWN
            // (3) check plane crossing center, rdb, and ldb which normal is (0.0, -0.5, -0.5)
            float3_set(&n, 0.0f, -0.5f, -0.5f);

            if (float3_dot_product(&n, &_impact) > 0) {
                return FACE_DOWN;
            } else { // could be FACE_FRONT or FACE_TOP
                // (4) check plane crossing center, rtb, and ltb which normal is (0.0, -0.5, 0.5)
                float3_set(&n, 0.0f, -0.5f, 0.5f);

                if (float3_dot_product(&n, &_impact) > 0) {
                    return FACE_FRONT;
                } else {
                    return FACE_TOP;
                }
            }
        }
    }
#elif PHYSICS_IMPACT_FACE_MODE == 2
    // The idea here is to divide the space like in the above method (1), but we narrow it down
    // to 3 sub-frustums (2 planes check) by first checking in which corner of the space around
    // center the point is
    // More verbose than method (1) but more performant

    const float3 center = {ldf->x + .5f, ldf->y + .5f, ldf->z + .5f};
    float3 _impact = *impact, n;
    float3_op_substract(&_impact, &center);

    if (impact->x < center.x) {
        if (impact->y < center.y) {
            if (impact->z < center.z) { // could be FACE_LEFT, FACE_DOWN, or FACE_BACK
                // (1) check plane crossing center, ldf, and ltf which normal is (0.5, 0.0, -0.5)
                float3_set(&n, 0.5f, 0.0f, -0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_DOWN or FACE_BACK
                    // (2) check plane crossing center, ldf, and rdf which normal is (0.0, -0.5,
                    // 0.5)
                    float3_set(&n, 0.0f, -0.5f, 0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_BACK;
                    }
                } else { // could be FACE_LEFT or FACE_DOWN
                    // (2) check plane crossing center, ldb, and ldf which normal is (0.5, -0.5,
                    // 0.0)
                    float3_set(&n, 0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_LEFT;
                    }
                }
            } else { // could be FACE_LEFT, FACE_DOWN, or FACE_FRONT
                // (1) check plane crossing center, ldb, and ltb which normal is (-0.5, 0.0, -0.5)
                float3_set(&n, -0.5f, 0.0f, -0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_LEFT or FACE_DOWN
                    // (2) check plane crossing center, ldb, and ldf which normal is (0.5, -0.5,
                    // 0.0)
                    float3_set(&n, 0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_LEFT;
                    }
                } else { // could be FACE_DOWN or FACE_FRONT
                    // (2) check plane crossing center, rdb, and ldb which normal is (0.0, -0.5,
                    // -0.5)
                    float3_set(&n, 0.0f, -0.5f, -0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_FRONT;
                    }
                }
            }
        } else {
            if (impact->z < center.z) { // could be FACE_LEFT, FACE_TOP, or FACE_BACK
                // (1) check plane crossing center, ldf, and ltf which normal is (0.5, 0.0, -0.5)
                float3_set(&n, 0.5f, 0.0f, -0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_TOP or FACE_BACK
                    // (2) check plane crossing center, ltf, and rtf which normal is (0.0, -0.5,
                    // -0.5)
                    float3_set(&n, 0.0f, -0.5f, -0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_BACK;
                    } else {
                        return FACE_TOP;
                    }
                } else { // could be FACE_LEFT or FACE_TOP
                    // (2) check plane crossing center, ltb, and ltf which normal is (-0.5, -0.5,
                    // 0.0)
                    float3_set(&n, -0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_LEFT;
                    } else {
                        return FACE_TOP;
                    }
                }
            } else { // could be FACE_LEFT, FACE_TOP, or FACE_FRONT
                // (1) check plane crossing center, ldb, and ltb which normal is (-0.5, 0.0, -0.5)
                float3_set(&n, -0.5f, 0.0f, -0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_lEFT or FACE_TOP
                    // (2) check plane crossing center, ltb, and ltf which normal is (-0.5, -0.5,
                    // 0.0)
                    float3_set(&n, -0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_LEFT;
                    } else {
                        return FACE_TOP;
                    }
                } else { // could be FACE_TOP or FACE_FRONT
                    // (2) check plane crossing center, rtb, and ltb which normal is (0.0, -0.5,
                    // 0.5)
                    float3_set(&n, 0.0f, -0.5f, 0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_FRONT;
                    } else {
                        return FACE_TOP;
                    }
                }
            }
        }
    } else {
        if (impact->y < center.y) {
            if (impact->z < center.z) { // could be FACE_RIGHT, FACE_DOWN, or FACE_BACK
                // (1) check plane crossing center, rdf, and rtf which normal is (0.5, 0.0, 0.5)
                float3_set(&n, 0.5f, 0.0f, 0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_RIGHT or FACE_DOWN
                    // (2) check plane crossing center, rdf, and rdb which normal is (-0.5, -0.5,
                    // 0.0)
                    float3_set(&n, -0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_RIGHT;
                    }
                } else { // could be FACE_DOWN or FACE_BACK
                    // (2) check plane crossing center, ldf, and rdf which normal is (0.0, -0.5,
                    // 0.5)
                    float3_set(&n, 0.0f, -0.5f, 0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_BACK;
                    }
                }
            } else { // could be FACE_RIGHT, FACE_DOWN, or FACE_FRONT
                // (1) check plane crossing center, ldf, and ltf which normal is (0.5, 0.0, -0.5)
                float3_set(&n, 0.5f, 0.0f, -0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_RIGHT or FACE_DOWN
                    // (2) check plane crossing center, rdf, and rdb which normal is (-0.5, -0.5,
                    // 0.0)
                    float3_set(&n, -0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_RIGHT;
                    }
                } else { // could be FACE_DOWN or FACE_FRONT
                    // (2) check plane crossing center, rdb, and ldb which normal is (0.0, -0.5,
                    // -0.5)
                    float3_set(&n, 0.0f, -0.5f, -0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_DOWN;
                    } else {
                        return FACE_FRONT;
                    }
                }
            }
        } else {
            if (impact->z < center.z) { // could be FACE_RIGHT, FACE_TOP, or FACE_BACK
                // (1) check plane crossing center, rdf, and rtf which normal is (0.5, 0.0, 0.5)
                float3_set(&n, 0.5f, 0.0f, 0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_RIGHT or FACE_TOP
                    // (2) check plane crossing center, rtf, and rtb which normal is (0.5, -0.5,
                    // 0.0)
                    float3_set(&n, 0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_RIGHT;
                    } else {
                        return FACE_TOP;
                    }
                } else { // could be FACE_TOP or FACE_BACK
                    // (2) check plane crossing center, ltf, and rtf which normal is (0.0, -0.5,
                    // -0.5)
                    float3_set(&n, 0.0f, -0.5f, -0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_BACK;
                    } else {
                        return FACE_TOP;
                    }
                }
            } else { // could be FACE_RIGHT, FACE_TOP, or FACE_FRONT
                // (1) check plane crossing center, ldf, and ltf which normal is (0.5, 0.0, -0.5)
                float3_set(&n, 0.5f, 0.0f, -0.5f);

                if (float3_dot_product(&n, &_impact) > 0) { // could be FACE_RIGHT or FACE_TOP
                    // (2) check plane crossing center, rtf, and rtb which normal is (0.5, -0.5,
                    // 0.0)
                    float3_set(&n, 0.5f, -0.5f, 0.0f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_RIGHT;
                    } else {
                        return FACE_TOP;
                    }
                } else { // could be FACE_TOP or FACE_FRONT
                    // (2) check plane crossing center, rtb, and ltb which normal is (0.0, -0.5,
                    // 0.5)
                    float3_set(&n, 0.0f, -0.5f, 0.5f);

                    if (float3_dot_product(&n, &_impact) > 0) {
                        return FACE_FRONT;
                    } else {
                        return FACE_TOP;
                    }
                }
            }
        }
    }
#endif
}

Ray *ray_world_to_local(const Ray *ray, Transform *t) {
    float3 origin, dir;
    transform_utils_position_wtl(t, ray->origin, &origin);
    transform_utils_vector_wtl(t, ray->dir, &dir);
    float3_normalize(&dir);
    return ray_new(&origin, &dir);
}

void ray_free(Ray *ray) {
    if (ray != NULL) {
        free(ray->origin);
        free(ray->dir);
        free(ray->invdir);
    }
    free(ray);
}
