/*
 * Voxels vertex shader variant: vlit, transparency pass
 */

// Lighting as 2D texture
#define VOXEL_VARIANT_UNLIT 0
#define VOXEL_VARIANT_LIGHTING_UNIFORM 0
#define VOXEL_VARIANT_LIGHTING_ATTRIBUTES 1

// Multiple render target transparency
#define VOXEL_VARIANT_MRT_TRANSPARENCY 1
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0
#define VOXEL_VARIANT_MRT_SHADOW_PACK 0
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 0

// No draw modes
#define VOXEL_VARIANT_DRAWMODES 0

#include "./vs_voxels_common.sh"