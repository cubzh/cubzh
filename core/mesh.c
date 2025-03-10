// -------------------------------------------------------------
//  Cubzh Core
//  mesh.c
//  Created by Arthur Cormerais on January 15, 2025.
// -------------------------------------------------------------

#include "mesh.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#define MESH_FLAG_NONE 0
#define MESH_FLAG_CCW 1 // front triangles are CCW
#define MESH_FLAG_SHADOW 2

struct _Mesh {
    Transform* transform;
    Vertex* vb;
    void* ib;
    Material* material;
    float3 *pivot;
    Box *bb;
    Box *worldAABB;
    uint32_t vbCount;       /* 4 bytes */
    uint32_t ibCount;       /* 4 bytes */
    uint32_t hash;          /* 4 bytes */
    uint16_t layers;        /* 2 bytes */
    uint8_t primitiveType;  /* 1 byte */
    uint8_t flags;          /* 1 byte */
};

void _mesh_clear_cached_world_aabb(Mesh *m) {
    if (m->worldAABB != NULL) {
        box_free(m->worldAABB);
        m->worldAABB = NULL;
    }
}

static void _mesh_toggle_flag(Mesh *m, const uint8_t flag, const bool toggle) {
    if (toggle) {
        m->flags |= flag;
    } else {
        m->flags &= ~flag;
    }
}

static bool _mesh_get_flag(const Mesh *m, const uint8_t flag) {
    return (m->flags & flag) != 0;
}

static void _mesh_void_free(void *o) {
    mesh_free((Mesh*)o);
}

Mesh* mesh_new(void) {
    Mesh* m = (Mesh*)malloc(sizeof(Mesh));
    m->transform = transform_new_with_ptr(MeshTransform, m, &_mesh_void_free);
    m->vb = NULL;
    m->ib = NULL;
    m->material = NULL;
    m->pivot = float3_new_zero();
    m->bb = box_new();
    m->worldAABB = NULL;
    m->vbCount = 0;
    m->ibCount = 0;
    m->hash = 0;
    m->layers = 1; // CAMERA_LAYERS_DEFAULT
    m->primitiveType = PrimitiveType_Triangles;
    m->flags = MESH_FLAG_CCW;
    return m;
}

bool mesh_retain(Mesh *m) {
    return transform_retain(m->transform);
}

void mesh_release(Mesh *m) {
    transform_release(m->transform);
}

void mesh_free(Mesh *m) {
    if (m->vb != NULL) {
        free(m->vb);
    }
    if (m->ib != NULL) {
        free(m->ib);
    }
    if (m->material != NULL) {
        material_release(m->material);
    }
    float3_free(m->pivot);
    box_free(m->bb);
    if (m->worldAABB != NULL) {
        box_free(m->worldAABB);
    }
    free(m);
}

Transform* mesh_get_transform(const Mesh *m) {
    return m->transform;
}

void mesh_set_vertex_buffer(Mesh *m, Vertex *vertices, uint32_t count) {
    if (m->vb != NULL) {
        free(m->vb);
    }
    if (vertices != NULL && count > 0) {
        m->vb = vertices;
        m->vbCount = count;
        m->hash = (uint32_t)crc32(0, (const void *)vertices, (uInt)m->vbCount);
    } else {
        m->vb = NULL;
        m->vbCount = 0;
        m->hash = 0;
    }
}

const Vertex* mesh_get_vertex_buffer(const Mesh *m) {
    return m->vb;
}

uint32_t mesh_get_vertex_count(const Mesh *m) {
    return m->vbCount;
}

void mesh_set_index_buffer(Mesh *m, void *indices, uint32_t count) {
    if (m->ib != NULL) {
        free(m->ib);
    }
    m->ib = indices;
    m->ibCount = count;
}

const void* mesh_get_index_buffer(const Mesh *m) {
    return m->ib;
}

uint32_t mesh_get_index_count(const Mesh *m) {
    return m->ibCount;
}

uint32_t mesh_get_hash(const Mesh *m) {
    return m->hash;
}

void mesh_set_primitive_type(Mesh *m, PrimitiveType type) {
    m->primitiveType = (uint8_t)type;
}

PrimitiveType mesh_get_primitive_type(const Mesh *m) {
    return m->primitiveType;
}

