/*
 * Voxels vertex shader variant: vlit, lighting pass, linear depth, draw modes
 */

// Vertex lighting as 2D texture
#define VOXEL_VARIANT_UNLIT 0
#define VOXEL_VARIANT_LIGHTING_UNIFORM 0
#define VOXEL_VARIANT_LIGHTING_ATTRIBUTES 1

// Multiple render target lighting and linear depth
#define VOXEL_VARIANT_MRT_TRANSPARENCY 0
#define VOXEL_VARIANT_MRT_LIGHTING 1
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 1
#define VOXEL_VARIANT_MRT_SHADOW_PACK 0
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 0

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODES 1

#include "./vs_voxels_common.sh"
