// -------------------------------------------------------------
//  Cubzh Core
//  camera.c
//  Created by Adrien Duermael on July 25, 2015.
// -------------------------------------------------------------

#include "camera.h"

#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "config.h"
#include "utils.h"
#include "xptools.h"
#include "vxconfig.h"
#include "transform.h"
#include "light.h"

#define CAMERA_NONE     0
#define CAMERA_PROJ     1   // camera projection is dirty
#define CAMERA_TARGET   2   // camera target is dirty

///  Projection and target dimensions are override values, when zero: default screen size should be used,
/// when non-zero: values set by coder should be used.
///
///  Camera stores the minimum FOV: it corresponds to vertical FOV in landscape, and horizontal FOV in
/// portrait. Use the utils function camera_utils_get_vertical_and_horizontal_fov to retrieve both
/// values based on screen orientation.
struct _Camera {
    // camera view transform, used to transform every object in view
    Transform *view;

    // cached matrices useful for helper functions
    Matrix4x4 *viewMtx, *invViewMtx; // computed on demand
    Matrix4x4 *projMatrix, *invProjMatrix, *viewProjMatrix; // cached from last renderer frame

    // projection parameters
    ProjectionMode mode; /* 4 bytes */
    float fov; /* 4 bytes */
    float width, height; /* 2 x 4 bytes */
    float nearPlane, farPlane; /* 2 x 4 bytes */

    // target in screen space (points)
    float targetX, targetY; /* 2 x 4 bytes */
    float targetWidth, targetHeight; /* 2 x 4 bytes */
    uint32_t color; /* 4 bytes */

    uint16_t layers; /* 2 bytes */
    uint8_t viewOrder; /* 1 byte */
    bool enabled; /* 1 byte */
    uint8_t dirty; /* 1 byte */

    char pad[7];
};

static void _camera_set_dirty(Camera *c, const uint8_t flag) {
    c->dirty |= flag;
}

static bool _camera_get_dirty(const Camera *c, const uint8_t flag) {
    return flag == (c->dirty & flag);
}

void _camera_void_free(void *o) {
    camera_free((Camera*)o);
}
    
Camera *camera_new(void) {
    Camera *c = (Camera *)malloc(sizeof(Camera));
    if (c == NULL) {
        return NULL;
    }
    
    c->view = transform_make_with_ptr(CameraTransform, c, _camera_void_free);
    c->viewMtx = matrix4x4_new_identity();
    c->invViewMtx = matrix4x4_new_identity();
    c->projMatrix = matrix4x4_new_identity();
    c->invProjMatrix = matrix4x4_new_identity();
    c->viewProjMatrix = matrix4x4_new_identity();
    c->mode = Perspective;
    c->fov = CAMERA_DEFAULT_FOV;
    c->width = -1.0f;
    c->height = -1.0f;
    c->nearPlane = CAMERA_DEFAULT_NEAR;
    c->farPlane = CAMERA_DEFAULT_FAR;
    c->targetX = 0.0f;
    c->targetY = 0.0f;
    c->targetWidth = -1.0f;
    c->targetHeight = -1.0f;
    c->color = UINT32_MAX;
    c->layers = CAMERA_LAYERS_DEFAULT;
    c->viewOrder = CAMERA_ORDER_DEFAULT;
    c->enabled = false;
    c->dirty = CAMERA_NONE;

    return c;
}

void camera_release(Camera *c) {
    transform_release(c->view);
}

void camera_free(Camera *c) {
    if (c != NULL) {
        matrix4x4_free(c->viewMtx);
        matrix4x4_free(c->invViewMtx);
        matrix4x4_free(c->projMatrix);
        matrix4x4_free(c->invProjMatrix);
        matrix4x4_free(c->viewProjMatrix);
    }
    free(c);
}

// MARK: - Matrices -

Transform *camera_get_view_transform(const Camera *c) {
    if (c == NULL) {
        return NULL;
    }
    return c->view;
}

