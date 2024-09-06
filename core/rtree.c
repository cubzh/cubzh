// -------------------------------------------------------------
//  Cubzh Core
//  rtree.c
//  Created by Arthur Cormerais on July 2, 2021.
// -------------------------------------------------------------

#include "rtree.h"

#include <float.h>

#include "cclog.h"
#include "config.h"
#include "shape.h"
#include "transform.h"

#if DEBUG_RTREE
static int debug_rtree_insert_calls = 0;
static int debug_rtree_split_calls = 0;
static int debug_rtree_remove_calls = 0;
static int debug_rtree_condense_calls = 0;
static int debug_rtree_update_calls = 0;
#endif

/// Ref: https://books.google.fr/books?id=1mu099DN9UwC&pg=PR5&redir_esc=y#v=onepage&q&f=false
struct _Rtree {
    // root node may change dynamically as the tree is updated
    RtreeNode *root;
    // height of the R-tree, it is dynamic
    uint16_t h;
    // minimum number of entries per node, under which a node has to be deleted
    uint8_t m;
    // maximum number of entries per node, over which a node overflows and has to split
    uint8_t M;

    char pad[4];
};

struct _RtreeNode {
    // parent is null for the root node
    RtreeNode *parent;
    // children is empty for a leaf node
    DoublyLinkedList *children;
    // axis-aligned bounding box for this node
    Box *aabb;
    // a leaf node carries a pointer to the corresponding object
    void *leaf;
    // collision masks may be used to filter out queries,
    uint16_t groups;       // standalone queries may filter w/ groups only (cast functions)
    uint16_t collidesWith; // reciprocal queries may use both masks (collision checks)
    // children count
    uint8_t count;
    // non-leaf node layers need to be refreshed
    bool layersDirty;

    char pad[2];
};

// MARK: - Private functions prototypes -

void _rtree_node_assign(RtreeNode *parent, RtreeNode *child, bool merge);
void _rtree_node_free(RtreeNode *rn);

// MARK: - Private functions -

RtreeNode *_rtree_node_new_root(Rtree *r) {
    RtreeNode *rn = (RtreeNode *)malloc(sizeof(RtreeNode));
    if (rn == NULL) {
        return NULL;
    }
    rn->parent = NULL;
    rn->children = doubly_linked_list_new();
    rn->aabb = NULL;
    rn->leaf = NULL;
    rn->count = 0;
    rn->groups = PHYSICS_GROUP_ALL_SYSTEM;
    rn->collidesWith = PHYSICS_GROUP_ALL_SYSTEM;
    rn->layersDirty = false;

    if (r->root != NULL) {
        rtree_recurse(r->root, _rtree_node_free);
    }
    r->root = rn;
    r->h++;

    return rn;
}

RtreeNode *_rtree_node_new_leaf(RtreeNode *parent,
                                Box *aabb,
                                uint16_t groups,
                                uint16_t collidesWith,
                                void *ptr) {
    RtreeNode *rn = (RtreeNode *)malloc(sizeof(RtreeNode));
    if (rn == NULL) {
        return NULL;
    }
    rn->parent = parent;
    rn->children = doubly_linked_list_new();
    rn->aabb = box_new_copy(aabb);
    rn->leaf = ptr;
    rn->count = 0;
    rn->groups = groups;
    rn->collidesWith = collidesWith;
    rn->layersDirty = false;

    if (parent != NULL) {
        _rtree_node_assign(parent, rn, true);
    }

    return rn;
}

RtreeNode *_rtree_node_new_branch(RtreeNode *parent, RtreeNode *child) {
    RtreeNode *rn = (RtreeNode *)malloc(sizeof(RtreeNode));
    if (rn == NULL) {
        return NULL;
    }
    rn->parent = parent;
    rn->children = doubly_linked_list_new();
    rn->aabb = NULL;
    rn->leaf = NULL;
    rn->count = 0;
    rn->groups = PHYSICS_GROUP_ALL_SYSTEM;
    rn->collidesWith = PHYSICS_GROUP_ALL_SYSTEM;
    rn->layersDirty = false;

    if (child != NULL) {
        _rtree_node_assign(rn, child, true);
    }
    if (parent != NULL) {
        _rtree_node_assign(parent, rn, true);
    }

    return rn;
}

void _rtree_node_free(RtreeNode *rn) {
    doubly_linked_list_free(rn->children);
    if (rn->aabb != NULL) {
        box_free(rn->aabb);
    }
    free(rn);
}

/// @returns added volume to src box if it would merge w/ insert box
float _rtree_box_expand_volume(const Box *src, const Box *insert, Box *result) {
    box_op_merge(src, insert, result);
    return box_get_volume(result) - box_get_volume(src);
}

