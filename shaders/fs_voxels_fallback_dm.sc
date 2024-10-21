/*
 * Voxels fragment shader fallback: draw modes
 */

// Lit
#define VOXEL_VARIANT_UNLIT 0

// No multiple render target
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODE_OVERRIDES 1

#include "./fs_voxels_common.sh"