const Matrix4x4 *camera_get_view_matrix(const Camera *c) {
    if (c == NULL) {
        return NULL;
    }
    // view matrix corresponds to the view transform unscaled wtl matrix
    matrix4x4_copy(c->viewMtx, transform_get_wtl(c->view));
    float3 scale;
    matrix4x4_get_scaleXYZ(c->viewMtx, &scale);
    matrix4x4_op_unscale(c->viewMtx, &scale);
    return c->viewMtx;
}

const Matrix4x4 *camera_get_inv_view_matrix(const Camera *c) {
    if (c == NULL) {
        return NULL;
    }
    // inverse view matrix corresponds to the view transform unscaled ltw matrix
    matrix4x4_copy(c->invViewMtx, transform_get_ltw(c->view));
    float3 scale;
    matrix4x4_get_scaleXYZ(c->invViewMtx, &scale);
    matrix4x4_op_unscale(c->invViewMtx, &scale);
    return c->invViewMtx;
}

const Matrix4x4 *camera_get_proj_matrix(const Camera *c) {
    if (c == NULL) {
        return NULL;
    }
    return c->projMatrix;
}

const Matrix4x4 *camera_get_inv_proj_matrix(const Camera *c) {
    if (c == NULL) {
        return NULL;
    }
    return c->invProjMatrix;
}

const Matrix4x4 *camera_get_view_proj_matrix(const Camera *c) {
    if (c == NULL) {
        return NULL;
    }
    return c->viewProjMatrix;
}

void camera_set_proj_matrix(const Camera *c, Matrix4x4 *proj, Matrix4x4 *viewProj) {
    if (c == NULL) {
        return;
    }
    matrix4x4_copy(c->projMatrix, proj);
    matrix4x4_copy(c->invProjMatrix, proj);
    matrix4x4_op_invert(c->invProjMatrix);
    matrix4x4_copy(c->viewProjMatrix, viewProj);
}

// MARK: - Projection -

ProjectionMode camera_get_mode(const Camera *c) {
    return c->mode;
}

void camera_set_mode(Camera *c, const ProjectionMode value) {
    c->mode = value;
    _camera_set_dirty(c, CAMERA_PROJ);
}

float camera_get_fov(const Camera *c) {
    return c->fov;
}

void camera_set_fov(Camera *c, const float value) {
    c->fov = CLAMP(value, CAMERA_FOV_MIN, CAMERA_FOV_MAX);
    if (c->mode == Perspective) {
        _camera_set_dirty(c, CAMERA_PROJ);
    }
}

float camera_get_width(const Camera *c) {
    return c->width;
}

void camera_set_width(Camera *c, const float value) {
    c->width = value;
    _camera_set_dirty(c, CAMERA_PROJ);
}

float camera_get_height(const Camera *c) {
    return c->height;
}

void camera_set_height(Camera *c, const float value) {
    c->height = value;
    _camera_set_dirty(c, CAMERA_PROJ);
}

float camera_get_near(const Camera *c) {
    return c->nearPlane;
}

void camera_set_near(Camera *c, const float value) {
    c->nearPlane = value;
    _camera_set_dirty(c, CAMERA_PROJ);
}

float camera_get_far(const Camera *c) {
    return c->farPlane;
}

void camera_set_far(Camera *c, const float value) {
    c->farPlane = value;
    _camera_set_dirty(c, CAMERA_PROJ);
}

float camera_get_target_x(const Camera *c) {
    return c->targetX;
}

void camera_set_target_x(Camera *c, const float value) {
    c->targetX = value;
    _camera_set_dirty(c, CAMERA_TARGET);
}

float camera_get_target_y(const Camera *c) {
    return c->targetY;
}

void camera_set_target_y(Camera *c, const float value) {
    c->targetY = value;
    _camera_set_dirty(c, CAMERA_TARGET);
}

float camera_get_target_width(const Camera *c) {
    return c->targetWidth;
}

void camera_set_target_width(Camera *c, const float value) {
    c->targetWidth = value;
    _camera_set_dirty(c, CAMERA_TARGET);
}

float camera_get_target_height(const Camera *c) {
    return c->targetHeight;
}

