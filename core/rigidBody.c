// -------------------------------------------------------------
//  Cubzh Core
//  rigidBody.c
//  Created by Adrien Duermael on April 8, 2021.
// -------------------------------------------------------------

#include "rigidBody.h"

#include <float.h>
#include <math.h>
#include <stdlib.h>

#include "scene.h"

#define SIMULATIONFLAG_NONE 0
#define SIMULATIONFLAG_MODE 3
#define SIMULATIONFLAG_COLLIDER_DIRTY 4
#define SIMULATIONFLAG_CALLBACK_ENABLED 8
#define SIMULATIONFLAG_END_CALLBACK_ENABLED 16
#define SIMULATIONFLAG_CUSTOM_COLLIDER 32

#if DEBUG_RIGIDBODY
static int debug_rigidbody_solver_iterations = 0;
static int debug_rigidbody_replacements = 0;
static int debug_rigidbody_collisions = 0;
static int debug_rigidbody_sleeps = 0;
static int debug_rigidbody_awakes = 0;
#endif

struct _RigidBody {
    // collider axis-aligned box, may be arbitrary or similar to the axis-aligned bounding box
    // (aabb)
    Box *collider;
    // pointer to r-rtree leaf, its aabb represents the space in the scene last occupied by this
    // rigidbody
    RtreeNode *rtreeLeaf;

    // Motion is an enforced force delta in world units, added every tick & not applied to velocity
    float3 *motion;

    // world velocity, in world units/sec is the current velocity along world axes
    // setting this directly ignores mass
    float3 *velocity;

    // world constant acceleration, in world units/sec^2 (ignores mass)
    float3 *constantAcceleration;

    // mass of the object determines how much a given force can move it,
    // it cannot be zero, a neutral mass is a mass of 1
    float mass;

    // combined friction of 2 surfaces in contact represents how much force is absorbed,
    // it is a rate between 0 (full stop on contact) and 1 (full slide, no friction)
    float friction;

    // bounciness represents how much force is produced in response to a collision,
    // it is a rate between 0 (no bounce) and 1 (100% of the force bounced)
    float bounciness;

    // per-axes mask where blocking contact occurred as of last physics frame
    uint8_t contact;

    // collision masks
    uint8_t groups;
    uint8_t collidesWith;

    // combines various simulation flags,
    // [0-1] simulation modes (2 bits)
    // [2] collider dirty
    // [3] callback enabled
    // [4] end callback enabled
    // [5] custom-set collider
    // [6-7] <unused>
    uint8_t simulationFlags;
    uint8_t awakeFlag;

    char pad[7];
};

static pointer_rigidbody_collision_func rigidbody_collision_callback = NULL;
static pointer_rigidbody_collision_func rigidbody_collision_couple_callback = NULL;

void _rigidbody_set_simulation_flag(RigidBody *rb, uint8_t flag) {
    rb->simulationFlags |= flag;
}

void _rigidbody_reset_simulation_flag(RigidBody *rb, uint8_t flag) {
    rb->simulationFlags &= ~flag;
}

bool _rigidbody_get_simulation_flag(const RigidBody *rb, uint8_t flag) {
    return flag == (rb->simulationFlags & flag);
}

void _rigidbody_set_simulation_flag_value(RigidBody *rb, uint8_t flag, uint8_t value) {
    _rigidbody_reset_simulation_flag(rb, flag);
    _rigidbody_set_simulation_flag(rb, value);
}

uint8_t _rigidbody_get_simulation_flag_value(const RigidBody *rb, uint8_t flag) {
    return rb->simulationFlags & flag;
}

void _rigidbody_fire_reciprocal_callbacks(RigidBody *selfRb,
                                          Transform *selfTr,
                                          RigidBody *otherRb,
                                          Transform *otherTr,
                                          AxesMaskValue axis,
                                          void *opaqueUserData) {

    // Reciprocal call only for dynamic rb, trigger rb each check for their own overlaps
    const bool isOtherDynamic = rigidbody_is_dynamic(otherRb);

    // (1) fire direct callback if enabled
    if (_rigidbody_get_simulation_flag(selfRb, SIMULATIONFLAG_CALLBACK_ENABLED)) {
        rigidbody_collision_callback(selfTr, selfRb, otherTr, otherRb, axis, opaqueUserData);
    }

    // (2) fire reciprocal callback if applicable
    if (isOtherDynamic &&
        _rigidbody_get_simulation_flag(otherRb, SIMULATIONFLAG_CALLBACK_ENABLED)) {
        rigidbody_collision_callback(otherTr,
                                     otherRb,
                                     selfTr,
                                     selfRb,
                                     axis == AxesMaskX ? AxesMaskNX : AxesMaskX,
                                     opaqueUserData);
    }

    // (3) register collision couple for end-of-contact callback if applicable
    if (_rigidbody_get_simulation_flag(selfRb, SIMULATIONFLAG_END_CALLBACK_ENABLED) ||
        (isOtherDynamic &&
         _rigidbody_get_simulation_flag(otherRb, SIMULATIONFLAG_END_CALLBACK_ENABLED))) {

        rigidbody_collision_couple_callback(selfTr, selfRb, otherTr, otherRb, axis, opaqueUserData);
    }
}

