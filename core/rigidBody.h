// -------------------------------------------------------------
//  Cubzh Core
//  rigidBody.h
//  Created by Adrien Duermael on April 8, 2021.
// -------------------------------------------------------------

#pragma once

#include "box.h"
#include "config.h"
#include "rtree.h"
#include "transform.h"
#include "utils.h"

#ifdef __cplusplus
extern "C" {
#endif

#if DEBUG
#define DEBUG_RIGIDBODY true
#else
#define DEBUG_RIGIDBODY false
#endif
#if DEBUG_RIGIDBODY
/// Count number of solver iterations, replacements & collisions per frame
#define DEBUG_RIGIDBODY_CALLS true
#define DEBUG_RIGIDBODY_EXTRA_LOGS false
#else
#define DEBUG_RIGIDBODY_CALLS false
#define DEBUG_RIGIDBODY_EXTRA_LOGS false
#endif

typedef struct _RigidBody RigidBody;
typedef struct _Transform Transform;
typedef struct _Scene Scene;
typedef struct float3 float3;

typedef enum {
    // this rigidbody does not contribute to any collision and is not simulated
    Disabled,
    // this rigidbody may contribute to collisions but is not simulated
    RigidbodyModeStatic,
    // this rigibody is simulated
    RigidbodyModeDynamic
} RigidbodyMode;

typedef void (*pointer_rigidbody_collision_func)(Transform *self,
                                                 RigidBody *selfRb,
                                                 Transform *other,
                                                 RigidBody *otherRb,
                                                 AxesMaskValue selfAxis,
                                                 void *opaqueUserData);

/// MARK: - Lifecycle -
RigidBody *rigidbody_new(const uint8_t mode, const uint8_t groups, const uint8_t collidesWith);
void rigidbody_free(RigidBody *b);
void rigidbody_reset(RigidBody *b);
void rigidbody_non_kinematic_reset(RigidBody *b);
bool rigidbody_tick(Scene *scene,
                    RigidBody *rb,
                    Transform *t,
                    Box *worldCollider,
                    Rtree *r,
                    const TICK_DELTA_SEC_T dt,
                    void *opaqueUserData);

/// MARK: - Accessors -
const Box *rigidbody_get_collider(const RigidBody *rb);
void rigidbody_set_collider(RigidBody *rb, const Box *value);
RtreeNode *rigidbody_get_rtree_leaf(const RigidBody *rb);
void rigidbody_set_rtree_leaf(RigidBody *rb, RtreeNode *leaf);
const float3 *rigidbody_get_motion(const RigidBody *rb);
void rigidbody_set_motion(RigidBody *rb, const float3 *value);
const float3 *rigidbody_get_velocity(const RigidBody *rb);
void rigidbody_set_velocity(RigidBody *rb, const float3 *value);
const float3 *rigidbody_get_constant_acceleration(const RigidBody *rb);
void rigidbody_set_constant_acceleration(RigidBody *rb, const float3 *value);
float rigidbody_get_mass(const RigidBody *rb);
void rigidbody_set_mass(RigidBody *rb, const float value);
float rigidbody_get_friction(const RigidBody *rb);
void rigidbody_set_friction(RigidBody *rb, const float value);
float rigidbody_get_bounciness(const RigidBody *rb);
void rigidbody_set_bounciness(RigidBody *rb, const float value);
uint8_t rigidbody_get_contact_mask(const RigidBody *rb);
void rigidbody_set_contact_mask(RigidBody *rb, const uint8_t value);
uint8_t rigidbody_get_groups(const RigidBody *rb);
void rigidbody_set_groups(RigidBody *rb, const uint8_t value);
uint8_t rigidbody_get_collides_with(const RigidBody *rb);
void rigidbody_set_collides_with(RigidBody *rb, const uint8_t value);
uint8_t rigidbody_get_simulation_mode(const RigidBody *rb);
void rigidbody_set_simulation_mode(RigidBody *rb, const uint8_t value);
bool rigidbody_get_collider_dirty(const RigidBody *rb);
void rigidbody_reset_collider_dirty(RigidBody *rb);
void rigidbody_toggle_collision_callback(RigidBody *rb, bool value, bool end);
void rigidbody_set_awake(RigidBody *rb);
bool rigidbody_get_collider_custom(RigidBody *rb);
void rigidbody_set_collider_custom(RigidBody *rb);
void rigidbody_reset_collider_custom(RigidBody *rb);

/// MARK: - State -
bool rigidbody_is_on_ground(const RigidBody *rb);
bool rigidbody_is_in_contact(const RigidBody *rb);
bool rigidbody_belongs_to_any(const RigidBody *rb, uint8_t groups);
bool rigidbody_collides_with_any(const RigidBody *rb, uint8_t groups);
bool rigidbody_collides_with_rigidbody(const RigidBody *rb1, const RigidBody *rb2);
bool rigidbody_is_collider_valid(const RigidBody *rb);
bool rigidbody_is_enabled(const RigidBody *rb);
bool rigidbody_is_dynamic(const RigidBody *rb);
bool rigidbody_is_trigger(
    RigidBody *rb); // a static rigidbody w/ collision callback(s) enabled is a trigger

/// MARK: - Utils -
void rigidbody_set_default_collider(RigidBody *rb);
bool rigidbody_check_velocity_contact(const RigidBody *rb, const float3 *velocity);
bool rigidbody_check_velocity_sleep(RigidBody *rb, const float3 *velocity);
void rigidbody_toggle_groups(RigidBody *rb, uint8_t groups, bool toggle);
void rigidbody_toggle_collides_with(RigidBody *rb, uint8_t groups, bool toggle);
bool rigidbody_collision_mask_match(const uint8_t m1, const uint8_t m2);
bool rigidbody_collision_masks_reciprocal_match(const uint8_t groups1,
                                                const uint8_t collidesWith1,
                                                const uint8_t groups2,
                                                const uint8_t collidesWith2);
float rigidbody_get_combined_friction(const RigidBody *rb1, const float friction2);
float rigidbody_get_combined_bounciness(const RigidBody *rb1, const float bounciness2);
float rigidbody_get_mass_push_ratio(const RigidBody *rb, const RigidBody *pushed);
void rigidbody_apply_force_impulse(RigidBody *rb, const float3 *value);
void rigidbody_apply_push(RigidBody *rb, const float3 *value);

/// MARK: - Callbacks -
void rigidbody_set_collision_callback(pointer_rigidbody_collision_func f);
void rigidbody_set_collision_couple_callback(pointer_rigidbody_collision_func f);
bool rigidbody_check_end_of_contact(Transform *t1,
                                    Transform *t2,
                                    AxesMaskValue axis,
                                    uint32_t *frames,
                                    void *opaqueUserData);

/// MARK: - Debug -
#if DEBUG_RIGIDBODY
int debug_rigidbody_get_solver_iterations(void);
int debug_rigidbody_get_replacements(void);
int debug_rigidbody_get_collisions(void);
int debug_rigidbody_get_sleeps(void);
int debug_rigidbody_get_awakes(void);
void debug_rigidbody_reset_calls(void);
#endif

#ifdef __cplusplus
} // extern "C"
#endif
