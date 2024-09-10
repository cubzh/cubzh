// -------------------------------------------------------------
//  Cubzh Core
//  rtree.h
//  Created by Arthur Cormerais on July 2, 2021.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <math.h>
#include <stdbool.h>
#include <stdio.h>

#include "box.h"
#include "doubly_linked_list.h"
#include "fifo_list.h"
#include "ray.h"

#if DEBUG
#define DEBUG_RTREE true
#else
#define DEBUG_RTREE false
#endif
#if DEBUG_RTREE
/// Count number of insert, remove, split, condense calls
#define DEBUG_RTREE_CALLS true
#define DEBUG_RTREE_EXTRA_LOGS false
#define DEBUG_RTREE_CHECK false
#else
#define DEBUG_RTREE_CALLS false
#define DEBUG_RTREE_EXTRA_LOGS false
#define DEBUG_RTREE_CHECK false
#endif

typedef struct _Rtree Rtree;
typedef struct _RtreeNode RtreeNode;
typedef void (*pointer_rtree_recurse_func)(RtreeNode *rn);
typedef bool (*pointer_rtree_query_overlap_func)(RtreeNode *rn, void *ptr, const float3 *epsilon);
typedef bool (*pointer_rtree_query_cast_all_func)(RtreeNode *rn, void *ptr, float *distance);
typedef size_t (*pointer_rtree_broadphase_step_func)(Rtree *r,
                                                     const Box *stepOriginBox,
                                                     float stepStartDistance,
                                                     const float3 *step3,
                                                     const Box *broadPhaseBox,
                                                     uint16_t groups,
                                                     uint16_t collidesWith,
                                                     void *optionalPtr,
                                                     const DoublyLinkedList *excludeLeafPtrs,
                                                     DoublyLinkedList *results,
                                                     const float3 *epsilon);

typedef struct RtreeCastResult {
    RtreeNode *rtreeLeaf;
    float distance;

    char pad[4];
} RtreeCastResult;

Rtree *rtree_new(uint8_t m, uint8_t M);
void rtree_free(Rtree *r);

uint16_t rtree_get_height(const Rtree *r);
RtreeNode *rtree_get_root(const Rtree *r);

/// MARK: - Nodes -
Box *rtree_node_get_aabb(const RtreeNode *rn);
uint8_t rtree_node_get_children_count(const RtreeNode *rn);
DoublyLinkedListNode *rtree_node_get_children_iterator(const RtreeNode *rn);
void *rtree_node_get_leaf_ptr(const RtreeNode *rn);
bool rtree_node_is_leaf(const RtreeNode *rn);
uint16_t rtree_node_get_groups(const RtreeNode *rn);
uint16_t rtree_node_get_collides_with(const RtreeNode *rn);
void rtree_node_set_collision_masks(RtreeNode *leaf,
                                    const uint16_t groups,
                                    const uint16_t collidesWith);

/// MARK: - Operations -
// NOTE: rtree_recurse is always "deep first"
void rtree_recurse(RtreeNode *rn, pointer_rtree_recurse_func f);
void rtree_insert(Rtree *r, RtreeNode *leaf);
RtreeNode *rtree_create_and_insert(Rtree *r,
                                   Box *aabb,
                                   uint16_t groups,
                                   uint16_t collidesWith,
                                   void *ptr);
void rtree_remove(Rtree *r, RtreeNode *leaf, bool freeLeaf);
void rtree_find_and_remove(Rtree *r, Box *aabb, void *ptr);
void rtree_update(Rtree *r, RtreeNode *leaf, Box *aabb);
void rtree_refresh_collision_masks(Rtree *r);

/// MARK: - Queries -
/// Three types of queries,
/// - OVERLAP: overlaps a primitive w/ the scene and returns all hits
/// - CAST ALL: cast a primitive on a trajectory in the scene and returns all hits
/// - CAST: cast a primitive on a trajectory in the scene and returns first hit
///
/// Each query returns,
/// - OVERLAP: directly fills the 'results' parameter w/ leaf ptr
/// - CAST ALL: populates the 'results' parameter w/ RtreeCastResult structs, to be freed by caller
/// - CAST: returns only 1 hit, but parameter 'excludeLeafPtrs' can be used to add a few exceptions
///
/// Two usages for collision masks in queries,
/// - standalone queries like cast functions may filter w/ 'collidesWith' only (no groups)
/// - reciprocal queries like collision checks may filter w/ both masks
size_t rtree_query_overlap_func(Rtree *r,
                                uint16_t groups,
                                uint16_t collidesWith,
                                pointer_rtree_query_overlap_func func,
                                void *ptr,
                                const DoublyLinkedList *excludeLeafPtrs,
                                FifoList *results,
                                const float3 *epsilon);
size_t rtree_query_overlap_box(Rtree *r,
                               const Box *aabb,
                               uint16_t groups,
                               uint16_t collidesWith,
                               const DoublyLinkedList *excludeLeafPtrs,
                               FifoList *results,
                               const float3 *epsilon);
size_t rtree_query_cast_all_func(Rtree *r,
                                 uint16_t groups,
                                 uint16_t collidesWith,
                                 pointer_rtree_query_cast_all_func func,
                                 void *ptr,
                                 const DoublyLinkedList *excludeLeafPtrs,
                                 DoublyLinkedList *results);
size_t rtree_query_cast_all_ray(Rtree *r,
                                const Ray *worldRay,
                                uint16_t groups,
                                uint16_t collidesWith,
                                const DoublyLinkedList *excludeLeafPtrs,
                                DoublyLinkedList *results);
size_t rtree_query_cast_all_box_step_func(Rtree *r,
                                          const Box *stepOriginBox,
                                          float stepStartDistance,
                                          const float3 *step3,
                                          const Box *broadPhaseBox,
                                          uint16_t groups,
                                          uint16_t collidesWith,
                                          void *optionalPtr,
                                          const DoublyLinkedList *excludeLeafPtrs,
                                          DoublyLinkedList *results,
                                          const float3 *epsilon);
size_t rtree_query_cast_all_box(Rtree *r,
                                const Box *aabb,
                                const float3 *unit,
                                float maxDist,
                                uint16_t groups,
                                uint16_t collidesWith,
                                const DoublyLinkedList *excludeLeafPtrs,
                                DoublyLinkedList *results,
                                const float3 *epsilon);

/// MARK: - Utils -
size_t rtree_utils_broadphase_steps(Rtree *r,
                                    const Box *originBox,
                                    const float3 *unit,
                                    float maxDist,
                                    uint16_t groups,
                                    uint16_t collidesWith,
                                    pointer_rtree_broadphase_step_func func,
                                    void *optionalPtr,
                                    const DoublyLinkedList *excludeLeafPtrs,
                                    DoublyLinkedList *results,
                                    const float3 *epsilon);
bool rtree_utils_result_sort_func(DoublyLinkedListNode *n1, DoublyLinkedListNode *n2);

/// MARK: - Debug -
#if DEBUG_RTREE
int debug_rtree_get_insert_calls(void);
int debug_rtree_get_split_calls(void);
int debug_rtree_get_remove_calls(void);
int debug_rtree_get_condense_calls(void);
int debug_rtree_get_update_calls(void);
void debug_rtree_reset_calls(void);
bool debug_rtree_integrity_check(Rtree *r);
void debug_rtree_reset_all_aabb(Rtree *r);
#endif

bool rtree_node_has_parent(const RtreeNode *const rn);

#ifdef __cplusplus
} // extern "C"
#endif