bool _rigidbody_dynamic_tick(Scene *scene,
                             RigidBody *rb,
                             Transform *t,
                             Box *worldCollider,
                             Rtree *r,
                             const TICK_DELTA_SEC_T dt,
                             FifoList *sceneQuery,
                             void *opaqueUserData) {

#if DEBUG_RIGIDBODY_CALLS
#define INC_REPLACEMENTS debug_rigidbody_replacements++;
#define INC_COLLISIONS debug_rigidbody_collisions++;
#define INC_SLEEPS debug_rigidbody_sleeps++;
#else
#define INC_REPLACEMENTS
#define INC_COLLISIONS
#define INC_SLEEPS
#endif

    float3 f3;
    float dt_f = (float)dt;

    // ------------------------
    // APPLY CONSTANT ACCELERATION
    // ------------------------

    float3_copy(&f3, scene_get_constant_acceleration(scene));
    float3_op_add(&f3, rb->constantAcceleration);
    float3_op_scale(&f3, dt);
    float3_op_add(rb->velocity, &f3);

    // ------------------------
    // APPLY DRAG
    // ------------------------
    // Later on, we might add other environmental drag like water,
    // or make it all accessible in Lua w/ pass-through rigidbodies & settable drag property / air
    // drag in config

    float drag = PHYSICS_AIR_DRAG_DEFAULT;
    drag = 1.0f - minimum(drag * dt_f, 1.0f);

    float3_op_scale(rb->velocity, drag);

    // ------------------------
    // ADD MOTION
    // ------------------------
    // Motion moves the object w/o drag and w/o affecting velocity directly, although it may
    // contribute to provoking collision responses, like a bounce

    float3_copy(&f3, rb->velocity);
    float3_op_add(&f3, rb->motion);
    // f3 now represents object's velocity + motion

    // dynamic rigidbodies may sleep
    if (rigidbody_check_velocity_sleep(rb, &f3)) {
        float3_set_zero(rb->velocity);
        INC_SLEEPS
        return false;
    }

    // ------------------------
    // CLAMP TO MAX VELOCITY
    // ------------------------

    const float sqMag = float3_sqr_length(&f3);
    if (sqMag > PHYSICS_MAX_SQR_VELOCITY) {
        float3_op_unscale(&f3, sqrtf(sqMag));
        float3_op_scale(&f3, PHYSICS_MAX_VELOCITY);
    }

#if DEBUG_RIGIDBODY_EXTRA_LOGS
    cclog_debug("🏞 rigidbody of type %d w/ total velocity (%.3f, %.3f, %.3f)",
                transform_get_type(t),
                f3.x,
                f3.y,
                f3.z);
#endif

    // ------------------------
    // PREPARE COLLISION TESTING
    // ------------------------

    float3 dv, swept3, push3, extraReplacement3;
    float minSwept;
    float3 pos = *transform_get_position(t);
    Box mapAABB, broadPhaseBox;
    RigidBody *contactX, *contactY, *contactZ;
    Transform *contactXTr, *contactYTr, *contactZTr;

    // initial frame delta translation
    float3_copy(&dv, &f3);
    float3_op_scale(&dv, dt);

    // retrieve the map AABB
    Shape *mapShape = transform_get_shape(scene_get_map(scene));
    if (mapShape == NULL) {
        return false;
    }
    shape_get_world_aabb(mapShape, &mapAABB, false);

    RigidBody *mapRb = shape_get_rigidbody(mapShape);

    // ----------------------
    // SOLVER ITERATIONS
    // ----------------------
    // A collision triggers a response that may fall within the same frame simulation, up to a max
    // number of solver iterations

    size_t solverCount = 0;
    while (float3_isZero(&dv, EPSILON_COLLISION) == false &&
           solverCount < PHYSICS_MAX_SOLVER_ITERATIONS) {
        minSwept = 1.0f;
        swept3 = float3_one;
        extraReplacement3 = float3_zero;
        contactX = NULL;
        contactY = NULL;
        contactZ = NULL;
        contactXTr = NULL;
        contactYTr = NULL;
        contactZTr = NULL;

        // ----------------------
        // MAP COLLISIONS
        // ----------------------
        // reduce the trajectory (broadphase box) to a smaller form by testing against the map first

        if (rigidbody_collides_with_any(rb, mapRb->groups)) {
            box_set_broadphase_box(worldCollider, &dv, &broadPhaseBox);

            if (box_collide(&mapAABB, &broadPhaseBox)) {
                minSwept = shape_box_swept(mapShape,
                                           worldCollider,
                                           &dv,
                                           true,
                                           &swept3,
                                           &extraReplacement3,
                                           EPSILON_ZERO);

                // not a free movement
                if (minSwept < 1.0f) {
                    if (swept3.x < 1.0f) {
                        contactX = mapRb;
                        contactXTr = shape_get_root_transform(mapShape);
                    }
                    if (swept3.y < 1.0f) {
                        contactY = mapRb;
                        contactYTr = shape_get_root_transform(mapShape);
                    }
                    if (swept3.z < 1.0f) {
                        contactZ = mapRb;
                        contactZTr = shape_get_root_transform(mapShape);
                    }

                    // already in contact (==0) or colliding (<0)
                    if (minSwept <= 0.0f) {
                        // continue sweep vs. scene to check for full replacement & response
                    }
                    // collision will occur with the map, shorten trajectory
                    else {
                        float3_copy(&f3, &dv);
                        float3_op_scale(&f3, minSwept);
                        box_set_broadphase_box(worldCollider, &f3, &broadPhaseBox);
                    }
                }
            }
        }

        // ----------------------
        // SCENE COLLISIONS
        // ----------------------
        // test the map-reduced trajectory (broadphase box) against scene colliders
        //
        // Note: currently, we perform a one-pass collision check = each moving collider against a
        // static scene it isn't going to be accurate in case of concurring trajectories We can add
        // a full broadphase if we see it's necessary

        // previous query should be processed entirely
        vx_assert(fifo_list_pop(sceneQuery) == NULL);

        // run collision query in r-tree w/ default inner epsilon
        if (rtree_query_overlap_box(r,
                                    &broadPhaseBox,
                                    rb->groups,
                                    rb->collidesWith,
                                    sceneQuery,
                                    -EPSILON_COLLISION) > 0) {
            RtreeNode *hit = fifo_list_pop(sceneQuery);
            Transform *hitLeaf = NULL;
            RigidBody *hitRb = NULL;
            float3 normal;
            while (hit != NULL) {
                hitLeaf = (Transform *)rtree_node_get_leaf_ptr(hit);
                vx_assert(rtree_node_is_leaf(hit));

                // currently, we do not remove self from r-tree before query
                if (hitLeaf == t) {
                    hit = fifo_list_pop(sceneQuery);
                    continue;
                }

                hitRb = transform_get_rigidbody(hitLeaf);
                vx_assert(hitRb != NULL);

                if (rigidbody_collides_with_rigidbody(rb, hitRb) == false) {
                    hit = fifo_list_pop(sceneQuery);
                    continue;
                }

                const float swept = box_swept(worldCollider,
                                              &dv,
                                              rtree_node_get_aabb(hit),
                                              true,
                                              &normal,
                                              NULL,
                                              EPSILON_ZERO);
                if (normal.x != 0.0f) {
                    if (swept < swept3.x) {
                        swept3.x = swept;
                        contactX = hitRb;
                        contactXTr = hitLeaf;
                    }
                } else if (normal.y != 0.0f) {
                    if (swept < swept3.y) {
                        swept3.y = swept;
                        contactY = hitRb;
                        contactYTr = hitLeaf;
                    }
                } else if (normal.z != 0.0f) {
                    if (swept < swept3.z) {
                        swept3.z = swept;
                        contactZ = hitRb;
                        contactZTr = hitLeaf;
                    }
                }
                minSwept = minimum(swept, minSwept);

                hit = fifo_list_pop(sceneQuery);
            }
        }

        // ----------------------
        // STOP MOTION THRESHOLD
        // ----------------------
        // remove superfluous movement or accumulated errors

        if (float_isZero(minSwept, PHYSICS_STOP_MOTION_THRESHOLD)) {

            if (float_isEqual(swept3.x, minSwept, EPSILON_ZERO)) {
                swept3.x = 0.0f;
            }
            if (float_isEqual(swept3.y, minSwept, EPSILON_ZERO)) {
                swept3.y = 0.0f;
            }
            if (float_isEqual(swept3.z, minSwept, EPSILON_ZERO)) {
                swept3.z = 0.0f;
            }
            minSwept = 0.0f;
        }

        // ----------------------
        // SUPERIOR MASS PUSH
        // ----------------------
        // check for push from superior mass vs. dynamic rigibodies in contact
        //
        // Notes:
        // - we use a strict > test to reduce superfluous movement from collisions,
        // to not awake rigidbodies as often
        // - self is flagged as awake, to permit pushing against contact

        if (contactX != NULL && float_isEqual(minSwept, swept3.x, EPSILON_ZERO)) {
            if (rigidbody_is_dynamic(contactX) && rb->mass > contactX->mass) {
                // apply push force to contact rigidbody velocity relative to colliding masses,
                // along the remainder of the trajectory
                const float push = minimum(rigidbody_get_mass_push_ratio(rb, contactX) *
                                               (1.0f - swept3.x),
                                           1.0f);

                push3.x = dv.x * push / dt_f;
                push3.y = dv.y * push / dt_f;
                push3.z = dv.z * push / dt_f;

                rigidbody_apply_push(contactX, &push3);
                rigidbody_set_awake(rb);
            }
        }
        if (contactY != NULL && float_isEqual(minSwept, swept3.y, EPSILON_ZERO)) {
            if (rigidbody_is_dynamic(contactY) && rb->mass > contactY->mass) {
                const float push = minimum(rigidbody_get_mass_push_ratio(rb, contactY) *
                                               (1.0f - swept3.y),
                                           1.0f);
                push3.x = dv.x * push / dt_f;
                push3.y = dv.y * push / dt_f;
                push3.z = dv.z * push / dt_f;

                rigidbody_apply_push(contactY, &push3);
                rigidbody_set_awake(rb);
            }
        }
        if (contactZ != NULL && float_isEqual(minSwept, swept3.z, EPSILON_ZERO)) {
            if (rigidbody_is_dynamic(contactZ) && rb->mass > contactZ->mass) {
                const float push = minimum(rigidbody_get_mass_push_ratio(rb, contactZ) *
                                               (1.0f - swept3.z),
                                           1.0f);
                push3.x = dv.x * push / dt_f;
                push3.y = dv.y * push / dt_f;
                push3.z = dv.z * push / dt_f;

                rigidbody_apply_push(contactZ, &push3);
                rigidbody_set_awake(rb);
            }
        }

        // ----------------------
        // PRE-COLLISION REPLACEMENT
        // ----------------------
        // a replaced component will become "in contact" after replacement (setting swept to 0)

        if (minSwept < 0.0f || float3_isZero(&extraReplacement3, EPSILON_ZERO) == false) {
            float3 replacement = extraReplacement3;
            if (swept3.x < 0.0f) {
                replacement.x = dv.x * swept3.x;
                swept3.x = 0.0f;
            }
            if (swept3.y < 0.0f) {
                replacement.y = dv.y * swept3.y;
                swept3.y = 0.0f;
            }
            if (swept3.z < 0.0f) {
                replacement.z = dv.z * swept3.z;
                swept3.z = 0.0f;
            }
            minSwept = 0.0f;

            rb->contact = AxesMaskNone;

            float3_op_add(&pos, &replacement);
            float3_op_add(&worldCollider->min, &replacement);
            float3_op_add(&worldCollider->max, &replacement);
            INC_REPLACEMENTS

#if DEBUG_RIGIDBODY_EXTRA_LOGS
            cclog_debug("🏞 rigidbody of type %d replaced w/ (%.3f, %.3f, %.3f)",
                        transform_get_type(t),
                        replacement.x,
                        replacement.y,
                        replacement.z);
#endif
        }

        // after replacement: only in contact (==0), colliding (<1), or free movement (>= 1)
        vx_assert(minSwept >= 0.0f);

        // ----------------------
        // PRE-COLLISION MOVEMENT
        // ----------------------

        // not in contact already
        if (minSwept > 0.0f) {
            float3_copy(&f3, &dv);
            float3_op_scale(&f3, minimum(minSwept, 1.0f));

            float3_op_add(&pos, &f3);
            float3_op_add(&worldCollider->min, &f3);
            float3_op_add(&worldCollider->max, &f3);
        } else {
            float3_set_zero(&f3);
        }

        // ----------------------
        // COLLISION CALLBACK
        // ----------------------

        // collision or contact on at least one component
        if (rigidbody_collision_callback != NULL && rigidbody_collision_couple_callback != NULL &&
            minSwept < 1.0f) {

            // fire reciprocal callbacks on the component(s, if tie) causing a new collision

            if (contactX != NULL && float_isEqual(minSwept, swept3.x, EPSILON_ZERO)) {
                const AxesMaskValue axis = dv.x > 0 ? AxesMaskX : AxesMaskNX;
                if (utils_axes_mask_get(rb->contact, axis) == false) {
                    _rigidbody_fire_reciprocal_callbacks(rb,
                                                         t,
                                                         contactX,
                                                         contactXTr,
                                                         axis,
                                                         opaqueUserData);
                }
            }
            if (contactY != NULL && float_isEqual(minSwept, swept3.y, EPSILON_ZERO)) {
                const AxesMaskValue axis = dv.y > 0 ? AxesMaskY : AxesMaskNY;
                if (utils_axes_mask_get(rb->contact, axis) == false) {
                    _rigidbody_fire_reciprocal_callbacks(rb,
                                                         t,
                                                         contactY,
                                                         contactYTr,
                                                         axis,
                                                         opaqueUserData);
                }
            }
            if (contactZ != NULL && float_isEqual(minSwept, swept3.z, EPSILON_ZERO)) {
                const AxesMaskValue axis = dv.z > 0 ? AxesMaskZ : AxesMaskNZ;
                if (utils_axes_mask_get(rb->contact, axis) == false) {
                    _rigidbody_fire_reciprocal_callbacks(rb,
                                                         t,
                                                         contactZ,
                                                         contactZTr,
                                                         axis,
                                                         opaqueUserData);
                }
            }
        }

        // ----------------------
        // COLLISION RESPONSE
        // ----------------------
        // Velocity, which is in unit/s & does not contain motion, is updated at the same time as
        // dv, which is the delta translation being processed in this solver iteration

        // collision or contact on at least one component
        if (minSwept < 1.0f) {
            // on the component(s, if tie) causing collision,
            if (float_isEqual(minSwept, swept3.x, EPSILON_ZERO)) {
                // (1) update contact mask if blocking collision was caused this frame
                if (dv.x > 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskX, true);
                } else if (dv.x < 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskNX, true);
                }

                // (2a) if in contact on both sides (2a.1), if displacement below bounciness
                // threshold (2a.2), or if combined bounciness is zero (2a.3), stop solver (2a.4)
                // and inherit contact velocity if inferior mass (2a.5)
                const float combined = contactX != NULL ? rigidbody_get_combined_bounciness(
                                                              rb,
                                                              rigidbody_get_bounciness(contactX))
                                                        : rb->bounciness;
                if (utils_axes_mask_get(rb->contact, AxesMaskX | AxesMaskNX) // (2a.1)
                    || float_isZero(dv.x, PHYSICS_BOUNCE_THRESHOLD)          // (2a.2)
                    || float_isZero(combined, EPSILON_ZERO)) {               // (2a.3)

                    dv.x = 0.0f; // (2a.4)
                    rb->velocity->x = contactX != NULL && rb->mass < contactX->mass
                                          ? rigidbody_get_mass_push_ratio(contactX, rb) *
                                                contactX->velocity->x // (2a.5)
                                          : 0.0f;
                }
                // (2b) apply bounciness
                else {
                    dv.x *= -combined;
                    rb->velocity->x *= -combined;
                }
            }
            // on the component(s) tangential to collision,
            else {
                // (1) reset contact mask if there was any motion
                if (dv.x != 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskX | AxesMaskNX, false);
                }

                // (2) apply combined friction
                const float combined = contactX != NULL ? rigidbody_get_combined_friction(
                                                              rb,
                                                              rigidbody_get_friction(contactX))
                                                        : rb->friction;
                dv.x *= combined;
                rb->velocity->x *= combined;
            }
            if (float_isEqual(minSwept, swept3.y, EPSILON_ZERO)) {
                if (dv.y > 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskY, true);
                } else if (dv.y < 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskNY, true);
                }

                const float combined = contactY != NULL ? rigidbody_get_combined_bounciness(
                                                              rb,
                                                              rigidbody_get_bounciness(contactY))
                                                        : rb->bounciness;
                if (utils_axes_mask_get(rb->contact, AxesMaskY | AxesMaskNY) ||
                    float_isZero(dv.y, PHYSICS_BOUNCE_THRESHOLD) ||
                    float_isZero(combined, EPSILON_ZERO)) {

                    dv.y = 0.0f;
                    rb->velocity->y = contactY != NULL && rb->mass < contactY->mass
                                          ? rigidbody_get_mass_push_ratio(contactY, rb) *
                                                contactY->velocity->y
                                          : 0.0f;
                } else {
                    dv.y *= -combined;
                    rb->velocity->y *= -combined;
                }
            } else {
                if (dv.y != 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskY | AxesMaskNY, false);
                }

                const float combined = contactY != NULL ? rigidbody_get_combined_friction(
                                                              rb,
                                                              rigidbody_get_friction(contactY))
                                                        : rb->friction;
                dv.y *= combined;
                rb->velocity->y *= combined;
            }
            if (float_isEqual(minSwept, swept3.z, EPSILON_ZERO)) {
                if (dv.z > 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskZ, true);
                } else if (dv.z < 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskNZ, true);
                }

                const float combined = contactZ != NULL ? rigidbody_get_combined_friction(
                                                              rb,
                                                              rigidbody_get_bounciness(contactZ))
                                                        : rb->bounciness;
                if (utils_axes_mask_get(rb->contact, AxesMaskZ | AxesMaskNZ) ||
                    float_isZero(dv.z, PHYSICS_BOUNCE_THRESHOLD) ||
                    float_isZero(combined, EPSILON_ZERO)) {

                    dv.z = 0.0f;
                    rb->velocity->z = contactZ != NULL && rb->mass < contactZ->mass
                                          ? rigidbody_get_mass_push_ratio(contactZ, rb) *
                                                contactZ->velocity->z
                                          : 0.0f;
                } else {
                    dv.z *= -combined;
                    rb->velocity->z *= -combined;
                }
            } else {
                if (dv.z != 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskZ | AxesMaskNZ, false);
                }

                const float combined = contactZ != NULL ? rigidbody_get_combined_friction(
                                                              rb,
                                                              rigidbody_get_friction(contactZ))
                                                        : rb->friction;
                dv.z *= combined;
                rb->velocity->z *= combined;
            }
            INC_COLLISIONS
        }
        // no collision,
        else {
            // (1) reset contact mask for axes that had motion
            if (dv.x != 0.0f) {
                utils_axes_mask_set(&rb->contact, AxesMaskX | AxesMaskNX, false);
            }
            if (dv.y != 0.0f) {
                utils_axes_mask_set(&rb->contact, AxesMaskY | AxesMaskNY, false);
            }
            if (dv.z != 0.0f) {
                utils_axes_mask_set(&rb->contact, AxesMaskZ | AxesMaskNZ, false);
            }

            // (2) all motion is solved
            float3_set_zero(&dv);
        }

        solverCount++;
    }