/// @returns volume of "dead space" if the two boxes would merge
float _rtree_box_merge_dead_space(const Box *b1, const Box *b2, Box *result) {
    box_op_merge(b1, b2, result);
    return box_get_volume(result) - box_get_volume(b1) - box_get_volume(b2);
}

/// @param merge child & parent aabb
void _rtree_node_assign(RtreeNode *parent, RtreeNode *child, bool merge) {
    // leaves should always stay at height level
    vx_assert(parent->leaf == NULL);

    doubly_linked_list_push_first(parent->children, child);
    parent->count++;
    child->parent = parent;

    if (merge) {
        if (parent->aabb == NULL) {
            // this should happen on a previously empty node
            vx_assert(parent->count == 1);

            parent->aabb = box_new_copy(child->aabb);
        } else {
            box_op_merge(parent->aabb, child->aabb, parent->aabb);
        }
        parent->layersDirty = true;
    }
}

/// @returns whether or not child was found & removed, if so, ancestors aabb will need to be
/// recomputed and the tree may need to be condensed
bool _rtree_node_remove_child(RtreeNode *parent, RtreeNode *child) {
    DoublyLinkedListNode *n;
    RtreeNode *rn;

    n = doubly_linked_list_first(parent->children);
    while (n != NULL) {
        rn = (RtreeNode *)doubly_linked_list_node_pointer(n);
        if (rn == child) {
            doubly_linked_list_delete_node(parent->children, n);
            parent->count--;
            child->parent = NULL;

            return true;
        }
        n = doubly_linked_list_node_next(n);
    }

    return false;
}

void _rtree_node_reset_aabb(RtreeNode *rn) {
    // cannot reset the box of a leaf, it is a collider
    vx_assert(rn->leaf == NULL);

    DoublyLinkedListNode *n = doubly_linked_list_first(rn->children);
    if (n != NULL) {
        // aabb is set to match its first child aabb
        RtreeNode *child = (RtreeNode *)doubly_linked_list_node_pointer(n);
        box_copy(rn->aabb, child->aabb);

        // merge w/ other children aabb if any
        n = doubly_linked_list_node_next(n);
        while (n != NULL) {
            child = (RtreeNode *)doubly_linked_list_node_pointer(n);
            box_op_merge(rn->aabb, child->aabb, rn->aabb);
            n = doubly_linked_list_node_next(n);
        }
    } else {
        // only the tree root can remain w/o children
        vx_assert(rn->parent == NULL);

        box_free(rn->aabb);
        rn->aabb = NULL;
    }
}

void _rtree_node_reset_collision_masks(RtreeNode *rn) {
    if (rn->layersDirty) {
        rn->groups = PHYSICS_GROUP_NONE;
        rn->collidesWith = PHYSICS_GROUP_NONE;

        DoublyLinkedListNode *n = doubly_linked_list_first(rn->children);
        RtreeNode *child;
        while (n != NULL) {
            child = (RtreeNode *)doubly_linked_list_node_pointer(n);
            rn->groups |= child->groups;
            rn->collidesWith |= child->collidesWith;
            n = doubly_linked_list_node_next(n);
        }

        if (rn->parent != NULL) {
            rn->parent->layersDirty = true;
        }
    }
    rn->layersDirty = false;
}

/// Choose where to optimally insert given aabb between the provided nodes rn and selectedRn,
/// writes best node & corresponding expansion volume in parameters selectedRn and selectedRnVol
void _rtree_insert_choose_node(Box *aabb,
                               Box *tmpBox,
                               RtreeNode *rn,
                               RtreeNode **selectedRn,
                               float *selectedRnVol) {

    // choose the node w/ minimum volume enlargement
    const float vol = _rtree_box_expand_volume(rn->aabb, aabb, tmpBox);
    if (vol < *selectedRnVol) {
        *selectedRn = rn;
        *selectedRnVol = vol;
    } else if (float_isEqual(vol, *selectedRnVol, EPSILON_COLLISION)) {
        // tie: choose the node w/ the smallest existing box
        const float boxVol = box_get_volume(rn->aabb);
        const float selectedBoxVol = box_get_volume((*selectedRn)->aabb);
        if (boxVol < selectedBoxVol) {
            *selectedRn = rn;
            *selectedRnVol = vol;
        } else if (float_isEqual(boxVol, selectedBoxVol, EPSILON_COLLISION)) {
            // tie: choose the node w/ the smaller number of entries
            if (rn->count < (*selectedRn)->count) {
                *selectedRn = rn;
                *selectedRnVol = vol;
            }
        }
    }
}

