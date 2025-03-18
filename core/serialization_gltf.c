// -------------------------------------------------------------
//  Cubzh Core
//  serialization_gltf.c
//  Created by Arthur Cormerais on December 30, 2024.
// -------------------------------------------------------------

#include "serialization_gltf.h"

#include <stdlib.h>
#include <string.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Weverything"
#define CGLTF_VALIDATE_ENABLE_ASSERTS DEBUG
#define CGLTF_IMPLEMENTATION
#include <cgltf/cgltf.h>
#pragma GCC diagnostic pop

#include "cclog.h"
#include "transform.h"
#include "light.h"
#include "camera.h"
#include "mesh.h"
#include "material.h"
#include "texture.h"
#include "utils.h"

#define GL_LINEAR 9729
#define GL_NEAREST 9728

static Texture* _serialization_gltf_load_texture(const cgltf_texture* texture, const TextureType type) {
    if (texture == NULL || texture->image == NULL) {
        return NULL;
    }

    const cgltf_image* image = texture->image;
    void* data;
    uint32_t size;
    Texture *t = NULL;
    if (image->buffer_view != NULL) { // embedded image data
        data = ((char*)image->buffer_view->buffer->data) + image->buffer_view->offset;
        size = (uint32_t)image->buffer_view->size;
        t = texture_new_raw(data, size, type);
    } else if (image->uri != NULL) { // external image file
        FILE* file = fopen(image->uri, "rb");
        if (file == NULL) {
            return NULL;
        }

        fseek(file, 0, SEEK_END);
        size = (uint32_t)ftell(file);
        fseek(file, 0, SEEK_SET);

        data = malloc(size);
        if (data == NULL) {
            fclose(file);
            return NULL;
        }

        if (fread(data, 1, size, file) != size) {
            free(data);
            fclose(file);
            return NULL;
        }

        t = texture_new_raw(data, size, type);
        free(data);
        fclose(file);
    } else {
        return NULL;
    }

    if (t != NULL) {
        if (texture->sampler != NULL) {
            const cgltf_sampler* sampler = texture->sampler;
            const bool useLinear = sampler->mag_filter == GL_LINEAR || sampler->min_filter == GL_LINEAR;
            texture_set_filtering(t, useLinear);
        } else {
            texture_set_filtering(t, type != TextureType_Normal);
        }
    }

    return t;
}

Asset *_serialization_gltf_new_asset(Transform *t) {
    Asset *asset = (Asset*)malloc(sizeof(Asset));
    switch(transform_get_type(t)) {
        case PointTransform:
            asset->type = AssetType_Object;
            asset->ptr = t;
            break;
        case CameraTransform:
            asset->type = AssetType_Camera;
            asset->ptr = transform_get_ptr(t);
            break;
        case LightTransform:
            asset->type = AssetType_Light;
            asset->ptr = transform_get_ptr(t);
            break;
        case MeshTransform:
            asset->type = AssetType_Mesh;
            asset->ptr = transform_get_ptr(t);
            break;
        default:
            asset->type = AssetType_Unknown;
            asset->ptr = NULL;
            vx_assert_d(false); // if not supported, should've been skipped already
            break;
    }
    return asset;
}