#if DEBUG_RIGIDBODY_CALLS
    debug_rigidbody_solver_iterations += solverCount;
#endif

    if (solverCount > 0 && float3_isEqual(&pos, transform_get_position(t), EPSILON_ZERO) == false) {
        // apply final position to transform
        transform_set_position(t, pos.x, pos.y, pos.z);

        return true;
    } else {
        return false;
    }
}

void _rigidbody_trigger_tick(Scene *scene,
                             RigidBody *rb,
                             Transform *t,
                             Box *worldCollider,
                             Rtree *r,
                             const TICK_DELTA_SEC_T dt,
                             FifoList *sceneQuery,
                             void *opaqueUserData) {

    // ------------------------
    // PREPARE OVERLAP TESTING
    // ------------------------
    // On an overlap, we consider the face w/ the most overlap to be the dominant overlap axis,
    // it matters only to have some deterministic way of assigning an overlap to an axis mask value
    // as this is currently how we register collision callbacks
    //
    // Note: contrary to dynamic rigidbodies which are always tied to a velocity and can only have
    // at most new contacts on 3 axes, trigger rigidbodies are not and may have new contacts on all
    // 6 axes

    Shape *mapShape = transform_get_shape(scene_get_map(scene));
    if (mapShape == NULL) {
        return;
    }
    Box mapAABB;
    shape_get_world_aabb(mapShape, &mapAABB, false);
    RigidBody *mapRb = shape_get_rigidbody(mapShape);

    float3 f3, center, maxContactsArea, maxContactsAreaN;
    RigidBody *axesRb[6];
    Transform *axesTr[6];

    float3_set_zero(&maxContactsArea);
    float3_set_zero(&maxContactsAreaN);
    box_get_center(worldCollider, &center);
    for (int i = 0; i < 6; ++i) {
        axesRb[i] = NULL;
        axesTr[i] = NULL;
    }

    // ----------------------
    // MAP OVERLAP
    // ----------------------

    if (rigidbody_collides_with_any(rb, mapRb->groups) && box_collide(&mapAABB, worldCollider)) {
        if (shape_box_overlap(mapShape, worldCollider, &f3)) {
            Transform *mapTr = shape_get_root_transform(mapShape);
            float3 lossyScale;
            transform_get_lossy_scale(mapTr, &lossyScale);

            // find the most overlapping edges to determine overlap axis & store it
            const float dx = minimum(worldCollider->max.x, f3.x + lossyScale.x) -
                             maximum(worldCollider->min.x, f3.x);
            const float dy = minimum(worldCollider->max.y, f3.y + lossyScale.y) -
                             maximum(worldCollider->min.y, f3.y);
            const float dz = minimum(worldCollider->max.z, f3.z + lossyScale.z) -
                             maximum(worldCollider->min.z, f3.z);
            if (dx <= dy && dx <= dz) { // colliders height & depth overlap the most = X or NX
                                        // (right or left face)
                if (f3.x < center.x) {  // overlap axis is NX (left)
                    maxContactsAreaN.x = dy * dz;
                    axesRb[AxisIndexNX] = mapRb;
                    axesTr[AxisIndexNX] = shape_get_root_transform(mapShape);
                } else { // overlap axis is X (right)
                    maxContactsArea.x = dy * dz;
                    axesRb[AxisIndexX] = mapRb;
                    axesTr[AxisIndexX] = shape_get_root_transform(mapShape);
                }
            } else if (dy <= dx && dy <= dz) { // colliders width & depth overlap the most = Y or NY
                                               // (top or bottom face)
                if (f3.y < center.y) {         // overlap axis is NY (bottom)
                    maxContactsAreaN.y = dx * dz;
                    axesRb[AxisIndexNY] = mapRb;
                    axesTr[AxisIndexNY] = shape_get_root_transform(mapShape);
                } else { // overlap axis is Y (top)
                    maxContactsArea.y = dx * dz;
                    axesRb[AxisIndexY] = mapRb;
                    axesTr[AxisIndexY] = shape_get_root_transform(mapShape);
                }
            } else { // colliders width & height overlap the most = Z or NZ (back or front face)
                if (f3.z < center.z) { // overlap axis is NZ (front)
                    maxContactsAreaN.z = dx * dy;
                    axesRb[AxisIndexNZ] = mapRb;
                    axesTr[AxisIndexNZ] = shape_get_root_transform(mapShape);
                } else { // overlap axis is Z (back)
                    maxContactsArea.z = dx * dy;
                    axesRb[AxisIndexZ] = mapRb;
                    axesTr[AxisIndexZ] = shape_get_root_transform(mapShape);
                }
            }
        }
    }

    // ----------------------
    // SCENE OVERLAP
    // ----------------------

    // previous query should be processed entirely
    vx_assert(fifo_list_pop(sceneQuery) == NULL);

    // run overlap query in r-tree
    // Note: w/ an outer epsilon to let trigger rigidbody callbacks be called before a potential
    // collision response from a dynamic rigidbody
    if (rtree_query_overlap_box(r,
                                worldCollider,
                                rb->groups,
                                rb->collidesWith,
                                sceneQuery,
                                EPSILON_COLLISION) > 0) {
        RtreeNode *hit = fifo_list_pop(sceneQuery);
        Transform *hitLeaf = NULL;
        RigidBody *hitRb = NULL;
        while (hit != NULL) {
            hitLeaf = (Transform *)rtree_node_get_leaf_ptr(hit);
            vx_assert(rtree_node_is_leaf(hit));

            // currently, we do not remove self from r-tree before query
            if (hitLeaf == t) {
                hit = fifo_list_pop(sceneQuery);
                continue;
            }

            hitRb = transform_get_rigidbody(hitLeaf);
            vx_assert(hitRb != NULL);

            if (rigidbody_collides_with_rigidbody(rb, hitRb) == false) {
                hit = fifo_list_pop(sceneQuery);
                continue;
            }

            Box *hitCollider = rtree_node_get_aabb(hit);

            // find dominant overlap axis and update it if closer
            const float dx = minimum(worldCollider->max.x, hitCollider->max.x) -
                             maximum(worldCollider->min.x, hitCollider->min.x);
            const float dy = minimum(worldCollider->max.y, hitCollider->max.y) -
                             maximum(worldCollider->min.y, hitCollider->min.y);
            const float dz = minimum(worldCollider->max.z, hitCollider->max.z) -
                             maximum(worldCollider->min.z, hitCollider->min.z);
            if (dx <= dy && dx <= dz) { // colliders height & depth overlap the most = X or NX
                // (right or left face)
                const float contactArea = dy * dz;
                if (hitCollider->min.x < center.x) { // overlap axis is NX (left)
                    if (contactArea > maxContactsAreaN.x) {
                        maxContactsAreaN.x = contactArea;
                        axesRb[AxisIndexNX] = hitRb;
                        axesTr[AxisIndexNX] = hitLeaf;
                    }
                } else if (contactArea > maxContactsArea.x) { // overlap axis is X (right)
                    maxContactsArea.x = contactArea;
                    axesRb[AxisIndexX] = hitRb;
                    axesTr[AxisIndexX] = hitLeaf;
                }
            } else if (dy <= dx && dy <= dz) { // colliders width & depth overlap the most = Y or NY
                // (top or bottom face)
                const float contactArea = dx * dz;
                if (hitCollider->min.y < center.y) { // overlap axis is NY (bottom)
                    if (contactArea > maxContactsAreaN.y) {
                        maxContactsAreaN.y = contactArea;
                        axesRb[AxisIndexNY] = hitRb;
                        axesTr[AxisIndexNY] = hitLeaf;
                    }
                } else if (contactArea > maxContactsArea.y) { // overlap axis is Y (top)
                    maxContactsArea.y = contactArea;
                    axesRb[AxisIndexY] = hitRb;
                    axesTr[AxisIndexY] = hitLeaf;
                }
            } else { // colliders width & height overlap the most = Z or NZ (back or front face)
                const float contactArea = dx * dy;
                if (hitCollider->min.z < center.z) { // overlap axis is NZ (front)
                    if (contactArea > maxContactsAreaN.z) {
                        maxContactsAreaN.z = contactArea;
                        axesRb[AxisIndexNZ] = hitRb;
                        axesTr[AxisIndexNZ] = hitLeaf;
                    }
                } else if (contactArea > maxContactsArea.z) { // overlap axis is Z (back)
                    maxContactsArea.z = contactArea;
                    axesRb[AxisIndexZ] = hitRb;
                    axesTr[AxisIndexZ] = hitLeaf;
                }
            }

            hit = fifo_list_pop(sceneQuery);
        }
    }

    // ----------------------
    // COLLISION CALLBACK
    // ----------------------
    // For trigger rigidbodies, we use axes mask solely to keep track of collision callbacks

    if (rigidbody_collision_callback != NULL && rigidbody_collision_couple_callback != NULL) {
        // fire reciprocal callbacks on the component(s, if tie) causing a new collision
        for (int i = 0; i < 6; ++i) {
            const AxesMaskValue axis = utils_axis_index_to_mask_value((AxisIndex)i);
            if (axesRb[i] != NULL) {
                if (utils_axes_mask_get(rb->contact, axis) == false) {
                    _rigidbody_fire_reciprocal_callbacks(rb,
                                                         t,
                                                         axesRb[i],
                                                         axesTr[i],
                                                         axis,
                                                         opaqueUserData);
                    utils_axes_mask_set(&rb->contact, axis, true);
                }
            } else {
                utils_axes_mask_set(&rb->contact, axis, false);
            }
        }
    }
}

