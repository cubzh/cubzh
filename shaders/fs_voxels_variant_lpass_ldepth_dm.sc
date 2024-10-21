/*
 * Voxels fragment shader variant: lighting pass, linear depth, draw modes
 */

// Lit
#define VOXEL_VARIANT_UNLIT 0

// Multiple render target lighting and linear depth
#define VOXEL_VARIANT_MRT_LIGHTING 1
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 1

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODE_OVERRIDES 1

#include "./fs_voxels_common.sh"
