/*
 * Voxels vertex shader variant: uniform vlit, lighting pass
 */

// Vertex lighting as color uniform
#define VOXEL_VARIANT_UNLIT 0
#define VOXEL_VARIANT_LIGHTING_UNIFORM 1
#define VOXEL_VARIANT_LIGHTING_ATTRIBUTES 0

// Multiple render target lighting
#define VOXEL_VARIANT_MRT_TRANSPARENCY 0
#define VOXEL_VARIANT_MRT_LIGHTING 1
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0
#define VOXEL_VARIANT_MRT_SHADOW_PACK 0
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 0

// No draw modes
#define VOXEL_VARIANT_DRAWMODES 0

#include "./vs_voxels_common.sh"