RigidBody *rigidbody_new(const uint8_t mode, const uint8_t groups, const uint8_t collidesWith) {
    RigidBody *b = (RigidBody *)malloc(sizeof(RigidBody));

    b->collider = box_new();
    b->rtreeLeaf = NULL;
    b->motion = float3_new_zero();
    b->velocity = float3_new_zero();
    b->constantAcceleration = float3_new_zero();
    b->mass = PHYSICS_MASS_DEFAULT;
    b->friction = PHYSICS_FRICTION_DEFAULT;
    b->bounciness = PHYSICS_BOUNCINESS_DEFAULT;
    b->contact = AxesMaskNone;
    b->groups = groups;
    b->collidesWith = collidesWith;
    b->simulationFlags = SIMULATIONFLAG_NONE;
    b->awakeFlag = 0;

    _rigidbody_set_simulation_flag_value(b, SIMULATIONFLAG_MODE, mode);

    return b;
}

void rigidbody_free(RigidBody *b) {
    if (b == NULL) {
        return;
    }

    box_free(b->collider);
    float3_free(b->motion);
    float3_free(b->velocity);
    float3_free(b->constantAcceleration);

    free(b);
}

void rigidbody_reset(RigidBody *b) {
    if (b == NULL) {
        return;
    }

    // note: rigidbody properties are persistent
    float3_set_zero(b->motion);
    float3_set_zero(b->velocity);

    rigidbody_non_kinematic_reset(b);
}

