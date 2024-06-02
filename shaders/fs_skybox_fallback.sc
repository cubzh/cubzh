/*
 * Skybox fragment shader fallback
 */

// No foreground
#define SKYBOX_VARIANT_CUBEMAPS 0

// No multiple render target
#define SKYBOX_VARIANT_MRT_CLEAR 0
#define SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH 0

#include "./fs_skybox_common.sh"
