// -------------------------------------------------------------
//  Cubzh Core
//  scene.c
//  Created by Gaetan de Villele on May 14, 2019.
// -------------------------------------------------------------

#include "scene.h"

#include <stdlib.h>
#include <float.h>

#include "weakptr.h"

#if DEBUG_SCENE
static int debug_scene_awake_queries = 0;
#endif

struct _Scene {
    Transform *root;
    Transform *map; // weak ref to Map transform (Shape retained by parent)
    Rtree *rtree;

    // transforms potentially removed from scene since last end-of-frame,
    // relevant for physics & sync, internal transforms do not need to be accounted for here
    FifoList *removed;

    // rigidbody couples registered & waiting for a call to end-of-collision callback
    DoublyLinkedList *collisions;

    // awake volumes can be registered for end-of-frame awake phase
    DoublyLinkedList *awakeBoxes;

    // constant acceleration for the whole Scene (gravity usually)
    float3 constantAcceleration;
};

typedef struct {
    Weakptr *t1, *t2;
    AxesMaskValue axis;
    uint32_t frames;
} _CollisionCouple;

void _scene_add_rigidbody_rtree(Scene *sc, RigidBody *rb, Transform *t, Box *collider) {
    rigidbody_set_rtree_leaf(rb,
                             rtree_create_and_insert(sc->rtree,
                                                     collider,
                                                     rigidbody_get_groups(rb),
                                                     rigidbody_get_collides_with(rb),
                                                     t));
}

void _scene_update_rtree(Scene *sc, RigidBody *rb, Transform *t, Box *collider) {
    // register awake volume here for new and removed colliders, and for transformations change
    if (rigidbody_is_enabled(rb) && rigidbody_is_collider_valid(rb)) {
        // insert valid collider as a new leaf
        if (rigidbody_get_rtree_leaf(rb) == NULL) {
            _scene_add_rigidbody_rtree(sc, rb, t, collider);
            scene_register_awake_rigidbody_contacts(sc, rb);
        }
        // update leaf due to collider or transformations change
        else if (rigidbody_get_collider_dirty(rb) || transform_is_physics_dirty(t)) {
            scene_register_awake_rigidbody_contacts(sc, rb);
            rtree_remove(sc->rtree, rigidbody_get_rtree_leaf(rb));
            rigidbody_set_rtree_leaf(rb, NULL);

            _scene_add_rigidbody_rtree(sc, rb, t, collider);
            scene_register_awake_rigidbody_contacts(sc, rb);
        }
    }
    // remove disabled rigidbody or invalid collider from rtree
    else if (rigidbody_get_rtree_leaf(rb) != NULL) {
        scene_register_awake_rigidbody_contacts(sc, rb);
        rtree_remove(sc->rtree, rigidbody_get_rtree_leaf(rb));
        rigidbody_set_rtree_leaf(rb, NULL);
    }

    rigidbody_reset_collider_dirty(rb);
    transform_reset_physics_dirty(t);
}

void _scene_refresh_rtree_collision_masks(RigidBody *rb) {
    RtreeNode *rbLeaf = rigidbody_get_rtree_leaf(rb);

    // refresh collision masks if in the rtree
    if (rbLeaf != NULL) {
        const uint8_t groups = rigidbody_get_groups(rb);
        const uint8_t collidesWith = rigidbody_get_collides_with(rb);
        if (groups != rtree_node_get_groups(rbLeaf) ||
            collidesWith != rtree_node_get_collides_with(rbLeaf)) {

            rtree_node_set_collision_masks(rbLeaf, groups, collidesWith);
        }
    }
}

