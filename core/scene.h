// -------------------------------------------------------------
//  Cubzh Core
//  scene.h
//  Created by Gaetan de Villele on May 14, 2019.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "fifo_list.h"
#include "rigidBody.h"
#include "rtree.h"
#include "shape.h"
#include "utils.h"

#if DEBUG
#define DEBUG_SCENE true
#else
#define DEBUG_SCENE false
#endif
#if DEBUG_SCENE
#define DEBUG_SCENE_CALLS true
#define DEBUG_SCENE_EXTRALOG false
#else
#define DEBUG_SCENE_CALLS false
#define DEBUG_SCENE_EXTRALOG false
#endif

/// A scene owns the root transform and provides helpers to the transforms hierarchy,
/// within which every transform is parented.
///
/// The map is parented to scene root, everything else can be arbitrary.
///
typedef struct _Scene Scene;

Scene *scene_new(Weakptr *g);
void scene_free(Scene *sc);
Weakptr *scene_get_weakptr(Scene *sc);
Weakptr *scene_get_and_retain_weakptr(Scene *sc);

/// Get the scene hierarchy root transform for more specific usages
Transform *scene_get_root(Scene *sc);
Transform *scene_get_system_root(Scene *sc);
Rtree *scene_get_rtree(Scene *sc);

/// FRAME REFRESH ORDER:
/// - physics and core tick+refresh (this function)
/// - scripting tick
/// - end-of-frame refresh
void scene_refresh(Scene *sc, const TICK_DELTA_SEC_T dt, void *callbackData);

/// End-of-frame refresh performs a final refresh after sandbox changes, enqueues transform for
/// sync, and refreshes shape buffers to be ready for rendering
///
/// FRAME REFRESH ORDER:
/// - physics and core tick+refresh
/// - scripting tick
/// - end-of-frame refresh (this function)
void scene_end_of_frame_refresh(Scene *sc, void *callbackData);
/// A standalone refresh can be called to solely refresh transforms in special cases where waiting
/// for end-of-frame isn't an option, overall it should be avoided
void scene_standalone_refresh(Scene *sc);

/// Creates, populates and returns an iterator containing all the shapes of the scene
/// The caller is responsible for freeing the returned list
DoublyLinkedList *scene_new_shapes_iterator(Scene *sc);

/// Parents or unparents a Map transform to the scene root
void scene_add_map(Scene *sc, Shape *m);
Transform *scene_get_map(Scene *sc);

/// Safely removes transform from the scene hierarchy
/// Transforms removed from hierarchy are kept alive for an additional frame allowing for removal
/// in all appropriate systems (r-tree, sync, etc). We may register for removal even tentatively,
/// and if the transform is re-added to the hierarchy in the same frame, removal is cancelled
bool scene_remove_transform(Scene *sc, Transform *t, const bool keepWorld);
/// Managed transforms have resources associated to their IDs, which need to be freed when their
/// transform is freed. Setting a managed ptr will toggle transform's destroy callback
void scene_register_managed_transform(Scene *sc, Transform *t);

typedef enum CollisionCoupleStatus {
    CollisionCoupleStatus_Begin,
    CollisionCoupleStatus_Tick,
    CollisionCoupleStatus_Discard
} CollisionCoupleStatus;
CollisionCoupleStatus scene_register_collision_couple(Scene *sc,
                                                      Transform *t1,
                                                      Transform *t2,
                                                      float3 *wNormal);

// MARK: - Physics -

void scene_set_constant_acceleration(Scene *sc, const float *x, const float *y, const float *z);
const float3 *scene_get_constant_acceleration(const Scene *sc);

/// Register a volume that will be processed during the awake phase
void scene_register_awake_box(Scene *sc, Box *b);
void scene_register_awake_rigidbody_contacts(Scene *sc, RigidBody *rb);
void scene_register_awake_block_box(Scene *sc,
                                    const Shape *shape,
                                    const SHAPE_COORDS_INT_T x,
                                    const SHAPE_COORDS_INT_T y,
                                    const SHAPE_COORDS_INT_T z);

typedef enum {
    Hit_None,
    Hit_Block,
    Hit_CollisionBox
} HitType;

typedef struct {
    Transform *hitTr;
    Block *block;
    float distance;
    HitType type;
    SHAPE_COORDS_INT3_T blockCoords;
    FACE_INDEX_INT_T faceTouched; // of the block if any (model space)

    char pad[1];
} CastResult;
CastResult scene_cast_result_default(void);

typedef struct {
    Transform *hitTr;
    HitType type;

    char pad[4];
} OverlapResult;

HitType scene_cast_ray(Scene *sc,
                       const Ray *worldRay,
                       uint16_t groups,
                       const DoublyLinkedList *filterOutTransforms,
                       CastResult *result);
size_t scene_cast_all_ray(Scene *sc,
                          const Ray *worldRay,
                          uint16_t groups,
                          const DoublyLinkedList *filterOutTransforms,
                          DoublyLinkedList *results);
Block *scene_cast_ray_shape_only(Scene *sc,
                                 const Shape *sh,
                                 const Ray *worldRay,
                                 CastResult *result);
HitType scene_cast_box(Scene *sc,
                       const Box *aabb,
                       const float3 *unit,
                       float maxDist,
                       uint16_t groups,
                       const DoublyLinkedList *filterOutTransforms,
                       CastResult *result);
size_t scene_cast_all_box(Scene *sc,
                          const Box *aabb,
                          const float3 *unit,
                          float maxDist,
                          uint16_t groups,
                          const DoublyLinkedList *filterOutTransforms,
                          DoublyLinkedList *results);
bool scene_overlap_box(Scene *sc,
                       const Box *aabb,
                       uint16_t groups,
                       uint16_t collidesWith,
                       const DoublyLinkedList *filterOutTransforms,
                       FifoList *results);

// MARK: - Debug -
#if DEBUG_RIGIDBODY
int debug_scene_get_awake_queries(void);
void debug_scene_reset_calls(void);
#endif

#ifdef __cplusplus
} // extern "C"
#endif
