/*
 * Voxels fragment shader fallback
 */

// Lit
#define VOXEL_VARIANT_UNLIT 0

// No multiple render target
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0

// No draw modes
#define VOXEL_VARIANT_DRAWMODES 0

#include "./fs_voxels_common.sh"