void _scene_refresh_recurse(Scene *sc,
                            Transform *t,
                            bool hierarchyDirty,
                            const TICK_DELTA_SEC_T dt,
                            void *callbackData) {

    // Refresh transform (top-first) after sandbox changes
    transform_refresh(t, hierarchyDirty, false);

    // Get rigidbody, compute world collider
    Box collider;
    RigidBody *rb = transform_get_or_compute_world_aligned_collider(t, &collider);

    // Step physics (top-first), collider is kept up-to-date
    if (rb != NULL) {
        rigidbody_tick(sc, rb, t, &collider, sc->rtree, dt, callbackData);
    }

    // Refresh transform (top-first) after changes
    transform_refresh(t, false, false);

    // Update r-tree (top-first) after changes
    if (rb != NULL) {
        transform_get_or_compute_world_aligned_collider(t, &collider);
        _scene_update_rtree(sc, rb, t, &collider);
    }

    // Recurse down the branch
    // ⬆ anything above recursion is executed TOP-FIRST
    DoublyLinkedListNode *n = transform_get_children_iterator(t);
    while (n != NULL) {
        _scene_refresh_recurse(sc,
                               (Transform *)doubly_linked_list_node_pointer(n),
                               hierarchyDirty || transform_is_hierarchy_dirty(t),
                               dt,
                               callbackData);
        n = doubly_linked_list_node_next(n);
    }
    // ⬇ anything after recursion is executed DEEP-FIRST

    // Clear intra-frame refresh flags (deep-first)
    transform_refresh_children_done(t);
}

void _scene_end_of_frame_refresh_recurse(Scene *sc, Transform *t, bool hierarchyDirty) {
    // Transform ends the frame inside scene hierarchy
    transform_set_scene_dirty(t, false);
    transform_set_is_in_scene(t, true);

    // Refresh transform (top-first) after sandbox changes
    transform_refresh(t, hierarchyDirty, false);

    // Apply shape current transaction (top-first), this may change BB & collider
    if (transform_get_type(t) == ShapeTransform) {
        shape_apply_current_transaction(transform_utils_get_shape(t), false);
    }

    // Update r-tree (top-first) after sandbox changes
    Box collider;
    RigidBody *rb = transform_get_or_compute_world_aligned_collider(t, &collider);
    if (rb != NULL) {
        _scene_update_rtree(sc, rb, t, &collider);
        _scene_refresh_rtree_collision_masks(rb);
    }

    // Recurse down the branch
    // ⬆ anything above recursion is executed TOP-FIRST
    DoublyLinkedListNode *n = transform_get_children_iterator(t);
    while (n != NULL) {
        _scene_end_of_frame_refresh_recurse(sc,
                                            (Transform *)doubly_linked_list_node_pointer(n),
                                            hierarchyDirty || transform_is_hierarchy_dirty(t));
        n = doubly_linked_list_node_next(n);
    }
    // ⬇ anything after recursion is executed DEEP-FIRST

    // Clear intra-frame refresh flags (deep-first)
    transform_refresh_children_done(t);

#ifndef P3S_CLIENT_HEADLESS
    // Refresh shape buffers (deep-first)
    if (transform_get_type(t) == ShapeTransform) {
        shape_refresh_vertices(transform_utils_get_shape(t));
    }
#endif
}

void _scene_shapes_iterator_func(Transform *t, void *ptr) {
    if (transform_get_type(t) == ShapeTransform) {
        doubly_linked_list_push_last((DoublyLinkedList *)ptr, (Shape *)transform_get_ptr(t));
    }
}

void _scene_standalone_refresh_func(Transform *t, void *ptr) {
    if (transform_get_type(t) == ShapeTransform) {
        shape_apply_current_transaction(transform_utils_get_shape(t), true);
    }
    transform_refresh(t, true, false);
}

bool _scene_cast_result_sort_func(DoublyLinkedListNode *n1, DoublyLinkedListNode *n2) {
    return ((RtreeCastResult*)doubly_linked_list_node_pointer(n1))->distance > ((RtreeCastResult*)doubly_linked_list_node_pointer(n2))->distance;
}

// MARK: -

