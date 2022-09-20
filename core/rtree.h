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
typedef struct RtreeCastResult RtreeCastResult;
typedef void (*pointer_rtree_recurse_func)(RtreeNode *rn);
typedef bool (*pointer_rtree_query_overlap_func)(RtreeNode *rn, void *ptr, float epsilon);
typedef bool (*pointer_rtree_query_cast_all_func)(RtreeNode *rn, void *ptr, float *distance);
typedef float (*pointer_rtree_broadphase_step_func)(Rtree *r,
                                                    const Box *stepOriginBox,
                                                    const float step,
                                                    const float3 *step3,
                                                    const Box *broadPhaseBox,
                                                    const uint8_t layers,
                                                    const uint8_t collidesWith,
                                                    FifoList *broadPhaseResults,
                                                    RtreeNode **firstHit,
                                                    void *optionalPtr,
                                                    const DoublyLinkedList *excludeLeafPtrs);

struct RtreeCastResult {
    RtreeNode *rtreeLeaf;
    float distance;

    char pad[4];
};

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
uint8_t rtree_node_get_groups(const RtreeNode *rn);
uint8_t rtree_node_get_collides_with(const RtreeNode *rn);
void rtree_node_set_collision_masks(RtreeNode *leaf,
                                    const uint8_t groups,
                                    const uint8_t collidesWith);

/// MARK: - Operations -
///
// NOTE: rtree_recurse is always "deep first"
void rtree_recurse(RtreeNode *rn, pointer_rtree_recurse_func f);
void rtree_insert(Rtree *r, RtreeNode *leaf);
RtreeNode *rtree_create_and_insert(Rtree *r,
                                   Box *aabb,
                                   uint8_t groups,
                                   uint8_t collidesWith,
                                   void *ptr);
void rtree_remove(Rtree *r, RtreeNode *leaf);
void rtree_find_and_remove(Rtree *r, Box *aabb, void *ptr);
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
                                const uint8_t groups,
                                const uint8_t collidesWith,
                                pointer_rtree_query_overlap_func func,
                                void *ptr,
                                FifoList *results,
                                const float epsilon);
size_t rtree_query_overlap_box(Rtree *r,
                               const Box *aabb,
                               const uint8_t groups,
                               const uint8_t collidesWith,
                               FifoList *results,
                               const float epsilon);
size_t rtree_query_cast_all_func(Rtree *r,
                                 const uint8_t groups,
                                 const uint8_t collidesWith,
                                 pointer_rtree_query_cast_all_func func,
                                 void *ptr,
                                 FifoList *results);
size_t rtree_query_cast_all_ray(Rtree *r,
                                const Ray *worldRay,
                                uint8_t groups,
                                const uint8_t collidesWith,
                                FifoList *results);
float rtree_query_cast_box_step_func(Rtree *r,
                                     const Box *stepOriginBox,
                                     const float step,
                                     const float3 *step3,
                                     const Box *broadPhaseBox,
                                     const uint8_t groups,
                                     const uint8_t collidesWith,
                                     FifoList *broadPhaseResults,
                                     RtreeNode **firstHit,
                                     void *optionalPtr,
                                     const DoublyLinkedList *excludeLeafPtrs);
bool rtree_query_cast_box(Rtree *r,
                          const Box *aabb,
                          const float3 *unit,
                          const float maxDist,
                          const uint8_t groups,
                          const uint8_t collidesWith,
                          RtreeNode **firstHit,
                          float *distance,
                          const DoublyLinkedList *excludeLeafPtrs);

/// MARK: - Utils -
bool rtree_utils_broadphase_steps(Rtree *r,
                                  const Box *originBox,
                                  const float3 *unit,
                                  const float maxDist,
                                  const uint8_t groups,
                                  const uint8_t collidesWith,
                                  RtreeNode **firstHit,
                                  float *distance,
                                  pointer_rtree_broadphase_step_func func,
                                  void *optionalPtr,
                                  const DoublyLinkedList *excludeLeafPtrs);

/// MARK: - Debug -
#if DEBUG_RTREE
int debug_rtree_get_insert_calls(void);
int debug_rtree_get_split_calls(void);
int debug_rtree_get_remove_calls(void);
int debug_rtree_get_condense_calls(void);
void debug_rtree_reset_calls(void);
bool debug_rtree_integrity_check(Rtree *r);
void debug_rtree_reset_all_aabb(Rtree *r);
#endif

#ifdef __cplusplus
} // extern "C"
#endif
