// -------------------------------------------------------------
//  Cubzh Core
//  shape.h
//  Created by Adrien Duermael on July 12, 2017.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "block.h"
#include "box.h"
#include "chunk.h"
#include "color_atlas.h"
#include "color_palette.h"
#include "config.h"
#include "flood_fill_lighting.h"
#include "index3d.h"
#include "map_string_float3.h"
#include "matrix4x4.h"
#include "octree.h"
#include "quaternion.h"
#include "ray.h"
#include "vertextbuffer.h"

typedef struct _RigidBody RigidBody;
typedef struct _Shape Shape;
typedef struct _int3 int3;
typedef struct _Scene Scene;
typedef struct _Transform Transform;
typedef struct _VertexBuffer VertexBuffer;
typedef struct _Chunk Chunk;
typedef struct _Rtree Rtree;

typedef struct _LoadShapeSettings {
    bool lighting;
    bool isMutable;
} LoadShapeSettings;

#define POINT_OF_INTEREST_ORIGIN "origin" // legacy
#define POINT_OF_INTEREST_HAND "Hand"     //

// Latest revision: sept. 2023
//
// A shape is a model made out of blocks. A list of chunks is used to partition
// model space for rendering buffers. Each chunk has an octree onto which physics
// queries can be performed.
//
// Memory allocation for rendering buffers (loosely called here vertex buffers) is meant
// to minimize memory usage and maximize buffer occupancy in order to draw the shape
// in a minimum number of drawcalls. The initial buffer is relatively small, and each
// subsequent buffer is allocated on-demand with increased capacity, to account for the
// common case of a scene filled with many small shapes.

/// Shape draw mode
typedef uint8_t ShapeDrawMode;
#define SHAPE_DRAWMODE_DEFAULT 0
#define SHAPE_DRAWMODE_ALL_TRANSPARENT 1
#define SHAPE_DRAWMODE_HIGHLIGHT 2
#define SHAPE_DRAWMODE_GREY 4
#define SHAPE_DRAWMODE_GRID 8

Shape *shape_make(void);
Shape *shape_make_2(const bool isMutable);
Shape *shape_make_copy(Shape *const origin);

/// Returns false if retain fails
bool shape_retain(Shape *const shape);

/// Convenience function to release the shape's Transform
/// /!\ `transform_release` is the function responsible for freeing resources
void shape_release(Shape *const shape);
/// /!\ Only called by `transform_release` to free shape-specific resources
void shape_free(Shape *const shape);

Weakptr *shape_get_weakptr(Shape *const s);
Weakptr *shape_get_and_retain_weakptr(Shape *const s);

uint16_t shape_get_id(const Shape *shape);

// removes all blocks from shape and resets its transform(s)
void shape_flush(Shape *shape);

// access palette reference to get or set the colors
ColorPalette *shape_get_palette(const Shape *shape);
void shape_set_palette(Shape *shape, ColorPalette *palette);

/// Gets the block in model OR transactions
const Block *shape_get_block(const Shape *const shape,
                             const SHAPE_COORDS_INT_T x,
                             const SHAPE_COORDS_INT_T y,
                             const SHAPE_COORDS_INT_T z);
/// Gets the block in model at the time of calling
Block *shape_get_block_immediate(const Shape *const shape,
                                 const SHAPE_COORDS_INT_T x,
                                 const SHAPE_COORDS_INT_T y,
                                 const SHAPE_COORDS_INT_T z);

/// Returns whether the block is considered added.
/// (a block is not added if it is out of bounds of a fixed size shape, or if
/// the shape already has a block at the given coordinates)
///
/// This function resizes the shape if needed.
bool shape_add_block_as_transaction(Shape *const shape,
                                    Scene *scene,
                                    const SHAPE_COLOR_INDEX_INT_T colorIndex,
                                    const SHAPE_COORDS_INT_T x,
                                    const SHAPE_COORDS_INT_T y,
                                    const SHAPE_COORDS_INT_T z);

/// Removes block from Shape, using the automatic transaction system.
/// Returns whether the block has been removed.
bool shape_remove_block_as_transaction(Shape *const shape,
                                       Scene *scene,
                                       const SHAPE_COORDS_INT_T x,
                                       const SHAPE_COORDS_INT_T y,
                                       const SHAPE_COORDS_INT_T z);

/// Replaces block from Shape, using the automatic transaction system.
/// Returns whether the block has been replaced.
bool shape_paint_block_as_transaction(Shape *const shape,
                                      const SHAPE_COLOR_INDEX_INT_T newColorIndex,
                                      const SHAPE_COORDS_INT_T x,
                                      const SHAPE_COORDS_INT_T y,
                                      const SHAPE_COORDS_INT_T z);