/// after this call, the toSplit node has been freed, and its parent aabb is up-to-date (but not
/// its ancestors aabb)
/// @returns parent node which now has an additional child
RtreeNode *_rtree_split_node_quadratic(Rtree *r, RtreeNode *toSplit) {
    DoublyLinkedListNode *n1, *n2;
    RtreeNode *rn1, *rn2;
    RtreeNode *seed1 = NULL, *seed2 = NULL;
    float maxVol = -FLT_MAX;
    Box tmpBox;
#if DEBUG_RTREE_EXTRA_LOGS
    uint16_t reinsertCount = 0;
    bool heightIncreased = false;

#define INC_REINSERT_COUNT reinsertCount++;
#define SET_HEIGHT_INCREASED heightIncreased = true;
#else
#define INC_REINSERT_COUNT
#define SET_HEIGHT_INCREASED
#endif

    // we shouldn't be splitting a node under max capacity
    vx_assert(toSplit->count > r->M);

    // quadratic split: we use as seeds the two aabb that if merged create as much dead space as
    // possible
    n1 = doubly_linked_list_first(toSplit->children);
    while (n1 != NULL) {
        rn1 = (RtreeNode *)doubly_linked_list_node_pointer(n1);
        n2 = doubly_linked_list_node_next(n1);
        while (n2 != NULL) {
            rn2 = (RtreeNode *)doubly_linked_list_node_pointer(n2);

            const float vol = _rtree_box_merge_dead_space(rn1->aabb, rn2->aabb, &tmpBox);
            if (vol > maxVol) {
                seed1 = rn1;
                seed2 = rn2;
                maxVol = vol;
            }

            n2 = doubly_linked_list_node_next(n2);
        }
        n1 = doubly_linked_list_node_next(n1);
    }
    vx_assert(seed1 != NULL && seed2 != NULL);

    // selected node is the root: create a new root, increase tree height
    if (toSplit->parent == NULL) {
        r->root = NULL;
        rn1 = _rtree_node_new_root(r);
        SET_HEIGHT_INCREASED
    }
    // selected node isn't the root: remove it from parent
    else {
        rn1 = toSplit->parent;
        _rtree_node_remove_child(toSplit->parent, toSplit);
        _rtree_node_reset_aabb(rn1);
    }

    // create 2 branch nodes w/ each one a seed node
    RtreeNode *rnSplit1 = _rtree_node_new_branch(rn1, seed1);
    RtreeNode *rnSplit2 = _rtree_node_new_branch(rn1, seed2);

    // insert remaining nodes
    uint8_t toInsert = toSplit->count - 2;
    while (doubly_linked_list_first(toSplit->children) != NULL) {
        rn1 = (RtreeNode *)doubly_linked_list_pop_first(toSplit->children);
        if (rn1 != seed1 && rn1 != seed2) {
            // prioritize minimum node size over any other criteria
            if (rnSplit1->count == r->m - toInsert) {
                rn2 = rnSplit1;
            } else if (rnSplit2->count == r->m - toInsert) {
                rn2 = rnSplit2;
            } else {
                // choose optimal insertion node
                rn2 = rnSplit1;
                float vol = _rtree_box_expand_volume(rnSplit1->aabb, rn1->aabb, &tmpBox);
                _rtree_insert_choose_node(rn1->aabb, &tmpBox, rnSplit2, &rn2, &vol);
            }

            // assign to chosen node
            _rtree_node_assign(rn2, rn1, true);
            toInsert--;
            INC_REINSERT_COUNT
        }
    }

    _rtree_node_free(toSplit);

    // split should result in 2 new nodes within capacity
    vx_assert(rnSplit1->parent == rnSplit2->parent);
    vx_assert(rnSplit1->count >= r->m && rnSplit1->count <= r->M);
    vx_assert(rnSplit2->count >= r->m && rnSplit2->count <= r->M);

#if DEBUG_RTREE_CALLS
    debug_rtree_split_calls++;
#endif
#if DEBUG_RTREE_EXTRA_LOGS
    if (heightIncreased) {
        cclog_debug("🏞 r-tree node split w/ %d reinsertion, height increased to %d",
                    reinsertCount,
                    r->h);
    } else {
        cclog_debug("🏞 r-tree node split w/ %d reinsertion", reinsertCount);
    }
#endif

    return rnSplit1->parent;
}

RtreeNode *_rtree_find_leaf(RtreeNode *start, Box *aabb, void *ptr, bool check) {
    FifoList *toExamine = fifo_list_new();
    DoublyLinkedListNode *n;
    RtreeNode *rn, *child;

    rn = start;
    while (rn != NULL) {
        if (rn->leaf != NULL) {
            if (rn->leaf == ptr) {
                return rn;
            }
            rn = fifo_list_pop(toExamine);
            continue;
        }

        n = doubly_linked_list_first(rn->children);
        while (n != NULL) {
            child = (RtreeNode *)doubly_linked_list_node_pointer(n);

            // examine each potential node
            if (check == false || box_collide_epsilon(child->aabb, aabb, EPSILON_COLLISION)) {
                fifo_list_push(toExamine, child);
            }

            n = doubly_linked_list_node_next(n);
        }

        rn = fifo_list_pop(toExamine);
    }

    fifo_list_free(toExamine, NULL);

    return NULL;
}

