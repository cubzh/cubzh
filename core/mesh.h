// -------------------------------------------------------------
//  Cubzh Core
//  mesh.h
//  Created by Arthur Cormerais on January 15, 2025.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include "transform.h"
#include "material.h"

typedef struct {
    float x, y, z;
    uint8_t nx, ny, nz;
    uint8_t tx, ty, tz;
    uint32_t rgba;
    int16_t u, v;
} Vertex;

typedef enum {
    PrimitiveType_Points,
    PrimitiveType_Lines,
    PrimitiveType_LineStrip,
    PrimitiveType_Triangles,
    PrimitiveType_TriangleStrip
} PrimitiveType;

typedef struct _Mesh Mesh;

Mesh* mesh_new(void);
bool mesh_retain(Mesh *m);
void mesh_release(Mesh *m);
void mesh_free(Mesh* m);

Transform* mesh_get_transform(const Mesh* m);
void mesh_set_vertex_buffer(Mesh* m, Vertex* vertices, uint32_t count); // takes ownership
const Vertex* mesh_get_vertex_buffer(const Mesh* m);
uint32_t mesh_get_vertex_count(const Mesh* m);
void mesh_set_index_buffer(Mesh* m, void* indices, uint32_t count); // takes ownership
const void* mesh_get_index_buffer(const Mesh* m);
uint32_t mesh_get_index_count(const Mesh* m);
uint32_t mesh_get_hash(const Mesh* m);
void mesh_set_primitive_type(Mesh* m, PrimitiveType type);
PrimitiveType mesh_get_primitive_type(const Mesh* m);
void mesh_set_front_ccw(Mesh* m, bool value);
bool mesh_is_front_ccw(const Mesh* m);
void mesh_set_pivot(Mesh *m, const float x, const float y, const float z);
float3 mesh_get_pivot(const Mesh *m);
void mesh_reset_pivot_to_center(Mesh *m);
float3 mesh_get_model_origin(const Mesh *m);
void mesh_reset_model_aabb(Mesh *m);
const Box* mesh_get_model_aabb(const Mesh *m);
void mesh_get_local_aabb(const Mesh *m, Box *box);
bool mesh_get_world_aabb(Mesh *m, Box *box, const bool refreshParents);
void mesh_set_layers(Mesh *m, const uint16_t value);
uint16_t mesh_get_layers(const Mesh *m);
void mesh_fit_collider_to_bounding_box(const Mesh *m);
void mesh_set_material(Mesh* m, Material* material);
Material* mesh_get_material(const Mesh* m);
void mesh_set_shadow(Mesh *m, bool value);
bool mesh_has_shadow(const Mesh *m);

#ifdef __cplusplus
}
#endif 