///
void shape_apply_current_transaction(Shape *const shape, bool keepPending);

/// @param useDefaultColor will translate a default color into shape palette
bool shape_add_block(Shape *shape,
                     SHAPE_COLOR_INDEX_INT_T colorIndex,
                     const SHAPE_COORDS_INT_T x,
                     const SHAPE_COORDS_INT_T y,
                     const SHAPE_COORDS_INT_T z,
                     bool useDefaultColor);

bool shape_remove_block(Shape *shape,
                        const SHAPE_COORDS_INT_T x,
                        const SHAPE_COORDS_INT_T y,
                        const SHAPE_COORDS_INT_T z);

bool shape_paint_block(Shape *shape,
                       const SHAPE_COLOR_INDEX_INT_T colorIndex,
                       const SHAPE_COORDS_INT_T x,
                       const SHAPE_COORDS_INT_T y,
                       const SHAPE_COORDS_INT_T z);

void shape_get_bounding_box_size(const Shape *shape, int3 *size);
// TODO: users of this function should probably use bounding box size and discard empty space at
// origin
SHAPE_SIZE_INT3_T shape_get_allocated_size(const Shape *shape);
bool shape_is_within_bounding_box(const Shape *shape, const SHAPE_COORDS_INT3_T coords);

// converts given box to a world axis-aligned box relative to shape
void shape_box_to_aabox(const Shape *s, const Box *box, Box *aabox, bool isCollider);

/// a bounding box is the smallest box containing all shape's blocks, it is axis-aligned and
/// therefore is dependant on which space we express it in,
/// (1) in model space, ie. "block coordinates", the AABB itself w/o transformation
Box shape_get_model_aabb(const Shape *s);
void shape_get_model_aabb_2(const Shape *s, SHAPE_COORDS_INT3_T *bbMin, SHAPE_COORDS_INT3_T *bbMax);
/// (2) in local space, ie. the model AABB w/ local transformations applied (on-demand)
void shape_get_local_aabb(const Shape *s, Box *box);
/// (3) in world space, ie. the model AABB w/ world transformations applied (cached)
/// @returns true if cache was invalid & world AABB recomputed
bool shape_get_world_aabb(Shape *s, Box *box);

// recomputes box from scratch
void shape_reset_box(Shape *shape);
// checks if box can be shrunk depending on the given removed block coordinates
void shape_shrink_box(Shape *shape, const SHAPE_COORDS_INT3_T coords);
// expands box to include given coordinates
void shape_expand_box(Shape *s, const SHAPE_COORDS_INT3_T coords);

size_t shape_get_nb_blocks(const Shape *shape);

void shape_set_model_locked(Shape *s, bool toggle);
bool shape_is_model_locked(Shape *s);

void shape_set_fullname(Shape *s, const char *fullname); // copies fullname
const char *shape_get_fullname(const Shape *s);

void shape_set_color_palette_atlas(Shape *s, ColorAtlas *ca);

// MARK: - Transform -

/// optional pivot
/// notes:
/// - while the pivot point is eg. (2, 4, 3), the transformation required is a (-2, -4, -3)
/// translation, thus shape_get_pivot does not return the actual translation, but a negated value of
/// it to avoid confusion outside of Shape
/// - internal pivot is here to offset model origin to change the way transformations are applied to
/// the shape
/// - for a lua Shape, it is set to its geometric center by default at it is what most user would
/// expect
/// - the effect of internal pivot can entirely be reproduced by using a separate Transform or
/// Object in lua w/ a local position
void shape_set_pivot(Shape *s, const float x, const float y, const float z);
float3 shape_get_pivot(const Shape *s);
void shape_reset_pivot_to_center(Shape *s);

float3 shape_block_to_local(const Shape *s, const float x, const float y, const float z);
float3 shape_block_to_world(const Shape *s, const float x, const float y, const float z);
float3 shape_local_to_block(const Shape *s, const float x, const float y, const float z);
float3 shape_world_to_block(const Shape *s, const float x, const float y, const float z);

/// translation
void shape_set_position(Shape *s, const float x, const float y, const float z);
void shape_set_local_position(Shape *s, const float x, const float y, const float z);
const float3 *shape_get_position(const Shape *s);
const float3 *shape_get_local_position(const Shape *s);
const float3 *shape_get_model_origin(const Shape *s);