void camera_set_target_height(Camera *c, const float value) {
    c->targetHeight = value;
    if (c->mode == Orthographic) {
        _camera_set_dirty(c, CAMERA_PROJ);
    }
    _camera_set_dirty(c, CAMERA_TARGET);
}

bool camera_is_projection_dirty(const Camera *c) {
    return _camera_get_dirty(c, CAMERA_PROJ);
}

bool camera_is_target_dirty(const Camera *c) {
    return _camera_get_dirty(c, CAMERA_TARGET);
}

void camera_clear_dirty(Camera *c) {
    c->dirty = CAMERA_NONE;
}

// MARK: - View -

uint32_t camera_get_color(const Camera *c) {
    return c->color;
}

void camera_set_color(Camera *c, const uint8_t r, const uint8_t g, const uint8_t b, const uint8_t a) {
    c->color = utils_uint8_to_rgba(r, g, b, a);
}

uint8_t camera_get_alpha(Camera *c) {
    return (c->color >> 24) & 0xff;
}

float camera_get_alpha_f(Camera *c) {
    return ((c->color >> 24) & 0xff) / 255.0f;
}

void camera_set_alpha(Camera *c, const uint8_t a) {
    uint8_t rgba[4]; utils_rgba_to_uint8(c->color, rgba);
    camera_set_color(c, rgba[0], rgba[1], rgba[2], a);
}

void camera_set_alpha_f(Camera *c, const float a) {
    camera_set_alpha(c, (uint8_t)(a * 255));
}

uint16_t camera_get_layers(const Camera *c) {
    return c->layers;
}

void camera_set_layers(Camera *c, const uint16_t value) {
    c->layers = value;
}

uint8_t camera_get_order(const Camera *c) {
    return c->viewOrder;
}

void camera_set_order(Camera *c, const uint8_t value) {
    c->viewOrder = value;
}

bool camera_is_enabled(const Camera *c) {
    return c->enabled && c->layers != CAMERA_LAYERS_NONE;
}

void camera_set_enabled(Camera *c, const bool value) {
    c->enabled = value;
}

// MARK: - Transform -

const float3 *camera_get_position(const Camera *c, const bool refreshParents) {
    if (c == NULL)
        return NULL;

    return transform_get_position(c->view, refreshParents);
}

Quaternion* camera_get_rotation(const Camera *c) {
    if (c == NULL)
        return NULL;

    return transform_get_rotation(c->view);
}

void camera_get_rotation_euler(const Camera *c, float3 *euler) {
    if (c == NULL)
        return;

    transform_get_rotation_euler(c->view, euler);
}

// MARK: - Utils -

void camera_unorm_screen_to_vector(const Camera *c, float x, float y, float3 *out_vector) {
    if (c == NULL) {
        return;
    }

    // unorm to norm screen pos
    float norm[4] = {x * 2.0f - 1.0f, y * 2.0f - 1.0f, 1.0f, 1.0f};

    // screen to view pos
    float view[4];
    matrix4x4_op_multiply_vec((float4 *)view, (const float4 *)norm, c->invProjMatrix);
    view[2] = 1.0f; // forward z
    view[3] = 0.0f; // vector
    // note: if we wanted a world point instead we could use z:near plane / w:1.0f

    // view to world pos
    float world[4];
    matrix4x4_op_multiply_vec((float4 *)world, (const float4 *)view, camera_get_inv_view_matrix(c));

    out_vector->x = world[0];
    out_vector->y = world[1];
    out_vector->z = world[2];

    // normalize because we arbitrarily set a z value
    float3_normalize(out_vector);
}

