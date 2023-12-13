// -------------------------------------------------------------
//  Cubzh Core
//  box.c
//  Created by Adrien Duermael on June 5, 2019.
// -------------------------------------------------------------

#include "box.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "utils.h"

Box *box_new(void) {
    Box *b = (Box *)malloc(sizeof(Box));
    b->min = float3_zero;
    b->max = float3_zero;
    return b;
}

Box *box_new_2(const float minX,
               const float minY,
               const float minZ,
               const float maxX,
               const float maxY,
               const float maxZ) {
    Box *b = (Box *)malloc(sizeof(Box));
    float3_set(&b->min, minX, minY, minZ);
    float3_set(&b->max, maxX, maxY, maxZ);
    return b;
}

Box *box_new_copy(const Box *src) {
    Box *b = (Box *)malloc(sizeof(Box));
    float3_set(&b->min, src->min.x, src->min.y, src->min.z);
    float3_set(&b->max, src->max.x, src->max.y, src->max.z);
    return b;
}

void box_free(Box *b) {
    if (b != NULL) {
        free(b);
    }
}

void box_free_std(void *b) {
    box_free((Box *)b);
}

void box_set_bottom_center_position(Box *b, const float3 *position) {
    float3 size;
    box_get_size_float(b, &size);

    float3_copy(&b->min, position);
    b->min.x -= size.x * 0.5f;
    b->min.z -= size.z * 0.5f;

    float3_copy(&b->max, &b->min);
    float3_op_add(&b->max, &size);
}

void box_get_center(const Box *b, float3 *center) {
    float3_set(center,
               b->min.x + (b->max.x - b->min.x) * .5f,
               b->min.y + (b->max.y - b->min.y) * .5f,
               b->min.z + (b->max.z - b->min.z) * .5f);
}

float box_get_diagonal(const Box *b) {
    const float w = b->max.x - b->min.x;
    const float h = b->max.y - b->min.y;
    const float d = b->max.z - b->min.z;
    return sqrtf(w * w + h * h + d * d);
}

bool box_equals(const Box *b1, const Box *b2, const float epsilon) {
    return float3_isEqual(&b1->min, &b2->min, epsilon) &&
           float3_isEqual(&b1->max, &b2->max, epsilon);
}

bool box_collide(const Box *b1, const Box *b2) {
    return (
        b1->max.x > b2->min.x + EPSILON_COLLISION && b1->min.x < b2->max.x - EPSILON_COLLISION &&
        b1->max.y > b2->min.y + EPSILON_COLLISION && b1->min.y < b2->max.y - EPSILON_COLLISION &&
        b1->max.z > b2->min.z + EPSILON_COLLISION && b1->min.z < b2->max.z - EPSILON_COLLISION);
}

bool box_collide_epsilon(const Box *b1, const Box *b2, const float epsilon) {
    return (b1->max.x > b2->min.x - epsilon && b1->min.x < b2->max.x + epsilon &&
            b1->max.y > b2->min.y - epsilon && b1->min.y < b2->max.y + epsilon &&
            b1->max.z > b2->min.z - epsilon && b1->min.z < b2->max.z + epsilon);
}

bool box_contains(const Box *b, const float3 *f3) {
    return (b->min.x <= f3->x && b->max.x >= f3->x && b->min.y <= f3->y && b->max.y >= f3->y &&
            b->min.z <= f3->z && b->max.z >= f3->z);
}

bool box_contains_epsilon(const Box *b, const float3 *f3, float epsilon) {
    return (b->min.x <= f3->x + epsilon && b->max.x >= f3->x - epsilon &&
            b->min.y <= f3->y + epsilon && b->max.y >= f3->y - epsilon &&
            b->min.z <= f3->z + epsilon && b->max.z >= f3->z - epsilon);
}

void box_copy(Box *dest, const Box *src) {
    if (dest == NULL || src == NULL) {
        return;
    }

    dest->min.x = src->min.x;
    dest->min.y = src->min.y;
    dest->min.z = src->min.z;
    dest->max.x = src->max.x;
    dest->max.y = src->max.y;
    dest->max.z = src->max.z;
}