/// rotation
void shape_set_rotation(Shape *s, Quaternion *q);
void shape_set_rotation_euler(Shape *s, const float x, const float y, const float z);
void shape_set_local_rotation(Shape *s, Quaternion *q);
void shape_set_local_rotation_euler(Shape *s, const float x, const float y, const float z);
Quaternion *shape_get_rotation(const Shape *s);
void shape_get_rotation_euler(const Shape *s, float3 *euler);
Quaternion *shape_get_local_rotation(const Shape *s);
void shape_get_local_rotation_euler(const Shape *s, float3 *euler);

/// scale
void shape_set_local_scale(Shape *s, const float x, const float y, const float z);
const float3 *shape_get_local_scale(const Shape *s);
void shape_get_lossy_scale(const Shape *s, float3 *scale);

/// matrices
const Matrix4x4 *shape_get_model_matrix(const Shape *s);

bool shape_set_parent(Shape *s, Transform *parent, const bool keepWorld);
/// /!\ shape_remove_parent is INTERNAL use only,
/// for external usage i.e. for shapes that exist as a lua Shape, transform removal needs to be
/// registered in scene, see lua_object for examples
bool shape_remove_parent(Shape *s, const bool keepWorld);
Transform *shape_get_root_transform(const Shape *s);
Transform *shape_get_pivot_transform(const Shape *s); // corresponds to shape model origin
void shape_move_children(Shape *from, Shape *to, const bool keepWorld);
uint32_t shape_count_shape_descendants(const Shape *s);
DoublyLinkedListNode *shape_get_transform_children_iterator(const Shape *s);

// MARK: - Chunks & buffers -

Index3D *shape_get_chunks(const Shape *shape);
size_t shape_get_nb_chunks(const Shape *shape);
CHUNK_COORDS_INT3_T shape_get_chunk_coordinates(const SHAPE_COORDS_INT3_T coords_in_shape,
                                                CHUNK_COORDS_INT3_T *coords_in_chunk);
void shape_get_chunk_and_coordinates(const Shape *shape,
                                     const SHAPE_COORDS_INT3_T coords_in_shape,
                                     Chunk **chunk,
                                     SHAPE_COORDS_INT3_T *chunk_coords,
                                     CHUNK_COORDS_INT3_T *coords_in_chunk);
void shape_log_vertex_buffers(const Shape *shape, bool dirtyOnly, bool transparent);
VertexBuffer *shape_add_buffer(Shape *shape, bool transparency, bool isVertexAttributes);
void shape_refresh_vertices(Shape *shape);
void shape_refresh_all_vertices(Shape *s);
VertexBuffer *shape_get_first_vertex_buffer(const Shape *shape, bool transparent);
VertexBuffer *shape_get_first_index_buffer(const Shape *shape, bool transparent);

// MARK: - Physics -

Rtree *shape_get_rtree(const Shape *shape);
RigidBody *shape_get_rigidbody(const Shape *s);
bool shape_ensure_rigidbody(Shape *s,
                            const uint16_t groups,
                            const uint16_t collidesWith,
                            RigidBody **out);
void shape_fit_collider_to_bounding_box(const Shape *s);
const Box *shape_get_local_collider(const Shape *s);
void shape_compute_world_collider(const Shape *s, Box *box);

/// @param s shape model used as obstacle against a moving object
/// @param modelBox moving object collider aligned with shape model space
/// @param modelVector moving object velocity vector in shape model space
/// @param epsilon collision tolerance in shape model space
/// @param withReplacement typically true if used for simulation, false if used for cast/overlap
/// @param normal axis where the first collision will occur
/// @param extraReplacement filled only if PHYSICS_EXTRA_REPLACEMENTS is enabled
/// @param block ptr to first hit block, convenient to grab here
/// @param blockCoords coordinates of block param
float shape_box_cast(const Shape *s,
                     const Box *modelBox,
                     const float3 *modelVector,
                     const float3 *epsilon,
                     const bool withReplacement,
                     float3 *normal,
                     float3 *extraReplacement,
                     Block **block,
                     SHAPE_COORDS_INT3_T *blockCoords);

/// Casts a world ray against given shape. World distance, local impact, block & block octree
/// coordinates can be returned through pointer parameters
/// @return true if a block is touched
bool shape_ray_cast(const Shape *s,
                    const Ray *worldRay,
                    float *worldDistance,
                    float3 *localImpact,
                    Block **block,
                    SHAPE_COORDS_INT3_T *coords);
bool shape_point_overlap(const Shape *s, const float3 *world);
/// Overlaps a box in shape's model space against its blocks
/// @return true if there is an overlap
bool shape_box_overlap(const Shape *s, const Box *modelBox, Box *out);