void rigidbody_non_kinematic_reset(RigidBody *b) {
    if (b == NULL) {
        return;
    }

    b->contact = AxesMaskNone;
}

bool rigidbody_tick(Scene *scene,
                    RigidBody *rb,
                    Transform *t,
                    Box *worldCollider,
                    Rtree *r,
                    const TICK_DELTA_SEC_T dt,
                    void *opaqueUserData) {

    if (dt <= 0.0) {
        return false;
    }

    static FifoList *sceneQuery = NULL;
    if (sceneQuery == NULL) {
        sceneQuery = fifo_list_new();
    }

    // a dynamic rigidbody is fully simulated - movement, mass push, replacement, callbacks,
    // collision responses
    if (rigidbody_is_dynamic(rb)) {
        return _rigidbody_dynamic_tick(scene,
                                       rb,
                                       t,
                                       worldCollider,
                                       r,
                                       dt,
                                       sceneQuery,
                                       opaqueUserData);
    }
    // a trigger rigidbody only checks for overlaps to fire callbacks
    else if (rigidbody_is_trigger(rb)) {
        _rigidbody_trigger_tick(scene, rb, t, worldCollider, r, dt, sceneQuery, opaqueUserData);
    }

    return false;
}

// MARK: - Accessors -

const Box *rigidbody_get_collider(const RigidBody *rb) {
    return rb->collider;
}

