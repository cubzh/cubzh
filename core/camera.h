// -------------------------------------------------------------
//  Cubzh Core
//  camera.h
//  Created by Adrien Duermael on July 25, 2015.
// -------------------------------------------------------------

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>

#include "float3.h"
#include "matrix4x4.h"
#include "shape.h"
#include "vxconfig.h"
#include "plane.h"

typedef struct _Camera Camera;

typedef enum {
    Perspective,
    Orthographic
} ProjectionMode;

Camera *camera_new(void);
void camera_release(Camera *c);
void camera_free(Camera *c);

// MARK: - Matrices -

Transform *camera_get_view_transform(const Camera *c);
const Matrix4x4 *camera_get_view_matrix(const Camera *c);     // computed on demand
const Matrix4x4 *camera_get_inv_view_matrix(const Camera *c); // computed on demand
const Matrix4x4 *camera_get_proj_matrix(const Camera *c);     // cached from last renderer frame
const Matrix4x4 *camera_get_inv_proj_matrix(const Camera *c); // cached from last renderer frame
const Matrix4x4 *camera_get_view_proj_matrix(const Camera *c); // cached from last renderer frame
void camera_set_proj_matrix(const Camera *c, Matrix4x4 *proj, Matrix4x4 *viewProj);

// MARK: - Projection -

ProjectionMode camera_get_mode(const Camera *c);
void camera_set_mode(Camera *c, const ProjectionMode value);
float camera_get_fov(const Camera *c);
void camera_set_fov(Camera *c, const float value);
float camera_get_width(const Camera *c);
void camera_set_width(Camera *c, const float value);
float camera_get_height(const Camera *c);
void camera_set_height(Camera *c, const float value);
float camera_get_near(const Camera *c);
void camera_set_near(Camera *c, const float value);
float camera_get_far(const Camera *c);
void camera_set_far(Camera *c, const float value);
float camera_get_target_x(const Camera *c);
void camera_set_target_x(Camera *c, const float value);
float camera_get_target_y(const Camera *c);
void camera_set_target_y(Camera *c, const float value);
float camera_get_target_width(const Camera *c);
void camera_set_target_width(Camera *c, const float value);
float camera_get_target_height(const Camera *c);
void camera_set_target_height(Camera *c, const float value);
bool camera_is_projection_dirty(const Camera *c);
bool camera_is_target_dirty(const Camera *c);
void camera_clear_dirty(Camera *c);

// MARK: - View -

uint32_t camera_get_color(const Camera *c);
void camera_set_color(Camera *c, const uint8_t r, const uint8_t g, const uint8_t b, const uint8_t a);
uint8_t camera_get_alpha(Camera *c);
float camera_get_alpha_f(Camera *c);
void camera_set_alpha(Camera *c, const uint8_t a);
void camera_set_alpha_f(Camera *c, const float a);
uint16_t camera_get_layers(const Camera *c);
void camera_set_layers(Camera *c, const uint16_t value);
uint8_t camera_get_order(const Camera *c);
void camera_set_order(Camera *c, const uint8_t value);
bool camera_is_enabled(const Camera *c);
void camera_set_enabled(Camera *c, const bool value);

// MARK: - Transform -

const float3 *camera_get_position(const Camera *c, const bool refreshParents);
Quaternion* camera_get_rotation(const Camera *c);
void camera_get_rotation_euler(const Camera *c, float3 *euler);

// MARK: - Utils -

/// unsigned normalized screen pos to vector
void camera_unorm_screen_to_vector(const Camera *c, float x, float y, float3 *out_vector);
void camera_unorm_screen_to_ray(const Camera *c, float x, float y, float3 *out_origin, float3 *out_direction);
bool camera_world_to_unorm_screen(const Camera *c, float x, float y, float z, float *resultX, float *resultY);

typedef enum {
    FitToScreen_Minimum,
    FitToScreen_Vertical,
    FitToScreen_Horizontal
} FitToScreen_Orientation;

/// distance necessary to fit given world box to screen
/// @param aspect camera projection aspect ratio
/// @param coverage portion of the camera target that should be filled, on the limiting dimension
/// @param targetInOut point to look at, written into with safe distance to use for orthographic camera
/// @param boxOut optional float[5], contains screen normalized bounding box (min, max) + ratio
/// @returns for perspective camera, result is the distance from eye to target, for orthographic,
/// result is a zoom factor to be multiplied with proj width/height
float camera_fit_to_screen_box(const Camera *c,
                               const float3 *min,
                               const float3 *max,
                               float aspect,
                               float coverage,
                               float3 *targetInOut,
                               float *boxOut,
                               FitToScreen_Orientation orientation);
/// distance necessary to fit bounding sphere, for perspective camera
/// @param aspect camera projection aspect ratio
/// @param coverage portion of the camera target that should be filled, on the limiting dimension
float camera_fit_to_screen_perspective_sphere(const Camera *c,
                                              const Box *box,
                                              float aspect,
                                              float coverage,
                                              FitToScreen_Orientation orientation);

bool camera_layers_match(const uint16_t layers1, const uint16_t layers2);

/// @param widthPoints screen width in points (may be used for ortho camera)
/// @param heightPoints screen height in points (may be used for ortho camera)
/// @param useBox forces the use of box fit for perspective camera
void camera_utils_apply_fit_to_screen(Camera *c, const Box *box, const float coverage,
                                      const uint32_t widthPoints, const uint32_t heightPoints,
                                      const bool useBox, FitToScreen_Orientation orientation);

/// @param hfov horizontal FOV in radians
/// @param aspect camera projection aspect ratio
/// @returns vertical FOV in radians
float camera_utils_horizontal_to_vertical_fov(const float hfov, const float aspect);

/// @param vfov vertical FOV in radians
/// @param aspect camera projection aspect ratio
/// @returns horizontal FOV in radians
float camera_utils_vertical_to_horizontal_fov(const float vfov, const float aspect);

/// @param outVFov out parameter, vertical FOV in radians
/// @param outHFov out parameter, horizontal FOV in radians
void camera_utils_get_vertical_and_horizontal_fov(const Camera *c, const float aspect, float *outVFov, float *outHFov);
float camera_utils_get_vertical_fov(const Camera *c, const float aspect);
float camera_utils_get_vertical_fov2(const Camera *c, const uint32_t screenWidth, const uint32_t screenHeight);
float camera_utils_get_horizontal_fov(const Camera *c, const float aspect);
float camera_utils_get_horizontal_fov2(const Camera *c, const uint32_t screenWidth, const uint32_t screenHeight);

#ifdef __cplusplus
} // extern "C"
#endif
