/*
 * Voxels vertex shader fallback: draw modes
 */

// Lit
#define VOXEL_VARIANT_UNLIT 0

// No multiple render target
#define VOXEL_VARIANT_MRT_TRANSPARENCY 0
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0
#define VOXEL_VARIANT_MRT_SHADOW_PACK 0
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 0

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODES 1

#include "./vs_voxels_common.sh"
