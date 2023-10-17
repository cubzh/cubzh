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
#define SIMULATIONFLAG_MODE 7 // first 3 bits
#define SIMULATIONFLAG_COLLIDER_DIRTY 8
#define SIMULATIONFLAG_BEGIN_CALLBACK_ENABLED 16
#define SIMULATIONFLAG_CALLBACK_ENABLED 32
#define SIMULATIONFLAG_END_CALLBACK_ENABLED 64
#define SIMULATIONFLAG_COLLIDER_CUSTOM_SET 128

#if DEBUG_RIGIDBODY
static int debug_rigidbody_solver_iterations = 0;
static int debug_rigidbody_replacements = 0;
static int debug_rigidbody_collisions = 0;
static int debug_rigidbody_sleeps = 0;
static int debug_rigidbody_awakes = 0;
#endif

struct _RigidBody {
    // collider axis-aligned box, may be arbitrary or similar to the axis-aligned bounding box
    Box *collider;
    // pointer to r-rtree leaf, its aabb represents the space last occupied in the scene
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
    // it is a rate between 0 (full stop on contact) and 1 (full slide, no friction), or
    // below 0 (inverted movement) and above 1 (amplified movement)
    float friction;

    // bounciness represents how much force is produced in response to a collision,
    // it is a rate between 0 (no bounce) and 1 (100% of the force bounced) or above
    float bounciness;

    // collision masks
    uint16_t groups;
    uint16_t collidesWith;

    // per-axes mask where blocking contact occurred as of last physics frame
    uint8_t contact;

    // combines various simulation flags,
    // [0-1] simulation modes (2 bits)
    // [2] collider dirty
    // [3] callback enabled
    // [4] end callback enabled
    // [5-7] <unused>
    uint8_t simulationFlags;
    uint8_t awakeFlag;

    char pad[5];
};

static pointer_rigidbody_collision_func rigidbody_collision_callback = NULL;

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

void _rigidbody_reset_state(RigidBody *rb) {
    rb->contact = AxesMaskNone;
}

void _rigidbody_fire_reciprocal_callbacks(Scene *sc,
                                          RigidBody *selfRb,
                                          Transform *selfTr,
                                          RigidBody *otherRb,
                                          Transform *otherTr,
                                          float3 wNormal,
                                          void *callbackData) {

    if (rigidbody_collision_callback == NULL) {
        return;
    }

    const bool selfBegin = _rigidbody_get_simulation_flag(selfRb,
                                                          SIMULATIONFLAG_BEGIN_CALLBACK_ENABLED);
    const bool selfTick = _rigidbody_get_simulation_flag(selfRb, SIMULATIONFLAG_CALLBACK_ENABLED);
    const bool selfEnd = _rigidbody_get_simulation_flag(selfRb,
                                                        SIMULATIONFLAG_END_CALLBACK_ENABLED);
    const bool otherBegin = _rigidbody_get_simulation_flag(otherRb,
                                                           SIMULATIONFLAG_BEGIN_CALLBACK_ENABLED);
    const bool otherTick = _rigidbody_get_simulation_flag(otherRb, SIMULATIONFLAG_CALLBACK_ENABLED);
    const bool otherEnd = _rigidbody_get_simulation_flag(otherRb,
                                                         SIMULATIONFLAG_END_CALLBACK_ENABLED);

    // Skip if collision couple has no callback
    if ((selfBegin || selfTick || selfEnd || otherBegin || otherTick || otherEnd) == false) {
        return;
    }

    // Register collision couple and queue callbacks if first instance of the frame
    float3 wNormalCache = wNormal;
    const CollisionCoupleStatus status = scene_register_collision_couple(sc,
                                                                         selfTr,
                                                                         otherTr,
                                                                         &wNormalCache);
    if (status == CollisionCoupleStatus_Discard) {
        return;
    }

    // Preferably keep world normal from own trajectory if self dynamic, rather than trigger
    // overlaps
    if (rigidbody_is_dynamic(selfRb)) {
        wNormalCache = wNormal;
    }

    // (1) fire direct callbacks if enabled
    if (selfBegin || selfTick) {
        if (status == CollisionCoupleStatus_Begin) {
            rigidbody_collision_callback(CollisionCallbackType_Begin,
                                         selfTr,
                                         selfRb,
                                         otherTr,
                                         otherRb,
                                         wNormalCache,
                                         callbackData);
        }
        rigidbody_collision_callback(CollisionCallbackType_Tick,
                                     selfTr,
                                     selfRb,
                                     otherTr,
                                     otherRb,
                                     wNormalCache,
                                     callbackData);
    }

    // (2) fire reciprocal callback if applicable
    if (otherBegin || otherTick) {
        float3 negated = wNormalCache;
        float3_op_scale(&negated, -1.0f);

        if (status == CollisionCoupleStatus_Begin) {
            rigidbody_collision_callback(CollisionCallbackType_Begin,
                                         otherTr,
                                         otherRb,
                                         selfTr,
                                         selfRb,
                                         negated,
                                         callbackData);
        }
        rigidbody_collision_callback(CollisionCallbackType_Tick,
                                     otherTr,
                                     otherRb,
                                     selfTr,
                                     selfRb,
                                     negated,
                                     callbackData);
    }
}