void rigidbody_set_collider(RigidBody *rb, const Box *value) {
    box_copy(rb->collider, value);
    _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_DIRTY);
}

RtreeNode *rigidbody_get_rtree_leaf(const RigidBody *rb) {
    return rb->rtreeLeaf;
}

void rigidbody_set_rtree_leaf(RigidBody *rb, RtreeNode *leaf) {
    rb->rtreeLeaf = leaf;
}

const float3 *rigidbody_get_motion(const RigidBody *rb) {
    return rb->motion;
}

void rigidbody_set_motion(RigidBody *rb, const float3 *value) {
    float3_copy(rb->motion, value);
}

const float3 *rigidbody_get_velocity(const RigidBody *rb) {
    return rb->velocity;
}

void rigidbody_set_velocity(RigidBody *rb, const float3 *value) {
    float3_copy(rb->velocity, value);
}

const float3 *rigidbody_get_constant_acceleration(const RigidBody *rb) {
    return rb->constantAcceleration;
}

void rigidbody_set_constant_acceleration(RigidBody *rb, const float3 *value) {
    float3_copy(rb->constantAcceleration, value);
}

float rigidbody_get_mass(const RigidBody *rb) {
    return rb->mass;
}

void rigidbody_set_mass(RigidBody *rb, const float value) {
    rb->mass = maximum(value, 1.0f);
}

float rigidbody_get_friction(const RigidBody *rb) {
    return rb->friction;
}

void rigidbody_set_friction(RigidBody *rb, const float value) {
    rb->friction = value;
}

float rigidbody_get_bounciness(const RigidBody *rb) {
    return rb->bounciness;
}

void rigidbody_set_bounciness(RigidBody *rb, const float value) {
    rb->bounciness = value;
}

uint8_t rigidbody_get_contact_mask(const RigidBody *rb) {
    return rb->contact;
}

void rigidbody_set_contact_mask(RigidBody *rb, const uint8_t value) {
    rb->contact = value;
}

uint8_t rigidbody_get_groups(const RigidBody *rb) {
    return rb->groups;
}

void rigidbody_set_groups(RigidBody *rb, uint8_t value) {
    rb->groups = value;
}

uint8_t rigidbody_get_collides_with(const RigidBody *rb) {
    return rb->collidesWith;
}

void rigidbody_set_collides_with(RigidBody *rb, uint8_t value) {
    rb->collidesWith = value;
}

uint8_t rigidbody_get_simulation_mode(const RigidBody *rb) {
    return rb != NULL ? _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) : Disabled;
}

