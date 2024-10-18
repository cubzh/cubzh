/*
 * Voxels vertex shader fallback: unlit, draw mode overrides
 */
 
// Unlit
#define VOXEL_VARIANT_UNLIT 1
#define VOXEL_VARIANT_LIGHTING_UNIFORM 0
#define VOXEL_VARIANT_LIGHTING_ATTRIBUTES 0

// No multiple render target
#define VOXEL_VARIANT_MRT_TRANSPARENCY 0
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0
#define VOXEL_VARIANT_MRT_SHADOW_PACK 0
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 0

// Draw mode overrides
#define VOXEL_VARIANT_DRAWMODE_OVERRIDES 1
#define VOXEL_VARIANT_DRAWMODE_OUTLINE 0

#include "./vs_voxels_common.sh"