bool _rigidbody_dynamic_tick(Scene *scene,
                             RigidBody *rb,
                             Transform *t,
                             Box *worldCollider,
                             Rtree *r,
                             const TICK_DELTA_SEC_T dt,
                             FifoList *sceneQuery,
                             void *callbackData) {

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
    const float dt_f = (float)dt;

    // ------------------------
    // APPLY CONSTANT ACCELERATION
    // ------------------------

    const float3 constantAcceleration = *scene_get_constant_acceleration(scene);

    f3 = (float3){(constantAcceleration.x + rb->constantAcceleration->x) * dt_f,
                  (constantAcceleration.y + rb->constantAcceleration->y) * dt_f,
                  (constantAcceleration.z + rb->constantAcceleration->z) * dt_f};
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

    float3 dv, normal, push3, extraReplacement3, modelDv, modelEpsilon, rtreeNormal;
    float minSwept, swept, rtreeSwept;
    float3 pos = *transform_get_position(t);
    Box broadphase, modelBox, modelBroadphase;
    Shape *shape;

    typedef struct {
        Transform *t;
        RigidBody *rb;
        const Matrix4x4 *model;
        float3 normal;
    } ContactData;
    ContactData contact; // TODO: list of contacts to handle contact ties

    // initial frame delta translation
    float3_copy(&dv, &f3);
    float3_op_scale(&dv, dt_f);

    // ----------------------
    // SOLVER ITERATIONS
    // ----------------------
    // A collision triggers a response that may fall within the same frame simulation, up to a max
    // number of solver iterations

    size_t solverCount = 0;
    while (float3_isZero(&dv, EPSILON_COLLISION) == false &&
           solverCount < PHYSICS_MAX_SOLVER_ITERATIONS) {

        minSwept = 1.0f;
        extraReplacement3 = float3_zero;
        contact.t = NULL;
        contact.rb = NULL;
        contact.model = NULL;

        box_set_broadphase_box(worldCollider, &dv, &broadphase);

        // ----------------------
        // SCENE COLLISIONS
        // ----------------------
        // test the trajectory (broadphase box) against scene colliders
        //
        // Note: currently, we perform a one-pass collision check = each moving collider against a
        // static scene. It isn't going to be accurate in case of concurring trajectories. We can
        // add a full broadphase if we see it's necessary

        // previous query should be processed entirely
        vx_assert(fifo_list_pop(sceneQuery) == NULL);

        // run collision query in r-tree w/ default inner epsilon
        if (rtree_query_overlap_box(r,
                                    &broadphase,
                                    rb->groups,
                                    rb->collidesWith,
                                    sceneQuery,
                                    -EPSILON_COLLISION) > 0) {
            RtreeNode *hit = fifo_list_pop(sceneQuery);
            Transform *hitLeaf;
            RigidBody *hitRb;
            while (hit != NULL) {
                hitLeaf = (Transform *)rtree_node_get_leaf_ptr(hit);
                vx_assert(rtree_node_is_leaf(hit));

                // self isn't removed from r-tree before query
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

                const RigidbodyMode mode = rigidbody_get_simulation_mode(hitRb);
                if (mode == RigidbodyMode_Disabled) {
                    hit = fifo_list_pop(sceneQuery);
                    continue;
                }

                const bool isTrigger = mode == RigidbodyMode_Trigger ||
                                       mode == RigidbodyMode_TriggerPerBlock;

                if (isTrigger && rigidbody_has_callbacks(hitRb) == false) {
                    hit = fifo_list_pop(sceneQuery);
                    continue;
                }

                rtreeSwept = box_swept(worldCollider,
                                       &dv,
                                       rtree_node_get_aabb(hit),
                                       &float3_epsilon_collision,
                                       true,
                                       &rtreeNormal,
                                       NULL);

                const Matrix4x4 *model = NULL;
                normal = float3_zero;

                if (mode == RigidbodyMode_Dynamic) {
                    swept = rtreeSwept;
                    normal = rtreeNormal;
                } else {
                    shape = transform_utils_get_shape(hitLeaf);

                    // solve non-dynamic rigidbodies in their model space (rotated collider)
                    const Box *collider = rigidbody_get_collider(hitRb);
                    const Matrix4x4 *invModel = transform_get_wtl(
                        shape != NULL ? shape_get_pivot_transform(shape) : hitLeaf);
                    rigidbody_broadphase_world_to_model(invModel,
                                                        worldCollider,
                                                        &modelBox,
                                                        &dv,
                                                        &modelDv,
                                                        EPSILON_COLLISION,
                                                        &modelEpsilon);

                    box_set_broadphase_box(&modelBox, &modelDv, &modelBroadphase);
                    if (box_collide(&modelBroadphase, collider)) {
                        // shapes may enable per-block collisions
                        if (shape != NULL && rigidbody_uses_per_block_collisions(hitRb)) {
                            swept = shape_box_cast(shape,
                                                   &modelBox,
                                                   &modelDv,
                                                   &modelEpsilon,
                                                   true,
                                                   &normal,
                                                   &extraReplacement3,
                                                   NULL,
                                                   NULL);
                        } else {
                            swept = box_swept(&modelBox,
                                              &modelDv,
                                              rigidbody_get_collider(hitRb),
                                              &modelEpsilon,
                                              true,
                                              &normal,
                                              NULL);
                        }

                        // if replacement, solve collision using shortest replacement between
                        // world-aligned & model-aligned
                        if (swept < 0.0f && rtreeSwept > swept) {
                            swept = rtreeSwept;
                            normal = rtreeNormal;
                        } else {
                            model = transform_get_ltw(
                                shape != NULL ? shape_get_pivot_transform(shape) : hitLeaf);
                        }
                    } else {
                        swept = 1.0f;
                    }
                }
                // earlier contact found
                if (swept < minSwept) {
                    if (isTrigger) {
                        // consider triggers here too, in case dynamic rb passes through in one
                        // frame
                        float3 wNormal;
                        if (model != NULL) {
                            matrix4x4_op_multiply_vec_vector(&wNormal, &normal, model);
                            float3_normalize(&wNormal);
                        } else {
                            wNormal = normal;
                        }

                        _rigidbody_fire_reciprocal_callbacks(scene,
                                                             rb,
                                                             t,
                                                             hitRb,
                                                             hitLeaf,
                                                             wNormal,
                                                             callbackData);
                    } else {
                        contact.t = hitLeaf;
                        contact.rb = hitRb;
                        contact.model = model;
                        contact.normal = normal;
                        minSwept = swept;
                    }
                }

                hit = fifo_list_pop(sceneQuery);
            }
        }

        // ----------------------
        // STOP MOTION THRESHOLD
        // ----------------------
        // remove superfluous movement or accumulated errors

        if (float_isZero(minSwept, PHYSICS_STOP_MOTION_THRESHOLD)) {
            minSwept = 0.0f;
        }

        // ----------------------
        // PRE-COLLISION REPLACEMENT
        // ----------------------
        // a replaced component will become "in contact" after replacement (setting swept to 0)

        if (minSwept < 0.0f /*|| float3_isZero(&extraReplacement3, EPSILON_ZERO) == false*/) {
            f3 = dv; // extraReplacement3;
            float3_op_scale(&f3, minSwept);
            minSwept = 0.0f;

#if PHYSICS_MASS_REPLACEMENTS
            // prioritize replacing inferior mass rigidbody
            if (contact.rb != NULL && rigidbody_is_dynamic(contact.rb) &&
                contact.rb->mass < rb->mass) {
                float3_op_scale(&f3, -1.0f);
                float3_op_add(contact.rb->velocity, &f3);
                rigidbody_non_kinematic_reset(contact.rb);
            } else {
                float3_op_add(&pos, &f3);
                float3_op_add(&worldCollider->min, &f3);
                float3_op_add(&worldCollider->max, &f3);
                rigidbody_non_kinematic_reset(rb);
            }
#else
            float3_op_add(&pos, &f3);
            float3_op_add(&worldCollider->min, &f3);
            float3_op_add(&worldCollider->max, &f3);
            rigidbody_non_kinematic_reset(rb);
#endif
            INC_REPLACEMENTS

#if DEBUG_RIGIDBODY_EXTRA_LOGS
            cclog_debug("🏞 rigidbody of type %d replaced w/ (%.3f, %.3f, %.3f)",
                        transform_get_type(t),
                        f3.x,
                        f3.y,
                        f3.z);
#endif
        }

        // after replacement: only in contact (==0), colliding (<1), or free movement (>= 1)
        vx_assert(minSwept >= 0.0f);

        // ----------------------
        // PRE-COLLISION MOVEMENT
        // ----------------------

        // not in contact already
        if (minSwept > 0.0f) {
            f3 = dv;
            float3_op_scale(&f3, minimum(minSwept, 1.0f));

            float3_op_add(&pos, &f3);
            float3_op_add(&worldCollider->min, &f3);
            float3_op_add(&worldCollider->max, &f3);
        }

        // ----------------------
        // COLLISION RESPONSE
        // ----------------------
        // Velocity, which is in unit/s & does not contain motion, is updated at the same time as
        // dv, which is the delta translation being processed in this solver iteration

        // collision or contact on at least one component
        if (minSwept < 1.0f) {
            // remainder of the trajectory after contact
            float3 remainder = dv;
            float3_op_scale(&remainder, 1.0f - minSwept);

            // contact world normal
            float3 wNormal;
            if (contact.model != NULL) {
                matrix4x4_op_multiply_vec_vector(&wNormal, &contact.normal, contact.model);
                float3_normalize(&wNormal);
            } else {
                wNormal = contact.normal;
            }

            // split intruding & tangential displacements
            const float intruding_mag = float3_dot_product(&remainder, &wNormal);
            const float vIntruding_mag = float3_dot_product(rb->velocity, &wNormal);
            const float3 intruding = (float3){wNormal.x * intruding_mag,
                                              wNormal.y * intruding_mag,
                                              wNormal.z * intruding_mag};
            const float3 tangential = (float3){remainder.x - intruding.x,
                                               remainder.y - intruding.y,
                                               remainder.z - intruding.z};
            const float3 vIntruding = (float3){wNormal.x * vIntruding_mag,
                                               wNormal.y * vIntruding_mag,
                                               wNormal.z * vIntruding_mag};

            // combined friction & bounciness
            const float friction = contact.rb != NULL
                                       ? rigidbody_get_combined_friction(rb, contact.rb)
                                       : rb->friction;
            const float bounciness = contact.rb != NULL
                                         ? rigidbody_get_combined_bounciness(rb, contact.rb)
                                         : rb->bounciness;

            // (1) apply combined friction on tangential displacement, assign tangential push if
            // displacement originated at least partly from own velocity, not only motion or scene
            // constant
            dv = tangential;
            float3_op_substract(rb->velocity, &vIntruding);

            float3_op_scale(&dv, friction);
            float3_op_scale(rb->velocity, friction);

            if (float3_isZero(rb->velocity, EPSILON_ZERO) == false) {
                push3 = tangential;
                // float3_op_scale(&push3, 1.0f - friction);
            } else {
                push3 = float3_zero;
            }

            // (2) apply combined bounciness on intruding displacement, add leftover to push ;
            // minor bounce responses are muffled
            const float3 vBounce = (float3){-vIntruding.x * bounciness,
                                            -vIntruding.y * bounciness,
                                            -vIntruding.z * bounciness};
            if (float3_sqr_length(&vBounce) > PHYSICS_BOUNCE_SQR_THRESHOLD) {
                const float3 bounce = (float3){-intruding.x * bounciness,
                                               -intruding.y * bounciness,
                                               -intruding.z * bounciness};

                float3_op_add(&dv, &bounce);
                float3_op_add(rb->velocity, &vBounce);

                push3.x += intruding.x * (1.0f - bounciness);
                push3.y += intruding.y * (1.0f - bounciness);
                push3.z += intruding.z * (1.0f - bounciness);
            } else {
                float3_op_add(&push3, &intruding);
            }

            // (3) apply push relative to colliding masses
            if (contact.rb != NULL && rigidbody_is_dynamic(contact.rb)) {
                const float push = rigidbody_get_mass_push_ratio(rb, contact.rb);

                push3.x *= push / dt_f;
                push3.y *= push / dt_f;
                push3.z *= push / dt_f;

                rigidbody_apply_push(contact.rb, &push3);

                // self is flagged as awake, since contact will move from push
                rigidbody_set_awake(rb);

                // TODO: inherit velocity from contact rigidbody
                /*const float inherit_push = rigidbody_get_mass_push_ratio(contact.rb, rb);
                const float inherit_mag = float3_dot_product(contact.rb->velocity, &tangential);
                const float3 inherit = (float3){
                    tangential.x * inherit_mag * (1.0f - friction),
                    tangential.y * inherit_mag * (1.0f - friction),
                    tangential.z * inherit_mag * (1.0f - friction)
                };
                rigidbody_apply_push(contact.rb, &push3);*/
            }

            // (4) reset contact mask if there was any motion, then update new contact along self's
            // box
            if (minSwept > 0.0f) {
                if (float_isZero(dv.x, EPSILON_ZERO) != false) {
                    utils_axes_mask_set(&rb->contact,
                                        (uint8_t)(dv.x > 0.0f ? AxesMaskNX : AxesMaskX),
                                        false);
                }
                if (float_isZero(dv.y, EPSILON_ZERO) != false) {
                    utils_axes_mask_set(&rb->contact,
                                        (uint8_t)(dv.y > 0.0f ? AxesMaskNY : AxesMaskY),
                                        false);
                }
                if (float_isZero(dv.z, EPSILON_ZERO) != false) {
                    utils_axes_mask_set(&rb->contact,
                                        (uint8_t)(dv.z > 0.0f ? AxesMaskNZ : AxesMaskZ),
                                        false);
                }
            }
            if (fabsf(wNormal.x) >= fabsf(wNormal.y) && fabsf(wNormal.x) >= fabsf(wNormal.z)) {
                if (wNormal.x > 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskNX, true);
                } else if (wNormal.x < 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskX, true);
                }
            }
            if (fabsf(wNormal.y) >= fabsf(wNormal.x) && fabsf(wNormal.y) >= fabsf(wNormal.z)) {
                if (wNormal.y > 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskNY, true);
                } else if (wNormal.y < 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskY, true);
                }
            }
            if (fabsf(wNormal.z) >= fabsf(wNormal.x) && fabsf(wNormal.z) >= fabsf(wNormal.y)) {
                if (wNormal.z > 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskNZ, true);
                } else if (wNormal.z < 0.0f) {
                    utils_axes_mask_set(&rb->contact, AxesMaskZ, true);
                }
            }

            // (5) fire reciprocal callbacks
            _rigidbody_fire_reciprocal_callbacks(scene,
                                                 rb,
                                                 t,
                                                 contact.rb,
                                                 contact.t,
                                                 wNormal,
                                                 callbackData);

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
    debug_rigidbody_solver_iterations += (int)solverCount;
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
                             FifoList *sceneQuery,
                             void *callbackData) {

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

        const Shape *s = transform_utils_get_shape(t);

        const Box *selfCollider = rigidbody_get_collider(rb);
        Transform *selfModelTr = transform_utils_get_model_transform(t);
        const Matrix4x4 *selfModel = transform_get_ltw(selfModelTr);
        const Matrix4x4 *selfInvModel = transform_get_wtl(selfModelTr);

        RtreeNode *hit = fifo_list_pop(sceneQuery);
        Transform *hitLeaf;
        RigidBody *hitRb;
        Box box;
        while (hit != NULL) {
            hitLeaf = (Transform *)rtree_node_get_leaf_ptr(hit);
            vx_assert(rtree_node_is_leaf(hit));

            // self isn't removed from r-tree before query
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

            const Shape *hitShape = transform_utils_get_shape(hitLeaf);

            Box hitCollider = *rigidbody_get_collider(hitRb);
            Transform *hitModelTr = transform_utils_get_model_transform(hitLeaf);
            const Matrix4x4 *hitModel = transform_get_ltw(hitModelTr);
            const Matrix4x4 *hitInvModel = transform_get_wtl(hitModelTr);

            // 1) check for overlap in self model space (ignoring hit shape per-block quality)
            box_model1_to_model2_aabox(&hitCollider,
                                       &box,
                                       hitModel,
                                       selfInvModel,
                                       &float3_zero,
                                       NoSquarify);

            bool overlap1;
            if (s != NULL && rigidbody_uses_per_block_collisions(rb)) {
                overlap1 = shape_box_overlap(s, &box, NULL);
            } else {
                overlap1 = box_collide_epsilon(&box, selfCollider, EPSILON_COLLISION);
            }

            // 2) check for overlap in hit model space (ignoring self shape per-block quality)
            box_model1_to_model2_aabox(selfCollider,
                                       &box,
                                       selfModel,
                                       hitInvModel,
                                       &float3_zero,
                                       NoSquarify);

            bool overlap2;
            if (hitShape != NULL && rigidbody_uses_per_block_collisions(hitRb)) {
                overlap2 = shape_box_overlap(hitShape, &box, &hitCollider); // out: block box
            } else {
                overlap2 = box_collide_epsilon(&box, &hitCollider, EPSILON_COLLISION);
            }

            // 3) if overlap in both spaces, trigger callbacks
            // Note: this can trigger false positives for per-block vs. per-block triggers, an
            // improvement will be to add shape vs. shape overlap
            if (overlap1 && overlap2) {
                // approximate a world normal based on boxes most overlapped axis
                const float3 overlaps = {
                    minimum(box.max.x, hitCollider.max.x) - maximum(box.min.x, hitCollider.min.x),
                    minimum(box.max.y, hitCollider.max.y) - maximum(box.min.y, hitCollider.min.y),
                    minimum(box.max.z, hitCollider.max.z) - maximum(box.min.z, hitCollider.min.z)};
                const float3 areas = {overlaps.y * overlaps.z,
                                      overlaps.x * overlaps.z,
                                      overlaps.x * overlaps.y};

                float3 normal = float3_zero;
                if (areas.x > areas.y && areas.x > areas.z) {
                    normal.x = box.max.x > hitCollider.min.x ? -1.0f : 1.0f;
                } else if (areas.y > areas.x && areas.y > areas.z) {
                    normal.y = box.max.y > hitCollider.min.y ? -1.0f : 1.0f;
                } else {
                    normal.z = box.max.z > hitCollider.min.z ? -1.0f : 1.0f;
                }
                float3 wNormal;
                matrix4x4_op_multiply_vec_vector(&wNormal, &normal, hitModel);

                _rigidbody_fire_reciprocal_callbacks(scene,
                                                     rb,
                                                     t,
                                                     hitRb,
                                                     hitLeaf,
                                                     wNormal,
                                                     callbackData);
            }

            hit = fifo_list_pop(sceneQuery);
        }
    }
}