void rigidbody_set_simulation_mode(RigidBody *rb, const uint8_t value) {
    if (_rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) != value) {
        _rigidbody_set_simulation_flag_value(rb, SIMULATIONFLAG_MODE, value);
#if TRANSFORM_AABOX_STATIC_COLLIDER_MODE != TRANSFORM_AABOX_DYNAMIC_COLLIDER_MODE
        if (value == RigidbodyModeStatic || value == RigidbodyModeDynamic) {
            _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_DIRTY);
        }
#endif
    }
}

bool rigidbody_get_collider_dirty(const RigidBody *rb) {
    return _rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_DIRTY);
}

void rigidbody_reset_collider_dirty(RigidBody *rb) {
    _rigidbody_reset_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_DIRTY);
}

void rigidbody_toggle_collision_callback(RigidBody *rb, bool value, bool end) {
    if (end) {
        if (value) {
            _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_END_CALLBACK_ENABLED);
        } else {
            _rigidbody_reset_simulation_flag(rb, SIMULATIONFLAG_END_CALLBACK_ENABLED);
        }
    } else {
        if (value) {
            _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_CALLBACK_ENABLED);
        } else {
            _rigidbody_reset_simulation_flag(rb, SIMULATIONFLAG_CALLBACK_ENABLED);
        }
    }
}

void rigidbody_set_awake(RigidBody *rb) {
    rb->awakeFlag = PHYSICS_AWAKE_FRAMES;
}

bool rigidbody_get_collider_custom(RigidBody *rb) {
    return _rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_CUSTOM_COLLIDER);
}

void rigidbody_set_collider_custom(RigidBody *rb) {
    _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_CUSTOM_COLLIDER);
}

void rigidbody_reset_collider_custom(RigidBody *rb) {
    _rigidbody_reset_simulation_flag(rb, SIMULATIONFLAG_CUSTOM_COLLIDER);
}

// MARK: - State -

bool rigidbody_is_on_ground(const RigidBody *rb) {
    return rb != NULL && utils_axes_mask_get(rb->contact, AxesMaskNY);
}

bool rigidbody_is_in_contact(const RigidBody *rb) {
    return rb != NULL && rb->contact != AxesMaskNone;
}

bool rigidbody_belongs_to_any(const RigidBody *rb, uint8_t groups) {
    return rb != NULL && rigidbody_collision_mask_match(rb->groups, groups);
}

bool rigidbody_collides_with_any(const RigidBody *rb, uint8_t groups) {
    return rb != NULL && rigidbody_collision_mask_match(rb->collidesWith, groups);
}

bool rigidbody_collides_with_rigidbody(const RigidBody *rb1, const RigidBody *rb2) {
    return rb1 != NULL && rb2 != NULL &&
           rigidbody_collision_masks_reciprocal_match(rb1->groups,
                                                      rb1->collidesWith,
                                                      rb2->groups,
                                                      rb2->collidesWith);
}

bool rigidbody_is_collider_valid(const RigidBody *rb) {
    if (rb == NULL) {
        return false;
    }

    if (rb->groups == PHYSICS_GROUP_NONE && rb->collidesWith == PHYSICS_GROUP_NONE) {
        return false;
    }

    float3 size;
    box_get_size_float(rb->collider, &size);
    return float3_isZero(&size, EPSILON_COLLISION) == false;
}

bool rigidbody_is_enabled(const RigidBody *rb) {
    return rb != NULL && _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) != Disabled;
}

bool rigidbody_is_dynamic(const RigidBody *rb) {
    return rb != NULL &&
           _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) == RigidbodyModeDynamic;
}

bool rigidbody_is_trigger(const RigidBody *rb) {
    return rb != NULL &&
           _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) == RigidbodyModeStatic &&
           (_rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_CALLBACK_ENABLED) ||
            _rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_END_CALLBACK_ENABLED));
}

// MARK: - Utils -

void rigidbody_set_default_collider(RigidBody *rb) {
    box_copy(rb->collider, &box_one);
    _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_DIRTY);
}

/// Returns whether or not the rigidbody can be considered in contact at the start of its movement
bool rigidbody_check_velocity_contact(const RigidBody *rb, const float3 *velocity) {
    if (rb->contact == AxesMaskNone) {
        return false;
    }
    const bool x = utils_axes_mask_get(rb->contact, AxesMaskX);
    const bool nx = utils_axes_mask_get(rb->contact, AxesMaskNX);
    if ((velocity->x == 0.0f && (x || nx)) || (velocity->x < 0.0f && nx) ||
        (velocity->x > 0.0f && x)) {
        return true;
    }
    const bool y = utils_axes_mask_get(rb->contact, AxesMaskY);
    const bool ny = utils_axes_mask_get(rb->contact, AxesMaskNY);
    if ((velocity->y == 0.0f && (y || ny)) || (velocity->y < 0.0f && ny) ||
        (velocity->y > 0.0f && y)) {
        return true;
    }
    const bool z = utils_axes_mask_get(rb->contact, AxesMaskZ);
    const bool nz = utils_axes_mask_get(rb->contact, AxesMaskNZ);
    if ((velocity->z == 0.0f && (z || nz)) || (velocity->z < 0.0f && nz) ||
        (velocity->z > 0.0f && z)) {
        return true;
    }
    return false;
}

bool rigidbody_check_velocity_sleep(RigidBody *rb, const float3 *velocity) {
    if (float3_isZero(velocity, EPSILON_ZERO)) {
        return true;
    }
    if (rb->contact == AxesMaskNone) {
        return false;
    }
    if (rb->awakeFlag > 0) {
        rb->awakeFlag--;
        rigidbody_non_kinematic_reset(rb);
#if DEBUG_RIGIDBODY_CALLS
        debug_rigidbody_awakes++;
#endif
        return false;
    }
    if (float_isZero(velocity->x, EPSILON_ZERO) == false) {
        const bool x = utils_axes_mask_get(rb->contact, AxesMaskX);
        const bool nx = utils_axes_mask_get(rb->contact, AxesMaskNX);
        if ((velocity->x < 0.0f && nx == false) || (velocity->x > 0.0f && x == false)) {
            return false;
        }
    }
    if (float_isZero(velocity->y, EPSILON_ZERO) == false) {
        const bool y = utils_axes_mask_get(rb->contact, AxesMaskY);
        const bool ny = utils_axes_mask_get(rb->contact, AxesMaskNY);
        if ((velocity->y < 0.0f && ny == false) || (velocity->y > 0.0f && y == false)) {
            return false;
        }
    }
    if (float_isZero(velocity->z, EPSILON_ZERO) == false) {
        const bool z = utils_axes_mask_get(rb->contact, AxesMaskZ);
        const bool nz = utils_axes_mask_get(rb->contact, AxesMaskNZ);
        if ((velocity->z < 0.0f && nz == false) || (velocity->z > 0.0f && z == false)) {
            return false;
        }
    }
    return true;
}

