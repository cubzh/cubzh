/*
 * Vertex color weight writer fragment shader w/ font cubemap
 */

// No draw modes
#define VOXEL_VARIANT_DRAWMODE_OVERRIDES 0

// Textured
#define OIT_VARIANT_TEX 0
#define OIT_VARIANT_FONT 1
#define OIT_VARIANT_CUTOUT 0

#include "./fs_transparency_weight_common.sh"