Scene *scene_new(void) {
    Scene *sc = (Scene *)malloc(sizeof(Scene));
    if (sc != NULL) {
        sc->root = transform_make(HierarchyTransform);
        sc->map = NULL;
        sc->rtree = rtree_new(RTREE_NODE_MIN_CAPACITY, RTREE_NODE_MAX_CAPACITY);
        sc->removed = fifo_list_new();
        sc->collisions = doubly_linked_list_new();
        sc->awakeBoxes = doubly_linked_list_new();
        float3_set(&sc->constantAcceleration, 0.0f, 0.0f, 0.0f);
    }
    return sc;
}

void scene_free(Scene *sc) {
    if (sc == NULL) {
        return;
    }

    Transform *t = (Transform *)fifo_list_pop(sc->removed);
    while (t != NULL) {
        transform_release(t); // from scene_register_removed_transform
        t = (Transform *)fifo_list_pop(sc->removed);
    }

    transform_release(sc->root);
    rtree_free(sc->rtree);
    fifo_list_free(sc->removed, NULL);
    doubly_linked_list_free(sc->collisions);
    doubly_linked_list_flush(sc->awakeBoxes, (pointer_free_function)box_free);
    doubly_linked_list_free(sc->awakeBoxes);

    free(sc);
}

Transform *scene_get_root(Scene *sc) {
    return sc->root;
}

Rtree *scene_get_rtree(Scene *sc) {
    return sc->rtree;
}

void scene_refresh(Scene *sc, const TICK_DELTA_SEC_T dt, void *callbackData) {
    if (sc == NULL) {
        return;
    }
#if DEBUG_RIGIDBODY_EXTRA_LOGS
    cclog_debug("🏞 physics step");
#endif
    _scene_refresh_recurse(sc,
                           sc->root,
                           transform_is_hierarchy_dirty(sc->root),
                           dt,
                           callbackData);
}

void scene_end_of_frame_refresh(Scene *sc, void *opaqueUserData) {
    if (sc == NULL) {
        return;
    }

    _scene_end_of_frame_refresh_recurse(sc, sc->root, transform_is_hierarchy_dirty(sc->root));

#if DEBUG_RTREE_CHECK
    vx_assert(debug_rtree_integrity_check(sc->rtree));
#endif

    // process transforms removal from hierarchy
    Transform *t = (Transform *)fifo_list_pop(sc->removed);
    DoublyLinkedListNode *n = NULL;
    Transform *child = NULL;
    RigidBody *rb = NULL;
    while (t != NULL) {
        // if still outside of hierarchy at end-of-frame, proceed with removal
        if (transform_is_scene_dirty(t)) {
            // enqueue children for r-tree leaf removal
            n = transform_get_children_iterator(t);
            while (n != NULL) {
                child = doubly_linked_list_node_pointer(n);

                transform_set_scene_dirty(child, true);
                scene_register_removed_transform(sc, child);

                n = doubly_linked_list_node_next(n);
            }

            // r-tree leaf removal
            rb = transform_get_rigidbody(t);
            if (rb != NULL && rigidbody_get_rtree_leaf(rb) != NULL) {
                rtree_remove(sc->rtree, rigidbody_get_rtree_leaf(rb));
                rigidbody_set_rtree_leaf(rb, NULL);
            }

            transform_set_scene_dirty(t, false);
            transform_set_is_in_scene(t, false);
        }
        transform_release(t); // from scene_register_removed_transform

        t = (Transform *)fifo_list_pop(sc->removed);
    }

    // process collision couples for end-of-contact callback
    n = doubly_linked_list_first(sc->collisions);
    _CollisionCouple *cc = NULL;
    Transform *t2 = NULL;
    while (n != NULL) {
        cc = (_CollisionCouple *)doubly_linked_list_node_pointer(n);
        t = weakptr_get(cc->t1);
        t2 = weakptr_get(cc->t2);

        if (t == NULL || t2 == NULL ||
            rigidbody_check_end_of_contact(t, t2, cc->axis, &cc->frames, opaqueUserData)) {
            weakptr_release(cc->t1);
            weakptr_release(cc->t2);
            free(cc);

            DoublyLinkedListNode *next = doubly_linked_list_node_next(n);
            doubly_linked_list_delete_node(sc->collisions, n);
            n = next;
        } else {
            n = doubly_linked_list_node_next(n);
        }
    }

    // awake phase
    FifoList *awakeQuery = fifo_list_new();
    Box *awakeBox;
    n = doubly_linked_list_first(sc->awakeBoxes);
    while (n != NULL) {
        // TODO: save groups in the list
        awakeBox = (Box *)doubly_linked_list_node_pointer(n);

        vx_assert(fifo_list_pop(awakeQuery) == NULL);
        if (rtree_query_overlap_box(sc->rtree,
                                    awakeBox,
                                    PHYSICS_GROUP_ALL,
                                    PHYSICS_GROUP_ALL,
                                    awakeQuery,
                                    EPSILON_COLLISION) > 0) {
            RtreeNode *hit = fifo_list_pop(awakeQuery);
            Transform *hitLeaf = NULL;
            RigidBody *hitRb = NULL;
            while (hit != NULL) {
                hitLeaf = (Transform *)rtree_node_get_leaf_ptr(hit);
                vx_assert(rtree_node_is_leaf(hit));

                hitRb = transform_get_rigidbody(hitLeaf);
                vx_assert(hitRb != NULL);

                rigidbody_set_awake(hitRb);

                hit = fifo_list_pop(awakeQuery);
            }
#if DEBUG_SCENE_CALLS
            debug_scene_awake_queries++;
#endif
        }

        DoublyLinkedListNode *next = doubly_linked_list_node_next(n);
        doubly_linked_list_delete_node(sc->awakeBoxes, n);
        n = next;
        box_free(awakeBox);
    }
    fifo_list_free(awakeQuery, NULL);

    // physics layers mask changes take effect in the rtree at the end of each frame
    rtree_refresh_collision_masks(sc->rtree);
}