void box_set_broadphase_box(const Box *b, const float3 *v, Box *bpBox) {
    bpBox->min.x = (v->x > 0.0f ? b->min.x : b->min.x + v->x);
    bpBox->min.y = (v->y > 0.0f ? b->min.y : b->min.y + v->y);
    bpBox->min.z = (v->z > 0.0f ? b->min.z : b->min.z + v->z);
    bpBox->max.x = (v->x > 0.0f ? b->max.x + v->x : b->max.x);
    bpBox->max.y = (v->y > 0.0f ? b->max.y + v->y : b->max.y);
    bpBox->max.z = (v->z > 0.0f ? b->max.z + v->z : b->max.z);
}

/// Broadphase box hit test should be done before calling box_swept to avoid useless tests
///
/// Based on function from Minetest:
/// https://github.com/minetest/minetest/blob/e2f8f4da83206d551f9acebd14d574ea37ca214a/src/collision.cpp#L62
///
/// Heavily modified for Cubzh engine, notes on changes:
/// - parameter 'speed' is pre-multiplied by dt and corresponds to 'dv'
/// - this implies that return value is a rate of dv, not a delta time
/// - collision checks are a bit broadened from previously (1) to now (2),
///     (1) "movingBox is already colliding or going to collide w/ staticBox within collision
///     tolerance d"
///     (2) "movingBox is already colliding w/ staticBox regardless of collision
///     tolerance, or going to collide w/ staticBox within collision tolerance d"
///     this is an important addendum since anything can be changed from Lua, thus
///     breaking the assumption that everything moves within their respective velocity
/// - this allow us to perform a replacement step at the start of all trajectories,
///     instead of adding dedicated replacement steps outside of physics simulation,
///     which would ironically trigger further replacements in some cases
/// - replacement happens backwards along the trajectory, unless PHYSICS_EXTRA_REPLACEMENTS
///     is set, in that case it happens on all axes individually
/// - if replacement is needed but movingBox is within 'dv' reach of exiting staticBox,
///     no action is needed and we let the velocity solve this replacement naturally (3)
float box_swept(const Box *movingBox,
                const float3 *dv,
                const Box *staticBox,
                const float3 *epsilon,
                const bool withReplacement,
                float3 *normal,
                float3 *extraReplacement) {

    Box relBox;
    relBox.min.x = movingBox->min.x - staticBox->min.x;
    relBox.min.y = movingBox->min.y - staticBox->min.y;
    relBox.min.z = movingBox->min.z - staticBox->min.z;
    relBox.max.x = movingBox->max.x - staticBox->min.x;
    relBox.max.y = movingBox->max.y - staticBox->min.y;
    relBox.max.z = movingBox->max.z - staticBox->min.z;

    // note (3): replacement allowance, typically used for simulation, not used for cast
    float3 allowance = withReplacement ? *dv : float3_zero;

    float3 staticBoxSize;
    staticBoxSize.x = staticBox->max.x - staticBox->min.x;
    staticBoxSize.y = staticBox->max.y - staticBox->min.y;
    staticBoxSize.z = staticBox->max.z - staticBox->min.z;

#if PHYSICS_EXTRA_REPLACEMENTS
    const bool isColliding = box_collide_epsilon(staticBox, movingBox, 0.0f);
#endif

    float result = 1.0f;
    if (extraReplacement != NULL) {
        *extraReplacement = float3_zero;
    }

    // Check for collision with X- plane
    if (dv->x > 0.0f) {
        // if (relBox.max.x <= d                                             // note (1)
        //     || relBox.min.x <= staticBoxSize.x && relBox.max.x >= 0.0f) { // note (2)
        //  Which can be simplified to: relBox.min.x <= staticBoxSize.x
        if (relBox.min.x + allowance.x < staticBoxSize.x - epsilon->x) { // note (3)
            const float swept = -relBox.max.x / dv->x;
            if ((relBox.min.y + dv->y * swept < staticBoxSize.y - epsilon->y) &&
                (relBox.max.y + dv->y * swept > epsilon->y) &&
                (relBox.min.z + dv->z * swept < staticBoxSize.z - epsilon->z) &&
                (relBox.max.z + dv->z * swept > epsilon->z)) {

                if (normal != NULL) {
                    normal->x = -1.0f;
                    normal->y = 0.0f;
                    normal->z = 0.0f;
                }
                result = swept;
            }
        } /* else if (relBox.min.x > staticBoxSize.x) {
           return 1.0f;
           }*/
    }
    // Check for collision with X+ plane
    else if (dv->x < 0.0f) {
        // if (relBox.min.x >= staticBoxSize.x - d                           // note (1)
        //     || relBox.min.x <= staticBoxSize.x && relBox.max.x >= 0.0f) { // note (2)
        //  Which can be simplified to: relBox.max.x >= 0.0f
        if (relBox.max.x + allowance.x > epsilon->x) { // note (3)
            const float swept = (staticBoxSize.x - relBox.min.x) / dv->x;
            if ((relBox.min.y + dv->y * swept < staticBoxSize.y - epsilon->y) &&
                (relBox.max.y + dv->y * swept > epsilon->y) &&
                (relBox.min.z + dv->z * swept < staticBoxSize.z - epsilon->z) &&
                (relBox.max.z + dv->z * swept > epsilon->z)) {

                if (normal != NULL) {
                    normal->x = 1.0f;
                    normal->y = 0.0f;
                    normal->z = 0.0f;
                }
                result = swept;
            }
        } /*else if(relBox.max.x < 0.0f) {
           return 1.0f;
           }*/
    }
#if PHYSICS_EXTRA_REPLACEMENTS
    else if (extraReplacement != NULL && isColliding) {
        extraReplacement->x = staticBoxSize.x - relBox.min.x;
        if (relBox.max.x < extraReplacement->x) {
            extraReplacement->x = -relBox.max.x;
        }
    }
#endif

#if PHYSICS_FULL_BOX_SWEPT
    bool continueSweep = result == 1.0f;
#else
    if (result < 1.0f) {
        return result;
    }
    const bool continueSweep = true;
#endif

    // Check for collision with Y- plane
    if (continueSweep && dv->y > 0.0f) {
        if (relBox.min.y + allowance.y < staticBoxSize.y - epsilon->y) {
            const float swept = -relBox.max.y / dv->y;
            if ((relBox.min.x + dv->x * swept < staticBoxSize.x - epsilon->x) &&
                (relBox.max.x + dv->x * swept > epsilon->x) &&
                (relBox.min.z + dv->z * swept < staticBoxSize.z - epsilon->z) &&
                (relBox.max.z + dv->z * swept > epsilon->z)) {

                if (swept < result) {
                    if (normal != NULL) {
                        normal->x = 0.0f;
                        normal->y = -1.0f;
                        normal->z = 0.0f;
                    }
                    result = swept;
                }
            }
        } /*else {
           return 1.0f;
           }*/
    }
    // Check for collision with Y+ plane
    else if (continueSweep && dv->y < 0.0f) {
        if (relBox.max.y + allowance.y >= epsilon->y) {
            const float swept = (staticBoxSize.y - relBox.min.y) / dv->y;
            if ((relBox.min.x + dv->x * swept < staticBoxSize.x - epsilon->x) &&
                (relBox.max.x + dv->x * swept > epsilon->x) &&
                (relBox.min.z + dv->z * swept < staticBoxSize.z - epsilon->z) &&
                (relBox.max.z + dv->z * swept > epsilon->z)) {

                if (swept < result) {
                    if (normal != NULL) {
                        normal->x = 0.0f;
                        normal->y = 1.0f;
                        normal->z = 0.0f;
                    }
                    result = swept;
                }
            }
        } /* else {
           return 1.0f;
           }*/
    }
#if PHYSICS_EXTRA_REPLACEMENTS
    else if (extraReplacement != NULL && isColliding) {
        extraReplacement->y = staticBoxSize.y - relBox.min.y;
        if (relBox.max.y < extraReplacement->y) {
            extraReplacement->y = -relBox.max.y;
        }
    }
#endif

#if PHYSICS_FULL_BOX_SWEPT
    continueSweep = result == 1.0f;
#else
    if (result < 1.0f) {
        return result;
    }
#endif

    // Check for collision with Z- plane
    if (continueSweep && dv->z > 0.0f) {
        if (relBox.min.z + allowance.z <= staticBoxSize.z - epsilon->z) {
            const float swept = -relBox.max.z / dv->z;
            if ((relBox.min.x + dv->x * swept < staticBoxSize.x - epsilon->x) &&
                (relBox.max.x + dv->x * swept > epsilon->x) &&
                (relBox.min.y + dv->y * swept < staticBoxSize.y - epsilon->y) &&
                (relBox.max.y + dv->y * swept > epsilon->y)) {

                if (swept < result) {
                    if (normal != NULL) {
                        normal->x = 0.0f;
                        normal->y = 0.0f;
                        normal->z = -1.0f;
                    }
                    result = swept;
                }
            }
        }
    }
    // Check for collision with Z+ plane
    else if (continueSweep && dv->z < 0.0f) {
        if (relBox.max.z + allowance.z >= epsilon->z) {
            const float swept = (staticBoxSize.z - relBox.min.z) / dv->z;
            if ((relBox.min.x + dv->x * swept < staticBoxSize.x - epsilon->x) &&
                (relBox.max.x + dv->x * swept > epsilon->x) &&
                (relBox.min.y + dv->y * swept < staticBoxSize.y - epsilon->y) &&
                (relBox.max.y + dv->y * swept > epsilon->y)) {

                if (swept < result) {
                    if (normal != NULL) {
                        normal->x = 0.0f;
                        normal->y = 0.0f;
                        normal->z = 1.0f;
                    }
                    result = swept;
                }
            }
        }
    }
#if PHYSICS_EXTRA_REPLACEMENTS
    else if (extraReplacement != NULL && isColliding) {
        extraReplacement->z = staticBoxSize.z - relBox.min.z;
        if (relBox.max.z < extraReplacement->z) {
            extraReplacement->z = -relBox.max.z;
        }
    }
#endif

    return result;
}

