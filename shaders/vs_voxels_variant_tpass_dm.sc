/*
 * Voxels vertex shader variant: transparency pass, draw modes
 */

// Lit
#define VOXEL_VARIANT_UNLIT 0

// Multiple render target transparency
#define VOXEL_VARIANT_MRT_TRANSPARENCY 1
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0
#define VOXEL_VARIANT_MRT_SHADOW_PACK 0
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 0

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODES 1

#include "./vs_voxels_common.sh"