void scene_standalone_refresh(Scene *sc) {
    transform_recurse(sc->root, _scene_standalone_refresh_func, NULL, false);
}

DoublyLinkedList *scene_new_shapes_iterator(Scene *sc) {
    DoublyLinkedList *list = doubly_linked_list_new();
    transform_recurse(sc->root, _scene_shapes_iterator_func, list, true);
    return list;
}

void scene_add_map(Scene *sc, Shape *map) {
    vx_assert(sc != NULL);
    vx_assert(map != NULL);

    if (sc->map != NULL) {
        transform_remove_parent(sc->map, true);
    }

    sc->map = shape_get_root_transform(map);
    transform_set_parent(sc->map, sc->root, true);

#if DEBUG_SCENE_EXTRALOG
    cclog_debug("🏞 map added to the scene");
#endif
}

Transform *scene_get_map(Scene *sc) {
    return sc->map;
}

void scene_remove_map(Scene *sc) {
    vx_assert(sc != NULL);

    if (sc->map != NULL) {
        transform_remove_parent(sc->map, true);
        sc->map = NULL;
    }

#if DEBUG_SCENE_EXTRALOG
    cclog_debug("🏞 map removed from the scene");
#endif
}

void scene_remove_transform(Scene *sc, Transform *t) {
    vx_assert(sc != NULL);
    if (t == NULL)
        return;

    scene_register_removed_transform(sc, t);
    transform_remove_parent(t, true);

#if DEBUG_SCENE_EXTRALOG
    cclog_debug("🏞 transform removed from the scene");
#endif
}

void scene_register_removed_transform(Scene *sc, Transform *t) {
    if (sc == NULL || t == NULL) {
        return;
    }

    transform_retain(t);
    fifo_list_push(sc->removed, t);
}

