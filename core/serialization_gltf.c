// -------------------------------------------------------------
//  Cubzh Core
//  serialization_gltf.c
//  Created by Arthur Cormerais on December 30, 2024.
// -------------------------------------------------------------

#include "serialization_gltf.h"

#include <stdlib.h>
#include <string.h>

#define CGLTF_VALIDATE_ENABLE_ASSERTS DEBUG
#define CGLTF_IMPLEMENTATION
#include <cgltf/cgltf.h>

#include "cclog.h"
#include "transform.h"
#include "light.h"
#include "camera.h"

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

    *out = doubly_linked_list_new();

    // Note: we build all possible node hierarchies from the global nodes list, and ignore scenes ;
    // this is because scenes are optional and may not even include all nodes from the file

    Transform **transforms = malloc(data->nodes_count * sizeof(Transform*));

    // first pass, create transforms
    for (cgltf_size j = 0; j < data->nodes_count; ++j) {
        const cgltf_node *node = &data->nodes[j];

        transforms[j] = NULL;

        // select type, skip if filtered out
        if (node->mesh != NULL) {
            if ((filter & AssetType_Mesh) == 0) {
                continue;
            }

            // TODO
            transforms[j] = transform_new(PointTransform);
            transform_set_name(transforms[j], "debug_gltf_mesh");
        } else if (node->light != NULL) {
            if ((filter & AssetType_Light) == 0) {
                continue;
            }

            Light *l = light_new();
            light_set_color(l, node->light->color[0], node->light->color[1], node->light->color[2]);
            light_set_intensity(l, node->light->intensity);
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
            light_set_range(l, node->light->range);
            light_set_angle(l, node->light->spot_outer_cone_angle);
            light_set_hardness(l, node->light->spot_inner_cone_angle / node->light->spot_outer_cone_angle);

            transforms[j] = light_get_transform(l);
            transform_set_name(transforms[j], node->light->name);
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

            transforms[j] = camera_get_view_transform(c);
            transform_set_name(transforms[j], node->camera->name);
        } else {
            if ((filter & AssetType_Object) == 0) {
                continue;
            }

            transforms[j] = transform_new(PointTransform);
            transform_set_name(transforms[j], node->name);
        }
        vx_assert_d(transforms[j] != NULL);

        // set transform
        if (node->has_matrix) {
            transform_utils_set_mtx(transforms[j], (const Matrix4x4 *)node->matrix);
        } else {
            if (node->has_translation) {
                transform_set_local_position_vec(transforms[j], (const float3 *)node->translation);
            }
            if (node->has_rotation) {
                transform_set_local_rotation_vec(transforms[j], (const float4 *)node->rotation);
            }
            if (node->has_scale) {
                transform_set_local_scale_vec(transforms[j], (const float3 *)node->scale);
            }
        }
    }

    // second pass, build hierarchy
    for (cgltf_size j = 0; j < data->nodes_count; ++j) {
        if (transforms[j] != NULL) {
            const cgltf_node *node = &data->nodes[j];

            if (node->parent == NULL) {
                Asset *asset = (Asset*)malloc(sizeof(Asset));
                switch(transform_get_type(transforms[j])) {
                    case PointTransform:
                        asset->type = AssetType_Object;
                        asset->ptr = transforms[j];
                        break;
                    case CameraTransform:
                        asset->type = AssetType_Camera;
                        asset->ptr = transform_get_ptr(transforms[j]);
                        break;
                    case LightTransform:
                        asset->type = AssetType_Light;
                        asset->ptr = transform_get_ptr(transforms[j]);
                        break;
                    // TODO
                    /*case MeshTransform:
                        asset->type = AssetType_Mesh;
                        asset->ptr = transform_get_ptr(transforms[j]);
                        break;*/
                    default:
                        vx_assert_d(false); // if not supported, should've been skipped already
                        continue;
                }
                doubly_linked_list_push_last(*out, asset);
            } else {
                Transform* parentTransform = NULL;
                const cgltf_node* currentParent = node->parent;
                Matrix4x4* combinedMtx = NULL;
                Matrix4x4 nodeMtx;
                
                // find first parent node that wasn't skipped
                while (currentParent != NULL) {
                    const cgltf_size parentIdx = currentParent - data->nodes;
                    if (transforms[parentIdx] != NULL) {
                        parentTransform = transforms[parentIdx];
                        break;
                    } else {
                        // accumulate transformations from skipped nodes
                        nodeMtx = matrix4x4_identity;
                        if (currentParent->has_matrix) {
                            matrix4x4_copy(&nodeMtx, (const Matrix4x4*)currentParent->matrix);
                        } else {
                            const float3 scale = currentParent->has_scale ? 
                                *(const float3*)currentParent->scale : float3_one;
                            const float3 position = currentParent->has_translation ? 
                                *(const float3*)currentParent->translation : float3_zero;
                            const Quaternion rotation = currentParent->has_rotation ? 
                                *(const Quaternion*)currentParent->rotation : quaternion_identity;
                            
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
                    matrix4x4_op_multiply(combinedMtx, transform_get_mtx(transforms[j]));
                    transform_utils_set_mtx(transforms[j], combinedMtx);
                    matrix4x4_free(combinedMtx);
                }

                if (parentTransform != NULL) {
                    transform_set_parent(transforms[j], parentTransform, false);
                }
            }
        }
    }

    free(transforms);

    cgltf_free(data);
    return true;
}
