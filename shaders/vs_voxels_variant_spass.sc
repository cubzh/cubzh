/*
 * Voxels vertex shader variant: shadow pass w/ depth packing
 */

// No lighting
#define VOXEL_VARIANT_UNLIT 0
#define VOXEL_VARIANT_LIGHTING_UNIFORM 0
#define VOXEL_VARIANT_LIGHTING_ATTRIBUTES 0

// Multiple render target shadow w/ depth packing
#define VOXEL_VARIANT_MRT_TRANSPARENCY 0
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0
#define VOXEL_VARIANT_MRT_SHADOW_PACK 1
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 0

// No draw mode
#define VOXEL_VARIANT_DRAWMODE_OVERRIDES 0
#define VOXEL_VARIANT_DRAWMODE_OUTLINE 0

#include "./vs_voxels_common.sh"