void _rtree_condense(Rtree *r, RtreeNode *start) {
    FifoList *toRemove = fifo_list_new();
    DoublyLinkedListNode *n;
    RtreeNode *rn1, *rn2;
#if DEBUG_RTREE_EXTRA_LOGS
    uint16_t removalCount = 0, reinsertCount = 0;

#define INC_REMOVAL_COUNT removalCount++;
#define INC_REINSERT_COUNT reinsertCount++;
#else
#define INC_REMOVAL_COUNT
#define INC_REINSERT_COUNT
#endif

    rn1 = start;

    // condense the branch from start to root (excluded)
    while (rn1->parent != NULL) {
        rn2 = rn1->parent;

        // node is under capacity, select it for removal
        if (rn1->count < r->m) {
            _rtree_node_remove_child(rn1->parent, rn1);
            fifo_list_push(toRemove, rn1);
            INC_REMOVAL_COUNT
        }
        // or update aabb, made dirty by removal down the tree
        else {
            _rtree_node_reset_aabb(rn1);
        }

        rn1 = rn2;
    }

    // update root box
    _rtree_node_reset_aabb(r->root);

    // reinsert all the leaves amongst the children of nodes selected for removal
    rn1 = fifo_list_pop(toRemove);
    while (rn1 != NULL) {
        n = doubly_linked_list_first(rn1->children);
        while (n != NULL) {
            rn2 = (RtreeNode *)doubly_linked_list_node_pointer(n);

            if (rn2->leaf != NULL) {
                rtree_insert(r, rn2);
                INC_REINSERT_COUNT
            } else {
                fifo_list_push(toRemove, rn2);
                INC_REMOVAL_COUNT
            }

            n = doubly_linked_list_node_next(n);
        }

        _rtree_node_free(rn1);
        rn1 = fifo_list_pop(toRemove);
    }

    fifo_list_free(toRemove, NULL);

#if DEBUG_RTREE_CALLS
    debug_rtree_condense_calls++;
#endif
#if DEBUG_RTREE_EXTRA_LOGS
    if (removalCount > 0 || reinsertCount > 0) {
        cclog_debug("🏞 r-tree condensed w/ %d removal & %d reinsertion",
                    removalCount,
                    reinsertCount);
    }
#endif
}

// MARK: - Public functions -

Rtree *rtree_new(uint8_t m, uint8_t M) {
    Rtree *r = (Rtree *)malloc(sizeof(Rtree));
    if (r == NULL) {
        return NULL;
    }
    r->root = NULL;
    r->h = 0;
    r->m = m;
    r->M = M;

    _rtree_node_new_root(r);

    return r;
}

void rtree_free(Rtree *r) {
    rtree_recurse(r->root, _rtree_node_free);
    free(r);
}

uint16_t rtree_get_height(const Rtree *r) {
    return r->h;
}

RtreeNode *rtree_get_root(const Rtree *r) {
    return r->root;
}

// MARK: Nodes

Box *rtree_node_get_aabb(const RtreeNode *rn) {
    return rn->aabb;
}

uint8_t rtree_node_get_children_count(const RtreeNode *rn) {
    return rn->count;
}

DoublyLinkedListNode *rtree_node_get_children_iterator(const RtreeNode *rn) {
    return doubly_linked_list_first(rn->children);
}

void *rtree_node_get_leaf_ptr(const RtreeNode *rn) {
    return rn->leaf;
}

bool rtree_node_is_leaf(const RtreeNode *rn) {
    return rn != NULL && rn->parent != NULL && rn->leaf != NULL && rn->aabb != NULL;
}

uint16_t rtree_node_get_groups(const RtreeNode *rn) {
    return rn->groups;
}

uint16_t rtree_node_get_collides_with(const RtreeNode *rn) {
    return rn->collidesWith;
}

void rtree_node_set_collision_masks(RtreeNode *leaf,
                                    const uint16_t groups,
                                    const uint16_t collidesWith) {
    // collision masks can be set only on a leaf
    vx_assert(rtree_node_is_leaf(leaf));

    leaf->groups = groups;
    leaf->collidesWith = collidesWith;
    leaf->parent->layersDirty = true;
}

/// MARK: Operations

// NOTE: rtree_recurse is always "deep first"
void rtree_recurse(RtreeNode *rn, pointer_rtree_recurse_func f) {
    DoublyLinkedListNode *n = doubly_linked_list_first(rn->children);
    RtreeNode *child = NULL;
    while (n != NULL) {
        child = (RtreeNode *)doubly_linked_list_node_pointer(n);
        rtree_recurse(child, f);
        n = doubly_linked_list_node_next(n);
    }
    f(rn); // free parent
}