void mesh_set_front_ccw(Mesh *m, bool value) {
    _mesh_toggle_flag(m, MESH_FLAG_CCW, value);
}

bool mesh_is_front_ccw(const Mesh *m) {
    return _mesh_get_flag(m, MESH_FLAG_CCW);
}

void mesh_set_pivot(Mesh *m, const float x, const float y, const float z) {
    float3_set(m->pivot, -x, -y, -z);
}

float3 mesh_get_pivot(const Mesh *m) {
    return (float3){-m->pivot->x, -m->pivot->y, -m->pivot->z};
}

void mesh_reset_pivot_to_center(Mesh *m) {
    float3 center; box_get_center(m->bb, &center);
    mesh_set_pivot(m, center.x, center.y, center.z);
}

float3 mesh_get_model_origin(const Mesh *m) {
    const float3 *pos = transform_get_position(m->transform, true);
    return (float3){pos->x + m->pivot->x, pos->y + m->pivot->y, pos->z + m->pivot->z};
}

void mesh_reset_model_aabb(Mesh *m) {
    if (m->vb == NULL || m->vbCount == 0) {
        m->bb->min = (float3){0.0f, 0.0f, 0.0f};
        m->bb->max = (float3){0.0f, 0.0f, 0.0f};
        return;
    }

    m->bb->min = (float3){m->vb[0].x, m->vb[0].y, m->vb[0].z};
    m->bb->max = (float3){m->vb[0].x, m->vb[0].y, m->vb[0].z};
    for (uint32_t i = 1; i < m->vbCount; i++) {
        const Vertex *v = &m->vb[i];
        m->bb->min.x = minimum(m->bb->min.x, v->x);
        m->bb->min.y = minimum(m->bb->min.y, v->y);
        m->bb->min.z = minimum(m->bb->min.z, v->z);
        m->bb->max.x = maximum(m->bb->max.x, v->x);
        m->bb->max.y = maximum(m->bb->max.y, v->y);
        m->bb->max.z = maximum(m->bb->max.z, v->z);
    }

    mesh_fit_collider_to_bounding_box(m);
    _mesh_clear_cached_world_aabb(m);
}

const Box* mesh_get_model_aabb(const Mesh *m) {
    return m->bb;
}

void mesh_get_local_aabb(const Mesh *m, Box *box) {
    if (box == NULL)
        return;

    const Box *model = mesh_get_model_aabb(m);
    transform_refresh(m->transform, false, true); // refresh mtx for intra-frame calculations
    box_to_aabox2(model, box, transform_get_mtx(m->transform), m->pivot, false);
}

bool mesh_get_world_aabb(Mesh *m, Box *box, const bool refreshParents) {
    if (m->worldAABB == NULL || transform_is_any_dirty(m->transform)) {
        const Box *model = mesh_get_model_aabb(m);
        transform_utils_aabox_local_to_world(m->transform, model, box, m->pivot, NoSquarify, refreshParents);
        if (m->worldAABB == NULL) {
            m->worldAABB = box_new_copy(box);
        } else {
            box_copy(m->worldAABB, box);
        }
        transform_reset_any_dirty(m->transform);
        return true;
    } else {
        box_copy(box, m->worldAABB);
        return false;
    }
}

void mesh_set_layers(Mesh *m, const uint16_t value) {
    m->layers = value;
}

uint16_t mesh_get_layers(const Mesh *m) {
    return m->layers;
}

void mesh_fit_collider_to_bounding_box(const Mesh *m) {
    RigidBody *rb = transform_get_rigidbody(m->transform);
    if (rb == NULL || rigidbody_is_collider_custom_set(rb))
        return;
    rigidbody_set_collider(rb, mesh_get_model_aabb(m), false);
}

void mesh_set_material(Mesh* m, Material* material) {
    if (m->material != NULL) {
        material_release(m->material);
    }
    m->material = material;
    if (material != NULL) {
        material_retain(material);
    }
}

Material* mesh_get_material(const Mesh* m) {
    return m->material;
}

void mesh_set_shadow(Mesh *m, bool value) {
    _mesh_toggle_flag(m, MESH_FLAG_SHADOW, value);
}

bool mesh_has_shadow(const Mesh *m) {
    return _mesh_get_flag(m, MESH_FLAG_SHADOW);
}
