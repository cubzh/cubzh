/*
 * Skybox fragment shader variant: cubemap, clear MRT
 */

// Blend foreground from cubemaps onto background gradient
#define SKYBOX_VARIANT_CUBEMAPS 1

// Clear multiple render target buffer
#define SKYBOX_VARIANT_MRT_CLEAR 1
#define SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH 0

#include "./fs_skybox_common.sh"