RigidBody *rigidbody_new(const uint8_t mode, const uint16_t groups, const uint16_t collidesWith) {
    RigidBody *b = (RigidBody *)malloc(sizeof(RigidBody));
    if (b == NULL) {
        return NULL;
    }

    b->collider = box_new_copy(&box_one);
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

void rigidbody_free(RigidBody *rb) {
    if (rb == NULL) {
        return;
    }

    box_free(rb->collider);
    float3_free(rb->motion);
    float3_free(rb->velocity);
    float3_free(rb->constantAcceleration);

    free(rb);
}

void rigidbody_reset(RigidBody *rb) {
    if (rb == NULL) {
        return;
    }

    // note: rigidbody properties are persistent
    float3_set_zero(rb->motion);
    float3_set_zero(rb->velocity);

    _rigidbody_reset_state(rb);
}

void rigidbody_non_kinematic_reset(RigidBody *rb) {
    if (rb == NULL) {
        return;
    }

    _rigidbody_reset_state(rb);
}

bool rigidbody_tick(Scene *scene,
                    RigidBody *rb,
                    Transform *t,
                    Box *worldCollider,
                    Rtree *r,
                    const TICK_DELTA_SEC_T dt,
                    void *callbackData) {

    if (dt <= 0.0) {
        return false;
    }

    static FifoList *sceneQuery = NULL;
    if (sceneQuery == NULL) {
        sceneQuery = fifo_list_new();
    }

    // dynamic rigidbodies are fully simulated, their callbacks are evaluated in this loop
    // vs. other dynamic rigidbodies only
    if (rigidbody_is_dynamic(rb)) {
        return _rigidbody_dynamic_tick(scene,
                                       rb,
                                       t,
                                       worldCollider,
                                       r,
                                       dt,
                                       sceneQuery,
                                       callbackData);
    }
    // check for overlaps to fire callbacks for trigger and static rigidbodies
    else if (rigidbody_is_active_trigger(rb)) {
        _rigidbody_trigger_tick(scene, rb, t, worldCollider, r, sceneQuery, callbackData);
    }

    return false;
}

// MARK: - Accessors -

const Box *rigidbody_get_collider(const RigidBody *rb) {
    return rb->collider;
}

void rigidbody_set_collider(RigidBody *rb, const Box *value, const bool custom) {
    box_copy(rb->collider, value);
    if (_rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) != RigidbodyMode_Disabled) {
        _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_DIRTY);
    }
    if (custom) {
        _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_CUSTOM_SET);
    }
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
    rb->bounciness = maximum(value, 0.0f);
}