void scene_register_collision_couple(Scene *sc, Transform *t1, Transform *t2, AxesMaskValue axis) {
    if (sc == NULL || t1 == NULL || t2 == NULL) {
        return;
    }

    _CollisionCouple *cc = (_CollisionCouple *)malloc(sizeof(_CollisionCouple));
    if (cc == NULL) {
        return;
    }
    cc->t1 = transform_get_and_retain_weakptr(t1);
    cc->t2 = transform_get_and_retain_weakptr(t2);
    cc->axis = axis;
    cc->frames = 0;
    doubly_linked_list_push_last(sc->collisions, cc);
}

// MARK: - Physics -

void scene_set_constant_acceleration(Scene *sc, const float *x, const float *y, const float *z) {
    vx_assert(sc != NULL);

    if (x != NULL) {
        sc->constantAcceleration.x = *x;
    }
    if (y != NULL) {
        sc->constantAcceleration.y = *y;
    }
    if (z != NULL) {
        sc->constantAcceleration.x = *z;
    }
}

const float3 *scene_get_constant_acceleration(const Scene *sc) {
    vx_assert(sc != NULL);
    return &sc->constantAcceleration;
}

void scene_register_awake_box(Scene *sc, Box *b) {
    float3 size;
    box_get_size_float(b, &size);
    if (float3_isZero(&size, EPSILON_COLLISION) == false) {
        DoublyLinkedListNode *n = doubly_linked_list_first(sc->awakeBoxes);
        Box *awakeBox;
        while (n != NULL) {
            awakeBox = doubly_linked_list_node_pointer(n);
            if (box_collide_epsilon(awakeBox, b, EPSILON_ZERO)) {
                box_op_merge(awakeBox, b, awakeBox);
                box_free(b);
                return;
            }
            n = doubly_linked_list_node_next(n);
        }
        doubly_linked_list_push_last(sc->awakeBoxes, b);
    }
}

void scene_register_awake_rigidbody_contacts(Scene *sc, RigidBody *rb) {
    if (rigidbody_get_rtree_leaf(rb) != NULL) {
        Box *awakeBox = box_new_copy(rtree_node_get_aabb(rigidbody_get_rtree_leaf(rb)));
        float3_op_add_scalar(&awakeBox->max, PHYSICS_AWAKE_DISTANCE);
        float3_op_substract_scalar(&awakeBox->min, PHYSICS_AWAKE_DISTANCE);
        scene_register_awake_box(sc, awakeBox);
    }
}

void scene_register_awake_block_box(Scene *sc,
                                    const Shape *shape,
                                    const SHAPE_COORDS_INT_T x,
                                    const SHAPE_COORDS_INT_T y,
                                    const SHAPE_COORDS_INT_T z) {

    const Transform *t = shape_get_pivot_transform(shape);

    const float3 modelPoint = { x + 0.5f, y + 0.5f, z + 0.5f };
    float3 worldPoint;
    matrix4x4_op_multiply_vec_point(&worldPoint, &modelPoint, transform_get_ltw(t));

    float3 scale2; transform_get_lossy_scale(sc->map, &scale2);
    float3_op_scale(&scale2, 0.5f);
    Box *worldBox = box_new_2((float)worldPoint.x - scale2.x - PHYSICS_AWAKE_DISTANCE,
                              (float)worldPoint.y - scale2.y - PHYSICS_AWAKE_DISTANCE,
                              (float)worldPoint.z - scale2.z - PHYSICS_AWAKE_DISTANCE,
                              (float)worldPoint.x + scale2.x + PHYSICS_AWAKE_DISTANCE,
                              (float)worldPoint.y + scale2.y + PHYSICS_AWAKE_DISTANCE,
                              (float)worldPoint.z + scale2.z + PHYSICS_AWAKE_DISTANCE);

    scene_register_awake_box(sc, worldBox);
}

CastResult scene_cast_result_default() {
    CastResult hit;
    hit.hitTr = NULL;
    hit.block = NULL;
    hit.blockCoords = (SHAPE_COORDS_INT3_T){ 0, 0, 0 };
    hit.distance = FLT_MAX;
    hit.type = CastHit_None;
    hit.faceTouched = FACE_NONE;
    return hit;
}