bool serialization_gltf_load(const void *buffer, const size_t size, const ASSET_MASK_T filter, DoublyLinkedList **out) {
    vx_assert_d(*out == NULL);

    cgltf_memory_options memoryOptions = {
        NULL, // default alloc
        NULL, // default free
        NULL // userdata
    };

    cgltf_file_options fileOptions = {
        NULL, // default file read
        NULL, // default file release
        NULL // userdata
    };

    cgltf_options options = {
        cgltf_file_type_invalid, // auto-detect
        0, // auto JSON token count
        memoryOptions,
        fileOptions
    };

    cgltf_data *data;
    const cgltf_result result = cgltf_parse(&options, buffer, size, &data);
    switch(result) {
        case cgltf_result_success:
            break;
        case cgltf_result_data_too_short:
            cclog_error("GLTF load failed: data too short");
            return false;
        case cgltf_result_unknown_format:
            cclog_error("GLTF load failed: unknown format");
            return false;
        case cgltf_result_invalid_json:
            cclog_error("GLTF load failed: invalid JSON");
            return false;
        case cgltf_result_invalid_gltf:
            cclog_error("GLTF load failed: invalid GLTF");
            return false;
        case cgltf_result_invalid_options:
            cclog_error("GLTF load failed: invalid options");
            return false;
        case cgltf_result_file_not_found:
            cclog_error("GLTF load failed: file not found");
            return false;
        case cgltf_result_io_error:
            cclog_error("GLTF load failed: IO error");
            return false;
        case cgltf_result_out_of_memory:
            cclog_error("GLTF load failed: out of memory");
            return false;
        case cgltf_result_legacy_gltf:
            cclog_error("GLTF load failed: legacy GLTF");
            return false;
        default:
            return false;
    }

    const cgltf_result buffersResult = cgltf_load_buffers(&options, data, NULL);
    switch(buffersResult) {
        case cgltf_result_success:
            break;
        case cgltf_result_data_too_short:
            cclog_error("GLTF buffers failed: data too short");
            return false;
        case cgltf_result_unknown_format:
            cclog_error("GLTF buffers failed: unknown format");
            return false;
        case cgltf_result_invalid_json:
            cclog_error("GLTF buffers failed: invalid JSON");
            return false;
        case cgltf_result_invalid_gltf:
            cclog_error("GLTF buffers failed: invalid GLTF");
            return false;
        case cgltf_result_invalid_options:
            cclog_error("GLTF buffers failed: invalid options");
            return false;
        case cgltf_result_file_not_found:
            cclog_error("GLTF buffers failed: file not found");
            return false;
        case cgltf_result_io_error:
            cclog_error("GLTF buffers failed: IO error");
            return false;
        case cgltf_result_out_of_memory:
            cclog_error("GLTF buffers failed: out of memory");
            return false;
        case cgltf_result_legacy_gltf:
            cclog_error("GLTF buffers failed: legacy GLTF");
            return false;
        default:
            return false;
    }

    *out = doubly_linked_list_new();

    // Note: we build all possible node hierarchies from the global nodes list, and ignore scenes ;
    // this is because scenes are optional and may not even include all nodes from the file

    Transform **transforms = malloc(data->nodes_count * sizeof(Transform*));

    // first pass, create transforms
    for (cgltf_size i = 0; i < data->nodes_count; ++i) {
        const cgltf_node *node = &data->nodes[i];

        transforms[i] = NULL;

        // select type, skip if filtered out
        if (node->mesh != NULL) {
            if ((filter & AssetType_Mesh) == 0) {
                continue;
            }

            // map each primitive to a separate mesh transform
            for (size_t j = 0; j < node->mesh->primitives_count; ++j) {
                const cgltf_primitive* primitive = &node->mesh->primitives[j];
                
                const cgltf_attribute* posAttr = NULL;
                const cgltf_attribute* normalAttr = NULL;
                const cgltf_attribute* uvAttr = NULL;
                const cgltf_attribute* colorAttr = NULL;
                const cgltf_attribute* tangentAttr = NULL;
                
                for (size_t k = 0; k < primitive->attributes_count; k++) {
                    switch (primitive->attributes[k].type) {
                        case cgltf_attribute_type_position:
                            posAttr = &primitive->attributes[k];
                            break;
                        case cgltf_attribute_type_normal:
                            normalAttr = &primitive->attributes[k];
                            break;
                        case cgltf_attribute_type_texcoord:
                            uvAttr = &primitive->attributes[k];
                            break;
                        case cgltf_attribute_type_color:
                            colorAttr = &primitive->attributes[k];
                            break;
                        case cgltf_attribute_type_tangent:
                            tangentAttr = &primitive->attributes[k];
                            break;
                        case cgltf_attribute_type_joints:
                        case cgltf_attribute_type_weights:
                        case cgltf_attribute_type_custom:
                        case cgltf_attribute_type_invalid:
                        default:
                            break;
                    }
                }
                
                if (posAttr) {
                    const cgltf_accessor* posAccessor = posAttr->data;
                    const cgltf_accessor* normalAccessor = normalAttr ? normalAttr->data : NULL;
                    const cgltf_accessor* uvAccessor = uvAttr ? uvAttr->data : NULL;
                    const cgltf_accessor* colorAccessor = colorAttr ? colorAttr->data : NULL;
                    const cgltf_accessor* tangentAccessor = tangentAttr ? tangentAttr->data : NULL;

                    const uint32_t vertexCount = (uint32_t)posAccessor->count;
                    Vertex* vertices = (Vertex*)malloc(vertexCount * sizeof(Vertex));
                    
                    for (size_t k = 0; k < vertexCount; ++k) {
                        // position (float3)
                        cgltf_accessor_read_float(posAccessor, k, &vertices[k].x, 3);

                        vertices[k].unused = 0.0f;
                        
                        // normal (uint8 normalized)
                        if (normalAccessor != NULL) {
                            float normal[3]; cgltf_accessor_read_float(normalAccessor, k, normal, 3);
                            vertices[k].nx = utils_pack_norm_to_uint8(normal[0]);
                            vertices[k].ny = utils_pack_norm_to_uint8(normal[1]);
                            vertices[k].nz = utils_pack_norm_to_uint8(normal[2]);
                        } else {
                            vertices[k].nx = utils_pack_norm_to_uint8(0.0f);
                            vertices[k].ny = utils_pack_norm_to_uint8(0.0f);
                            vertices[k].nz = utils_pack_norm_to_uint8(1.0f); // default to forward
                        }

                        // tangent (uint8 normalized, pre-apply handedness)
                        if (tangentAccessor != NULL) {
                            float tangent[4]; cgltf_accessor_read_float(tangentAccessor, k, tangent, 4);
                            vertices[k].tx = utils_pack_norm_to_uint8(tangent[0] * tangent[3]);
                            vertices[k].ty = utils_pack_norm_to_uint8(tangent[1] * tangent[3]);
                            vertices[k].tz = utils_pack_norm_to_uint8(tangent[2] * tangent[3]);
                        } else {
                            vertices[k].tx = utils_pack_norm_to_uint8(1.0f); // default to right
                            vertices[k].ty = utils_pack_norm_to_uint8(0.0f);
                            vertices[k].tz = utils_pack_norm_to_uint8(0.0f);
                        }

                        // color (uint32)
                        if (colorAccessor != NULL) {
                            float color[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
                            cgltf_accessor_read_float(colorAccessor, k, color,
                                                      colorAccessor->type == cgltf_type_vec3 ? 3 : 4);
                            
                            vertices[k].rgba = utils_uint8_to_rgba(
                                (uint8_t)(color[0] * 255.0f),
                                (uint8_t)(color[1] * 255.0f),
                                (uint8_t)(color[2] * 255.0f),
                                (uint8_t)(color[3] * 255.0f)
                            );
                        } else {
                            vertices[k].rgba = 0xFFFFFFFF;
                        }

                        // uv (int16 normalized)
                        if (uvAccessor != NULL) {
                            float uv[2]; cgltf_accessor_read_float(uvAccessor, k, uv, 2);
                            vertices[k].u = utils_pack_unorm_to_int16(uv[0], true);
                            vertices[k].v = utils_pack_unorm_to_int16(uv[1], true);
                        } else {
                            vertices[k].u = utils_pack_unorm_to_int16(0.0f, false);
                            vertices[k].v = utils_pack_unorm_to_int16(0.0f, false);
                        }
                    }

                    void *indices = NULL;
                    uint32_t ibCount = 0;
                    PrimitiveType primitiveType = PrimitiveType_Triangles;
                    if (primitive->indices != NULL) {
                        const cgltf_accessor* indexAccessor = primitive->indices;
                        const bool index32 = indexAccessor->count > UINT16_MAX;

                        indices = malloc(indexAccessor->count * (index32 ? sizeof(uint32_t) : sizeof(uint16_t)));
                        ibCount = (uint32_t)indexAccessor->count;

                        cgltf_size index;
                        for (size_t k = 0; k < indexAccessor->count; ++k) {
                            index = cgltf_accessor_read_index(indexAccessor, k);
                            if (index32) {
                                ((uint32_t*)indices)[k] = (uint32_t)index;
                            } else {
                                ((uint16_t*)indices)[k] = (uint16_t)index;
                            }
                        }
                    } else {
                        switch(primitive->type) {
                            case cgltf_primitive_type_points: {
                                primitiveType = PrimitiveType_Points;
                                break;
                            }
                            case cgltf_primitive_type_lines: {
                                primitiveType = PrimitiveType_Lines;
                                break;
                            }
                            case cgltf_primitive_type_line_loop: {
                                // convert line loop to line strip by adding an extra index to close the loop
                                primitiveType = PrimitiveType_LineStrip;
                                const bool index32 = vertexCount > UINT16_MAX;
                                ibCount = vertexCount + 1;
                                indices = malloc(ibCount * (index32 ? sizeof(uint32_t) : sizeof(uint16_t)));
                                
                                // generate sequential indices and add first vertex at the end
                                for (uint32_t k = 0; k < vertexCount; ++k) {
                                    if (index32) {
                                        ((uint32_t*)indices)[k] = k;
                                    } else {
                                        ((uint16_t*)indices)[k] = (uint16_t)k;
                                    }
                                }
                                if (index32) {
                                    ((uint32_t*)indices)[vertexCount] = 0;
                                } else {
                                    ((uint16_t*)indices)[vertexCount] = 0;
                                }
                                break;
                            }
                            case cgltf_primitive_type_line_strip:
                                primitiveType = PrimitiveType_LineStrip;
                                break;
                            case cgltf_primitive_type_triangles:
                                primitiveType = PrimitiveType_Triangles;
                                break;
                            case cgltf_primitive_type_triangle_strip:
                                primitiveType = PrimitiveType_TriangleStrip;
                                break;
                            case cgltf_primitive_type_triangle_fan: {
                                // convert triangle fan to regular triangles
                                primitiveType = PrimitiveType_Triangles;
                                const uint32_t triCount = vertexCount - 2;
                                const bool index32 = vertexCount > UINT16_MAX;
                                ibCount = triCount * 3;
                                indices = malloc(ibCount * (index32 ? sizeof(uint32_t) : sizeof(uint16_t)));

                                for (uint32_t k = 0; k < triCount; k++) {
                                    if (index32) {
                                        ((uint32_t*)indices)[k * 3] = 0;            // center vertex
                                        ((uint32_t*)indices)[k * 3 + 1] = k + 1;    // current vertex
                                        ((uint32_t*)indices)[k * 3 + 2] = k + 2;    // next vertex
                                    } else {
                                        ((uint16_t*)indices)[k * 3] = 0;            // center vertex
                                        ((uint16_t*)indices)[k * 3 + 1] = (uint16_t)k + 1;    // current vertex
                                        ((uint16_t*)indices)[k * 3 + 2] = (uint16_t)k + 2;    // next vertex
                                    }
                                }
                                break;
                            }
                            default:
                                vx_assert_d(false);
                                break;
                        }
                    }

                    Material* material = NULL;
                    if (primitive->material != NULL) {
                        const cgltf_material* gltf_material = primitive->material;
                        material = material_new();

                        if (gltf_material->has_pbr_metallic_roughness) {
                            const cgltf_pbr_metallic_roughness* pbr = &gltf_material->pbr_metallic_roughness;
                            material_set_albedo(material, 
                                utils_float_to_rgba(
                                    pbr->base_color_factor[0],
                                    pbr->base_color_factor[1], 
                                    pbr->base_color_factor[2],
                                    pbr->base_color_factor[3]));
                                
                            material_set_metallic(material, pbr->metallic_factor);
                            material_set_roughness(material, pbr->roughness_factor);

                            // albedo texture
                            if (pbr->base_color_texture.texture != NULL) {
                                Texture* texture = _serialization_gltf_load_texture(pbr->base_color_texture.texture, TextureType_Albedo);
                                if (texture != NULL) {
                                    material_set_texture(material, MaterialTexture_Albedo, texture);
                                    texture_release(texture);
                                }
                            }

                            // metallic-roughness map
                            if (pbr->metallic_roughness_texture.texture != NULL) {
                                Texture* texture = _serialization_gltf_load_texture(pbr->metallic_roughness_texture.texture, TextureType_Metallic);
                                if (texture != NULL) {
                                    material_set_texture(material, MaterialTexture_Metallic, texture);
                                    texture_release(texture);
                                }
                            }
                        }

                        const float emissiveStrength = gltf_material->has_emissive_strength ? 
                            gltf_material->emissive_strength.emissive_strength : 0.0f;
                        material_set_emissive(material,
                            utils_float_to_rgba(
                                gltf_material->emissive_factor[0] * emissiveStrength,
                                gltf_material->emissive_factor[1] * emissiveStrength,
                                gltf_material->emissive_factor[2] * emissiveStrength,
                                0.0f));

                        // emissive texture
                        if (gltf_material->emissive_texture.texture != NULL) {
                            Texture* texture = _serialization_gltf_load_texture(gltf_material->emissive_texture.texture, TextureType_Emissive);
                            if (texture != NULL) {
                                material_set_texture(material, MaterialTexture_Emissive, texture);
                                texture_release(texture);
                            }
                        }

                        // normal map
                        if (gltf_material->normal_texture.texture != NULL) {
                            Texture* texture = _serialization_gltf_load_texture(gltf_material->normal_texture.texture, TextureType_Normal);
                            if (texture != NULL) {
                                material_set_texture(material, MaterialTexture_Normal, texture);
                                texture_release(texture);
                            }
                        }

                        switch (gltf_material->alpha_mode) {
                            default:
                            case cgltf_alpha_mode_opaque:
                                material_set_opaque(material, true);
                                material_set_alpha_cutout(material, -1.0f);
                                break;
                            case cgltf_alpha_mode_mask:
                                material_set_opaque(material, true);
                                material_set_alpha_cutout(material, gltf_material->alpha_cutoff);
                                break;
                            case cgltf_alpha_mode_blend:
                                material_set_opaque(material, false);
                                material_set_alpha_cutout(material, -1.0f);
                                break;
                        }

                        material_set_double_sided(material, gltf_material->double_sided);
                        material_set_unlit(material, gltf_material->unlit);
                    }
                    
                    Mesh* mesh = mesh_new();
                    mesh_set_vertex_buffer(mesh, vertices, (uint32_t)posAccessor->count);
                    mesh_set_index_buffer(mesh, indices, ibCount);
                    mesh_set_primitive_type(mesh, primitiveType);
                    mesh_set_front_ccw(mesh, false);
                    mesh_reset_model_aabb(mesh);
                    mesh_set_material(mesh, material);
                    
                    Transform* meshTransform = mesh_get_transform(mesh);
                    if (j == 0) {
                        transforms[i] = meshTransform;
                    } else {
                        transform_set_parent(meshTransform, transforms[i], false);
                    }
                    transform_set_name(meshTransform, node->name);

                    if (material != NULL) {
                        material_release(material);
                    }
                }
            }
        } else if (node->light != NULL) {
            if ((filter & AssetType_Light) == 0) {
                continue;
            }

            Light *l = light_new();
            light_set_color(l, node->light->color[0], node->light->color[1], node->light->color[2]);
            light_set_intensity(l, CLAMP01F(node->light->intensity));
            switch(node->light->type) {
                case cgltf_light_type_directional:
                    light_set_type(l, LightType_Directional);
                    break;
                case cgltf_light_type_point:
                    light_set_type(l, LightType_Point);
                    break;
                case cgltf_light_type_spot:
                    light_set_type(l, LightType_Spot);
                    break;
                default:
                    break;
            }
            light_set_range(l, node->light->range > 0.0f ? node->light->range : LIGHT_DEFAULT_RANGE);
            light_set_angle(l, node->light->spot_outer_cone_angle > 0.0f ? node->light->spot_outer_cone_angle : LIGHT_DEFAULT_ANGLE);
            light_set_hardness(l, node->light->spot_inner_cone_angle / light_get_angle(l));

            transforms[i] = light_get_transform(l);
            transform_set_name(transforms[i], node->light->name);
        } else if (node->camera != NULL) {
            if ((filter & AssetType_Camera) == 0) {
                continue;
            }

            Camera *c = camera_new();
            switch(node->camera->type) {
                case cgltf_camera_type_orthographic: {
                    camera_set_mode(c, Orthographic);
                    camera_set_width(c, node->camera->data.orthographic.xmag);
                    camera_set_height(c, node->camera->data.orthographic.ymag);
                    camera_set_near(c, node->camera->data.orthographic.znear);
                    camera_set_far(c, node->camera->data.orthographic.zfar);
                    break;
                }
                case cgltf_camera_type_perspective: {
                    camera_set_mode(c, Perspective);
                    if (node->camera->data.perspective.has_aspect_ratio) {
                        camera_set_width(c, node->camera->data.perspective.aspect_ratio);
                        camera_set_height(c, 1.0f);
                    }
                    camera_set_fov(c, node->camera->data.perspective.yfov);
                    if (node->camera->data.perspective.has_zfar) {
                        camera_set_far(c, node->camera->data.perspective.zfar);
                    }
                    camera_set_near(c, node->camera->data.perspective.znear);
                    break;
                }
                default:
                    break;
            }

            transforms[i] = camera_get_view_transform(c);
            transform_set_name(transforms[i], node->camera->name);
        } else {
            if ((filter & AssetType_Object) == 0) {
                continue;
            }

            transforms[i] = transform_new(PointTransform);
            transform_set_name(transforms[i], node->name);
        }
        vx_assert_d(transforms[i] != NULL);

        // set transform
        if (node->has_matrix) {
            transform_utils_set_mtx(transforms[i], (const Matrix4x4 *)node->matrix);
        } else {
            if (node->has_translation) {
                transform_set_local_position_vec(transforms[i], (const float3 *)node->translation);
            }
            if (node->has_rotation) {
                transform_set_local_rotation_vec(transforms[i], (const float4 *)node->rotation);
            }
            if (node->has_scale) {
                transform_set_local_scale_vec(transforms[i], (const float3 *)node->scale);
            }
        }
    }

    // second pass, build hierarchy
    for (cgltf_size j = 0; j < data->nodes_count; ++j) {
        if (transforms[j] != NULL) {
            const cgltf_node *node = &data->nodes[j];

            if (node->parent == NULL) {
                doubly_linked_list_push_last(*out, _serialization_gltf_new_asset(transforms[j]));
            } else {
                Transform* parentTransform = NULL;
                cgltf_node* currentParent = node->parent;
                Matrix4x4* combinedMtx = NULL;
                Matrix4x4 nodeMtx;
                
                // find first parent node that wasn't skipped
                while (currentParent != NULL) {
                    const cgltf_size parentIdx = (cgltf_size)(currentParent - data->nodes);
                    if (transforms[parentIdx] != NULL) {
                        parentTransform = transforms[parentIdx];
                        break;
                    } else if (currentParent->has_matrix || currentParent->has_scale ||
                               currentParent->has_translation || currentParent->has_rotation) {
                            
                        // accumulate transformations from skipped nodes
                        nodeMtx = matrix4x4_identity;
                        if (currentParent->has_matrix) {
                            matrix4x4_copy(&nodeMtx, (const Matrix4x4*)currentParent->matrix);
                        } else {
                            const float3 scale = currentParent->has_scale ? 
                                *(const float3*)currentParent->scale : float3_one;
                            const float3 position = currentParent->has_translation ? 
                                *(const float3*)currentParent->translation : float3_zero;
                            Quaternion rotation = currentParent->has_rotation ?
                                *(Quaternion*)currentParent->rotation : quaternion_identity;

                            transform_utils_compute_SRT(&nodeMtx, &scale, &rotation, &position);
                        }

                        if (combinedMtx == NULL) {
                            combinedMtx = matrix4x4_new_copy(&nodeMtx);
                        } else {
                            matrix4x4_op_multiply_2(&nodeMtx, combinedMtx);
                        }
                    }
                    currentParent = currentParent->parent;
                }

                if (combinedMtx != NULL) {
                    transform_refresh(transforms[j], false, false);
                    matrix4x4_op_multiply(combinedMtx, transform_get_mtx(transforms[j]));
                    transform_utils_set_mtx(transforms[j], combinedMtx);
                    matrix4x4_free(combinedMtx);
                }

                if (parentTransform != NULL) {
                    transform_set_parent(transforms[j], parentTransform, false);
                } else {
                    doubly_linked_list_push_last(*out, _serialization_gltf_new_asset(transforms[j]));
                }
            }
        }
    }

    free(transforms);

    cgltf_free(data);
    return true;
}