void box_get_size_int(const Box *b, int3 *i3) {
    if (i3 == NULL)
        return;
    float3 f3;
    box_get_size_float(b, &f3);
    i3->x = (int32_t)f3.x;
    i3->y = (int32_t)f3.y;
    i3->z = (int32_t)f3.z;
}

void box_get_size_float(const Box *b, float3 *f3) {
    if (f3 == NULL)
        return;
    float3_copy(f3, &b->max);
    float3_op_substract(f3, &b->min);
}

bool box_is_empty(const Box *b) {
    return float3_isEqual(&b->min, &b->max, EPSILON_ZERO);
}

void box_squarify(Box *b, SquarifyType squarify) {
    const float dx = b->max.x - b->min.x;
    const float dz = b->max.z - b->min.z;
    if (squarify == MinSquarify) {
        if (dx > dz) {
            b->min.x += (dx - dz) * .5f;
            b->max.x = b->min.x + dz;
        } else if (dz > dx) {
            b->min.z += (dz - dx) * .5f;
            b->max.z = b->min.z + dx;
        }
    } else if (squarify == MaxSquarify) {
        if (dx > dz) {
            b->min.z -= (dx - dz) * .5f;
            b->max.z = b->min.z + dx;
        } else if (dz > dx) {
            b->min.x -= (dz - dx) * .5f;
            b->max.x = b->min.x + dz;
        }
    }
}