CastHitType scene_cast_ray(Scene *sc, const Ray *worldRay, uint8_t groups,
                           const DoublyLinkedList *filterOutTransforms, CastResult *result) {

    CastResult hit = scene_cast_result_default();

    if (result != NULL) {
        *result = hit;
    }

    if (worldRay == NULL || groups == PHYSICS_GROUP_NONE) {
        return CastHit_None;
    }

    DoublyLinkedList *sceneQuery = doubly_linked_list_new();
    if (rtree_query_cast_all_ray(sc->rtree, worldRay, PHYSICS_GROUP_NONE, groups, filterOutTransforms, sceneQuery) > 0) {
        // sort query results by distance
        doubly_linked_list_sort_ascending(sceneQuery, _scene_cast_result_sort_func);

        // process query results in order, this function only returns first hit block or collision box
        DoublyLinkedListNode *n = doubly_linked_list_first(sceneQuery);
        RtreeCastResult *rtreeHit;
        Transform *hitTr;
        RigidBody *hitRb;
        while (n != NULL && hit.type == CastHit_None) {
            rtreeHit = (RtreeCastResult*) doubly_linked_list_node_pointer(n);
            hitTr = (Transform *) rtree_node_get_leaf_ptr(rtreeHit->rtreeLeaf);
            hitRb = transform_get_rigidbody(hitTr);

            const RigidbodyMode mode = rigidbody_get_simulation_mode(hitRb);

            if (mode == RigidbodyMode_Dynamic) {
                hit.hitTr = hitTr;
                hit.distance = rtreeHit->distance;
                hit.type = CastHit_CollisionBox;
            } else if (transform_get_type(hitTr) == ShapeTransform &&
                       rigidbody_uses_per_block_collisions(transform_get_rigidbody(hitTr))) {

                CastResult blockHit;
                Block *b = scene_cast_ray_shape_only(sc, transform_utils_get_shape(hitTr), worldRay, &blockHit);
                if (b != NULL) {
                    hit = blockHit;
                }
            } else {
                // solve non-dynamic rigidbodies in their model space (rotated collider)
                const Box *collider = rigidbody_get_collider(hitRb);
                Transform *modelTr = transform_get_type(hitTr) == ShapeTransform ?
                                           shape_get_pivot_transform(transform_utils_get_shape(hitTr)) :
                                           hitTr;
                Ray *modelRay = ray_world_to_local(worldRay, modelTr);

                float distance;
                if (ray_intersect_with_box(modelRay, &collider->min, &collider->max, &distance)) {
                    const float3 modelVector = {
                        modelRay->dir->x * distance,
                        modelRay->dir->y * distance,
                        modelRay->dir->z * distance
                    };
                    float3 worldVector; transform_utils_vector_ltw(modelTr, &modelVector,
                                                                   &worldVector);

                    hit.hitTr = hitTr;
                    hit.distance = float3_length(&worldVector);
                    hit.type = CastHit_CollisionBox;
                }

                ray_free(modelRay);
            }

            n = doubly_linked_list_node_next(n);
        }
    }
    doubly_linked_list_flush(sceneQuery, free);
    doubly_linked_list_free(sceneQuery);

    if (result != NULL) {
        *result = hit;
    }

    return hit.type;
}

Block *scene_cast_ray_shape_only(Scene *sc, const Shape *sh, const Ray *worldRay, CastResult *result) {
    CastResult hit = scene_cast_result_default();

    if (result != NULL) {
        *result = hit;
    }

    if (sh == NULL)
        return NULL;

    float3 localImpact;
    shape_ray_cast(sh, worldRay, &hit.distance, &localImpact, &hit.block, &hit.blockCoords);

    if (hit.block != NULL) {
        // find which side local impact is relative to touched block
        float3 ldf = { hit.blockCoords.x, hit.blockCoords.y, hit.blockCoords.z };
        const FACE_INDEX_INT_T face = ray_impacted_block_face(&localImpact, &ldf);

        hit.hitTr = shape_get_root_transform(sh);
        hit.type = CastHit_Block;
        hit.faceTouched = face;
    }

    if (result != NULL) {
        *result = hit;
    }

    return hit.block;
}