uint8_t rigidbody_get_contact_mask(const RigidBody *rb) {
    return rb->contact;
}

uint16_t rigidbody_get_groups(const RigidBody *rb) {
    return rb->groups;
}

void rigidbody_set_groups(RigidBody *rb, uint16_t value) {
    rb->groups = value;
}

uint16_t rigidbody_get_collides_with(const RigidBody *rb) {
    return rb->collidesWith;
}

void rigidbody_set_collides_with(RigidBody *rb, uint16_t value) {
    rb->collidesWith = value;
}

uint8_t rigidbody_get_simulation_mode(const RigidBody *rb) {
    return rb != NULL ? _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE)
                      : RigidbodyMode_Disabled;
}

void rigidbody_set_simulation_mode(RigidBody *rb, const uint8_t value) {
    const uint8_t mode = _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE);
    if (mode != value) {
        if (mode == RigidbodyMode_Dynamic) {
            rigidbody_reset(rb); // reset rigidbody when disabling simulation
        }
        _rigidbody_set_simulation_flag_value(rb, SIMULATIONFLAG_MODE, value);
#if TRANSFORM_AABOX_STATIC_COLLIDER_MODE != TRANSFORM_AABOX_DYNAMIC_COLLIDER_MODE
        if (value != RigidbodyMode_Disabled) {
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

void rigidbody_set_awake(RigidBody *rb) {
    rb->awakeFlag = PHYSICS_AWAKE_FRAMES;
}

// MARK: - State -

bool rigidbody_has_contact(const RigidBody *rb, uint8_t value) {
    return rb != NULL && utils_axes_mask_get(rb->contact, value);
}

bool rigidbody_is_in_contact(const RigidBody *rb) {
    return rb != NULL && rb->contact != AxesMaskNone;
}

bool rigidbody_belongs_to_any(const RigidBody *rb, uint16_t groups) {
    return rb != NULL && rigidbody_collision_mask_match(rb->groups, groups);
}

bool rigidbody_collides_with_any(const RigidBody *rb, uint16_t groups) {
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

    return box_is_valid(rb->collider, EPSILON_COLLISION);
}

bool rigidbody_is_enabled(const RigidBody *rb) {
    return rb != NULL &&
           _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) != RigidbodyMode_Disabled;
}

bool rigidbody_has_callbacks(const RigidBody *rb) {
    return rb != NULL &&
           (_rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_BEGIN_CALLBACK_ENABLED) ||
            _rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_CALLBACK_ENABLED) ||
            _rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_END_CALLBACK_ENABLED));
}