void camera_unorm_screen_to_ray(const Camera *c, float x, float y, float3 *out_origin, float3 *out_direction) {
    transform_refresh(c->view, false, true); // refresh ltw for intra-frame calculations
    const float3 *eye = transform_get_position(c->view, false);

    float3 origin, direction;
    if (c->mode == Perspective) {
        origin = *eye;

        camera_unorm_screen_to_vector(c, x, y, &direction);
    } else {
        const float dx = c->width * x;
        const float dy = c->height * y;

        float3 right, up;
        if (quaternion_is_zero(transform_get_rotation(c->view), EPSILON_ZERO_RAD)) {
            right = float3_right;
            up = float3_up;
        } else {
            transform_get_right(c->view, &right, false);
            transform_get_up(c->view, &up, false);
        }

        origin = (float3){eye->x + right.x * dx + up.x * dy,
                          eye->y + right.y * dx + up.y * dy,
                          eye->z + right.z * dx + up.z * dy };

        transform_get_forward(c->view, &direction, false);
    }

    if (out_origin != NULL) {
        *out_origin = origin;
    }
    if (out_direction != NULL) {
        *out_direction = direction;
    }
}

bool camera_world_to_unorm_screen(const Camera *c, float x, float y, float z, float *resultX, float *resultY) {
    float4 world = { x, y, z, 1.0f };
    float4 screen;

    // world to clip space
    matrix4x4_op_multiply_vec(&screen, &world, c->viewProjMatrix);

    if (float_isZero(screen.w, EPSILON_ZERO)) {
        return false;
    }

    // perspective division
    screen.x /= screen.w;
    screen.y /= screen.w;
    screen.z /= screen.w;

    if (fabsf(screen.x) > 1 || fabsf(screen.y) > 1 || fabsf(screen.z) > 1) {
        return false;
    }

    // norm to unorm
    *resultX = screen.x * 0.5f + 0.5f;
    *resultY = screen.y * 0.5f + 0.5f;

    return true;
}