// MARK: - Graphics -

bool shape_is_hidden(Shape *s);

void shape_set_draw_mode(Shape *s, ShapeDrawMode m);
ShapeDrawMode shape_get_draw_mode(const Shape *s);

void shape_set_inner_transparent_faces(Shape *s, const bool toggle);
bool shape_draw_inner_transparent_faces(const Shape *s);

void shape_set_shadow(Shape *s, const bool toggle);
bool shape_has_shadow(const Shape *s);

void shape_set_unlit(Shape *s, const bool value);
bool shape_is_unlit(const Shape *s);

void shape_set_layers(Shape *s, const uint16_t value);
uint16_t shape_get_layers(const Shape *s);

// MARK: - POI -

void shape_debug_points_of_interest(const Shape *s);

MapStringFloat3Iterator *shape_get_poi_iterator(const Shape *s);
const float3 *shape_get_point_of_interest(const Shape *s, const char *key);
void shape_set_point_of_interest(Shape *s, const char *key, const float3 *f3);

MapStringFloat3Iterator *shape_get_point_rotation_iterator(const Shape *s);
void shape_set_point_rotation(Shape *s, const char *key, const float3 *f3);
const float3 *shape_get_point_rotation(const Shape *s, const char *key);

void shape_remove_point(Shape *s, const char *key);

// MARK: - Baked lighting -

/// Shape lighting may be initialized from baked lighting, or by calling this function directly.
/// Calling this function will enable the use of baked lighting for the shape i.e. adding or
/// removing blocks will now update baked lighting. If already enabled, it overwrites existing
/// baked lighting
void shape_compute_baked_lighting(Shape *s);

void shape_toggle_baked_lighting(Shape *s, const bool toggle);
bool shape_uses_baked_lighting(const Shape *s);
VERTEX_LIGHT_STRUCT_T *shape_create_lighting_data_blob(const Shape *s, void **inout);
void shape_set_lighting_data_from_blob(Shape *s,
                                       VERTEX_LIGHT_STRUCT_T *blob,
                                       SHAPE_COORDS_INT3_T min,
                                       SHAPE_COORDS_INT3_T max);
void shape_clear_baked_lighing(Shape *s);

/// Helper function that returns light or default light if pos out of bounds
VERTEX_LIGHT_STRUCT_T shape_get_light_or_default(const Shape *s,
                                                 SHAPE_COORDS_INT_T x,
                                                 SHAPE_COORDS_INT_T y,
                                                 SHAPE_COORDS_INT_T z);

/// Block removal may open up sunlight or emission propagation, and/or remove emission sources
void shape_compute_baked_lighting_removed_block(Shape *s,
                                                Chunk *c,
                                                SHAPE_COORDS_INT3_T coords_in_shape,
                                                CHUNK_COORDS_INT3_T coords_in_chunk,
                                                SHAPE_COLOR_INDEX_INT_T blockID);

/// Block addition may shut sunlight or emission propagation, and/or add emission sources
void shape_compute_baked_lighting_added_block(Shape *s,
                                              Chunk *c,
                                              SHAPE_COORDS_INT3_T coords_in_shape,
                                              CHUNK_COORDS_INT3_T coords_in_chunk,
                                              SHAPE_COLOR_INDEX_INT_T blockID);

/// Block replacement may remove or replace emission sources
void shape_compute_baked_lighting_replaced_block(Shape *s,
                                                 Chunk *c,
                                                 SHAPE_COORDS_INT3_T coords_in_shape,
                                                 CHUNK_COORDS_INT3_T coords_in_chunk,
                                                 SHAPE_COLOR_INDEX_INT_T blockID);

uint64_t shape_get_baked_lighting_hash(const Shape *s);

// MARK: - History -

void shape_history_setEnabled(Shape *s, const bool enable);
bool shape_history_getEnabled(Shape *s);
void shape_history_setKeepTransactionPending(Shape *s, const bool b);
bool shape_history_getKeepTransactionPending(Shape *s);
bool shape_history_canUndo(const Shape *const s);
bool shape_history_canRedo(const Shape *const s);
void shape_history_undo(Shape *const s);
void shape_history_redo(Shape *const s);

// MARK: - Lua flags -
// These flags are only used to check from VX whether or not some Lua features should be enabled

bool shape_is_lua_mutable(const Shape *s);
void shape_set_lua_mutable(Shape *s, const bool value);
void shape_enableAnimations(Shape *const s);
void shape_disableAnimations(Shape *const s);
bool shape_getIgnoreAnimations(Shape *const s);

#ifdef __cplusplus
} // extern "C"
#endif