void rigidbody_toggle_groups(RigidBody *rb, uint8_t groups, bool toggle) {
    if (toggle) {
        rb->groups = rb->groups | groups;
    } else {
        rb->groups = rb->groups & ~groups;
    }
}

void rigidbody_toggle_collides_with(RigidBody *rb, uint8_t groups, bool toggle) {
    if (toggle) {
        rb->collidesWith = rb->collidesWith | groups;
    } else {
        rb->collidesWith = rb->collidesWith & ~groups;
    }
}

bool rigidbody_collision_mask_match(const uint8_t m1, const uint8_t m2) {
    return (m1 & m2) != PHYSICS_GROUP_NONE;
}

bool rigidbody_collision_masks_reciprocal_match(const uint8_t groups1,
                                                const uint8_t collidesWith1,
                                                const uint8_t groups2,
                                                const uint8_t collidesWith2) {

    return (collidesWith1 & groups2) != PHYSICS_GROUP_NONE ||
           (collidesWith2 & groups1) != PHYSICS_GROUP_NONE;
}

float rigidbody_get_combined_friction(const RigidBody *rb1, const float friction2) {
#if PHYSICS_COMBINE_FRICTION_FUNC == 0
    return minimum(rb1->friction, friction2);
#elif PHYSICS_COMBINE_FRICTION_FUNC == 1
    return maximum(rb1->friction, friction2);
#elif PHYSICS_COMBINE_FRICTION_FUNC == 2
    return (rb1->friction + friction2) * .5f;
#endif
}

float rigidbody_get_combined_bounciness(const RigidBody *rb1, const float bounciness2) {
#if PHYSICS_COMBINE_BOUNCINESS_FUNC == 0
    return minimum(rb1->bounciness, bounciness2);
#elif PHYSICS_COMBINE_BOUNCINESS_FUNC == 1
    return maximum(rb1->bounciness, bounciness2);
#elif PHYSICS_COMBINE_BOUNCINESS_FUNC == 2
    return (rb1->bounciness + bounciness2) * .5f;
#endif
}

float rigidbody_get_mass_push_ratio(const RigidBody *rb, const RigidBody *pushed) {
    // no push from 1x mass to full push at 2x mass or more
    return CLAMP01((rb->mass - pushed->mass) / pushed->mass);
}

void rigidbody_apply_force_impulse(RigidBody *rb, const float3 *value) {
    // keep it simple: an IMPULSE is like applying immediately one second worth of acceleration from
    // that force
    const float3 v = {value->x / rb->mass, value->y / rb->mass, value->z / rb->mass};
    float3_op_add(rb->velocity, &v);
}

void rigidbody_apply_push(RigidBody *rb, const float3 *value) {
    // a PUSH ensures a given velocity at minimum and is not additive to avoid snow-balling
    if ((value->x > 0 && value->x > rb->velocity->x) ||
        (value->x < 0 && value->x < rb->velocity->x)) {
        rb->velocity->x = value->x;
    }
    if ((value->y > 0 && value->y > rb->velocity->y) ||
        (value->y < 0 && value->y < rb->velocity->y)) {
        rb->velocity->y = value->y;
    }
    if ((value->z > 0 && value->z > rb->velocity->z) ||
        (value->z < 0 && value->z < rb->velocity->z)) {
        rb->velocity->z = value->z;
    }
}

void rigidbody_set_collision_callback(pointer_rigidbody_collision_func f) {
    rigidbody_collision_callback = f;
}

void rigidbody_set_collision_couple_callback(pointer_rigidbody_collision_func f) {
    rigidbody_collision_couple_callback = f;
}

bool rigidbody_check_end_of_contact(Transform *t1,
                                    Transform *t2,
                                    AxesMaskValue axis,
                                    uint32_t *frames,
                                    void *opaqueUserData) {

    // we drop any collision couple as soon as,
    // (1) one of the rigidbody is null (NO CALLBACK)
    // (2) both rigidbodies are non-dynamic non-trigger (NO CALLBACK)
    // (3) a max delay has passed (NO CALLBACK)
    // (4) one of the rigidbody is dynamic or trigger w/ no more contact on collision axis (CALLBACK
    // CALLED) Note: simplistic & often inaccurate but rather cost-free, and safe since obsolete or
    // impossible to resolve callbacks are just dropped
    // TODO: we can revise this later w/ more usage
    RigidBody *rb1 = transform_get_rigidbody(t1);
    RigidBody *rb2 = transform_get_rigidbody(t2);
    if (rb1 == NULL || rb2 == NULL) {
        return true; // (1)
    } else {
        const bool isValid1 = rigidbody_is_dynamic(rb1) || rigidbody_is_trigger(rb1);
        const bool isValid2 = rigidbody_is_dynamic(rb2) || rigidbody_is_trigger(rb2);
        if (isValid1 == false && isValid2 == false) {
            return true; // (2)
        } else if (*frames > PHYSICS_DISCARD_COLLISION_COUPLE) {
            return true; // (3)
        } else if ((isValid1 && utils_axes_mask_get(rb1->contact, axis) == false) ||
                   (isValid2 &&
                    utils_axes_mask_get(rb2->contact, utils_axes_mask_value_swapped(axis)) ==
                        false)) {

            if (_rigidbody_get_simulation_flag(rb1, SIMULATIONFLAG_END_CALLBACK_ENABLED)) {
                rigidbody_collision_callback(t1, rb1, t2, rb2, AxesMaskNone, opaqueUserData);
            }
            if (_rigidbody_get_simulation_flag(rb2, SIMULATIONFLAG_END_CALLBACK_ENABLED)) {
                rigidbody_collision_callback(t2, rb2, t1, rb1, AxesMaskNone, opaqueUserData);
            }
            return true; // (4)
        } else {
            *frames += 1;
            return false;
        }
    }
}

// MARK: - Debug -
#if DEBUG_RIGIDBODY

int debug_rigidbody_get_solver_iterations() {
    return debug_rigidbody_solver_iterations;
}

int debug_rigidbody_get_replacements() {
    return debug_rigidbody_replacements;
}

int debug_rigidbody_get_collisions() {
    return debug_rigidbody_collisions;
}

int debug_rigidbody_get_sleeps() {
    return debug_rigidbody_sleeps;
}

int debug_rigidbody_get_awakes() {
    return debug_rigidbody_awakes;
}

void debug_rigidbody_reset_calls() {
    debug_rigidbody_solver_iterations = 0;
    debug_rigidbody_replacements = 0;
    debug_rigidbody_collisions = 0;
    debug_rigidbody_sleeps = 0;
    debug_rigidbody_awakes = 0;
}

#endif