float camera_fit_to_screen_box(const Camera *c,
                               const float3 *min,
                               const float3 *max,
                               float aspect,
                               float coverage,
                               float3 *targetInOut,
                               float *boxOut,
                               FitToScreen_Orientation orientation) {
    if (c == NULL) {
        return 0.0f;
    }

    transform_refresh(c->view, false, true); // refresh ltw for intra-frame calculations
    const float3 eye = *transform_get_position(c->view, false);

    // world bounding box vertices
    float world[4 * 8] = {min->x, min->y, min->z, 1.0f, max->x, min->y, min->z, 1.0f,
                          max->x, max->y, min->z, 1.0f, min->x, max->y, min->z, 1.0f,
                          min->x, min->y, max->z, 1.0f, max->x, min->y, max->z, 1.0f,
                          max->x, max->y, max->z, 1.0f, min->x, max->y, max->z, 1.0f};

    // set camera view at a distance that should always guarantee that camera
    // isn't inside the box, for projection purposes
    const float d = 1 + c->nearPlane + maximum(max->x - min->x, maximum(max->y - min->y, max->z - min->z));
    float3 forward; transform_get_forward(c->view, &forward, false);
    targetInOut->x -= forward.x * d;
    targetInOut->y -= forward.y * d;
    targetInOut->z -= forward.z * d;
    transform_set_position(c->view, targetInOut->x, targetInOut->y, targetInOut->z);
    transform_refresh(c->view, false, true); // refresh wtl for intra-frame calculations
    // TODO: build a view matrix without using camera transform


    float result = 0;
    if (c->mode == Orthographic) {
        // compute view-proj for given view
        Matrix4x4 viewProj = *camera_get_view_matrix(c);
        matrix4x4_op_multiply(&viewProj, c->projMatrix);

        // world to screen unorm
        float screen[4 * 8];
        int vIdx;
        for (int i = 0; i < 8; i++) {
            vIdx = 4 * i;

            // world to clip space
            matrix4x4_op_multiply_vec((float4 *) (&screen[vIdx]), (float4 *) (&world[vIdx]), &viewProj);

            // perspective division
            screen[vIdx] /= screen[vIdx + 3];
            screen[vIdx + 1] /= screen[vIdx + 3];

            // norm to unorm (no need to bother for flip V here)
            screen[vIdx] = (screen[vIdx] + 1) / 2;
            screen[vIdx + 1] = (screen[vIdx + 1] + 1) / 2;
        }

        // screen normalized bounding box
        float screenMin[2] = {screen[0], screen[1]};
        float screenMax[2] = {screen[0], screen[1]};
        for (int i = 1; i < 8; i++) {
            vIdx = 4 * i;

            if (screen[vIdx] < screenMin[0]) { // x
                screenMin[0] = screen[vIdx];
            }
            if (screen[vIdx + 1] < screenMin[1]) { // y
                screenMin[1] = screen[vIdx + 1];
            }

            if (screen[vIdx] > screenMax[0]) { // x
                screenMax[0] = screen[vIdx];
            }
            if (screen[vIdx + 1] > screenMax[1]) { // y
                screenMax[1] = screen[vIdx + 1];
            }
        }

        if (boxOut != NULL) {
            boxOut[0] = screenMin[0];
            boxOut[1] = screenMin[1];
            boxOut[2] = screenMax[0];
            boxOut[3] = screenMax[1];
        }

        // resize ratio for the limiting dimension (max of normalized height/width)
        const float bbWidth = screenMax[0] - screenMin[0];
        const float bbHeight = screenMax[1] - screenMin[1];
        float r;
        switch(orientation) {
            case FitToScreen_Minimum:
                r = maximum(bbWidth, bbHeight) / coverage;
                break;
            case FitToScreen_Vertical:
                r = bbHeight / coverage;
                break;
            case FitToScreen_Horizontal:
                r = bbWidth / coverage;
                break;
        }

        if (boxOut != NULL) {
            boxOut[4] = r;
        }

        result = r;
    } else {
        const Matrix4x4 *viewMtx = camera_get_view_matrix(c);

        // world to view
        float view[4 * 8];
        int vIdx;
        for (int i = 0; i < 8; i++) {
            vIdx = 4 * i;

            matrix4x4_op_multiply_vec((float4 *) (&view[vIdx]), (float4 *) (&world[vIdx]), viewMtx);
        }

        // view bounding rectangle
        float viewMin[2] = { view[0], view[1] };
        float viewMax[2] = { view[0], view[1] };
        for (int i = 1; i < 8; i++) {
            vIdx = 4 * i;

            if (view[vIdx] < viewMin[0]) { // x
                viewMin[0] = view[vIdx];
            }
            if (view[vIdx + 1] < viewMin[1]) { // y
                viewMin[1] = view[vIdx + 1];
            }

            if (view[vIdx] > viewMax[0]) { // x
                viewMax[0] = view[vIdx];
            }
            if (view[vIdx + 1] > viewMax[1]) { // y
                viewMax[1] = view[vIdx + 1];
            }
        }

        // vertical & horizontal FOV in radians
        float fov_v, fov_h;
        camera_utils_get_vertical_and_horizontal_fov(c, aspect, &fov_v, &fov_h);

        // choose maximum distance to fit view rectangle
        const float half_width = (viewMax[0] - viewMin[0]) * 0.5f * (1.0f / coverage);
        const float half_height = (viewMax[1] - viewMin[1]) * 0.5f * (1.0f / coverage);

        float dh = half_width / tanf(fov_h * .5f);
        float dv = half_height / tanf(fov_v * .5f);

        switch(orientation) {
            case FitToScreen_Minimum:
                result = maximum(dv, dh);
                break;
            case FitToScreen_Vertical:
                result = dv;
                break;
            case FitToScreen_Horizontal:
                result = dh;
                break;
        }
    }

    // restore camera original position
    transform_set_position(c->view, eye.x, eye.y, eye.z);

    return result;
}

float camera_fit_to_screen_perspective_sphere(const Camera *c,
                                              const Box *box,
                                              float aspect,
                                              float coverage,
                                              FitToScreen_Orientation orientation) {
    if (c == NULL) {
        return 0.0f;
    }

    float fov;
    if (orientation == FitToScreen_Minimum) {
        // minimum FOV in radians
        fov = utils_deg2Rad(c->fov);
    } else {
        // vertical & horizontal FOV in radians
        float fov_v, fov_h;
        camera_utils_get_vertical_and_horizontal_fov(c, aspect, &fov_v, &fov_h);

        fov = orientation == FitToScreen_Vertical ? fov_v : fov_h;
    }

    // bounding sphere from bounding box
    const float radius = box_get_diagonal(box) * .5f / coverage;

    // range between eye and center of the sphere
    const float d = radius / tanf(fov * .5f);

    return d;
}

