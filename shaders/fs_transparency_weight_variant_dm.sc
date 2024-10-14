/*
 * Vertex color weight writer fragment shader w/ non-default draw modes
 */

// Non-default draw modes
#define VOXEL_VARIANT_DRAWMODE_OVERRIDES 1

// No texture
#define OIT_VARIANT_TEX 0
#define OIT_VARIANT_FONT 0
#define OIT_VARIANT_CUTOUT 0

#include "./fs_transparency_weight_common.sh"