/// note: use this if there is no rotation, if both rotation & scale are involved, use box_to_aabox
/// or the transform helper functions which are specific to what type of box should be produced,
/// - transform_utils_box_to_aabb
/// - transform_utils_box_to_static_collider
/// - transform_utils_box_to_dynamic_collider
void box_to_aabox_no_rot(const Box *b,
                         Box *aab,
                         const float3 *translation,
                         const float3 *offset,
                         const float3 *scale,
                         SquarifyType squarify) {

    // translate & scale local box to translation
    float3_set(&aab->min,
               (b->min.x + offset->x) * scale->x + translation->x,
               (b->min.y + offset->y) * scale->y + translation->y,
               (b->min.z + offset->z) * scale->z + translation->z);
    float3_set(&aab->max,
               (b->max.x + offset->x) * scale->x + translation->x,
               (b->max.y + offset->y) * scale->y + translation->y,
               (b->max.z + offset->z) * scale->z + translation->z);

    // lastly, squarify BB base if required
    if (squarify) {
        box_squarify(aab, squarify);
    }
}

void box_to_aabox(const Box *b,
                  Box *aab,
                  const float3 *translation,
                  const float3 *offset,
                  Quaternion *rotation,
                  const float3 *scale,
                  SquarifyType squarify) {

    Matrix4x4 *tmp = matrix4x4_new_identity();
    Matrix4x4 *mtx = matrix4x4_new_scale(scale);
    quaternion_to_rotation_matrix(rotation, tmp);
    matrix4x4_op_multiply_2(tmp, mtx);
    matrix4x4_set_translation(tmp, translation->x, translation->y, translation->z);
    matrix4x4_op_multiply_2(tmp, mtx);
    matrix4x4_free(tmp);

    box_to_aabox2(b, aab, mtx, offset, squarify);

    matrix4x4_free(mtx);
}