void rtree_insert(Rtree *r, RtreeNode *leaf) {
    RtreeNode *rn, *selectedNode;
    DoublyLinkedListNode *n;
    float selectedNodeVol;
    Box tmpBox;
    uint16_t level;
#if DEBUG_RTREE_EXTRA_LOGS
    uint16_t boxMergeCount = 0, boxResetCount = 0, splitCount = 0;

#define INC_BOX_MERGE_COUNT boxMergeCount++;
#define INC_BOX_RESET_COUNT boxResetCount++;
#define INC_SPLIT_COUNT splitCount++;
#else
#define INC_BOX_MERGE_COUNT
#define INC_BOX_RESET_COUNT
#define INC_SPLIT_COUNT
#endif

    // we should only be inserting a leaf (no parent yet)
    vx_assert(leaf->leaf != NULL && leaf->aabb != NULL);

    selectedNode = r->root;
    level = 1;

    // traverse the tree to select an appropriate leaf
    while (level < r->h) {
        // all leaves are at the same tree height level because the tree height changes only from
        // the root, therefore there cannot be a node w/o children at an intermediate level
        vx_assert(selectedNode->parent == NULL || selectedNode->count > 0);

        selectedNodeVol = FLT_MAX;

        n = doubly_linked_list_first(selectedNode->children);
        while (n != NULL) {
            rn = (RtreeNode *)doubly_linked_list_node_pointer(n);

            _rtree_insert_choose_node(leaf->aabb, &tmpBox, rn, &selectedNode, &selectedNodeVol);

            n = doubly_linked_list_node_next(n);
        }

        level++;
    }

    // selected node is at minima the R-tree root node
    vx_assert(selectedNode != NULL);

    // assign leaf node to the selected node
    _rtree_node_assign(selectedNode, leaf, true);
    INC_BOX_MERGE_COUNT

    // a) selected node is not full: simply propagate aabb update upwards
    if (selectedNode->count <= r->M) {
        rn = selectedNode->parent;
        while (rn != NULL) {
            box_op_merge(rn->aabb, leaf->aabb, rn->aabb);
            rn = rn->parent;
            INC_BOX_MERGE_COUNT
        }
    }
    // b) selected node is full, split it
    else {
        rn = _rtree_split_node_quadratic(r, selectedNode);
        selectedNode = NULL;
        INC_SPLIT_COUNT

        // propagate aabb update upwards, or split if needed
        while (rn != NULL) {
            if (rn->count > r->M) {
                rn = _rtree_split_node_quadratic(r, rn);
                INC_SPLIT_COUNT
            } else {
                _rtree_node_reset_aabb(rn);
                INC_BOX_RESET_COUNT
                rn = rn->parent;
            }
        }
    }

#if DEBUG_RTREE_CALLS
    debug_rtree_insert_calls++;
#endif
#if DEBUG_RTREE_EXTRA_LOGS
    cclog_debug("🏞 r-tree node inserted w/ %d box merge, %d box reset & %d split",
                boxMergeCount,
                boxResetCount,
                splitCount);
#endif
}

RtreeNode *rtree_create_and_insert(Rtree *r,
                                   Box *aabb,
                                   uint16_t groups,
                                   uint16_t collidesWith,
                                   void *ptr) {
    RtreeNode *newLeaf = _rtree_node_new_leaf(NULL, aabb, groups, collidesWith, ptr);
    rtree_insert(r, newLeaf);
    return newLeaf;
}

void rtree_remove(Rtree *r, RtreeNode *leaf, bool freeLeaf) {
#if DEBUG_RTREE_EXTRA_LOGS
    bool heightDecreased = false;

#define SET_HEIGHT_DECREASED heightDecreased = true;
#else
#define SET_HEIGHT_DECREASED
#endif

    // we should only be removing a leaf already attached to the tree
    vx_assert(rtree_node_is_leaf(leaf));

    RtreeNode *parent = leaf->parent;
    if (_rtree_node_remove_child(parent, leaf)) {
        if (freeLeaf) {
            _rtree_node_free(leaf);
        }
        _rtree_condense(r, parent);

        // reduce height if root has only one non-leaf child
        if (r->root->count == 1 && r->h >= 2) {
            r->root = (RtreeNode *)doubly_linked_list_pop_first(r->root->children);
            _rtree_node_free(r->root->parent);
            r->root->parent = NULL;
            r->h--;
            SET_HEIGHT_DECREASED
        }
    }

#if DEBUG_RTREE_CALLS
    debug_rtree_remove_calls++;
#endif
#if DEBUG_RTREE_EXTRA_LOGS
    if (heightDecreased) {
        cclog_debug("🏞 r-tree node removed, height decreased to %d", r->h);
    } else {
        cclog_debug("🏞 r-tree node removed");
    }
#endif
}