bool camera_layers_match(const uint16_t layers1, const uint16_t layers2) {
    return (layers1 & layers2) != CAMERA_LAYERS_NONE;
}

void camera_utils_apply_fit_to_screen(Camera *c, const Box *box, const float coverage,
                                      const uint32_t widthPoints, const uint32_t heightPoints,
                                      const bool useBox, FitToScreen_Orientation orientation) {

    const float width = camera_get_width(c) > 0 ? camera_get_width(c) : (float)widthPoints;
    const float height = camera_get_height(c) > 0 ? camera_get_height(c) : (float)heightPoints;
    const float aspect = width / height;

    float3 target;
    box_get_center(box, &target);

    // fit to screen based on projection mode
    if (camera_get_mode(c) == Perspective) {
        const float d = useBox ?
            camera_fit_to_screen_box(c, &box->min, &box->max, aspect, coverage, &target, NULL, orientation) :
            camera_fit_to_screen_perspective_sphere(c, box, aspect, coverage, orientation);

        Transform *view = camera_get_view_transform(c);
        float3 forward; transform_get_forward(view, &forward, true);
        transform_set_position(view,
                               target.x - forward.x * d,
                               target.y - forward.y * d,
                               target.z - forward.z * d);
    } else {
        const float r = camera_fit_to_screen_box(c, &box->min, &box->max, aspect, coverage, &target, NULL, orientation);

        camera_set_width(c, width * r);
        camera_set_height(c, height * r);
        transform_set_position(camera_get_view_transform(c), target.x, target.y, target.z);
    }
}

float camera_utils_horizontal_to_vertical_fov(const float hfov, const float aspect) {
    return 2.0f * atanf(tanf(hfov * .5f) / aspect);
}

float camera_utils_vertical_to_horizontal_fov(const float vfov, const float aspect) {
    return 2.0f * atanf(tanf(vfov * .5f) * aspect);
}

void camera_utils_get_vertical_and_horizontal_fov(const Camera *c, const float aspect, float *outVFov, float *outHFov) {
    const float fov_min = utils_deg2Rad(c->fov);
    if (aspect > 1.0f) { // landscape: minimum FOV is vertical FOV
        *outVFov = fov_min;
        *outHFov = camera_utils_vertical_to_horizontal_fov(fov_min, aspect);
    } else { // portrait: minimum FOV is horizontal FOV
        *outVFov = camera_utils_horizontal_to_vertical_fov(fov_min, aspect);
        *outHFov = fov_min;
    }
}

float camera_utils_get_vertical_fov(const Camera *c, const float aspect) {
    const float fov_min = utils_deg2Rad(c->fov);
    if (aspect > 1.0f) {
        return fov_min;
    } else {
        return camera_utils_horizontal_to_vertical_fov(fov_min, aspect);
    }
}

float camera_utils_get_vertical_fov2(const Camera *c, const uint32_t screenWidth, const uint32_t screenHeight) {
    const float width = camera_get_width(c) > 0 ? camera_get_width(c) : (float)screenWidth;
    const float height = camera_get_height(c) > 0 ? camera_get_height(c) : (float)screenHeight;
    const float aspect = width / height;

    return camera_utils_get_vertical_fov(c, aspect);
}

float camera_utils_get_horizontal_fov(const Camera *c, const float aspect) {
    const float fov_min = utils_deg2Rad(c->fov);
    if (aspect > 1.0f) {
        return camera_utils_vertical_to_horizontal_fov(fov_min, aspect);
    } else {
        return fov_min;
    }
}

float camera_utils_get_horizontal_fov2(const Camera *c, const uint32_t screenWidth, const uint32_t screenHeight) {
    const float width = camera_get_width(c) > 0 ? camera_get_width(c) : (float)screenWidth;
    const float height = camera_get_height(c) > 0 ? camera_get_height(c) : (float)screenHeight;
    const float aspect = width / height;

    return camera_utils_get_horizontal_fov(c, aspect);
}