void box_to_aabox2(const Box *b,
                   Box *aab,
                   const Matrix4x4 *mtx,
                   const float3 *offset,
                   SquarifyType squarify) {

    box_model1_to_model2_aabox(b, aab, mtx, NULL, offset, squarify);
}

void box_model1_to_model2_aabox(const Box *b,
                                Box *aab,
                                const Matrix4x4 *model1,
                                const Matrix4x4 *invModel2,
                                const float3 *offset,
                                SquarifyType squarify) {
    float3 min = b->min;
    float3 max = b->max;

    // optional box offset
    if (offset != NULL) {
        float3_op_add(&min, offset);
        float3_op_add(&max, offset);
    }

    float3 points[8] = {min,
                        {max.x, min.y, min.z},
                        {max.x, min.y, max.z},
                        {min.x, min.y, max.z},
                        {min.x, max.y, min.z},
                        {max.x, max.y, min.z},
                        max,
                        {min.x, max.y, max.z}};
    float3 transformed[8];

    // transform all 8 box points
    matrix4x4_op_multiply_vec_point(&transformed[0], &points[0], model1);
    matrix4x4_op_multiply_vec_point(&transformed[1], &points[1], model1);
    matrix4x4_op_multiply_vec_point(&transformed[2], &points[2], model1);
    matrix4x4_op_multiply_vec_point(&transformed[3], &points[3], model1);
    matrix4x4_op_multiply_vec_point(&transformed[4], &points[4], model1);
    matrix4x4_op_multiply_vec_point(&transformed[5], &points[5], model1);
    matrix4x4_op_multiply_vec_point(&transformed[6], &points[6], model1);
    matrix4x4_op_multiply_vec_point(&transformed[7], &points[7], model1);
    if (invModel2 != NULL) {
        memcpy(points, transformed, sizeof(float3) * 8);
        matrix4x4_op_multiply_vec_point(&transformed[0], &points[0], invModel2);
        matrix4x4_op_multiply_vec_point(&transformed[1], &points[1], invModel2);
        matrix4x4_op_multiply_vec_point(&transformed[2], &points[2], invModel2);
        matrix4x4_op_multiply_vec_point(&transformed[3], &points[3], invModel2);
        matrix4x4_op_multiply_vec_point(&transformed[4], &points[4], invModel2);
        matrix4x4_op_multiply_vec_point(&transformed[5], &points[5], invModel2);
        matrix4x4_op_multiply_vec_point(&transformed[6], &points[6], invModel2);
        matrix4x4_op_multiply_vec_point(&transformed[7], &points[7], invModel2);
    }

    // get box min/max in that new space
    aab->min = transformed[0];
    aab->max = transformed[0];
    for (int i = 1; i < 8; ++i) {
        aab->min.x = minimum(aab->min.x, transformed[i].x);
        aab->min.y = minimum(aab->min.y, transformed[i].y);
        aab->min.z = minimum(aab->min.z, transformed[i].z);
        aab->max.x = maximum(aab->max.x, transformed[i].x);
        aab->max.y = maximum(aab->max.y, transformed[i].y);
        aab->max.z = maximum(aab->max.z, transformed[i].z);
    }

    // lastly, squarify box base if required
    if (squarify) {
        box_squarify(aab, squarify);
    }
}

void box_op_merge(const Box *b1, const Box *b2, Box *result) {
    result->min.x = minimum(b1->min.x, b2->min.x);
    result->min.y = minimum(b1->min.y, b2->min.y);
    result->min.z = minimum(b1->min.z, b2->min.z);
    result->max.x = maximum(b1->max.x, b2->max.x);
    result->max.y = maximum(b1->max.y, b2->max.y);
    result->max.z = maximum(b1->max.z, b2->max.z);
}

float box_get_volume(const Box *b) {
    return (b->max.x - b->min.x) * (b->max.y - b->min.y) * (b->max.z - b->min.z);
}

bool box_is_valid(const Box *b, float epsilon) {
    if (float3_is_valid(&b->min) == false || float3_is_valid(&b->max) == false) {
        return false;
    }
    const float3 size = {
        maximum(b->max.x - b->min.x, 0.0f),
        maximum(b->max.y - b->min.y, 0.0f),
        maximum(b->max.z - b->min.z, 0.0f)
    };
    if (float3_isZero(&size, epsilon) || float3_is_valid(&size) == false) {
        return false;
    }
    return float_is_valid(size.x * size.y * size.z);
}