void rtree_find_and_remove(Rtree *r, Box *aabb, void *ptr) {
    RtreeNode *leaf = _rtree_find_leaf(r->root, aabb, ptr, false);
    if (leaf != NULL) {
        vx_assert(leaf != r->root); // cannot happen (for code analyzer)
        rtree_remove(r, leaf, true);
    }
#if DEBUG_RTREE_EXTRA_LOGS
    else {
        cclog_debug("⚠️⚠️⚠️rtree_remove: leaf not found");
    }
#endif
}

void rtree_update(Rtree *r, RtreeNode *leaf, Box *aabb) {
    Box tmpBox;
    DoublyLinkedListNode *n;
    RtreeNode *child;

    // simulate node volume w/ updated leaf aabb
    box_copy(&tmpBox, aabb);
    n = doubly_linked_list_first(leaf->parent->children);
    while (n != NULL) {
        child = (RtreeNode *)doubly_linked_list_node_pointer(n);
        if (child != leaf) {
            box_op_merge(&tmpBox, child->aabb, &tmpBox);
        }
        n = doubly_linked_list_node_next(n);
    }
    const float vol = box_get_volume(&tmpBox);

    // if volume difference is within threshold, keep leaf in place
    if (fabsf(vol - box_get_volume(leaf->parent->aabb)) < RTREE_LEAF_UPDATE_THRESHOLD) {
        box_copy(leaf->aabb, aabb);
        box_copy(leaf->parent->aabb, &tmpBox);

        // propagate aabb update upwards
        RtreeNode *rn = leaf->parent->parent;
        while (rn != NULL) {
            _rtree_node_reset_aabb(rn);
            rn = rn->parent;
        }
#if DEBUG_RTREE_CALLS
        debug_rtree_update_calls++;
#endif
    } else {
        rtree_remove(r, leaf, false);
        box_copy(leaf->aabb, aabb);
        rtree_insert(r, leaf);
    }
}

void rtree_refresh_collision_masks(Rtree *r) {
    rtree_recurse(r->root, _rtree_node_reset_collision_masks);
}

// MARK: Queries

size_t rtree_query_overlap_func(Rtree *r,
                                uint16_t groups,
                                uint16_t collidesWith,
                                pointer_rtree_query_overlap_func func,
                                void *ptr,
                                const DoublyLinkedList *excludeLeafPtrs,
                                FifoList *results,
                                float epsilon) {

    FifoList *toExamine = fifo_list_new();
    DoublyLinkedListNode *n;
    RtreeNode *rn, *child;
    size_t hits = 0;

    rn = r->root;
    while (rn != NULL) {
        n = doubly_linked_list_first(rn->children);
        while (n != NULL) {
            child = (RtreeNode *)doubly_linked_list_node_pointer(n);

            if (rigidbody_collision_masks_reciprocal_match(child->groups,
                                                           child->collidesWith,
                                                           groups,
                                                           collidesWith) &&
                func(child, ptr, epsilon)) {

                if (child->leaf == NULL) {
                    fifo_list_push(toExamine, child);
                } else if (excludeLeafPtrs == NULL ||
                           doubly_linked_list_contains(excludeLeafPtrs, child->leaf) == false) {

                    if (results != NULL) {
                        fifo_list_push(results, child);
                    }
                    hits++;
                }
            }

            n = doubly_linked_list_node_next(n);
        }
        rn = (RtreeNode *)fifo_list_pop(toExamine);
    }

    fifo_list_free(toExamine, NULL);

    return hits;
}

bool _rtree_query_overlap_box_func(RtreeNode *rn, void *ptr, float epsilon) {
    return box_collide_epsilon(rn->aabb, (Box *)ptr, epsilon);
}

size_t rtree_query_overlap_box(Rtree *r,
                               const Box *aabb,
                               uint16_t groups,
                               uint16_t collidesWith,
                               const DoublyLinkedList *excludeLeafPtrs,
                               FifoList *results,
                               float epsilon) {

    return rtree_query_overlap_func(r,
                                    groups,
                                    collidesWith,
                                    _rtree_query_overlap_box_func,
                                    (void *)aabb,
                                    excludeLeafPtrs,
                                    results,
                                    epsilon);
}

