/*
 * Vertex color weight writer fragment shader w/ texture cutout
 */

// No draw modes
#define VOXEL_VARIANT_DRAWMODE_OVERRIDES 0

// Texture cutout
#define OIT_VARIANT_TEX 1
#define OIT_VARIANT_FONT 0
#define OIT_VARIANT_CUTOUT 1

#include "./fs_transparency_weight_common.sh"
