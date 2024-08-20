/*
 * Quad fragment shader variant: lighting pass
 */

// Multiple render target lighting
#define QUAD_VARIANT_MRT_LIGHTING 1
#define QUAD_VARIANT_MRT_LINEAR_DEPTH 0

// No texture
#define QUAD_VARIANT_TEX 0
#define QUAD_VARIANT_CUTOUT 0

// No alpha
#define QUAD_VARIANT_ALPHA 0

#include "./fs_quad_common.sh"