bool rigidbody_is_active_trigger(const RigidBody *rb) {
    return rb != NULL &&
           _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) >= RigidbodyMode_Trigger &&
           rigidbody_has_callbacks(rb);
}

bool rigidbody_is_rotation_dependent(const RigidBody *rb) {
    return rb != NULL &&
           _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) !=
               RigidbodyMode_Disabled &&
           _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) != RigidbodyMode_Dynamic;
}

bool rigidbody_is_dynamic(const RigidBody *rb) {
    return rb != NULL &&
           _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) == RigidbodyMode_Dynamic;
}

bool rigidbody_uses_per_block_collisions(const RigidBody *rb) {
    return rb != NULL && (_rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) ==
                              RigidbodyMode_TriggerPerBlock ||
                          _rigidbody_get_simulation_flag_value(rb, SIMULATIONFLAG_MODE) ==
                              RigidbodyMode_StaticPerBlock);
}

bool rigidbody_is_collider_custom_set(const RigidBody *rb) {
    return rb != NULL && _rigidbody_get_simulation_flag(rb, SIMULATIONFLAG_COLLIDER_CUSTOM_SET);
}

// MARK: - Utils -

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
        _rigidbody_reset_state(rb);
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

void rigidbody_toggle_groups(RigidBody *rb, uint16_t groups, bool toggle) {
    if (toggle) {
        rb->groups = rb->groups | groups;
    } else {
        rb->groups = rb->groups & ~groups;
    }
}

