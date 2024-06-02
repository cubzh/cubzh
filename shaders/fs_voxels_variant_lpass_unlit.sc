/*
 * Voxels fragment shader variant: lighting pass
 */

// Unlit (only relevant w/ lighting pass)
#define VOXEL_VARIANT_UNLIT 1

// Multiple render target lighting
#define VOXEL_VARIANT_MRT_LIGHTING 1
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0

// No draw modes
#define VOXEL_VARIANT_DRAWMODES 0

#include "./fs_voxels_common.sh"