size_t rtree_query_cast_all_func(Rtree *r,
                                 uint16_t groups,
                                 uint16_t collidesWith,
                                 pointer_rtree_query_cast_all_func func,
                                 void *ptr,
                                 const DoublyLinkedList *excludeLeafPtrs,
                                 DoublyLinkedList *results) {
    vx_assert(results != NULL);

    FifoList *toExamine = fifo_list_new();
    DoublyLinkedListNode *n;
    RtreeNode *rn, *child;
    size_t hits = 0;
    float dist;
    RtreeCastResult *result;

    rn = r->root;
    while (rn != NULL) {
        n = doubly_linked_list_first(rn->children);
        while (n != NULL) {
            child = (RtreeNode *)doubly_linked_list_node_pointer(n);

            if (rigidbody_collision_masks_reciprocal_match(child->groups,
                                                           child->collidesWith,
                                                           groups,
                                                           collidesWith) &&
                func(child, ptr, &dist)) {

                if (child->leaf == NULL) {
                    fifo_list_push(toExamine, child);
                } else if (excludeLeafPtrs == NULL ||
                           doubly_linked_list_contains(excludeLeafPtrs, child->leaf) == false) {

                    result = malloc(sizeof(RtreeCastResult));
                    if (result != NULL) {
                        result->rtreeLeaf = child;
                        result->distance = dist;
                        doubly_linked_list_push_last(results, result);
                        hits++;
                    }
                }
            }

            n = doubly_linked_list_node_next(n);
        }
        rn = (RtreeNode *)fifo_list_pop(toExamine);
    }

    fifo_list_free(toExamine, NULL);

    return hits;
}

bool _rtree_query_cast_ray_all_func(RtreeNode *rn, void *ptr, float *distance) {
    return ray_intersect_with_box((Ray *)ptr, &rn->aabb->min, &rn->aabb->max, distance);
}

size_t rtree_query_cast_all_ray(Rtree *r,
                                const Ray *worldRay,
                                uint16_t groups,
                                uint16_t collidesWith,
                                const DoublyLinkedList *excludeLeafPtrs,
                                DoublyLinkedList *results) {

    return rtree_query_cast_all_func(r,
                                     groups,
                                     collidesWith,
                                     _rtree_query_cast_ray_all_func,
                                     (void *)worldRay,
                                     excludeLeafPtrs,
                                     results);
}

size_t rtree_query_cast_all_box_step_func(Rtree *r,
                                          const Box *stepOriginBox,
                                          float stepStartDistance,
                                          const float3 *step3,
                                          const Box *broadPhaseBox,
                                          uint16_t groups,
                                          uint16_t collidesWith,
                                          void *optionalPtr,
                                          const DoublyLinkedList *excludeLeafPtrs,
                                          DoublyLinkedList *results) {

    float swept;
    RtreeNode *hit;
    FifoList *query = fifo_list_new();
    RtreeCastResult *result;
    size_t hits = 0;

    if (rtree_query_overlap_box(r,
                                broadPhaseBox,
                                groups,
                                collidesWith,
                                excludeLeafPtrs,
                                query,
                                EPSILON_COLLISION) > 0) {
        hit = fifo_list_pop(query);
        while (hit != NULL) {
            swept = box_swept(stepOriginBox,
                              step3,
                              hit->aabb,
                              &float3_epsilon_collision,
                              false,
                              NULL,
                              NULL);

            if ((excludeLeafPtrs == NULL ||
                 doubly_linked_list_contains(excludeLeafPtrs, hit->leaf) == false)) {

                result = malloc(sizeof(RtreeCastResult));
                if (result != NULL) {
                    result->rtreeLeaf = hit;
                    result->distance = stepStartDistance + swept * float3_length(step3);
                    doubly_linked_list_push_last(results, result);
                    hits++;
                }
            }
            hit = fifo_list_pop(query);
        }
    }

    vx_assert(fifo_list_get_size(query) == 0);
    fifo_list_free(query, NULL);

    return hits;
}

size_t rtree_query_cast_all_box(Rtree *r,
                                const Box *aabb,
                                const float3 *unit,
                                float maxDist,
                                uint16_t groups,
                                uint16_t collidesWith,
                                const DoublyLinkedList *excludeLeafPtrs,
                                DoublyLinkedList *results) {

    return rtree_utils_broadphase_steps(r,
                                        aabb,
                                        unit,
                                        maxDist,
                                        groups,
                                        collidesWith,
                                        rtree_query_cast_all_box_step_func,
                                        NULL,
                                        excludeLeafPtrs,
                                        results);
}

// MARK: Utils

size_t rtree_utils_broadphase_steps(Rtree *r,
                                    const Box *originBox,
                                    const float3 *unit,
                                    float maxDist,
                                    uint16_t groups,
                                    uint16_t collidesWith,
                                    pointer_rtree_broadphase_step_func func,
                                    void *optionalPtr,
                                    const DoublyLinkedList *excludeLeafPtrs,
                                    DoublyLinkedList *results) {
    vx_assert(results != NULL);

    Box broadPhaseBox, stepOriginBox = *originBox;
    float d = 0.0f, step = 0.0f;
    size_t hits = 0;

    // broadphase query w/ a nominal step, since max distance can at worst be arbitrarily large,
    // and the broadphase aligned box would under-perform
    while (d < maxDist) {
        d += step;
        step = minimum(maxDist - d, RTREE_CAST_STEP_DISTANCE);

        const float3 step3 = {unit->x * step, unit->y * step, unit->z * step};
        box_set_broadphase_box(&stepOriginBox, &step3, &broadPhaseBox);

        hits += func(r,
                     &stepOriginBox,
                     d,
                     &step3,
                     &broadPhaseBox,
                     groups,
                     collidesWith,
                     optionalPtr,
                     excludeLeafPtrs,
                     results);

        float3_op_add(&stepOriginBox.min, &step3);
        float3_op_add(&stepOriginBox.max, &step3);
    }

    return hits;
}