void rigidbody_toggle_collides_with(RigidBody *rb, uint16_t groups, bool toggle) {
    if (toggle) {
        rb->collidesWith = rb->collidesWith | groups;
    } else {
        rb->collidesWith = rb->collidesWith & ~groups;
    }
}

bool rigidbody_collision_mask_match(const uint16_t m1, const uint16_t m2) {
    return (m1 & m2) != PHYSICS_GROUP_NONE;
}

bool rigidbody_collision_masks_reciprocal_match(const uint16_t groups1,
                                                const uint16_t collidesWith1,
                                                const uint16_t groups2,
                                                const uint16_t collidesWith2) {

    return (collidesWith1 & groups2) != PHYSICS_GROUP_NONE ||
           (collidesWith2 & groups1) != PHYSICS_GROUP_NONE;
}

float rigidbody_get_combined_friction(const RigidBody *rb1, const RigidBody *rb2) {
#if PHYSICS_COMBINE_FRICTION_FUNC == 0
    return minimum(rb1->friction, rb2->friction);
#elif PHYSICS_COMBINE_FRICTION_FUNC == 1
    return maximum(rb1->friction, rb2->friction);
#elif PHYSICS_COMBINE_FRICTION_FUNC == 2
    return (rb1->friction + rb2->friction) * .5f;
#endif
}

