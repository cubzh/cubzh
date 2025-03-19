/*
 * Voxels vertex shader variant: shadow pass w/ shadow sampler
 */

// No lighting
#define VOXEL_VARIANT_UNLIT 0

// Multiple render target shadow w/ depth sampling
#define VOXEL_VARIANT_MRT_TRANSPARENCY 0
#define VOXEL_VARIANT_MRT_LIGHTING 0
#define VOXEL_VARIANT_MRT_LINEAR_DEPTH 0
#define VOXEL_VARIANT_MRT_SHADOW_PACK 0
#define VOXEL_VARIANT_MRT_SHADOW_SAMPLE 1

// No draw modes
#define VOXEL_VARIANT_DRAWMODES 0

#include "./vs_voxels_common.sh"