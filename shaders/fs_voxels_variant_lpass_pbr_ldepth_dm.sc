/*
 * Voxels fragment shader variant: lighting pass, pbr, linear depth, draw modes
 */

// Multiple render target lighting w/ pbr and linear depth
#define VOXEL_VARIANT_MRT_LIGHTING 1
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 1
#define VOXEL_VARIANT_MRT_PBR 1

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODES 1

#include "./fs_voxels_common.sh"