bool rtree_utils_result_sort_func(DoublyLinkedListNode *n1, DoublyLinkedListNode *n2) {
    return ((RtreeCastResult *)doubly_linked_list_node_pointer(n1))->distance >
           ((RtreeCastResult *)doubly_linked_list_node_pointer(n2))->distance;
}

// MARK: - Debug functions -
#if DEBUG_RTREE

int debug_rtree_get_insert_calls(void) {
    return debug_rtree_insert_calls;
}

int debug_rtree_get_split_calls(void) {
    return debug_rtree_split_calls;
}

int debug_rtree_get_remove_calls(void) {
    return debug_rtree_remove_calls;
}

int debug_rtree_get_condense_calls(void) {
    return debug_rtree_condense_calls;
}

int debug_rtree_get_update_calls(void) {
    return debug_rtree_update_calls;
}

void debug_rtree_reset_calls(void) {
    debug_rtree_insert_calls = 0;
    debug_rtree_split_calls = 0;
    debug_rtree_remove_calls = 0;
    debug_rtree_condense_calls = 0;
    debug_rtree_update_calls = 0;
}

bool debug_rtree_integrity_check(Rtree *r) {
    DoublyLinkedList *toExamine = doubly_linked_list_new();
    DoublyLinkedListNode *n;
    RtreeNode *rn, *child, *rbLeaf;
    Transform *t;
    Shape *s;
    RigidBody *rb;
    bool success = true;

    doubly_linked_list_push_first(toExamine, r->root);
    while (doubly_linked_list_first(toExamine) != NULL) {
        rn = (RtreeNode *)doubly_linked_list_pop_first(toExamine);

        if (rn->leaf != NULL) {
            if (rn->count > 0) {
                cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: misplaced leaf");
                success = false;
            }
            t = (Transform *)rn->leaf;
            if (transform_get_type(t) == ShapeTransform) {
                s = (Shape *)transform_get_ptr(t);
                rb = shape_get_rigidbody(s);
            } else {
                rb = NULL;
            }
            if (rb != NULL) {
                rbLeaf = rigidbody_get_rtree_leaf(rb);
                if (rbLeaf != NULL) {
                    if (float3_isEqual(&rn->aabb->min, &rbLeaf->aabb->min, EPSILON_ZERO) == false ||
                        float3_isEqual(&rn->aabb->max, &rbLeaf->aabb->max, EPSILON_ZERO) == false) {

                        cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: mismatched leaf");
                        success = false;
                    }
                } else {
                    cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: dangling leaf");
                    success = false;
                }
            }
        } else if (rn->parent != NULL) {
            if (rn->count == 0) {
                cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: dangling branch");
                success = false;
            } else if (rn->count < r->m) {
                cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: underflowing node");
                success = false;
            } else if (rn->count > r->M) {
                cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: overflowing node");
                success = false;
            }
        }

        const size_t childrenCount = doubly_linked_list_node_count(rn->children);
        if (rn->count != childrenCount) {
            cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: mismatched children count");
            success = false;
        }

        n = doubly_linked_list_first(rn->children);
        while (n != NULL) {
            child = (RtreeNode *)doubly_linked_list_node_pointer(n);

            if (box_contains_epsilon(rn->aabb, &child->aabb->min, EPSILON_ZERO) == false ||
                box_contains_epsilon(rn->aabb, &child->aabb->max, EPSILON_ZERO) == false) {

                cclog_debug("⚠️⚠️⚠️debug_rtree_integrity_check: parent aabb does not contain "
                            "child aabb");
                success = false;
            }
            doubly_linked_list_push_first(toExamine, child);

            n = doubly_linked_list_node_next(n);
        }
    }

    doubly_linked_list_free(toExamine);

    return success;
}

void _debug_rtree_reset_all_aabb_recurse(RtreeNode *rn) {
    if (rn->leaf == NULL) {
        _rtree_node_reset_aabb(rn);
    }
}

void debug_rtree_reset_all_aabb(Rtree *r) {
    rtree_recurse(r->root, _debug_rtree_reset_all_aabb_recurse);
}

#endif

bool rtree_node_has_parent(const RtreeNode *const rn) {
    return rn->parent != NULL;
}
