/*
 * Voxels fragment shader variant: lighting pass, draw modes
 */

// Lit
#define VOXEL_VARIANT_UNLIT 0

// Multiple render target lighting
#define VOXEL_VARIANT_MRT_LIGHTING 1
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODES 1

#include "./fs_voxels_common.sh"