CastHitType scene_cast_box(Scene *sc, const Box *aabb, const float3 *unit, float maxDist, uint8_t groups,
                           const DoublyLinkedList *filterOutTransforms, CastResult *result) {

    CastResult hit = scene_cast_result_default();

    if (result != NULL) {
        *result = hit;
    }

    if (aabb == NULL || unit == NULL || groups == PHYSICS_GROUP_NONE) {
        return CastHit_None;
    }

    RtreeCastResult firstHit = { NULL, FLT_MAX };
    if (rtree_query_cast_box(sc->rtree, aabb, unit, maxDist, PHYSICS_GROUP_NONE, groups,
                             filterOutTransforms, &firstHit)) {

        vx_assert(firstHit.rtreeLeaf != NULL);

        Transform *hitTr = (Transform *)rtree_node_get_leaf_ptr(firstHit.rtreeLeaf);
        RigidBody *hitRb = transform_get_rigidbody(hitTr);
        const RigidbodyMode mode = rigidbody_get_simulation_mode(hitRb);

        if (mode == RigidbodyMode_Dynamic) {
            hit.hitTr = hitTr;
            hit.distance = firstHit.distance;
            hit.type = CastHit_CollisionBox;
        } else {
            Box modelBox, modelBroadphase;
            float3 modelVector, modelEpsilon;
            Shape *hitShape = transform_utils_get_shape(hitTr);

            float3 vector = {
                unit->x * maxDist, unit->y * maxDist, unit->z * maxDist
            };

            // solve non-dynamic rigidbodies in their model space (rotated collider)
            const Box *collider = rigidbody_get_collider(hitRb);
            const Matrix4x4 *invModel = transform_get_wtl(hitShape != NULL ?
                                                          shape_get_pivot_transform(hitShape) :
                                                          hitTr);
            rigidbody_broadphase_world_to_model(invModel, aabb, &modelBox, &vector, &modelVector,
                                                EPSILON_COLLISION, &modelEpsilon);

            box_set_broadphase_box(&modelBox, &modelVector, &modelBroadphase);
            if (box_collide(&modelBroadphase, collider)) {
                // shapes may enable per-block collisions
                if (hitShape != NULL && rigidbody_uses_per_block_collisions(hitRb)) {
                    Block *block = NULL;
                    SHAPE_COORDS_INT3_T blockCoords;
                    float3 normal;
                    const float swept = shape_box_swept(hitShape,
                                                        &modelBox,
                                                        &modelVector,
                                                        &modelEpsilon,
                                                        false,
                                                        &normal,
                                                        NULL,
                                                        &block,
                                                        &blockCoords);
                    if (swept < 1.0f) {
                        hit.hitTr = hitTr;
                        hit.block = block;
                        hit.distance = swept * maxDist;
                        hit.type = CastHit_Block;
                        hit.blockCoords = blockCoords;
                        hit.faceTouched = utils_aligned_normal_to_face(&normal);
                    }
                } else {
                    const float swept = box_swept(&modelBox,
                                                  &modelVector,
                                      rigidbody_get_collider(hitRb),
                                      &modelEpsilon,
                                      true,
                                      NULL,
                                      NULL);
                    if (swept < 1.0f) {
                        hit.hitTr = hitTr;
                        hit.distance = swept * maxDist;
                        hit.type = CastHit_CollisionBox;
                    }
                }
            }
        }
    }

    if (result != NULL) {
        *result = hit;
    }

    return hit.type;
}

// MARK: - Debug -
#if DEBUG_SCENE

int debug_scene_get_awake_queries(void) {
    return debug_scene_awake_queries;
}

void debug_scene_reset_calls(void) {
    debug_scene_awake_queries = 0;
}

#endif