float rigidbody_get_combined_bounciness(const RigidBody *rb1, const RigidBody *rb2) {
#if PHYSICS_COMBINE_BOUNCINESS_FUNC == 0
    return minimum(rb1->bounciness, rb2->bounciness);
#elif PHYSICS_COMBINE_BOUNCINESS_FUNC == 1
    return maximum(rb1->bounciness, rb2->bounciness);
#elif PHYSICS_COMBINE_BOUNCINESS_FUNC == 2
    return (rb1->bounciness + rb2->bounciness) * .5f;
#endif
}

float rigidbody_get_mass_push_ratio(const RigidBody *rb, const RigidBody *pushed) {
    return CLAMP01(rb->mass / pushed->mass - PHYSICS_MASS_PUSH_THRESHOLD);
}

void rigidbody_apply_force_impulse(RigidBody *rb, const float3 *value) {
    // keep it simple: an IMPULSE is like applying immediately one second worth of acceleration from
    // that force
    const float3 v = {value->x / rb->mass, value->y / rb->mass, value->z / rb->mass};
    float3_op_add(rb->velocity, &v);
}

void rigidbody_apply_push(RigidBody *rb, const float3 *value) {
    // a PUSH ensures a given velocity at minimum and is not additive, to emulate the principle of
    // both objects possibly moving already in the same direction
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

void rigidbody_broadphase_world_to_model(const Matrix4x4 *invModel,
                                         const Box *worldBox,
                                         Box *outBox,
                                         const float3 *worldVector,
                                         float3 *outVector,
                                         float epsilon,
                                         float3 *outEpsilon3) {

    box_to_aabox2(worldBox, outBox, invModel, &float3_zero, NoSquarify);
    matrix4x4_op_multiply_vec_vector(outVector, worldVector, invModel);
    const float3 epsilon3 = (float3){epsilon, epsilon, epsilon};
    matrix4x4_op_multiply_vec_vector(outEpsilon3, &epsilon3, invModel);
}

// MARK: - Callbacks -

void rigidbody_set_collision_callback(pointer_rigidbody_collision_func f) {
    rigidbody_collision_callback = f;
}

void rigidbody_fire_reciprocal_collision_end_callback(Transform *self,
                                                      Transform *other,
                                                      void *callbackData) {
    if (rigidbody_collision_callback == NULL) {
        return;
    }

    RigidBody *selfRb = transform_get_rigidbody(self);
    RigidBody *otherRb = transform_get_rigidbody(other);
    vx_assert(selfRb != NULL && otherRb != NULL);

    if (_rigidbody_get_simulation_flag(selfRb, SIMULATIONFLAG_END_CALLBACK_ENABLED)) {
        rigidbody_collision_callback(CollisionCallbackType_End,
                                     self,
                                     selfRb,
                                     other,
                                     otherRb,
                                     float3_zero,
                                     callbackData);
    }
    if (_rigidbody_get_simulation_flag(otherRb, SIMULATIONFLAG_END_CALLBACK_ENABLED)) {
        rigidbody_collision_callback(CollisionCallbackType_End,
                                     other,
                                     otherRb,
                                     self,
                                     selfRb,
                                     float3_zero,
                                     callbackData);
    }
}

void rigidbody_toggle_collision_callback(RigidBody *rb, CollisionCallbackType type, bool value) {
    switch (type) {
        case CollisionCallbackType_Begin:
            if (value) {
                _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_BEGIN_CALLBACK_ENABLED);
            } else {
                _rigidbody_reset_simulation_flag(rb, SIMULATIONFLAG_BEGIN_CALLBACK_ENABLED);
            }
            break;
        case CollisionCallbackType_Tick:
            if (value) {
                _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_CALLBACK_ENABLED);
            } else {
                _rigidbody_reset_simulation_flag(rb, SIMULATIONFLAG_CALLBACK_ENABLED);
            }
            break;
        case CollisionCallbackType_End:
            if (value) {
                _rigidbody_set_simulation_flag(rb, SIMULATIONFLAG_END_CALLBACK_ENABLED);
            } else {
                _rigidbody_reset_simulation_flag(rb, SIMULATIONFLAG_END_CALLBACK_ENABLED);
            }
            break;
    }
}

// MARK: - Debug -
#if DEBUG_RIGIDBODY

int debug_rigidbody_get_solver_iterations(void) {
    return debug_rigidbody_solver_iterations;
}

int debug_rigidbody_get_replacements(void) {
    return debug_rigidbody_replacements;
}

int debug_rigidbody_get_collisions(void) {
    return debug_rigidbody_collisions;
}

int debug_rigidbody_get_sleeps(void) {
    return debug_rigidbody_sleeps;
}

int debug_rigidbody_get_awakes(void) {
    return debug_rigidbody_awakes;
}

void debug_rigidbody_reset_calls(void) {
    debug_rigidbody_solver_iterations = 0;
    debug_rigidbody_replacements = 0;
    debug_rigidbody_collisions = 0;
    debug_rigidbody_sleeps = 0;
    debug_rigidbody_awakes = 0;
}

#endif
